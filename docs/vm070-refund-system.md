# VM-0.7.0 — Refund System Consolidation

Recorded: 2026-09-20 JST

Baseline: `release/vm-0.6.10-refund-chute` at `d4a36226467532b4d093f270f2f98fa428baa0b2`

Implementation branch: `release/vm-0.7.0-refund-system`

## Evidence, hypothesis and decisions

**Evidence:** The founder prefers ballistic Refund Coins and a second player independently preferred VM-0.6.9 to the static VM-0.6.6 direction. VM-0.6.10 established that Concept C can source all three trajectory families, but it left a physical inconsistency: coins could not remain on landed products and their 24×24 pickup footprint could leave the 32 px visual embedded in a can. It also made the first scoring opportunity ballistic before the player had learned that a Refund Coin is worth one point. Finally, natural complete-group retention fell from VM-0.6.9's 23/44 doubles and 1/7 triples to VM-0.6.10's 16/46 doubles and 0/10 triples.

**Hypothesis:** A deterministic supported-on-can state, a separate 32×32 world-contact footprint, one static teaching opportunity per run and bounded group-retiming fallbacks will make the selected scoring system coherent enough for external testing without changing Standard difficulty or D3.

**Decision:** Concept C remains frozen at its existing position, shape, 150 ms preparation, emitter segment and visual states. Ballistic coins remain the provisional Standard scoring direction. The first teaching opportunity is repeated every run; no save-state or first-install tutorial system was added. Standard difficulty, D3, hazards, player movement, conveyor behavior, event cadence, 55/35/10 weights, five-coin cap, score value and the global 44 px trajectory-separation rule remain unchanged. UI polish, Overload Mode and Hazard-Earned Ballistic Refund Coins remain deferred.

## Implementation result

### Supported-on-can lifecycle

`ConveyorCollectible.MotionState.SUPPORTED_ON_CAN` is a deterministic state, not unconstrained rigid-body physics.

- A hard or first top impact still produces the existing controlled ricochet.
- A later post-bounce top contact at no more than 260 px/s vertical speed may become supported.
- A support registry permits at most one coin on each landed can.
- A supported coin stores the can instance ID and horizontal offset, follows that can exactly, remains collectible, and continues its ordinary lifetime and expiry warning.
- Visual bob is clamped so it may rise but cannot dip into the can.
- Collection, expiry, round stop and support loss release the claim; no stale claim is retained.
- When the can disappears, the coin falls to a valid conveyor settle. If no clear conveyor position exists, it expires rather than floating or teleporting through a can.
- Side contacts and hard contacts remain bounded ricochets; coin-on-coin physics and stacking were not added.

### Pickup versus world-contact geometry

The player pickup Area2D remains **24×24 px**. Coin-versus-can calculations use a separate **32×32 px** world footprint, matching the visible C1 coin more closely. The larger footprint is used for swept top/side contact, overlap tests, clear-space settlement and left-edge cleanup. It does not make the player pickup easier.

The regression suite covers hard top impact, later low-energy support, moving support, one-coin-per-can claims, high-speed side contact at the 32 px envelope, support collection, support loss, support expiry and final non-overlap.

### Teaching sequence

At approximately the existing first-offer time, every fresh run creates one safe, static ground coin with the existing `REFUND COIN +1` arrow/highlight. It uses the same visual, pickup signal, +1 scoring path and pickup SFX as any other Refund Coin. Its review lifetime is four seconds. The event stream schedules its next attempt immediately, so ignoring the teaching coin does not stall the run; all later accepted events use the Concept C ballistic path.

No modal tutorial, pause, dialogue or persistence was added. The existing ASCII-safe desktop control legend remains available; touch controls were not redesigned.

### Multi-event hierarchy

The group planner now tries the following bounded hierarchy with one candidate-pool build:

- DOUBLE: simultaneous → the same candidates at 60 ms → the same candidates at 120 ms → single fallback.
- TRIPLE: 0/100/200 ms → 0/110/220 ms → 0/180/360 ms → double → single.

