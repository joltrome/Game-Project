# VM-0.6.0 Standard presentation/audio candidate

F5 now opens the main menu. PLAY starts the accepted S1/P-A/C-A Standard scene. Move with A/D or Left/Right; jump with Space. Results offer RETRY and MENU; R retries, Escape returns from results/credits. Music and SFX have independent mute controls. Best score is local to the device/browser.

The Miraie theme is a temporary composer demo, plays once per session, and has a quiet tail. Final seamless audio and explicit commercial confirmation remain pending. No SFX assets or new gameplay were added.

Review [VM-0.6.0 handoff](docs/vm060-presentation-audio.md) and [audio provenance](docs/audio-source-inventory.md). Export with the `Web Standard RC0` preset to `builds/VM-0.6.0-STANDARD-RC0/index.html`. Do not upload or distribute before Startup Lab review.

The earlier implementation records below are historical. Prototype A, D2, and comparison scenes remain available independently.

---

# Vending Machine Survival

Gray-box survival prototype developed from an initial comparison between:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.5.0-VIS-03-D3-TEST internal runtime candidate

**Phase:** VM-0.5.0-VIS-03 runtime motion/readability review awaiting Startup Lab
**Gameplay evidence:** A broader external playtest reported positive difficulty and replay reactions, and at least one tester deliberately pursued Refund Coins, accepted extra risk, and died because of that choice. This supports the intended survival-versus-score tension strongly enough to freeze the gray-box loop, subject to the limitations recorded in the roadmap. One tester missed the countdown, but the issue was not independently repeated after VM-0.4.4, so the timer was not redesigned again.

Prototype B is now the primary direction. Prototype A remains preserved as a frozen comparison baseline and a possible future machine-jam event; that event is not implemented. The source project defaults to Prototype B for editor F5 testing.

Prototype A is frozen on `master` and tag `VM-0.2.3-A-R1`. Its scene remains available at `scenes/prototypes/arena.tscn`.
Prototype B's first externally preferred baseline is tagged `VM-0.3.4-B-EXTERNAL-PREFERRED`. The accepted endless collectible baseline is tagged `VM-0.4.0`. VM-0.4.1 defaults to a configurable 60-second round with Refund Coins as the only score; an exported `fixed_round_enabled` development setting can restore endless behavior.

The visual experiment lineage contains isolated wrappers around the unchanged conveyor scene. D2 remains the unmodified 1152×480 fallback. D3 remains the 1152×648 close-up with six recurring, safety-validated background drops per deterministic 60-second run. Startup Lab selected the centered 60×60 VIS-02 falling collision. VIS-03 adds the approved rigid-block technician, coherent full rack and lighter lane-local warning in separate clean/debug scenes without retuning gameplay. The project-wide F5 scene remains the frozen conveyor baseline.

## Open locally

1. Install Godot 4.x.
2. In Godot Project Manager, choose **Import**.
3. Select this folder's `project.godot`.
4. Open the project and press **F5** for Prototype B.

## Switch prototypes in Godot

- Prototype B: open `scenes/prototypes/conveyor.tscn` and press **F6**, or press **F5** on this branch.
- Prototype A: open `scenes/prototypes/arena.tscn` and press **F6**.
- To switch back to B immediately, select the already open `conveyor.tscn` tab and press **F6** again. This does not edit either scene or require changing branches.

## Browser playtest exports

Install the matching Godot 4.7.1 export templates, then run:

```bash
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web Current" builds/web-current/index.html
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web AB" builds/web-ab/index.html
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web BA" builds/web-ba/index.html
```

`Web Current` launches only the latest conveyor build. `Web AB` and `Web BA`
remain archived comparative-playtest flows.

The generated files are ignored by Git. Each upload archive must have
`index.html` at its root:

```bash
(cd builds/web-current && zip -r -FS ../vending-machine-current.zip . -x '*.import' '.DS_Store')
(cd builds/web-ab && zip -r ../vending-machine-playtest-ab.zip .)
(cd builds/web-ba && zip -r ../vending-machine-playtest-ba.zip .)
```

The Web canvas is 1152 × 648. Serve a directory over HTTP rather than opening
`index.html` directly:

```bash
python3 -m http.server 8122 --directory builds/web-current
python3 -m http.server 8123 --directory builds/web-ab
python3 -m http.server 8124 --directory builds/web-ba
```

## VM-0.5.0 internal motion variants

Run either wrapper without changing the default project scene:

- D2: open `scenes/experiments/motion_d2.tscn`, then press **F6**.
- D3 stress: open `scenes/experiments/motion_d3.tscn`, then press **F6**. Its visible build ID is `VM-0.5.0-MOTION-02-D3-STRESS`.

