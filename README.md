# Vending Machine Survival

Gray-box core-loop experiment comparing:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.3.2-B

**Phase:** Prototype B — opposing-height hazard experiment
**Gameplay evidence:** VM-0.3.1-B had a dominant hold-right-and-jump strategy; VM-0.3.2-B is pending manual review

The Prototype B branch defaults to a separate fixed-camera conveyor scene using the unchanged VM-0.1.2 `CharacterBody2D` player. The belt and landed cans retain the same -140 px/s physical support velocity. VM-0.3.2-B replaces the old x=280 instant-death check with a visible conveyor end at x=160 and an explicit recessed off-belt kill region. It also adds one fixed-height left-to-right service arm: its 96×28 px collision band is centered at y=460, clears grounded players, intersects the ordinary jump arc, and reaches screen center 1.20 seconds after visible entry at 520 px/s. A deterministic scheduler cycles can-only, sweeper-only, sweeper-then-can, and can-then-sweeper patterns. Automated checks pass; the effect on decision quality and perceived fairness remains a hypothesis pending manual review.

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

Play Build VM-0.3.2-B without changing parameters. Hold right continuously and note whether the service arm actually interrupts the previous automatic-jump strategy. Stay grounded beneath one arm, then deliberately jump early into another; grounded passage should be safe and airborne contact should kill once. During sweeper-then-can, wait for the arm before jumping the can. During can-then-sweeper, try jumping early enough to land before the arm arrives. At the left edge, confirm touching the orange conveyor-end lip is non-lethal and standing on a can there is safe; allow the can to leave so the player visibly falls into the recessed retrieval opening before death. Record readability, unavoidable states, and whether early versus delayed jumps are distinguishable. Do not tune offsets or add hazards before Startup Lab review.

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

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
