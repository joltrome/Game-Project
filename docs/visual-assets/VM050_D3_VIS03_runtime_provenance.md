# VM-0.5.0 VIS-03 Runtime Asset Provenance

Recorded: 2026-09-02 JST

## Source packages

The VIS-03 runtime files were copied from the project-specific Work artifact
packages supplied by Startup Lab:

- rack and warning package:
  `vm050_d3_vis03_art_revision/`;
- approved rigid-block technician package:
  `vm050_vis03_technician_block_limbs/`.

The package manifests report these as project-specific runtime derivatives.
The relevant Aseprite masters and package documentation were inspected
read-only before integration. No raw third-party pack, `.local_art_sources/`
file, unrelated Work scratch file, or source Aseprite document was copied into
the public repository.

## Repository policy choice

Only the six PNG runtime exports required by Godot are committed. Editable
Aseprite masters remain in the private Work artifact package. This follows the
existing policy of keeping raw sources outside the public repository when the
runtime export plus provenance record is sufficient.

## Committed runtime exports

| Runtime file | Dimensions | SHA-256 |
|---|---:|---|
| `VM050_D3_VIS03_drop_warning_runtime_sheet.png` | 192×96 | `6e40ab8bee2b07f5d0b779f19ed69bb48364566f874b6d54720446156772149f` |
| `VM050_D3_VIS03_full_product_rack_baseline.png` | 312×108 | `9c934557ec48278ace42d3e69d834ede2c253ea76086a3256e8ebb1f21b87d6f` |
| `VM050_D3_VIS03_rack_lane_blue_sheet.png` | 192×31 | `5abca486648ef712599abd13967af5c0a8e83ddcc64ed0beed5a8dc5a275cb2b` |
| `VM050_D3_VIS03_rack_lane_green_sheet.png` | 192×31 | `7a03fd54e459be1279be5eb5993a751d19b743a52dbb97eb311f69480de29f1c` |
| `VM050_D3_VIS03_rack_lane_red_sheet.png` | 192×31 | `2dcb6103ece86852bbae61d09a09649f7015780b5f26158a0e758d1d08914bae` |
| `VM050_VIS03_technician_rigid_block_limbs_sheet.png` | 760×48 | `19c5b01405764c60ad7fe1a1418a7150405603a98055c2ad02ae476a97cc5b88` |

The five rack/warning hashes match the supplied VIS-03 delta manifest. The
technician hash was calculated from both the supplied rigid-block PNG and its
unchanged repository copy.

## Frozen assets reused

VIS-03 continues to load the already committed VIS-02 rotational falling
products and landed products, plus the V2 carriage, Refund Coin, and conveyor
tile. Those assets were not copied or edited during this task.

## Runtime safeguards

- All imported sprites use nearest-neighbour filtering.
- The technician uses a stable 40×48 cell at 1× and a bottom-centre `(20,48)`
  visual origin against the unchanged 32×48 collision.
- Rack and warning art is non-colliding.
- The full rack and lane overlays use exact 2× scale.
- The selected falling collision is a centred 60×60 rectangle; the art and
  physics remain the existing VIS-02 implementation.
- The landed state remains 72×48.