Export and serve the internal Web builds:

```bash
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web Motion D2" builds/web-motion-d2/index.html
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web Motion D3 Stress" builds/web-motion-d3-stress/index.html
python3 -m http.server 8120 --directory builds/web-motion-d2
python3 -m http.server 8125 --directory builds/web-motion-d3-stress
```

The generated directories and ZIPs are ignored by Git. See
[`docs/vm050-motion-experiment.md`](docs/vm050-motion-experiment.md) for the
controlled variables, exact D3 lifecycle, validation results, instrumentation,
and original comparison protocol. See
[`docs/vm050-motion02-d3-stress-report.md`](docs/vm050-motion02-d3-stress-report.md)
for the stress cadence, hazard-budget strategy, deterministic reports, and
five-run founder protocol.

## Use with Codex

1. Open this repository folder in the ChatGPT desktop app's Codex view, Codex CLI, or the Codex IDE extension.
2. Read `AGENTS.md` before changing code.
3. Open `docs/roadmap.html` in a browser and use **Copy Codex handoff** for a current task brief.
4. Commit after each runnable milestone.

## Next task

Manually compare `VM-0.5.0-VIS-02-D3-FALL72` and
`VM-0.5.0-VIS-02-D3-FALL60` in Startup Lab. Alternate 72, 60, 60, 72, 60 to
reduce adaptation bias. Do not select a collision, revise art, tune gameplay,
merge the visual branch, or begin another milestone in Codex before that
review. Player movement, the 60-second round, hazards, Refund Coin value and
scoring, countdown, core offer system, conveyor speed curve, D3 cadence, and
Sweeper behavior remain frozen except for a reproducible bug or fairness
failure.

## VM-0.5.0-VIS-03 runtime candidate

Run either scene with F6:

- Clean Startup Lab candidate:
  `scenes/experiments/motion_vis03_test.tscn`
- Developer/debug candidate:
  `scenes/experiments/motion_vis03_debug.tscn`

The clean build hides internal labels, local instrumentation, and overlay
access. It shows only a compact ASCII control hint for four seconds. The debug
build uses the same gameplay values and retains F8 collision/pivot/D3-state
diagnostics. Both select the centered 60×60 falling collision and unchanged
72×48 landed collision.

Run the targeted suite:

```bash
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/vms-vis03-runtime.log --path . --script res://tests/test_vm050_vis03_runtime_integration.gd
```

Export the single-threaded Web builds:

```bash
mkdir -p builds/web-vis03-debug builds/web-vis03-test
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/vms-vis03-debug-export.log --path . --export-release "Web VIS-03 Debug" builds/web-vis03-debug/index.html
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/vms-vis03-test-export.log --path . --export-release "Web VIS-03 Test" builds/web-vis03-test/index.html
```

Serve locally:

```bash
python3 -m http.server 8130 --bind 127.0.0.1 --directory builds/web-vis03-debug
python3 -m http.server 8131 --bind 127.0.0.1 --directory builds/web-vis03-test
```

Prepared internal archives and evidence recordings:

- `builds/VM-0.5.0-VIS-03-D3-DEBUG-web.zip`
- `builds/VM-0.5.0-VIS-03-D3-TEST-web.zip`
- `builds/VM-0.5.0-VIS-03-D3-TEST-motion.mp4`
- `builds/VM-0.5.0-VIS-03-D3-TEST-warning.mp4`

Generated builds and recordings remain ignored and have not been uploaded.
See [`docs/vm050-vis03-runtime-integration.md`](docs/vm050-vis03-runtime-integration.md)
for exact art mapping, validation results, screenshots, and the four-run manual
review protocol.

## VM-0.5.0-VIS-02 collision comparison

Run either current scene with F6:

- 72×72 baseline: `scenes/experiments/motion_vis02_fall72.tscn`
- 60×60 retest: `scenes/experiments/motion_vis02_fall60.tscn`

Both use the exact same VIS-02 art and frozen gameplay. The developer overlay
is OFF by default; press F8 in a local debug run to show collision boxes,
pivots, selected rack lane, D3 state, and `VIS02-FALL-72`/`VIS02-FALL-60` ID.

Run the targeted suite:

```bash
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/vms-vis02-runtime-retest.log --path . --script res://tests/test_vm050_vis02_runtime_retest.gd
```

Export the single-threaded Web builds:

```bash
mkdir -p builds/web-vis02-fall72 builds/web-vis02-fall60
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web VIS-02 Fall 72" builds/web-vis02-fall72/index.html
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web VIS-02 Fall 60" builds/web-vis02-fall60/index.html
```

