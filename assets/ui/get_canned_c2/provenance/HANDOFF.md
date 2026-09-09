# Codex integration handoff

## Authority and scope

The [production brief](production-brief.txt) freezes C2 Minimal and L1 Compact Stack. The copied [RC0 functional contract](RC0-functional-contract-reference.md) is the behavioral reference. Its original location is `/Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/docs/vm060-ui-functional-contract.md`.

This delivery adds visual assets only, outside the Git repository. It does not implement scenes, audio, score persistence, death attribution, gameplay or engine imports. Keep RC0 behavior and architecture. The selected C2 composition is unchanged apart from the approved CTA punctuation and the manufacturer readability adjustment documented below.

## Layout and texture rules

- Logical canvas: **1152 × 648**, 16:9, origin at top left. All coordinates below are logical pixels. Every asset uses a top-left anchor unless a text alignment is explicitly stated.
- Fit the entire canvas using `min(viewport width / 1152, viewport height / 648)` and center it with letterboxing. Do not stretch axes independently, crop the edges or rearrange the composition.
- PNG artwork uses nearest filtering, no mipmaps, no smoothing and no tint except the white glyph atlases. Source sprite cells are enlarged at the specified scale. Static supplied PNGs are already at their intended logical dimensions.
- Keep all layers on the same fitted canvas. Texture-only elements must ignore mouse input and cannot take focus. Use opaque white modulation for baked colored artwork.
- Full-frame transparent lettering textures deliberately preserve coordinates and simplify matching. Their transparent margins are not interactive hit areas. `chassis.png` is the only shared opaque full-frame background.
- Transparent logo and button margins are intentional. Do not trim, fit to visible alpha bounds or allow intrinsic texture size to resize its parent Button.
- No shaders, particles, lighting system, simulated physics, viewport captures or gameplay instances are required.

## Layer order

| Z | Content | Rule |
|---:|---|---|
| 0 | Shared chassis, interior, lower cream surface, OUT opening and conveyor seam | Opaque 1152 × 648 PNG |
| 10 | Static menu/result lettering and common OUT label | Full-canvas transparent layers |
| 20 | Conveyor tiles | Repeat and clip to the defined belt rectangle |
| 30 | Technician and settled red product | Source frame crops, exact specified scales |
| 35 | Refund Coin | Approved physical spin |
| 40 | Menu logo OR result headline, plus dynamic score numerals | Headline swaps in one fixed slot |
| 50 | Interactive controls and their focus/pressed state textures | Keep hit targets fixed |
| 60 | VENTASTIC | Main Menu only |

The JSON `layers` arrays list concrete file placements. The result headline and dynamic scores are specified separately in `headline_slot` and `score_slots`; add them at Z40. ON and OFF variants occupy the same control rectangle. Preview values 01/12 and 14/14 are examples, not defaults to hard-code.

## Exact coordinates

| Element | Top-left / geometry | Size / alignment |
|---|---|---|
| Chassis texture | (0, 0) | 1152 × 648 |
| Red chassis surface, baked | (20, 20) | 1112 × 608 |
| Interior, baked | (44, 54) | 1064 × 398 |
| Lower cream surface, baked | (44, 452) | 1064 × 152 |
| L1 logo | (300, 96) | 552 × 184; no scaling |
| Result headline canvas | (144, 112) | 864 × 112; all five files identical canvas |
| Headline visible text | Top Y126, centered X576 | Display grid ×9; 81px cap height |
| OUT opening, baked | (84, 352) | 52 × 60 |
| OUT lettering, baked | Center X110, top Y332 | Small grid ×2 |
| Conveyor seam, baked | (136, 407) | 912 × 5 |
| Conveyor clip | (136, 412) | 912 × 32; fifteen tiles, last clipped to 16px |
| Technician | (504, 352) | 50 × 60 final footprint |
| Settled red can | (582, 364) | 72 × 48 final footprint |
| Coin | (689, 376) | 32 × 32 final footprint |
| Menu Best Score label | Right X1048, top Y350 | Small grid ×2; baked |
| Menu Best Score value | Right X1048, top Y376 | Display grid ×3 normally; 176px slot |
| Result score labels | Centers X450 and X714, top Y267 | Small grid ×2; baked |
| Result values | Centers X450 and X714, top Y291 | Display grid ×5 normally; 232px each |
| MOVE / key hint | (76, 553) / (76, 577) | Small grid ×2; baked |
| JUMP / SPACE | (304, 553) / (304, 577) | Small grid ×2; baked |
| Result R / ESC hints | (76, 577) / (256, 577) | Small grid ×2; baked |
| VENTASTIC | (1006, 609) | 102 × 14, cream, menu only |

