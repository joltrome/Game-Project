# VM-0.6.6 — Variable Refund Coin Events

Recorded: 2026-09-14 JST

Branch: `release/vm-0.6.6-variable-coin-events`

Starting branch/HEAD: `release/vm-0.6.5-independent-coins` at `87e83600950056fed8c8bbf9055f302d7415608a`. Local and `origin` matched and the tree was clean before branching.

## Scope

VM-0.6.6 changes only the natural post-teaching Refund Coin scheduler and its player-relative placement/lifetime calculation. The teaching coin remains one grounded coin at approximately **1.75 seconds**. Score value, collection, player, conveyor physics, hazards, D3 scheduling, carriage, timer, death, UI, audio, Pause, and mobile controls are unchanged.

This implements the Startup Lab hypothesis that variable-intensity asynchronous coin events may produce more varied movement choices than synchronized batches or a uniform single-coin stream. Technical completion does not validate that hypothesis.

## Event scheduler

After the teaching coin, each event independently selects a requested size with exported weights:

- **1 coin: 55%**
- **2 coins: 35%**
- **3 coins: 10%**

The initial requested **1.20–2.30 second** interval produced only 43–47 coins in representative isolated 60-second diagnostics. Per the brief, event-size weights were preserved and only the exported event interval was adjusted to **1.10–2.10 seconds**. Every completed event samples a new interval; timing is not synchronized to coin cleanup.

The active cap is **5**. A selected event is truncated to available capacity; it never evicts an existing coin. Placement may further omit an event member rather than violate player, geometry, separation, reachability, active-hazard, or D3-priority rules. Requested and delivered counts, cap truncation, placement failures, sides, positions, lifetimes, and next interval are logged for deterministic QA.

Each delivered coin remains its own one-coin entity and receives an independent position, requested **2.50–4.00 second** lifetime, effective lifetime, final **0.70-second** warning, collection resolution, and cleanup. There is no batch lifetime or batch cleanup.

## Player-relative placement

Code inspection confirmed the VM-0.6.5 right-bias mechanism: minimum spawn X included `conveyor speed × complete requested lifetime`. With a 2.50–4.00-second requested lifetime, longer-lived coins were structurally pushed right.

VM-0.6.6 explicitly partitions placement against the player's current X. “Centred” is within one player collision width; behind and ahead are strictly outside that band. Single-event selection uses exported **35% behind / 20% centred / 45% ahead** weights.

Multi-coin events select from small directional-conflict plans instead of authored traversal routes:

- pairs: behind+ahead, centred+ahead, or behind+centred;
- triples: behind+centred+ahead, behind+ahead+ahead, or behind+behind+ahead.

Plan order is shuffled before cap truncation. Placement tries the requested side first, then unused alternate sides before reusing a side, so fallback does not quietly collapse a multi-coin event into one same-side pile. Normal event coins stay at least **110 px** from previously active coins; siblings in one event use **96 px**. The latter is three 32 px coin diameters and permits competing directions inside the playable region without overlap.

## Effective visible lifetime

The new minimum guaranteed useful visible lifetime is an exported **1.65 seconds**. Placement computes the minimum X from actual conveyor travel over that duration. Effective lifetime is:

`minimum(requested lifetime, simulated time to the left exit)`

The exit time integrates the existing conveyor speed curve at 120 Hz, so it accounts for the frozen speed ramp rather than assuming a constant speed. Reachability and D3 checks use the effective lifetime. The existing per-coin warning is configured against that same effective lifetime, so an exit-limited coin warns during its actual final window.

## Deterministic results

The isolated fixtures below measure offered opportunities, not player collection performance.

| Seed | Events | Selected 1 / 2 / 3 | Delivered 1 / 2 / 3 | Coins | Behind / centred / ahead | Avg active | Max | Cap truncation | Placement failures | Effective TTL |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 401 | 35 | 20 / 12 / 3 | 21 / 14 / 0 | 49 | 14 / 11 / 24 | 2.270 | 5 | 1 event / 1 coin | 3 | 1.685–3.805 s |
| 1701 | 36 | 17 / 16 / 3 | 19 / 17 / 0 | 53 | 17 / 13 / 23 | 2.563 | 5 | 0 | 5 | 1.760–3.966 s |
| 4202 | 35 | 20 / 13 / 2 | 21 / 12 / 2 | 51 | 18 / 14 / 19 | 2.414 | 5 | 0 | 1 | 1.751–3.760 s |

