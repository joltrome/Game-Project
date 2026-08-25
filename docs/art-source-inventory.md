# VM-0.5.0 Art Source Inventory and Compatibility Audit

Audit date: 2026-08-08

Gameplay baseline: VM-0.4.7

Audit scope: local inventory, license evidence, technical compatibility, palette directions, protagonist bases, and one target-screenshot plan. No gameplay or production-art integration is authorized by this document.

## Safety and workspace

- Raw third-party sources are copied only into `.local_art_sources/`, which is ignored by Git.
- `git check-ignore` resolves the workspace and sampled raw files to `.gitignore`.
- Original files in `/Users/jeromenicholaz/Downloads` remain untouched.
- The local research workspace is approximately 3.5 MB, so no large directory needed an external-path exception.
- Archives were retained under `.local_art_sources/_archives/`. The known Kowches ZIP was also unpacked locally because it contains PNG and Aseprite files and no executable.
- No raw third-party file is approved for the public repository merely because commercial use is permitted. Redistribution restrictions still matter.

Local workspace:

```text
.local_art_sources/
├── 00_inventory/
├── 01_oberzs_industrial/
├── 02_warehouse_factory/
├── 03_neon_platformer/
├── 04_factory_kmh/
├── 05_vending_machines/
├── 06_atomic_industrial/
├── 07_kowches_character/
├── _archives/
└── _unknown/
```

## Presence inventory

| Expected source | Classification | Exact original local path | Unpacked/archive state | Obvious duplicates and notes |
|---|---|---|---|---|
| Oberzs — Industrial Pack | **FOUND MULTIPLE COPIES · UNPACKED** | `/Users/jeromenicholaz/Downloads/Industrial pack/` and `/Users/jeromenicholaz/Downloads/Industrial pack.zip` | Folder plus 28 KB ZIP | Same pack in folder/archive form; 18 PNG files and no local license/readme. |
| ACTG — Warehouse / Factory | **FOUND · UNPACKED** | `/Users/jeromenicholaz/Downloads/WarehouseV2.png` and `/Users/jeromenicholaz/Downloads/warehouse.png` | Two loose PNG releases; no archive found | Official page lists these exact filenames. They are v2 and earlier sheets, not byte duplicates. |
| Vryell — Neon Platformer | **FOUND MULTIPLE COPIES · UNPACKED** | `/Users/jeromenicholaz/Downloads/Platformer/`, `/Users/jeromenicholaz/Downloads/Platformer 2/`, and `/Users/jeromenicholaz/Downloads/NeonPlatformer.zip` | Two unpacked folders plus 60 KB ZIP | `Platformer/` and `Platformer 2/` are byte-identical. Only one was copied into the research workspace. |
| Kevin's Mom's House — factory_ | **FOUND MULTIPLE COPIES · UNPACKED** | `/Users/jeromenicholaz/Downloads/factory_ [version 1.0]/` and `/Users/jeromenicholaz/Downloads/factory_ [version 1.0].zip` | Folder plus 3.7 KB ZIP | Same two-file pack in folder/archive form. |
| karsiori — Pixel Art Vending Machines | **FOUND MULTIPLE COPIES · UNPACKED** | `/Users/jeromenicholaz/Downloads/Pixel Art Vending Machines Pack/` and `/Users/jeromenicholaz/Downloads/Pixel Art Vending Machines Pack.zip` | Folder plus 130 KB ZIP | 44 PNG variations plus one informational TXT. The local TXT says 45 variations while the current page and actual PNG count say 44. |
| Atomic Realm — Industrial Tileset | **FOUND MULTIPLE COPIES · UNPACKED** | `/Users/jeromenicholaz/Downloads/[FREE] Industrial Tileset/` and `/Users/jeromenicholaz/Downloads/[FREE] Industrial Tileset.zip` | Folder plus 1.2 MB ZIP | The downloaded material is the **FREE** tier: PNG/GIF assets only. The paid SOURCE-tier PSD files are not present. |
| Kowches — Free Basic Platformer Character | **ARCHIVE ONLY** in Downloads; unpacked in ignored workspace | `/Users/jeromenicholaz/Downloads/BasicPlatformerCharacter.zip` | 20 KB ZIP containing PNGs and one `.aseprite` file | No duplicate original was found. |
| NES Industrial Tileset | **NOT FOUND** | — | Intentionally not downloaded | Not recommended as the primary direction. |
| Goblinspire — Factory Assembly Line | **NOT FOUND** | — | No matching archive/folder found | Do not purchase or download automatically. |
| Muffinespixels Factory Platformer | **NOT FOUND** | — | No matching archive/folder found | Reference only; do not purchase or download automatically. |

