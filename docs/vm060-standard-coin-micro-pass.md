# VM-0.6.0 Final Standard Coin Micro-Pass

Date: 2026-09-07 JST  
Status: implemented and technically validated; pending manual Startup Lab acceptance

## Scope

This checkpoint implements only the final authorized Standard Mode Refund Coin corrections:

1. add decision separation to one authored multi-coin route without changing the overall economy; and
2. prevent a new offer from spawning on or immediately against the player.

It does not begin VM-0.6.0 menu, results, persistence, music, SFX, HUD, or conveyor-visual work. It does not change movement, hazards, D3 cadence, conveyor physics, product behavior, carriage behavior, round duration, coin value, coin art, or the selected 24×24 C-A pickup collider.

## Route topology

Only `SAFE_VERSUS_RISK` changed. Its four authored centres are:

| Coin | Centre | Band | Purpose |
|---|---:|---|---|
| 1 | `(610, 550)` | Ground | accessible start; abandonment remains possible |
| 2 | `(546, 550)` | Ground | simple continuation |
| 3 | `(482, 500)` | Low air | leftward jump commitment |
| 4 | `(578, 474)` | Low air | optional modest rightward redirect/tail |

This does not merely increase spacing along one trajectory. The fourth coin reverses horizontal direction after the leftward jump, creating a continuation/abandon choice. Existing long linear trails and compact jackpot clusters remain so not every offer becomes demanding.

The 120 Hz route-action validator measured:

- no further input: 1 of 4;
- unchanged input: 2 of 4;
- passive jump: 3 of 4;
- intended aggressive input: 4 of 4;
- safe abandonment: 1 of 4.

The route also passes at the maximum configured conveyor speed.

Developer logs classify routes as `LINEAR`, `STAIR_UP`, `STAIR_DOWN`, `ARC`, `STAGGER`, `RISK_TAIL`, or `CLUSTER`. These labels are not player-facing.

## Player spawn exclusion

At offer reservation, every candidate is checked against:

- the actual player collision bounds;
- the existing 24×24 coin placement/pickup footprint; and
- exported `player_spawn_safety_padding = 8.0` px around the player.

If the authored placement conflicts, the director tries a bounded set of existing anchors and derived left/right clearances. Every candidate in the offer receives the same horizontal translation, preserving all sibling offsets and route topology. It never moves only the conflicting sibling and never uses collection lockout.

If no whole-offer placement passes existing bounds, hazard, reachability, sibling, and player-safety checks, the attempt rejects and the existing 0.10-second scheduler retry applies. A delayed staggered sibling that becomes player-blocked retries up to exported `maximum_delayed_coin_spawn_retries = 4`; after the fifth failed attempt, that sibling is skipped and later siblings continue. This prevents an unbounded retry loop and permanent offer starvation.

Instrumentation records attempt count, archetype, player overlap and buffer encounters, alternate placement, whole-route shift, delayed retries, and bounded skips. It contains no raw user content.

## Before/after deterministic economy

The pre-change baseline and final build used seeds 401, 1701, and 4202.

| Seed | Baseline coins/offers | Final coins/offers | First offer | Final multi-coin size counts |
|---:|---:|---:|---:|---|
| 401 | 54 / 22 | 54 / 22 | 1.750 s | 2 coins: 1; 3 coins: 11; 4 coins: 3 |
| 1701 | 55 / 22 | 55 / 22 | 1.750 s | 2 coins: 1; 3 coins: 10; 4 coins: 4 |
| 4202 | 55 / 22 | 55 / 22 | 1.750 s | 2 coins: 1; 3 coins: 10; 4 coins: 4 |

Aggregate final multi-offer archetypes: `ARC 9`, `LINEAR 9`, `STAGGER 10`, `STAIR_DOWN 9`, `CLUSTER 3`, `RISK_TAIL 5`. Template selection counts are unchanged from the recorded baseline.

The neutral economy simulations held the player outside offer geometry, so player-safety encounters were zero. Separate 60-second coin-scheduler audits fixed the player at the common ground offer position `(610, 550)`:

| Seed | Offers | Overlap encounters | Buffer encounters | Alternate offers | Spawn intersections | Delayed skips |
|---:|---:|---:|---:|---:|---:|---:|
| 401 | 22 | 18 | 9 | 8 | 0 | 0 |
| 1701 | 22 | 22 | 11 | 10 | 0 | 0 |
| 4202 | 22 | 22 | 11 | 10 | 0 | 0 |

Encounter counts include rejected alternatives within a placement attempt, so they may exceed the number of relocated offers. The audit intentionally pauses hazard physics to isolate the coin scheduler; it is not a claim that an inactive player survives a real 60-second round.

## Verification

- all 26 automated Godot test scripts passed at 60 Hz;
- exact spawn-frame exclusion and 8 px buffer tests passed;
- whole-route relocation preserved every sibling offset;
- exactly-once scoring and normal subsequent collection passed;
- bounded delayed retry/skip and later-sibling continuation passed;
- Arena, base Conveyor, and selected VIS-04 P-A/C-A each launched headlessly for 180 frames;
- the `Web VIS-04 P-A C-A` single-threaded export completed;
- the local HTTP browser load produced a 1280×720 canvas and no console warnings or errors.

Web review build: `builds/web-vis04-pa-ca/index.html` (generated and ignored by Git).

## Manual acceptance questions

Play at least three natural runs and three coin-greedy runs. For each multi-coin offer, note:

1. After the first coin, did a later coin sometimes require another jump, horizontal redirect, or continue/abandon decision?
2. Did any route still feel like an automatic single pickup line?
3. Did the changed route feel confusing or demand near-perfect movement?
4. Did any coin appear under the player or produce an unexplained score increase?
5. Did offers visibly disappear or pause because the player occupied a common spawn area?
6. Did the overall cadence or score availability feel materially reduced?

Do not infer success from the automated route simulator. Manual acceptance is required before Standard Mode coin gameplay is frozen again and VM-0.6.0 presentation/audio work begins.
