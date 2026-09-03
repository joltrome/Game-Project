# VM-0.5.0 VIS-04 Runtime Asset Provenance

Recorded: 2026-09-03 JST

## Source package

The VIS-04 runtime files were copied from the project-specific Work artifact
package supplied by Startup Lab:

`vm050_vis04_scale_motion_coin/`

Before integration, the package report, implementation notes, manifest,
measurements, S0/S1/S2 player comparisons, C0/C1/C2 coin comparisons, and the
relevant Aseprite masters were inspected read-only. Startup Lab authorized only
S1 and C1 for this runtime comparison. S2 and C2 were not copied.

## Repository policy choice

Only the two PNG runtime sheets required by Godot are committed. Editable
Aseprite candidate masters, comparison GIFs, Work reports, and scratch material
remain in the private Work artifact package. No `.local_art_sources/` file or
raw third-party pack was copied into the public repository.

## Committed runtime exports

| Runtime file | Source | Sheet dimensions | Runtime cell | SHA-256 |
|---|---|---:|---:|---|
| `VM050_VIS04_S1_50x60_run_sheet.png` | `VM050_VIS04_S1_50x60_candidate_sheet.png` | 300×60 | 50×60 | `62ceeddcbfbe00d74c5481d13252ca7d835ed9934e62609a076d883bc2fb4ebc` |
| `VM050_VIS04_C1_16x16_coin_sheet.png` | `VM050_VIS04_C1_32x32_coin_candidate_logical_sheet.png` | 96×16 | 16×16, rendered at exact 2× | `5453420ab18a9fcef9ddce5832ba33f7ce8a9d244eb69955f016862de062c6d8` |

The repository copies are byte-identical to the corresponding supplied Work
PNGs. Godot imports both with nearest-neighbour filtering.

## Frozen assets reused

VIS-04 continues to load the already committed VIS-03 rack, lane, warning, and
non-RUN technician state art; VIS-02 falling and landed product art; and V2
carriage and conveyor assets. None of those files was copied or edited during
VIS-04.

## Runtime safeguards and limitation

- S1 RUN uses the authored 50×60 cells at exact 1× with a stable bottom-centre
  visual origin and the unchanged 32×48 gameplay collision.
- The supplied S1 package contains only the six RUN frames. To avoid inventing
  art, IDLE/JUMP/FALL/LAND/DEATH continue using the approved 40×48 VIS-03 cells,
  uniformly rendered at 1.25× with nearest-neighbour filtering into the same
  50×60 footprint. This transition is a runtime-review compromise, not approved
  final animation art.
- C1 uses 16×16 cells at exact 2×, producing a 32×32 visual without non-uniform
  scaling.
- The C-A and C-B collision choices are runtime configuration only; the coin
  route director retains its frozen 24×24 authored footprint.
- No collision was changed to accommodate S1. C-B changes only the authorized
  instantiated pickup shape to 32×32.
