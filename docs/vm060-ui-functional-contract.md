# VM-0.6.0 RC0 — UI functional contract for Work

Recorded: 2026-09-08. Engineering checkpoint: **`1dcaae78cf40b3fe44bdd5157c64a0e62d8afa92`**, branch `release/vm-0.6.0-presentation-audio`. Pushed unchanged and verified against the live remote before this document was written.

**Startup Lab functionally accepts RC0 as the presentation/audio engineering baseline. Its current menu/results visual presentation is rejected as the final UI direction.** Work will explore a more playful, animated, arcade-like, game-specific visual layer. This checkpoint authorizes documentation only; it does not authorize UI redesign, copy changes, death messages or an audio swap.

## Functional requirements to preserve

| Surface | Required behavior |
|---|---|
| Main menu | Identify Vending Machine Survival; title/logo location and treatment may change in the future visual pass. Keep a clear Play action, Move: A/D or Left/Right and Jump: Space onboarding, current local best score, Credits access, independent Music and SFX controls. Launch must contain no gameplay instance, running round, hazards or director. |
| Credits | Remain accessible from Menu, with Back/Escape returning to a clean menu. Preserve factual music credit and temporary-demo status until a separately authorized provenance/asset update. |
| Death results | Distinguish failure from successful completion; display the actual completed run's Refund Coin count and local best score. Keep Retry and Menu. Current state label is GAME OVER. |
| Completion results | The original 60-second controller ends the run successfully and displays the actual run score and best. Keep Retry and Menu. Current state label is SURVIVED. |
| Result audio controls | RC0 exposes Music/SFX controls on results as well as menu/gameplay. Preserve both controls and their state if retained on the results design. If Work proposes moving them, explicitly identify the destination and obtain Startup Lab's decision; do not silently drop the capability. |
| Gameplay | Preserve frozen S1/P-A/C-A Standard, movement/input, 60-second timer, death rule, coin scoring/topology/cadence/spawn safety, products, carriage, D3 and leftward conveyor physics/visuals. The menu/results art brief does not reopen world art, camera or gameplay. |
| Retry | Begin a fresh Standard run immediately, including from the R shortcut during a live run. Reset player, timer, score, hazards, coins, pending offers, all directors, carriage and warnings; no accumulated nodes/listeners. Do not impose a transition that delays replay or starts gameplay behind a transition. |
| Menu return | Remove and free the old run completely. No timer, hazard, director or warning continues behind Menu. Music and mute state survive. |

State flow: **Launch → Menu → Play → Standard → death OR completion → corresponding Results → Retry OR Menu**. Credits is a Menu side path, not an extra step before Play. Only Standard exists; no mode selector.

## Existing input contract

