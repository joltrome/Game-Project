# VM-0.5.0-VIS-04-RT Runtime Validation

Recorded: 2026-09-03 JST

This report records implementation and technical validation. Human judgments
about prominence, animation quality, visual fairness, perceived carriage
pressure, pickup feel, or external-test readiness remain with Startup Lab.

## Scope and Git starting point

- Verified parent branch: `visual/vm-0.5.0-vis-03`.
- Verified parent/local/remote commit:
  `0f083d297e7b5ae2c2c3af3a59e2653eb51996c2`.
- The parent working tree was clean and its remote branch matched local HEAD.
- VIS-04 work was isolated on `visual/vm-0.5.0-vis-04`.
- No merge into the stable gameplay baseline was performed.

## Runtime candidates

Four scenes share the same integration code:

| Configuration | Player | Carriage center Y | Coin visual | Pickup collision |
|---|---|---:|---:|---:|
| P-A/C-A | S1 | 518 | 32×32 | 24×24 |
| P-B/C-A | S1 | 506 | 32×32 | 24×24 |
| P-B/C-B | S1 | 506 | 32×32 | 32×32 |
| `VIS04-PROVISIONAL` | S1 | 506 | 32×32 | 32×32 |

Godot positive Y points downward, so P-B decreases the physical carriage center
from 518 to 506. Only that Y coordinate differs between P-A and P-B. Carriage
size, X path, speed, cue timing, frequency, and visual remain frozen.

The first three scenes show internal identifiers and allow F8 to toggle the
debug overlay. The provisional scene is a clean combined candidate: internal
IDs and instrumentation are hidden, F8 is unavailable, and the compact control
hint disappears after four seconds. It is not approved for external testing.

## S1 technician and RUN mapping

- exact runtime visual: 50×60;
- authored sheet: 300×60, six 50×60 cells;
- runtime scale for RUN: exact 1×;
- sprite offset: `(-25,-60)` under the existing player-local anchor `(0,24)`;
- stable visual origin: bottom center;
- gameplay collision: unchanged centered 32×48;
- RUN: six frames, 60 ms each, 360 ms loop;
- facing follows current left/right input on the first physics frame;
- movement speed, acceleration, jump, gravity, coyote time, buffering, and
  conveyor support are unchanged.

The Work package did not include S1 versions of IDLE, JUMP, FALL, LAND, or
DEATH. Those states therefore reuse VIS-03's 40×48 art at uniform 1.25× nearest
scale, keeping the bottom-centered 50×60 footprint. This is disclosed for
manual transition review; no missing pose was redrawn and no controller timing
was changed.

## Carriage geometry evidence

- P-A center/band: Y=518, collision band Y=504–532.
- P-B center/band: Y=506, collision band Y=492–520.
- Both remain mechanically clear of the 32×48 grounded player collision.
- Both still overlap a player standing on a landed product.
- Both still intersect the deterministic normal jump arc.
- P-A jump-overlap intervals were approximately 0.006–0.156 s and
  0.427–0.578 s after takeoff.
- P-B jump-overlap intervals were approximately 0.024–0.200 s and
  0.383–0.560 s after takeoff.

These measurements show that the Y-only shift changes when the normal jump arc
occupies the carriage band. They do not establish whether P-B is too forgiving,
too dangerous, or correctly pressurized in human play.

## C1 coin mapping

- logical frame: 16×16;
- rendered visual: exact 2×, 32×32;
- six frames at 90 ms each;
- C-A pickup collision: unchanged centered 24×24 rectangle;
- C-B pickup collision: centered 32×32 rectangle;
- the authored route/director footprint remains 24×24 in both candidates;
- routes, spawn timing, offer weights, lifetime, score value, and exactly-once
  collection logic remain unchanged.

The C-B shape is duplicated on the instantiated coin after route selection.
Therefore its larger pickup region does not modify placement or route
validation. Automated contact invoked twice increments score once. Whether the
32×32 collider creates implausible side pickups or trivializes a risky route
requires manual play.

## Frozen gameplay verification

Controlled snapshots match VIS-03 for the player controller, player collision,
conveyor speed curve, ordinary and D3 warning/fall values, selected 60×60
falling product, 72×48 landed product, product behavior, coin routes and score,
60-second round, and D3 schedule. The existing rack and warning are reused
without redesign or retiming. Prototype A and D2 files were not edited.

The deterministic natural VIS-04 run with schedule seed 5002 produced six
warnings at approximately 9.82, 19.42, 28.62, 37.62, 46.42, and 54.62 seconds,
using lanes 2, 1, 2, 1, 2, and 0. The longest warning gap was 9.60 seconds;
maximum active D3 sequences and falling products were both one.

The existing landed-Y regression remains green: ordinary and D3 products
settle source-independently with the 72×48 landed collision bottom aligned to
conveyor Y=584.

## Automated, launch, Web, and browser validation

- Targeted `test_vm050_vis04_runtime_validation.gd`: 0 failures.
- Full suite: all 25 `tests/test_*.gd` scripts passed, 0 failures.
- Headless 180-frame launches passed for Prototype A, Prototype B, D2,
  VIS-03 Debug, P-A/C-A, P-B/C-A, P-B/C-B, and `VIS04-PROVISIONAL`.
