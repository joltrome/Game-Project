# VM-0.8.1.3 — Mode Record Readability + Double-Jump Experiment

Recorded: 2026-11-06 JST

Branch: `release/vm-0.8.1.3-movement-record-readability`

Starting and parent HEAD: `852f8eab6692606fb440f8845f9c921c94a3bba7`

Parent candidate: VM-0.8.1.2 Terminal Overload

Implementation commit: `746efd86050ee613b166d2f69286fd1dfefba657`

The isolated branch was pushed and its remote hash independently verified.
The VM-0.8.1.2 remote remains at its original parent hash. No merge or tag was
created; generated builds remain local and ignored.

## Scope and status

This is an isolated founder-review candidate. It repairs the presentation of
the already-correct Standard and Overload records and adds one configurable
movement experiment. The default and Single Jump build use zero additional
air jumps. The Double Jump build enables exactly one additional airborne jump
at 100% of the existing vertical impulse.

No Standard or Terminal Overload hazard, speed, cadence, collision, score,
camera, gravity, first jump, horizontal movement, coyote-time, buffering,
audio, art, or persistence rule was retuned. VM-0.8.1.2 and `master` remain
preserved. This candidate is technically ready for founder A/B review; Double
Jump is not adopted or recommended by this implementation result.

## Evidence

- Record persistence and formatting were already correct, but Mode Select drew
  both records at y=382/414 over the busy animated machine artwork. Actual
  mobile scaling made the problem more severe.
- The frozen shared controller accepted only a grounded/coyote jump. No
  airborne-jump budget existed.
- Founder described the current movement as restrictive. This is qualitative
  evidence motivating a comparison, not evidence that Double Jump is the
  correct permanent design.
- Terminal Overload's deterministic pressure and tail performance were already
  acceptable. There was no evidence authorizing hazard or balance retuning.

## Decision

- Keep the existing record stores and place each Best directly beneath its own
  authored mode button on the cream control surface.
- Add an exported `additional_air_jumps` budget to the shared controller with a
  production default of zero and a separately exported airborne impulse
  multiplier.
- Ship separate Single and Double founder builds. Keep the normal/default
  candidate on Single Jump.
- Extend the development review helper instead of changing release menus:
  `J` toggles movement, and `F8` toggles Standard/Overload. Existing checkpoint
  and CLEAN/SATURATED controls remain available. Debug runs cannot write either
  record. The standalone Double Jump experiment also disables both record
  stores and identifies its movement condition during gameplay.

## Hypothesis

Exactly one additional airborne jump may improve recovery and agency in late
Overload without making electrical threats, landed-can terrain, Refund choices,
or MAX pressure trivial. This requires founder play. A smoother or easier feel
alone is not sufficient evidence for adoption.

## Record presentation

Both fields use the existing C2 pixel text, with no generic card or new asset:

| Field | Center X | Label Y / style | Value Y / style | Color / surface |
|---|---:|---|---|---|
| Standard | 396 | 560, small ×2 | 576, display ×2 | ink on cream |
| Overload | 804 | 560, small ×2 | 576, display ×2 | ink on cream |

The labels are `60 SECOND SHIFT   BEST` and
`ENDLESS / ESCALATING   BEST`. Standard zero is displayed as `0`. Overload is
`--` only when its current score formula has no compatible stored result.
Logical positions do not change on neutral, hover, keyboard focus, pressed, or
record-width changes.

Human-readable QA rule recorded for future presentation work:

> Pixel presence is not readability. Verify foreground/background contrast,
> artwork intersection, practical final-pixel size, clipping, fixed anchoring,
> focus stability, and representative mobile output.

Native and exported-browser pixels were inspected at 1152×648, 844×390 and
640×360. Both records remain on the cream panel, do not intersect the animated
machine or button artwork, do not clip, remain fixed across focus, and remain
legible at the two requested mobile sizes.

## Double Jump state contract

- `additional_air_jumps = 0` is the default and Single Jump setting.
- `additional_air_jumps = 1` is the isolated Double Jump setting.
- `airborne_jump_velocity_multiplier = 1.0` is the founder-build setting.
- A grounded or coyote jump is the first impulse and does not consume the one
  airborne allowance.
- The next airborne jump consumes the allowance. A third impulse is rejected.
- Any legitimate `is_on_floor()` support, including conveyor or landed-can
  support, replenishes the allowance.
- Jump buffering can trigger a new grounded takeoff after landing but cannot
  create a third impulse before landing.
