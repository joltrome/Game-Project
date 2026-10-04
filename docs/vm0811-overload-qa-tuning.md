# VM-0.8.1.1 — Overload QA & Tuning report

Recorded: 2026-10-03 JST

Branch: `release/vm-0.8.1.1-overload-qa-tuning`

Starting HEAD: `a035802e72d09841021d3abfaa90784c351477e2`

Parent candidate: VM-0.8.1 Overload Rework

## Scope and status

VM-0.8.1.1 is a focused founder-QA correction on the isolated VM-0.8.1
candidate. It fixes Mode Select interaction defects, provides a real intensity
review workflow, makes the existing Overload checkpoints visually legible,
adds one validated late-game overlap made from existing actors, and bounds
optional-reward planning. It does not merge to `master`, upload to itch.io,
rebalance Score, alter Standard difficulty, change the electrical collider, or
add a hazard type.

This build is ready for founder review. It is not an accepted gameplay baseline
and no claim is made that it is fun, balanced, fair, or production-final.

## Evidence recorded

- Founder testing found that Standard looked permanently selected on entry.
- `ESC: BACK` was displayed but Escape did not return to Main Menu.
- switching Standard/Overload records could briefly render overlapping text.
- late intensity could not be compared without repeatedly surviving 45–90 s.
- the 30–90 s visual presentation remained too similar while mechanics rose.
- Overload still read as a faster, largely serial Standard loop.
- VM-0.8.1 stress profiles contained 0–2 frames above 16.67 ms per seed.

These observations establish concrete QA problems. They do not validate the
new visual intensity, late overlap, difficulty, or founder skill target.

## Decisions preserved

- Standard gameplay and its 60-second round remain frozen.
- Overload Score remains `floor(active seconds × 100) + Refunds × 250`.
- The electrical actor remains one 96×28 collider at y=518 with a 200 ms
  warning, unchanged path/timing/lethality, and `FRIED.` attribution.
- No new hazard, electrical SFX, Score rebalance, power-up, chute, mode,
  progression, cosmetic, leaderboard, ad, or monetization system was added.

## Mode Select corrections

### Escape

Root cause: Escape is mapped to `pause`; the generic pause branch consumed the
event before the later Mode Select Escape branch could run. The fix gives the
screen-specific Mode Select Escape transition precedence. The pause path is
unchanged in gameplay.

An automated regression injects a real `InputEventKey` for Escape through the
viewport and asserts `MODE_SELECT → MENU`; it does not call `show_menu()`.

### Neutral entry and visual precedence

Root cause: `standard.grab_focus()` was necessary for keyboard navigation but
immediately exposed the intentionally strong authored focus art. Logical focus
is now retained while its visual treatment remains dormant until directional
keyboard/gamepad input occurs.

Visual precedence is explicit:

1. a currently pressed control alone uses PRESSED;
2. active pointer hover alone uses FOCUS;
3. after keyboard navigation begins, the focus owner alone uses FOCUS;
4. initial entry and mouse exit use IDLE for both choices.

The existing authored IDLE/FOCUS/PRESSED PNGs are unchanged. Enter and Space
activate the logical focus owner. Pointer/touch presses still activate the
pressed control. Back click and Escape both return to Main Menu.

### Best-record rendering

Root cause: record changes queued the old labels for deferred deletion and
created replacements at the same coordinates immediately. One persistent
`ModeRecordLabel` and one persistent `ModeRecordValue` are now created with the
Mode Select screen and updated in place. Rapid Standard/Overload switching no
longer creates duplicate nodes, stale values, or a one-frame double render.
Neutral entry displays `BEST RECORD` / `--`; the active hover/focus displays the
corresponding mode's record.

## Real intensity review helper

The existing scene remains:

`res://scenes/tests/vm081_overload_review.tscn`

Controls:

- `1` = 0 s
- `2` = 15 s
- `3` = 30 s
- `4` = 45 s
- `5` = 60 s
- `6` = 90 s / MAX
- `F11` = previous real checkpoint
- `F12` = next real checkpoint
- `R` = restart the selected checkpoint
- `F9` = visual-only stage cycle, retained for art inspection
- `F10` = trigger the existing electrical cue

Selecting a real checkpoint starts a fresh Overload run with the checkpoint as
actual survival time. It applies the existing piecewise curve's conveyor,
Sweeper, product-pressure, cooldown, compound-margin and pattern-weight state;
reconstructs the deterministic endless D3 schedule at that time; synchronizes
the visual emergency stage; and clears transient run state.

Every forced run displays `DEBUG INTENSITY <N> SEC  RECORDS DISABLED`. Debug
results display `DEBUG RUN - RECORDS DISABLED`. No forced run can update Best
Score, Best Survival, or Best Refunds.

A developer-only Web preset targets this scene with the `vm0811_review` feature.
The normal release preset still starts the real Main Menu.

## Checkpoint alignment

