# VM-0.8.0 — Overload Mode

## Scope and product boundary

VM-0.8.0 adds a separately selectable endless mastery experiment to the
VM-0.7.4 responsive-cabinet build. It does not replace or rebalance Standard.
The menu keeps `CLOCK IN` for the frozen 60-second game and adds `OVERLOAD` as
a compact second choice. Both modes use the same gameplay scene and the same
responsive desktop/mobile presentation; mode flags configure the session before
the gameplay children become ready.

The hypothesis under evaluation is: an endless, bounded escalation built from
the accepted systems may create mastery and replay depth for experienced
players without making Standard hostile to new players. Automated validation
cannot establish voluntary replay, competition, fairness or enjoyment.

## Mode contract

### Standard

Standard retains its existing 60-second countdown, completion outcome, D3
schedule, teaching sequence, hazard director, VM-0.7.3 Refund Coin pressure,
score behavior, movement, audio and difficulty curves. A mode-leak regression
starts Overload, returns to the menu, starts Standard and verifies that the
finite round and finite D3 schedule are restored.

### Overload

- No 60-second success ending; play ends on death.
- The HUD displays elapsed survival time as `MM:SS.cc`.
- It begins at approximately the Standard 28-second intensity. Hazard teaching
  templates are marked presented instead of replayed, and the static teaching
  coin is skipped; the accepted VM-0.7.3 ballistic coin stream remains active.
- Existing phase-four hazard weights are used: can-only `0`, sweeper-only `0`,
  sweeper-then-can `50`, can-then-sweeper `50`.
- Retry restarts Overload directly. Returning to the menu and selecting Standard
  creates a clean Standard run.
- Best survival time and best Refund count are persisted independently in
  `user://overload_best.cfg`; no combined score formula is introduced.
- Each death prints one local `VM080_OVERLOAD_RUN` JSON record. It includes
  survival seconds, Refunds, death cause, intensity, final conveyor/sweeper/
  hazard multipliers, pattern cooldown, compound margin, pattern weights,
  consecutive compounds, maximum active coins and frame-planning summary.
  Nothing is sent over a network.

## Bounded intensity

Values interpolate linearly between authored checkpoints and stop changing at
120 seconds. Base conveyor speed is 140 px/s, base Sweeper speed is 520 px/s,
base product target fall duration is 0.55 seconds, and player maximum relative
speed remains 300 px/s.

| Overload time | Conveyor multiplier / speed | Sweeper multiplier / speed | Product speed multiplier / target fall duration | Pattern cooldown | Compound margin |
|---:|---:|---:|---:|---:|---:|
| 0 s | 1.12 / 156.8 px/s | 1.07 / 556.4 px/s | 1.06 / 0.519 s | 0.62 s | 0.56 s |
| 30 s | 1.22 / 170.8 px/s | 1.13 / 587.6 px/s | 1.10 / 0.500 s | 0.52 s | 0.52 s |
| 60 s | 1.30 / 182.0 px/s | 1.18 / 613.6 px/s | 1.14 / 0.482 s | 0.46 s | 0.48 s |
| 90 s | 1.36 / 190.4 px/s | 1.22 / 634.4 px/s | 1.17 / 0.470 s | 0.42 s | 0.45 s |
| 120 s and later | 1.40 / 196.0 px/s | 1.25 / 650.0 px/s | 1.20 / 0.458 s | 0.40 s | 0.42 s |

The conveyor also remains capped by the existing player-control ratio. At the
maximum authored speed, rightward recovery is still 104 px/s (`300 - 196`).
Cooldown and reaction values stay positive, escalation cannot pass the table's
last row, and the existing reachability, reservation, warning and spacing
validators remain authoritative.

## D3 and Refund Coin behavior

D3 continues its existing deterministic 7–9 second rhythm past the original six
events. Only Overload enables this endless extension. To prevent high late-run
ordinary-product pressure from starving a scheduled D3 event, Overload reserves
the existing ordinary-product slot up to 3.5 seconds before the next D3 event.
This does not create a new hazard, remove a can, change a collision or alter the
Standard schedule.

Refund Coins retain the VM-0.7.3 pressure, group-planning, collision, scoring,
support and cadence behavior. Overload omits only the one-time beginner teaching
coin because it starts after the teaching phase. There is still one Concept C
chute, one-point Refunds, and no multiplier or combined score.

## Deterministic safety and performance evidence