- Both impulses emit the existing `jump_accepted` signal, so the existing
  animation/SFX presentation is reused. No new art or audio was added.
- The existing mobile Jump action drives both impulses. No new touch control is
  required.

The player exposes local counters for accepted total and airborne jumps. The
Overload run summary records `movement_mode`, `accepted_jumps`, and
`accepted_airborne_jumps`. It does not log sensitive player content.

## Review helper

Scene: `res://scenes/tests/vm081_overload_review.tscn`

- `J`: restart the current review state as SINGLE or DOUBLE.
- `F8`: restart as Standard or Overload.
- `1`–`8`: 0/10/20/30/45/60/75/90 checkpoint.
- `F10`: CLEAN/SATURATED.
- `F11` / `F12`: previous/next checkpoint.
- `F9`: visual-only emergency-stage cycle.
- `R`: restart the selected state.

The gameplay label states `MOVEMENT: SINGLE` or `MOVEMENT: DOUBLE` and
`RECORDS DISABLED`. Command-line review also supports `--double-jump`,
`--standard`, `--checkpoint=60`, and `--saturated`.

## Terminal Overload freeze evidence

The established deterministic pressure profile reproduced the VM-0.8.1.2
encounter result exactly. At 45 versus 60/MAX, accepted patterns remain
76→116/min, sweeps 76→116/min, ordinary drops 8→16/min, time with at least two
threats 92.5→100%, and maximum meaningful threats four→five. MAX retains zero
measured hazard-free time in that fixture.

Three 120-second saturated profiles:

| Seed | Mean step | Planning max | p95 | p99 | Worst step | >16.67 | >33.33 | >50 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 401 | 0.0470 ms | 12.261 ms | 0.090 ms | 0.221 ms | 12.307 ms | 0 | 0 | 0 |
| 1701 | 0.0503 ms | 14.500 ms | 0.093 ms | 0.228 ms | 14.570 ms | 0 | 0 | 0 |
| 4202 | 0.0470 ms | 10.927 ms | 0.092 ms | 0.223 ms | 10.953 ms | 0 | 0 | 0 |

The dedicated effective-pressure run measured 0.0415 ms mean, 0.062 ms p95,
0.158 ms p99, 10.461 ms worst, and zero steps over 16.67/33.33/50 ms.

## Automated and launch validation

- New VM-0.8.1.3 focused suite: 28 checks, zero failures, including actual
  conveyor support, moving landed-can support, buffered landing, retry reset,
  coyote accounting, held LEFT/RIGHT plus real mobile Jump, standalone experiment record protection,
  and actual `J`/`F8` keyboard transitions. It was rerun after final isolation
  changes, alongside the VM-0.8.0/0.8.1.1/0.8.1.2 regression suites.
- Locked movement reversal, physical conveyor, real touch input, VM-0.8.1.1 UI,
  and VM-0.8.1.2 Terminal Overload targeted suites: passed.
- Two complete 54-script sequential repository runs each passed 53 scripts.
  The sole failure in both was the existing audio retry test's `<0.08 s`
  playback-position timing assertion under the long batch. That test passed
  unchanged on both immediate isolated reruns, including after the final batch;
  all of its surrounding functional audio assertions passed in the batches.
  No audio code or test threshold was changed. Therefore all 54 scripts pass
  individually, but this report does not falsely label the sequential batch
  54/54 clean.
- Standard session, Prototype A, Conveyor, review helper, and saturated MAX
  Double review all completed 180-frame headless launches.
- Single, Double and review Web exports completed with single-threaded presets.
- Local Chrome loaded real Single, Double and review gameplay pixels with zero
  console errors and zero page errors.

The recurring macOS system-CA diagnostic, restricted editor-settings save
diagnostic, and existing test-exit ObjectDB warnings did not fail a test,
launch, export, or browser load.

## Artifacts

- Single Web directory: `builds/VM-0.8.1.3-SINGLE-JUMP/`
- Single root ZIP: `builds/VM-0.8.1.3-SINGLE-JUMP.zip`
- Single ZIP SHA-256:
  `15b5aaf6649cdf36e2b7681f43f186bdeec996250ad45cbc9f95a4b816a28451`
- Double Web directory: `builds/VM-0.8.1.3-DOUBLE-JUMP-EXPERIMENT/`
- Double root ZIP: `builds/VM-0.8.1.3-DOUBLE-JUMP-EXPERIMENT.zip`
- Double ZIP SHA-256:
  `52f15f1b960298baedd8229896e585c4a2178f229ac7a3f368f3a08393ba9128`
