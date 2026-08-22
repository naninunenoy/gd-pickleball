# Implementation notes

`docs/rules.md` is the player-facing source of truth. If behavior changes, update `rules.md` first, then match the code. This file is internals and a list of things not to add yet.

All in-game strings must stay English. Godot's default font does not cover Japanese.

## What this slice must prove

- Both partners are controlled as a team. WASD aims the landing, it does not move a player
- NESW is shot type. Contact is automatic
- Closest player hits. Partner covers the open half
- Double bounce and NVZ volley faults are in from the start
- Opponent AI only returns
- Rally scoring, first to 11

## Layout

```
docs/rules.md              player-facing rules
docs/implementation.md     this note
scripts/court_map.gd       feet to pixels
scripts/match_rules.gd     court geometry and legality, view-independent
scripts/shot_catalog.gd    shot parameters
scripts/athlete.gd         one player; court_pos is feet
scripts/ball.gd            landing-based flight, no physics engine
scripts/court_view.gd      court draw
scripts/reticle.gd         aim reticle
scripts/main.gd            match flow, input, AI, scoring
scripts/check_slice.gd     headless sanity checks
scenes/main.tscn           entry
```

New shots or rules belong in `match_rules.gd` / `shot_catalog.gd`. Do not pile magic numbers into `main.gd`.

## Coordinates

Units are feet. Pixels are for drawing only.

- `x = 0` left sideline, `x = 20` right sideline
- `y = 0` top (CPU) baseline, `y = 44` bottom (player) baseline
- Net `y = 22`
- CPU NVZ: `y = 15 .. 22`
- Player NVZ: `y = 22 .. 29`
- Service boxes run 15 ft from baseline to NVZ line, 10 ft wide
- Lines are in. Do not use `Rect2.has_point`; the far edge is half-open

The player team is always south (bottom of the screen). Side change is not implemented. Do not swap ends.

CPU "right" is screen left (`x < 10`). Even/odd server side uses that team's own score.

```
Human even: screen-right serves, target = north-left box
Human odd:  screen-left serves, target = north-right box
CPU even:   CPU right = screen left serves, target = south-right box
CPU odd:    CPU left = screen right serves, target = south-left box
```

## State

`main.gd` `Phase`:

1. `SERVE_AIM` — aim with the reticle. Human serves with Space. CPU serves after a short wait
2. `IN_FLIGHT` — flight or first bounce. Contact starts the next shot
3. `POINT_END` — show the reason for about 1.4s
4. `MATCH_END` — 11 points. Space rematches

`hits_completed` is the number of legal outbound hits.

- Shot 1 (serve) and shot 2 (return) cannot be volleyed
- Incoming balls with `hits_completed >= 3` can be volleyed

If volley is selected during the double-bounce window, do not take it in the air; wait for the bounce. A kitchen volley is a fault only when volleys are otherwise legal and contact happens in the air in the NVZ.

## Input

Actions are registered in `main.gd` `_ensure_actions()`. Do not depend on the `project.godot` Input Map.

| action | role |
|---|---|
| `aim_*` | reticle. Do not use this to move athletes |
| `shot_north/south/east/west` | armed shot, sticky |
| `confirm` | serve and rematch only |

`toggle_hitter` is reserved and ignored. Do not add a timing window.

Default shot is drive. `VOLLEY` after a bounce becomes a drive (punch). `SMASH` without height becomes a drive.

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
- Do not volley. Wait for the bounce
- Do not poach, hunt gaps, or vary pace on purpose

## HUD

Required:

- Court and NVZ
- Four players, hitter ring
- Ball, shadow, predicted land
- Reticle (green in, red out)
- Score and constraint (let it bounce / volley OK / NVZ)
- Shot labels

## Add later / do not add now

OK in a later slice:

- Hitter toggle (`toggle_hitter`)
- A light timing window
- Side change, side-out, win-by-2
- Lob
- Slight opponent aim variation

Do not add now:

- WASD moving athletes
- Shot buttons choosing the landing
- Physics-engine ball flight
- Official two-server rotation halfway
- Character stats, stamina, gauges

## Checks

```bash
godot --headless --path . -s res://scripts/check_slice.gd
godot --headless --path . --quit-after 720 -- --auto-rally
```

Web export is still `./scripts/export_web.sh`.
