# Pickleball doubles (vertical slice) rules

Player-facing rules only. Implementation internals live in `docs/implementation.md`.

This version is not a full game. It repeats serve-to-rally points. First to 11 wins.

## Controls

You control both players on the bottom court at once. You do not walk a character directly.

| Input | Meaning |
|---|---|
| WASD / left stick | Aim where the ball will land |
| Up | Drive (long, fast, low) |
| Down | Drop / dink (short, slow, arcing) |
| Right | Volley (take it out of the air when legal) |
| Left | Smash (high balls only; otherwise becomes a drive) |
| Space / Enter / gamepad A | Serve. After the match, rematch |

NESW is how you hit, not where. Aim is on the movement keys.

The last chosen shot stays selected. Default is drive. On contact, that shot flies toward the reticle. There is no timing window.

## Two-player movement

- Movement to the ball is automatic
- The closer player takes the ball
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

- Aim the diagonal service box
- Reticle outside the box is a fault
- Net or out is a fault
- The receiver must let it bounce

## Double bounce

These two shots cannot be taken out of the air:

1. Serve
2. Return

From the third shot, volleys are legal outside the kitchen. If a volley is not legal, the hitter waits for the bounce and then hits automatically.

## Kitchen (NVZ)

- There is a 7-foot kitchen on each side of the net
- A volley in that area (including the line) is a fault
- Entering after a bounce to hit is legal
- Landing a dink in the kitchen is legal

## Shots

The same landing point still plays differently by shot:

- **Drive**: basic fast ball
- **Drop / dink**: slow arc. Drop from the back, dink at the NVZ
- **Volley**: cut it out of the air. Not on serve or return. Not in the kitchen
- **Smash**: put away a high ball. Too low becomes a drive

The reticle can go out of court. Aiming out makes an out.

## When a point ends

One of these awards a point:

- Ball lands out
- Ball does not clear the net
- Serve misses the diagonal box
- Kitchen volley
- Defense cannot reach, second bounce

The opponent only returns. It aims near center and does not read you. Safe center shots keep the rally going. Winners come from open space or from aiming out.

## Not in this slice

- Timing that changes shot quality
- Toggle who hits
- Side change, side-out scoring, win-by-2, two-server rotation
- Lobs, fakes, spin
- Opponent poaching or hunting gaps
