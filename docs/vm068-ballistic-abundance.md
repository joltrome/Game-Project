# VM-0.6.8 — Ballistic Abundance + Controlled Can Collision

Recorded: 2026-09-17 JST

Control: `release/vm-0.6.6-variable-coin-events` at `7605554e72112f2aa9a4503400c5a93adecb28e9`

Ballistic baseline: `release/vm-0.6.7-ballistic-coins` at `173a69ee9b1e3951ea5456ace0b493c197f902ca`

Experiment branch: `release/vm-0.6.8-ballistic-abundance`

## Evidence, hypothesis and decision

Evidence from founder review is that VM-0.6.7 is directionally promising, but remains visually and mechanically unpolished. Its representative unattended runs delivered only 21/20/24 coins versus the VM-0.6.6 control's 49/53/51, so abundance is a major comparison confound. Founder review also observed coins visually embedding in landed products.

The hypothesis under test is that denser ballistic opportunities, varied multi-launch rhythm and controlled landed-can ricochet will increase decision frequency without sacrificing hazard readability. This implementation does not validate that hypothesis.

The approved decision is one isolated experiment: retain deterministic authored arcs and avoid general-purpose rigid-body physics. Add collection-state telemetry so later playtests can show whether ballistic motion matters. VM-0.6.6 and VM-0.6.7 remain preserved and independently runnable.

## Implementation

The 1.10–2.10-second event-attempt cadence, 55/35/10 one/two/three-coin weights, five-coin cap, one-point value, 2.0–3.0-second post-contact lifetime and final 0.70-second warning are unchanged.

VM-0.6.8 relaxes the VM-0.6.7 blanket rejection of landed-can landing footprints because runtime collision now handles that contact deterministically. SHALLOW, MEDIUM and HIGH remain the only trajectory families. Per-coin source variation is bounded to ±20 px horizontally and ±16 px vertically; flight duration varies by at most ±7.5 percent. The landing target continues to come from validated authored placement.

Double events use a configurable 50 percent stagger probability. A stagger delays the second launch by 0.10–0.30 seconds. Triple events use a configurable 75 percent stagger probability; each following launch is delayed by another 0.10–0.25 seconds. Every sibling still owns its trajectory, bounce state, lifetime, warning, collection and expiry independently.

Landed-can contact uses the existing landed 72×48 AABB expanded by the 24×24 pickup footprint. Top contact reflects vertical motion upward at 0.34 restitution, with at least 180 px/s upward speed and a 70 px/s outward deflection. Side contact reflects horizontal motion at 0.35 and adds 180 px/s upward motion. A coin may ricochet from landed cans at most twice. A third contact deterministically searches for the nearest clear conveyor position; if no clear position exists, the coin expires rather than embedding, jittering or remaining unreachable. Falling products, D3 cans before landing, carriage, walls and ceiling remain outside this collision matrix.

D3 first searches for a physically fair lane that is also clear of optional coins. In VM-0.6.8 only, if coins occupy every otherwise valid lane, D3 claims a physically fair lane without waiting for the rewards. That preserves hazard priority and the accepted warning schedule; visual overlap during this fallback is a manual readability risk, not a proven success.

Each completed VM-0.6.8 run prints a `VM068_COIN_SUMMARY` diagnostic with delivered, collected, AIRBORNE, BOUNCING and SETTLED collections, EXPIRED, EXITED_LEFT, landed-can ricochet count, collection rate and average launch-to-collection time. No network analytics or player content is recorded.

## Deterministic results

These are unattended, stationary-player technical simulations. They measure opportunity and system behavior, not collection success or enjoyment.

| Seed | Events | Requested | Delivered | Delivery | Selected 1/2/3 | Simultaneous / staggered multi-events | Archetypes S/M/H | Avg / max active | Cap skips | Placement failures | Ricochets |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 401 | 36 | 56 | 39 | 69.6% | 20/13/3 | 7/9 | 20/10/9 | 2.037 / 5 | 0 | 17 | 44 |
| 1701 | 34 | 55 | 34 | 61.8% | 19/10/5 | 8/7 | 16/11/7 | 1.719 / 4 | 0 | 21 | 39 |
| 4202 | 35 | 58 | 37 | 63.8% | 16/16/3 | 9/10 | 21/11/5 | 1.926 / 4 | 0 | 21 | 41 |

VM-0.6.7 rejection diagnosis was: seed 401 — D3 12, can 13, sibling 11; seed 1701 — D3 16, can 8, sibling 7; seed 4202 — D3 14, can 16, sibling 6. VM-0.6.8 rejections are respectively `{sibling: 10, D3: 4, can: 2, lifetime: 1}`, `{D3: 4, sibling: 13, can: 4}`, and `{sibling: 18, D3: 3}`. The third seed is one coin below the 35–40 directional target; cadence, weights and cap were not changed merely to force that number.

All seeds retained D3 warnings at approximately 8.50, 17.04, 24.61, 33.40, 40.60 and 48.36 seconds. The longest warning gap is 8.792 seconds and coin-caused D3 delay is zero.

Synthetic lifecycle tests collected one coin in each AIRBORNE, BOUNCING and SETTLED state and separately verified EXPIRED and EXITED_LEFT classification. Unattended natural simulations intentionally collect no coins. Real collection-state proportions and average player collection time therefore remain unverified until human playtesting.

## Manual review required

Review whether the 34–39 delivered opportunities feel frequent enough, simultaneous doubles remain readable, staggered doubles/triples create choices, and ricochets look intentional rather than chaotic. Watch especially for reward/hazard confusion when D3 takes priority, excessive upper-screen attention, triple clutter, trapped-looking coins, and settled collection dominating the run.

Do not declare VM-0.6.8 the winner without comparing it to VM-0.6.6. The later **Hazard-Earned Ballistic Refund Coins** hypothesis remains explicitly postponed and unimplemented.

## Builds

- VM-0.6.6 control: `builds/VM-0.6.6-VARIABLE-COIN-EVENTS/`
- VM-0.6.7 baseline: `builds/VM-0.6.7-BALLISTIC-COINS/`
- VM-0.6.8 experiment: `builds/VM-0.6.8-BALLISTIC-ABUNDANCE/`
- VM-0.6.8 ZIP: `builds/VM-0.6.8-BALLISTIC-ABUNDANCE.zip`
- Export preset: `Web GET CANNED VM-0.6.8 Ballistic Abundance`

Generated build artifacts remain ignored and are not committed.

## Validation result

- Focused VM-0.6.8 abundance/collision coverage passed.
- VM-0.6.7 ballistic-baseline regression passed with its original 21/20/24 delivery metrics and D3 schedule.
- VM-0.6.6 control regression passed with its original 49/53/51 isolated-control metrics.
- Full automated suite: **41 of 41 test scripts passed**.
- Standard presentation scene launched headlessly for 180 frames; frozen Arena and Conveyor scenes each launched headlessly for 120 frames.
- The single-threaded Web export completed and the root-level ZIP contains all nine generated files with `index.html` at archive root.
- A local Chromium smoke test loaded every exported resource with HTTP 200, entered gameplay and completed a run without a JavaScript or game-code error.
- The automated Chromium/DevTools environment did emit repeated `WebGL: INVALID_OPERATION` buffer warnings while rendering. No corresponding game failure was visible, but the strict “browser console clean” gate is therefore **not fully verified** in this environment and should be checked in the founder's normal itch-compatible browser.

The automated suite proves deterministic launch/collision/state invariants. It does not establish that simultaneous events, staggered triples, ricochets or D3-priority visual overlaps are readable during human play.
