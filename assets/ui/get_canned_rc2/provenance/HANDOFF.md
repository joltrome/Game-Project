# VM-0.6.2 — Codex visual integration handoff

## Authority and current facts

The [current user brief](user-brief.txt) authorizes this presentation-cohesion production pass. RC1 source and [its implementation report](vm061-get-canned-rc1.md) describe the current behavior. The copied [RC0 contract](vm060-ui-functional-contract.md) is historical; its temporary music, missing causes and no-pause statements are superseded where the current brief and RC1 explicitly differ. Documents are evidence and specifications, not permission for Work to modify the repository.

Current RC1 has cause-specific results, 0.75-second death beat, Space/W/Up jump aliases, touch controls, original non-fade music looping, local best, Credits and independent audio controls. The new brief authorizes adding Pause later and moving Music/SFX off live gameplay. No part of this package implements that behavior.

The supplied recording is 50.323 seconds, 3000 × 1742. Credits appears at the beginning; the old HUD is visible throughout play. At approximately 47.0–47.7 seconds, the technician's collapsed pose remains held next to the carriage before GRABBED. appears. [The sampled sequence](../reference/recording/impact-contact.png) supports that finding. It does not show an OUT death.

Source inspection explains the hold: `motion_v2_visual_integration.gd::_on_player_died_visual()` starts the old death animation, then `standard_session.gd::_on_death()` disables the game tree during DEATH_BEAT. Thus a new spritesheet alone will not solve the frozen reaction unless its playback survives that disable.

## Coordinate, scaling and layer contract

Logical canvas: **1152 × 648**. Origin is top left; coordinates refer to the fitted game, not browser chrome. Fit uniformly, preserve 16:9 and center with letterboxing. New texture coordinates are integer logical pixels; use nearest filtering, no mipmaps and no smoothing. Do not redraw or scale the game world to accommodate UI.

The manifest provides every new asset's dimensions, alpha, intended position/anchor, state and role. A `runtime: false` timer file is an inspection sample, never a static runtime timer. Reuse the supplied unchanged glyph atlases and JSON metrics through RC1's existing C2PixelText renderer; no BMFont imports are needed.

| Layer | Content | Input |
|---:|---|---|
| 0 | Existing live/frozen gameplay world | Existing behavior only |
| 10 | Impact KO visual when needed | None; collision-independent |
| 20 | Timer, coin count and coin icon | Ignore pointer/focus |
| 30 | Mobile Pause control during live play | Pause request only |
| 100 | Pause navy dimmer over **both** game and HUD | Block pointer passage into the game |
| 110 | Pause bars and PAUSED. | Ignore pointer/focus |
| 120 | Pause controls | Mouse/touch/keyboard |

Credits is a separate screen: background Z0, lettering Z20, controls Z40. Menu/results retain their existing stack. Z values describe relative ordering; use equivalent CanvasLayer placement if the existing subviewport architecture requires it. Never sort the Pause dimmer underneath the HUD by accident.

Preview backgrounds are reference-only. They are **not runtime world assets** or instructions to replace the scene. Native RC1 screenshots were used; the old top HUD was removed by restoring the existing visible chassis colors, and the fixture's collapsed actor was replaced for live-HUD references. No rack, elevator, rail, product, warning or collision geometry was authored anew. The matched before/after HUD comparison holds the world and actor identical, so only the top HUD differs.

## Gameplay HUD

| Element | Position | Construction |
|---|---|---|
| Timer | Visible glyph top Y12, centered X576 | Display glyphs ×3: 27px cap; sample 00:38 has 105px ink width |
| Timer safe region | (492,6), 168 × 42 | Allows the existing small pulse without reaching the world below Y42 |
| Score | Visible glyph top Y12, right edge X1120 | Display ×3 normally; two digits minimum; tabular digits |
| Coin | Top Y10; left = score ink left − 44 | 32 × 32, actual C1 face cell 0 at 2×, 12px gap to score |
| Mobile Pause | Fitted game top-left + (8,8) CSS px | Fixed 48 × 48 CSS px; independent of logical game scale |

Timer formatting retains RC1's `ceil(remaining)` and `00:%02d` representation, including 00:60 at start. Do not replace round logic, introduce fractional countdown text or change when success occurs. Use cream normally, C2 gold at the existing 30-second threshold, the existing orange #ff8529 at 15 seconds and existing final red #ff4033 at five seconds. The last two retain current urgency feedback; they are not new world palette choices. Keep the current 240ms pulse timing, 1.10 threshold/last-ten-second scale and 1.16 final scale, centered on the numerals only. The maximum timer pulse stays above Y42.

