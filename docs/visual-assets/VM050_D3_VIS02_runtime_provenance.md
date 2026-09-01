# VM-0.5.0 VIS-02 Runtime Asset Provenance

Recorded: 2026-09-02 JST

## Authoritative package

The approved source package was inspected at:

`/Users/jeromenicholaz/.codex/.chatgpt-projects/g-p-6a620f9598f48191b1f5f1a94286b5cd/artifacts/vm050_d3_vis02_art_revision/`

The delta manifest, Godot handoff, envelope metrics, runtime-review lessons,
primary PNG exports, GIF previews, and all eleven primary Aseprite masters were
inspected before integration. The Aseprite masters were opened read-only to
confirm canvases, frame counts, tags, and timing.

The package manifest states that the runtime derivatives are project-specific
and contain no embedded raw third-party artwork. The B0.1/B0.2 and V1/V2 work
remain visual-identity history; VIS-02 is the approved runtime correction for
this internal comparison.

## Repository policy used

Only the eleven game-ready PNG sheets required at runtime were copied into
`assets/vm050_d3_vis02/`. The four relevant text handoff/provenance documents
were copied into `docs/visual-assets/`.

The following were deliberately not copied:

- Aseprite masters;
- raw third-party packs or `.local_art_sources/` content;
- GIF previews, review boards, collision-study images, and comparison sheets;
- unrelated Work scratch files.

Editable masters remain in the authoritative external package. This matches
the repository's established public-source policy: commit approved runtime
derivatives and provenance, while keeping raw/editable working sources outside
the public repository unless a later policy explicitly approves them.

## Runtime PNG inventory

| Runtime file | PNG dimensions | SHA-256 |
|---|---:|---|
| `VM050_D3_VIS02_drop_warning_runtime_sheet.png` | 192×96 | `1ae7ca8edb73944d9739369b86ad1ea2f43f02716a3ad985d5a2ed67a7a54d61` |
| `VM050_D3_VIS02_falling_blue_coffee_runtime_sheet.png` | 288×36 | `71f6822c740c84687ff268ff9c042617514160e49ce876d2520ccd55a58964ca` |
| `VM050_D3_VIS02_falling_green_sports_runtime_sheet.png` | 288×36 | `284960e50a1341f09673bf93dee2df8dd0ef64ef9676572fec7bf84b6356b284` |
| `VM050_D3_VIS02_falling_red_soda_runtime_sheet.png` | 288×36 | `d7a8321565f3f4d01bba782a6d1f68fc7e435320e1893257a15b61fd06616afd` |
| `VM050_D3_VIS02_landed_blue_coffee_runtime_sheet.png` | 144×24 | `c75f09a466dc4cc28f23fb11eea18413ad2b518ec4972c7b667baaf35744c204` |
| `VM050_D3_VIS02_landed_green_sports_runtime_sheet.png` | 144×24 | `8b4d4a0f11d50031861bb1307081d9016d5958e28a64e989b7dc4a224bbafc33` |
| `VM050_D3_VIS02_landed_red_soda_runtime_sheet.png` | 144×24 | `1b9d08aa0d3621ac151f261b622281431dfd9629878fa15ebdbd21ad7475172c` |
| `VM050_D3_VIS02_rack_slot_blue_sheet.png` | 224×38 | `f6e370bef84814d9f6a7087f4c90b42cc70bf9a2a07a3fbf50bb199b0b52aa0e` |
| `VM050_D3_VIS02_rack_slot_green_sheet.png` | 224×38 | `bd079efbe2bb01d97038715737cdd72e63edd48b34e9c5112d5d480a046182dd` |
| `VM050_D3_VIS02_rack_slot_red_sheet.png` | 224×38 | `e366e0d395eaa100e029153e6feb352d76a129421463f52b22b05aa250b9eb0a` |
| `VM050_D3_VIS02_technician_chunky_runtime_sheet.png` | 608×48 | `e289f2c9cb2122a0a8ef3c66f9fd79894f6248d8f41b5157f5fed7c9437c9a62` |

## Runtime guarantees

- nearest-neighbour filtering;
- integer `1×` technician and `2×` product display scales;
- stable per-animation frame canvases and origins;
- visual animation does not drive translation or collision;
- product color identity remains continuous from rack to falling to landed;
- the same VIS-02 art is used in both falling-collision builds.

The 60×60 collision is an internal gameplay retest, not an alteration of the
runtime art or a final production decision.
