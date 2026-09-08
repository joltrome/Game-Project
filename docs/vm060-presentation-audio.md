# VM-0.6.0 — Presentation & Audio Foundation

**Subsequent Startup Lab review:** RC0 is functionally accepted as the presentation/audio engineering baseline. The current menu/results visuals are rejected as the final direction; Work will explore their replacement. Commit `1dcaae7` has since been pushed unchanged. The implementation/QA record below describes the original RC0 task; its “unpushed”/no-push references are historical. See [UI functional contract](vm060-ui-functional-contract.md).

Date: 2026-09-08 JST. Candidate: **VM-0.6.0-STANDARD-RC0**, for Startup Lab review only. No itch.io upload or external distribution.

## Acceptance and repository state

Startup Lab explicitly reconfirmed both final corrections as accepted in this session. The coin micro-pass status and roadmap now record that acceptance; historical findings remain historical. Standard gameplay is frozen on S1 / P-A / C-A.

- Branch before and after: `release/vm-0.6.0-presentation-audio`.
- Starting HEAD: `e658cb848f7f0320b17c3c7e183e49a73eb246f7`.
- Starting working tree: clean. Live GitHub branch and local upstream matched HEAD, 0 ahead / 0 behind.
- Accepted coin commit: `e7f4d33140d4d3e654aa80068edb967d8d768c0e`.
- Accepted leftward conveyor commit: `e658cb848f7f0320b17c3c7e183e49a73eb246f7`.
- Final implementation is recorded in the local milestone commit containing this handoff. Its exact hash and final remote state are returned in the task response. No remote push is part of this milestone.

## Implementation

| Area | Behavior |
|---|---|
| Main menu | Default launch is `scenes/presentation/standard_session.tscn`. A small Control wrapper builds Menu/Game/Results/Credits screens; it instantiates no gameplay until Play. |
| Controls | Menu displays Move: A/D or Left/Right and Jump: Space. Keyboard focus supports Tab/Enter. R retries during gameplay/results; Escape returns from results/credits. |
| Standard | Play instantiates the accepted `motion_vis04_pa_ca.tscn`, applying only clean presentation/debug settings. All pre-existing gameplay scripts, art assets and gameplay scenes remain unchanged. |
| Results | Original round signals select GAME OVER or SURVIVED, actual coin score and local best. Connections are deferred so collision callbacks finish before the whole run is disabled. There is no long transition. |
| Retry | Replaces the entire run: player, timer, score, hazards, coin director, D3, carriage, warnings and observers. Audio belongs to the persistent session wrapper and survives this replacement. |
| Menu return | Removes and frees the full previous run. No hidden timer, hazard or director remains behind Menu. |
| Local score | `StandardScoreStore`, ConfigFile at `user://standard_best.cfg`, section `standard`, key `best_score`. Only a higher nonnegative score updates the record. Missing/corrupt/wrong-type/negative data falls back to zero. Failed writes retain in-session best and never block Play. |
| Routing | `default_bus_layout.tres`: Master → output, Music → Master (-6 dB), SFX → Master (0 dB). One MusicPlayer and one silent SFXPlayer per session; no mixer UI. |
| Music lifecycle | One start per application/page session. Desktop starts at menu. Web waits for a pressed menu key or mouse interaction; Play/Retry never duplicate playback. Results and menu return continue the same track. |
| Demo loop | Supplied Miraie MP3 copied unchanged. **TEMPORARY COMPOSER DEMO**, ~109.032 seconds, no loop, quiet tail preserved; silence after the demo ends until a fresh launch. No speculative audio editing. |
| Asset replacement | Set the Audio node's exported `music_stream` to the final approved seamless OGG/WAV, configure the composer's loop behavior, update provenance and repeat browser QA. No gameplay/menu rewrite. |
| Sound controls | Independent Music/SFX mute buttons in Menu, Game and Results. Mute changes the bus only and survives transitions. Session-to-session mute persistence is intentionally not implemented. SFX currently has no audible content. |
| SFX hooks | `coin_pickup`, `jump`, `landing`, `product_impact`, `rack_warning`, `rack_release`, `carriage_warning`, `carriage_sweep`, `player_death`, `final_seconds`, `round_complete`, `ui_confirm`, `ui_back`. Existing signals handle most events; jump/land are observed after player physics without writing gameplay state. |
| Debug/release | Standard F8 requires **both** `OS.is_debug_build()` and custom feature `standard_debug`. RC0 uses `standard_release`, release export and no instrumentation. Legacy comparison scenes remain available separately. |
| Normal labels | Build IDs, VIS-04, P-A/C-A, configuration comparisons, diagnostic instructions/legend and F8 text are hidden. No RC0 label is player-facing. Existing world signage and composition are preserved. |
| HUD | Existing timer and score hierarchy, sizes and urgency timing remain; limited outline consistency and top-left sound controls. No world/camera/redraw pass. |

