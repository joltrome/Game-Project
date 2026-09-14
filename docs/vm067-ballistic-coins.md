# VM-0.6.7 — Ballistic Refund Coin Prototype

Recorded: 2026-09-14 JST

Control: `release/vm-0.6.6-variable-coin-events` at `7605554e72112f2aa9a4503400c5a93adecb28e9`

Prototype branch: `release/vm-0.6.7-ballistic-coins`

## Experiment boundary

VM-0.6.6 remains the accepted control. VM-0.6.7 changes only how the existing one-point Refund Coins enter, move, bounce, and begin their post-contact lifetime. The 1.10–2.10-second event-attempt interval, 55/35/10 requested 1/2/3-coin weights, five-coin cap, approximately 1.75-second teaching event, collection value, D3 cadence, hazards, player, conveyor, timer, UI, audio, Pause, and mobile controls are unchanged.

The hypothesis is that visible deterministic launches may create more prediction, aerial interception, and recovery decisions than static-spawn coins. Technical completion does not validate that hypothesis.

## Deterministic motion

Every ballistic coin uses an authored launch origin, a selected clear conveyor landing point, a fixed flight duration, a calculated initial velocity, and gravity. Position during first flight is calculated analytically from elapsed time rather than delegated to `RigidBody2D`; identical parameters therefore reproduce the same arc.

The three exported archetypes are:

| Archetype | Launch origin | First-flight duration | Role |
|---|---:|---:|---|
| SHALLOW | `(840, 300)` | 0.72 s | Lower, quicker lateral entry |
| MEDIUM | `(720, 260)` | 0.90 s | Gentle teaching/default trajectory |
| HIGH | `(620, 220)` | 1.10 s | Higher, slower entry |

Horizontal and vertical launch velocities are derived per destination. Singles select one archetype. Doubles select two distinct archetypes. Triples request SHALLOW + MEDIUM + HIGH. A 60 Hz path-separation check rejects siblings that approach within the configured 44 px trajectory distance; no decorative identical fan is created.

The first teaching event uses MEDIUM. Coins retain the existing gold art, spin, 24×24 pickup collider, score and collection audio. They remain non-solid and collectible throughout AIRBORNE, BOUNCING and SETTLED states. Collection resolves once, stops motion/lifetime callbacks, adds one point, and plays the existing Refund Coin SFX once.

## Contact, bounce and expiry

First conveyor contact is deterministic at the planned ground point. It starts, rather than consumes, an independently sampled 2.0–3.0-second post-contact lifetime. The coin performs exactly two analytic vertical bounces while conveyor translation continues left:

- first restitution: 0.38 of incoming vertical speed;
- second restitution: 0.16;
- then SETTLED, with no micro-bounce loop.

The accepted final 0.70-second expiry warning begins only from the post-contact countdown. Its opacity pulse remains 1.5–4 pulses per second and never fully hides the coin. Airborne time never starts the warning. Round end, death, and Retry stop and remove every state.

## Geometry, hazards and world compromise

Landing targets are sampled from the existing player-relative placement bands, then validated against the player spawn exclusion, reachability, active/sibling separation, current landed-can footprint, and D3 priority. The actual launch velocity, not a teleport, connects source to destination. Instrumentation records launch, player crossing, first-landing and settle side relative to the current player.

Ballistic coins intentionally do not participate in full product/can/carriage physics. Their `Area2D` pickup mask continues to detect the player only. A clear conveyor landing region is required at reservation time; if a landed can unexpectedly enters that region during flight, the reward passes through it rather than adding ricochet or emergent collision behavior. This is a bounded prototype compromise and requires visual review.

Hazards remain higher priority than rewards. While D3 is selected, a candidate arc must remain clear of the committed warning/drop lane. While D3 is stored, a coin is admitted only when its complete flight and post-contact opportunity clear before the next reservation. This conservative rule preserved the exact D3 schedule, but materially reduced delivered coin opportunity; see the confound below.

## Deterministic results

These headless 60-second fixtures measure generated opportunities with a stationary non-colliding player; they do not measure collection performance or fun.

