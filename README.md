# gd-pickleball

**Pickleball court practice** — portrait play against two automatic opponents.

Both drills use the original fixed overhead view. All athletes, the net, the kitchen lines and the baselines stay visible. The former wall drill is now **RALLY**, a one-bounce exchange against two opponents; **VOLLEY** keeps volleys and short dinks. The left header selector changes drill before play, after a miss or while paused. The right selector chooses one or two near-side athletes; both drills start with two and always keep two opponents.

Use the large bottom button to choose **KITCHEN LINE** or **BASELINE** at any time, including during a rally. Both teammates move forward/backward together at the same pace. The button never serves, swings, resets the score or discards an early queued return. Each drill remembers its own line and player count. When positioned at the kitchen, both may step forward to collect a short bounced dink, then recover toward the selected line after hitting.

Tap anywhere else to serve or return on release. A short swipe plays a dink; a longer swipe plays a deep stroke. Left/right chooses the course and long up/down swipes lift/drive. There is no hold power. Early input waits for the legal contact, including the first bounce in RALLY or on a dink. Missing a second bounce ends that exchange. Opponents pick up short shots after their bounce and automatically return across the court.

P1 covers the left half and P2 the right. The incoming course selects the receiver, with central balls shared with the partner. Horizontal footwork is automatic and stays within each player's territory; depth follows the common line choice. Real racket contacts trigger a flash and ring. The court camera stays fixed during line changes, receiver changes, hits and retries.

All game text is English. Click or Space / Enter uses the same gesture on desktop. P / Escape pauses and R resets. Leaving the app pauses an active rally. The two drills retain separate saved personal bests.

- [Player rules](docs/rules.md)
- [Implementation and validation](docs/implementation.md)

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

The bottom of the game always shows **BUILD <run>.<attempt>** (for example, **BUILD 27.1**). This number is embedded inside the loaded game pack and matches `version.json`'s `display_id`. GitHub Actions supplies the workflow run/attempt automatically. Local Web exports show `BUILD LOCAL`, or use `APP_BUILD_ID=preview-1 ./scripts/export_web.sh` to choose a preview label.

Pushes to `main` run `.github/workflows/web.yml`; GitHub Pages source must be **GitHub Actions**. Public URL after deployment: https://naninunenoy.github.io/gd-pickleball/
