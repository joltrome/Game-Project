# Vending Machine Survival

Gray-box core-loop experiment comparing:

1. A compact arena with left/right movement and jumping.
2. An automatically scrolling conveyor with limited repositioning and jumping.

## Scope lock

No daily challenges, leaderboards, ads, cosmetics, accounts, monetization, meta-progression, or extra modes before voluntary restart behavior is observed.

## Current state

**Build:** VM-0.2.2-A-R1

**Phase:** Prototype A — compact arena  
**Prototype A gameplay evidence:** One limited informal observation

The default scene is the compact-arena prototype using the locked VM-0.1.2 `CharacterBody2D` player. Build VM-0.2.2-A-R1 fixes paired-pattern starvation by reserving a selected pair until two current lanes pass the existing capacity, overlap, spacing, and reachable-region checks. The experimental ramp uses singles before six seconds, guarantees the first pair selection from six seconds onward, uses a 50 percent pair probability from 10 to 15 seconds after that first reservation, and selects pairs at 15 seconds or later. The controller, telegraph curve, fall-speed curve, cooldown curve, six-second landed lifetime, and two-platform cap are unchanged. This pacing experiment requires manual evaluation and is not a validated difficulty result.

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

Play Build VM-0.2.2-A-R1 without changing parameters. Confirm that early play starts with singles and that the first paired warning reliably appears during a short run. Watch for an understandable pause while a reserved pair waits for both temporary platforms to despawn. For every pair, verify that both warning columns map to their exact cans, at least one reachable response remains, jumping becomes relevant without creating an unavoidable configuration, and no reserved pair is replaced by another single. Record observations before tuning or adding content.

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
