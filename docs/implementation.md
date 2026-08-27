# Implementation notes

`docs/rules.md` is the player-facing source of truth. If behavior changes, update `rules.md` first, then match the code. This file is internals and a list of things not to add yet.

All in-game strings must stay English. The project embeds `fonts/Inter-Regular.ttf` so Web/WASM labels are not tofu boxes.

## What this slice must prove

- Overhead 2D is gone. One 3D TPS (the kitchen view); only the camera pose changes
- Away from the line the same camera pulls back and up so the kitchen is ahead. On the line it moves in and reads ball height against the net
- Arriving and stopping settles the camera. Running keeps a small shake
- Both partners are controlled as a team. Mouse or a finger aims a free landing on the opponent court. It does not move a player
- Click is soft, double-click is hard. On a phone, Soft / Hard buttons are the swing. Those two paces are the only swings. Human contact is not automatic
- Serves are not aimed. They always land at `MatchRules.serve_land_point`. No service fault
- Closest player is the hitter. Partner covers the open half
- If a volley is legal and the ball is on the defender's side outside the NVZ, run to the airborne ball and hit it in the air. Do not wait for a bounce
- Double bounce and NVZ volley faults are in from the start
- Opponent AI only returns, and still auto-hits (including legal volleys)
- Rally scoring, first to 11

## Layout

```
docs/rules.md              player-facing rules
docs/implementation.md     this note
scripts/court_map.gd       court feet to world (X, height Y, court-y Z)
scripts/match_rules.gd     court geometry and legality, view-independent
scripts/shot_catalog.gd    shot parameters
scripts/kitchen_occupancy.gd  on-line / set / team kitchen labels
scripts/camera_rig.gd      baseline vs kitchen TPS
scripts/athlete.gd         one player; court_pos is feet
scripts/ball.gd            landing-based flight, no physics engine
scripts/court_3d.gd        3D court, net, kitchen-line emphasis
scripts/reticle.gd         aim reticle on the ground
scripts/minimap.gd         partner / kitchen overlay; drag to aim
scripts/play_hud.gd        Soft / Hard / Pause buttons
scripts/main.gd            match flow, input, AI, scoring
scripts/check_slice.gd     headless sanity checks
scenes/main.tscn           entry
```

New shots or rules belong in `match_rules.gd` / `shot_catalog.gd`. Do not pile magic numbers into `main.gd`.

## Coordinates

Units are feet. The 3D world is 1:1 with court feet. `CourtMap.to_world` maps court `(x, y)` to `Vector3(x, height, y)`.

- `x = 0` left sideline, `x = 20` right sideline
- `y = 0` north (CPU) baseline, `y = 44` south (player) baseline
- Net `y = 22`
- CPU NVZ: `y = 15 .. 22`
- Player NVZ: `y = 22 .. 29`
- Service boxes run 15 ft from baseline to NVZ line, 10 ft wide
- Lines are in. Do not use `Rect2.has_point`; the far edge is half-open

The player team is always south. Side change is not implemented. Do not swap ends.

Mouse aim is a camera ray onto the ground plane `Y = 0`, then clamped to the north side of the net. A finger drag uses the same ray. Dragging the mini-map writes court coordinates directly.

CPU "right" is screen left (`x < 10`). Even/odd server side uses that team's own score.

```
Human even: screen-right serves, target = north-left box
Human odd:  screen-left serves, target = north-right box
CPU even:   CPU right = screen left serves, target = south-right box
CPU odd:    CPU left = screen right serves, target = south-left box
```

## State

`main.gd` `Phase`:

1. `SERVE_AIM` — reticle hidden on your serve. Human click/double-click or Soft / Hard; CPU waits, then serves to `serve_land_point`
2. `IN_FLIGHT` — flight or first bounce. Human must swing while in range. CPU auto-returns. Legal volleys are taken in the air
3. `POINT_END` — show the reason for about 1.4s
4. `MATCH_END` — 11 points. A click or tap rematches

`hits_completed` is the number of legal outbound hits.

- Shot 1 (serve) and shot 2 (return) cannot be volleyed
- Incoming balls with `hits_completed >= 3` can be volleyed

If a volley is not legal yet, ignore in-air clicks and wait for the bounce. A kitchen volley is a fault only when volleys are otherwise legal and contact happens in the air in the NVZ.

## Input

Actions are registered in `main.gd` `_ensure_actions()`. Do not depend on the `project.godot` Input Map.

