# VM-0.8.1 — Overload Rework implementation and QA report

Recorded: 2026-10-03 JST  
Branch: `release/vm-0.8.1-overload-rework`  
Accepted parent: VM-0.8.0 at `dcc450a974c4c0a081910d23e252dbf47f29c1f0`

## Scope and status

VM-0.8.1 is an isolated founder-review candidate. It does not change Standard
gameplay, merge to `master`, upload to itch.io, or add a new hazard. The pass
reworks Overload presentation, bounded intensity, local scoring, machine-state
communication, and the presentation of the existing carriage collider.

## Evidence

- Experienced-player feedback described VM-0.8.0 as essentially Standard
  without the timer.
- The VM-0.8.0 mode entry, HUD, and Results appeared appended rather than
  integrated into the production C2 presentation.
- Players did not reliably understand the old carriage as a grabber.
- Existing deterministic tests establish the frozen carriage geometry and
  Standard behavior used as regressions here.

These observations are qualitative. They do not validate the VM-0.8.1 curve,
Score weights, emergency-state perception, or electrical warning.

## Decisions implemented

- Main Menu keeps one primary `CLOCK IN`; it opens a separate Mode Select.
- Standard and Overload are sibling authored controls with idle, focus, and
  pressed PNG states. Back returns to Main Menu; Retry remains same-mode.
- Active Overload shows current `SCORE`, `SURVIVAL`, and `REFUNDS` only.
- Overload Results keep the cause headline primary and show combined Score,
  raw survival/refunds, Best Score, Retry, and Menu.
- The existing carriage mechanics are presented as a dense electrical short.
  Electrical contact maps to `FRIED.`; Standard receives this presentation
  replacement without receiving Overload emergency decoration.
- Four bounded visual states communicate escalation: UNSTABLE, WARNING,
  CRITICAL, and MAX.

## Hypotheses under review

- A stronger but bounded intensity curve may create a distinct mastery mode
  without making situations theoretically unrecoverable.
- `floor(100 × active survival seconds) + 250 × Refunds` may create one useful
  comparable result. The 100 and 250 weights are exported/configurable test
  values, not accepted balance.
- The electrical presentation may communicate warning and danger better than
  the old grabber while preserving the exact mechanics.
- Persistent casing failure states may communicate escalation without requiring
  the player to read a timer.

## Main Menu, Mode Select, HUD, and Results

- Main Menu is otherwise unchanged. `CLOCK IN` opens Mode Select.
- Desktop Mode Select uses the approved native 344×94 Standard/Overload assets
  and 144×64 Back assets. Standard is initially focused. Selected-mode record
  text follows focus or hover.
- The Mode Select suppresses Main Menu-only control/record lettering so the
  authored mode controls and descriptions do not overlap stale copy.
- Desktop Overload HUD uses the existing 1152×42 production bar. It contains
  only current Score, elapsed Survival, Refunds, Pause, and a subordinate
  Overload machine marking.
- Overload Results suppress the old Standard score lettering and use the
  approved Score-first hierarchy. `R: RETRY` and `ESC: MENU` remain visible.
- Near-16:9 touch review renders the current metrics on the bottom deck; wide
  touch review renders them on the side wings and suppresses duplicate monitor
  labels. The core 1152×648 game remains uniformly scaled.

The browser checks at 640×360 and 844×390 verified real rendered pixels. Final
comfort, finger occlusion, and warning recognition remain physical-device and
human-review questions.

## Combined Score and migration

The calculation layer is `scripts/presentation/overload_score.gd`.

```text
Score = floor(active_survival_seconds × 100) + Refunds × 250
Formula scope = survival100_refund250_v1
```

The result is a stable non-negative integer and uses comma grouping for display.
Existing independent Best Survival and Best Refund records are preserved. They
are never combined into a fictional historical Score because they may come from
different runs. The first actual VM-0.8.1 Overload result establishes Best
Score for the formula scope; only a strict greater result displays `NEW BEST`.

## Bounded Overload intensity

Overload begins at a declared Standard-equivalent intensity of 60 seconds. Its
piecewise-linear checkpoints are:

| Time | Conveyor | Sweeper | Product/fall pressure | Pattern cooldown | Compound margin |
|---:|---:|---:|---:|---:|---:|
| 0 s | 1.250 | 1.150 | 1.120 | 0.500 s | 0.500 s |
| 15 s | 1.350 | 1.250 | 1.250 | 0.420 s | 0.440 s |
| 30 s | 1.425 | 1.350 | 1.350 | 0.350 s | 0.390 s |
| 45 s | 1.470 | 1.450 | 1.450 | 0.300 s | 0.350 s |
| 60 s | 1.500 | 1.550 | 1.520 | 0.270 s | 0.320 s |
| 90+ s | 1.500 | 1.600 | 1.580 | 0.250 s | 0.300 s |

At the maximum, conveyor world speed is capped at 210 px/s. The unchanged
player relative maximum is 300 px/s, leaving 90 px/s rightward recovery. The
maximum target fall duration is approximately 0.348 s. Pattern selection stays
inside the existing compound-only/fairness validator.

## Emergency visual stages

| Stage | Active interval | Presentation |
|---|---|---|
| UNSTABLE | 0–<15 s | seated covers, restrained machine marking |
| WARNING | 15–<30 s | beacon/lens activation |
| CRITICAL | 30–<90 s | displaced cover/seam and late electrical art |
| MAX | 90+ s | bounded maximum casing separation and beacon state |

Transitions use the supplied discrete assets and a 60 ms local cover twitch.
They add no collision, score, scheduler, movement, or lethality. MAX remains
bounded; it does not continue scaling indefinitely.

## Electrical presentation and frozen mechanics

