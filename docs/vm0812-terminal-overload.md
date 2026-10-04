# VM-0.8.1.2 — Terminal Overload + Mode Record Repair

Recorded: 2026-10-04 JST

Branch: `release/vm-0.8.1.2-terminal-overload`

Starting HEAD: `a6f667e587ce353cc9fc94f1d068960cda7a4a23`

Parent candidate: VM-0.8.1.1 Overload QA & Tuning

## Scope and status

VM-0.8.1.2 changes the existing Overload systems so that MAX begins at 60
seconds and behaves as a terminal survival state. It also replaces the hidden,
contextual Mode Select record with two fixed records. It adds no hazard type,
does not change Standard gameplay, does not change the player, electrical
collision, score formula, audio, or approved UI art, and is not merged to
`master`.

The build is technically ready for founder review. Human perception, actual
3–10-second survival after entering MAX, and physical-phone comfort remain
unverified. No claim is made that this candidate is balanced, fair to humans,
fun, or accepted.

## Evidence and root causes

### Effective pressure, not configured pressure

The initial natural-lifecycle diagnostic selected one compound pattern at
approximately 5.008 seconds, then left it reserved behind D3's external-product
reservation. A D3 candidate repeatedly failed its lane/coin-path check while
the ordinary scheduler launched nothing else. From 10 through 100 seconds the
diagnostic measured zero accepted patterns, sweeps, ordinary products, or D3
warnings, with 100% hazard-free time. The original scheduler did not expose
rejection reasons, which was itself an observability gap.

That run is a failure diagnosis, not a representative performance benchmark:
its synchronous first-load work also created artificial 140–188 ms samples.
It nevertheless proved the product problem: multiplier tables were not
evidence that the player received pressure.

Permanent Overload-tuning rule:

> Configured intensity multipliers are not sufficient evidence of effective
> difficulty. Track accepted event density, concurrency, scheduler rejection,
> and hazard-free downtime.

### Electrical contradiction

The existing base Sweeper speed is 520 px/s. VM-0.8.1.1 MAX applied 1.60×, or
832 px/s. Its approximate center travel was `(576 - -48) / 832 = 0.75 s`, below
the inherited Standalone Sweeper gate of 0.8–1.2 seconds. Therefore the faster
hazard could reject itself and reduce delivered electrical pressure.

Standard keeps the exact old gate. Overload now evaluates the existing 200 ms
warning plus travel to the player's relevant region, a minimum response
margin, left/right grounded reach, jump response, current position, and a
sampled corridor against projected landed cans. A fast electrical pattern is
accepted only when at least one response corridor remains. Geometry, warning,
path, collision and lethality are unchanged.

### Mode records and positional movement

The prior screen deliberately created a neutral `BEST RECORD / --` field and
replaced its content only after a mode became the active visual target. Its
right-aligned value recomputed `position.x` from changing ink width. This made
records undiscoverable on entry and caused visible text movement.

Mode Select now always displays:

- `STANDARD BEST` plus the Standard coin record; zero is explicit.
- `OVERLOAD BEST` plus the current-formula combined score; `--` appears only
  when no valid combined Overload run exists.

The two labels and values have fixed centers and never switch on hover. An
end-to-end test writes isolated real record files, loads exact values, records
better runs, recreates Mode Select, and verifies both updated values.

Button QA found equal 344×94 IDLE/FOCUS canvases. IDLE alpha bounds are
`Rect2(12,12,320,70)` and FOCUS bounds are `Rect2(6,0,332,88)` for both mode
buttons. Both alpha centers remain at x=172. Focus expands the highlight
symmetrically within the stable canvas; Artwork-node position and hit rect do
not move. PRESSED retains the intentional authored depression.

## Terminal phase model

| Time | Phase | Conveyor multiplier | Right recovery | Sweeper multiplier | Product multiplier | Cooldown | Compound margin | Sweep cap | Falling cap | D3 coexistence |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | UNSTABLE | 1.25 | 125.0 px/s | 1.15 | 1.12 | 0.50 s | 0.50 s | 1 | 1 | off |
| 10 | WARNING | 1.34 | 112.4 px/s | 1.25 | 1.25 | 0.42 s | 0.44 s | 1 | 1 | off |
| 20 | CRITICAL | 1.42 | 101.2 px/s | 1.35 | 1.35 | 0.35 s | 0.39 s | 1 | 1 | off |
| 30 | SEVERE | 1.50 | 90.0 px/s | 1.45 | 1.45 | 0.28 s | 0.34 s | 1 | 2 | validated |
| 45 | CATASTROPHIC | 1.65 | 69.0 px/s | 1.55 | 1.52 | 0.22 s | 0.29 s | 2 | 2 | validated |
| 60+ | MAX / MELTDOWN | 1.82 | 45.2 px/s | 1.60 | 1.58 | 0.08 s | 0.24 s | 3 | 3 | validated |