| action | role |
|---|---|
| mouse left | First click arms Soft and waits 0.2s for a possible double-click. `event.double_click` upgrades to Hard immediately. Also starts a serve. Ignored for 0.5s after a touch so a phone's synthetic click does not swing |
| finger drag | Same ground ray as the mouse. Does not swing. Hidden during your serve |
| mini-map drag | Maps widget coordinates onto the court, then `CourtMap.clamp_aim` |
| Soft / Hard HUD | Immediate pace. Also starts a serve. Used on phones; also works with a mouse |
| Pause HUD | Toggles pause. Space / Start still work |
| `shot_soft` | Z / A. Immediate soft. Also starts a serve |
| `shot_hard` | X / B. Immediate hard. Also starts a serve |
| `confirm` | Enter rematch only |
| `pause` | Space / Start. Toggles pause. Does not hit |

`pointing/emulate_mouse_from_touch` is off so a tap on the court is not a left click. HUD buttons still receive `InputEventScreenTouch`.

Mouse court position is a camera ray onto the ground, clamped to the north side of the net, and written to `reticle.court_pos`. Human returns use that point. Out of court is allowed so a miss can go out.

On a tall/narrow viewport the camera uses `KEEP_WIDTH` so the court stays in frame. Compact layouts move Soft / Hard to the bottom and shrink the HUD.

Human hits only while a swing is armed and the hitter is in range. `--auto-rally` presses Hard for the human so headless rallies still run.

`toggle_hitter` and leftover `aim_*` actions are reserved and ignored. Do not add early/late quality windows yet.

Serve uses click/double-click or Soft / Hard only for pace. Landing is always `serve_land_point`. In-air swing after the double bounce is a volley (hard + high = smash). Kitchen volleys still fault.

## Ball

Do not use Jolt / Godot Physics for the ball. `RallyBall` stores start, land, duration, and apex.

```
ground(t) = lerp(start, land, u)
height(t) = lerp(h0, h1, u) + 4 * apex_extra * u * (1 - u)
```

After the first bounce, a short bounce arc runs. Second bounce is a defensive loss. Move speed is capped, so winners can exist.

Net fault: on the frame the path crosses `y = 22`, `height < 3.0`. Aiming to the same side of the net is also a fault.

## Auto movement

- Only the defending hitter runs to the contact point
- Contact is `ball.ground_pos` when a volley is legal, the ball is on the defender's side, and it is not over the NVZ. Otherwise contact is the predicted bounce
- Partner goes home (back or NVZ line)
- Everyone stays back while `hits_completed < 2`
- After that, the off-ball player steps to the NVZ line
- Speed `Athlete.MOVE_SPEED`, reach `Athlete.REACH`
- If distances are nearly equal, prefer the home side (left stays left)

Hitter toggle is the next slice. Closest player only for now.

## Opponent AI

Return only.

- Land near the center of the opponent court (small jitter)
- Drop if standing near the NVZ, otherwise drive
- Volley when it is legal and the hitter is outside the NVZ. Otherwise wait for the bounce
- Do not poach, hunt gaps, or vary pace on purpose

## Camera

`KitchenOccupancy.in_front_view` is the kitchen-camera trigger (on the line or closer to the net on your side). Baseline and transition use the same 3D TPS, pulled back.

`CameraRig.compose(focus, ball, blend)` is view-independent and unit-tested:

- blend 0: same kitchen 3D view, further back and a bit higher, looking at play height toward the kitchen
- blend 1: close over the shoulder, looking at net / ball height

There is no separate 2D renderer for the main view. Shake scales with the focus athlete's speed and drops to zero when they are set on the line. Follow damping is faster when set so arriving is the stable moment.

The focus athlete is the human server/receiver during serve, the human hitter while defending, and the human closer to the net after we hit (so the partner walking up to the line pulls the camera with them).

On a portrait viewport (`height > width`) the camera uses `Camera3D.KEEP_WIDTH` so the court does not become a vertical tunnel.

## HUD

Required:

- 3D court, NVZ, and emphasized kitchen lines
- Four players, hitter / set ring
- Ball, shadow, height stem, predicted land
- Free-aim reticle on the opponent court (hidden during your serve)
- Score and constraint (let it bounce / volley OK / NVZ)
- Kitchen occupancy (you / CPU / rally phase) and which camera is active
- Soft / Hard labels or on-screen buttons
- Minimap for partner spacing (also an aim pad)

## Add later / do not add now

OK in a later slice:

- Hitter toggle (`toggle_hitter`)
- A light timing-quality window (early / late)
- Side change, side-out, win-by-2
- Lob
- Slight opponent aim variation

Do not add now:

- WASD moving athletes
- Physics-engine ball flight
- Official two-server rotation halfway
- Character stats, stamina, gauges

## Checks

```bash
godot --headless --path . -s res://scripts/check_slice.gd
godot --headless --path . --quit-after 720 -- --auto-rally
godot --path . --quit-after 180 -- --camera-preview
```

`--camera-preview` snaps the baseline serve view, then both teams SET at the kitchen line, and writes `/tmp/gd-pickleball-baseline.png` and `/tmp/gd-pickleball-kitchen.png`.

Web export is still `./scripts/export_web.sh`.
