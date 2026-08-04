# Vending Machine Survival

Gray-box survival prototype developed from an initial comparison between:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.4.5 score visibility and differentiated Refund Coin routes

**Phase:** External readability testing of the fixed-round conveyor loop
**Gameplay evidence:** The first external comparison selected the conveyor, subsequent manual testing accepted the optional collectible as proactively motivating, and Startup Lab review accepted the VM-0.4.4 top-centre countdown for the next build. Whether VM-0.4.5's central score and differentiated routes improve score awareness and deliberate route choice remains unverified.

Prototype B is now the primary direction. Prototype A remains preserved as a frozen comparison baseline and a possible future machine-jam event; that event is not implemented. The source project defaults to Prototype B for editor F5 testing.

Prototype A is frozen on `master` and tag `VM-0.2.3-A-R1`. Its scene remains available at `scenes/prototypes/arena.tscn`.
Prototype B's first externally preferred baseline is tagged `VM-0.3.4-B-EXTERNAL-PREFERRED`. The accepted endless collectible baseline is tagged `VM-0.4.0`. VM-0.4.1 defaults to a configurable 60-second round with Refund Coins as the only score; an exported `fixed_round_enabled` development setting can restore endless behavior.

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

## Use with Codex

1. Open this repository folder in the ChatGPT desktop app's Codex view, Codex CLI, or the Codex IDE extension.
2. Read `AGENTS.md` before changing code.
3. Open `docs/roadmap.html` in a browser and use **Copy Codex handoff** for a current task brief.
4. Commit after each runnable milestone.

## Next validation task

Run fresh-tester VM-0.4.5 sessions without explaining the offer categories. Record
whether the central score is noticed, whether most routes require a second input
after the first coin, whether players intentionally abandon risky extensions,
whether aerial and staggered routes remain readable beside hazards, and whether
compact offers feel distinct. Do not tune from developer preference alone.

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

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