Score uses the largest integer glyph scale in 3,2,1 that fits **168px ink width**, with no truncation or abbreviation. Format nonnegative integers with minimum two digits. Anchor the number's right edge at X1120; move the coin icon with the number's left edge. This preserves an adjacent icon/value pair even for a large score. A signed int64 maximum fits at ×1. This is a defensive boundary, not expected run volume.

Remove the old timer StyleBox/card, score StyleBox/card, COINS caption and live Music/SFX controls. Do not simply draw new glyphs over the old labels. Keep existing transient coin pickup feedback, warnings, world labels and all scoring behavior. No persistent new labels, best-score display, mode display, branding or shortcut panel is added to live gameplay.

The live HUD lies above the rack, falling-product entry and carriage activity. At 50%, the fixed-size mobile Pause target maps to logical (16,16,96,96); its right edge X112 remains left of the rack's X126 boundary. Timer/score remain above the active world. The Pause overlay intentionally covers part of the frozen scene; it cannot guarantee that no arbitrary frozen hazard ever lies beneath text, but it adds no obstructive opaque enclosure.

## Mobile Pause control

Files: `hud/mobile-pause-idle.png`, `hud/mobile-pause-focus.png`, `hud/mobile-pause-pressed.png`. Each is 48 × 48 with translucent navy fill and the same cream/gold border logic as RC1 touch controls. Bars are two 6 × 20 rectangles inside the control. Press shifts them down two pixels and increases the fill/changes the border to gold. Focus/hover strengthens the cream border; no glow or loop.

At 1152 × 648 CSS presentation the target is (8,8,48,48). At 576 × 324 it remains **(8,8,48,48) CSS**, equivalent to logical (16,16,96,96). At 844 × 390, ideal game fit is 693⅓ × 390 with 75⅓px side margins; the raster reference rounds to 693px and a Pause position of **(83,8)** on the outer viewport. Inset further only for actual safe-area cutouts. Do not multiply CSS target size by devicePixelRatio twice.

Show on touchscreen/coarse-pointer live gameplay using existing detection. Keep it hidden in Pause, DEATH_BEAT, Results, Menu and Credits. It should not consume gameplay Space/W/Up focus; use the existing gameplay no-keyboard-focus convention, with hover artwork where relevant. Desktop Esc provides access. Opening Pause releases held touch actions; closing it must not reassert a stale held finger. Left/Right/Jump art and target sizes are unchanged and are included only in integrated references.

## Credits

Sparse C2 chassis; no tableau, manufacturer mark, slogan or old red header bar.

| Element | Position / size | Type |
|---|---|---|
| Background | (0,0), 1152 × 648 | Same outer C2 chassis/interior/control-band geometry |
| CREDITS. canvas | (144,86), 864 × 112 | Visible top Y100; display ×9, 81px cap |
| Game block | (276,248), 600 × 72 | GAME / DESIGN small ×3; JOLTROME display ×4, name top Y279 |
| Music block | (276,349), 600 × 72 | ORIGINAL MUSIC small ×3; MIRAIE display ×4, name top Y380 |
| BACK body | (416,472), 320 × 70 | C2 primary; texture starts (404,460), 344 × 94 |
| BACK hit target | (416,463), 320 × 88 | Default keyboard focus |
| Music texture / hit | (808,557), 136 × 44 / (808,548), 136 × 88 | Byte-identical C2 ON/OFF state art |
| SFX texture / hit | (962,557), 122 × 44 / (962,548), 122 × 88 | Byte-identical C2 ON/OFF state art |

The supplied credit blocks render only the two legitimate credits authorized in the brief. Remove MADE FOR ONE MORE TRY. and the redundant old prose. Original Music → Miraie remains factual; the obsolete RC0 temporary-demo constraint is not current RC1 music status. Do not add invented contributors or placeholders.

Expansion rule: when real content reaches three or four blocks, use column centers **340 and 812**, role rows **Y248 and Y349**, name rows **Y279 and Y380**, maximum width **424px per block**. Role cap remains 21px; names normally 36px. Reduce a long name from display ×4 to ×3 only as needed to fit; do not overlap neighboring credits. If more than four real blocks are later approved, scroll only the content region (112,224,928,216), keeping headline, BACK and audio fixed. Do not implement empty scrolling or placeholder content now.

Keep Back/Escape return to Menu and existing session audio. Focus order: BACK → Music → SFX. Audio ON/OFF is one control per bus; changing its texture must retain focus and the existing session state.

## Pause

Dimmer RGBA **(13,20,36,140)**: 54.90% alpha, described as 55%. Do not apply that alpha again on top of the supplied PNG. Alternatively, draw the same solid color at that alpha. The world and HUD remain visible beneath it, frozen. Hide/release live touch controls before showing the overlay.