Score formatting: nonnegative integer, minimum two decimal digits, no abbreviation or truncation. Display numerals are tabular. For results, choose the largest common integer glyph scale in **5, 4, 3, 2, 1** that fits both 232px slots. Menu uses **3, 2, 1** within 176px. Width is the sum of glyph advances minus the final spacing, multiplied by scale. Align the visible glyph top at the specified Y; shrinking never moves captions. This handles the maximum signed 64-bit value, with a deliberately tiny exceptional display at ×1. The [stress reference](../reference/score-stress-int64.png) demonstrates the boundary; it is not expected gameplay volume. Preserve RC0 validation of stored values.

## Button construction and behavior

| Control | Hit rectangle X,Y,W,H | Texture position | PNG size |
|---|---|---|---|
| CLOCK IN | 416,472,320,70 | 404,460 | 344 × 94 |
| RETRY | 336,472,280,70 | 324,460 | 304 × 94 |
| MENU | 644,478,144,64 | 644,478 | 144 × 64 |
| Credits | 660,557,112,44 | 660,557 | 112 × 44 |
| Music ON/OFF | 808,557,136,44 | 808,557 | 136 × 44 |
| SFX ON/OFF | 962,557,122,44 | 962,557 | 122 × 44 |

Each state is a PNG in its named button folder. For CLOCK IN and RETRY, the control owns the visible body's hit rectangle and its texture child starts at **(-12,-12)**. Disable parent clipping so the focus cue can extend outside. Do not make the transparent padding clickable by accident. Secondary PNG origins equal their hit origins.

Use one focusable Button per action, with normal engine input, a transparent base style and no second visible text label. Map idle → idle, keyboard focus OR pointer hover → focus, button held down → pressed. Pressed wins while held; on release return to focus if still focused/hovered. Do not toggle on mouse-down or repeatedly activate on key repeat. Keep the hit rectangle and texture origin constant across state changes.

CLOCK IN and RETRY retain the study's stepped pixel body and six-pixel base depth, with four-pixel face/label depression. Secondary controls gain only a two-pixel focus outline and a two-pixel text depression plus underline on press. Their normal state remains unboxed. Focus does not animate or blink.

Music and SFX each remain **one control**, not separate ON/OFF buttons. Select the relevant label/state PNG from the same coordinates after reading the existing audio state. Preserve focus when the label changes. Expose the actual action/state to accessibility metadata if the current engine surface supports it; the baked lettering should not remove semantic button names.

Maintain RC0 mouse activation, Tab/Shift+Tab and standard UI focus navigation, Enter/Space activation, R retry routing and Escape return from Results/Credits. Default focus: CLOCK IN on Menu, RETRY on Results, BACK in existing Credits. Proposed traversal: CLOCK IN → Credits → Music → SFX; RETRY → MENU → Music → SFX. Keep a deterministic wrap and directional neighbors. Starting a run releases menu focus. Gameplay audio controls remain `FOCUS_NONE` under the contract; do not reuse menu keyboard-focus settings there.

## Approved sprite reuse and motion

| Object | Existing source filename | Cell / crop | Playback | Final footprint |
|---|---|---|---|---|
| Menu technician | `VM050_VIS04_S1_50x60_run_sheet.png` | 50 × 60 cells, horizontal | 0→1→2→3→4→5, 60ms each, repeat 360ms | 50 × 60, 1× |
| Result technician | `VM050_VIS03_technician_rigid_block_limbs_sheet.png` | Cell 0: (0,0,40,48) | Hold frame 0; approved existing idle, no invented death pose | 50 × 60, nearest 1.25× as existing S1 presentation |
| Refund Coin | `VM050_VIS04_C1_16x16_coin_sheet.png` | 16 × 16 cells, horizontal | 0→1→2→3→4→5, 90ms each, repeat 540ms | 32 × 32, 2× |
| Settled red product | `VM050_D3_VIS02_landed_red_soda_runtime_sheet.png` | Cell 2: (72,0,36,24) | Hold settled frame; no new collision semantics | 72 × 48, 2× |
| Conveyor | `VM050_D3_V2_conveyor_tile_sheet.png` | 32 × 16 cells, horizontal | **3→2→1→0**, 100ms each, repeat 400ms | 64 × 32 per tile, 2× |

The copied source sheets are byte-identical references, not replacement art. Prefer reusing the existing repository resources rather than importing duplicate textures. [Source provenance](source-provenance.json) supplies absolute source paths and hashes. The manifest's `frame_count` describes **frames used by this UI animation**; a source sheet can contain additional states not used here. The crop order determines which source cells are used. No rows below Y0 are used.

Conveyor tile origins are X136 + 64n for n=0…14, Y412. The last tile is clipped to the right edge X1048. Do not stretch it to fill the remainder. All belt tiles use the same animation phase. Static reference images use belt cell 3, menu technician cell 1, result idle cell 0 and coin cell 0; previews start menu technician at cell 0. This is a reference-pose difference, not a timing ambiguity.

Menu motion consists only of the three loops above. Results hold the technician still while the belt and coin continue. No headline delay, transition cinematic, result-specific character sprite, new particle system or audio synchronization is required. RETRY is immediately available. Decorative animation uses no gameplay physics or collision nodes.