Retiming already-bounded candidate pools avoids repeated sampling and the 100–200 ms planning spikes seen in the discarded first VM-0.7.0 draft. The chute remains open through the final accepted sibling using the existing visual controller. The 100 ms / 50 px chute-mouth grace remains local and bounded. Once coins leave that grace, VM-0.7.0 uses the existing **44 px global ballistic separation**; it does not globally reduce that rule. Cadence remains 1.10–2.10 seconds, weights remain 55/35/10, maximum active coins remain five and D3 remains authoritative.

The initial implementation draft was rejected during development: five deterministic runs retained only 19/62 complete doubles (30.6%) and produced a 132.09 ms maximum planning event. That implementation was not shipped. Reusing and retiming one bounded candidate pool corrected both failures.

## Deterministic evidence

### Five-round integrity gate

Seeds 401, 1701, 4202, 7007 and 9011 selected 73 doubles and 16 triples. Final results were:

| Metric | VM-0.6.9 | VM-0.6.10 | VM-0.7.0 |
|---|---:|---:|---:|
| Complete doubles | 23/44 (52.3%) | 16/46 (34.8%) | **38/73 (52.1%)** |
| Complete triples | 1/7 (14.3%) | 0/10 (0%) | **1/16 (6.3%)** |
| Maximum planning event | 44.586 ms recorded control | 44.207 ms | **53.784 ms** in this five-seed gate |

The triple result is non-zero but sparse. It proves the fallback can retain a full triple; it does not establish that triple frequency or readability is ideal. One natural short-stagger double occurred in these five seeds. A controlled mouth-conflict regression also proves a pair rejected at simultaneous timing becomes valid at the bounded 120 ms fallback without moving its landing points. Natural frequency and visual readability of that fallback remain external-observation items.

### Three-round native natural profile

Seeds 401, 1701 and 4202 selected 54 singles, 43 doubles and 10 triples: **170 requested coins**, with **112 delivered**. Complete groups were 22/43 doubles (51.2%) and 1/10 triples (10.0%). Delivered coins were 38/35/39; average active coins were 2.249/2.110/2.235 and the maximum was five in every run.

Natural D3 warnings remained at approximately 8.50, 17.04, 24.61, 33.40, 40.60 and 48.36 seconds. The longest gap remained 8.792 seconds. No natural D3 candidate was delayed by a coin.

Group degradation reasons across those runs were 13 sibling-geometry conflicts, eight exhausted scatter searches, five active-cap limits and four D3-priority decisions. This instrumentation records why requested groups were reduced; it does not weaken those safety gates.

Support-on-can telemetry is present for support entries, supported collections, support-loss transitions and forced depenetrations. The three non-interactive natural profiles recorded 30 support entries, three support losses and zero forced depenetrations. They recorded no supported collections because the profile disables player interaction; deterministic unit scenarios cover supported collection and claim release.

### Performance

The native natural profile produced:

| Seed | p95 step | p99 step | Worst step | Mean planning | Max planning |
|---:|---:|---:|---:|---:|---:|
| 401 | 0.047 ms | 0.118 ms | 42.530 ms | 6.484 ms | 42.487 ms |
| 1701 | 0.048 ms | 0.111 ms | 49.192 ms | 6.136 ms | 49.145 ms |
| 4202 | 0.047 ms | 0.097 ms | 38.683 ms | 8.643 ms | 38.652 ms |

An artificial three-can stress profile had maximum planning events of 58.095, 60.537 and 83.610 ms. It produced no 100–200 ms event. Because that harness injects extra landed cans outside the natural scheduler, its D3 overlap delays are stress-fixture effects and are not evidence of a natural D3 regression.

## Validation

- VM-0.7.0 targeted refund-system tests: passed.
- VM-0.6.8 abundance/can-collision regression: passed.
- VM-0.6.9 integrity regression: passed.
- VM-0.6.10 Concept C regression: passed.
- VM-0.6.2 touch/pause regression: passed.
- Deterministic nine-case review scene autoplay: passed.
- Complete repository suite: **44/44 test scripts passed** in the single requested final pass.
- Standard, D2, frozen Prototype A, frozen Prototype B and the review scene: all launched headlessly and exited successfully.
- Web export: completed successfully to `builds/VM-0.7.0-REFUND-SYSTEM/`.
- Root ZIP: valid, contains nine generated files with `index.html` at archive root.
- Desktop browser startup: menu, active play, teaching coin and teaching cue rendered successfully through a local HTTP server; the browser console contained no warnings or errors from the game.