## Source-format inventory

| Pack | PNG | GIF | Aseprite | PSD | JSON/tilemap metadata | Palette/source project |
|---|---:|---:|---:|---:|---:|---|
| Oberzs | 18 | 0 | 0 | 0 | 0 | Flattened PNG only |
| ACTG | 2 | 0 | 0 | 0 | 0 | Flattened PNG only |
| Neon Platformer | 39 | 0 | 0 | 0 | 0 | One 16×2 PNG palette with 21 visible colors |
| factory_ | 1 | 0 | 0 | 0 | 0 | Flattened PNG only |
| Vending Machines | 44 | 0 | 0 | 0 | 0 | Individual flattened machine PNGs |
| Atomic FREE | 27 | 2 | 0 | 0 | 0 | Individual character frames and sheets; no paid SOURCE-tier PSD |
| Kowches | 20 | 0 | 1 | 0 | 0 | Editable 19-frame Aseprite project plus sheet and individual frames |

No found pack includes a Godot TileSet resource, JSON atlas metadata, or a native tilemap. Import setup must be authored in Godot.

## License evidence

“Local license” means a license/readme was actually present in the downloaded material. Web-page evidence is recorded separately and should be saved with production records before a source becomes critical.

| Pack | Local license found | Commercial use | Modification | Redistribution | Attribution | Current decision |
|---|---|---|---|---|---|---|
| Oberzs | **No** | Official page explicitly permits personal and commercial projects | Not explicit on the retrieved page | Official page forbids redistribution | Not stated | **LICENSE NEEDS VERIFICATION for modification.** Use as rendering/animation reference until clarified. |
| ACTG | **No** | Official page marks the pack CC0 | CC0 page status | CC0 page status | Not required by CC0 | Safe reference and potential commodity source, but archive the page/license evidence before production use. |
| Neon Platformer | **No**; local TXT files are thanks/patrons/fog notes | Official page permits personal and commercial use | Not explicit on the base-pack page | Official page forbids reselling/redistributing | Not necessary; appreciated | **LICENSE NEEDS VERIFICATION for modification.** Mechanical/animation reference only for now. |
| factory_ | Local readme contains technical notes, not the license | Official page marks the pack CC0 | CC0 page status | CC0 page status | Credit appreciated, not necessary | Suitable CC0 secondary shape reference. |
| Vending Machines | Local TXT contains dimensions, not the license | Official page states CC0 for commercial/non-commercial work | Official page says the pack may be used however desired | CC0 page status | Optional/appreciated | Strongest direct-use legal candidate, but signature pieces should still be redrawn for identity. |
| Atomic FREE | **Yes:** `4. License.png` | Local license permits commercial/non-commercial use | Local license permits editing | Local license forbids repackaging, resale, or redistribution regardless of modification | Official page requires credit linking to `https://atomicrealm.itch.io/`; local image does not mention it | Legally usable in a game with attribution, but raw files must remain private. Prefer reference/recolor rather than direct style leadership. |
| Kowches | **No** | Official page permits personal and commercial projects | Official page permits editing | Official page forbids reselling/redistributing the assets as-is | Appreciated, not required | Best editable animation-base candidate; save the page terms before production use and do not ship it unchanged. |

Source pages:

- Oberzs: <https://oberzs.itch.io/industrial-pack>
- ACTG: <https://actg.itch.io/warehouse-factory>
- Vryell: <https://vryell.itch.io/neon-platformer>
- Kevin's Mom's House: <https://kevins-moms-house.itch.io/factory>
- karsiori: <https://karsiori.itch.io/pixel-art-vending-machines>
- Atomic Realm: <https://atomicrealm.itch.io/industrial-tileset>
- Kowches: <https://kowches.itch.io/free-basic-platformer-character>

## Technical compatibility matrix

