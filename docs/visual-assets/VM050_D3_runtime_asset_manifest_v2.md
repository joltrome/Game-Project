# VM-0.5.0 D3 Runtime Animation Assets V2

Status: **art-only package awaiting Startup Lab approval**. Stop before Godot integration.

This revision adapts the approved B0.1/B0.2 identities to the frozen runtime collision envelopes. It does not overwrite the concept masters or the earlier corrected MOTION-02 art package. No collision, gameplay, cadence, scheduling, scoring, movement, carriage timing, coin-route, D2, Prototype-A, or Godot file was changed.

All runtime exports require nearest-neighbor rendering. Review-only magenta/cyan collision guides are hidden inside editable masters or isolated in review sheets; they are absent from runtime PNG sheets.

## Concept masters

| Classification | Source | Approved identity retained |
|---|---|---|
| CONCEPT MASTER | `../VM-0.5.0_mockup_B0.1_signature_assets.aseprite` | Technician, red soda, blue coffee, green sports drink, Refund Coin |
| CONCEPT MASTER | `../VM-0.5.0_mockup_B0.2_retrieval_carriage.aseprite` | Lethal retrieval carriage and separate safe-rail language |
| PRESERVED PRIOR PACKAGE | `../vm050_d3_runtime_assets/` | Corrected V1 concept-scale animation assets; not overwritten |

The V2 files below are **RUNTIME DERIVATIVES**, not replacements for the concept masters.

## Runtime derivatives

| Asset | Runtime master and sheet | Logical size | Rendered size / scale | Frozen collision | Representative visible alpha | Margins L/R/T/B | Anchor / origin | Animation | Lethality and expected mapping |
|---|---|---:|---:|---:|---:|---:|---|---|---|
| Technician | `VM050_D3_V2_technician_runtime.aseprite` / `_sheet.png` | 32×48 | 32×48 at 1× | 32×48 | 30×47 | 1/1/1/0 | bottom-center `(16,48)`; feet on bottom edge | `IDLE` 1–3 at 0.16s; `RUN` 4–9 at 0.08s; `JUMP` 10–11 at 0.12s; `FALL` 12–13 at 0.12s; `LAND` 14–16 at 0.07/0.07/0.12s; `DEATH` 17–19 at 0.14s | Player body. Keep collision unchanged; align visual bottom-center to existing collision bottom-center. |
| Falling red soda | `VM050_D3_V2_falling_red_soda_runtime.aseprite` / `_sheet.png` | 36×36 | 72×72 at exact 2× | 72×72 | 72×68 in every frame | 0/0/2/2 | center `(18,18)` logical | `FALL_TUMBLE` 1–4 at 0.085s | Lethal. Center rendered 72×72 art on existing 72×72 collision. |
| Falling blue coffee | `VM050_D3_V2_falling_blue_coffee_runtime.aseprite` / `_sheet.png` | 36×36 | 72×72 at exact 2× | 72×72 | 72×68 in every frame | 0/0/2/2 | center `(18,18)` logical | `FALL_TUMBLE` 1–4 at 0.085s | Lethal; same mapping as red soda. |
| Falling green sports drink | `VM050_D3_V2_falling_green_sports_runtime.aseprite` / `_sheet.png` | 36×36 | 72×72 at exact 2× | 72×72 | 72×68 in every frame | 0/0/2/2 | center `(18,18)` logical | `FALL_TUMBLE` 1–4 at 0.085s | Lethal; same mapping as red soda. |
| Landed red soda | `VM050_D3_V2_landed_red_soda_runtime.aseprite` / `_sheet.png` | 36×24 | 72×48 at exact 2× | 72×48 | 68×44 settled | 2/2/4/0 | center `(18,12)` logical; bottom is collision bottom | `IMPACT` 1–2 at 0.07/0.08s; `SETTLED` 3–4 at 0.16s | Lethal/solid according to existing implementation. Swap visual state only; do not change collision. |
| Landed blue coffee | `VM050_D3_V2_landed_blue_coffee_runtime.aseprite` / `_sheet.png` | 36×24 | 72×48 at exact 2× | 72×48 | 68×44 settled | 2/2/4/0 | center `(18,12)` logical | same as red | Lethal/solid; same mapping as red. |
| Landed green sports drink | `VM050_D3_V2_landed_green_sports_runtime.aseprite` / `_sheet.png` | 36×24 | 72×48 at exact 2× | 72×48 | 68×44 settled | 2/2/4/0 | center `(18,12)` logical | same as red | Lethal/solid; same mapping as red. |
| Retrieval carriage | `VM050_D3_V2_retrieval_carriage_runtime.aseprite` / `_sheet.png` | 48×14 | 96×28 at exact 2× | 96×28 | 96×28 | 0/0/0/0 | center `(24,7)` logical | `TELEGRAPH` 1–3 at 0.11s; `ACTIVE_SWEEP` 4–7 at 0.07s; `RETURN` 8–9 at 0.12s | Lethal moving carriage. Preserve separate muted fixed rail. Center on existing 96×28 collision. |
| Refund Coin | `VM050_D3_V2_refund_coin_runtime.aseprite` / `_sheet.png` | 12×12 | 24×24 at exact 2× | 24×24 | face frame 24×24; spin narrows as intended | pickup, not lethal | center `(6,6)` logical | `SPIN` 1–6 at 0.09s | Nonlethal pickup. Center on existing 24×24 pickup collision; do not change routes/value. |
| Conveyor tile | `VM050_D3_V2_conveyor_tile.aseprite` / `_sheet.png` | 32×16 | 64×32 at exact 2× | visual-only | n/a | n/a | top-left tile origin | `BELT_LOOP` 1–4 at 0.10s | Visual-only; tile horizontally. No conveyor behavior change. |
| Rack lifecycle | `VM050_D3_V2_rack_product_lifecycle.aseprite` / `_sheet.png` | 72×44 | background composition scale | non-colliding | n/a | n/a | background placement | `STORED` 1; `SELECTED` 2–4; `RELEASE` 5–6 | Smaller, muted background scenery. Map to existing state changes without changing director timing. |
| Warning column | `VM050_D3_V2_warning_column.aseprite` / `_sheet.png` | 24×96 | background composition scale | non-colliding | n/a | n/a | selected-lane center | `WARNING` 1–4; `RELEASE` 5–6, all 0.10s | Visual telegraph only. Loop across the existing generous warning duration. |