The recurring macOS Godot editor-settings/CA diagnostics are environment messages rather than game-script failures. Physical iPhone Safari, Android Chrome and itch.io hosting remain unverified until the founder performs those tests.

## Manual review scene

Run the deterministic nine-case review:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  res://scenes/tests/refund_chute_trajectory_review.tscn
```

Use number keys:

1. SHALLOW single
2. MEDIUM single
3. HIGH single
4. simultaneous DOUBLE
5. staggered DOUBLE
6. staggered TRIPLE
7. 90 ms short-stagger DOUBLE presentation
8. can bounce then support
9. supporting can disappears and coin falls to the belt

`R` replays the currently selected case. The gallery is deterministic and does not score. For case 8, confirm the first hard top impact bounces and the later low-energy contact seats the 32 px coin cleanly on the 72×48 can. For case 9, confirm support loss leaves no floating coin or stale support. Use normal gameplay to collect a supported coin because the review gallery intentionally isolates movement.

## Normal local play

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  res://scenes/presentation/standard_session.tscn
```

Inspect the first static `REFUND COIN +1` opportunity, then natural ballistic launches and supported coins. Controls are A/D or LEFT/RIGHT, SPACE to jump, R to retry and ESCAPE for Pause/Menu where available. At round end, the console prints `VM070_COIN_SUMMARY` with integrity and support telemetry.

Native performance profile:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --log-file /tmp/vm070-profile-natural.log \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  --script res://tests/profile_vm069_performance.gd -- --mode=VM070 --natural
```

## Web and physical-phone review

Desktop Web build directory:

`builds/VM-0.7.0-REFUND-SYSTEM/`

Archive:

`builds/VM-0.7.0-REFUND-SYSTEM.zip`

Serve on this Mac for desktop-only review:

```sh
python3 -m http.server 8170 --bind 127.0.0.1 \
  --directory /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.7.0-REFUND-SYSTEM
```

For a phone on the same trusted Wi-Fi, first find the Mac's Wi-Fi address with `ipconfig getifaddr en0`, then serve on the local network:

```sh
python3 -m http.server 8170 --bind 0.0.0.0 \
  --directory /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.7.0-REFUND-SYSTEM
```

Open `http://MAC_IP_ADDRESS:8170/index.html` in iPhone Safari or Android Chrome. Rotate to landscape. Verify LEFT, RIGHT and JUMP individually; hold a direction with one finger and jump with another; release each finger and confirm no stuck input; Pause and Resume; die and Retry; rotate to portrait and confirm the rotate guidance; return to landscape and inspect cropping, audio and frame smoothness. This local-network check does **not** prove itch.io compatibility.

## Known risks and unverified product questions

- The supported-on-can behavior is deterministic and technically covered, but natural human readability and collection value require playtesting.
- Complete doubles meet the directional target; triples are non-zero but remain uncommon.
- The bounded short-stagger path is covered by a controlled geometry regression and occurred once across five sampled natural runs; that frequency and its visual readability remain unvalidated.
- No technical test can prove that the first static coin communicates its lesson to a fresh player.
- Actual multi-touch, audio policy, browser viewport behavior and sustained performance require physical-device testing.
- Standard difficulty was deliberately not changed. Founder mastery is not fresh-player difficulty evidence.

## External-playtest gate

The final suite, launch, export and desktop-browser gates are green, so the technical build is ready for the requested external playtest. External testing should observe comprehension of the first coin, visible can support, trajectory readability, meaningful multi-coin choices, unexplained score changes, mobile input failures and performance stalls. Physical-phone and itch.io behavior remain unverified. No further internal feature or difficulty iteration is authorized by this report.
