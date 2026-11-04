import json
from pathlib import Path
import re
import tempfile
import unittest

from fingerprint_web import fingerprint_export


class WebExportTests(unittest.TestCase):
    def fixture(self, root: Path, pack: bytes = b"game-a") -> None:
        root.mkdir()
        config = {"executable": "index", "fileSizes": {"index.pck": len(pack), "index.wasm": 8}}
        (root / "index.html").write_text(
            '<html><head><link href="index.icon.png"></head><body><script src="index.js"></script>\n'
            f'const GODOT_CONFIG = {json.dumps(config)};\n'
            'const engine = new Engine(GODOT_CONFIG);\nengine.startGame({});</body></html>')
        (root / "index.js").write_text("engine")
        (root / "index.wasm").write_bytes(b"\0asmtest")
        (root / "index.pck").write_bytes(pack)
        (root / "index.icon.png").write_bytes(b"icon")
        (root / "index.audio.worklet.js").write_text("audio")

    def test_every_asset_and_godot_configuration_share_one_version(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "out"
            self.fixture(root)
            manifest = fingerprint_export(root, "commit-a")
            prefix = manifest["executable"]
            html = (root / "index.html").read_text()
            config = json.loads(re.search(r"const GODOT_CONFIG = (.+);", html)[1])
            self.assertEqual(config["executable"], prefix)
            self.assertEqual(config["fileSizes"], {f"{prefix}.pck": 6, f"{prefix}.wasm": 8})
            self.assertIn(f'src="{prefix}.js"', html)
            self.assertIn(f'href="{prefix}.icon.png"', html)
            self.assertTrue((root / f"{prefix}.audio.worklet.js").is_file())
            self.assertEqual((root / f"{prefix}.pck").read_bytes(), b"game-a")
            self.assertFalse((root / "index.wasm").exists())
            self.assertEqual(json.loads((root / "version.json").read_text()), manifest)
            self.assertIn("await window.ensureCurrentGameBuild()", html)
            self.assertIn("cache: 'no-store'", html)
            self.assertIn("visibilitychange", html)
            self.assertNotIn("__GAME_BUILD__", html)

    def test_content_or_deploy_revision_changes_asset_urls(self):
        with tempfile.TemporaryDirectory() as directory:
            builds = []
            for number, (pack, revision) in enumerate([
                (b"game-a", "commit-a"), (b"game-a", "commit-a"),
                (b"game-b", "commit-a"), (b"game-a", "commit-b"),
            ]):
                root = Path(directory) / str(number)
                self.fixture(root, pack)
                builds.append(fingerprint_export(root, revision)["build"])
            self.assertEqual(builds[0], builds[1])
            self.assertNotEqual(builds[0], builds[2])
            self.assertNotEqual(builds[0], builds[3])

    def test_unknown_template_fails_before_changing_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "out"
            self.fixture(root)
            (root / "index.html").write_text("unsupported template")
            with self.assertRaises(ValueError):
                fingerprint_export(root)
            self.assertTrue((root / "index.pck").is_file())


if __name__ == "__main__":
    unittest.main()
