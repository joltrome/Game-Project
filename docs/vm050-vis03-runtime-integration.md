# VM-0.5.0-VIS-03-RT Runtime Integration

Recorded: 2026-09-02 JST

This report records implementation and technical validation. Human judgments
about locomotion, warning readability, clutter, fairness, or readiness for an
external test remain with Startup Lab.

## Scope and Git starting point

- Verified parent branch: `visual/vm-0.5.0-vis-02`.
- Verified parent/local/remote commit:
  `ea7ea8bf072d2cd3e788375d5c884e4efa3809a6`.
- The parent working tree was clean.
- VIS-03 work was isolated on `visual/vm-0.5.0-vis-03`.
- The project-wide F5 scene remains the frozen conveyor baseline.

## Mandatory death-interactivity check

The existing death order remains valid for the collapsed DEATH art. Before
the visual adapter receives `player_died`, the conveyor sets `is_dead`, stops
player physics and active interaction, clears or stops hazards, disables coin
interaction/director processing, and prevents additional score changes. The
VIS-03 automated test kills the player, confirms player physics is disabled,
confirms score cannot change through player interaction, and only then accepts
the three-frame DEATH presentation. No death or collision semantics changed.

## Runtime assets and mapping

Six approved PNGs were added under `assets/vm050_d3_vis03/`. Their hashes and
source policy are recorded in
`docs/visual-assets/VM050_D3_VIS03_runtime_provenance.md`. VIS-02 product art
and landed art, plus V2 carriage, coin, and belt assets, are reused unchanged.

### Rigid-block technician

- visual cell: 40×48 at exact 1×;
- visual offset: `(-20,-48)`;
- bottom-centre anchor: `(20,48)` mapped through the existing player-centred
  anchor node;
- gameplay collision: unchanged 32×48;
- IDLE: atlas indices 0–2, 160 ms each;
- RUN: atlas indices 3–6 only, 80 ms each, 320 ms loop (12.5 fps);
- atlas indices 7–8: excluded neutral padding;
- JUMP: indices 9–10, 120 ms each;
- FALL: indices 11–12, 120 ms each;
- LAND: indices 13–15 at 70/70/120 ms;
- DEATH: indices 16–18 at 140 ms.

Grounded directional input selects RUN and sets facing directly from current
input. JUMP/FALL follow vertical velocity. LAND is visual-only and is
immediately interrupted by input or airborne state, so it adds no control
delay. A rapid right-to-left runtime regression confirms facing changes on the
first opposite-input physics frame rather than retaining stale orientation.
Restart replaces the dead scene and clears the DEATH state.

### Full rack and lane lifecycle

One always-safe 312×108 baseline is placed at `(126,96)` at exact 2× scale.
It replaces the older code-drawn three-row inventory while preserving the
surrounding D3 environment. Three 24×31 lane overlays sit at the existing
logical centres 406, 526, and 646, at Y=238 and exact 2× scale. They are hidden
and visually indistinguishable at rest.

The existing logical lifecycle maps as follows:

`STORED` → hidden NORMAL overlay over the common baseline;
`SELECTED` → only the chosen red/blue/green lane overlay appears;
`RELEASE` → that lane opens while the matching product variant is assigned to
the foreground product;
`RESET` → the overlay plays its reset cell and returns hidden NORMAL.

The baseline, overlays, and warning contain no collision object.

### Warning

The VIS-03 24×96 warning uses eight 100 ms frames, displays at the existing
4× runtime scale and existing lane alignment, and remains non-colliding. It
loops visually while the existing exact 1.10-second D3 gameplay warning is
active, then hides on release. Its playback does not drive timing or schedule
state.

### Falling and landed products

The selected candidate uses the approved VIS-02 eight-frame rotational art
with a centred 60×60 lethal falling collision. Product visual footprint,
trajectory, speed, warning, release position, scheduler validation, and landing
trigger remain unchanged; no speed or cadence compensation was added.

Both ordinary/right-source and D3/background-source products still normalize
to parent, landed-body, sprite, and collision-centre Y=560, so the unchanged
72×48 landed collision ends exactly on conveyor Y=584 and retains solidity and
support velocity.

## Clean and debug candidates

### Clean candidate — `VM-0.5.0-VIS-03-D3-TEST`

- scene: `scenes/experiments/motion_vis03_test.tscn`;
- hides build/experiment identifiers, internal motion-study text, D3 state,
  selected-lane diagnostics, local instrumentation, and F8 overlay access;
- shows one small ASCII-safe move/jump/restart hint for four seconds, then
  removes it from gameplay;
- preserves the existing timer and Refund Coin HUD.

### Debug candidate — `VM-0.5.0-VIS-03-D3-DEBUG`

- scene: `scenes/experiments/motion_vis03_debug.tscn`;
- retains build/study identifiers, D3 diagnostics and local instrumentation;
- F8 toggles collision, pivot, selected-lane, state and collision-profile
  diagnostics;
- uses the exact same selected gameplay values as the clean candidate.

## Frozen gameplay verification

