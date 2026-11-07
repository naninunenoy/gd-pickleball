# Wall practice implementation

`docs/rules.md` is the player-facing source of truth. All in-game strings stay English and use the embedded Inter font.

## Architecture

- `wall_rally.gd`: deterministic practice state and analytic ball trajectories, independent of display/input. READY -> OUTBOUND -> RETURNING -> BOUNCED -> OUTBOUND on a legal tap, or MISSED on a second ground bounce.
- `main.gd`: input, pause/focus lifecycle, local best persistence, auto-rally diagnostics, scene synchronization.
- `athlete.gd`: automatically moving athletes with separate identities, selection rings and paddle swings.
- `ball.gd`: bright ball, ground shadow, short trail and contact marker.
- `court_3d.gd`: half court and solid wall; there is no net or opposing CPU.
- `camera_rig.gd`: stable portrait camera showing the full wall, bounce zone and player.
- `play_hud.gd`: rally/best counters, timing and gesture cues, build identifier; every control ignores pointer input.
- `check_slice.gd`: deterministic rules and full-scene input/lifecycle regression checks, including mode persistence and receiver handoff.

Coordinates are feet, X across a 12-foot practice lane, Y up, Z away from the wall at Z=0. The wall returns the ball along the shot's course within the lane. An outbound arc hits the wall at height 3.4 by default (2.0–4.8 with vertical aiming), then returns to a ground bounce at Z=13.6. The next bounce would be at Z=23. Contact between 16% and 84% of that bounce arc sends the ball back only when the racket can reach it. Short taps hit on release, with a 0.35s early-tap buffer. Optional POWER releases retain their selected power until this ball reaches the assisted contact area or the shot is canceled by a second bounce, pause, or new input. Both buffers expire and are consumed by one return. Each return counts once; serving counts zero. Rally progression gradually shrinks flight times to a 72% floor, with optional held-shot speed applied separately. Integration uses small steps and preserves segment overshoot so slow frames do not skip entire input windows.

## Dominant hand and contact

`main.gd` exports an internal `dominant_hand` setting, defaulting to `WallRally.Hand.RIGHT`. Set it to `WallRally.Hand.LEFT` in a scene or before adding the main node to the tree to mirror the player. No handedness selector is exposed in the game HUD. The chosen hand survives retries.

The racket center is 1.15 feet to the dominant side and 1.1 feet ahead of the player's feet. On wall rebound, `trajectory_apex()` predicts the highest point of the upcoming first-bounce arc. For this symmetric arc it is `(target_x, 2.65, 18.3)`. The calculation also handles different start/end heights and linear paths. `movement_target()` offsets that point by the dominant hand and forward racket reach, putting the feet at `(apex.x - hand side * 1.15, 0, apex.z + 1.1)`.

The player moves to that fixed destination before the bounce and waits there throughout the bounce, holding the stance after a return until the next wall rebound supplies a new destination. The racket is raised to the predicted peak height; neither the feet nor the racket chase the ball's changing depth. The ground marker shows the predicted strike point. `WallRally.paddle_position()` is the shared contact geometry. `can_return()` uses the normal shot's 0.42-foot radius on ascent and retains its 0.35s early-tap buffer. At and after the apex, both normal and POWER inputs use 3.0 feet of arm/racket reach from the prepared pose while retaining the 0.42-foot lateral tolerance. The phase window closes at 84% of the bounce arc; physical reach usually closes earlier. Feet keep their predicted apex destination, and the rendered racket extends to the actual contact point on a successful strike. Both strike from the real ball position; body contact cannot substitute for racket contact.

The held serve ball starts on the racket. A return preserves the current ball position and launches its outgoing arc from that exact point. `last_contact_pos` and `contact_age` drive a 0.28s follow-through that begins with the rendered racket face at the real contact, then blends back to the ready pose. The striking arm, hand, free arm and swing rotation all mirror with handedness. Visual synchronization uses the same `player_pos` and racket coordinates as the simulation.

## Two-player prediction and ownership

