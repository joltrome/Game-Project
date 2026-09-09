# VM-0.6.1 GET CANNED! RC1 — Startup Lab review

2026-09-09 JST. **Implementation candidate; return to Startup Lab now.** No itch upload, external test launch, final SFX or Overload work. Standard gameplay remains frozen.

## Checkpoint and scope

Accepted remote RC0: `release/vm-0.6.0-presentation-audio` at `437f76f643d0caa35e6b9dbf88c437561ae893d9`. Original engineering RC0 is `1dcaae78cf40b3fe44bdd5157c64a0e62d8afa92`. Both remain preserved. Latest pre-integration local HEAD: `d348aaaf454808ea171095053f59ffbeb3cf7c91`, branch `release/vm-0.6.1-get-canned-rc1`; preceding commits record rejected audio experiments, not runtime changes. The 188 existing runtime/config/asset/test files were verified identical to accepted RC0 before integration; all 27 baseline scripts passed again.

RC1 changes are the presentation scripts/scene, copied C2 PNGs/metrics and original WAV, jump mapping, typed death source in `conveyor.gd`, a three-line post-stop collection guard in `collectible_director.gd`, an RC1 export preset, focused tests, local QA recipes and documentation. Internal project name and paths remain unchanged to preserve the existing best-score storage namespace. The window/browser title and visible logo say **GET CANNED!**.

Live remote recheck on 2026-09-09 still returned RC0 at `437f76f643d0caa35e6b9dbf88c437561ae893d9`; no RC1 remote branch exists. RC1 is committed locally and unpushed. The final commit ID and clean working-tree state are reported in the completion handoff; this report belongs to that commit.

## Work integration and visual review

Authoritative package: `/Users/jeromenicholaz/.codex/.chatgpt-projects/g-p-6a620f9598f48191b1f5f1a94286b5cd/artifacts/vm060_get_canned_c2_production/`. Its HANDOFF, manifest, font/source records and five gameplay source sheets were checked. **38 copied PNGs are byte-identical**; existing approved gameplay sprite sheets are referenced directly.

- C2 Minimal, logical 1152×648, aspect-preserving letterbox; no marquee or decorative additions.
- L1 compact logo: (300,96), 552×184. Menu-only VENTASTIC: **(1006,609), 102×14**, per production package (not the smaller earlier refinement mark).
- CLOCK IN, no exclamation: hit region (416,472), 320×70. Exact Work idle/focus/pressed PNGs; visible padding does not change the hit box. Hover and keyboard focus share focus art; pressed takes precedence. Deterministic keyboard wrap: CLOCK IN → Credits → Music → SFX; results: Retry → Menu → Music → SFX.
- Shared results composition; only headline varies. Run and best numerals use the supplied display atlas, common fit scale, two digits minimum, no truncation through signed int64 maximum. Menu best uses the specified right anchor and shrinking scale.
- Work's white atlas plus JSON metrics renders the two glyph families with exact ink-top/ink-width alignment and nearest filtering. No commercial font dependency. The unused BMFont descriptors are preserved as `.fnt.txt` in provenance because Godot's font import claimed the shared PNG atlas; the documented metrics fallback avoids that importer conflict without changing pixels.
- Authorized compact legend difference: **SPACE / W / UP**. The supplied small atlas has no up-arrow glyph. Only the old SPACE pixels are covered; the added aliases use existing glyphs and fit the allotted area.
- Exact authentic tableau: S1 run, coin spin, landed can crop, leftward conveyor. Run: six frames ×60 ms; coin: six ×90 ms; belt: reverse 3,2,1,0 ×100 ms; results use idle technician. No logo bounce, sparkles or unrelated animation.
- Credits retains its existing layout/font and factual Miraie credit; the game title/music description is current. Gameplay HUD typography is retained.

Native pixel comparison against Work's final references found **zero differences in static regions** for the menu and all five result designs after masking the intentional legend, variable score/mute state and sprite animation phase. Comparison is not a claim that fractional phone scaling reproduces every source pixel exactly.

Evidence (local ignored QA files):

