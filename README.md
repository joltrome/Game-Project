# Vending Machine Survival

Gray-box core-loop experiment comparing:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-EXT-AB / VM-EXT-BA browser-playtest distribution

**Phase:** Frozen Prototype A/B external comparative playtest preparation
**Gameplay evidence:** Prototype A and Prototype B are frozen for the first external comparison; the browser distribution is an implementation result, not new gameplay evidence.

The source project still defaults to Prototype B for editor F5 testing. The Web AB and Web BA export presets instead launch one shared neutral session flow. Each game lasts 60 seconds, restarts remain available with `R`, and the order is fixed by the selected export preset rather than by the tester.

Prototype A is frozen on `master` and tag `VM-0.2.3-A-R1`. Its scene remains available at `scenes/prototypes/arena.tscn`.
Prototype B is frozen at Build VM-0.3.4-B on this branch.

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
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web AB" builds/web-ab/index.html
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web BA" builds/web-ba/index.html
```

The generated files are ignored by Git. Each upload archive must have
`index.html` at its root:

```bash
(cd builds/web-ab && zip -r ../vending-machine-playtest-ab.zip .)
(cd builds/web-ba && zip -r ../vending-machine-playtest-ba.zip .)
```

The Web canvas is 1152 × 648. Serve a directory over HTTP rather than opening
`index.html` directly:

```bash
python3 -m http.server 8123 --directory builds/web-ab
python3 -m http.server 8124 --directory builds/web-ba
```

## Use with Codex

1. Open this repository folder in the ChatGPT desktop app's Codex view, Codex CLI, or the Codex IDE extension.
2. Read `AGENTS.md` before changing code.
3. Open `docs/roadmap.html` in a browser and use **Copy Codex handoff** for a current task brief.
4. Commit after each runnable milestone.

## Next validation task

Return to Startup Lab with the completed AB/BA distribution report before
uploading or publishing. After approval, create two separately assigned itch.io
HTML pages so testers cannot choose their order. Do not tune either frozen game
between assignments.

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

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