Player maximum relative speed remains 300 px/s. Overload alone raises the
conveyor cap from 70% to 85% of that speed; recovery remains positive. Standard
retains the frozen 70% cap.

Pattern weights for `[single, sweeper, can→sweeper, sweeper→can]` are:

- 0 s: `[10, 10, 40, 40]`
- 10 s: `[5, 5, 45, 45]`
- 20 s: `[0, 10, 45, 45]`
- 30 s: `[0, 12, 44, 44]`
- 45 s: `[0, 20, 40, 40]`
- 60+ s: `[0, 50, 25, 25]`

The target maximum hazard-free windows are 3.0, 2.7, 2.3, 1.9, 1.4 and 0.9
seconds. These targets bound scheduling opportunity; they do not blind-spawn a
hazard or bypass safety validation.

## Phase-specific encounter behavior

- UNSTABLE preserves some single-pattern and recovery space.
- WARNING makes compound patterns dominant.
- CRITICAL removes ordinary single selection and shortens recovery.
- SEVERE enables validated D3/ordinary/electrical coexistence and a second
  falling-product slot.
- CATASTROPHIC permits two active Sweepers and increasingly coexisting systems.
- MAX permits three active Sweepers and three falling products, uses almost no
  scheduler comfort delay, and continually retries existing hazards through
  their validators.

When a compound selection is blocked by D3's pre-reservation, Overload records
the rejection and may schedule a separately validated electrical response
instead of freezing the entire scheduler. It does not bypass electrical
solvability. Every attempt, rejection reason, and commit is instrumented.

## D3 and ordinary-product coexistence

Standard still rejects D3 whenever an ordinary product is active. Later
Overload instead projects the existing product's landing and conveyor movement
to D3's impact horizon. D3 and ordinary pressure may coexist only when their
projected collision footprints remain separated. Existing D3 lane selection,
warning identity, collision, and source logic remain authoritative.

## Deterministic effective-pressure result

The metric's meaningful-threat count includes active Sweeper/falling/landed
actors, visible warnings/cues and an active D3 sequence. It is a deterministic
stationary-player scheduling fixture—not a human survival simulation.

| Checkpoint | Attempts/min | Accepted/min | Rejected/min | Sweeps/min | Ordinary/min | D3/min | Compound/min | D3+electric/min | No-hazard share | Longest gap | ≥1 | ≥2 | Max threats |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 240 | 18 | 222 | 18 | 0 | 6 | 0 | 6 | 55.58% | 5.092 s | 43.71% | 15.02% | 3 |
| 10 | 366 | 36 | 330 | 30 | 6 | 6 | 18 | 6 | 0% | 0 s | 100% | 76.67% | 3 |
| 20 | 396 | 30 | 366 | 30 | 6 | 6 | 12 | 6 | 3.08% | 0.283 s | 96.92% | 36.83% | 3 |
| 30 | 376 | 44 | 332 | 44 | 8 | 8 | 16 | 8 | 0% | 0 s | 100% | 81.89% | 3 |
| 45 | 388 | 76 | 312 | 76 | 8 | 8 | 16 | 8 | 0% | 0 s | 100% | 92.50% | 4 |
| 60/MAX | 448 | 116 | 332 | 116 | 16 | 8 | 20 | 8 | 0% | 0 s | 100% | 100% | 5 |
| 75 | 408 | 104 | 304 | 108 | 16 | 8 | 24 | 8 | 0% | 0 s | 100% | 99.78% | 5 |
| 90 | 336 | 108 | 228 | 96 | 30 | 6 | 42 | 6 | 0% | 0 s | 100% | 100% | 6 |

Attempt count includes bounded retry attempts while active caps or warnings are
occupied; it is not a count of player-facing hazards. The recorded rejection
reasons are `active_sweeper_cap`, `falling_product_cap`,
`electrical_warning_pending`, and `d3_product_slot_reserved`.

MAX passes the mechanical differentiation gate relative to 45 seconds:

- accepted patterns rise from 76 to 116 per minute (+52.6%);
- sweeps rise from 76 to 116 per minute (+52.6%);
- ordinary drops rise from 8 to 16 per minute;
- ≥2-threat time rises from 92.5% to 100%;
- observed maximum meaningful threats rises from four to five.

This establishes delivered scheduler pressure, not the founder's desired
human survival duration.

## Review helper

Scene: `res://scenes/tests/vm081_overload_review.tscn`

- `1`–`8`: 0, 10, 20, 30, 45, 60, 75 and 90 seconds.
- `F11` / `F12`: previous / next checkpoint.
- `F10`: toggle CLEAN / SATURATED and recreate the selected checkpoint.
- `F9`: retain the visual-only emergency-stage cycle for art inspection.
- `R`: restart the selected debug state.