| Element | Texture position / size | Hit target |
|---|---|---|
| Dimmer | (0,0), 1152 × 648 | Full fitted game; blocks gameplay input |
| Pause bars | (552,112), 48 × 40 | None |
| PAUSED. canvas | (276,184), 600 × 72; display ×6 | None |
| RESUME body | (416,296), 320 × 70; texture (404,284), 344 × 94 | (416,287,320,88) |
| RETRY | (406,394), 160 × 88 | Same rectangle |
| MENU | (586,394), 160 × 88 | Same rectangle |
| Music ON/OFF | (682,510), 164 × 88 | Same rectangle |
| SFX ON/OFF | (862,510), 164 × 88 | Same rectangle |

RETRY/MENU use display ×3; audio uses the same small family at ×3 for readable floating text over the dim world. This is a size adjustment, not another font. Pause audio is lower-right to keep the central playfield/player position in the fixture clearer. All Pause controls meet a 44px target at 50% scale without making their normal state into cards.

Default focus is RESUME. Order: RESUME → RETRY → MENU → Music → SFX; reverse with Shift+Tab. Preserve deterministic directional neighbors and wrap. Idle uses idle art; keyboard focus or hover uses focus art; held press uses pressed art and takes precedence. Audio OFF variants share the ON variants' geometry. Keep one Button per action; do not replace an ON node with a new OFF node and lose focus. Decorative images ignore input; the background blocker prevents pointer fall-through.

RESUME/BACK use the locked C2 primary construction: 6px base, 4px press depression, unchanged stepped corners. Their texture extends 12px beyond the physical body. Do not alpha-trim or let the texture resize the Button. The invisible hit extension is nine pixels above/below the 70px body. For secondary controls, the 88px hit target is constant while focus decoration remains compact. No animation needs to delay the action.

### Required pause functionality — not implemented by Work

- Add a reversible PAUSED state and Esc pause/resume during active play. P can remain an optional unadvertised alias. Existing Escape meanings in Credits/Results remain unchanged.
- Freeze timer, physics, hazards, warning state and all gameplay animation phases; Resume restores the exact state. Keep the overlay and SessionAudio processing so Music/SFX remain adjustable and the accepted music loop continues.
- **Do not call the terminal death/completion stop path to pause.** `_stop_active_gameplay()` clears warnings/pattern state and stops actors; it is not a reversible pause operation. Verify actual rigid bodies as well as callbacks/timers are frozen.
- RETRY disposes the paused run and starts cleanly; MENU disposes it and returns safely. Resume releases UI focus before restoring gameplay input. No queued key/finger may trigger a jump or second action on return.
- Preserve first-death/completion priority. Pause requests during DEATH_BEAT or after a terminal outcome should not delay, replace or reset the committed result. Focus-loss auto-pause is reasonable only while actively running, if Codex implements it safely; it is not claimed present by this artwork.
- Move Music/SFX off live gameplay only when Pause access is integrated; retain Menu, Results and Credits audio access/state.

## Universal impact KO

Primary runtime asset: `death/technician-impact-ko.png`, **560 × 96 RGBA**, five horizontal **112 × 96** cells. `death/frames/` provides the individual cells; the editable `.aseprite` contains identical pixels and timings.

Anchor **(40,88)** in every cell corresponds to the existing technician visual bottom-center. The standing character remains the approved **50 × 60** size; the larger cell is transparent padding for the topple. Draw at scale 1, with texture top-left equal to captured visual anchor minus (40,88). In the reference, the anchor is (640,576), so the cell origin is (600,488). Do not scale the 112 × 96 canvas down to 50 × 60.

| Frame | Start | Hold | Treatment |
|---:|---:|---:|---|
| 0 | 0ms | 60ms | Impact brace: existing upper blocks sink two pixels while boots remain planted; no elastic scaling |
| 1 | 60ms | 70ms | 12° rigid recoil/topple; 3px center drift |
| 2 | 130ms | 80ms | 32° off-balance; 8px center drift |
| 3 | 210ms | 80ms | 62° fall; 16px center drift |
| 4 | 290ms | 130ms | 90° side-rest; 24px center drift; final hold pose |

All rotations are nearest-sampled rigid transforms of the approved S1 run cell 1. No new colors, eyes, face marks, cap, anatomy or smoothed interpretation is added. The small brace uses the same existing pixel blocks. This is deliberately a stiff toy-like topple; it should not become a floppy ragdoll or multiply-bouncing gag.

