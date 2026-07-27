# Vending Machine Survival — Agent Instructions

## Product goal

Discover a fun, responsive, visually coherent core gameplay loop for **Vending Machine Survival**.

Working pitch:

> A tiny person is trapped inside a malfunctioning vending machine. Dodge falling products and increasingly absurd machine failures for as long as possible.

## Prototype comparison

Build and compare two gray-box prototypes in one Godot 4 GDScript project:

1. **Compact arena:** left/right movement and jumping.
2. **Conveyor:** automatic environmental scrolling with limited horizontal repositioning and jumping.

Use shared player physics, collision logic, death feedback, restart timing, product scale, sound levels, and gray-box visual language. The structural movement model should be the main independent variable.

## Scope lock

Do not implement:

- Daily challenges
- Leaderboards
- Ads
- Cosmetics
- Accounts
- Monetization
- Meta-progression
- Additional game modes

Do not expand scope before players voluntarily restart after dying.

## Operating principles

- Keep **evidence**, **hypotheses**, **decisions**, and **results** separate.
- Challenge mechanics that feel generic, unfair, overcomplicated, or visually inconsistent.
- Prefer observed play behavior over compliments, survey enthusiasm, or numerical ratings.
- Every hazard must have a readable vending-machine-native source.
- Avoid hazard states with no reachable response.
- Make the smallest change that can test or disprove a gameplay hypothesis.
- Do not hide a weak loop behind progression, content volume, polish, or rewards.

## Technical direction

- Engine: Godot 4
- Language: GDScript
- First distribution target: Web export hosted on itch.io
- Repository should include `docs/roadmap.html` as the durable project and playtest record.
- No OpenAI API or other paid API is required for the core prototype. Warn and estimate cost before introducing any separately billed API.

## Development workflow

Before editing:

1. Inspect existing files and current task state.
2. State the smallest intended change.
3. Identify which hypothesis or gate the change supports.
4. Confirm that shared variables remain controlled between prototypes.

After editing:

1. Run available tests and launch checks.
2. Report files changed.
3. Report test results and warnings.
4. Identify fairness, control-feel, performance, and scope risks.
5. Update the roadmap/decision log when a material decision or result changes.

## Cost and paid-service control

Use `docs/cost-usage.md` as the cumulative ledger for separately billed project usage.

Before any action that could create a separate charge:

1. Alert the user during the task and stop for approval.
2. Name the provider, model or service, feature, environment, and estimated request count.
3. Estimate input, cached-input, output, or other billable units when possible.
4. Provide low, expected, and high cost estimates.
5. Add usage instrumentation before implementing a paid-API feature.

If an API key is detected, do not print, expose, commit, or use it. Stop and provide the estimates above. Do not purchase extra Codex credits, enable paid hosting, deploy paid infrastructure, or activate paid services without explicit approval.

At the end of every meaningful task, report:

- Codex authentication mode, model, and subscription usage only when visible.
- OpenAI API and third-party paid-service request counts.
- Input, cached-input, and output tokens only when exposed by a trusted interface or provider.
- Separately billed task cost and cumulative separately billed project cost.
- Unavailable or untracked usage and whether the user should check **Codex Settings → Usage**.

Ordinary Codex use through a ChatGPT subscription is not separately billed OpenAI API usage. Do not assume ChatGPT Plus includes OpenAI API credits, and never invent token counts, usage allowance, or cost. If no separately billed API or service was used, state exactly: `Separately billed cost this task: $0.00`.

For paid API development sessions, record available provider/model, request ID, feature, environment, request count, input/cached-input/output units, tool calls, calculated cost, and timestamp without logging raw sensitive user content.

## Core quality gates

### Controls

- Immediate but non-binary horizontal response.
- Predictable stopping distance.
- Tunable coyote time and jump buffering.
- Useful but not consequence-free air control.
- No keyboard input combinations blocked by the chosen bindings.

### Fairness

- Clear telegraph and source for every damaging event.
- At least one reachable response when a hazard commits.
- No random state that seals every escape path.
- Visual and physical hitboxes agree.
- Death cause is understandable without explanatory text.

### Restart

- Fast death feedback.
- Intentional player-triggered restart.
- Direct return to gameplay without a menu.
- No tester prompting to retry.

### Visual coherence

- One consistent gray-box visual grammar.
- Danger, background, collision geometry, and decoration are distinguishable.
- Products and failures originate from visible vending-machine mechanisms.
- The conveyor has a legible physical source of motion.

## Initial behavioral gate

For approximately ten useful moderated tests, the provisional continuation gate is:

- At least 7/10 voluntarily restart after the first death.
- At least 4/10 initiate a fourth run.
- Most testers correctly understand why they died.
- One prototype produces clearly stronger self-directed replay behavior.

This threshold is a reversible decision, not evidence.
