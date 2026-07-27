# Vending Machine Survival

Gray-box core-loop experiment comparing:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.2.2-A
**Phase:** Prototype A — compact arena  
**Prototype A gameplay evidence:** One limited informal observation

The default scene is the compact-arena prototype using the locked VM-0.1.2 `CharacterBody2D` player. Build VM-0.2.2-A adds validated one- and two-can warning patterns to the temporary-platform baseline without changing the controller, telegraph curve, fall-speed curve, cooldown curve, six-second landed lifetime, or two-platform cap. Pattern selection uses seven logical lanes, rejects occupied or impassable configurations before commitment, and delays when no valid pattern exists. This concurrent-pattern experiment requires manual evaluation and is not a validated difficulty result.

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

Play Build VM-0.2.2-A without changing parameters. Confirm that early play uses single cans, occasional paired warnings appear after 15 seconds, and paired warnings become more common after 35 seconds. For every pair, verify that both warning columns map to their exact cans, at least one understandable response remains, and existing platforms never disappear merely because a pattern was attempted. Record observations before tuning or adding content.

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

## Cost

No OpenAI API or separately billed paid API is used by this starter project. Cumulative separately billed project cost: **$0.00**.

See [`docs/cost-usage.md`](docs/cost-usage.md) for the task ledger and unavailable usage fields.
