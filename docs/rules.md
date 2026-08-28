# Pickleball doubles (vertical slice) rules

Player-facing rules only. Implementation internals live in `docs/implementation.md`.

This version is not a full game. It repeats serve-to-rally points. First to 11 wins.

## Camera

The game is always the kitchen 3D view. There is no 2D overhead. Away from the kitchen the same camera sits further back and a bit higher so you can see the line you are running to. On the line it moves in and looks across the net.

- Away from the kitchen: pulled back, still third-person 3D
- On the kitchen line: closer and lower, ball height against the net
- While you are still moving the camera is less stable. It settles when you arrive and stop
- A small map in the corner shows both partners and the kitchen lines

## Controls

You control both players on the bottom court at once. You do not walk a character directly.

| Input | Meaning |
|---|---|
| Mouse / drag | Aim where the next return should land on the opponent court |
| Click | Soft hit (slow, high) |
| Double-click | Hard hit (fast, low) |
| Soft / Hard buttons | Same two paces. Use these on a phone |
| Drag the mini-map | Aim by placing the landing on the map |
| Space / Start / Pause | Pause |

Z / gamepad A still hit soft. X / gamepad B still hit hard.

On a phone, drag the 3D view or the mini-map to aim, then tap Soft or Hard. A tap on the court does not swing. Soft / Hard also start a serve.

Move the mouse or finger to place the reticle. The ball goes to that point when you hit. A green reticle is in. A red reticle is out or on your side of the net.

If you never click, the ball bounces twice and you lose the point. CPU still returns on its own.

## Two-player movement

- Movement to the ball is automatic
- The closer player is the one who can hit
- The partner covers the open half
- Both stay back until serve and return are done
- After that, the off-ball player moves up to the kitchen line

If a volley is legal, the hitter runs to the airborne ball and can take it in the air. They do not wait for a bounce.

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
- Click or Soft / Hard. The ball always lands deep in the legal diagonal box
- Soft/hard only changes the arc
- The receiver must let it bounce, then click or tap Soft / Hard to return

## Double bounce

These two shots cannot be taken out of the air:

1. Serve
2. Return

From the third shot, a click in the air is a volley if you are outside the kitchen. Soft is a soft volley. Hard is a punch or smash. If that volley is legal, take it in the air. Do not wait for a bounce.

## Kitchen (NVZ)

- There is a 7-foot kitchen on each side of the net
- A volley in that area (including the line) is a fault
- Entering after a bounce to hit is legal
- Landing a soft ball in the kitchen is legal

## Shots

Only two paces:

- **Soft (click)**: slow and high. Use this to drop or dink
- **Hard (double-click)**: fast and low. Use this to drive. A high ball becomes a smash

The mouse or a finger picks the landing. Click vs double-click, or Soft vs Hard, is how hard it gets there.

## When a point ends

One of these awards a point:

- Ball lands out
- Ball does not clear the net
- Kitchen volley
- You do not click or tap Soft / Hard in time, second bounce

The opponent only returns. It aims near center and does not read you.

## Not in this slice

- Timing that changes shot quality (early / late grading)
- Toggle who hits
- Side change, side-out scoring, win-by-2, two-server rotation
- Lobs, fakes, spin
- Opponent poaching or hunting gaps
