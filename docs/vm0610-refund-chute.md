# VM-0.6.10 — Refund Chute Integration Prototype

Recorded: 2026-09-20 JST

Control: `release/vm-0.6.9-ballistic-integrity` at `5842c5d12bd23f0620058014cd3ef2d6978c39a6`

Prototype branch: `release/vm-0.6.10-refund-chute`

## Evidence, hypothesis, control and decision

**Evidence:** Founder review prefers the ballistic direction conceptually, a second player independently described VM-0.6.9 as more fun, and the accepted ballistic implementation had no visible physical source. Work selected Concept C, a compact angled Refund Hopper, for an in-motion integration test.

**Hypothesis:** One visible angled Refund Chute can plausibly source SHALLOW, MEDIUM, HIGH, simultaneous-double and staggered-multi ballistic Refund Coins while improving visual cause and effect.

**Control:** VM-0.6.9 retains its three prototype launch origins and remains preserved on its own branch and in its existing build.

**Prototype:** VM-0.6.10 uses the same VM-0.6.9 event cadence, trajectory durations, landing selection, coin behavior and difficulty, but moves accepted ballistic launch points into the Concept C mouth and cues the chute before release.

**Decision:** This is an integration candidate, not an adoption decision. Do not begin VM-0.7.0 until the chute and all six deterministic review cases have been reviewed in motion.

## Concept C runtime contract

- Visual top-left: `(692,338)`
- Visual size: `84×66`
- Nominal emitter centre: `(732,374)`
- Approved diagonal emitter segment: `(714,380)` to `(746,368)`
- Single-launch variation: nominal X ±6 px, projected onto that segment
- Visual states: `IDLE`, `PRE_EJECT`, `OPEN`
- PRE-EJECT: 150 ms
- OPEN: begins at first launch and remains through the final sibling plus 150 ms
- Chute body Z: 2; front lip Z: 13; Refund Coin Z remains 12, so a coin visibly crosses behind the lip
- Collision: none. The chute is presentation-only.

The four PNGs in `assets/vm0610_refund_chute/` are exact project-created exports from the approved Work Concept C package. Their hashes and source path are recorded in that directory's `PROVENANCE.md`. No raw third-party source or unrelated Work scratch file was copied.

## Trajectory mapping

The existing 0.72/0.90/1.10-second SHALLOW/MEDIUM/HIGH durations, 1250 px/s² gravity, landing candidates and post-contact behavior remain authoritative. For each accepted landing point, the director solves velocity from the selected mouth point to that landing over the existing duration. The old trajectory character is therefore retained without retaining the old unrelated origins.

For the deterministic review target `(430,572)` from nominal `(732,374)`, the representative solutions are:

| Family | Duration | Initial velocity | Character |
|---|---:|---:|---|
| SHALLOW | 0.72 s | approximately `(-419.4,-175.0)` px/s | flatter, faster horizontal travel |
| MEDIUM | 0.90 s | approximately `(-335.6,-342.5)` px/s | intermediate arc |
| HIGH | 1.10 s | approximately `(-274.5,-507.5)` px/s | highest arc and longest airtime |

Normal events retain the existing bounded ±7.5% duration variation. The new launch position is varied only inside the documented mouth segment.

Simultaneous doubles use opposite endpoints of the 34.18 px mouth segment. The global 44 px trajectory separation remains unchanged. A chute-only grace is permitted for at most 100 ms after each coin's own launch and only while each coin remains within 50 px of its own mouth origin. Immediately after that bound, the normal 44 px rule applies. Staggered doubles and triples retain their existing event rhythm; the deterministic triple review uses 0/140/280 ms sibling offsets after the 150 ms preparation.

## Deterministic visual review

The developer-only scene `scenes/tests/refund_chute_trajectory_review.tscn` bypasses RNG and exposes six cases:

1. SHALLOW single
2. MEDIUM single
3. HIGH single
4. simultaneous DOUBLE
5. staggered DOUBLE
6. staggered TRIPLE

Number keys select a case; `R` replays SHALLOW. The harness freezes the normal hazard, round, conveyor and player simulation so only the launch under review moves. It does not exist in the production UI and does not award score.

The 60 fps, 1152×648 review recording is `builds/validation-vm0610/refund-chute-review.avi`; the summary image is `builds/validation-vm0610/refund-chute-contact-sheet.png`. Technical inspection confirms that all six cases begin at the physical mouth, singles retain distinct arc heights, the simultaneous pair is visibly distinct at release, and the staggered triple ejects sequentially. Whether HIGH feels physically plausible and whether the rapid multi-ejection is sufficiently readable are subjective and remain for Startup Lab review.

## Deterministic behavior evidence

The targeted suite verifies the exact position/size/layer contract, non-collision, all three visual states, final-sibling hold, round-end reset, shared emitter bounds, deterministic family endpoints, bounded simultaneous-mouth grace, restoration of normal separation, a real planned simultaneous double, a real planned staggered triple, cap five, unchanged score in the review harness and the frozen D3 schedule.

