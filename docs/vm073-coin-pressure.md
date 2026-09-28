# VM-0.7.3 Coin Pressure / Anti-Camping experiment

## Scope and comparison

VM-0.7.3 is an isolated reward-topology experiment built from the exact
VM-0.7.2.1 hotfix commit `6de7b11fae97e4a19b93350e2d1d246476bc9540`.
The control remains `VM-0.7.2.1-MOBILE-MONITOR-HOTFIX`; the experiment is
`VM-0.7.3-COIN-PRESSURE`. The experiment keeps one Concept C Refund Chute and
changes only how eligible single ballistic events prefer a landing destination.

Unchanged systems include the player, conveyor, hazards and their difficulty,
D3 schedule, 60-second round, score value, teaching coin, ballistic physics,
event cadence, 55/35/10 single/double/triple weights, five-coin active cap,
supported-on-can behavior, chute source/animation and mobile monitor/deck.

## Evidence, decision, hypothesis and result

**Evidence.** Tester Neptune independently found a repeatable strategy: wait
under the Refund Chute, chase a coin only when required, then return beneath
the chute. The founder reproduced it. This is evidence of a predictable scoring
home base, not evidence that general hazard difficulty must increase.

**Decision.** Test player-relative destinations with the existing single chute.
Keep the feature opt-in and retain VM-0.7.2.1 as an independently playable
control. After profiling showed that constraining every member of a multi-coin
group reduced complete-double integrity, pressure was deliberately limited to
the configured 55% single-event stream; the accepted double/triple group planner
remains unchanged.

**Hypothesis.** Spatially varied destinations selected relative to the player's
current position may make under-chute camping less predictably optimal without
changing Standard hazard difficulty.

**Technical result.** The experiment is implemented, bounded, tested and Web
exported. A fixed-campsite deterministic comparison increased the median landing
displacement across all delivered event coins from 48 px in the control to 72 px
in the experiment. This does not establish that camping is solved; founder A/B
play is required.

## Target selection

Each ballistic archetype derives its valid landing interval from the conveyor
support edge, current control-band edge, coin footprint and the archetype's
actual flight duration. At survival time zero the deterministic test measured:

| Archetype | Valid landing X interval |
|---|---:|
| SHALLOW | 452.1876–748.0 |
| MEDIUM | 452.2244–748.0 |
| HIGH | 452.2693–748.0 |

Each interval is divided into four equal logical zones: `FAR_LEFT`, `MID_LEFT`,
`MID_RIGHT`, and `FAR_RIGHT`. These names are development telemetry only.

- 75% of pressure-eligible singles request a committed destination; 25% retain
  an easier nearby preference.
- The exported useful-displacement hypothesis starts at 200 px. It is a
  preference, not a validity rule. The planner clamps it to 80% of the actually
  reachable displacement before using the existing bounded fallback path.
- SHALLOW and HIGH rank distant zones while retaining their existing flight
  durations and physics. MEDIUM ranks a balanced displacement around 90% of the
  configured preference. No trajectory physics were retuned.
- The two most recent destination zones receive bounded ranking penalties of
  48 px and 18 px. Repetition is discouraged, not forbidden, so safety and valid
  placement remain authoritative.
- 85% of the existing bounded single-event attempts use the preferred zone;
  remaining attempts may safely fall back to the full valid interval.

The valid intervals show why a universal 180–250 px commitment is not safe from
every player position and for every arc. Clamping and fallback are expected
fairness behavior, not a hidden second targeting system.

## Instrumentation and deterministic comparison

Developer telemetry records event/coin index, planning-time player X, preferred
and actual zone, landing X, absolute displacement, archetype, commitment,
clamp/fallback state, recent-zone sequence, collection/expiry, collection X and
time to collection. At round end the opt-in experiment prints one concise
`VM073_COIN_PRESSURE_SUMMARY` containing displacement and zone totals.

The focused fixed-campsite comparison produced:

| Metric | VM-0.7.2.1 control | VM-0.7.3 experiment |
|---|---:|---:|
| Event count | 35 | 36 |
| Delivered event coins | 46 | 49 |
| Median displacement, all event coins | 48 px | 72 px |
| Selected singles/doubles/triples | 20 / 10 / 5 | 23 / 9 / 4 |
| Experiment pressure singles | n/a | 23 |
| Experiment pressure zones L→R | n/a | 7 / 4 / 7 / 5 |
| Experiment committed / fallback / clamped | n/a | 18 / 9 / 18 |
| Consecutive actual-zone repeats | n/a | 2 |

The experiment-only pressure singles averaged 69.57 px and had a 76 px median
in this one campsite seed. The difference between the exported 200 px preference
and observed displacement reflects the reachable-envelope clamp and existing
safety validator.

## Five-seed natural performance and integrity

Seeds: 401, 1701, 4202, 7007 and 9011.

- Mean planning time across the five per-seed means: 1.855 ms.
- Maximum planning event: 8.985 ms.
- Maximum p95 step: 0.048 ms.
- Maximum p99 step: 0.104 ms.
- Worst simulated step: 9.041 ms.
- Steps above 16.67 / 25 / 33.33 / 50 ms: 0 / 0 / 0 / 0.
- Pressure-eligible singles: 66; aggregate destination zones: 28 / 8 / 14 / 16.
- Weighted mean single-event pressure displacement: 89.45 px.
- Complete doubles: 38 / 66 (57.6%), compared with 36 / 61 (59.0%) in the
  freshly profiled VM-0.7.2.1 control.
- Complete triples: 1 / 18 (5.6%) in both experiment and control.
- Every seed retained the six expected D3 warnings.

Planning remains bounded and did not reintroduce the prior 50–200 ms stalls.
These are deterministic harness results, not device frame-time measurements.

## Build and browser QA

Export preset:

`Web GET CANNED VM-0.7.3 Coin Pressure`

Web directory:

`builds/VM-0.7.3-COIN-PRESSURE/`

ZIP:

`builds/VM-0.7.3-COIN-PRESSURE.zip`

ZIP SHA-256:

`1a4c9c8cb1aa6426beebbd1ad492ceb43e9b4f2646db3d9fac90ff7e5df8113a`

The ZIP contains nine files with `index.html` at its root. Touch-enabled
844×390 and desktop 1152×648 localhost captures entered the real Standard game,
contained 53 quantized color bins in the sampled render, visibly showed actual
gameplay and reported no browser console or page errors.

## Founder A/B protocol

Play the control first, then the experiment, and repeat in the reverse order if
possible to reduce order bias.

1. In each build, stand directly beneath the Refund Chute.
2. Stay there between Refund Coin events.
3. Chase coins only when the route requires it.
4. Return beneath the chute immediately after the chase.
5. Attempt to collect nearly every coin for one complete run.
6. Then play one natural run without deliberately exploiting the chute.

Primary question: **Can under-the-chute still serve as an obvious optimal home
base?** Also note whether targets feel varied rather than deterministic
opposite-wall ping-pong, whether optional coins remain safely abandonable, and
whether multi-coin events still read correctly.

## Known limits

- Automated displacement proves a wider deterministic distribution, not the
  removal of a human dominant strategy.
- The 200 px preference is frequently clamped by real safe geometry.
- Pressure currently tests single events only; this preserves multi-event
  integrity but limits how much of the stream is changed.
- Collection rate, perceived fairness, mobile execution and whether SHALLOW,
  MEDIUM and HIGH feel strategically distinct require manual review.
- A second chute, global difficulty tuning, Endless/Overload and other new
  systems remain explicitly deferred.
