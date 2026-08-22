# Pickleball doubles (vertical slice) rules

Player-facing rules only. Implementation internals live in `docs/implementation.md`.

This version is not a full game. It repeats serve-to-rally points. First to 11 wins.

## Controls

You control both players on the bottom court at once. You do not walk a character directly.

| Input | Meaning |
|---|---|
| WASD / left stick | Aim where a **return** will land |
| Face buttons / IJKL | Choose the shot **and** hit |

NESW is the face-button cluster (how you hit), not the D-pad.

| Direction | Shot | Gamepad | PlayStation | Keyboard |
|---|---|---|---|---|
| North | Drive | Y | Triangle | **I** (also Up) |
| South | Drop / dink | A | Cross | **K** (also Down) |
| West | Smash | X | Square | **J** (also Left) |
| East | Volley | B | Circle | **L** (also Right) |

Keyboard: WASD is the left hand (aim), IJKL is the right hand (face buttons). That is the usual twin-stick layout. Arrow keys are extra aliases. **Space pauses** (Start on a gamepad).

You must press a shot button to hit. If you never press, the ball bounces twice and you lose the point. CPU still returns on its own.

## Two-player movement

- Movement to the ball is automatic
- The closer player is the one who can hit
- The partner covers the open half
- Both stay back until serve and return are done
- After that, the off-ball player moves up to the kitchen line

Hitter toggle and changing ends are not in this slice. Left stays left, right stays right.

## Match

- Every rally is worth 1 point
- First to 11 wins. No win-by-2
- You serve first
- The team that won the point serves next
- Even score: serve from the right. Odd score: serve from the left
- Teams do not switch ends

## Serve

- You do not aim the serve
- There is no service fault
- Press any shot button. The ball always lands deep in the legal diagonal box
- Drive and drop only change the arc. Volley and smash become a drive
- The receiver must let it bounce, then press a shot to return

## Double bounce

These two shots cannot be taken out of the air:

1. Serve
2. Return

From the third shot, volleys are legal outside the kitchen. Press East / B / L while the ball is in the air.

## Kitchen (NVZ)

- There is a 7-foot kitchen on each side of the net
- A volley in that area (including the line) is a fault
- Entering after a bounce to hit is legal
- Landing a dink in the kitchen is legal

## Shots

WASD still aims the landing. The face button is how it gets there:

- **Drive**: basic fast ball
- **Drop / dink**: slow arc. Drop from the back, dink at the NVZ
- **Volley**: cut it out of the air. Not on serve or return. Not in the kitchen
- **Smash**: put away a high ball. Too low becomes a drive

The reticle can go out of court on returns. Aiming out makes an out. The serve reticle is hidden.

## When a point ends

One of these awards a point:

- Ball lands out (returns only)
- Ball does not clear the net (returns only)
- Kitchen volley
- You do not press in time, second bounce

The opponent only returns. It aims near center and does not read you.

## Not in this slice

- Timing that changes shot quality (early / late grading)
- Toggle who hits
- Side change, side-out scoring, win-by-2, two-server rotation
- Lobs, fakes, spin
- Opponent poaching or hunting gaps
