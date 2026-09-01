# VM-0.5.0-VIS-02 — Changed-Asset Godot Handoff

Status: **instructions only; wait for Startup Lab approval**.

Do not change CollisionShape2D dimensions, pivots, gameplay values, D3 cadence, warning duration, product trajectory/physics, landing Y, carriage timing, coin routes, scoring, D2, or Prototype A.

## Technician swap

- Replace V2 technician art with `VM050_D3_VIS02_technician_chunky_runtime_sheet.png`.
- Sheet: 608×48; 19 horizontal 32×48 frames.
- Runtime scale: `(1,1)`.
- Pivot: bottom-center `(16,48)`.
- Align to the existing player collision bottom-center exactly as V2.
- Animation ranges and timing are unchanged from V2.
- The collapsed `DEATH` pose is terminal presentation art and should only be used if the existing death flow is already noninteractive. This handoff does not authorize collision-logic changes.

## Falling-product candidate

- Sheets:
  - `VM050_D3_VIS02_falling_red_soda_runtime_sheet.png`
  - `VM050_D3_VIS02_falling_blue_coffee_runtime_sheet.png`
  - `VM050_D3_VIS02_falling_green_sports_runtime_sheet.png`
- Each sheet: 288×36; eight horizontal 36×36 frames.
- Exact scale: `(2,2)`; frame canvas remains 72×72.
- Pivot: logical center `(18,18)`, rendered center `(36,36)`.
- Tag: `ROTATIONAL_TUMBLE` frames 1–8 at 0.075s.
- Do not apply additional Godot rotation, mirroring, or scaling.

Important: vertical/horizontal frames leave 10px of invisible frozen collision on the short axis. This exceeds the agreed art-review threshold. Startup Lab approval is required before substituting these sheets.

## Landed products

- Sheets: `VM050_D3_VIS02_landed_red/blue/green_*_runtime_sheet.png`.
- Each sheet: 144×24; four horizontal 36×24 frames.
- Exact scale: `(2,2)`; rendered frame 72×48.
- Pivot: logical center `(18,12)`.
- Align all source paths to the same existing conveyor landing Y. Do not compensate for the known landed-height integration bug in the art.
- Play `IMPACT` 1–2, then `SETTLED` 3–4 according to the existing state flow.

## Rack system

- Sheets: `VM050_D3_VIS02_rack_slot_red_sheet.png`, `...blue...`, `...green...`.
- Each sheet: 224×38; eight horizontal 28×38 frames.
- Use frame 1 as the visual baseline for both decorative slots and mechanically active lanes.
- Active lanes alone may advance through `SELECTED` 2–5 and `RELEASE` 6–7, then return to baseline through `RESET` 8.
- Decorative lanes may remain on frame 1 permanently; they do not require new gameplay nodes.
- Do not reveal active lane indices or special frames at rest.

## Drop warning

- Sheet: `VM050_D3_VIS02_drop_warning_runtime_sheet.png`.
- Sheet dimensions: 192×96; eight horizontal 24×96 frames.
- Tag: `MACHINE_WARNING` 1–8 at 0.10s.
- Place the twin guide rails on the current drop centerline beneath the selected slot.
- Loop/retime these visual frames across the existing warning duration. Do not change the duration itself.
- The rack slot's local lamp and shake should begin before or with the guide lights so attention flows rack → path → player area.

## Explicitly unchanged

- Continue using the V2 carriage, Refund Coin, and their existing mappings.
- Preserve the fixed rail as safe muted infrastructure.
- Preserve the existing environment composition and runtime code.

## Required integration gate

Startup Lab may approve the technician, rack, warning, and landed revisions independently. The falling-product sheet needs an explicit decision about its 10px short-axis collision margin before integration.