Frame 4 remains held until Results. Suggested complete impact sequence: **70ms captured live-pose hit-stop → 420ms KO → 260ms additional frame-4 hold = 750ms**. The 130ms inside the KO is already part of its 420ms; do not add it twice. The full reference GIF has a 1000ms context interval before that sequence and a 1000ms Results interval afterward; those intervals are preview-only.

Use for CANNED. and GRABBED. Both ordinary and D3 products share it. Mirror the entire presentation node around its anchor to fall left; if UV-flipping instead, compensate to mirrored canvas anchor **(72,88)**. Do not choose direction by changing the committed cause. Use a reliable impact-side/facing sign already available; otherwise keep one deterministic direction. No new collision query or contact result is needed for the art itself.

### Critical integration details

1. Capture the last live technician pose/transform **before the existing immediate collapsed-death selection**. The deferred session death callback can already be too late; cache the last live frame or capture at the accepted death latch. Otherwise the 70ms hit-stop will still show the old flattened sprite.
2. Preserve first-death-wins, cause, score and timer snapshots. Disable input/gameplay exactly as the existing terminal flow requires. Hide the old technician visual when the KO takes over to prevent a duplicate.
3. Run this presentation playback independently of the disabled game tree. Do not re-enable world simulation just to make the new animation move. Use the existing monotonic death deadline; no added 420ms after the existing 750ms.
4. Anchor at the actual captured visual bottom-center, converted through the existing camera/subviewport fit. Never spawn the KO at screen center or move the CharacterBody/collider. Baked pose drift is visual only.
5. For airborne impacts, keep the captured anchor and play the short topple there; do not invent floor collision, teleport downward or reposition onto a product. For edge impacts, allow natural clipping by the game viewport/occluder; do not recenter the actor to keep the whole sheet visible. These cases need in-engine subjective review.
6. Dispose the presentation sprite/timer on Results, Retry, Menu or stale run serial. Successful completion keeps its current direct CLOCKED OUT. transition. UNKNOWN should retain its honest fallback behavior; this impact artwork must not imply newly detected cause data.

No flash, shake, particles, explosion, hit text, gore, new sound or long cinematic is required. The later SFX pass has a clear impact moment at the death latch, and optional reaction onset at 70ms; this package supplies no audio.

## OUT / VENDED.

Source evidence: LEFT_OUT enters `_kill_player(LEFT_OUT)` and the same visual death handler; no dedicated clipping/disappearance path was found. The recording shows GRABBED. only. Do not claim OUT movement was playtested here.

Do not reuse the sideways impact topple as a new chute collision. No additional authored OUT pose is supplied or required. Optional minimal finishing transform: reuse the captured current pose, move its **visual only** downward 64 logical pixels linearly over **160ms**, and clip through the existing OUT opening. Native D3 aperture reference: **(108,446,48,116)**. The example anchor is (132,576); Codex must use the actual source/occluder coordinates under the existing scene transform. If the visual is already hidden, leave it hidden rather than respawning it for the effect.

This is one transform and existing occlusion, not another sprite animation system. Keep the current result deadline; add no new delay or physics movement. [The optional preview](../death/out-finish-reference.gif) contains the 160ms movement and the remainder of a 750ms deadline. First cause and VENDED. mapping remain unchanged.

## Readability, remaining consistency and QA boundary

100%: timer/score cap 27px, Credits role and Pause audio 21px, names 36px, main controls 27px, Credits audio 14px. All are readable against their intended backgrounds. 75%: these remain legible; fractional nearest scaling yields uneven pixel widths. 50%: timer/main controls 13–14px, roles/Pause audio 10–11px; the retained Credits audio is seven pixels high and remains small. Targets are at least 44 CSS px at that scale; mobile Pause is fixed 48 CSS px. Smaller fits than 50% are outside this delivered readability review and require device-specific integration judgment.

The HUD avoids active world routes. Pause necessarily overlays some frozen world content, but uses transparency rather than an opaque enclosing dashboard. Existing machine labels such as PRODUCT BAY, VEND ELEVATOR and OUT remain part of the frozen world art; this pass does not replace them. No additional VENTASTIC appears. Menu/results/controls legend remain exactly RC1, including Space/W/Up aliases.

The biggest remaining risk is the feel of the rigid KO on actual airborne/edge contacts. Aseprite import in the desktop editor, Godot playback, pause reversibility, actual phone touch and itch iframe rendering have not been run here. PNG/atlas reconstruction, frame timing, native Aseprite cell decoding, state dimensions/alpha, hit separation, source hashes, world-preservation bounds and repository/old-package hashes were checked in [qa-results.json](qa-results.json).

This is ready for Startup Lab asset review and Codex integration, not a claim of a tested VM-0.6.2 game build. No SFX work follows automatically.
