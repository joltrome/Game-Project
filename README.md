# Vending Machine Survival

Gray-box core-loop experiment comparing:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.2.3-A

**Phase:** Prototype A — compact arena  
**Prototype A gameplay evidence:** Limited internal observations

The default scene is the compact-arena prototype using the locked VM-0.1.2 `CharacterBody2D` player. Build VM-0.2.3-A is a combined experimental pacing correction: piecewise warning and target fall-duration curves accelerate single drops through 12 seconds, paired patterns begin at 12 seconds, post-drop scheduling runs independently of landed capacity, and temporary terrain rolls through a three-platform cap using warned oldest-first removal. Each falling can keeps its own aligned chute visible until landing. The controller and arena dimensions are unchanged. Pacing, fairness, jump usage, and challenge remain unvalidated until manual review.

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

Play Build VM-0.2.3-A without changing parameters. Confirm that single cans visibly accelerate, the first pair appears near 12–13 seconds, and two independent chutes remain aligned with their cans throughout each fall. Watch the orange `REMOVE` warning when rolling terrain exceeds three platforms. Verify that one prior platform remains after paired replacement where possible, the player’s supporting platform is avoided when another can be removed, no long capacity pause returns, and every pattern still presents a reachable response. Record pacing, warning readability, jump usage, and any unavoidable arrangement before tuning.

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
