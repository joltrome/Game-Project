# Vending Machine Survival

Gray-box core-loop experiment comparing:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.3.4-B

**Phase:** Prototype B — final elevated-state and right-edge correction
**Gameplay evidence:** Manual VM-0.3.3-B testing found that can-top camping remained safe and player-relevant Sweeper Arm encounters were too infrequent to displace right-edge hold-and-jump play

The Prototype B branch defaults to a separate fixed-camera conveyor scene using the unchanged VM-0.1.2 `CharacterBody2D` player. VM-0.3.4-B derives one fixed Sweeper Arm band from actual player and can collision dimensions: the grounded player remains below it, while can-top standing and 0.300 seconds of the normal jump overlap it. The scheduler now records physical player-region arrivals rather than treating pattern selection as an encounter. A 72 px right-edge zone reserves a normally telegraphed compound pressure pattern after 1.0 second of continuous dwell. Constant-velocity geometry and timing checks pass; whether the correction is readable, fair, and sufficient against the observed dominant strategies remains a hypothesis pending manual review.

Prototype A is frozen on `master` and tag `VM-0.2.3-A-R1`. Its scene remains available at `scenes/prototypes/arena.tscn`.

## Open locally

1. Install Godot 4.x.
2. In Godot Project Manager, choose **Import**.
3. Select this folder's `project.godot`.
4. Open the project and press **F5** for Prototype B.

## Switch prototypes in Godot

- Prototype B: open `scenes/prototypes/conveyor.tscn` and press **F6**, or press **F5** on this branch.
- Prototype A: open `scenes/prototypes/arena.tscn` and press **F6**.
- To switch back to B immediately, select the already open `conveyor.tscn` tab and press **F6** again. This does not edit either scene or require changing branches.

## Use with Codex

1. Open this repository folder in the ChatGPT desktop app's Codex view, Codex CLI, or the Codex IDE extension.
2. Read `AGENTS.md` before changing code.
3. Open `docs/roadmap.html` in a browser and use **Copy Codex handoff** for a current task brief.
4. Commit after each runnable milestone.

## Next validation task

Play Build VM-0.3.4-B without changing parameters. Verify that an arm passes over a grounded player, kills a player standing on a can, and can be avoided by stepping down before it arrives. Try ordinary jumps through the arm band. Briefly visit the right edge, then leave; no targeted pressure should follow. On a separate run, remain at the right edge for more than one second and test blind immediate jumping, moving left, and delaying until the arm passes. Record the exact time and pattern for every unclear or apparently unavoidable death. Do not tune further or begin external playtesting until Startup Lab reviews this final correction.

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

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
