# Wall practice implementation

`docs/rules.md` is the player-facing source of truth. All in-game strings stay English and use the embedded Inter font.

## Architecture

- `wall_rally.gd`: deterministic practice state and analytic ball trajectories, independent of display/input. READY -> OUTBOUND -> RETURNING -> BOUNCED -> OUTBOUND on a legal tap, or MISSED on a second ground bounce.
- `main.gd`: input, pause/focus lifecycle, local best persistence, auto-rally diagnostics, scene synchronization.
- `athlete.gd`: one automatically moving player with a paddle swing.
- `ball.gd`: bright ball, ground shadow, short trail and contact marker.
- `court_3d.gd`: half court and solid wall; there is no net, CPU or partner.
- `camera_rig.gd`: stable portrait camera showing the full wall, bounce zone and player.
- `play_hud.gd`: rally/best counters, timing cue, one large tap pad, pause/resume.
- `check_slice.gd`: deterministic rules and full-scene input/lifecycle regression checks.

Coordinates are feet, X across a 12-foot practice lane, Y up, Z away from the wall at Z=0. The wall varies its rebound within the lane. An outbound arc hits the wall at height 3.4, then returns to a ground bounce at Z=13.6. The next bounce would be at Z=23. A legal tap between 16% and 76% of that bounce arc sends the ball back only when the racket can reach it. A 0.18s buffer accepts a slightly early tap; it expires normally and is consumed by a return. Each return counts once; serving counts zero. Flight times gradually shrink to a 72% floor. Integration uses small steps and preserves segment overshoot so slow frames do not skip entire input windows.

## Dominant hand and contact

`main.gd` exports an internal `dominant_hand` setting, defaulting to `WallRally.Hand.RIGHT`. Set it to `WallRally.Hand.LEFT` in a scene or before adding the main node to the tree to mirror the player. No handedness selector is exposed in the game HUD. The chosen hand survives retries.

The racket center is 1.15 feet to the dominant side and 1.1 feet ahead of the player's feet. On wall rebound, `trajectory_apex()` predicts the highest point of the upcoming first-bounce arc. For this symmetric arc it is `(target_x, 2.65, 18.3)`. The calculation also handles different start/end heights and linear paths. `movement_target()` offsets that point by the dominant hand and forward racket reach, putting the feet at `(apex.x - hand side * 1.15, 0, apex.z + 1.1)`.

The player moves to that fixed destination before the bounce and waits there throughout the bounce, holding the stance after a return until the next wall rebound supplies a new destination. The racket is raised to the predicted peak height; neither the feet nor the racket chase the ball's changing depth. The ground marker shows the predicted strike point. `WallRally.paddle_position()` is the shared contact geometry. `can_return()` still checks timing and the racket's 0.42-foot contact radius, so a tap returns the ball as it passes the prepared racket near the apex. A slightly early tap can use the existing 0.18s buffer. Body contact cannot substitute for racket contact.

The held serve ball starts on the racket. A return preserves the current ball position and launches its outgoing arc from that exact point. `last_contact_pos` and `contact_age` drive a 0.28s follow-through that begins with the rendered racket face at the real contact, then blends back to the ready pose. The striking arm, hand, free arm and swing rotation all mirror with handedness. Visual synchronization uses the same `player_pos` and racket coordinates as the simulation.

## Input and lifecycle

Screen touch press, court click, the bottom pad, Space and Enter share one tap action. Drags and double-click distinctions do not aim or select shots. Touch release never swings. The first active finger owns touch input until release. Touch-generated mouse events are suppressed for 600ms in both the world and HUD. Pause uses a separate button or P/Escape. A tap while paused resumes without serving or returning. Focus loss pauses active play and clears a buffered swing. Best is saved to `user://wall_practice.cfg` on miss, pause/focus loss and exit; failed writes do not interrupt play.

## Portrait layout

The reference viewport is 432x864 with `canvas_items` stretch and `keep` aspect, native portrait orientation, and a fixed KEEP_WIDTH camera. Wider/landscape windows retain a tall centered play area. The footer/pad stays inside a bottom margin; the header is inset from the top. The Web shell disables scrolling, selection and browser touch gestures. Browser orientation locking is not assumed: the scene preserves the portrait framing when a browser rotates.

## Validation

```bash
export PATH="$HOME/.local/bin:$PATH"
export GODOT="$HOME/.local/bin/godot"
godot --headless --path . --import
godot --headless --path . -s res://scripts/check_slice.gd
godot --headless --path . --fixed-fps 60 --quit-after 7200 -- --auto-rally
./scripts/export_web.sh
python3 -m http.server 8080 --directory build/web
```

For Web testing, use a touch-enabled portrait viewport (including 320px and 390px widths). Verify serve on the court and pad, timed returns, second-bounce/retry, pause/resume without a swing, multitouch/synthetic mouse suppression, portrait framing after rotation, and a clean browser console. Native --headless uses the dummy renderer; browser tests cover actual WebGL rendering. No deployment is required for local validation.

## Web deployment and cache updates

`export_web.sh` cleans its output directory, exports and verifies the raw Godot build, then runs `fingerprint_web.py`. A SHA-256 digest of the output, update code and CI revision identifies the release. `index.html` remains the entry point; every `index.*` asset is renamed to `game-<build>.*`, including the engine, pack, WASM, icons and audio worklets. Both the HTML references and Godot's executable/file-size configuration are updated together. `version.json` records the build and, in CI, `GITHUB_SHA`.

The inline updater from `web_update.js` fetches a uniquely queried `version.json` with `cache: no-store` before the engine starts. A stale page navigates to `?build=<latest>` so an old entry HTML cache is bypassed too. It repeats the check on visible-tab and back/forward-cache restoration, with a 3s timeout and no reload loop for a temporarily mixed CDN release. It never clears IndexedDB, local storage or unrelated caches. GitHub Pages response headers cannot be configured here, and a build cannot remotely delete a browser's HTTP cache: changing asset URLs is the cache invalidation mechanism.

Run `python3 -m unittest discover -s scripts -p 'test_web_export.py'` for the export checks. CI runs them after generating the actual Web build. Browser validation should simulate long-lived cached HTML/assets, publish a second release, and verify the new version/PCK/WASM are requested while the saved personal best survives.
