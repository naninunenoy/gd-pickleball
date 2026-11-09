# gd-pickleball

**Pickleball practice** — wall rallies and singles/doubles volleys, made for your phone in portrait.

Use the left header selector before playing, after a miss, or while paused to switch between **WALL RALLY** and **VOLLEY RALLY**. The choice is saved. The right selector chooses wall player count or volley SINGLES / DOUBLES. Each game remembers its own choice.

**Volley rally** is a first-person kitchen-line exchange. Choose **SINGLES** for 1v1 or **DOUBLES** for 2v2 on the same phone; opponents return automatically. Tap anywhere to start or return when you lift your finger. A short swipe plays a **dink** into the opposing kitchen; a longer swipe plays a deep stroke. The arrow previews a short dink in blue and a deep stroke in green. Left/right aims the course; longer up/down swipes launch upward/downward. Gesture duration never adds power. Normal volleys retain their relaxed tempo (65% of normal wall speed with gentle acceleration).

A dink clears the net and bounces in the kitchen before it is picked up. Opponents reply with a dink, and your receiver moves forward to collect its bounce. An early tap waits until after the bounce; a normal tap on the low ball automatically dinks it back. Use a longer swipe to send the next ball deep and recover behind the kitchen line. Unbounced volleys are blocked inside the kitchen. A landing ring marks short shots, and the camera moves forward and looks lower during a dink pickup. Missing the second bounce ends the rally.

In doubles, P1 covers the left half and P2 the right. The course selects the opposing receiver; opponents return crosscourt, and that course selects your next receiver. Central balls go to the partner. After hitting, each athlete recovers toward their home lane. The camera follows the selected receiver's first-person view, and the header shows P1/P2 TO HIT. Volley and wall practice keep separate personal bests and independent player-count preferences.

**Wall rally:** One wall. Practice with one or two athletes on the same phone. Tap anywhere to serve and return after one bounce. Footwork is automatic; keep the rally going and beat your saved personal best.

The entire screen accepts taps and holds, including the score and footer. During a rally, there are no shot or player-switch buttons. Release a short tap for a normal shot, with a little early-tap assistance. You can also return the ball as it falls after the apex: normal taps and strong shots share the same extended reach during descent. Holding for at least 0.2 seconds selects optional power: release near the racket for a faster shot, up to 1.6x at 0.75 seconds. Nothing fires on press, so normal taps and holds never compete. Before lifting your finger, optionally swipe to aim: left/right changes the lateral shot direction, up/down sends it higher/lower. An arrow previews your swipe. A still tap sends the ball straight toward the wall; hold duration controls speed independently of aiming. A bright ring and sparks mark each strike. Tap to retry after a second bounce. Desktop click or Space / Enter uses the same gesture. P / Escape pauses; R resets. Leaving the app/tab pauses an active rally; tap anywhere to resume.

Use the **1 PLAYER / 2 PLAYERS** selector before serving, after a miss, or while paused. Changing mode restarts the rally and keeps the shared personal best; the selected mode is saved. In two-player practice, P1 owns the left side and P2 owns the right. The return course chooses the receiver; central balls are yielded to the partner. After every strike both athletes return toward their own home positions until the ball hits the wall. Only after the wall rebound does the receiver approach the strike point, with limited middle coverage. The receiver stays fixed for that ball, including during a hold. P1/P2 labels, different outfits and the active player's foot ring show who is receiving. The other athlete stays at their own home position. A player may receive consecutive balls; switching follows the course rather than alternating turns.

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

The bottom of the game always shows **BUILD <run>.<attempt>** (for example, **BUILD 27.1**). This number is embedded inside the loaded game pack and matches `version.json`'s `display_id`. GitHub Actions supplies the workflow run/attempt automatically. Local Web exports show `BUILD LOCAL`, or use `APP_BUILD_ID=preview-1 ./scripts/export_web.sh` to choose a preview label.

Pushes to `main` run `.github/workflows/web.yml`; GitHub Pages source must be **GitHub Actions**. Public URL after deployment: https://naninunenoy.github.io/gd-pickleball/
