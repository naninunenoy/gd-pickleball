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

Coordinates are feet, X across a 12-foot practice lane, Y up, Z away from the wall at Z=0. Player feet stay at Z=18.8 and automatically track the rebound X. The wall varies its rebound within the lane. An outbound arc hits the wall at height 3.4, then returns to a ground bounce at Z=13.6. The next bounce would be at Z=23. A legal tap between 16% and 76% of that bounce arc sends the ball back. A 0.18s buffer accepts a slightly early tap; it expires normally and is consumed by a return. Each return counts once; serving counts zero. Flight times gradually shrink to a 72% floor. Integration uses small steps and preserves segment overshoot so slow frames do not skip entire input windows.

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