Average opportunity was **51.0 coins**. Across all single events, sides were **19 behind / 11 centred / 27 ahead**, or **33.3% / 19.3% / 47.4%**, broadly matching 35/20/45. Across all coins, sides were 49/38/66. Requested TTLs spanned **2.508–3.977 seconds**; effective TTLs spanned **1.685–3.966 seconds**, and 102 of 153 coins were exit-limited. The configured interval was 1.10–2.10 seconds and observed intervals spanned 1.105–2.067 seconds.

An early deterministic seed-401 sequence is shown in [variable-event-timeline.svg](screenshots/vm066/variable-event-timeline.svg). It includes singles, doubles, selected triples, behind-player placement, and overlapping independent lifetimes. It also shows that safety may truncate a selected event; it is a diagnostic artifact, not evidence of subjective quality.

## D3 priority

The natural D3 lifecycle regression preserved all six warnings at **8.50, 17.04, 24.61, 33.40, 40.60, and 48.36 seconds** for all three seeds. The longest warning gap remained **8.792 seconds**. D3 collectible rejection count was zero. Variable-coin attempts skipped for D3 priority 1/1/0 times in the three D3 fixtures; optional coins never delayed a hazard.

## Validation

- Dedicated VM-0.6.6 suite: passed.
- Focused collectible, fixed-round, D3, VM-0.6.4 and VM-0.6.5 regressions: passed.
- Historical VM-0.6.5 suite is explicitly pinned to its accepted compatibility scheduler and reproduced 48/51/52 coins.
- Final full suite: **39/39 scripts passed** in one complete run.
- Standard Mode: **180 headless frames, exit 0**. The only message was the local macOS CA-certificate access warning; no game/script error occurred.
- Single-threaded Web export: succeeded with nine generated files.
- ZIP: integrity passed; `index.html` is at archive root.
- Localhost browser QA: Menu and live gameplay rendered; all nine resources loaded; warning/error console was empty.

Generated builds and validation logs remain ignored and are not committed.

## Build outputs

- Web directory: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.6-VARIABLE-COIN-EVENTS/`
- Review ZIP: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.6-VARIABLE-COIN-EVENTS.zip`
- Export preset: `Web GET CANNED VM-0.6.6 Variable Coin Events`

## How to test locally

### Godot

```sh
cd /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --editor project.godot
```

Press **F5** to run the configured Standard presentation, then select **CLOCK IN**. Use A/D or Left/Right to move, Space/W/Up to jump, P/Escape or the upper-left button to pause, and R to retry.

Play at least three runs: one survival-first, one coin-greedy, and one natural. The first coin should remain a single straightforward teaching coin around 1.75 seconds. Afterward, recognize event size by coins appearing at the same moment: most are singles, doubles should be common, and triples occasional. Multi-event coins should occupy conflicting player-relative directions rather than form one route.

To verify left-side placement, spend time in the middle/right of the band and watch for coins appearing behind the player; deliberately turn left for some of them. In a double or triple event, watch the coins separately: their warnings should begin at different times and one may expire or leave left while another remains. Every warning should remain visible, accelerate during the final approximately 0.70 seconds, and never flash fully off. D3 rack warnings should still begin around 8.5 seconds and recur at the established schedule rather than waiting for coins.

Expected technical behavior is a mixture of 1/2/3 requested events, independent lifetimes, visible behind/centre/ahead opportunities, no more than five active coins, and unchanged hazard behavior. Whether these moments create better choices is not locally automatable and requires founder review.

### Web

```sh
cd /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter
python3 -m http.server 8769 --bind 127.0.0.1 --directory builds/VM-0.6.6-VARIABLE-COIN-EVENTS
```

Open `http://127.0.0.1:8769/`. Browser audio starts after the first click or key input. Stop the server with Control-C. Do not upload this experiment to itch.io yet.

## Known risks and unverified questions

- Deterministic tests verify configuration, distribution, timing, independence, geometry, reachability, cap, D3 priority, reproducibility, and technical Web loading. They do not establish that variable events create stronger choices, that abundance feels right, or that 1.65 seconds is subjectively fair.
- Safety/cap truncation means selected triples are intentionally not guaranteed to deliver all three coins. A natural representative seed delivered complete triples, and bounded empty-arena tests prove full 1/2/3 events are possible without relaxing safety.
- The 110 px active / 96 px sibling separation is a constrained-space technical choice requiring visual review.
- Browser QA covered one local Chromium environment, not Safari, real touch hardware, or an itch iframe.
- **Hazard-Earned Refund Coins** remains prominently preserved in the design backlog as the next major scoring experiment only if external testing shows time-generated events still lack meaning. It was not implemented.