| Time | Visual state | Conveyor | Sweeper | Product pressure | Cooldown | Compound margin | Late D3 + electrical overlap |
|---:|---|---:|---:|---:|---:|---:|---|
| 0 s | UNSTABLE | 1.250 | 1.150 | 1.120 | 0.500 s | 0.500 s | off |
| 15 s | WARNING | 1.350 | 1.250 | 1.250 | 0.420 s | 0.440 s | off |
| 30 s | CRITICAL | 1.425 | 1.350 | 1.350 | 0.350 s | 0.390 s | off |
| 45 s | SEVERE | 1.470 | 1.450 | 1.450 | 0.300 s | 0.350 s | enabled when validated |
| 60 s | CATASTROPHIC | 1.500 | 1.550 | 1.520 | 0.270 s | 0.320 s | enabled when validated |
| 90+ s | MAX | 1.500 | 1.600 | 1.580 | 0.250 s | 0.300 s | enabled when validated |

The mechanical multipliers are the existing VM-0.8.1 curve. The new mechanical
change is limited to the late overlap described below.

## Visual escalation

Six presentation stages now correspond to all six mechanical checkpoints:
UNSTABLE, WARNING, CRITICAL, SEVERE, CATASTROPHIC, and MAX. The four approved
cover/fixture asset levels are mapped across these stages; no new art asset was
invented.

- localized red emergency illumination grows around cabinet borders, bezel,
  fixtures, and background machine surfaces;
- gameplay entities are not tinted and there is no opaque playfield filter;
- warning fixtures persist increasingly from WARNING through CATASTROPHIC;
- panel flicker is restrained and localized to the cabinet presentation;
- threshold entry applies a 0.18 s, 2-pixel, integer-aligned horizontal casing
  jolt without moving gameplay coordinates;
- MAX applies a 1-pixel cabinet-only vibration at 8 Hz;
- all emergency textures are cached instead of repeatedly loaded per frame.

The player, hazards, coins, collision bodies, support positions, D3 lanes, and
camera coordinates are unaffected by jolt or vibration.

## Controlled late overlap

VM-0.8.1's encounter structure remained serial even at aggressive multipliers.
From 45 seconds onward, Overload may schedule one validator-approved
`SWEEPER_ONLY` encounter while an actual visible D3 warning/fall sequence is
active. The feature is disabled before 45 seconds and in Standard.

The overlap:

- uses the existing electrical actor and existing D3 product only;
- permits at most one Sweeper and one falling D3 product;
- does not raise the falling-product cap or create a new pattern type;
- runs the existing compound spacing, response-margin, collision, D3 safety,
  reachability and scheduling validation before launch;
- is armed by the real D3 selected/warning/falling lifecycle, not by its earlier
  pre-reservation lead time;
- can occur at most once per active D3 sequence.

This is the hypothesis under review: controlled concurrency may create stronger
mastery pressure than speed-only tuning while retaining a reachable response.
Automated validation proves caps and validator use, not human-perceived fairness.

## Performance investigation and correction

The pre-change rerun reproduced the tail issue. Slow frames were caused by
Refund Coin group candidate generation: slow events used 152–216 placement
attempts. Emergency presentation was not instantiated in that headless profile,
so it was not the source of those measured spikes. Emergency code nevertheless
contained repeated `load(...)` calls in update paths; these are now cached as a
preventive runtime correction.

Overload alone now supplies a configurable total planning-attempt budget of
112 per event. Standard retains the default value `0` (unlimited/current
behavior). A tested budget of 96 removed the tail but degraded deterministic
double integrity to approximately 46% in one seed, so it was rejected.

### Before: VM-0.8.1 rerun

| Seed | Planning max | p95 | p99 | Worst | >16.67 ms | >33.33 ms | >50 ms |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 401 | 19.900 ms | 0.092 ms | 0.291 ms | 20.024 ms | 2 | 0 | 0 |
| 1701 | 17.807 ms | 0.089 ms | 0.274 ms | 17.936 ms | 3 | 0 | 0 |
| 4202 | 14.261 ms | 0.092 ms | 0.274 ms | 14.317 ms | 0 | 0 | 0 |

### After: VM-0.8.1.1 final three-seed 120 s stress profile

| Seed | Planning mean | Planning max | p95 | p99 | Worst | >16.67 ms | >33.33 ms | >50 ms | Full doubles |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 401 | 2.015 ms | 16.797 ms | 0.076 ms | 0.217 ms | 16.857 ms | 1 | 0 | 0 | 58.82% |
| 1701 | 2.226 ms | 12.188 ms | 0.080 ms | 0.198 ms | 12.253 ms | 0 | 0 | 0 | 63.64% |
| 4202 | 1.811 ms | 11.390 ms | 0.078 ms | 0.195 ms | 11.413 ms | 0 | 0 | 0 | 70.00% |

