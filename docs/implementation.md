# Implementation and validation

## Runtime

Godot 4.7.2, Compatibility/WebGL 2, portrait reference viewport 432x864. `scenes/main.tscn` instantiates the fixed court, four-athlete layout, ball and HUD.

- `volley_rally.gd` is the live model for both drills. `ground_mode` replaces the former wall drill with bounced opponent rallies; the other profile exchanges volleys and dinks.
- `wall_rally.gd` supplies shared state, geometry constants, handedness and analytic-segment helpers. Its legacy wall trajectory is no longer instantiated by `main.gd`.
- `main.gd` handles gestures, profile/formation changes, persistence and visible athletes.
- `court_3d.gd` builds the floor, boundaries, kitchen markings and net. It contains no wall geometry.
- `camera_rig.gd` always applies the former wall overview: position (6,16,34.5), target (6,1,12), horizontal FOV 46. There is no first-person hand or camera tracking.
- `athlete.gd`, `ball.gd` and `play_hud.gd` render actual racket contacts, bounce targets and controls.

## Teams and formation

Near indices are 0..player_count-1; the two opponents are player_count and player_count+1. A one-athlete near team uses center lane X=6, while pairs and both opponents use racket homes X=3/9. Dominant-hand offsets are 1.15 feet sideways and 1.1 feet forward, mirrored on the far side.

The near team's selected home depth is Z=19.4 for kitchen or Z=22 for baseline. `_team_z` moves toward the current formation target at 16 ft/s and is assigned to every near athlete, so horizontal movement cannot desynchronize forward/backward motion. A kitchen-side dink pickup temporarily advances the whole team to Z=16; outgoing shots recover toward the chosen home line. Far athletes independently approach their selected contact or recover home (Z=1 for RALLY, Z=3.6 for VOLLEY).

`set_court_line()` changes a target without mutating phase, ball, score or pending aim. Idle models also advance their formation, and a READY serve starts from actual current feet rather than resetting a move in progress. Both profiles expose the same always-available thumb button near the bottom; GUI input is consumed so a formation change cannot become a hit. During an owned shot gesture the formation button is disabled. Secondary/synthetic mouse input is suppressed after touch.

Incoming course selects the near receiver and outgoing course selects one of two opponents. Center balls are shared with the partner. Lateral targets permit at most 0.5 feet of overlap into the other half. CPU returns crosscourt; return count never chooses a course.

## Flight and contact

Positions use feet, with net Z=11.5 and height 2.85. Analytic arcs retain 0.25 feet of net clearance. Normal velocity uses 65% of the historical wall outbound reference (~15.8 ft/s), with per-return duration reduction 0.003 and a 0.9 floor. Overshoot is retained through 1/120-second integration steps.

RALLY outgoing deep shots land at far Z=5.4 and rise to the actual CPU racket at height 2.65. The CPU returns to near Z=17.6, then BOUNCED runs toward Z=23 with a 2.65-foot peak. Both sides must collect the bounce. VOLLEY preserves its high unbounced trajectory, with incoming endpoint at the currently selected home depth. Unbounced contact requires feet outside the kitchen.

Swipe displacement / 120 reference pixels retains magnitude after the 14-pixel deadzone. Magnitudes below 0.65 choose a dink, with a blue preview; longer swipes choose a deep stroke. Gesture duration never adds power. Dinks land 2.2 feet beyond the net, then rise to a contact 3.4 feet beyond it at height 1.9. The near bounce lasts 0.84 seconds and a pickup opens after 0.08 seconds. RALLY bounce duration is 1.15 seconds. Both are legal inside the kitchen after bouncing. Early input queues through the bounce and is consumed once at actual contact. A second bounce enters MISSED and cancels stale input.

## Persistence and UI

The historical `user://wall_practice.cfg` and `practice.game=wall|volley` identifiers are retained for existing records. Product UI calls the profiles RALLY and VOLLEY. `practice.players` / `volley.players` default to 2; `practice.front` defaults false and `volley.front` true. Counts, formations and personal bests are stored independently per profile. One-player practice still has two opponents.

All four athletes are visible from the overview. Score/instructions sit above the court; the gesture hint, large line switch and build number sit below the action. Header drill/team selectors appear in idle/missed/pause states. Court taps and swipes occupy the rest of the viewport.

## Verification

Run `godot --headless --path . -s res://scripts/check_slice.gd`. The suite exercises both drills, both line choices, both striking hands, one/two near athletes against two CPUs, net clearance, actual racket contacts, bounce legality, live synchronized formation changes, queued inputs, button hit isolation, constant camera transform and saved preferences. Full-scene checks use isolated temporary save paths.

Web checks use touch-enabled Chromium at 390x844 and 320x568. Verify all four athletes and net, no wall, both profiles sharing the overview, thumb-button changes during a rally, no accidental serve, continued normal returns, and a clean console. Export checks run with `python3 -m unittest discover -s scripts -p 'test_web_export.py'`.

## Web deployment

Pushes to main run the Godot checks, single-threaded Web export, release-version checks and GitHub Pages deployment. Asset filenames are fingerprinted per release. A no-store `version.json` check reloads stale entry pages while retaining local records. The visible BUILD number is embedded in the loaded pack as the Actions run/attempt. Local previews set `APP_BUILD_ID` explicitly.
