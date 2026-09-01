# VM-0.5.0-VIS-02 — Readability and Consistency Delta Manifest

Status: **art-only review package; not approved for automatic integration**.

Starting point: `../vm050_d3_runtime_assets_v2/`

VIS-02 changes only the technician proportions, falling/landed product drawing, rack visual family, and drop-warning treatment. The V2 Refund Coin, retrieval carriage, conveyor behavior, D3 environment composition, HUD hierarchy, and all gameplay values remain authoritative and unchanged.

## Changed runtime assets

| V2 source | VIS-02 candidate | Logical / rendered size | Animation and timing | Collision / anchor | Visible envelope | What changed and why |
|---|---|---|---|---|---|---|
| `VM050_D3_V2_technician_runtime.aseprite` | `VM050_D3_VIS02_technician_chunky_runtime.aseprite` | 32×48 at 1× | `IDLE` 1–3 at 0.16s; `RUN` 4–9 at 0.08s; `JUMP` 10–11 at 0.12s; `FALL` 12–13 at 0.12s; `LAND` 14–16 at 0.07/0.07/0.12s; `DEATH` 17–19 at 0.14s | 32×48; bottom-center `(16,48)` | All live frames 32×48, margins 0/0/0/0 | Same technician identity redrawn with a broader cap/head, wider face, chunky torso, shorter/thicker arms and legs, larger boots, and larger color blocks. |
| `VM050_D3_V2_falling_red_soda_runtime.aseprite` | `VM050_D3_VIS02_falling_red_soda_runtime.aseprite` | 36×36 at exact 2× = 72×72 | `ROTATIONAL_TUMBLE` 1–8 at 0.075s | Frozen 72×72; center `(18,18)` logical | Diagonal frames 64×64 with 4px margins; vertical frames 52×70 with 10px side margins; horizontal frames 70×52 with 10px top/bottom margins | Replaced four-frame diagonal mirroring with a full eight-angle sequence. Metal ends, asymmetric pull tab, highlight, and white slash move consistently around the can. |
| `VM050_D3_V2_falling_blue_coffee_runtime.aseprite` | `VM050_D3_VIS02_falling_blue_coffee_runtime.aseprite` | Same as red | Same | Same | Same | Preserves blue body and rotating gold coffee mark. |
| `VM050_D3_V2_falling_green_sports_runtime.aseprite` | `VM050_D3_VIS02_falling_green_sports_runtime.aseprite` | Same as red | Same | Same | Same | Preserves green body and rotating teal/gold sports label. |
| V2 landed red/blue/green masters | `VM050_D3_VIS02_landed_*_runtime.aseprite` | 36×24 at exact 2× = 72×48 | `IMPACT` 1–2 at 0.07/0.08s; `SETTLED` 3–4 at 0.16s | Frozen 72×48; center `(18,12)` logical | 68×44; margins no larger than 4px | Rounded the silhouette, strengthened both cylindrical ends, and retained label continuity so it reads as a fallen drink instead of a crate. |
| `VM050_D3_V2_rack_product_lifecycle.aseprite` | `VM050_D3_VIS02_rack_slot_red/blue/green.aseprite` | Each slot 28×38, non-colliding background art | `NORMAL` 1; `SELECTED` 2–5 at 0.10s; `RELEASE` 6–7 at 0.10/0.14s; `RESET` 8 at 0.18s | Background placement; no gameplay collision | n/a | Every decorative and mechanically active lane now shares the exact same shelf, rail, muted-product, label, and lighting grammar at rest. Only the selected state adds a local lamp, shake, frame, and gate response. |
| `VM050_D3_V2_warning_column.aseprite` | `VM050_D3_VIS02_drop_warning_runtime.aseprite` | 24×96, non-colliding | `MACHINE_WARNING` 1–8 at 0.10s | Center on existing selected drop path | n/a | Replaces giant chevrons with a small rack-mounted `DROP` plate, twin fixed guide rails, and traveling segmented coral/gold lamps. Existing telegraph duration remains authoritative. |

## Frozen unchanged assets

- `VM050_D3_V2_retrieval_carriage_runtime.*`
- `VM050_D3_V2_refund_coin_runtime.*`
- Conveyor gameplay/physics and existing visual mapping
- Red chassis, off-white frame, dark blue-gray chamber, right elevator, left OUT area, conveyor, and HUD composition

## Collision review result

Exact per-frame measurements are in `VM050_D3_VIS02_envelope_metrics.tsv`.

- Technician: every live frame has zero invisible margin. The collapsed terminal `DEATH` pose is measured separately and is not an active-play collision reference.
- Landed products: maximum invisible margin is 4 runtime pixels.
- Falling products: diagonal frames meet the 4px review threshold, but vertical/horizontal frames have a 10px invisible margin on their short axis.

### Required Startup Lab decision

The eight-frame art now communicates real rotation better than V2. However, a recognizably cylindrical can cannot fill a square 72×72 collision in its vertical, horizontal, and diagonal orientations without turning into a near-square crate.

Therefore the current contract is **not fully artistically and collision-fairly viable at the same time**. Do not integrate the VIS-02 falling sheets until Startup Lab decides whether:

1. the measured 10px short-axis margin is acceptable for a controlled playtest; or
2. a narrowly scoped collision-envelope retest should be authorized later.

VIS-02 does not modify the collision itself.

## Review outputs

- `VM050_D3_VIS02_art_revision_overview.png`
- `VM050_D3_VIS02_technician_comparison.png`
- `VM050_D3_VIS02_technician_pose_collision_review.png`
- `VM050_D3_VIS02_product_collision_study.png`
- `VM050_D3_VIS02_product_continuity.png`
- `VM050_D3_VIS02_rack_consistency_review.png`
- `VM050_D3_VIS02_rack_state_sequence.png`
- `VM050_D3_VIS02_warning_comparison.png`
- `VM050_D3_VIS02_integrated_gameplay_preview.aseprite/.gif`
- `VM050_D3_VIS02_integrated_gameplay_still1.png` through `...still16.png`

The integrated animation is an editorial review only. It is not gameplay-timing authority.
