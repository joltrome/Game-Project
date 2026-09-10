# VM-0.6.2 GET CANNED! RC2 — implementation and Startup Lab handoff

Status: implemented for Startup Lab review. No itch.io upload. No final SFX.

## Checkpoint and scope

Before implementation: `release/vm-0.6.1-get-canned-rc1`, clean working tree, HEAD `9a447fc451b78111ee221abad373a8775379adf5`, initially without upstream. Pushed that unchanged RC1 checkpoint first and verified the live origin branch at the same full hash. RC2 branch: `release/vm-0.6.2-presentation-cohesion`.

Evidence: Startup Lab's VM-0.6.2 brief; Work's `vm062_get_canned_presentation_cohesion/implementation/HANDOFF.md` and `manifest.json`; native render captures, measured transforms, headless tests and local browser QA. Work's handoff and manifest are preserved under `assets/ui/get_canned_rc2/provenance/`. Runtime PNGs are byte-identical to Work. No redrawing or new font family.

DECISION: extend C2 to HUD, Credits and Pause; put mid-run audio controls in Pause; use the authored KO for impact deaths and a simple clipped chute disappearance for OUT. Correct the measured can-contact position only. Existing Standard P-A/C-A/S1 tuning, coin economy/topology/8 px exclusion, bounded whole-offer retries, leftward conveyor, jump aliases, hazard cadence/speeds, 60 seconds and score values remain frozen.

## Functional and visual implementation

- **HUD:** centered C2 timer at ink Y12, three-times display glyphs; existing countdown rounding, urgency thresholds and pulse driver retained. Work's coin icon beside the right-aligned, minimum-two-digit score; full int64 values fit without truncation. Old timer card and score/card/COINS presentation hidden; underlying scoring/timer controllers retained. No live Music/SFX buttons. World warnings and coin pickup feedback retained.
- **Credits:** exact CREDITS., GAME / DESIGN, JOLTROME, ORIGINAL MUSIC, MIRAIE, BACK and Music/SFX assets. No slogan. Manifest-driven layer/block structure uses the two current baked blocks. Future legitimate blocks can be supplied as additional assets/layer entries using Work's recorded expansion grid; empty placeholders and speculative scroll UI are not added.
- **Pause:** Esc or P toggles; R retries. Uses `SceneTree.paused` and a pausable gameplay subtree, while the session, UI and persistent audio continue processing. It does not invoke terminal gameplay cleanup. The existing live frame/HUD remain behind the overlay. Dimmer is exactly RGBA **(13,20,36,140)**, alpha **140/255 = 54.90196%**, applied once. Focus order: Resume, Retry, Menu, Music, SFX. Resume retains the exact run; Retry creates a fresh scene; Menu disposes the old scene and clears pause.
- **Focus:** native/Web window-focus-out requests Pause only during a live, nonterminal run. Focus return never resumes automatically. Browser/app switching behavior outside tested Chromium still needs physical-device coverage; no large visibility workaround was introduced.
- **Mobile:** Work's 48×48 CSS-pixel Pause target is at fitted-game inset (8,8), using the existing counter-scaled touch layer. At 844×390 the game fits 693.333×390 with 75.333 px side margin; Pause occupies CSS X83.333–131.333, Y8–56. Hidden outside gameplay. Pause hides native TouchScreenButtons and clears Left/Right/Jump; fresh touches work after Resume. Portrait rotate guidance remains. Scope remains mobile Web playtest compatibility.
- **Menu/results:** accepted C2 logo, CLOCK IN, layouts, VENTASTIC placement and cause headlines retained. No new subtitle or flavor copy. Success remains CLOCKED OUT.

## Death presentation

`MotionV2VisualIntegration` has an opt-in RC2 live-pose signal before its legacy collapse handler. The session captures the actual texture/frame, global transform, visibility, bottom-center anchor and facing; the original technician is hidden. A presentation-only `StandardDeathReaction` processes independently of the disabled run. Legacy experiment scenes retain their old behavior by default.

Exact Work sheet: `death/technician-impact-ko.png`, 560×96; five 112×96 frames, anchor (40,88), native scale 1. Mirror the parent anchor, not the texture around an incorrect center. Airborne anchors remain airborne; no corpse physics or interactions are introduced.