| Pack | Pixel grid / native size | Outline and shading | Colorfulness / detail | Animation quality | Environment usefulness | Character usefulness | Vending usefulness | Editability | Target compatibility | Main risk |
|---|---|---|---|---|---|---|---|---|---|---|
| Oberzs | 16 px tiles; engineer frames 16×28 | Thin dark outline, compact clusters, cool midtone shading | Medium saturation; detail fits small gameplay sprites | Idle 9, run 8, jump 2 | High for panels, pipes, vent, console, background | High proportion reference | Medium mechanical vocabulary | PNG only; recolor practical, structural edits slower | **High after recolor** | Gray/cool industrial language could dominate; stock engineer is recognizable. |
| ACTG | Large side-view sheet, 704×128 v2 plus 415×129 earlier sheet; no declared uniform grid | Thin-to-medium outlines, flat/midtone shading | Muted brown, tan, red; medium detail | None | Medium for crates, scaffold, forklift, barrels | None | Low | Flat PNG; objects can be isolated manually | **Medium as shape reference** | Brown warehouse palette conflicts with colorful vending direction; scale varies. |
| Neon Platformer | 8/16 px tiles; main character sheet uses seven 32×48 cells | Crisp one-pixel outlines and high-contrast highlights | Very saturated, cyber-neon, medium detail | Main sheet labels idle/walk/jump/crouch/hit/death; additional gun sheet | Medium for mechanical shapes | Medium animation reference | Medium: small machines, conveyor, coins, pipe | PNG only; supplied palette helps recolor | **Low for direct mixing; medium as reference** | Cyberpunk palette and 32×48 proportions could define the game incorrectly. |
| factory_ | 16×16 tiles in a 192×144 sheet | Thin dark outline, highly simplified flat shading | Exactly 4 visible colors; warm cream/coral/dark | Spring 6 frames and belt 4 frames, per readme | Medium for simple conveyor/panel shapes | None | Low/medium shape reference | Flat PNG but only four colors, so recolor is easy | **Medium as secondary reference** | Much simpler than vending/Atomic art; direct mixture would look under-detailed. |
| Vending Machines | Six frontal machines, roughly 45–50×84–94 | Mostly thin outlines with more internal texture and occasional soft glass/transparency | Colorful but inconsistent complexity: 15–203 visible colors per image | None | Low as a side-view tileset | None | **Very high** for UI, products, coin mechanisms, framing, labels | Individual PNGs; recolor easy, structural animation absent | **Very high as primary vending reference** | Direct full-machine use does not describe an interior and may look like a stock pack. |
| Atomic FREE | 32×32 grid; tilesheets 96×96 or 192×128 | Thick black outlines, strong specular highlights, dense mechanical detail | High saturation and high contrast | Walk 6 individual frames; jump 8 individual frames; sheets/GIFs included | High mechanical vocabulary and subdued background variants | Medium robot motion reference | Medium for pipes, actuators, braces | PNG/GIF only in local tier; paid PSD absent | **Medium after redraw/recolor** | Pixel scale, outline weight, and density overpower Oberzs/Karsiori; attribution and no-redistribution requirements. |
| Kowches | 64×64 canvases with visible figure about 14–21×29–31; source header has 19 frames | One-pixel dark outline, minimal flat three-color design | Very low detail and neutral palette | Idle 3, run 8, jump 3, fall 2, land 3; Aseprite source | None | **High as animation/anchor base** | None | Best editability: `.aseprite`, sheet, individual PNGs | **High as a custom-animation base, low unchanged** | Stock blank-base appearance; current collision is 32×48, so silhouette/scale must be redesigned rather than dropped in. |

All packs are broadly side-view compatible except the frontal vending machines, which are valuable for object construction and color language rather than direct environment layout. Current Godot gameplay uses a 32×48 player collision box and a 1152×648 viewport. Pixel-art imports should use nearest-neighbor filtering and integer display scales; no project-wide pixel filtering decision has yet been committed.

## Visual cohesion recommendation

### A. Primary style references

1. **karsiori Vending Machines** — define vending-machine color language, buttons, windows, product rows, coin hardware, labels, cream/teal/red relationships, and friendly appliance identity.
2. **Oberzs Industrial Pack** — define the compact side-view pixel scale, thin-outline language, mechanical sprite proportions, and how much detail fits around a 16×28 character.

