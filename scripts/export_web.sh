#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-$HOME/.local/bin/godot}"
OUT_DIR="$ROOT/build/web"
OUT_HTML="$OUT_DIR/index.html"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot binary not found at $GODOT" >&2
  echo "Run ./scripts/install_godot.sh first." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Importing project resources"
"$GODOT" --headless --path "$ROOT" --import

echo "Exporting Web release preset to $OUT_HTML"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT_HTML"

# GitHub Pages would otherwise treat underscore-prefixed files as Jekyll drafts.
touch "$OUT_DIR/.nojekyll"

echo "Export complete:"
ls -lh "$OUT_DIR"

required_files=(index.html index.js index.wasm index.pck)
for name in "${required_files[@]}"; do
  if [[ ! -s "$OUT_DIR/$name" ]]; then
    echo "Missing or empty export file: $name" >&2
    exit 1
  fi
done

python3 - "$OUT_DIR" <<'PY'
from pathlib import Path
import sys

out = Path(sys.argv[1])
wasm = (out / "index.wasm").read_bytes()[:4]
if wasm != b"\x00asm":
    raise SystemExit(f"index.wasm is not a WebAssembly module: {wasm!r}")

html = (out / "index.html").read_text(encoding="utf-8")
if "const GODOT_THREADS_ENABLED = false;" not in html:
    raise SystemExit("Web export is not single-threaded; GitHub Pages would need COOP/COEP headers")
print("WASM module and single-threaded export verified")
PY