- Review Web directory: `builds/validation-vm0813/web-review/`
- Native/browser captures: `builds/validation-vm0813/native/` and
  `builds/validation-vm0813/browser/`

Generated build artifacts and captures remain ignored and are not committed.
Nothing was uploaded to itch.io.

## Changed-file manifest

| Files | Purpose |
|---|---|
| `scripts/player.gd` | Default-zero extra-jump allowance, exported impulse multiplier, counters and existing-signal reuse. |
| `scripts/presentation/standard_session.gd` | Mode-record layout, isolated build identification/configuration, protected experiment records, review label and jump telemetry. |
| `scripts/experiments/vm081_overload_review.gd` | Real `J` movement and `F8` mode switches; command-line comparison options. |
| `project.godot` | New review-export entry feature only. |
| `export_presets.cfg` | Separate Single, Double and development review Web presets. |
| `tests/test_vm0813_movement_record_readability.gd` and `.gd.uid` | New focused controller, support, touch, record, isolation and real-input tests. |
| `tests/test_vm071_mobile_playability.gd`, `tests/test_vm072_mobile_arcade_deck.gd`, `tests/test_vm080_overload.gd` | Current build-ID expectations only. |
| `tests/test_vm0811_overload_qa_tuning.gd` | Updated record-label wording expectation only. |
| `tools/capture_mobile_web.cjs` | Reproducible neutral/focused Mode Select Web captures; static-menu pixel check distinguished from gameplay. |
| `tools/qa/capture_vm0813.gd` and `.gd.uid` | Reproducible known-record desktop/mobile native captures. |
| `AGENTS.md` | Permanent human-readability QA rule. |
| `docs/PROJECT_HANDOFF.md`, `docs/roadmap.html`, `docs/cost-usage.md`, this report | Current state, separated evidence/decision/hypothesis/result, factual validation and cost ledger. |

No scene, art/audio asset, hazard director, collectible director, conveyor,
electrical actor, D3 scheduler or collision-resource file changed.

## Local test entry points

From the project directory, serve all ignored build folders:

```sh
python3 -m http.server 8193 --bind 127.0.0.1 --directory builds
```

- Single: `http://127.0.0.1:8193/VM-0.8.1.3-SINGLE-JUMP/index.html`
- Double: `http://127.0.0.1:8193/VM-0.8.1.3-DOUBLE-JUMP-EXPERIMENT/index.html`
- Review: `http://127.0.0.1:8193/validation-vm0813/web-review/index.html`

If port 8193 is already serving these builds, reuse it; do not start a second
server on that port. Add `?mobile_touch_review` and use a mobile-sized browser
viewport for desktop display inspection. This does not establish physical-phone
input acceptance.

Native review (from the project directory):

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --path . --scene res://scenes/tests/vm081_overload_review.tscn -- --checkpoint=30 --saturated
```

Add `--double-jump` after `--` to start in Double. On a Mac, function keys may
require Fn. No itch upload is needed for local desktop comparison.

## Founder A/B protocol

1. Play Single Jump Standard briefly to re-establish the frozen controller.
2. In the review helper, play Single at SATURATED 30, 45 and 60/MAX.
3. Play the Double build Standard briefly.
4. Repeat the same SATURATED 30, 45 and 60/MAX states with Double.
5. On physical mobile, hold RIGHT and repeatedly press Jump, then repeat with
   LEFT. Confirm the second press is accepted, a third is not, and thumbs do not
   obscure the technician, cans, or incoming hazards.
6. Record whether Double improves agency/recovery, creates excessive airtime,
   trivializes electrical pressure, reduces landed-can relevance, makes Refund
   choices safer, weakens MAX overwhelm, or causes spontaneous retries.

Do not adopt Double Jump merely because it feels smoother or easier.

## Still unverified

- Founder preference under controlled Single/Double order.
- Whether Double meaningfully improves agency rather than only lowering risk.
- Whether electrical, D3, landed-can and Refund decisions remain strategically
  relevant.
- Physical-phone simultaneous RIGHT/LEFT + repeated Jump behavior and visual
  occlusion.
- Human readability of the repaired records at the actual hosted itch embed.
- Human fairness and survival duration at Terminal MAX.

## Cost

All work used local Godot, Git, browser automation, screenshots and docs. No
OpenAI API, third-party paid API/service, hosting, itch.io upload, analytics,
asset purchase, or extra Codex credit was used. Separately billed cost: `$0.00`.
