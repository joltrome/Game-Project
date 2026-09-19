# VM-0.6.9 — Ballistic Integrity + Performance Validation

Recorded: 2026-09-19 JST

Static control: `release/vm-0.6.6-variable-coin-events` at `7605554e72112f2aa9a4503400c5a93adecb28e9`

Ballistic baseline: `release/vm-0.6.8-ballistic-abundance` at `4b03374eff708b77f69da0e3f447ba379886b6fd`

Experiment branch: `release/vm-0.6.9-ballistic-integrity`

## Evidence, hypothesis and decision

Founder review prefers the ballistic direction conceptually and reported possible stutter, but no fresh-player evidence supports making Standard harder. VM-0.6.8 deterministic runs also showed that selected doubles/triples often degraded while their siblings were attempted independently. These are separate questions: the implementation measured performance before changing the planner.

The hypothesis under test is that bounded group planning plus correction of confirmed planning hotspots will preserve more selected multi-coin events without changing Standard difficulty, D3 authority or the established event rhythm.

The approved decision is one isolated validation pass. VM-0.6.6 remains the fallback/control; VM-0.6.8 remains the preserved ballistic baseline. Standard difficulty is unchanged. Experienced-player challenge remains assigned to score optimization and the postponed Overload Mode, not to making first-time Standard more punishing. Hazard-Earned Ballistic Refund Coins remain a postponed hypothesis.

## Reproducible profiling method

`tests/profile_vm069_performance.gd` runs a fixed 120 Hz, 60-second deterministic simulation with seeds 401, 1701 and 4202. It can switch the same current code between VM-0.6.6, VM-0.6.8 and VM-0.6.9 feature paths. The stress fixture adds three valid moving landed cans at 20 seconds while natural coin events, ricochets and D3 continue. It records CPU duration around each simulated step, event-planning duration, placement attempts, trajectory checks, landed-can geometry queries, active coins, active hazards, landed cans and ricochet steps.

This is an intentionally synthetic CPU profile. Its sub-millisecond median/p95/p99 values are not monitor frame times; the worst values expose synchronous planning stalls. The injected cans can temporarily block D3 lanes, so the stress fixture is not used for D3 cadence acceptance. Separate natural runs verify the frozen six-event D3 schedule.