Timing from the first lethal signal: **70 ms captured-pose hit-stop + 420 ms KO + 260 ms final hold = 750 ms**. KO frame durations: **60,70,80,80,130 ms**; boundaries at **70,130,200,280,360 ms** after death. The last pose begins at 360 ms, completes its authored duration at 490 ms, then holds to 750 ms. Results use the same monotonic deadline; observed headless transitions were approximately 757–774 ms due to frame scheduling. No additional 750 ms wait follows the animation.

Ordinary and D3 impacts → CANNED.; carriage → GRABBED.; OUT → VENDED.; unknown → GAME OVER.; success → CLOCKED OUT. First cause wins; disabled player/hazards/timer/coins cannot change the result. The tests also cover a competing late completion and stale callbacks from disposed runs.

OUT uses the current captured pose, clipped to world rectangle **(108,446,48,116)** and moved **64 px down over 160 ms**, then hidden. This is visual-only and does not extend the 750 ms deadline. An already invisible pose stays invisible. Unknown deaths retain their captured pose without inventing an impact reaction.

Native inspection: product and carriage KO render correctly; airborne KO remains visibly suspended during the brief hold, as specified. The can-top pose rests at the corrected top. Left/right edges retain the actual anchor and normal world clipping; no recentering/clamp was added. Near-OUT impact can overlap the carriage rail during the frozen beat; this is recorded for art review, not compensated with physics. OUT's earlier below-chute pose was removed by the approved clipping/disappearance treatment.

## Contact investigation and narrow fix