- Existing mechanical actor: one Sweeper/carriage actor.
- Frozen collider: 96×28 at y=518.
- Frozen warning: 200 ms.
- Frozen direction/path/speed/clearance and live-exit lethality.
- Warning art: three charge frames at 70/70/60 ms.
- Active art: four 70 ms arc frames, with the approved late variant from the
  CRITICAL stage onward.
- Exit: the complete live 96×28 art remains visible and lethal until the actual
  collider clears; then it dissipates with no residual collision.
- The source housing and rail are non-lethal presentation.
- Electrical-specific SFX remain deferred.

## Telemetry

All telemetry remains local. Overload results add combined Score, formula ID,
survival, Refunds, death cause, final intensity values, current visual stage,
and maximum stage reached. No analytics or network transmission was added.

## Automated validation

- Targeted VM-0.8.1 integration test: 19 checks passed.
- Updated VM-0.8.0 mode/intensity regression: all checks passed.
- Relevant presentation/audio/mobile regressions passed.
- Full repository suite was run once after the main implementation: 51 test
  scripts, 0 failures.
- Headless launches passed for Standard session, VM-0.8.1 review scene, frozen
  Prototype A, frozen Prototype B, mobile review, and VIS-04 reference scene.
- A later presentation-only correction removed stale Main Menu/Standard
  lettering from Mode Select and Overload Results; both affected targeted suites
  were rerun and passed.

Godot reports the known macOS certificate lookup warning in headless mode and
test-process ObjectDB/resource cleanup warnings. The test processes still exit
0. Export exits 0; sandboxed CLI export cannot save the user's global Godot
editor settings, which does not affect the generated build.

## Performance evidence

Three deterministic 120-second maximum-intensity profiles produced:

| Seed | Planning mean | Planning max | p95 step | p99 step | Worst step | >16.67 ms | >33.33 ms | >50 ms |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 401 | 2.101 ms | 17.511 ms | 0.072 ms | 0.179 ms | 17.555 ms | 1 | 0 | 0 |
| 1701 | 3.101 ms | 17.576 ms | 0.074 ms | 0.182 ms | 17.622 ms | 2 | 0 | 0 |
| 4202 | 2.257 ms | 14.210 ms | 0.071 ms | 0.183 ms | 14.260 ms | 0 | 0 | 0 |

Each run produced 14 deterministic D3 warnings through 114.433 s; longest D3
gap was approximately 8.792 s. These native deterministic profiles include the
gameplay planner at maximum intensity, but do not substitute for physical mobile
render-tail measurement with the full screen composition.

## Web QA and build

- Export preset: `Web GET CANNED VM-0.8.1 Overload Rework`
- Directory: `builds/VM-0.8.1-OVERLOAD-REWORK/`
- ZIP: `builds/VM-0.8.1-OVERLOAD-REWORK.zip`
- Single-threaded Godot Web export; `index.html` is at the archive root.
- Localhost browser flow passed: Main Menu, Mode Select, Overload, Results,
  Retry, 640×360 forced-touch bottom deck, and 844×390 forced-touch side wings.
- Browser console had no project warnings or errors.

## Developer review helper

Launch `res://scenes/tests/vm081_overload_review.tscn` from Godot.

- It enters Overload directly.
- Press `F9` to cycle UNSTABLE → WARNING → CRITICAL → MAX.
- Press `F10` to trigger the existing 200 ms electrical warning and active
  sweep without changing its mechanics.
- The helper is not the exported release main scene.

## Founder test protocol

1. Open the Web build and verify Main Menu has one `CLOCK IN` action.
2. Select `CLOCK IN`; verify Standard starts focused, focus/press states are
   visibly physical, and Back/Esc returns to Main Menu.
3. Start Standard and confirm its 60-second countdown, movement, hazards,
   Refunds, completion, and retry behavior feel unchanged.
4. Start Overload. Verify Score, elapsed Survival, and Refunds are the only
   current-run HUD metrics.
5. Collect Refunds and survive; confirm Score rises and the result explains the
   raw time/refund components.
6. Die to the electrical sweep; verify the 200 ms source charge, dense moving
   danger, complete live exit, and `FRIED.` attribution.
7. Verify Overload Retry starts Overload immediately; Menu returns to Main Menu.
8. Use the review scene and `F9` to inspect all four stages, then `F10` at each
   stage to compare the electrical art.
9. On a physical landscape phone, hold RIGHT and mash JUMP; ensure the player,
   landed cans, incoming hazards, and host HUD remain visible around the thumbs.
10. Continue a run into CRITICAL/MAX if possible and note perceived fairness,
    warning recognition, clutter, and any frame hitch.

Experienced testers should receive controls only. Record attempts, survival,
Refunds, Score, total session duration, voluntary Retry, score-chasing behavior,
electrical-warning recognition, fairness/demanding language, and stop reason.
Do not reveal thresholds, weights, expected survival, or encourage Retry.

## Known risks and unverified items

- Human comprehension of the combined Score formula and relative value of
  survival versus Refunds is unverified.
- The intended serious-pressure window and >90-second rarity are unverified.
- Electrical warning recognition at 200 ms, especially on a physical phone,
  is unverified.
- Emergency-stage perceptibility without timer-reading is unverified.
- Physical-device control comfort, notch/safe-area behavior, and full visual
  render-tail performance remain unverified.
- Authored compact mobile action assets are preserved in the repository for the
  approved host-space study. The current responsive build keeps non-game screens
  uniformly scaled and uses the accepted host-space cabinet/HUD during gameplay;
  founder review must decide whether exact compact non-game recomposition is
  necessary before acceptance.

No claim is made that VM-0.8.1 is fun, balanced, fair, or production-final.
