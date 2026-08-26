# Vending Machine Survival

Gray-box survival prototype developed from an initial comparison between:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.4.7 external-playtest cleanup baseline

**Phase:** Frozen gray-box core loop; VM-0.5.0-MOTION-02 D3 frequency stress test awaiting five-run founder review
**Gameplay evidence:** A broader external playtest reported positive difficulty and replay reactions, and at least one tester deliberately pursued Refund Coins, accepted extra risk, and died because of that choice. This supports the intended survival-versus-score tension strongly enough to freeze the gray-box loop, subject to the limitations recorded in the roadmap. One tester missed the countdown, but the issue was not independently repeated after VM-0.4.4, so the timer was not redesigned again.

Prototype B is now the primary direction. Prototype A remains preserved as a frozen comparison baseline and a possible future machine-jam event; that event is not implemented. The source project defaults to Prototype B for editor F5 testing.

Prototype A is frozen on `master` and tag `VM-0.2.3-A-R1`. Its scene remains available at `scenes/prototypes/arena.tscn`.
Prototype B's first externally preferred baseline is tagged `VM-0.3.4-B-EXTERNAL-PREFERRED`. The accepted endless collectible baseline is tagged `VM-0.4.0`. VM-0.4.1 defaults to a configurable 60-second round with Refund Coins as the only score; an exported `fixed_round_enabled` development setting can restore endless behavior.

The branch `visual/vm-0.5.0-motion-01` contains two isolated internal wrappers around the unchanged conveyor scene. D2 remains the unmodified 1152×480 fallback. D3 is now the `VM-0.5.0-MOTION-02-D3-STRESS` build: a 1152×648 close-up with six recurring, safety-validated background drops per deterministic 60-second run. Each accepted drop reserves suppression of one ordinary product event, so the experiment changes source and vertical pressure rather than adding product hazards. The project-wide F5 scene remains the frozen conveyor baseline.

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

Complete the documented five-run D3 stress test and return the recordings and
observations to Startup Lab. Do not select D2 or D3, tune the stress frequency,
merge this experiment branch, add another motion concept, or start production
art before that review. Player movement, the 60-second round, hazards, Refund
Coin value and scoring, countdown, core offer system, conveyor speed curve, and
Sweeper behavior remain frozen except for a reproducible bug or fairness
failure.

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
