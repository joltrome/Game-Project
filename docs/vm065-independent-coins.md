# VM-0.6.5 — Independent Refund Coin Stream Experiment

Recorded: 2026-09-14 JST

Branch: `release/vm-0.6.5-independent-coins`

Starting branch/HEAD: `release/vm-0.6.4-pre-external-test` at `0d08301d958ed3f6fdd7d88d23914eb82a4409b6` (clean and synchronized with `origin` before branching).

## Scope and implementation

VM-0.6.5 changes only the natural Refund Coin scheduling/lifetime presentation. It preserves the first grounded teaching coin at **1.75 seconds**, then replaces synchronized 2/3-coin natural offers with separately created one-coin entities.

Each accepted stream coin now owns its own:

- spawn timestamp and sampled position;
- lifetime, sampled from **2.50–4.00 seconds**;
- final **0.70-second** expiry-warning state; and
- collection or expiration cleanup.

Normal spawn attempts use a fresh deterministic random interval from **0.75–1.70 seconds**. At most **4** stream coins may be active. Capacity never evicts an existing coin; a capped attempt waits for the next normal scheduling opportunity.

Each accepted normal spawn makes one deterministic **10%** bonus roll. A successful roll reserves one additional one-coin attempt after **0.10–0.30 seconds**. A bonus receives its own sampled position and lifetime and counts toward the cap. It is never joined by a third burst coin. Normal coins retain **120 px** minimum centre separation. Bonus coins use **96 px**: the approved 120 px starting value proved geometrically incompatible with the 0.10–0.30-second delay in the moving playfield, so the narrower configurable bonus separation preserves a visibly separate opportunity without reconstructing a batch.

The prior constrained-scatter and authored route functions remain only as compatibility surfaces for historical direct tests. Natural Standard scheduling no longer calls them.

## Expiry presentation and collection

Every coin begins an independent warning when its own remaining lifetime reaches **0.70 seconds**. The warning continuously modulates opacity instead of flashing fully off:

- pulse cadence interpolates from **1.5 to 4.0 pulses per second**;
- early warning opacity does not fall below approximately **0.78**;
- the configured final minimum is **0.45**;
- visual seed phase offsets prevent intentionally synchronized warnings; and
- cadence is capped at four pulses per second.

Collection still resolves immediately, scores once, and uses the existing exactly-once Refund Coin SFX hook. Resolution stops physics, monitoring, lifetime processing, and expiry presentation before emitting the existing collection signal.

## Hazard priority

D3 remains unchanged. The coin director now predicts each existing/candidate coin's left-moving footprint at the next D3 reservation and over its warning-plus-fall horizon. A coin placement is accepted only when at least one currently eligible D3 lane remains clear, including a configurable **0.20-second** expiry clearance. During a committed D3 warning, a new coin must remain clear of the selected lane. During the falling state, the existing exact falling-product path check remains authoritative.

If no coin position satisfies player, geometry, separation, active-hazard and D3-priority constraints within **96** deterministic placement attempts, the optional coin is skipped; D3 is not rescheduled for it. Bonus placement uses at most **4** bounded lifetime/placement cycles.

In the deterministic D3 regression, all three seeds produced six warnings at **8.50, 17.04, 24.61, 33.40, 40.60 and 48.36 seconds**. Coin-caused D3 rejection count was **0** and the longest warning gap was **8.792 seconds**, replacing VM-0.6.4's observed 11.4–11.6-second coin-conflict gaps. Optional stream attempts skipped for D3 priority 8/3/6 times for seeds 401/1701/4202.

## Deterministic opportunity measurements

The comparison uses the same isolated 60-second empty-hazard fixtures as the VM-0.6.4 economy measurement. These counts measure opportunities, not collectible performance in live play.

