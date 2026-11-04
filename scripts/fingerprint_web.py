#!/usr/bin/env python3
"""Give each Godot Web release immutable asset URLs and a freshness check."""

import hashlib
import json
from pathlib import Path
import re
import sys


def fingerprint_export(out: Path, revision: str = "") -> dict:
    html_path = out / "index.html"
    html = html_path.read_text(encoding="utf-8")
    config_match = re.search(r"const GODOT_CONFIG = (.+);", html)
    if not config_match:
        raise ValueError("Unsupported Godot HTML: GODOT_CONFIG not found")
    config = json.loads(config_match[1])
    if config.get("executable") != "index":
        raise ValueError("Expected a fresh, unversioned index export")
    for name in ("index.html", "index.js", "index.pck", "index.wasm"):
        if not (out / name).is_file() or (out / name).stat().st_size == 0:
            raise ValueError(f"Missing export: {name}")
    if html.count("engine.startGame({") != 1 or html.count("</head>") != 1:
        raise ValueError("Unsupported Godot HTML: startup or head changed")

    updater = Path(__file__).with_name("web_update.js").read_text(encoding="utf-8")
    files = sorted(out.glob("index.*"))
    digest = hashlib.sha256()
    digest.update(Path(__file__).read_bytes())
    digest.update(updater.encode())
    digest.update(revision.encode())
    for path in files:
        digest.update(path.name.encode() + b"\0")
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    build = digest.hexdigest()[:16]
    executable = f"game-{build}"
    assets = {path.name: executable + path.name[len("index"):]
              for path in files if path.name != "index.html"}
    config["executable"] = executable
    config["fileSizes"] = {assets.get(name, name): size
                           for name, size in config.get("fileSizes", {}).items()}
    html = html[:config_match.start(1)] + json.dumps(config, separators=(",", ":")) + html[config_match.end(1):]
    for original, versioned in assets.items():
        html = html.replace(original, versioned)
    updater = updater.replace("__GAME_BUILD__", build)
    html = html.replace("</head>", f'<meta name="game-build" content="{build}">\n<script>\n{updater}\n</script>\n</head>')
    html = html.replace("engine.startGame({", "startCurrentGame({")
    startup = """
async function startCurrentGame(options) {
    if (await window.ensureCurrentGameBuild()) return engine.startGame(options);
    return new Promise(() => {}); // Navigation to the current release is underway.
}
"""
    html = html.replace("const engine = new Engine(GODOT_CONFIG);",
                        "const engine = new Engine(GODOT_CONFIG);\n" + startup)
    if "async function startCurrentGame" not in html or "new Engine(GODOT_CONFIG)" not in html:
        raise ValueError("Unsupported Godot HTML: engine creation changed")
    for original, versioned in assets.items():
        (out / original).rename(out / versioned)
    html_path.write_text(html, encoding="utf-8")
    manifest = {"build": build, "executable": executable}
    if revision:
        manifest["revision"] = revision
    (out / "version.json").write_text(json.dumps(manifest) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    result = fingerprint_export(Path(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 else "")
    print(f"Versioned Web release: {result['build']}")
