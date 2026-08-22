# gd-pickleball

Overhead 2D pickleball doubles. This version repeats serve-to-rally points. First to 11.

- Player rules: [`docs/rules.md`](docs/rules.md)
- Implementation notes: [`docs/implementation.md`](docs/implementation.md)
- Design discussion (phases, kitchen, camera hypotheses): [`docs/design-discussion.md`](docs/design-discussion.md)

Mouse aims on the opponent court. Click is a soft hit, double-click is a hard hit. If a volley is legal, take it in the air. Serves always land in the legal box; there is no service fault.

In-game text is English only. `fonts/Inter-Regular.ttf` is the UI font so labels stay readable in the web build.

## Run

Godot **4.7.2**, main scene `scenes/main.tscn`. Headless checks:

```bash
./scripts/install_godot.sh
godot --headless --path . -s res://scripts/check_slice.gd
godot --headless --path . --quit-after 720 -- --auto-rally
```

## Web

Godot 4.7 / GDScript exports to WASM for GitHub Pages. The game scripts are not recompiled for the browser. A prebuilt engine WASM ships with a `.pck`.

GitHub Pages uses a **no-threads** web export. That is the Godot 4.3+ default, so COOP/COEP headers for `SharedArrayBuffer` are not required.

Limits:

- Web is Compatibility renderer / WebGL 2.0 only
- Godot 4 C# does not export to web. This repo is GDScript only
- No-threads builds are slower than threaded ones

Public URL after Pages is enabled:

https://naninunenoy.github.io/gd-pickleball/

```bash
./scripts/install_godot.sh
./scripts/export_web.sh
python3 -m http.server 8080 --directory build/web
```

Opening the HTML via `file://` will not work. Push to `main` runs `.github/workflows/web.yml`. Set Pages source to **GitHub Actions** once in the repo settings.