CLEAN recreates phase mechanics and presentation on an empty board. SATURATED
at 30+ seconds adds one landed product, a validated D3 warning and the existing
electrical warning. It uses existing actors and does not update records. Both
states display `DEBUG ... RECORDS DISABLED`.

## Human-solvability boundary

Exact checks cover actor caps, collision-footprint separation, projected D3 /
ordinary overlap, current player position, minimum reaction time, player reach,
sampled avoidance corridor, and positive rightward recovery. The solver also
retains the existing warning and collider semantics.

The following remain heuristic or human-only:

- whether simultaneous readable cues can be perceived and acted on;
- whether a mathematically reachable corridor is reasonable under near-perfect
  timing and changing terrain;
- whether MAX is oppressive without feeling arbitrary;
- whether a competent player usually survives only 3–10 seconds after MAX;
- whether clean and saturated debug starts accurately represent subjective
  fatigue from a natural run.

## Performance

Three established 120-second saturated stress seeds include cans, landed-can
terrain, D3, Refund Coins and electrical scheduling. Headless timing does not
measure GPU cost of the emergency artwork; exported browser rendering is
checked separately.

| Seed | Mean step | Planning max | p95 | p99 | Worst step | >16.67 | >33.33 | >50 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 401 | 0.0438 ms | 11.748 ms | 0.081 ms | 0.177 ms | 11.791 ms | 0 | 0 | 0 |
| 1701 | 0.0456 ms | 13.850 ms | 0.078 ms | 0.152 ms | 13.886 ms | 0 | 0 | 0 |
| 4202 | 0.0422 ms | 10.120 ms | 0.075 ms | 0.125 ms | 10.142 ms | 0 | 0 | 0 |

The dedicated pressure profiler measured 0.0421 ms mean, 0.064 ms p95, 0.173
ms p99, 10.742 ms worst and zero steps above 16.67, 33.33 or 50 ms.

## Standard freeze evidence

Automated regression asserts the existing Standard phase snapshot, 0.70
conveyor cap, one Sweeper/one falling-product caps, fixed electrical gate, D3
ordinary suppression, player movement and score weights. Existing Standard,
Prototype A, D2, audio, mobile and gameplay suites all remain green. No
Standard branch is routed through the new Overload solver or coexistence rule.

## Tests and actual-pixel QA

- Targeted VM-0.8.0/0.8.1/0.8.1.1/0.8.1.2 suites: passed.
- Final authoritative repository suite: 53 scripts, zero failures.
- One timing-sensitive audio assertion failed once under host contention and
  passed unchanged on its isolated rerun and in the final full suite.
- Release and review Web exports completed using Godot 4.7.1 single-threaded
  presets.
- Local Chrome loaded release and review exports with zero console errors and
  zero page errors.
- Actual release pixels passed at 1152×648 desktop, 844×390 mobile side wings,
  and 640×360 mobile bottom deck.
- Native captures cover Mode Select neutral, Standard focus, Overload focus,
  both records, normal Overload result, updated record, 844×390 Mode Select,
  clean 0/10/20/30/45/60 and saturated 60.

Desktop static-menu color diversity is intentionally below the gameplay-only
crop threshold, but its pixels loaded correctly and its browser console was
clean. Both gameplay captures passed the real-pixel threshold.

## Build and founder review

Release directory:

`builds/VM-0.8.1.2-TERMINAL-OVERLOAD/`

Root-index ZIP:

`builds/VM-0.8.1.2-TERMINAL-OVERLOAD.zip`

Review Web directory:

`builds/validation-vm0812/web-review/`

Founder test order:

1. Open the normal release, CLOCK IN, and confirm both Best records are visible
   before changing focus.
2. Move between Standard and Overload with keyboard/pointer. Confirm no record
   text or physical button translation.
3. Finish or die in one Overload run and confirm Results then Mode Select show
   the updated combined Best.
4. Open the review helper. Compare CLEAN 30, 45 and 60 using keys `4`, `5`, `6`.
5. At 60, press `F10` to compare SATURATED 60. Confirm the debug label and that
   records cannot change.
6. Play at least three natural Overload runs. Record survival after first
   reaching 60/MAX, whether each death had a readable cause and reachable
   response, whether pressure ever becomes idle, and whether the cue stack is
   comprehensible.
7. Repeat one natural run on a physical phone. Confirm side-wing/deck controls,
   player visibility, hazard readability and simultaneous RIGHT + JUMP input.

Stop after founder review. Do not alter Score weights, add systems, merge,
upload to itch.io, or tune from deterministic evidence alone.

## Cost

All work was local Godot, Git, browser and documentation work. No OpenAI API,
third-party paid API/service, paid hosting, itch upload, extra Codex credit
purchase or analytics request was made. Separately billed cost: `$0.00`.