The Overload regression checks exact 0/30/60/90/120/max checkpoints, monotonic
bounded escalation, positive reaction values, player recovery capacity,
separate record persistence, menu focus/touch selection, elapsed HUD behavior,
results, Retry, mode cleanup and restoration of Standard's original values.

A 120-second late-intensity stress profile exercised compound hazards, landed
cans, the active coin system and continuing D3 events across three deterministic
seeds:

| Seed | Coins delivered | D3 warnings | Planning mean | Planning max | p95 | p99 | Worst step | >16.67 / >33.33 / >50 ms |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 401 | 80 | 14 | 1.981 ms | 13.042 ms | 0.069 ms | 0.224 ms | 13.081 ms | 0 / 0 / 0 |
| 1701 | 82 | 14 | 1.705 ms | 9.010 ms | 0.067 ms | 0.187 ms | 9.059 ms | 0 / 0 / 0 |
| 4202 | 80 | 14 | 1.653 ms | 9.120 ms | 0.063 ms | 0.125 ms | 9.151 ms | 0 / 0 / 0 |

The maximum observed landed-can count was five and maximum concurrent active
hazards was two. For seed 401, D3 warnings occurred at 8.500, 17.042, 24.608,
33.400, 40.600, 48.358, 56.525, 65.225, 73.958, 81.592, 88.925, 97.542,
105.850 and 114.433 seconds. The longest interval was 8.792 seconds and no D3
reservation was rejected. These deterministic runs establish bounded scheduling
and measured computation, not human fairness.

The final complete automated suite passes 50 scripts. Standard, Prototype A,
Prototype B and the current D3 visual scene each launch for 180 headless frames.

## Web and mobile QA

Export preset: `Web GET CANNED VM-0.8.0 Overload`

Build directory:

`builds/VM-0.8.0-OVERLOAD/`

Root ZIP:

`builds/VM-0.8.0-OVERLOAD.zip`

The ZIP contains `index.html` and all eight companion generated files at the
archive root. The single-threaded export was loaded through localhost. Browser
selection produced a Standard screenshot with a countdown and an Overload
screenshot with elapsed time, with no captured page or console errors.

Evidence:

- `builds/validation-vm080/web/menu-1152x648.png`
- `builds/validation-vm080/web/standard-844x390.png`
- `builds/validation-vm080/web/overload-844x390.png`

Overload reuses the VM-0.7.4 layout chooser and touch controls; it introduces no
mode-specific mobile controls. Browser geometry/pixels are verified, while real
phone comfort and late-run readability remain physical-device questions.

## Manual review

1. Open `project.godot` in Godot 4 and press F6 on
   `scenes/presentation/standard_session.tscn`, or press F5 if that is the main
   scene.
2. Choose `CLOCK IN`. Verify Standard counts down from 60 seconds and reaches
   the existing successful CLOCKED OUT result.
3. Return to the menu, choose `OVERLOAD`, and verify the HUD counts upward and
   play continues beyond 60 seconds.
4. Die in Overload. Record survival time and Refunds, then select Retry. Verify
   the new run begins quickly in Overload and the best values remain visible.
5. Return to the menu and start Standard again. Verify no elapsed timer,
   intensity, D3 reservation, score or record leaks into Standard.
6. On a landscape phone, hold RIGHT and repeatedly press JUMP. Confirm the
   responsive cabinet remains usable and threats remain visible around the
   controls. This is a physical validation step, not an automated acceptance.
7. For experienced-player testing, give only the controls. Do not ask anyone to
   retry. Record attempts, best survival, Refunds, total session time, voluntary
   retries, attempts to beat another score, and when/why the player stops.

The critical question is: **does Overload make experienced players voluntarily
retry and compete with themselves or others?** Comments such as “cool mode”
followed by quitting after one or two runs are a weak signal.

## Known risks and backlog boundary

Human play has not yet established whether maximum pressure remains readable,
whether the opening is appropriately active, whether competition centers on
time or Refunds, or whether endless D3/coin pressure creates a late-run dominant
strategy. The separate-record design deliberately avoids choosing a combined
scoring formula before evidence exists.

Postponed—not implemented here: a second chute if camping remains severe,
leaderboards, cosmetics/characters, progression, monetization, additional modes
and broader presentation polish.

## Cost and distribution

This work used local Godot, Git, profiling, export and localhost browser QA.
OpenAI API requests: **0**. Third-party paid API/service requests: **0**.
Generated usage units and task-only subscription consumption were not exposed.
**Separately billed cost this task: $0.00**. Cumulative separately billed
project cost: **$0.00**. No paid hosting, extra credits, analytics, itch upload
or public deployment was performed.
