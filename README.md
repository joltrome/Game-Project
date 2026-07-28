# Vending Machine Survival

Gray-box core-loop experiment comparing:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.2.3-A-R1

**Phase:** Prototype A — compact arena  
**Prototype A gameplay evidence:** Limited internal observations

The default scene is the compact-arena prototype using the locked VM-0.1.2 `CharacterBody2D` player. Build VM-0.2.3-A-R1 preserves the aggressive pacing and rolling terrain while correcting wall-hug camping. Fourteen symmetric logical lanes are derived from the arena and can collision geometry, covering every reachable player center. A configurable one-second edge dwell reserves a normal warned single or pair containing the corresponding wall-adjacent lane, retaining the request when current terrain or fairness checks make it temporarily invalid. Anti-camping effectiveness and perceived fairness remain unvalidated until manual review.

## Open locally

1. Install Godot 4.x.
2. In Godot Project Manager, choose **Import**.
3. Select this folder's `project.godot`.
4. Open the project and press **F6/F5**.

## Use with Codex

1. Open this repository folder in the ChatGPT desktop app's Codex view, Codex CLI, or the Codex IDE extension.
2. Read `AGENTS.md` before changing code.
3. Open `docs/roadmap.html` in a browser and use **Copy Codex handoff** for a current task brief.
4. Commit after each runnable milestone.

## Next validation task

Play Build VM-0.2.3-A-R1 without changing parameters. Test both walls separately: briefly touch the wall and leave, then remain against it for more than one second. Confirm brief use is not singled out, sustained camping eventually produces a normally warned wall-adjacent drop, the warning and chute align exactly, and an inward escape remains reachable. Let an edge can land and verify it sits flush with the wall, remains non-lethal and jumpable, and creates no narrow pocket. Also confirm that the established pacing, rolling terrain, two-chute pairs, and restart behavior remain intact.

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

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