Controlled snapshots match the VIS-02 Fall60 baseline for player parameters,
conveyor curve, ordinary and D3 warning/fall values, product footprint,
landed collision, carriage, Refund Coin, round length, and D3 schedule. D2 and
Prototype A remain independently loadable. No player-controller, conveyor,
carriage, coin, scheduler, cadence, score, or Prototype A file was edited.

The VIS-03 deterministic natural run produced six warnings at approximately
9.82, 18.02, 26.22, 33.42, 41.82 and 50.02 seconds in one representative run,
with maximum one sequence, maximum one falling product, and no adjacent
same-lane selection. Safety retries can change later valid warning times and
lanes without changing the frozen schedule configuration.

## Automated and launch validation

- New `test_vm050_vis03_runtime_integration.gd`: 0 failures.
- Full suite: all 24 `tests/test_*.gd` scripts passed.
- During the first aggregate pass, the legacy D3 stress suite recorded 19
  products for seed 7907 against its timing-sensitive minimum of 20, while all
  cadence, lifecycle, suppression, safety, and concurrency assertions passed.
  The unchanged suite passed independently immediately afterward with all
  three deterministic seeds at 20 products. No code was changed for this
  rerun.
- VIS-03 Debug, VIS-03 Test, D2, and Prototype A each completed headless launch
  validation with zero scene-launch failures.
- The selected source-independent landed-Y regression passed.

Godot on macOS prints a system CA-certificate warning in local headless mode
and cannot save editor settings from the filesystem sandbox; neither warning
affected imports, tests, scene launches, or exports.

## Web and browser QA

Single-threaded release exports (`GODOT_THREADS_ENABLED = false`) were written
to:

- `builds/web-vis03-debug/`;
- `builds/web-vis03-test/`.

Prepared archives:

- `builds/VM-0.5.0-VIS-03-D3-DEBUG-web.zip`;
- `builds/VM-0.5.0-VIS-03-D3-TEST-web.zip`.

Each archive contains `index.html` at its root. Both builds loaded through
localhost with a 1280×720 CSS canvas and 2560×1440 backing canvas. Each exposed
one Godot canvas and produced zero browser warnings and zero browser errors.
No build was uploaded or published.

## Visual evidence

- clean browser baseline:
  `docs/screenshots/vm050-vis03/clean-baseline-browser.png`;
- clean runtime movement snapshot:
  `docs/screenshots/vm050-vis03/clean-runtime-movement-browser.png`;
- debug-overlay browser view:
  `docs/screenshots/vm050-vis03/debug-overlay-browser.png`;
- seven-second movement contact sheet:
  `docs/screenshots/vm050-vis03/movement-contact-sheet.png`;
- rack-warning/release/landing contact sheet:
  `docs/screenshots/vm050-vis03/warning-contact-sheet.png`.

Local 1152×648, 60 fps recordings:

- `builds/VM-0.5.0-VIS-03-D3-TEST-motion.mp4` (7.02 seconds);
- `builds/VM-0.5.0-VIS-03-D3-TEST-warning.mp4` (4.82 seconds).

The motion recording is a developer-only scripted capture using real player
input actions and the normal controller. It covers continuous right and left
movement, rapid reversals, run-to-jump, airborne direction change, landing,
and conveyor-relative movement. Hazards were suppressed only in the temporary
capture harness so the sequence could be repeatable; that harness was kept in
`/tmp` and is not part of either build or repository.

## Manual Startup Lab protocol

Run the clean scene first with F6 and complete four 60-second attempts:

1. Movement-focused: hold both directions, tap, reverse rapidly, jump while
   running, change direction in air, and move immediately after landing.
2. Survival-first: judge warning, product, carriage and clutter readability.
3. Coin-greedy: pursue Refund Coins and observe whether the lighter D3 warning
   remains visible under full pressure.
4. Natural: play normally and judge whether the scene reads as one coherent
   game rather than a development dashboard.

Use the debug scene only when attribution is unclear; press F8 to reveal the
developer overlay. Record any observed foot shuffling/body glide, warning miss,
false hit impression, visual clutter, or new visual bug. Do not tune from these
implementation results alone.

## Evidence, decision, hypothesis, and remaining uncertainty

### Evidence

- The internal VIS-02 comparison selected centred 60×60 for the falling lethal
  collision over 72×72.
- VIS-03 supplies a coherent full-rack baseline and a lighter lane-local
  warning treatment.
- The rigid-block technician was selected for live evaluation because the
  articulated limb construction conflicted with the geometric character and
  environment language.

### Decision

Integrate VIS-03 as an isolated D3 clean/debug candidate without changing
frozen gameplay, and return it to Startup Lab before external distribution.

### Hypothesis

The rigid-block technician may feel coherent at live controller speed, and the
unified rack plus lighter warning may improve world consistency without
reducing gameplay clarity.

### Still unverified

- perceived technician glide or skitter during true human input;
- fast-reversal and landing-transition quality;
- warning clarity under full survival and coin pressure;
- background clutter and fresh-user readability;
- carriage readability against the richer rack;
- external-test readiness.

The right-side VEND ELEVATOR remains more schematic than the rack and is
recorded as a later visual backlog item. No claim of final art quality,
readability, fairness, fun, or external validation is made.