| Seed | Events | Selected 1 / 2 / 3 | Delivered coins | SHALLOW / MEDIUM / HIGH | Avg flight | Flight range | Launch B/C/A | Landing B/C/A | Settle B/C/A | Cross-player arcs | Avg post TTL | Max active | Placement failures | D3 gap |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 401 | 35 | 19 / 11 / 5 | 21 | 10 / 7 / 4 | 0.852 s | 0.72–1.10 s | 0 / 4 / 17 | 7 / 2 / 12 | 15 / 5 / 0 | 10 | 2.458 s | 4 | 36 | 8.792 s |
| 1701 | 34 | 19 / 14 / 1 | 20 | 8 / 5 / 7 | 0.898 s | 0.72–1.10 s | 0 / 7 / 13 | 7 / 3 / 10 | 15 / 4 / 0 | 14 | 2.435 s | 3 | 31 | 8.792 s |
| 4202 | 36 | 16 / 17 / 3 | 24 | 10 / 8 / 6 | 0.875 s | 0.72–1.10 s | 0 / 6 / 18 | 8 / 2 / 14 | 16 / 8 / 0 | 15 | 2.469 s | 3 | 36 | 8.792 s |

`B/C/A` means behind/centred/ahead relative to player position at the measured lifecycle point. The test harness verifies aerial collection directly, including exactly-once score and SFX, rather than auto-collecting coins during the natural diagnostics.

No trajectory simulation failed its deterministic equations. Event cap truncation was zero in these three runs. Placement failures were primarily the deliberate D3 cutoff, current landed-can overlap, and sibling-trajectory separation. All six D3 warnings remained **8.50, 17.04, 24.61, 33.40, 40.60 and 48.36 seconds**, maximum gap **8.792 seconds**, with zero D3 collectible-path rejection or delay.

### Important A/B confound

The control delivered 49/53/51 coins for the same representative seeds, while this prototype delivered 21/20/24. Event attempts and requested 55/35/10 selection remain configured as approved, but deterministic ballistic/D3/can/trajectory constraints omit many requested members. Relaxing the D3 cutoff raised delivery to 31–35 coins but delayed a frozen D3 warning to a 9.567-second gap in seed 1701, so that approach was rejected.

This abundance difference is a meaningful comparison confound. Manual review must not attribute every preference to ballistic motion alone. Adoption should require evidence that the new scoring verb outweighs the reduced opportunity, or a separately approved follow-up that preserves D3 without changing the tested motion.

## Validation

- Targeted VM-0.6.7 lifecycle, trajectory, cap, D3 and cleanup suite: passed.
- Exact VM-0.6.6 control regression: passed and retained its deterministic 49/53/51 isolated coin results.
- Final stable-source full suite: **40/40 scripts passed**.
- Standard presentation: **180 headless frames, exit 0**.
- Frozen Prototype A and raw Prototype B scenes: **120 headless frames each, exit 0**.
- Single-threaded Web export: succeeded with nine generated root files.
- ZIP integrity: passed; `index.html` is at the archive root.
- Local Chromium/WebGL browser: menu and live gameplay rendered; the teaching ballistic coin was visibly airborne; console contained only Godot/WebGL informational messages and no warnings or errors.
- The local macOS Godot process reported its recurring system CA-certificate/editor-settings sandbox messages; neither caused a script, scene-launch, test, or export failure.

Generated builds and validation logs are ignored and are not committed.

## Build outputs

- Control Web directory: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.6-VARIABLE-COIN-EVENTS/`
- Control ZIP: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.6-VARIABLE-COIN-EVENTS.zip`
- Prototype Web directory: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.7-BALLISTIC-COINS/`
- Prototype ZIP: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.7-BALLISTIC-COINS.zip`
- Export preset: `Web GET CANNED VM-0.6.7 Ballistic Coins`
- Diagnostic: [ballistic-state-contact-sheet.svg](screenshots/vm067/ballistic-state-contact-sheet.svg)

## Known product/readability risks

- Gold art and lateral arcs technically distinguish rewards from downward products, but hazard confusion during real greedy play is unverified.
- Predictability, interception difficulty, bounce satisfaction, triple readability, and whether attention shifts upward too much are subjective and unverified.
- Natural deterministic runs show many arcs crossing the stationary player's X, but that does not prove aerial pickups are common, fair, or skillful with a moving player.
- Settled positions skew behind because the conveyor keeps moving; whether this creates useful turn-back decisions or merely lost opportunities needs playtesting.
- Reduced delivered abundance is a substantial A/B confound, documented above.
- Browser QA covered one local Chromium/WebGL environment, not Safari, touch hardware, or an itch.io iframe.

## Decision and preserved backlog

No adoption decision is made by this implementation. Compare VM-0.6.6 and VM-0.6.7 manually before changing the accepted branch.

**Hazard-Earned Refund Coins** remains postponed and explicitly preserved as a separate future hypothesis: a successful hazard interaction could later eject a ballistic coin. VM-0.6.7 remains time-generated and does not implement that loop.