`WallRally` stores two independent foot positions and paddle heights; `player_pos` and `paddle_height` address the active receiver for existing input/contact APIs. `set_player_count(1|2)` resets the rally while retaining best and handedness. Both athletes use the internal handedness setting. Solo movement timing and straight shots retain their existing behavior.

In pair mode, `_launch()` predicts the outbound wall impact, lateral reflection and next post-bounce apex immediately after a successful strike. It compares each athlete's distance to the feet position offset for the racket, divided by `MOVE_SPEED`, and selects the shortest arrival time. A tie keeps the current athlete. The wall rebound confirms the same prediction without selecting again. Neither charging, releasing early nor a frame update changes the receiver; only the next successful shot or a mode reset may do so. The selected athlete moves to the fixed receiving stance; the other moves to their home racket lane (X=3 or 9, with feet offset for the striking hand) at Z=21.4, behind the receiving lane.

`last_hitter` is separate from `active_player`. `Athlete.sync_practice(..., player_index)` renders its own foot position and racket and uses contact follow-through only for `last_hitter`, preventing a switched receiver from inheriting the previous athlete's swing. P1 is cream, P2 is blue, both have ID labels, and only the active receiver shows a foot ring. `main.gd` creates/removes the second athlete when changing mode.

The mode selector is available in READY, MISSED and pause, disappears while charging or playing, and does not launch a ball. Changing mode cancels controller ownership and queued shots, restarts READY, and saves `practice.players` alongside the shared `practice.best` in the existing config. Config writes preserve the highest stored best. `save_path` can isolate full-scene persistence checks from the real player profile.

## Input and lifecycle

During a rally the whole viewport accepts one gesture, including the header and footer. There are no shot or player-switch controls. HUD labels have `MOUSE_FILTER_IGNORE`. The sole mode selector accepts input only in READY, MISSED or paused states and emits `player_count_requested`; touch and synthetic mouse cannot activate it twice. Touch, left mouse and Space/Enter all call `press()` on down without checking racket range or hitting. On release, `main.gd` uses wall-clock elapsed time: below `MIN_POWER_HOLD` (0.2s), cancel charging and call normal `tap()`; otherwise call `release(elapsed)`. The branches are exclusive. Normal taps retain their 0.35s early buffer and 0.42-foot ascending contact radius; descending taps use the shared arm/racket reach. `can_tap()` gives an early HUD cue.

Touch and mouse gestures record the initial viewport position and the owning pointer's current/release position. Movement under 14 reference pixels is ignored; otherwise the normalized displacement becomes the shot aim. Reference viewport coordinates make the deadzone scale consistently across phones. Keyboard-only shots pass zero aim. `PlayHud` draws a noninteractive arrow during an active swipe and clears it on release or cancellation. Secondary pointers cannot change aim.

`tap(aim)` and `release(elapsed, aim)` carry direction alongside power through immediate and buffered contact. `_launch()` records `shot_aim`: horizontal input offsets the wall target by up to 4.5 feet from the actual contact, clamped to X=2..10; screen-up raises wall impact height by up to 1.4 feet from the 3.4-foot default, while screen-down lowers it. Diagonals combine the normalized components. Every shot still travels toward the wall. Wall rebounds preserve the outgoing lateral slope, with their bounce target clamped to the lane. Their post-bounce apex and automatic footwork use that new target. Zero aim sends the ball straight out and back along its contact X coordinate. Return and wall-hit counters do not choose shot direction. Aim never teleports the ball, changes hold timing, or causes an extra hit; cancellation clears queued aim with queued power.

Strong releases use 1.8 feet of reach on ascent and the same 3.0-foot descending reach as normal taps, with the original 0.42-foot lateral tolerance. `_can_reach()` is shared by normal contact, strong contact and pending-shot consumption so their contact rules agree with the HUD cue during descent. A pending strong shot preserves its selected speed and assisted reach until contact or cancellation. An early strong release has no timeout within the current ball. The ball is never rewound or teleported: the strike and arm animation begin at the current ball position. The HUD shows "Waiting for the ball." after an early release and displays the orange power meter once a hold reaches 0.2s. Power caps at 0.75s, mapping from 1.0x to 1.6x speed. Outbound, wall return and bounce durations are divided by that speed; geometry and predicted apex stay unchanged.

