# gd-pickleball

**Wall rally** — solo pickleball practice, made for your phone in portrait.

One player. One wall. Tap to serve and return after one bounce. Normal taps hit on press, with a little early-tap assistance. Footwork is automatic; keep the rally going and beat your saved personal best.

Use the court or the large main button. The separate POWER button is optional: hold and release for a faster shot, up to 1.6x at 0.75 seconds. Normal play needs no holding, aiming, dragging or double-tapping. A bright ring and sparks mark each strike. Tap to retry after a second bounce. On desktop, click or Space / Enter hits immediately; Shift + Space / Enter charges. P / Escape pauses; R resets. Leaving the app/tab pauses an active rally.

- [Player rules](docs/rules.md)
- [Implementation and validation](docs/implementation.md)

All in-game text is English, using the embedded Inter font.

## Run

Godot **4.7.2**, main scene `scenes/main.tscn`.

```bash
./scripts/install_godot.sh
export PATH="$HOME/.local/bin:$PATH"
godot --headless --path . --import
godot --headless --path . -s res://scripts/check_slice.gd
godot --headless --path . --fixed-fps 60 --quit-after 7200 -- --auto-rally
```

Open `project.godot` in the Godot editor to play natively. The reference viewport is 432x864; wider screens keep the same tall play area.

## Web

```bash
./scripts/install_godot.sh
./scripts/export_web.sh
python3 -m http.server 8080 --directory build/web
```

Open over HTTP, not `file://`. The Web export uses WebGL 2.0 / Compatibility and single-threaded WASM, without SharedArrayBuffer or COOP/COEP requirements. No-threads builds are slower than threaded builds. Mobile browsers preserve the portrait layout even when orientation cannot be locked. Best records use local storage and can be cleared with browser site data.

Each export gives its JavaScript, WASM, PCK and companion files a release-specific name. The entry page checks `version.json` without using the HTTP cache before starting, when returning to the tab, and when restoring browser history. If the page is stale, it opens the current release automatically. This refreshes game files without deleting personal best records. GitHub Pages does not support setting custom cache response headers from this repository.

Pushes to `main` run `.github/workflows/web.yml`; GitHub Pages source must be **GitHub Actions**. Public URL after deployment: https://naninunenoy.github.io/gd-pickleball/
