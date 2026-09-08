# Opportunity and Design Backlog

This backlog records ideas without granting implementation approval. Evidence, hypotheses, decisions, and implementation results remain in `docs/roadmap.html`.

## Postponed

- **Overload Mode:** Possible separate mode where Refund Coins add time while the machine escalates toward a visually explicit overload. This changes coins from optional score temptation into a survival resource, so it must not replace or modify Standard Mode without a separate hypothesis and playtest.
- **Can-platform bonus routes:** Possible high Refund Coin routes that are comfortably reachable only by using a landed product as a platform. This may deepen scoring decisions, but it creates hazard-state-dependent reachability and is not part of the final Standard coin micro-pass.
- **Time bonuses for coins:** Do not add time to Standard Mode coins. Revisit only inside a separately approved Overload Mode experiment.
- **Prototype A machine-jam event:** Preserve the frozen arena as a possible short event inside the conveyor game. Do not implement it yet.
- **Moving-height Sweeper Arms:** Reconsider only if new playtest evidence identifies a specific decision or fairness problem the current fixed height cannot address.
- **Additional can sizes and speeds:** Reconsider only after the single collectible experiment and further conveyor testing; do not add variants as content volume alone.
- **Additional platforms:** Reconsider only if evidence shows a missing terrain decision that existing landed cans cannot provide.
- **Distinct Refund Coin pickup sound:** First future audio task once an audio pipeline is explicitly approved; do not add an audio system solely for VM-0.4.3.
- **Overdrive after standard completion:** Possible post-60-second option; do not implement until the fixed-round result and desired continuation behavior are reviewed.
- **Separate Endless mode:** Possible future selectable mode; do not implement as an automatic continuation or before mode scope is approved.
- **Harder fixed-duration tiers:** Possible future difficulty structure; do not add until the standard 60-second baseline is externally tested.
- **Local personal-best tracking:** Possible local-only replay aid; do not implement until score behavior is validated and persistence is explicitly approved.
- **Right-side VEND ELEVATOR visual revision:** VIS-03 preserves the current schematic elevator because it does not block the runtime review. Revisit only after Startup Lab evaluates the integrated rack/warning candidate; do not change its gameplay source, geometry, timing, or collision while addressing visual coherence.

## Rejected for the current direction

- **Full 30-second mode switching:** Do not alternate between two complete game modes. Prototype B is the primary direction; Prototype A is preserved only as a possible future machine-jam event.

## External-playtest suggestions — unvalidated

These suggestions came from external playtesting. They are not requirements and do not grant implementation approval.

| Suggestion | Source and status | Rationale | Major design risk |
|---|---|---|---|
| Stomp or jump on missiles to disable them | External playtest · unvalidated suggestion | Could turn a hazard into an optional timing opportunity. | May make jumping overly dominant and reduce the missile's opposing-height purpose. |
| Duck action plus multiple missile heights | External playtest · unvalidated suggestion | Could add a second response to vertically differentiated missiles. | Adds a player action, control, collision state, tutorial requirement, and future mobile-input cost. |
| Rolling cylindrical or package hazard | External playtest · unvalidated suggestion | Could create a vending-machine-native form of variable ground pressure. | Adds another hazard type and may create unclear or unavoidable compound patterns. |
| Award Refund Coins for jumping over missiles | External playtest · unvalidated suggestion | Could explicitly reward a risky avoidance action. | Overlaps the existing Refund Coin risk/reward economy and may distort the optimal survival strategy. |
| Additional products occasionally falling during conveyor play | External playtest · unvalidated suggestion | Could provide a later escalation related to the preserved Prototype A machine-jam concept. | Multiple attack sources may overload warning readability or create unavoidable combinations. |
| Separate Endless or Overdrive mode | External playtest · unvalidated suggestion | Could serve players who repeatedly finish the standard round and want to continue. | Splits modes and balance work prematurely. Do not implement until repeated standard-round completers demonstrate demand. |
| Occasional low-risk forward coin versus larger risky rear coin routes | External playtest · unvalidated suggestion | Could make the survival-versus-score choice more explicit. | May duplicate the existing offer economy or make one route predictably optimal. VM-0.4.7 only adds a single-coin centred/ahead anti-streak correction; it does not implement a new paired-route system. |

## Directional-pressure hypothesis to observe

- **Missile and conveyor direction:** One external tester reported that leftward conveyor force combined with missiles entering from the left may feel overly compressed and suggested reversing missile direction. Status: unvalidated hypothesis; no baseline change approved. In later sessions, record whether missile deaths feel unavoidable because of conveyor motion, whether players are forced to camp right, and whether telegraph and reaction margins remain adequate. If independently repeated, A/B-test left-entry versus right-entry missiles before changing the frozen baseline. The primary risk of an immediate reversal is replacing a tested pressure relationship with a different untested dominant strategy.

## After accepted Standard freeze — 2026-09-08

Startup Lab accepts the final coin micro-pass and leftward conveyor visuals. No further Standard gameplay pass is authorized. Backlog only (not release commitments): separate Overload Mode, time-giving coins in Overload only, escalating overload intensity, landed-can-required high coin routes, and right-side vend elevator polish if later player evidence warrants it.

Expected review sequence: VM-0.6.0 presentation/audio foundation → VM-0.6.1 audio content/SFX → VM-0.6.2 release-candidate QA and finished-experience external test → soft release. Each later milestone requires authorization; none was started here.