Use neither palette unchanged. The combination works only if Oberzs machinery is pushed away from gray/navy dominance and karsiori detail is reduced into a consistent limited palette.

### B. Secondary references

- **factory_:** use its simple 16 px conveyor, panel, and scaffold shapes; redraw/recolor rather than mixing the four-color sheet wholesale.
- **ACTG Warehouse:** borrow silhouettes for crates, barrels, scaffold, pallet hardware, and maintenance clutter; avoid its brown-dominant palette.
- **Kowches:** use animation timing and stable anchors for the custom protagonist.

### C. Mechanical reference only

- **Atomic FREE:** study pipes, pistons, support columns, specular-metal grouping, and background/foreground separation. Redraw into the thinner primary outline and smaller grid.
- **Neon Platformer:** study conveyor tiling, readable mechanical motion, coin-frame shapes, and state coverage. Do not inherit its purple/navy neon identity.

### D. Do not mix directly

- Atomic foreground tiles beside factory_ tiles: 32 px heavy-outline density versus 16 px four-color minimalism.
- Neon character beside the Oberzs engineer: 32×48 labeled-sheet/cyberpunk proportions versus 16×28 compact worker proportions.
- Unedited ACTG warehouse props as dominant scenery: muted brown/tan language conflicts with colorful appliance interiors.
- An unchanged Kowches base or Oberzs engineer as the final protagonist: either would make the character visibly stock.
- Whole frontal karsiori vending machines pasted behind the player: they describe an exterior object, not the interior space, and would read as an asset collage.

## Proposed palette directions

These colors are sampled from the found packs, then grouped for the target direction. They are proposals, not a final palette decision.

### Option A — Colorful Classic Vending

| Role | Hex | Sample source |
|---|---|---|
| Machine panel | `#FFF4E0` | karsiori |
| Teal structure | `#40796E` | karsiori |
| Vending red | `#BE5340` | karsiori |
| Refund gold | `#FFD55E` | Neon palette |
| Medium blue | `#2584B8` | Oberzs |
| Product green | `#417656` | karsiori |
| Selective dark | `#06101C` | karsiori |

Best fit for the brief. Risk: karsiori images contain many more shades than this seven-color backbone, so direct pieces need deliberate reduction.

### Option B — 90s Arcade Machine

| Role | Hex | Sample source |
|---|---|---|
| Navy frame | `#0C1238` | Neon palette |
| Cyan signal | `#34FFF2` | Neon palette |
| Coral/red | `#FF6892` | Neon palette |
| Warm yellow | `#FFD55E` | Neon palette |
| Violet accent | `#611E78` | Neon palette |
| Off-white | `#FFF1E8` | Neon palette |
| Secondary blue | `#298FC3` | Neon palette |

Strong arcade identity, but highest cyberpunk risk. Navy and violet must remain framing/accent colors, not the entire playfield.

### Option C — Japanese Retro Appliance

| Role | Hex | Sample source |
|---|---|---|
| Warm ivory | `#FFECD6` | factory_ |
| Turquoise | `#33B3D6` | Oberzs |
| Tomato red | `#BE5340` | karsiori |
| Mustard/gold | `#9D7D4A` | ACTG |
| Leaf green | `#417656` | karsiori |
| Dark blue-violet | `#29273B` | Oberzs |
| Pale cyan highlight | `#97E8F0` | Oberzs |

Warmest and most appliance-like option. Risk: mustard and ivory can drift toward a faded/brown industrial screen unless cyan, red, and green remain prominent.

## Protagonist-base comparison

### Oberzs engineer

- Native frame canvas: 16×28.
- Visible silhouette: approximately 12–13×22–24.
- Frames: idle 9, run 8, jump 2.
- Palette: 16 visible colors in the character sheets.
- Strengths: strong worker identity, hard-hat silhouette, compact proportions, readable orange/yellow against cool machinery. At 2×, the visible figure is roughly 24–26×44–48 and aligns closely with the current 32×48 collision height.
- Gaps: no dedicated fall or land sheet; very little facial/expression room; PNG only; stock appearance; modification permission is not explicit in the retrieved license text.
- Estimated custom work: medium to high. Retain proportion and motion study, redraw helmet/head, torso, jumpsuit, hands, and palette; create fall/land frames and verify anchors.

