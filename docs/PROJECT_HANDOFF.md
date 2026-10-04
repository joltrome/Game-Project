# GET CANNED! Project Handoff

This is the durable cross-session source of truth. Replace stale current-state
facts after an accepted milestone; do not append duplicate state snapshots.

## Current Accepted Baseline

- Accepted implementation: **VM-0.8.0 — Overload Mode**
- Branch: `release/vm-0.8.0-overload`
- Accepted HEAD: `dcc450a974c4c0a081910d23e252dbf47f29c1f0`
- Standard/mobile reference: **VM-0.7.4 Responsive Mobile Cabinet** at
  `f12c75758d5224a3b30607d7e51734a30c47a271`
- Current accepted build: `builds/VM-0.8.0-OVERLOAD.zip`
- In-progress isolated candidate: **VM-0.8.1.1 — Overload QA & Tuning** on
  `release/vm-0.8.1.1-overload-qa-tuning`
- Candidate source parent: VM-0.8.1 at
  `a035802e72d09841021d3abfaa90784c351477e2`
- Candidate report: `docs/vm0811-overload-qa-tuning.md`
- Candidate build: `builds/VM-0.8.1.1-OVERLOAD-QA-TUNING.zip`
- Product direction: the conveyor game is primary. Standard remains an
  approachable 60-second shift; Overload is a separate veteran/mastery mode.

## Current Game

The player is a tiny technician trapped inside the malfunctioning VENTASTIC
vending machine. Move with A/D or Left/Right, jump with Space, restart with R,
and use the production Pause control. Standard ends after 60 seconds. Overload
continues until death, uses the existing systems at higher bounded intensity,
and records survival and Refund performance locally.

Desktop uses the full production presentation with no fake mobile controls.
Landscape mobile preserves a fixed 1152×648, 16:9 internal game: near-16:9 uses
the bottom arcade deck; sufficiently wide phones use side control wings.
Portrait shows `ROTATE DEVICE`.

## Frozen Gameplay Systems

- Shared player controller, collision, jump, coyote time, buffering, support
  velocity, and zero-inertia grounded response.
- Standard's 60-second timer, difficulty, hazard timing, completion, death,
  score behavior, VM-0.7.3 Refund Coin pressure, teaching coin, and D3 schedule.
- Left-moving physical conveyor, landed-can support behavior, current product
  geometry, and player-relative recovery limits.
- D3 source/rack logic, warning priority, reservations, fall behavior, and
  Standard's six authored background drops.
- One Concept C Refund Chute, ballistic coin planner, one-point Refunds,
  exactly-once collection, can support, and current placement safety.
- Existing horizontal Sweeper/carriage mechanics: 96×28 collider, y=518,
  left-to-right path, offscreen spawn, 200 ms warning, speed curves, live exit,
  clearance, collision, and death behavior. VM-0.8.1 may replace its visual
  presentation with the approved electrical short only; mechanics remain frozen.
- Prototype A and D2 remain preserved historical comparison/fallback scenes.

## Accepted Visual / UI Rules

- Production C2 is the source of truth. New UI must look native to the original
  GET CANNED! asset sheet, not merely reuse its palette.
- Primary actions use authored IDLE/FOCUS/PRESSED PNG states with visible
  physical depression. No default buttons, generic cards, or flat substitutes.
- Original logo, death headlines, OUT opening, technician/can/coin scene,
  conveyor, glyph matrices, control grammar, and composition anchors are kept.
- Internal gameplay remains 1152×648 and uniformly scaled, never cropped or
  distorted. Mobile uses the accepted geometry-derived deck/wing chooser.
- Pixel art uses nearest-neighbor filtering, integer-authored coordinates, no
  mipmap blur, and no unapproved full-screen tint, bloom, particles, or shake.

## Permanent QA Rules

- For layout, responsive, viewport, or scaling work, verify separately:
  intended outer geometry, actual internal render surface, and actual rendered
  gameplay pixels. A correctly positioned empty rectangle is a failure.
- Browser screenshots must contain the real game after entering the real scene.
  Final mobile acceptance still requires founder testing on physical devices.
- Preserve deterministic safety/reachability/reservation validation and run the
  full repository test suite once after targeted work.
- Performance review emphasizes tail behavior: planning maximum, p95, p99,
  worst step, and counts above 16.67/33.33/50 ms—not average FPS alone.
- Any displayed control/input hint must have an automated functional test where
  practical; tests must inject the real input path rather than only call the
  target transition directly.
- No paid API/service may be used without a prior cost estimate and approval.

## Current Audio

- Accepted run-owned Miraie master starts from position zero after CLOCK IN,
  continues through Pause, and stops/fades on outcome. Menu/Credits/Results are
  silent; Retry starts a new run-owned playback.
- Active SFX: Refund pickup, jump (+10 dB), landing, product landing, shared UI
  confirmation, impact death, and Standard completion. OUT is intentionally
  silent. `WarningSound1.wav` is preserved but excluded from runtime.
- Music/SFX have independent persistent 0–100% controls.
- Electrical charge/travel/death/clear sounds are deferred. Do not source or
  generate them during VM-0.8.1.

## Latest Playtest Evidence

- External tests selected the conveyor over the vertical-only arena and showed
  voluntary restarts plus meaningful survival-versus-Refund risk taking.
- Experienced-player feedback asks why Standard stops at 60 seconds and reports
  limited long-term depth after mastery exposure.
