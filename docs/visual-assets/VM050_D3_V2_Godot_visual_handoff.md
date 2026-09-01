# VM-0.5.0 D3 V2 — Exact Godot Visual Handoff

Status: instructions only. **Do not integrate until Startup Lab approves V2.**

## Global import rule

- Use nearest-neighbor texture filtering.
- Disable mipmaps and smoothing for these pixel sheets.
- Use only the integer scales stated below.
- Do not non-uniformly stretch any sprite.
- Do not edit or replace any existing `CollisionShape2D`.
- Animation preview timings are visual starting points only. Keep the frozen D3 event cadence, warning duration, product scheduling, landing logic, movement, scoring, carriage timing, and coin routes unchanged.

## Exact mappings

### Technician

- Source sheet: `VM050_D3_V2_technician_runtime_sheet.png`.
- Sheet dimensions: 608×48; 19 horizontal frames of 32×48.
- Runtime scale: `(1,1)`; rendered frame 32×48.
- Pivot: logical bottom-center `(16,48)`.
- Place that pivot on the existing player collision's bottom-center. Do not center the sprite vertically and do not add compensating transparent padding.
- Tags/ranges: `IDLE` 1–3, `RUN` 4–9, `JUMP` 10–11, `FALL` 12–13, `LAND` 14–16, `DEATH` 17–19.
- `DEATH` is a collapsed terminal pose and is not a visual representation of an active 32×48 body. Confirm the existing death flow is already noninteractive before using it. Do not change collision logic under this art-only handoff; if that condition is not already true, stop and return the mismatch to Startup Lab.

### Falling products

- Sheets: `VM050_D3_V2_falling_red_soda_runtime_sheet.png`, `...blue_coffee...`, `...green_sports...`.
- Each sheet: 144×36; 4 horizontal frames of 36×36.
- Runtime scale: exact `(2,2)`; rendered frame 72×72.
- Pivot: logical center `(18,18)`, rendered center `(36,36)`.
- Align the rendered center with the existing 72×72 falling-product collision center.
- Loop `FALL_TUMBLE` while the existing foreground falling state is active. Do not rotate or scale again in Godot.

### Landed products

- Sheets: `VM050_D3_V2_landed_red_soda_runtime_sheet.png`, `...blue_coffee...`, `...green_sports...`.
- Each sheet: 144×24; 4 horizontal frames of 36×24.
- Runtime scale: exact `(2,2)`; rendered frame 72×48.
- Pivot: logical center `(18,12)`, rendered center `(36,24)`.
- Align with the existing 72×48 landed collision. The art's lower edge already aligns with the collision bottom.
- Play `IMPACT` frames 1–2 once, then use/loop `SETTLED` frames 3–4 only as the current implementation permits. This is a visual state swap, not a new landing state.

### Retrieval carriage

- Source sheet: `VM050_D3_V2_retrieval_carriage_runtime_sheet.png`.
- Sheet dimensions: 432×14; 9 horizontal frames of 48×14.
- Runtime scale: exact `(2,2)`; rendered frame 96×28.
- Pivot: logical center `(24,7)`, rendered center `(48,14)`.
- Align with the existing 96×28 moving-carriage collision center.
- Tags/ranges: `TELEGRAPH` 1–3, `ACTIVE_SWEEP` 4–7, `RETURN` 8–9.
- Keep the safe fixed rail separate, muted, stationary, and nonlethal. Do not restore the telescoping arm.

### Refund Coin

- Source sheet: `VM050_D3_V2_refund_coin_runtime_sheet.png`.
- Sheet dimensions: 72×12; 6 horizontal frames of 12×12.
- Runtime scale: exact `(2,2)`; rendered frame 24×24.
- Pivot: logical center `(6,6)`, rendered center `(12,12)`.
- Center on the existing 24×24 pickup collision. Loop `SPIN` 1–6.
- Do not change spawn frequency, paths, clustering behavior, score value, or collection rules.

### Conveyor

- Source sheet: `VM050_D3_V2_conveyor_tile_sheet.png`.
- Sheet dimensions: 128×16; 4 horizontal frames of 32×16.
- Runtime scale: exact `(2,2)`; each rendered tile is 64×32.
- Tile from a consistent top-left origin. Loop `BELT_LOOP` 1–4.
- This is visual-only. Do not change conveyor velocity, physics, collision, or timing.

### Rack and warning

- Sources: `VM050_D3_V2_rack_product_lifecycle_sheet.png` and `VM050_D3_V2_warning_column_sheet.png`.
- Both are non-colliding background visuals.
- Map the rack to the existing stored, selected, released/empty, and reset events. Map the warning loop across the existing warning window.
- Stored products remain smaller and muted. The 2× foreground tumble communicates depth-plane transition.
- Do not derive gameplay timing from the editorial GIFs.

## Required pre-merge visual checks

1. Overlay the existing collision debug shapes and compare them to `VM050_D3_V2_collision_overlay_study.png`.
2. Confirm the technician's feet stay fixed to the same bottom-center point through all non-death tags.
3. Confirm every falling frame renders at exactly 72×72 and every landed frame at exactly 72×48.
4. Confirm the safe rail never inherits the carriage's vivid/lit treatment.
5. Confirm the rack product is visibly the same red/blue/green identity that emerges into the foreground.
6. Verify nearest-neighbor output at the tested gameplay window size.
7. Run existing D3 gameplay and cadence tests without updating expected mechanics.

## Integration boundary

This package authorizes asset substitution and animation playback only after approval. It does not authorize edits to collision sizes, cadence/frequency, scheduling, suppression/replacement logic, player movement, scoring, carriage timing, coin routes, D2, or Prototype A.