All Y values below are world coordinates (the camera's presentation offset is separate). Visible boot bottom equals player collider bottom and visual anchor. Player rectangle remains **32×48**; falling product collision remains **60×60**; landed support remains **72×48**.

| Measurement | Conveyor | Ordinary can before | D3 can before | Ordinary/D3 after |
|---|---:|---:|---:|---:|
| Visible boot bottom / player collider bottom / anchor Y | 583.994812 | 535.999878 | 535.999878 | 539.999939 |
| Visible supporting surface Y | 584 | 540 | 540 | 540 |
| Physical supporting top Y | 584 | 536 | 536 | 540 |
| Visual gap | 0.005188 px | 4.000122 px | 4.000122 px | 0.000061 px |
| Can collider bottom Y | — | 584 | 584 | 588 |

Diagnosis: settled 36×24 can art has two transparent top source rows, displayed at 2×, creating a **4 px** offset. Can body/art center remains Y560, visible bottom584; sprite local offset remains (0,0). Player boots are already correct on the conveyor, so no player/global visual adjustment was warranted.

Fix: in RC2 only, move the landed `CollisionShape2D.position.y` from **0 to +4** for both sources. Size is still **72×48**. The lower four pixels now extend beneath the conveyor plane; the visible art remains seated on the belt. This changes effective support height by the explicitly authorized 4 px correction, not the jump arc or collision dimensions. Existing geometry/spawn safety remains conservatively based on the original envelope. Legacy experiment defaults remain offset0, retaining the original landed-Y regression; the new RC2 regression verifies top540 for both sources.

Fixtures verified standing, moving support, jump launch and downward landing, walking off onto the conveyor, multiple landed products, and ordinary/D3 source equivalence. The jump-return fixture follows the moving platform horizontally to isolate vertical landing; it is not a claim about unassisted human execution. Ordinary-source measurement waits for the real belt to carry the can inside the reachable band before placing the player.

## Validation and artifacts

Baseline: **30/30 scripts passed before editing**. Final: **34/34**, consisting of those same 30 plus `test_vm062_cohesion.gd`, `test_vm062_contact.gd`, `test_vm062_death_reaction.gd`, `test_vm062_touch_pause.gd`.

- Pause: exact snapshots of player position/velocity, timer, hazard position/lifetime, warning time, coin/score state and animated frame. Simulation resumes after unpause; audio controls remain usable. **30 Pause/Resume cycles** and **20 fresh Retry-from-Pause cycles** passed, retaining the same persistent music player. Three-finger test holds Right+Jump, taps Pause, releases fingers and resumes without stuck actions.
- Native visual QA: HUD, Credits, Pause, product/carriage/airborne/left-edge/right-edge/can-top KO and OUT. Captured with the actual renderer. QA scripts disable unrelated hazards where needed; runtime does not.
- Web Chromium: desktop menu, Credits, Pause, Retry/Menu flows; 844×390 DPR2 landscape Pause/touch interaction; portrait guidance; real **800×450 local iframe** loaded and paused with visible HUD and no clipping. This is an itch-style local embed, not a hosted itch test. No physical device was used.
- Console: clean fresh embedded load after adding the QA wrapper's favicon. Repeated live DPR/orientation changes reproduced RC1's Chromium `bindBuffer`/`bufferSubData` WebGL warnings; no GDScript errors were observed. This remains an engine/browser coverage caveat, not a claim of a universally warning-free resize path.
- Native environment: sandbox certificate/editor-settings-save diagnostics and the existing occasional two-ObjectDB exit warnings. Successful export and isolated PCK resource validation are recorded separately; no new runtime script error remains in the passing tests.
- Final Web pack: required C2 glyph metrics, RC2 layout and KO resource present; docs/tests/tools/build archives and temporary MP3 excluded; `standard_release` enabled, `standard_debug` absent. ZIP has `index.html` directly at root.

Local artifact root: `builds/validation-vm062/` (ignored generated evidence).

| Artifact | Path |
|---|---|
| Gameplay / Credits / Pause | `native/gameplay.png`, `native/credits.png`, `native/pause.png` |
| KO recordings | `native/product.gif`, `native/airborne.gif`, `native/carriage.gif`, `native/near-can.gif`, `native/left-edge.gif`, `native/right-edge.gif` |
| OUT recording | `native/out.gif` |
| Contact before/after overlays and measurements | `contact/before-ordinary.png`, `contact/after-ordinary.png`, corresponding D3/conveyor images; `contact/before.json`, `contact/after.json` |
| Browser evidence | `browser/desktop-pause.png`, `browser/credits.png`, `browser/mobile-pause.png`, `browser/mobile-multitouch-pause.png`, `browser/portrait.png`, `browser/embedded-pause.png` |
| Test logs/count | `baseline/summary.json`, `final-tests/summary.json` and individual logs |
| Asset hashes | `asset-verification.json` |
| Release folder / root ZIP | `builds/VM-0.6.2-GET-CANNED-RC2/`, `builds/VM-0.6.2-GET-CANNED-RC2.zip` |

## Music, costs and remaining review

Music architecture/source/import were not edited. Original WAV SHA-256 remains `1e12cc678e944c2ea1aa560653c1c07e3b26a1dbdd9dfead40d3deced3b391d4`. Accepted native full-length looping and decoded guard remain; no manual restart, trimming, fade, crossfade, OGG or rejected A/B/C source. One persistent player across menu, gameplay, Pause, results and retries. Silent SFX hooks remain; no final SFX sourced or implemented.

Model: GPT-6 family in Codex; Astra/High requested. Exact runtime variant/reasoning, authentication details, token counts and subscription consumption are not independently exposed here. Several usage-limit/app interruptions occurred; no token or dollar estimate is invented. Review Codex Settings → Usage for account usage. OpenAI API requests: **0**. Paid external-service requests: **0**. **Separately billed cost this task: $0.00**. Cumulative separately billed project cost: **$0.00**.

Remaining review: Startup Lab should judge KO feel (especially airborne/rail overlap), Pause readability and small-screen typography. Real iOS/Android, Safari/audio interruptions, broader focus-loss behavior and actual itch hosting remain unvalidated. The unchanged original WAV keeps the existing download-size cost. Gameplay retuning and final SFX are outside RC2.

**Return to Startup Lab: YES — Return now.** Review this build before authorizing external distribution or the SFX milestone. Git checkpoint details are recorded below after validation.

## Git checkpoint

Implementation commit: `b4e54660a76615d98fbf04dc5ec19bfd0b021c57`. Tests, QA fixtures, roadmap and this report are committed separately. The final documentation commit and verified origin HEAD are supplied in the session handoff (avoiding a self-referential commit hash). RC2 is pushed without force after final validation.

Changed implementation files: `scripts/presentation/cohesion_hud.gd`, `cohesion_screen.gd`, `standard_death_reaction.gd`, `standard_session.gd`, `standard_touch_controls.gd`, `c2_screen.gd`; `scripts/experiments/motion_v2_visual_integration.gd`; `export_presets.cfg`; 48 exact Work PNGs plus imports/layout/provenance under `assets/ui/get_canned_rc2/`. Supporting changes: four RC2 tests, three QA scripts, this report, roadmap and cost ledger.