Three natural 60-second VM-0.6.10 seeds delivered `38 / 41 / 34` coins and never exceeded the five-coin cap. All six D3 warnings occurred at approximately `8.50, 17.04, 24.61, 33.40, 40.60, 48.36` seconds with an 8.792-second maximum gap and no coin-caused D3 rejection.

There is one important compatibility result: shared-mouth geometry reduced natural complete multi-event integrity in these seeds. VM-0.6.10 retained `16/46` selected doubles (34.8%) and `0/10` selected triples as complete groups, versus VM-0.6.9's recorded `23/44` doubles (52.3%) and `1/7` triples (14.3%). Controlled double/triple review cases work, but the full natural planner more often rejects siblings for geometry. The integration does not weaken safety or secretly convert triples to simultaneous launches to hide this. Startup Lab must decide after visual review whether this is acceptable, whether a future narrowly approved very-short-stagger rule should be tested, or whether Concept C is incompatible with the desired natural multi-event integrity.

## Performance comparison

The same three-seed 60-second stress harness was run sequentially against current-code VM-0.6.9 and VM-0.6.10 paths:

| Metric | VM-0.6.9 control path | VM-0.6.10 chute path |
|---|---:|---:|
| Mean event planning, mean of seeds | 7.377 ms | 7.535 ms |
| Maximum event planning | 44.586 ms | 44.207 ms |
| p95 CPU-step range | 0.040–0.045 ms | 0.039–0.042 ms |
| p99 CPU-step range | 0.064–0.071 ms | 0.062–0.070 ms |
| Worst-step range | 37.444–44.612 ms | 36.963–44.248 ms |
| Steps over 16.67 ms, all seeds | 22 | 17 |
| Steps over 33.33 ms, all seeds | 7 | 7 |

The chute path's mean planning value was 2.1% higher, while its maximum and CPU-step tails were slightly lower in this run. This is normal run-to-run variance rather than evidence of an improvement; it does not show a meaningful regression. It remains below the previously recorded VM-0.6.9 mean/max of 8.664/53.696 ms.

## Validation result

- Focused VM-0.6.7, VM-0.6.8, VM-0.6.9 and VM-0.6.10 tests passed.
- The complete repository suite passed **43 of 43 scripts** in one final pass.
- Standard ran headlessly for 180 frames. D2, frozen Prototype A and the original Prototype B scene each ran headlessly for 120 frames. All exited zero.
- The recurring macOS CA-certificate diagnostic appeared in headless runs; there was no script, parser, scene or assertion failure.
- The single-threaded Web export completed and produced nine files.
- The ZIP contains those nine files with `index.html` at archive root.
- The Web build loaded through localhost in the in-app browser. The main menu rendered, Enter started gameplay, the chute rendered in the active scene, and the captured browser console contained no warnings or errors.
- Normal-speed visual evidence was rendered as a 60 fps, 12.1-second MJPEG review movie containing all six deterministic cases.

Automated and rendered checks establish geometry, timing, state cleanup, regression safety and reproducible trajectories. They do not establish that Concept C is sufficiently convincing, that HIGH feels physically plausible, or that reduced natural multi-event integrity is an acceptable tradeoff.

## Preserved and deferred

Unchanged: Standard difficulty, movement, jump, conveyor, hazards, D3 cadence, 60-second round, coin value, score, event cadence/weights, five-coin cap, landing selection, bounce, can collision and telemetry. The existing teaching event still exists; only its ballistic release is visually sourced from the chute in this opt-in build.

Deferred to an explicitly approved later milestone: a new static teaching coin, `SUPPORTED_ON_CAN`, stuck-coin footprint correction, Standard difficulty, Overload Mode and Hazard-Earned Refund Coins.

## Run locally

Repository:

```text
/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter
```

Normal prototype:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  res://scenes/presentation/standard_session.tscn
```

Deterministic six-case gallery:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  res://scenes/tests/refund_chute_trajectory_review.tscn
```

Press `1` through `6` for the cases listed above. Watch whether the coin begins under the front lip, whether MEDIUM and HIGH visibly differ from SHALLOW, whether HIGH appears propelled by the same angled mechanism rather than changing direction magically, whether both simultaneous coins remain distinguishable, and whether all sequential siblings leave before the hopper closes. The close 34 px starting pair is intentional; normal 44 px separation must be visible after the first 100 ms / 50 px.

Normal controls: `A/D` or `LEFT/RIGHT` to move, `SPACE` to jump, `R` to restart, `ESCAPE` to pause/menu where available.

Web build: `builds/VM-0.6.10-REFUND-CHUTE/`

ZIP: `builds/VM-0.6.10-REFUND-CHUTE.zip`

Serve locally:

```sh
python3 -m http.server 8160 --bind 127.0.0.1 \
  --directory /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.10-REFUND-CHUTE
```

Open `http://127.0.0.1:8160/index.html`.

Performance output is printed as `VM069_NATIVE_PROFILE` JSON by:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --log-file /tmp/vm0610-profile.log \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  --script res://tests/profile_vm069_performance.gd -- --mode=VM0610
```

Generated builds, recordings and screenshots remain ignored by Git and were not uploaded.