Serve locally:

```bash
python3 -m http.server 8126 --bind 127.0.0.1 --directory builds/web-vis02-fall72
python3 -m http.server 8127 --bind 127.0.0.1 --directory builds/web-vis02-fall60
```

Prepared internal archives:

- `builds/VM-0.5.0-VIS-02-D3-FALL72-web.zip`
- `builds/VM-0.5.0-VIS-02-D3-FALL60-web.zip`

Generated builds remain ignored by Git and have not been uploaded. See
[`docs/vm050-vis02-runtime-retest.md`](docs/vm050-vis02-runtime-retest.md) for
asset mappings, the landed-Y fix, measured margins, screenshots, validation,
and the manual comparison protocol.

## VM-0.5.0-VIS-01-D3-V2

Open `scenes/experiments/motion_d3.tscn` and run the current scene with `F6`.
The developer collision overlay is OFF by default; press `F8` in a local debug
run to show sprite origins, collision boxes, the selected D3 rack lane, and its
logical state.

Run the VIS-01 integration test:

```bash
godot --headless --log-file /tmp/vms-vm050-vis01-test.log --path . --script res://tests/test_vm050_vis01_integration.gd
```

Export the single-threaded Web build:

```bash
godot --headless --path . --export-release "Web VIS-01 D3 V2" builds/web-vis01-d3-v2/index.html
```

Serve it locally from `builds/web-vis01-d3-v2/`:

```bash
python3 -m http.server 8123 --bind 127.0.0.1
```

Then open `http://127.0.0.1:8123/index.html`. The prepared upload archive is
`builds/VM-0.5.0-VIS-01-D3-V2-web.zip`; generated builds remain ignored by Git.

## Automated movement test

Run the mirrored grounded-reversal scenarios with Godot available on `PATH`:

```bash
godot --headless --log-file /tmp/vms-movement-controller-test.log --path . --script res://tests/test_movement_controller.gd
```

## Automated arena test

```bash
godot --headless --log-file /tmp/vms-arena-test.log --path . --script res://tests/test_arena_loop.gd
```

## Automated landed-can test

```bash
godot --headless --log-file /tmp/vms-landed-can-test.log --path . --script res://tests/test_landed_can_persistence.gd
```

## Automated pattern test

```bash
godot --headless --log-file /tmp/vms-two-can-pattern-test.log --path . --script res://tests/test_two_can_patterns.gd
```

## Automated edge-coverage test

```bash
godot --headless --log-file /tmp/vms-edge-coverage-test.log --path . --script res://tests/test_edge_coverage.gd
```

## Automated conveyor test

```bash
godot --headless --log-file /tmp/vms-conveyor-test.log --path . --script res://tests/test_conveyor_prototype.gd
```

## Automated physical-conveyor test

```bash
godot --headless --log-file /tmp/vms-physical-conveyor-test.log --path . --script res://tests/test_physical_conveyor.gd
```

## Automated sweeper and controlled-pattern test

```bash
godot --headless --log-file /tmp/vms-air-sweeper-test.log --path . --script res://tests/test_air_sweeper_patterns.gd
```

## Automated intensity-director test

```bash
godot --headless --log-file /tmp/vms-intensity-director-test.log --path . --script res://tests/test_intensity_director.gd
```

## Automated elevated-state and right-edge correction test

```bash
godot --headless --log-file /tmp/vms-elevated-right-edge-test.log --path . --script res://tests/test_elevated_right_edge_correction.gd
```

## Automated browser-distribution flow test

```bash
godot --headless --log-file /tmp/vms-playtest-distribution-test.log --path . --script res://tests/test_playtest_distribution.gd
```

## Automated collectible experiment test

```bash
godot --headless --log-file /tmp/vms-collectible-test.log --path . --script res://tests/test_collectible_experiment.gd
```

## Automated fixed-round and Refund Coin test

```bash
godot --headless --log-file /tmp/vms-fixed-round-refund-coin-test.log --path . --script res://tests/test_fixed_round_refund_coin.gd
```

## Automated central score and differentiated-route test

```bash
godot --headless --log-file /tmp/vms-vm045-score-routes-test.log --path . --script res://tests/test_vm045_score_routes.gd
```

## Automated route decision-separation test

```bash
godot --headless --log-file /tmp/vms-vm046-route-decision-test.log --path . --script res://tests/test_vm046_route_decision_separation.gd
```

## Automated motion-experiment test

```bash
godot --headless --log-file /tmp/vms-vm050-motion-test.log --path . --script res://tests/test_vm050_motion_experiment.gd
```

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
