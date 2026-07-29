# Vending Machine Survival

Gray-box core-loop experiment comparing:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.3.3-B

**Phase:** Prototype B — final internal intensity tuning
**Gameplay evidence:** VM-0.3.2-B is structurally coherent but its sweeper patterns were too infrequent to displace the hold-right-and-jump strategy

The Prototype B branch defaults to a separate fixed-camera conveyor scene using the unchanged VM-0.1.2 `CharacterBody2D` player. VM-0.3.3-B replaces the fixed pattern cycle with a deterministic four-phase intensity director. The 0–5 second teaching phase guarantees can-only and sweeper-only patterns. The 5–12 second phase weights patterns 20/20/30/30 across can-only, sweeper-only, sweeper-then-can, and can-then-sweeper; 12–20 seconds uses 10/10/40/40; 20+ uses 0/0/50/50. Compound response margins narrow continuously from 1.10 seconds at 5 seconds to a 0.50-second floor at 40 seconds. Empty cooldown narrows from 1.60 to 0.50 seconds over the same checkpoints. Conveyor speed remains 140 px/s; can and sweeper speeds begin a continuous 12% maximum ramp after 15 seconds. These are intensity hypotheses, not validated balance results.

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

Play Build VM-0.3.3-B without changing parameters. On the first run, blindly hold right and jump whenever a can approaches; record whether and when that strategy fails. On later runs, deliberately wait grounded for sweeper-then-can patterns, and jump early enough to land during can-then-sweeper patterns. Continue beyond 20 seconds and note whether the tighter cadence remains readable. Record the time and cause of every death that feels unavoidable or visually unclear. Do not tune values or begin external playtesting until Startup Lab reviews this internal result.

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

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