The first finger/mouse button/key owns the gesture. The main node catches release globally, including after dragging across the screen. Secondary fingers, synthetic mouse events for 600ms after touch, repeated key events and duplicate releases cannot create extra shots. A canceled touch, pause, focus loss, reset or second bounce cancels held input and queued shots. A release after a canceled/missed hold cannot restart play, even if it would classify as a short tap. A fresh press while paused only resumes; its release does not swing. P/Escape retains desktop pause; leaving the app/tab pauses active play. Best is saved to `user://wall_practice.cfg` on miss, pause/focus loss and exit; failed writes do not interrupt play.

`RallyBall` pools a contact flash, expanding ring and six sparks, driven by the simulation's `last_contact_pos`, `contact_age` and shot power. They appear for 0.30s after a successful serve/return, strengthen with power, pause with the simulation, and never trigger for a failed input. No per-strike particle nodes or materials are allocated.

## Portrait layout

The reference viewport is 432x864 with `canvas_items` stretch and `keep` aspect, native portrait orientation, and a fixed KEEP_WIDTH camera. Wider/landscape windows retain a tall centered play area. The footer stays inside a bottom margin; the header is inset from the top. The Web shell disables scrolling, selection and browser touch gestures. Browser orientation locking is not assumed: the scene preserves the portrait framing when a browser rotates.

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

For Web testing, use a touch-enabled portrait viewport (including 320px and 390px widths). Verify short-tap shots on release across the header, court and footer, early-tap assistance, short taps begun and released during descent, ordinary and strong contacts throughout reachable descent for either hand and speed, holding through the normal contact window without firing, strong release and impact burst, second-bounce/retry, pause/focus cancellation, left/right/up/down swipes for short and held shots, direction retained through buffered contact, dragging before release, multitouch/synthetic mouse suppression, portrait framing after rotation, and a clean browser console. Native --headless uses the dummy renderer; browser tests cover actual WebGL rendering. No deployment is required for local validation.

## Web deployment and cache updates

`export_web.sh` cleans its output directory, exports and verifies the raw Godot build, then runs `fingerprint_web.py`. A SHA-256 digest of the output, update code and CI revision identifies the release. `index.html` remains the entry point; every `index.*` asset is renamed to `game-<build>.*`, including the engine, pack, WASM, icons and audio worklets. Both the HTML references and Godot's executable/file-size configuration are updated together. `version.json` records the build and, in CI, `GITHUB_SHA`.

Before exporting, the script generates ignored `build_info.json` with a visible `display_id`: `GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT` in CI, `APP_BUILD_ID` or `LOCAL` for local Web exports. The export preset explicitly includes this file in the PCK. The HUD reads it once from `res://build_info.json` and permanently displays `BUILD <display_id>` at the bottom, including while paused. It does not read the latest remote manifest to label the running game. This makes a stale PCK distinguishable from a current build. The same ID is recorded in `version.json` and the HTML's `game-display-build` meta tag. Without generated metadata the native development HUD shows `BUILD DEV`.

The inline updater from `web_update.js` fetches a uniquely queried `version.json` with `cache: no-store` before the engine starts. A stale page navigates to `?build=<latest>` so an old entry HTML cache is bypassed too. It repeats the check on visible-tab and back/forward-cache restoration, with a 3s timeout and no reload loop for a temporarily mixed CDN release. It never clears IndexedDB, local storage or unrelated caches. GitHub Pages response headers cannot be configured here, and a build cannot remotely delete a browser's HTTP cache: changing asset URLs is the cache invalidation mechanism.

Run `python3 -m unittest discover -s scripts -p 'test_web_export.py'` for the export checks. CI runs them after generating the actual Web build. Browser validation should simulate long-lived cached HTML/assets, publish a second release, and verify the new version/PCK/WASM are requested while the saved personal best survives.