- [Final browser menu](../builds/validation-vm061/screenshots/web-menu-final.png), [native comparison fixture](../builds/validation-vm061/screenshots/menu.png), [live menu GIF](../builds/validation-vm061/screenshots/menu-runtime.gif).
- [CANNED](../builds/validation-vm061/screenshots/canned.png), [GRABBED](../builds/validation-vm061/screenshots/grabbed.png), [VENDED](../builds/validation-vm061/screenshots/vended.png), [GAME OVER](../builds/validation-vm061/screenshots/game-over.png), [CLOCKED OUT](../builds/validation-vm061/screenshots/clocked-out.png).
- [Credits](../builds/validation-vm061/screenshots/credits.png), [touch layout](../builds/validation-vm061/screenshots/touch-844x390.png), [Web simultaneous right+jump at DPR2](../builds/validation-vm061/screenshots/web-touch-multitouch-844x390-dpr2.png).

Screenshot harness scores/mutes are fixtures, not changes to actual saves. The menu GIF captures the running production animation at approximately 60 ms intervals; it is visual evidence, not a frame-timing benchmark.

## Death, state flow and input

Per-run `ConveyorPrototype.DeathCause`: UNKNOWN, FALLING_PRODUCT, BACKGROUND_PRODUCT, RETRIEVAL_CARRIAGE, LEFT_OUT. Existing lethal handlers pass an optional cause into `_kill_player()`. External D3 products receive source metadata before collision signals/tree insertion. The existing first-death/round-complete guard executes before assigning the cause. Public signal signatures are unchanged.

Flow: lethal handler → `_kill_player(cause)` → `player_died` → existing fixed round death signal → deferred session snapshot → DEATH_BEAT → shared RESULTS. Bound run serials reject stale callbacks from a disposed run.

| Outcome | Result headline |
|---|---|
| Ordinary falling product | CANNED. |
| D3 background product | CANNED. |
| Retrieval carriage | GRABBED. |
| Left OUT/chute | VENDED. |
| Unknown | GAME OVER. |
| 60-second success | CLOCKED OUT. |

Death presentation constant: **0.75 real seconds**, measured in focused tests at approximately 0.75–0.78 s including frame scheduling. A monotonic deadline prevents a large current frame delta shortening the hold. The complete game scene stays visible and disabled; the old generic death overlay is hidden. Input, hazards, score and timer cannot continue changing the outcome. No shake, VFX or new death animation. Successful completion still goes directly to results.

One pre-existing late-callback gap mattered to this acceptance criterion: hiding/stopping a coin did not reject an already queued collection signal. The collected callback now returns when the director is stopped. This changes only post-death/completion handling, not offers, scoring values or active gameplay.

R starts a clean run from gameplay/results; Escape returns from results/Credits to menu. R is ignored during the short death beat. Retry disposes the entire game tree and creates a fresh Standard scene; Menu removes it. Best score uses the unchanged local ConfigFile behavior and storage path. Both mute states survive transitions within the application session; they are not new persisted preferences.

Space, W and Up all map to the **same `jump` action**. Tests feed each key through Input and the existing shared jump controller; each produces the same -700 test-controller velocity. Production player physics, speed, gravity, coyote time and buffering are unchanged.

## Original music

See [full investigation](vm061-original-wav-investigation.md) for source/reference hashes, decoder evidence, import settings and the founder's passed listening gate. **A/B/C are rejected and unused.** Entire original → original frame 0 is the required sequence.

The original non-fade WAV is byte-identical in the repository. Godot imports stereo PCM16 at 48 kHz, full-file forward loop [0,4542981), without trimming/normalization/forced rate. One runtime-only first-frame decoder guard corrects the verified Godot 4.7.1 endpoint read; it adds no audible time. Actual period: 94.6454375 s. Explicit STREAM avoids the Web sample backend's observed incorrect near-end restart. No manual end-of-track restart callback.

No OGG/conversion service; local FFmpeg lacks libvorbis. WAV is retained under the founder's later instruction. The runtime PCM payload is approximately 18.17 MB; this is a meaningful download/memory caveat for mobile, not evidence of a performance failure. A future compressed derivative requires direct original-source conversion and listening validation.

Native numerical comparison: three wraps exactly equal direct original PCM concatenation; founder accepted the native capture by ear. Isolated Web STREAM harness: seven wraps from one start. Session regression: 12 fresh retries, one music instance and one start. Browser emulated touch CLOCK IN produced a running AudioContext; combined direction/jump, results and menu did not require another context. Actual phone audio/device policy remains unverified.

