# Pickleball doubles (vertical slice) rules

Player-facing rules only. Implementation internals live in `docs/implementation.md`.

This version is not a full game. It repeats serve-to-rally points. First to 11 wins.

## Controls

You control both players on the bottom court at once. You do not walk a character directly.

| Input | Meaning |
|---|---|
| WASD / D-pad / left stick | Choose a target **zone** on the opponent court |
| Z / gamepad A | Soft hit (slow, high) |
| X / gamepad B | Hard hit (fast, low) |
| Space / Start | Pause |

The opponent court is split into 6 zones: left/right by deep, mid, and kitchen.

```
W  deeper (toward their baseline)
S  shorter (toward the net)
A  left
D  right
```

| | Left | Right |
|---|---|---|
| Deep | W+A | W+D |
| Mid | A | D |
| Kitchen | S+A | S+D |

Press Z or X to hit into the highlighted zone. If you never press, the ball bounces twice and you lose the point. CPU still returns on its own.

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
- Press Z or X. The ball always lands deep in the legal diagonal box
- Soft/hard only changes the arc
- The receiver must let it bounce, then press Z or X to return

## Double bounce

These two shots cannot be taken out of the air:

1. Serve
2. Return

From the third shot, Z or X in the air is a volley if you are outside the kitchen. Soft is a soft volley. Hard is a punch or smash.

## Kitchen (NVZ)

- There is a 7-foot kitchen on each side of the net
- A volley in that area (including the line) is a fault
- Entering after a bounce to hit is legal
- Landing a soft ball in the kitchen is legal

## Shots

Only two paces:

- **Soft (Z)**: slow and high. Use this to drop or dink
- **Hard (X)**: fast and low. Use this to drive. A high ball becomes a smash

WASD picks the zone. Z/X is how hard it gets there.

## When a point ends

One of these awards a point:

- Ball lands out (returns only; zones are in court)
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
