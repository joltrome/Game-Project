# VM-0.5.0-MOTION-02 — D3 Background-Drop Frequency Stress Test

Recorded: 2026-08-26

Branch: `visual/vm-0.5.0-motion-01`

Build ID: `VM-0.5.0-MOTION-02-D3-STRESS`

Status: implemented and technically validated; founder manual stress test pending. These results do not establish that the frequency is readable, fair, enjoyable, or preferable to D2.

## Evidence entering the experiment

- Manual review of an approximately 31-second MOTION-01 D3 recording found one clearly observable source-to-threat sequence: stored product selection, background state change, aligned `DROP` warning, falling product, and return to foreground play.
- That sequence made the background appear connected to gameplay and moved attention vertically from the rack through the warning and fall path to the player/conveyor.
- One event in approximately 31 seconds was insufficient exposure to judge repeated readability, distraction, perceived fairness, decision value, or whole-round effect.
- D2 improved composition inside its 2.4:1 viewport, but its shallow presentation left substantial unused space on a normal 16:9 window. D2 remains an unchanged fallback.

## Hypothesis under evaluation

When background-sourced drops occur regularly, they may remain readable and fair while producing meaningful vertical decision pressure without increasing total product pressure. The deliberately aggressive frequency is an upper-bound stress test, not a validated final cadence.

## Implementation decision

MOTION-02 modifies only D3 scheduling, local instrumentation, its internal build identity/export target, and the disabled-by-default ordinary-product replacement seam. D2, the project-wide default scene, Prototype A, movement, coins, HUD, hazards, timings outside D3, art, and the 60-second round remain unchanged.

Initial exported values:

| Setting | Value |
|---|---:|
| First reservation | 8.50 s |
| Repeat interval | seeded 7.00–9.00 s |
| Minimum successful warning gap | 7.00 s |
| Maximum completed D3 drops | 6 |
| Warning duration | 1.10 s, unchanged |
| Target release-to-belt duration | 0.85 s, unchanged |
| Invalid-state retry delay | 0.12 s |
| Logical lanes | x=406, 526, 646 |
| Deterministic default seed | 5002 |

The cap is six rather than seven because a seventh release near the end of the round could occur after the last ordinary product opportunity, leaving no equivalent event to suppress. That produced 23 product hazards against the 22-product frozen deterministic baseline. Six allowed every accepted background sequence to reserve and consume one ordinary-event suppression in the tested runs. This is a hazard-budget correction, not a subjective reduction because the scene felt busy.

## Scheduler and hazard-budget behavior

1. D3 precomputes a deterministic nominal reservation schedule from the exported first-event and interval range.
2. At a reservation time it checks that no D3 sequence, ordinary warning, or falling product is active and that enough round time remains for warning plus fall.
3. It evaluates the three logical lanes against the live arena. It rejects invalid candidates with explicit reasons and retries after 0.12 seconds; it does not spawn from an invalid lane.
4. A valid selection starts one warning immediately, marks the selected background slot, and reserves one future ordinary-product suppression.
5. The next ordinary product event consumes that suppression without spawning. Targeted carriage behavior and non-product hazards are not suppressed.
6. The background product releases after the unchanged 1.10-second warning, uses a fall speed derived from its actual distance and the unchanged 0.85-second target duration, and registers with the existing conveyor product collection.
7. Landing uses the existing solid, non-lethal, conveyor-carried product state. The D3 slot resets only after landing.
8. Restart, death, and round completion cancel the reservation/warning state and clear any unused suppression debt.

This is advance replacement rather than waiting to intercept the next ordinary warning. Waiting for a future ordinary event delayed the first visible D3 warning to approximately 11 seconds because the frozen director did not offer a suitable product event during the 8–10-second target window. The suppression debt preserves the budget while allowing the D3 warning itself to begin in the approved window.

## Fairness validation

Exact/deterministic pre-spawn checks:

- maximum one active D3 state machine;
- maximum one falling product across ordinary and background products;
- no ordinary warning is already visible;
- candidate footprint remains inside the playable belt/control bounds;
- no current falling product or projected landed-product footprint overlaps the lane at impact;
- no active Refund Coin path intersects the fall corridor;
- the current carriage configuration retains grounded clearance;
- no immediate same-lane repetition when another lane is valid;
- enough round time remains to complete warning and fall;
- warning, selected slot, released product, landing, and reset retain one-to-one identity;
- each accepted D3 sequence queues exactly one ordinary-product suppression.

Heuristics:

- player escape reach projects current x using the frozen net left/right speeds across warning plus fall time, collision widths, clearance, and a reaction reserve;
- existing landed products are projected with constant conveyor velocity until impact;
- coin-path and carriage checks are conservative snapshots, not a full solver for all future player/hazard trajectories;
- perceived fairness, warning recognition, visual overload, preferred action, and attention cost require human playtesting.

## Local instrumentation