## Mobile and validation

Touch layer: three native `TouchScreenButton`s map to move_left, move_right and jump. Native per-finger handling supplies hold, release, drag across/outside and multitouch. Hidden on ordinary desktop; shown through touchscreen/coarse-pointer detection or first touch. Hiding on death/retry/menu and focus loss releases held touch actions. No alternate physics or gesture system.

Targets remain **72×72 CSS px** for Left/Right and **96×72** for Jump, with 12 px bottom margin, within the fitted game area. Only the overlay counters window stretch and Web devicePixelRatio; game scaling/geometry is unchanged. A translucent treatment keeps the lower play area visible. Finger occlusion and comfort need real-device review. Portrait shows nonblocking ROTATE DEVICE; it does not rearrange the game or force orientation.

| Check | Result / limit |
|---|---|
| Baseline | All 27 existing scripts passed before editing |
| Final suite | **30/30 scripts passed**; affected presentation/input tests rerun after final overlay adjustments |
| Cause/race | All lethal handlers, production D3 source marker, first contact wins, late death at 0.001 s, completion first, stale run callback, exactly one result |
| Death beat | Delayed result, scene hold, no post-death pickup, fixed score/time/cause, no R during hold |
| Retry/persistence/audio | 12 cycles; fresh player/timer/hazards/offers/D3, constant node count, one player/start, independent mutes; missing/corrupt/unavailable save behavior preserved |
| Keyboard | Space/W/Up identical action and jump; browser Enter/Tab/Escape and Credits flow exercised |
| Touch automation | Left/right press/release, direction drag, drag-out, simultaneous direction+jump, release one while holding other, focus/transition cleanup |
| Browser touch | Emulated CLOCK IN, both held buttons highlighted, technician visibly jumped while moving right, audio context running |
| Desktop/browser | 1152×648 menu/results, natural OUT death, Retry/Menu, best 22 retained across reload, Credits and audio controls |
| Responsive | 844×390 DPR1/DPR2 and 667×375 landscape; 390×844 portrait guidance. Aspect preserved; text intentionally small per Work |
| Real devices | None accessible; no claim of iPhone/Safari/Android or itch iframe validation |
| Console | Fresh load/play flows clean. One live DPR/orientation change emitted four Chromium WebGL buffer warnings without visible failure; clean after reload. Retained as a device/engine QA caveat |
| Native environment | Sandbox certificate/editor-settings diagnostics and occasional two-ObjectDB exit warnings; no script errors in passing suite. Export verified despite editor-settings save restriction |

Frozen regression checks retain P-A/C-A/S1, 60-second Standard, six D3 releases, coin topology/exclusion/retries and corrected leftward conveyor visual/physical behavior. No gameplay export property was retuned; player and hazard behavior files/scenes/assets are unchanged.

Build: `builds/VM-0.6.1-GET-CANNED-RC1/index.html`; ZIP: `builds/VM-0.6.1-GET-CANNED-RC1.zip`. Export uses `standard_release`, excludes tests/tools/docs/build archives and the temporary MP3, includes required glyph JSON. ZIP: 27,634,992 bytes (26.35 MiB), SHA-256 `6fc6b74d9f931d9b4262972638702e289c18d8635ef58d4e0e6c331146c5c43b`. ZIP contents and final sizes/hashes are in `builds/validation-vm061/export-artifact.json`. No upload.

## Decision and cost

**Return to Startup Lab: YES — Return now.** Review visual fidelity, death-beat feel and mobile usability before approving external testing. Native original-WAV listening is already accepted. Remaining limits are physical-device/browser coverage, the observed live-resize WebGL warning, mobile payload size, and future SFX/optional compressed audio work.

Model: GPT-6 family exposed; Astra/High requested, exact runtime variant/reasoning not independently exposed. Codex/ChatGPT session context; precise authentication/token/subscription consumption unavailable. OpenAI API requests: 0; paid third-party/service requests: 0. **Separately billed cost this task: $0.00**. Cumulative separately billed project cost: **$0.00**. No paid conversion, image generation, extra credits or hosting. Check Codex Settings → Usage for subscription allowance; no token counts are invented.
