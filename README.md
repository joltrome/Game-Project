# Vending Machine Survival

Gray-box core-loop experiment comparing:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.3.1-B

**Phase:** Prototype B — minimum fixed-camera conveyor
**Gameplay evidence:** Physical conveyor pressure pending manual review

The Prototype B branch defaults to a separate fixed-camera conveyor scene using the unchanged VM-0.1.2 `CharacterBody2D` player. Build VM-0.3.1-B gives the belt and landed cans the same physical support velocity. Grounded input remains direct and relative to that support: no input moves left at 140 px/s, right input moves right at a net 160 px/s, and left input moves left at a net 440 px/s. Jump takeoff inherits the support velocity once, then remains independent while airborne. Single warned drops remain the only hazard. Deterministic tests measured the first warning at 0.850 seconds, first belt impact at 1.867 seconds, and passive left-boundary failure at 2.683 seconds. Gameplay pressure and fairness remain hypotheses pending manual review.

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

Play Build VM-0.3.1-B without changing parameters. First release all input and confirm the belt physically carries the grounded player left toward failure. Confirm right input recovers position and left input combines with the belt. Jump without horizontal input from both the belt and a landed can; horizontal motion should continue naturally while airborne, and a vertical jump from a can should return near the same relative can position. Check belt-to-can and can-to-belt transitions for jitter or speed resets. Record the first-warning, first-impact, and first-required-response feel. Observe the possible hold-right-and-jump exploit, but do not tune or add paired drops before manual review.

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

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