- VM-0.8.0 was perceived as “Standard, but endless”; its added UI also appeared
  appended rather than native to the production screen.
- Players did not understand the horizontal carriage as a grabber.
- These are qualitative product signals, not evidence that Standard should be
  retuned or that VM-0.8.1's proposed difficulty/score weights are validated.

## Current Hypotheses

- Steeper but bounded Overload escalation may produce genuine mastery pressure
  while retaining readable, theoretically survivable situations.
- Combined Score `floor(100 × active survival seconds) + 250 × Refunds` may
  provide one comparable result; both weights remain experimental.
- A dense traveling electrical short on the unchanged 96×28 danger envelope may
  communicate warning, active danger, and death better than the grabber art.
- Six persistent cabinet failure states aligned to 0/15/30/45/60/90 seconds
  may communicate increasing machine instability without timer reading.
- One validator-approved electrical/D3 overlap from 45 seconds onward may
  create distinct mastery pressure without speed-only tuning or a new hazard.
- Real checkpoint review may reduce tuning time and founder-survival bias while
  preserving real records through explicit debug-run isolation.
- Success still depends on unprompted voluntary Retry and score competition.

## VM-0.8.1.1 Candidate Result

- Mode Select now enters visually neutral while retaining logical keyboard
  focus. Pointer hover and keyboard focus are mutually exclusive visual modes;
  Escape, Back, Enter, Space and touch paths have functional regression tests.
- Best-record content uses one persistent label/value pair, eliminating the
  deferred-delete overlap seen during rapid Standard/Overload switching.
- Active Overload uses current-run Score, Survival and Refunds only. Results use
  Score as the primary comparison number while retaining raw run explanation.
- Score is provisionally `floor(100 × active seconds) + 250 × Refunds`; weights
  are configurable and unvalidated. Historical independent raw records are not
  combined into a fake Best Score.
- Overload starts at the declared Standard-60-second equivalent and reaches
  bounded maximum values at 90 seconds. Maximum conveyor speed still leaves
  90 px/s rightward player recovery.
- UNSTABLE/WARNING/CRITICAL/SEVERE/CATASTROPHIC/MAX decoration adds localized
  cabinet lighting, a 2 px/0.18 s threshold jolt and a 1 px/8 Hz MAX vibration
  without moving gameplay coordinates. The electrical
  replacement preserves the one existing 96×28, y=518 carriage actor, 200 ms
  warning, path, timing, collision, live exit, and cleanup; electrical contact
  reports `FRIED.`
- From 45 seconds onward, one existing electrical sweep may overlap an actual
  D3 warning/fall after the existing validators approve it; caps remain one
  Sweeper and one falling product.
- The review helper selects real 0/15/30/45/60/90 states with 1–6 or F11/F12;
  forced runs are visibly marked and cannot update any Best record.
- Three final 120-second profiles had no step above 33.33 ms; worst step was
  16.857 ms and one seed had one step above 16.67 ms. Desktop and 640×360 /
  844×390 exported Web pixels loaded with clean browser consoles. Physical-phone
  and human gameplay acceptance remain pending.

## Deferred / Backlog

Electrical SFX; second Refund Chute; new hazards; power-ups/items; coin magnet;
slowdown; characters/cosmetics; progression/economy; global leaderboards;
daily challenges; ads/IAP/Steam integration; monetization; Prototype A machine
jam; additional modes; and broader presentation polish. None is authorized by
VM-0.8.1.1.

## Current Work / Codex Artifacts

- Approved production-faithful Overload UI handoff:
  `/Users/jeromenicholaz/.codex/.chatgpt-projects/g-p-6a620f9598f48191b1f5f1a94286b5cd/artifacts/vm080_overload_revision/HANDOFF.md`
- Approved emergency/electrical handoff:
  `/Users/jeromenicholaz/.codex/.chatgpt-projects/g-p-6a620f9598f48191b1f5f1a94286b5cd/artifacts/vm080_emergency_electrical_study/HANDOFF.md`
- VM-0.8.0 report: `docs/vm080-overload.md`
- VM-0.8.1.1 report: `docs/vm0811-overload-qa-tuning.md`
- VM-0.7.4 mobile report: `docs/vm074-responsive-mobile-cabinet.md`
- Accepted build references:
  `builds/VM-0.8.0-OVERLOAD.zip` and
  `builds/VM-0.7.4-RESPONSIVE-MOBILE-CABINET.zip`

## Recent Milestones

- VM-0.8.0: separate bounded endless Overload experiment with independent raw
  records and local telemetry.
- VM-0.7.4: geometry-derived responsive bottom-deck/side-wing mobile cabinet.
- VM-0.7.3: bounded player-relative single-event Refund Coin pressure.
- VM-0.7.2.1: corrected real-game rendering inside the mobile monitor.
- VM-0.7.0: consolidated ballistic Refund System.
- VM-0.6.4: persistent audio levels, shared UI confirmations, and pre-test pass.

## Next Recommended Step

Run founder review of the isolated VM-0.8.1.1 Web build and the development-only
review scene. Verify neutral Mode Select entry, Escape/Back, single-source Best
record display, six real 0/15/30/45/60/90 checkpoint states, visual distinction,
late D3/electrical overlap readability and fairness, the 200 ms electrical
warning, physical-phone rendering and late-run feel. Do not merge, upload, tune,
or add systems until Startup Lab reviews the evidence.
