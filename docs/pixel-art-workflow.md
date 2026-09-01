# Pixel-Art Workflow for the VM-0.5.0 Slice

This is a short production workflow, not an art tutorial. It assumes Startup Lab has approved one palette and one target screenshot.

## Recommended tool path

- **Preferred: Aseprite.** It can open the found Kowches `.aseprite` project, preserve frame tags/layers, edit indexed palettes, onion-skin animation, and export deterministic sheets.
- **Free alternative: Pixelorama.** Use when avoiding a software purchase is more important than directly preserving Aseprite-native structure. Confirm imported layers/tags before relying on them.
- Neither application was found installed during the audit. Do not purchase or install either automatically.

## Source editability

- **Native editable source:** Kowches only (`player.aseprite`, 19 frames on a 64×64 canvas).
- **Frame-level editable PNGs:** Kowches and Atomic character frames.
- **Palette-aided flattened PNGs:** Neon Platformer includes a 21-color palette image.
- **Flattened PNG only:** Oberzs, ACTG, factory_, karsiori vending machines, and Atomic tiles. Recoloring is practical; deep animation or structural edits require manual separation/redraw.
- **PSD:** none in the downloaded sources. Atomic's paid SOURCE tier advertises PSD files, but that tier is not present locally.

## Production sequence

1. Confirm license evidence and the source's allowed production role.
2. Duplicate the approved reference into `.local_art_sources/`; never edit the original Downloads copy.
3. Establish the approved target palette before producing multiple assets.
4. Set a logical pixel grid and integer game scale. For the protagonist, test a roughly 16×24 or 16×28 visible silhouette displayed at 2× against the frozen 32×48 collision.
5. Edit silhouette first: head/helmet, torso, hands, feet, and major machine outlines must read without shading.
6. Preserve animation anchors. Keep the grounded foot point and frame canvas stable across idle, run, jump, fall, and land.
7. Add only enough shading to separate gameplay objects from low-contrast machinery. Do not copy each pack's original shade count.
8. Export a transparent PNG sprite sheet plus, where possible, the editable working file. Use stable filenames and document frame dimensions/order.
9. Import into Godot with nearest-neighbor filtering, no unintended mipmap blur, and integer Sprite2D scale.
10. Align visuals to existing collision shapes; do not resize gameplay collision to fit art during the vertical slice.
11. Verify at actual 1152×648 gameplay scale, itch.io embed scale, and fullscreen—not only in a zoomed pixel editor.
12. Capture a comparison screenshot and test hierarchy: timer, player, warnings, lethal hazards, solid obstacles, Refund Coins, then decoration.

## Signature versus commodity review

- Require explicit approval for protagonist, HUD, right housing, left chute, Sweeper mechanism, Refund Coin, product obstacles, and signage.
- Commodity pipes, bolts, vents, wires, braces, motors, and background panels can use approved pack material when licenses, outline weight, scale, and palette are normalized.
- Never commit raw third-party source packs. Commit only deliberately approved game-ready derivatives whose license permits their use in the shipped project, plus attribution/license records where required.

## VIS-01 V2 runtime implementation

The approved V2 package resolves the earlier collision-envelope problem with exact integer runtime mappings. Godot uses the exported horizontal PNG sheets at nearest-neighbour filtering, stable per-frame canvases, and fixed origins. The technician is `32×48` at `1×`; falling products are `36×36` at `2×`; landed products are `36×24` at `2×`; the carriage is `48×14` at `2×`; the Refund Coin is `12×12` at `2×`; and conveyor tiles are `32×16` at `2×`.

Animation changes visuals only. Existing bodies continue to own translation, collision, support velocity, score, timing, and cleanup. The D3-only integration adapter maps gameplay state to animation state and preserves red/blue/green identity from the selected background rack product through falling and landed states. Editable Aseprite masters remain outside the public repository under the established art-source policy; runtime exports and provenance documentation are committed.