The shared preview period is **10,800ms** (least common multiple of 360, 540 and 400). GIF frames occur at the union of source frame boundaries, preserving 60/90/100ms holds without rounding to a common FPS. The runtime should use source animation timings, not treat the GIF as a spritesheet. Pausing or hiding the menu/result should stop its presentation updates; retain one clean lifecycle owner and remove duplicate callbacks on transition.

The composer metadata supplied by Startup Lab is 104 BPM, C major / 8B. It is mood context only. No soundtrack file is included, processed or synchronized. Keep one existing SessionAudio outside the replaceable gameplay scene and preserve mute states and music continuity.

## Dynamic headline mapping

| Result source | Texture | Display text |
|---|---|---|
| Ordinary falling/moving product | `results/headlines/canned.png` | CANNED. |
| D3 background-sourced falling product | same texture | CANNED. |
| Retrieval carriage | `results/headlines/grabbed.png` | GRABBED. |
| Left OUT / death chute | `results/headlines/vended.png` | VENDED. |
| Death with unknown/unavailable cause | `results/headlines/game-over.png` | GAME OVER. |
| Standard completion | `results/headlines/clocked-out.png` | CLOCKED OUT. |

One layout serves all rows. No subtitle, cause-specific frame, alternative score position or additional result feature is introduced. Scores in success references are sample values only; the screen must continue to display real run/best values.

**Current RC0 has no cause field.** Integrate the generic fallback and completion first if plumbing is still absent. A later contained cause-data change can select the three supplied death textures. It must preserve UNKNOWN fallback and completion precedence, attribute D3 correctly, avoid making landed products a new lethal category, and keep existing score/retry lifecycle behavior. No such code or tests are part of this art delivery.

## Typography and credits boundary

Baked label/control/headline PNGs guarantee the selected glyph shape and placement. The two bitmap font atlases supply dynamic numerals and the actual uppercase UI coverage. [FONTS-AND-SOURCES.md](FONTS-AND-SOURCES.md) specifies metrics, provenance and importer limitations. Do not reconstruct the logo using a Label: its bespoke exclamation and spacing are locked in the supplied transparent image.

Keep the existing Credits screen, factual Miraie attribution, temporary-demo status and Back/Escape behavior. This brief does not authorize replacing the currently integrated audio asset or changing factual credit text to claim the WAV is already integrated. The uppercase-only production font must not silently replace the existing mixed-case Credits body font. No new credits composition is required.

## Changes from refinement and remaining checks

1. CLOCK IN loses its exclamation and is recentered within the unchanged primary body.
2. CLOCKED OUT. is the locked success headline; it uses the existing refinement treatment and slot.
3. VENTASTIC uses the same glyphs at 2× instead of 1×: 102 × 14 at (1006,609), replacing 51 × 7 at (1016,615). This solves an actual 50% scale problem while retaining one unboxed, static mark.
4. All previously unspecified secondary hover/focus/press and audio OFF states now have explicit restrained textures. Display colon/hyphen coverage, font descriptors, fixed hit targets and overflow rules are production details, not new concepts.

The biggest visual risk remains seven-pixel small labels at a 50% browser presentation. At 75%, nearest filtering preserves readability but yields uneven 1/2-pixel strokes. Prefer an 864 × 486 or larger embed; evaluate the actual browser/device-pixel ratio during integration. The approved result technician is an idle figure, not a new death pose. Accept that deliberately restrained reuse rather than introducing new character art in this pass.

Complexity is low to moderate: texture substitution, two font imports if used, fixed layout, existing input/audio binding, and a few presentation animations. There are no architecture-changing effects. Required engine checks after integration: import nearest/no mipmaps; verify alpha/pixel alignment; inspect actual BMFont sizing if used; mouse and keyboard focus/activation; audio ON/OFF focus retention; R/Escape behavior; score persistence; clean Retry/Menu lifecycle; one persistent music player; release/debug gating; browser scale readability. These are integration checks, not completed Godot tests.

Asset-side QA includes source hashes, native canvas sizes, fixed state geometry, font coverage/atlas metrics, reconstruction of six screens from the manifest, stable headline substitution, maximum int64 score fit, every decoded GIF frame against source composition, and repository before/after hashes. See [qa-results.json](qa-results.json). The local HTML index is a convenience viewer; its media were inspected directly and its links validated, but it was not browser-tested.

## Cost and stop rule

No paid APIs, asset stores, external fonts, SFX or separate services were used. Separately billed requests: **0**. Separately billed production-pass cost: **$0.00**. Input/cache/output billing units are not applicable. Subscription/session usage is outside this separate-service report; historical cumulative project cost is not established here.

All repository access was read-only. Do not interpret this package as an instruction to overwrite the repo from Work. Codex performs integration in a separate authorized step. Production art delivery stops here.
