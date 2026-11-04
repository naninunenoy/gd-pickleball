# gd-pickleball

**Wall rally** — solo pickleball practice, made for your phone in portrait.

One player. One wall. Tap to serve, let the ball bounce once, then tap when the pad says **TAP NOW**. Footwork is automatic; you control the rhythm. Keep the rally going and beat your saved personal best.

Tap the court or the large bottom pad. No aiming, dragging or double-tap needed. A second bounce ends the rally; tap to try again. Pause freezes play and leaving the app/tab pauses an active rally. On desktop, click or Space / Enter to hit, P / Escape to pause, R to reset.

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