Runtime music path: `res://assets/audio/miraie_main_theme_TEMPORARY_DEMO.mp3`.
Full source, permission status, original path, hash and replacement procedure: [audio inventory](audio-source-inventory.md).

## Screenshots

All are actual browser-rendered captures. Completion uses the isolated local QA harness described below; the screen itself is the same StandardSession implementation.

- [Main menu, 1280×720](screenshots/vm060/main-menu.png)
- [Death result, including preservation of a higher best](screenshots/vm060/death-result.png)
- [Completion result](screenshots/vm060/completion-result.png)
- [Gameplay/HUD](screenshots/vm060/gameplay-hud.png)
- [Menu at 800×600](screenshots/vm060/menu-800x600.png)
- [Independent mute controls](screenshots/vm060/menu-muted.png)
- [Persisted score reloaded in RC0](screenshots/vm060/best-score-reloaded.png)

## Automated verification

Godot **4.7.1.stable.official.a13da4feb**, 60 Hz. Before edits: **26/26 passed**. Final suite: **27/27 passed**, zero assertion failures. Three historical tests changed only their default-launch expectation from direct Conveyor to the new Standard menu; all their gameplay assertions remain.

| Regression | Result |
|---|---|
| Coin economy, seeds 401 / 1701 / 4202 | Exactly 54 / 55 / 55 coins; 22 offers; first offer 1.750 seconds. |
| Spawn safety | Zero spawn-frame intersections for all three audits. 8 px buffer, whole-offer sibling offsets, bounded retries/skips, normal collection and exactly-once score pass. |
| Conveyor | Negative visual animation speed retained; physical no-input/right/left speeds remain approximately -140/+160/-440 px/s. |
| Player/collisions | S1 six-frame 60 ms RUN, 32×48 player, 24×24 pickup, 60×60 falling and 72×48 landed geometry pass; movement/jump/gravity unchanged. |
| Carriage | P-A original Y=518 and unchanged path/speed/cues/collision pass. |
| D3 | Existing cadence tests pass; the new wrapper completes an isolated natural 60-second round with six D3 releases. Warning/release/impact, carriage and final-second hooks are observed. |
| Retry stress | 12 death cycles, including direct Retry chains and menu returns every fourth cycle. Constant fresh-run node count; no stale hazards, coins, pending stagger state, score or timer. |
| Results | Death score and title; complete scene frozen; distinct once-only 60-second completion; lower completion score preserves best. |
| Audio | Both buses/routes, independent mute/unmute, same MusicPlayer instance, exactly one start across all transitions, non-looping demo, no extra nodes. |
| Persistence | Missing, higher, lower, reload, wrong-type, negative, malformed config and unavailable storage paths pass. |
| Legacy | Prototype A and D2 still load and pass existing tests. No legacy scene deletion. |

Logs: `builds/validation-vm060/`, including `suite-summary.txt` and per-test logs. New focused test: `tests/test_vm060_presentation_audio.gd`.

## Browser and manual/runtime QA

Local Chromium WebGL2, single-threaded export, 1280×720 and 800×600:

- Menu opens with controls, a clear Play button and no internal comparison labels. No gameplay is present behind it.
- Keyboard menu navigation, Play, R retry, Escape menu return, movement/jump input and mute controls were exercised. Natural deaths and repeated replays were inspected; score/timer reset and old warnings/hazards do not carry over.
- Browser-side Web Audio instrumentation observed **zero buffer-source starts before interaction**. A real menu Tab keypress started one ~109.032-second non-looping source. The same source/start count persisted across Play, death, retries, menu return, focus/tab changes and beyond the demo's end (context time exceeded 545 seconds). It did not restart or stack.
- Music/SFX mute labels change independently and remain through transitions. Automated bus checks verify routing. Musical balance and subjective listening approval remain with Startup Lab; no waveform comparison was used.
- A separate ignored QA scene runs the same original 60-second controller and natural hazards with player collision/motion disabled solely to guarantee a complete round. A real spawned coin callback supplies score 1. Browser output recorded `LOCAL_QA_COMPLETE score=1 best=1 music_starts=1`; SURVIVED rendered correctly. This harness and its export are **not in RC0**.
- IndexedDB `/userfs` contained `[standard] best_score=1`. Navigating to the production RC0 on the same origin loaded BEST SCORE 01; a subsequent natural zero-score death showed 00 collected / 01 best. The same save code ran in both builds.
- Layout remained readable and unclipped at both tested sizes; 800×600 uses a centered 16:9 presentation with letterboxing.
- Final RC0 browser console: **zero errors**, but not warning-free. Chromium emits `bindBuffer: element array buffers can not be bound to a different target` and `bufferSubData: no buffer`. The unchanged accepted P-A/C-A Web build reproduced the same two warning types in this environment. These are recorded findings; no renderer/gameplay workaround was introduced.