Instrumentation remains in memory and optional local console output only. It does not write analytics files or make network requests.

Recorded events include:

- nominal reservation and actual attempt time;
- candidate lane and acceptance or rejection;
- aggregate rejection reason plus per-lane candidate reasons;
- warning start, product release, landing, and visual completion/reset;
- ordinary product event suppression and reservation identity;
- background-product player collision/death;
- restart/death/completion cleanup;
- run summary containing total drops, longest successful-warning gap, suppression count, collision count, and rejection counts.

One attempt can reject several candidate lanes, so per-lane reason totals can exceed the number of rejected scheduling attempts.

## Deterministic 60-second reports

Frozen deterministic baseline: 22 total product hazards.

| Seed | Warnings (s) | Lanes | Drops | Rejected attempts | Longest warning gap | Suppressed ordinary | Ordinary spawned | Total product hazards |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| 5002 | 9.82, 19.22, 28.22, 36.22, 44.02, 51.82 | 2,1,2,0,1,2 | 6 | 48 | 9.40 s | 6 | 15 | 21 |
| 6011 | 9.82, 19.02, 28.02, 36.02, 44.02, 51.82 | 2,1,2,0,1,2 | 6 | 49 | 9.20 s | 6 | 15 | 21 |
| 7907 | 9.82, 16.82, 24.82, 32.62, 41.82, 49.82 | 2,1,0,2,1,0 | 6 | 22 | 9.20 s | 6 | 14 | 20 |

All seeds recorded six warnings, releases, landings, and visual resets; six actual ordinary suppressions; maximum one active D3 sequence; and maximum one falling product. Total product hazards did not exceed the frozen 22-product baseline, although the safety delays reduced the tested totals by one or two. Therefore the budget is bounded but not an assertion of exact difficulty equivalence.

Per-lane rejection reason totals:

- seed 5002: coin-path overlap 11, falling product active 40, landed-product overlap 25, ordinary warning active 28;
- seed 6011: coin-path overlap 12, falling product active 40, landed-product overlap 26, ordinary warning active 27;
- seed 7907: coin-path overlap 8, falling product active 16, landed-product overlap 19, ordinary warning active 9.

## Validation result

- All 21 automated Godot suites passed.
- The dedicated suite ended with `VM050_MOTION_EXPERIMENT_TEST_FAILURES=0`.
- Tests cover the early first event, six natural drops, bounded spacing, lane variety, maximum one active D3 sequence/falling product, invalid-lane recovery, replacement suppression, collision/death attribution, and restart/death/completion cleanup.
- Frozen-scene, D2, movement, Prototype A, Prototype B, coin, round, hazard, distribution, and prior motion tests remained green.
- Original Arena, original Conveyor, D2, and D3 Stress each completed 180 headless frames with exit code 0.
- The single-threaded Web export completed, contains `index.html` at its root, loaded at 1152×648 and 900×700 over localhost, and produced no browser-console warnings or errors.
- Godot emitted the existing macOS CA-certificate and restricted editor-settings-save warnings; they did not fail tests, launches, or export.

## Build artifacts

Generated artifacts are ignored and are not committed:

- Local scene: `scenes/experiments/motion_d3.tscn`
- Web directory: `builds/web-motion-d3-stress/`
- Upload-ready local archive: `builds/vm-0.5.0-motion-02-d3-stress-web.zip`

Export and serve:

```bash
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web Motion D3 Stress" builds/web-motion-d3-stress/index.html
(cd builds/web-motion-d3-stress && zip -q -r ../vm-0.5.0-motion-02-d3-stress-web.zip . -x '*.import' '.DS_Store')
python3 -m http.server 8125 --directory builds/web-motion-d3-stress
```

No itch.io upload or public distribution was performed.

## Founder manual stress-test plan

Run five complete attempts without changing exported values between runs:

1. **Survival-first:** ignore Refund Coins; record every D3 warning noticed/missed, whether the source-to-warning-to-product correspondence remained clear, any forced jump/reposition, and any death that felt unavoidable.
2. **Coin-greedy:** pursue Refund Coins; record whether D3 creates deliberate tradeoffs, interrupts a readable route, or overloads attention.
3. **Natural run 1:** play normally; note event count, perceived gaps, repeated-lane annoyance, attention travel, and death cause.
4. **Natural run 2:** repeat without tuning; note whether familiarity improves recognition or makes repetition tedious.
5. **Natural run 3:** repeat without tuning; note whether the mechanic still influences decisions late in the round.

For every run, bring the result screen or recording plus:

- completed duration and score;
- number of clearly noticed background drops;
- any missed warning or mistaken source;
- whether six exposures felt too rare, appropriate, or excessive;
- whether a drop changed the intended movement/jump;
- whether ordinary product pressure appeared reduced, equivalent, or increased;
- any perceived unfairness, distraction, or visual incoherence.

Do not tune frequency, choose D3, modify D2, or begin production art until Startup Lab reviews those five runs.