- All four VIS-04 Web exports completed with `index.html`, `index.pck`, and
  `index.wasm` in separate output directories.
- Each Web export reports `GODOT_THREADS_ENABLED = false`.
- All four builds loaded through a local HTTP server and exposed one canvas.
- Browser console result: zero warnings and zero errors for every build.
- No build was uploaded or published.

Godot may print a macOS CA-certificate warning and an editor-settings write
warning under the filesystem sandbox. Neither affected imports, tests,
headless launches, exports, or browser loading.

## Build and evidence paths

Scenes:

- `scenes/experiments/motion_vis04_pa_ca.tscn`
- `scenes/experiments/motion_vis04_pb_ca.tscn`
- `scenes/experiments/motion_vis04_pb_cb.tscn`
- `scenes/experiments/motion_vis04_provisional.tscn`

Web directories:

- `builds/web-vis04-pa-ca/`
- `builds/web-vis04-pb-ca/`
- `builds/web-vis04-pb-cb/`
- `builds/web-vis04-provisional/`

Developer evidence:

- `docs/screenshots/vm050-vis04/01-standing-current-y-overlay.png`
- `docs/screenshots/vm050-vis04/02-standing-raised-12-overlay.png`
- `docs/screenshots/vm050-vis04/03-jump-raised-12-overlay.png`
- `docs/screenshots/vm050-vis04/04-coin-c-a-24-overlay.png`
- `docs/screenshots/vm050-vis04/05-coin-c-b-32-overlay.png`
- `docs/screenshots/vm050-vis04/06-s1-product-interactions-overlay.png`
- `docs/screenshots/vm050-vis04/07-s1-movement-contact-sheet.png`
- local 1152×648, 60 fps, 7.02-second recording:
  `builds/validation-vis04/s1-movement.mp4`

The scripted movement recording uses the normal controller and actual input
actions. It covers hold right/left, rapid reversal, taps, run-to-jump, airborne
direction change, landing-to-move, and conveyor-relative movement. Hazards were
disabled only in the temporary out-of-repository capture harness so the input
sequence could be repeated. The recording is local evidence and ignored as a
generated build artifact.

## Manual Startup Lab protocol

Open each scene in Godot and press F6. Use A/D or Left/Right, Space to jump, R
to restart, and F8 only in the three internal comparison scenes to toggle the
overlay.

1. **Player locomotion — P-B/C-A:** hold left and right, reverse rapidly, use
   short taps, run into a jump, change direction in air, land and move
   immediately, and test movement under conveyor support. Judge prominence,
   skitter/glide, pose transitions, and visible-art/hurtbox credibility.
2. **Carriage baseline — P-A/C-A:** stand and run beneath the carriage, then
   jump and stand on landed products near it. Observe the visible cap overlap.
3. **Carriage raised — P-B/C-A:** repeat the same interactions. Judge standing
   clearance, jump pressure, fairness, and whether the carriage still matters.
4. **Coin old collider — P-B/C-A:** attempt edge grazes, jump-route pickups,
   and deliberate near misses. Record visible touches that fail to collect.
5. **Coin 32 collider — P-B/C-B:** repeat the same attempts. Record visually
   implausible pickups, accidental/free pickups, or reduced route commitment.
6. **Combined — `VIS04-PROVISIONAL`:** play one natural full run and judge the
   player, coin, rack/warning, D3 product, carriage, and overall proportions
   together.

Use the overlay screenshots and recording only for attribution; do not select a
candidate from automated geometry alone.

## Evidence, decision, hypotheses, and remaining uncertainty

### Evidence

- The VIS-04 Work study identified S1 as the smallest studied scale that did
  not visually disappear, found S2 unnecessarily heavy/obstructive, found the
  six-frame bolder RUN less skittery in preview, and found C1 more physically
  token-like than C0.
- The Work measurement found about 8 px of S1 visual overlap at the baseline
  carriage path and estimated a 12 px upward shift to restore the prior visual
  gap.
- Runtime validation confirms the documented S1/C1 dimensions, exact integer
  scaling, stable origins, isolated carriage-Y and coin-collider differences,
  green regression suite, and unchanged frozen snapshots.

### Decision

Run the isolated P-A/P-B and C-A/C-B comparisons before external distribution.
No carriage or pickup-collision candidate is selected by this implementation.

### Hypotheses

- S1 may improve protagonist readability without undermining the tiny-worker
  fantasy.
- P-B may restore credible visual clearance while retaining jump pressure.
- C1 may improve coin desirability.
- C-B may better match visible-touch expectation without trivializing routes.

### Still unverified

- whether S1 and the six-frame RUN stop reading as skitter/glide to a player;
- whether the reused, scaled VIS-03 non-RUN poses make transitions visually
  inconsistent;
- whether the 32×48 hurtbox remains credible beneath the 50×60 sprite;
- whether P-B retains understandable and meaningful human jump pressure;
- whether C-A produces visible touch/no-collect cases;
- whether C-B creates implausible or strategically free pickups;
- whether the combined candidate is ready for external testing.

No claim of final art quality, improved fairness, better game feel, or external
readiness is made.