| Seed | VM-0.6.4 coins | VM-0.6.5 coins | Average active | Maximum active | Normal | Bonus | Cap skips | Interval range | Lifetime range |
|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| 401 | 53 | 48 | 2.559 | 4 | 46 | 1 | 0 | 0.755–1.647 s | 2.526–3.976 s |
| 1701 | 54 | 51 | 2.643 | 4 | 48 | 2 | 0 | 0.763–1.679 s | 2.507–3.975 s |
| 4202 | 52 | 52 | 2.679 | 4 | 46 | 5 | 1 | 0.757–1.683 s | 2.514–3.961 s |

Average offered opportunities are **53.0 before** and **50.3 after** across these seeds. The new range of 48–52 is broadly comparable but slightly lower; Startup Lab should judge perceived abundance rather than treating exact equality as established. Every repeated seed reproduced spawn kind, timestamp, position and lifetime. No synchronized three-coin spawn, invalid geometry, lifetime violation, interval violation, player-overlap spawn or cap violation occurred.

The deterministic seed-401 timeline is [independent-coin-timeline.svg](screenshots/vm065/independent-coin-timeline.svg). It illustrates overlapping, independently ending lifetimes and their individual warning tails; it is diagnostic evidence, not a claim about player experience.

## Validation

- Dedicated VM-0.6.5 suite: passed.
- Affected VM-0.6.4, collectible, fixed-round, D3 and audio regressions: passed.
- Historical VM-0.4.2, VM-0.4.7, VM-0.6.0 and VM-0.6.4 natural-scheduler tests are explicitly pinned to the preserved legacy scheduler they document.
- Final clean full suite: **38/38 scripts passed**.
- Configured Standard scene: **180 headless frames, exit 0**.
- Single-threaded Web export: succeeded.
- Web build: loaded through localhost; Menu and gameplay rendered; browser warning/error console was empty.
- ZIP: nine files, integrity check passed, `index.html` is at archive root.

Generated validation logs are under `builds/validation-vm065-final/` and remain ignored. Generated Web artifacts remain ignored and are not source-controlled.

## Build outputs

- Web directory: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.5-INDEPENDENT-COINS/`
- Review ZIP: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.5-INDEPENDENT-COINS.zip`
- Export preset: `Web GET CANNED VM-0.6.5 Independent Coins`

## How to test locally

### Godot

```sh
cd /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --editor project.godot
```

Press **F6** only when `scenes/presentation/standard_session.tscn` is selected, or press **F5** to launch the configured Standard presentation. Select **CLOCK IN**. Controls are A/D or Left/Right to move, Space/W/Up to jump, P/Escape or the upper-left button to pause, and R to retry.

Play at least three full attempts, including one coin-greedy run. Expect the teaching coin around 1.75 seconds. After that, coins should appear one at a time at varied intervals while older coins remain active; an occasional second opportunity may follow 0.10–0.30 seconds later. No normal three-coin batch should appear. Watch several coins expire: during their final 0.70 seconds each should remain visible while pulsing progressively faster, never fully disappearing between pulses. Compare overlapping coins to confirm their warning and disappearance times are independent. D3 rack warnings should still begin around 8.5 seconds and then approximately every 7–9 seconds rather than waiting roughly 11.5 seconds for coin paths to clear.

### Web

```sh
cd /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter
python3 -m http.server 8768 --bind 127.0.0.1 --directory builds/VM-0.6.5-INDEPENDENT-COINS
```

Open `http://127.0.0.1:8768/`. Browser audio starts after the first click/key interaction. The same three-run review applies. Do not upload this experiment to itch.io yet.

## Known risks and unverified questions

- Automated checks establish timing, bounds, cap, deterministic behavior, individual expiry state, safe opacity/cadence limits, exactly-once resolution and D3 priority; they do not establish that the stream feels more organic, produces better choices, or has the right abundance.
- The 96 px bonus separation is an experimental technical compromise and needs visual review.
- Browser testing covered one local in-app Chromium environment, not Safari, a real touch device, or an itch iframe.
- Subjective music/SFX balance was not reopened or reevaluated.
- **Hazard-Earned Refund Coins** remains a post-external-test backlog experiment only. Nothing in VM-0.6.5 awards coins for hazard interaction.