## Fairness result

The generated measurement source is `VM050_D3_V2_envelope_metrics.tsv`. It includes every live technician frame, all twelve falling-product danger frames, settled frames for all three product identities, and the active carriage.

- Technician live frames: 30×47 alpha in 32×48; 1/1/1/0 margins.
- Technician `DEATH` frames intentionally use a collapsed horizontal pose and therefore do not fill the live collision. They are terminal/noninteractive presentation frames, not a fairness reference. If the current game keeps player collision active during its death presentation, Startup Lab should reject that mapping or use a non-collapsed death frame; V2 does not authorize collision-logic changes.
- Falling products: 72×68 alpha in 72×72; 0/0/2/2 margins in every tumble frame.
- Landed products: 68×44 alpha in 72×48; 2/2/4/0 margins.
- Retrieval carriage: 96×28 alpha in 96×28; no invisible margin.
- No measured active-play lethal-direction margin exceeds the 4-runtime-pixel review threshold. The only larger margin is the explicitly noninteractive technician `DEATH` pose described above.

## Review and preview files

- `VM050_D3_V2_collision_overlay_study.aseprite` and `.png`: exact native collision rectangles plus enlarged nearest-neighbor review.
- `VM050_D3_V2_concept_runtime_comparison.aseprite` and `.png`: B0.1/B0.2 concept dimensions and V2 runtime derivatives shown inside equal frozen gameplay envelopes.
- `VM050_D3_V2_product_state_continuity.aseprite` and `.png`: `BACKGROUND → SELECTED → RELEASE → TUMBLE → IMPACT → LANDED` continuity.
- `VM050_D3_V2_source_to_threat_preview.aseprite`, `.gif`, and `_strip.png`: integrated product-bay flow at runtime-correct size relationships.
- `VM050_D3_V2_runtime_asset_overview.png`: compact review board.
- Each animated asset also includes an editable `.aseprite`, a horizontal runtime sheet, and a GIF preview.

## Identity and artistic compromise

The technician still uses the approved off-white/red service cap, pale two-eyed face and short red mouth, teal jumpsuit, blue lower-body shadow, red chest badge, separated teal legs, and navy outline/gloves/boots. No yellow/gold body color was introduced.

Drink identity remains red soda with a white slash, blue coffee with a gold circular mark, and green sports drink with a teal/gold label. The products change orientation and apparent foreground scale, not brand identity. The carriage retains its red appliance body, off-white inset, blue center panel, warning lamp, rollers, and coral/gold bumper; no telescoping arm was restored. The coin retains a navy rim, gold face, highlight, and simplified yen-like mark.

The deliberate compromise is stronger silhouette breadth: a released drink becomes a large diagonal tumbling can to occupy the square hazard envelope, then lands sideways to occupy the shorter solid envelope. This is the minimum art adaptation needed to make the frozen lethal regions visible and fair.
