# VM-0.6.4 — pre-external-test pass

Recorded: 2026-09-13 JST

Branch: `release/vm-0.6.4-pre-external-test`

Starting HEAD: `b1bfbf3e1e1b971ab4fe180302cc061b73c9764d` (verified VM-0.6.3 audio correction)

## Scope and decisions

This pass prepares the accepted Standard game for founder review before an external Web test. It makes the six changes authorized by Startup Lab:

1. raises only the Jump SFX runtime gain from **+6 dB to +10 dB**;
2. uses `ClockInUiConfirm1.wav` once for actual CLOCK IN, CREDITS, BACK, RESUME, RETRY, MENU and Pause-toggle activations;
3. replaces binary Music/SFX settings with independent persistent **0–100%** sliders;
4. supports Pause through **P**, **Escape**, and one visible upper-left **48×48** button usable by mouse or touch;
5. retains the existing landscape multitouch Left/Right/Jump controls and portrait rotation guidance; and
6. replaces natural authored Refund Coin routes with bounded constrained scatter while preserving coin value, legal regions, safety checks and approximately the accepted opportunity economy.

No SFX or music source was edited. Player movement, collisions, conveyor physics, hazards, product/D3/carriage timing, timer, score per coin, death/KO behavior, world art and gameplay difficulty values were not changed.

## Audio and controls

`SessionAudio` applies user volume at the existing `Music` and `SFX` buses. A slider percentage is converted from linear amplitude to dB and layers over the authored music-state or per-event gain. Therefore 100% is the authored reference, 0% is mute, and Pause ducking/death fades remain independent.

Preferences are stored at `user://standard_audio.cfg` under schema 2. A new user starts at 100/100. Existing recognized Music/SFX booleans migrate deterministically: OFF to 0%, ON to 100%. The sliders update live; mouse/touch release or keyboard adjustment completion produces at most one SFX preview when the SFX value changed. Hover and focus are silent.

The slider is a native Godot `HSlider` in a small C2-compatible dark panel with cream outline, teal fill and gold grabber. It adds no font or art asset. The same component is reused on Menu, Credits, Pause and Results.

The one `PauseButton` is anchored by the existing full-viewport touch-control layer at `(8,8)` with a `48×48` target. It is visible only during active gameplay on desktop and touch-capable Web. Entering Pause releases held touch inputs; Resume does not synthesize movement or jump input.

## Refund Coin scatter

Historical authored template functions remain available so old direct regression tests and factual comparisons keep meaning, but the **natural Standard scheduler now selects only `SCATTER_TEMPLATE`**.

- First offer: one grounded teaching coin at **1.75 s**.
- Later offer-count weights: **1 coin 0%, 2 coins 10%, 3 coins 90%**.
- Pair mode: **15%** of multi-coin offers.
- Normal minimum centre separation: **120 px**.
- Pair-mode separation: exactly **64 px** for one pair; a third coin remains at least 120 px from both.
- Layout search: at most **96** deterministic attempts on a **4 px** position quantum.
- Three-coin layouts reject near-collinear triangles with area below **600 px²**.
- Existing legal bands, belt/world bounds, player exclusion plus 8 px buffer, can/Sweeper/D3 conflict checks, reachability assumptions and bounded retry behavior remain active.

The accepted authored baseline offered 54/55/55 coins in 22 offers for seeds 401/1701/4202. Constrained scatter produced:

| Seed | Old coins | Scatter coins | Offers | 1/2/3-coin offers | Pair offers | Minimum separation | Median pairwise separation | Exhausted layouts |
|---:|---:|---:|---:|---|---:|---:|---:|---:|
| 401 | 54 | 53 | 21 | 1 / 8 / 12 | 2 | 64 px | 127.059 px | 0 |
| 1701 | 55 | 54 | 21 | 1 / 7 / 13 | 5 | 64 px | 129.244 px | 1 |
| 4202 | 55 | 52 | 21 | 1 / 9 / 11 | 5 | 64 px | 124.000 px | 1 |

The cadence multiplier is **0.84** so the lower 1–3 coin cap retains approximately the old opportunity total: 52–54 instead of 54–55 in these runs. All recorded spawns had zero player-safety or invalid-geometry violations. A developer contact sheet is at [coin-scatter-contact-sheet.svg](screenshots/vm064/coin-scatter-contact-sheet.svg).

## Validation

- Dedicated VM-0.6.4 audio/UI/Pause/mobile/scatter test: passed.
- All targeted affected regressions: passed.
- Final uninterrupted full suite: **37/37 test scripts passed**.
- Configured Standard scene: **180 headless frames, exit 0**.
- Single-threaded Web export: succeeded.
- Export inspection: `WarningSound1.wav` remains excluded.
- ZIP validation: 9 generated files, with `index.html` at archive root.
- Desktop localhost browser: Menu, game start, sliders, settings reload, and clickable Pause exercised.
- Compact landscape browser viewport: menu/gameplay layout and upper-left Pause target rendered without clipping.
- Browser warning/error console: **empty**.

The existing D3 scheduler itself is unchanged. Simultaneous scattered coins can legitimately occupy all three D3 visual fall corridors for their unchanged 2.25-second lifetime. In deterministic D3 regressions, D3 correctly waited on explicit `collectible_path_overlap` rejections, creating observed warning gaps of approximately 11.4–11.6 seconds while still completing all six events. The three D3 tests now allow up to 12.0 seconds only when that exact rejection is recorded; other cadence failures remain failures. This is a known cross-system scheduling risk for external observation, not a D3 retune.

Known benign headless output includes the existing macOS CA diagnostic and non-failing legacy teardown resource/object warnings. Founder listening, qualitative coin decisions, real-device multitouch, Safari and hosted itch iframe behavior remain unverified.

## Build outputs

- Web directory: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.4-PRE-EXTERNAL-TEST/`
- Review ZIP: `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.6.4-PRE-EXTERNAL-TEST.zip`
- Export preset: `Web GET CANNED VM-0.6.4 Pre-External Test`

Generated build artifacts remain ignored and are not committed.

## How to test locally

### Godot

```sh
cd /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --editor project.godot
```

Press **F5**. Desktop controls are A/D or Left/Right, Space/W/Up, P or Escape for Pause, the upper-left Pause button by mouse, and R for fresh Retry.

Use the Music and SFX sliders on Menu, Pause, Credits and Results. Set either to 0% to mute it; 100% restores the authored reference. Reload the project/page to confirm persistence. Activate CLOCK IN, CREDITS, BACK, Pause/Resume, RETRY and MENU and confirm exactly one shared UI confirmation per action. Trigger gameplay SFX by jumping, landing, collecting a coin, letting a product land, dying by impact, and completing 60 seconds. OUT remains intentionally silent and the carriage warning remains visual-only.

Inspect several coin offers. Expect one teaching coin, then usually three separated competing positions; occasional offers contain a deliberate close pair plus a separated option. No offer may exceed three coins or appear on the player.

### Web

```sh
cd /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter
python3 -m http.server 8767 --bind 127.0.0.1 --directory builds/VM-0.6.4-PRE-EXTERNAL-TEST
```

Open `http://127.0.0.1:8767/`. Browser audio requires an initial click/key interaction. On a touch-capable device in landscape, hold Left or Right and tap Jump simultaneously; while holding direction, tap the upper-left Pause button. Pause must clear held input, and Resume must not leave movement stuck. Portrait should show ROTATE DEVICE. Desktop/compact browser emulation does not prove real-device multitouch or itch iframe audio/focus behavior.
