# Opportunity and Design Backlog

This backlog records ideas without granting implementation approval. Evidence, hypotheses, decisions, and implementation results remain in `docs/roadmap.html`.

## Postponed

- **Prototype A machine-jam event:** Preserve the frozen arena as a possible short event inside the conveyor game. Do not implement it yet.
- **Moving-height Sweeper Arms:** Reconsider only if new playtest evidence identifies a specific decision or fairness problem the current fixed height cannot address.
- **Additional can sizes and speeds:** Reconsider only after the single collectible experiment and further conveyor testing; do not add variants as content volume alone.
- **Additional platforms:** Reconsider only if evidence shows a missing terrain decision that existing landed cans cannot provide.
- **Distinct Refund Coin pickup sound:** First future audio task once an audio pipeline is explicitly approved; do not add an audio system solely for VM-0.4.3.
- **Overdrive after standard completion:** Possible post-60-second option; do not implement until the fixed-round result and desired continuation behavior are reviewed.
- **Separate Endless mode:** Possible future selectable mode; do not implement as an automatic continuation or before mode scope is approved.
- **Harder fixed-duration tiers:** Possible future difficulty structure; do not add until the standard 60-second baseline is externally tested.
- **Local personal-best tracking:** Possible local-only replay aid; do not implement until score behavior is validated and persistence is explicitly approved.

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
