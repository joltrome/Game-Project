# Vending Machine Survival

Gray-box survival prototype developed from an initial comparison between:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.4.0 optional collectible experiment on the conveyor direction

**Phase:** First post-comparison experiment on the selected conveyor direction
**Gameplay evidence:** In a first external comparison of approximately five testers, everyone understood the objective and voluntarily restarted at least once. The overwhelming preference was for the conveyor. This is a small sample and does not establish broad retention or final balance.

Prototype B is now the primary direction. Prototype A remains preserved as a frozen comparison baseline and a possible future machine-jam event; that event is not implemented. The source project defaults to Prototype B for editor F5 testing.

Prototype A is frozen on `master` and tag `VM-0.2.3-A-R1`. Its scene remains available at `scenes/prototypes/arena.tscn`.
Prototype B's first externally preferred baseline is tagged `VM-0.3.4-B-EXTERNAL-PREFERRED`. VM-0.4.0 adds one optional, non-solid, current-run collectible experiment without changing the player or existing hazards.

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

Manually test VM-0.4.0 and return to Startup Lab before changing it. Observe
whether you voluntarily leave the safest area, whether collection creates
meaningful risk, whether missing one encourages another run, whether the pickup
distracts from survival readability, and whether ignoring every pickup remains
the safest dominant strategy.

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

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