### Kowches base

- Source: one 64×64, 19-frame, 32-bit Aseprite project plus individual PNGs and a 256×320 sheet.
- Visible silhouette: about 14–21×29–31 inside the padded 64×64 canvas.
- Frames: idle 3, run 8, jump 3, fall 2, land 3.
- Palette: 3 visible colors.
- Strengths: complete relevant state coverage, stable padded canvases, editable Aseprite source, neutral silhouette intended for customization, commercial editing explicitly allowed.
- Gaps: the unchanged figure is generic and visually narrow relative to the current 32×48 collision; a 2× scale would be too tall, while a non-integer scale would blur pixel structure.
- Estimated custom work: medium. Preserve timing/foot anchors, redraw a roughly 16×24 or 16×28 technician silhouette intended for a clean 2× game display, then re-export on consistent canvases.

### Recommendation

Use **Kowches as the animation timeline and anchor base**, **Oberzs as the proportion/maintenance-worker reference**, and create an original technician/mascot over them. Target an oversized helmet/cap, compact body, saturated jumpsuit, and a silhouette designed for integer scaling against the existing 32×48 collision. Do not replace the player with either stock sprite unchanged. If the custom pass cannot produce a consistent run/jump/fall/land set, commission the protagonist before commissioning commodity background props.

## Asset-by-asset production strategy

| Current game element | Recommended strategy | Source contribution | Why |
|---|---|---|---|
| Protagonist | **Custom redraw over animation base; commission if needed** | Kowches timing/anchors + Oberzs proportions | Signature asset; must be original and collision-readable. |
| Countdown and coin HUD | **Custom** | karsiori displays, buttons, price/coin panels | Signature UI; preserve the validated hierarchy rather than fitting stock art around it. |
| Right product elevator/internal housing | **Custom or heavily kitbashed/redrawn** | karsiori housing/controls + Oberzs/Atomic actuator construction | Must explain the exact invisible boundary and dominate the right-side silhouette coherently. |
| Left retrieval/drop area | **Custom** | karsiori retrieval openings + factory_ conveyor language | Signature danger source and vending identity. |
| Sweeper/service mechanism | **Custom animation** | Oberzs console/laser motion and Atomic piston construction as reference | Hazard readability requires a bespoke source, clear arm silhouette, and exact hitbox alignment. |
| Refund Coin | **Custom/cleaned existing visual** | karsiori coin mechanisms + Neon coin contrast reference | Signature score object; the Neon sheet reads more like gems than refund coins. |
| Product obstacles | **Custom family sharing one collision silhouette** | karsiori product-window contents as reference | Can vary soda/coffee/water/carton appearance later without changing behavior; first slice needs one clear product. |
| Conveyor | **Custom/recolor/kitbash** | factory_ belt shape + Oberzs/Atomic mechanical construction | Large persistent foreground object; direct Neon purple belt would overdefine the palette. |
| Background pipes, bolts, vents, wiring | **Use/recolor/modify commodity sources** | Oberzs first; Atomic only after outline reduction and attribution plan | Low-signature elements can save time if kept low contrast. |
| Background braces, crates, motors, panels | **Recolor/kitbash** | ACTG/factory_/Oberzs | Useful silhouettes, but ACTG brown and mixed scale must be normalized. |
| Machine signage/brand identity | **Custom** | karsiori labels and appliance proportions | Signature recognition and cohesion asset. |
| Warning lanes/chutes | **Custom skin over frozen geometry** | karsiori product rows + Oberzs rails | Must preserve one-to-one warning correspondence and current collision/timing. |

## One VM-0.5.0 target screenshot

Use the current 1152×648 gameplay proportions and depict one live, readable decision—not a decorative concept screen.