Reproduce the stress profile:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --rendering-method gl_compatibility \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  --script res://tests/profile_vm069_performance.gd
```

Add `-- --natural` for the natural-lifecycle scenario, or `-- --mode=VM069` to restrict one feature path.

## Performance evidence before correction

In the same three-seed stress scenario, VM-0.6.6 and VM-0.6.8 both had rare synchronous planning stalls. VM-0.6.8 was worse. Ricochet-active steps averaged below 0.60 ms in every baseline run, while individual event-planning calls reached 155.10 ms in VM-0.6.6 and 210.63 ms in VM-0.6.8. The confirmed bottleneck was bounded-but-expensive placement planning: repeated numerical conveyor-distance integration, lifetime simulation and landed-can geometry collection across thousands of candidate attempts. Ricochet micro-stepping was not a meaningful hotspot and was left unchanged.

The table reports the median seed for percentile/worst columns and the total slow simulated steps across all three 60-second seeds:

| Metric | VM-0.6.6 static | VM-0.6.8 ballistic | VM-0.6.9 integrity |
|---|---:|---:|---:|
| Median CPU step | 0.019 ms | 0.023 ms | 0.024 ms |
| p95 CPU step | 0.032 ms | 0.046 ms | 0.087 ms |
| p99 CPU step | 0.123 ms | 0.155 ms | 0.339 ms |
| Median seed's worst step | 146.911 ms | 200.743 ms | 43.818 ms |
| Worst-step range across seeds | 123.233–155.155 ms | 155.819–210.673 ms | 43.469–53.746 ms |
| Steps over 16.67 ms, three seeds | 57 | 72 | 22 |
| Steps over 33.33 ms, three seeds | 30 | 59 | 12 |
| Mean event-planning duration | 27.769 ms | 56.959 ms | 8.664 ms |
| Maximum event-planning duration | 155.100 ms | 210.635 ms | 53.696 ms |

VM-0.6.9's p95/p99 are slightly higher but remain below 0.4 ms in this CPU harness. The material result is the reduction in rare planning stalls: mean planning fell 84.8 percent versus VM-0.6.8, maximum planning fell 74.5 percent, and steps over 33.33 ms fell from 59 to 12. Rare 43–54 ms planning events still exist; this pass reduces rather than eliminates the worst-case search.

## Optimizations actually made

- Conveyor distance during integrity planning now uses bounded composite Simpson integration instead of hundreds of 120 Hz samples. Existing runtime conveyor physics is unchanged.
- Post-contact time-to-left-exit uses a bounded binary solve against that distance integral instead of another 120 Hz lifetime walk.
- Landed-can collision rectangles are cached once per physics frame for integrity-mode planning/runtime queries and explicitly rebuilt on the next frame. Tests cover reuse and invalidation.
- Single events use one direct bounded search. Only selected pairs/triples build candidate pools.
- Pair/triple search is bounded to four candidate options per sibling, 12 placement attempts per option and 64 combination checks. No unbounded combinatorial search was introduced.

Profiling counters are disabled by default. They are enabled only by the profiling harness or explicit developer configuration. No network analytics or identifying data is recorded.

## Group-planning architecture and integrity evidence

VM-0.6.9 plans a requested pair/triple before spawning any sibling. Each sibling receives individually valid candidate options. The bounded combination search then checks time-aligned flight separation, time-aligned post-contact separation, active-opportunity separation and one common D3-safe lane. A full triple is attempted first, then a pair, then a single; a full double falls back only to a single. Every degradation records a reason.

Time alignment matters for staggered events: two different landing coordinates are not treated as if they touch the belt simultaneously. The earlier coin's conveyor displacement is included before the later coin lands. This removes a confirmed false rejection without weakening collision/readability clearance.

Natural 60-second deterministic runs produced:

| Build | Seed deliveries | Selected doubles | Full doubles | Double integrity | Selected triples | Full triples | Triple integrity |
|---|---:|---:|---:|---:|---:|---:|---:|
| VM-0.6.8 | 39 / 34 / 37 | 39 | 14 | 35.9% | 11 | 1 | 9.1% |
| VM-0.6.9 | 41 / 38 / 39 | 44 | 23 | 52.3% | 7 | 1 | 14.3% |

Double integrity improved by 16.4 percentage points and one selected triple survived as a complete three-coin event. Triple evidence remains sparse because the unchanged weight selects triples only 10 percent of the time; human review must determine whether that frequency is sufficient. Delivered opportunity remains close to the directional 35–40 target, with one run at 41. Requested cadence and 55/35/10 weights were not increased to force the result.

Each natural run retained six D3 warnings at approximately 8.50, 17.04, 24.61, 33.40, 40.60 and 48.36 seconds, with an 8.792-second longest gap and zero coin-caused D3 delay.

## Human-play telemetry

At death or completion, VM-0.6.9 prints one concise `VM069_COIN_SUMMARY` JSON line to the Godot output or browser console. It includes delivered/collected coins, AIRBORNE/BOUNCING/SETTLED collections, EXPIRED, EXITED_LEFT, collection rate, average launch-to-collection time, ricochets, selected singles/doubles/triples, full/degraded doubles/triples, integrity rates and degradation reasons. The idempotent round-stop guard prevents a second summary for the same run.

## Web and WebGL investigation

The single-threaded VM-0.6.9 Web export loaded from localhost, entered gameplay and emitted its run summary without a JavaScript or game-code error. Automated Chromium repeated these warnings:

```text
WebGL: INVALID_OPERATION: bindBuffer: element array buffers can not be bound to a different target
WebGL: INVALID_OPERATION: bufferSubData: no buffer
```

The same two warnings, twice, occur in preserved VM-0.6.6 and VM-0.6.8 exports. VM-0.6.6 has no ballistic code, so they are not caused specifically by ballistic planning. They appear during Godot/Web rendering startup or run transitions and did not correspond to a game-code exception. A project-side rendering defect was not identified. Whether the founder's normal itch.io browser reproduces them remains unverified.

Equal 30-second foreground `requestAnimationFrame` windows for all three builds showed approximately 120 Hz, 8.3 ms median and 9.8–9.9 ms p95 with no frame over 16.67 ms. However, an unattended player dies early, so most of those windows observe results/menu rendering rather than sustained stressful gameplay. They are valid Web load/render smoke checks, not the primary gameplay-performance evidence. The native deterministic profile above is the controlled sustained-gameplay comparison.

## Validation result

- Focused VM-0.6.9 integrity/cache/telemetry coverage passed.
- Natural seeds verified 23/44 full doubles, 1/7 full triples, 41/38/39 deliveries, cap five and the frozen six-event D3 schedule.
- The same seeded stress fixture was rerun after correction.
- VM-0.6.6 and VM-0.6.8 preserved build directories and branches were not modified.
- The full automated suite passed **42 of 42 scripts**, including unchanged VM-0.6.6, VM-0.6.7 and VM-0.6.8 regressions.
- Standard launched headlessly for 180 frames; the frozen Arena and Conveyor scenes each launched for 120 frames. All three exited zero. The recurring macOS CA-certificate diagnostic remained; no scene script/parse failure occurred.
- The release Web export is single-threaded and loads through localhost without a JavaScript/game-code error.
- The ZIP contains all nine generated files with `index.html` at archive root.
- Git branch/commit/remote verification is recorded in the task handoff after the validated commit is pushed.

Automated checks establish bounded planning, technical safety and measurable integrity improvement. They do not establish that ballistic coins are more fun, that every triple is readable, that mobile performance is acceptable, or that VM-0.6.9 should replace VM-0.6.6.

## Builds

- VM-0.6.6 control: `builds/VM-0.6.6-VARIABLE-COIN-EVENTS/`
- VM-0.6.8 baseline: `builds/VM-0.6.8-BALLISTIC-ABUNDANCE/`
- VM-0.6.9 experiment: `builds/VM-0.6.9-BALLISTIC-INTEGRITY/`
- VM-0.6.9 ZIP: `builds/VM-0.6.9-BALLISTIC-INTEGRITY.zip`
- Export preset: `Web GET CANNED VM-0.6.9 Ballistic Integrity`

Generated build artifacts remain ignored and are not committed.