- Every visible button supports mouse activation. Preserve usable hit targets, focus/hover/pressed feedback and viewport fit when artwork/layout changes.
- Menu, Credits and Results support keyboard focus navigation (Tab/Shift+Tab and Godot's standard UI focus actions) and focused-button activation through standard `ui_accept` (Enter/Space). Default focus: Play on Menu, Back in Credits, Retry on Results. Keep a visible focus indicator and a usable navigation order in any new layout.
- Gameplay movement: physical A/D or Left/Right; jump: physical Space. Starting a run releases UI focus. Gameplay sound buttons have `FOCUS_NONE`, so they do not take movement/jump input away from the player.
- Physical R is the `restart` action in GAME and RESULTS; it starts a clean run without a menu detour. It has no retry action in MENU/CREDITS.
- Escape returns to Menu from RESULTS or CREDITS. It does **not** open Menu or pause during live Standard gameplay. A legacy `pause` InputMap entry exists, but StandardSession does not implement a pause action; do not advertise one as existing behavior.
- Web audio unlocks on an ordinary pressed key/mouse interaction. Do not require an extra tutorial or activation screen. Decorative UI must not intercept the functional controls.

## Audio, persistence and debug contract

- `StandardSession` owns one `SessionAudio` node outside the replaceable gameplay scene. Keep exactly one MusicPlayer/start across Menu → Game → Results → Retry → Menu, including focus changes; no scene-local copies or automatic replay on transitions.
- Buses: **Master, Music, SFX**. Music/SFX route to Master; current Music level is -6 dB and SFX 0 dB. Preserve routing and independent controls; no mix changes in this checkpoint.
- Mute changes only the selected bus, preserves playback position and survives all in-session state transitions. Mute persistence across launches is not currently implemented. Silent SFX hooks remain connected; do not add placeholder assets.
- Runtime music remains `res://assets/audio/miraie_main_theme_TEMPORARY_DEMO.mp3`, assigned to `Audio.music_stream` in `scenes/presentation/standard_session.tscn`. Desktop starts on menu; Web waits for normal interaction. It plays once, including the quiet tail; after it ends, it stays silent until a fresh launch. This temporary policy is not the final seamless-loop specification.
- Standard best uses `user://standard_best.cfg`, `[standard] best_score`. Higher scores update; equal/lower scores do not replace best. Missing, corrupt, wrong-type or negative values safely initialize to zero; unavailable writes retain the in-session best and do not prevent play. Web uses local browser storage, not a server/account/leaderboard.
- Keep normal builds free of VIS-04, P-A/C-A, candidate/build IDs, lane/collision diagnostics and developer instructions. Standard F8 requires **both** `OS.is_debug_build()` and custom feature `standard_debug`; release RC0 uses `standard_release`. Local instrumentation remains disabled in normal Standard. Preserve legacy developer/comparison scenes independently.

## Visual aspects Work may replace in the upcoming design

**Not frozen:** layout, button appearance, typography, logo treatment, decorative UI, screen composition, transitions, menu/result animation and flavor copy. The present static rectangular design is a functional reference, not a visual target. Keep the established Japanese retro vending arcade identity and the functional distinctions above. Flavor copy may change in a future authorized implementation; accurate credits and control meanings must remain accurate.

Work may propose playful motion and cause-specific result treatments, but must not invent new gameplay states or assume unavailable death-cause data. Transitions must preserve fast Retry, cleanup, readable scores and continuous audio. **No visual, copy or behavior change was implemented during this checkpoint.**

## Death-cause inspection — available data and gap

**The production result system cannot currently distinguish death causes cleanly.** It stores death versus completion only, not a typed cause.

| Source | Current path/data |
|---|---|
| Ordinary falling product | `FallingProduct.player_hit(product)` → `ConveyorPrototype._on_product_hit(product)`; only a falling-lethal product can kill. |
| D3 background/product-bay falling product | Spawned through `spawn_external_conveyor_product()` and uses the same product-hit/kill path. D3 additionally emits `product_player_collision(schedule_index, lane_index, death_resulted, collided_at)` from its own listener. |
| Retrieval carriage/grabber | `AirSweeper.player_hit(sweeper)` → `_on_sweeper_hit(sweeper)`. Its pattern variants are the same death-source class. |
| Left-side OUT/chute | `OffBeltKillRegion.body_entered(body)` → `_on_off_belt_kill_region_body_entered(body)`, guarded by `left_failure_enabled` and player identity. |

All three core callbacks converge on **`_kill_player()` with no argument** → zero-argument **`player_died`** → `FixedRoundController._on_player_died()` → **`round_ended_by_death(score, time_remaining)`** → deferred `StandardSession._on_death(score, remaining)` → `_show_results(score, false)`. The wrapper retains `last_score` and `last_survived`, with no death enum/property. `RoundState` has RUNNING/DEAD/COMPLETE; `StandardSession.State` has MENU/GAME/RESULTS/CREDITS. Neither enum describes the cause.

Developer-only `MotionLocalInstrumentation` already tracks string classifications **`falling_product`, `retrieval_carriage`, `left_failure`, `background_product`, `unknown`** and records them in `run_end.death_cause`. It defers the run-end log to let individual hit listeners run; LEFT is a fallback inferred from player X. The D3 listener distinguishes `background_product`, overriding generic falling-product attribution. The existing motion test checks that deferred D3 classification. However, this logger is disabled in RC0 and its output is not consumed by Results. It is evidence of available source information, not a production result contract.

**Other distinctions for Work:** D3 background products may be a fourth art/copy treatment or grouped with other falling products. Landed products are solid/supporting, not a separate lethal-contact cause; being carried/pushed into OUT still ends via the OUT region. No additional direct Standard death source was found. A direct test/developer call to `_kill_player()` has no source and needs an UNKNOWN fallback. Time expiry is success, not a death cause. Prototype A has its own preserved falling-product death path and is not an additional Standard mode.

### Smallest future engineering change — proposal only

1. Add one typed `DeathCause` enum and per-run cause property to ConveyorPrototype (e.g. UNKNOWN, FALLING_PRODUCT, BACKGROUND_PRODUCT, RETRIEVAL_CARRIAGE, LEFT_OUT). Give `_kill_player(cause = UNKNOWN)` an optional cause; set it only after its existing dead/complete guard so the first lethal event wins.
2. Pass explicit causes from the current product, carriage and OUT callbacks without changing collisions, timing or outcomes. If distinct D3 copy is selected, mark D3-created products with source metadata **before they can collide**, then classify at `_on_product_hit`; do not depend on later logger-listener order or player position.
3. Preserve the current signal signatures. The existing deferred StandardSession death callback can snapshot `game.conveyor.death_cause` into a result field before cleanup and choose presentation later. Fresh run creation resets the source to UNKNOWN.
4. In that separately authorized pass, add focused tests for each cause, D3 attribution, first-cause-wins, clean retry reset, UNKNOWN fallback and unchanged successful completion. Keep all existing regressions.

No enum, metadata, field, signal, callback or message was changed here.

Source files: [session wrapper](../scripts/presentation/standard_session.gd), [conveyor](../scripts/conveyor.gd), [round controller](../scripts/fixed_round_controller.gd), [D3 director](../scripts/experiments/motion_background_drop_director.gd), [developer instrumentation](../scripts/experiments/motion_local_instrumentation.gd), [falling product](../scripts/falling_product.gd), [carriage](../scripts/air_sweeper.gd).

## Music master context for the next authorized implementation

Startup Lab reports the composer supplied `2026 09 08 miraie joltrome VENDING MACHINE BGM.wav` and `2026 09 08 miraie joltrome VENDING MACHINE BGM fade.wav`. **The non-fade master is the intended source for the eventual seamless runtime asset.**

Neither exact filename was found in the current project workspace/session attachments or at the corresponding exact paths in Downloads (where the earlier supplied MP3 resides). This records founder-reported receipt, not local binary verification. No waveform, hash, duration, loop boundary or permission status is inferred. Current [audio provenance](audio-source-inventory.md), runtime MP3, assets and playback remain unchanged. After UI direction is selected, a separately authorized pass can locate the supplied non-fade master, generate/import an appropriate runtime OGG, validate the seamless loop and replace the demo. No audio conversion or swap occurred here.

## Validation boundary

RC0's recorded baseline is 27/27 passing scripts, including 12 retry cycles and the full-round/D3 checks; see [engineering handoff and screenshots](vm060-presentation-audio.md). This preservation pass only changes documentation. Verify the changed-path list and runtime/config/test/build hashes against RC0; there is no behavioral change requiring a new gameplay tuning or test pass. Preserve all tests during the future UI integration and rerun them then, adding targeted interaction/layout checks only where needed.

Preservation verification: all **188 tracked runtime/configuration/asset/test files** were byte-compared with `1dcaae7` and are unchanged. The RC0 ZIP retains SHA-256 `0b0cbebe19691258eaaab7c6117105fe758422803753bf05fdd1509dce64ced0`. Contract links resolve, roadmap JavaScript parses, and the documentation diff passes whitespace checks. The gameplay suite was not rerun for this documentation-only pass; its recorded 27/27 RC0 result remains the baseline.