One 16.857 ms deterministic planning frame remains in seed 401, 0.187 ms over
the 16.67 ms target. No seed exceeded 33.33 or 50 ms. Tail behavior improved
and did not regress versus VM-0.8.1. Each run preserved 14 D3 warnings, an
approximately 8.792 s longest D3 gap, and a maximum of two concurrent hazards.
This is native deterministic CPU evidence, not physical-phone render-tail data.

## Automated validation

- New focused suite covers initial neutrality, hover/focus/pressed precedence,
  directional keyboard activation, Enter/Space, real Escape dispatch, Back,
  persistent record nodes, rapid record switching, every checkpoint, disabled
  debug records, late D3/electrical overlap, caps, frozen geometry, and Standard.
- Legacy UI tests were updated only where they assumed the now-invalid default
  visible Standard focus.
- Existing VM-0.8.0/0.8.1, mobile, movement, arena, D2, D3, Refund, audio,
  presentation and gameplay tests remain part of the full suite.
- AGENTS.md now permanently requires functional automated coverage, where
  practical, for any displayed input hint.

- Clean full repository run: 52 test scripts, 0 failures.
- During an earlier run with two live Web canvases, legacy wall-clock-only
  VM-0.7.0/VM-0.7.1 performance thresholds failed under host contention; both
  passed immediately after the browser canvases closed, and the final clean
  52-script run passed. No threshold or legacy test was weakened.
- Headless Standard, frozen Prototype A, frozen Prototype B, D2, and the real
  intensity review scene all exited 0. The review scene reports only the known
  short `--quit-after` ObjectDB/resource cleanup diagnostic.

## Web and actual-pixel QA

Release preset:
`Web GET CANNED VM-0.8.1.1 Overload QA Tuning`

Developer preset:
`Web GET CANNED VM-0.8.1.1 Review Helper`

Actual exported Web pixels were inspected for Main Menu, neutral Mode Select,
keyboard-selected Overload, real 0/30/45/60/90 checkpoints, debug Results,
640×360 mid/MAX gameplay, and 844×390 Mode Select/Results. No overlap, clipping,
or missing gameplay surface was observed. Both browser consoles reported zero
errors. Existing uniform scaling remains acceptable for this focused pass; no
mobile non-game redesign was introduced. Physical-device touch size, notch
behavior, readability, visual phase perception, and performance remain
unverified.

## Build outputs

- Release directory: `builds/VM-0.8.1.1-OVERLOAD-QA-TUNING/`
- Release ZIP: `builds/VM-0.8.1.1-OVERLOAD-QA-TUNING.zip`
- Developer review Web directory: `builds/validation-vm0811/web-review/`
- Single-threaded Web export; release archive contains `index.html` at root.
- Generated build artifacts remain ignored and are not committed.
- No itch.io upload or public distribution occurred.

## Founder test protocol

### Normal release

1. Open the release build and choose `CLOCK IN`.
2. Confirm neither mode looks selected initially.
3. Hover Standard, then Overload; confirm only one highlights at a time.
4. Alternate hover/focus several times; confirm Best record never overlaps.
5. Press Escape; confirm it returns to Main Menu.
6. Re-enter Mode Select and verify Back click, arrow navigation, Enter and Space.
7. Start Standard and confirm its 60-second behavior is unchanged.

### Real Overload checkpoint review

1. Run `res://scenes/tests/vm081_overload_review.tscn` in Godot, or serve the
   developer review Web directory locally.
2. Press `1`, `2`, `3`, `4`, `5`, and `6` to compare 0/15/30/45/60/90 seconds.
3. Use `F11`/`F12` to step backward/forward and `R` to replay the selected state.
4. At every checkpoint compare visual state, perceived intensity, overlap,
   fairness, readability, and any hitch.
5. Confirm the debug marker is present and a forced death does not change any
   real Best record.

Do not tune immediately from one founder run. Record whether 30, 45, 60 and MAX
are perceptibly distinct; whether the D3/electrical overlap remains readable;
whether any death felt unavoidable; and whether Overload is now structurally
distinct rather than merely faster.

## Known risks and unverified items

- Human perception of the six visual stages is unverified.
- Human fairness and recognition of late D3/electrical overlap are unverified.
- MAX's “barely controllable” target is unverified and must not be judged only
  from founder mastery.
- One deterministic frame remains 0.187 ms over the 16.67 ms target.
- Full triples remain rare/absent in the profiled late-run stress fixture; this
  milestone intentionally did not redesign the coin planner.
- Physical phone pixels, touch comfort, safe areas and render-tail performance
  remain unverified.
- Electrical-warning recognition at 200 ms remains an uninformed human test.
- Score comprehension and 100/250 weight quality remain unverified.

## Cost

No OpenAI API or third-party paid-service request was made. All implementation,
profiling, Web export and browser QA were local. Separately billed cost for this
task is `$0.00`; cumulative separately billed project cost remains `$0.00`.
The task-end ChatGPT Plus/Codex account snapshot showed 4% of the shared 5-hour
window and 46% of the shared weekly window used, no paid credit balance, and two
unused free reset credits. Exact task-only tokens and model identity were not
exposed.