1. **Top 0–150 px: machine electronics/HUD.** Place the unchanged central countdown and secondary coin score inside a cream-and-teal vending display with a red status strip and gold coin icon. Keep the timer larger than every other label.
2. **Upper playfield 150–430 px: low-contrast interior context.** Add product racks, coil silhouettes, rails, wiring, motors, vents, and panel seams using reduced-saturation Oberzs shapes and simplified Atomic mechanical ideas. Keep values close enough that none resemble active hazards.
3. **Right side around the existing x=760 control boundary:** show a large physical product elevator/carriage or internal housing continuing to the screen edge. Align its solid face exactly with the frozen wall. Include karsiori-inspired product windows, buttons, and service panels.
4. **Left side x=96–160:** show a recessed retrieval/drop chute with a dark opening, bright safety lip, and belt termination. It should visually explain the existing left failure area without moving it.
5. **Foreground at y≈584:** render the conveyor with strong horizontal direction cues and readable top surface, but keep its patterns below hazard/coin contrast.
6. **Tiny protagonist:** show the custom maintenance worker near the middle-right of the valid control band, at the existing gameplay scale, with a clear two- or three-color silhouette plus one bright suit accent.
7. **Active product obstacle:** show one clearly solid product can on the belt and one aligned chute/warning state above it; use the same gameplay footprint as VM-0.4.7.
8. **Sweeper/service arm:** show the existing arm as a bright, readable vending actuator entering from its real source and altitude.
9. **Refund Coin route:** show one conservative forward coin and a visibly more committed rearward extension using the existing offer system; do not alter placement for the mockup.
10. **Hierarchy check:** protagonist, lethal Sweeper/falling product, warnings, Refund Coins, and timer must read first; landed product and belt second; decorative machinery last.

Pack contributions for the mockup:

- karsiori: vending display, product window, coin slot/button, right-housing color language.
- Oberzs: scale, technician proportions, pipe/console/vent silhouettes, background panel density.
- factory_: conveyor and simple brace shapes.
- ACTG: low-contrast maintenance/storage silhouettes only.
- Atomic: piston/actuator construction reference, redrawn with thinner outlines.
- Kowches: protagonist animation anchor/base.
- Neon: mechanical-motion and high-contrast collectible reference only; no direct palette leadership.

## Known gameplay QA carried into art production

Some multi-coin offers can still feel locally clustered. The pending hypothesis is that routes with three or more coins may need a total footprint around 35–60 percent of the usable horizontal playfield or clearer vertical branching. **Do not modify the director during the art audit or visual slice unless visual integration reveals a reproducible geometry/readability bug.** Test the existing routes against new art first; decoration must not make current separation harder to perceive.

## What Codex can safely implement after visual approval

- A separate target-screenshot/mockup scene or non-gameplay visual overlay that does not change collision or scheduling.
- Godot import defaults and per-texture nearest-neighbor settings for approved, repository-safe derived assets.
- A custom visual shell for the existing HUD nodes without moving or reprioritizing validated information.
- Decorative background layers with no collision and explicit low-contrast limits.
- Visual-only skins for the fixed conveyor, right boundary, left retrieval area, Sweeper, product, warning, and coin nodes.
- AnimationPlayer/Sprite2D integration that preserves the current collision shapes, positions, timings, and state transitions.
- Screenshot regression checks and side-by-side gray-box/vertical-slice readability validation.

## Blockers before production integration

1. Startup Lab must choose a palette direction and approve the target screenshot composition.
2. Oberzs and base Neon modification permission should be clarified or those sources must remain reference-only.
3. Save durable copies of official license terms for any selected production source.
4. Decide whether Aseprite will be purchased/installed, Pixelorama will be used, or a pixel artist will receive the working files. Neither Aseprite nor Pixelorama was found installed during this audit.
5. Approve the custom protagonist method and target logical sprite size before redrawing frames.
6. Decide whether Atomic attribution/no-redistribution handling is worth the style-normalization cost; the local FREE tier has no PSD sources.
7. Do not start full VM-0.5.0 integration until Startup Lab reviews this audit.

## VM-0.5.0-MOTION-01 provenance follow-up

On 2026-08-26, the D2/D3 structural motion study implemented the approved visual direction using only project-owned Godot geometry and default-font text. No raw pack file, Work mockup, Aseprite source, flattened reference image, or custom font was moved into `assets/` or committed.

The inspected Work Aseprite mockup includes a hidden `SOURCE Sports Drink` layer whose third-party provenance is not sufficiently clear for redistribution. It remains reference-only in the ignored/local working material. The playable study therefore recreates the relevant vending-machine framing, product bays, retrieval opening, rail, product, and carriage as original code-native shapes. This is a deliberate production-safety decision, not a finding that the reference source is unusable under every possible license review.