Browser persistence depends on available IndexedDB/site storage and the hosting origin. Clearing site data, private browsing, storage eviction or iframe restrictions may remove/prevent persistence. It does not sync between devices. Browser audio begins through normal user interaction, following [Godot's Web export guidance](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html). Safari/Firefox and the actual itch.io iframe were not tested in this milestone; there was no upload.

## Export and review artifact

- Preset: `Web Standard RC0`; custom feature `standard_release`.
- Entry point: `builds/VM-0.6.0-STANDARD-RC0/index.html`.
- Archive: `builds/VM-0.6.0-STANDARD-RC0.zip` (14,815,111 bytes).
- Archive SHA-256: `0b0cbebe19691258eaaab7c6117105fe758422803753bf05fdd1509dce64ced0`.
- Export succeeds with single-threading; ZIP has `index.html` and its JS/PCK/WASM/runtime support files at the archive root. No docs/tests/local QA harness are included.
- Serve over HTTP; do not open the HTML via `file://`.
- Review only. No upload, public hosting, external playtest or SFX sourcing.

## Findings, limits and next review

No blocker remains to **internal RC0 review**. Before a final music/release candidate: obtain explicit commercial confirmation, preferred composer credit and proper seamless asset; then authorize VM-0.6.1 SFX/content work. No SFX currently play because slots are intentionally empty.

Environment findings:

1. Godot headless execution prints the pre-existing macOS CA-certificate diagnostic; sandboxed editor/export also reports unavailable editor-settings writes. Neither prevents tests or export.
2. Starting MP3 playback and exiting with the dummy headless audio driver reports one AudioStreamMP3 and one AudioStreamPlaybackMP3 reference at shutdown, even after explicit stop/free. A minimal standalone player outside the session wrapper reproduces it (`builds/validation-vm060/repro_headless_audio.gd`). Repeated-run node/audio counts remain constant; no browser duplication was observed. This is a recorded headless/engine finding, not silently hidden.
3. The malformed-config test intentionally causes ConfigFile's parser diagnostic; it verifies safe recovery and continues to pass.
4. The two WebGL warning types reproduce in the accepted baseline, as described above.

Optional later Work/art brief: refine the **existing runtime menu/results typography and button treatment** using these screenshots, retaining geometry, controls and established palette. No new art task was started and no full redesign is recommended before Startup Lab reviews the functional flow.

No Overload, time-giving coins, new routes, extra modes, hazards, movement, multipliers, accounts, online leaderboard, analytics or monetization were added. No original gameplay file changed. Right-side elevator and all unrelated gameplay/presentation ideas remain backlog only.

## Changed files and cost

Implementation: four scripts under `scripts/presentation/`, `scenes/presentation/standard_session.tscn`, their Godot UIDs, `default_bus_layout.tres`, `project.godot`, one new Web export preset, the demo MP3/import metadata. Tests: one new presentation/audio suite and default-launch assertions in three older suites. Documentation: this handoff, audio inventory, acceptance record, roadmap, README, gameplay/design backlogs, cost ledger and seven screenshots/import metadata.

Model: GPT-6 family exposed by session instructions; Astra/High requested, exact runtime variant and reasoning setting not independently exposed. Authentication: ChatGPT/Codex context, exact authentication details unavailable. Services: local Git/Godot/Python, localhost HTTP/browser tools, read-only GitHub branch check and official Godot documentation lookup. OpenAI API requests: **0**. Third-party paid-service requests: **0**. Input/cached/output units and subscription usage: not exposed; check Codex Settings → Usage if needed.

**Separately billed cost this task: $0.00**. Cumulative recorded separately billed project cost: **$0.00**.
