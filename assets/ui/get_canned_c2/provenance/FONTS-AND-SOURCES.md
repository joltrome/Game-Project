# Lettering and source provenance

## Two project-authored glyph families

The display and small-text bitmaps were authored in the preceding GET CANNED! refinement package as explicit pixel matrices. This production pass reuses those matrices. No commercial typeface, downloaded font, traced reference-game lettering or external font binary is used in the runtime artwork.

| Family | Base construction | Runtime use | Coverage |
|---|---|---|---|
| Display | Variable-width glyphs, generally 7 × 9; all digits use seven-column cells; one-column interglyph spacing | Scores; supplied baked logo, headline and primary-button lettering | A–Z, 0–9, space, `! . / : -` |
| Small | Variable-width glyphs, generally 5 × 7; one-column interglyph spacing | Controls, score captions, shortcuts, secondary buttons, VENTASTIC | A–Z, 0–9, space, `: . / - ! ← →` |

The display colon and hyphen are minimal production additions to cover timer/separator needs. They do not change any selected lettering. The timer reference demonstrates glyph support only; it does not authorize a gameplay HUD redesign. No lowercase, accented letters, Japanese text or broad language coverage is supplied. Existing Credits body text retains its existing font and factual wording.

Files for each family:

- `display.png` / `small.png`: white RGB, transparent-alpha atlas. Tint cream `#f2e7c9` or ink `#0d1424` at runtime. Do not tint precolored button/logo PNGs.
- `display.fnt` / `small.fnt`: text-format BMFont descriptors pointing to the adjacent atlas; no external font binaries.
- `display-metrics.json` / `small-metrics.json`: Unicode code point, exact atlas rectangle, offset, advance, baseline and line height for every included glyph.
- `glyph-definitions.json`: project-authored source matrices; human-readable and reproducible.

Display cap height is 9, baseline 9, line height 11. Small cap height is 7, baseline 7, line height 9. All glyph Y offsets are zero; a space has zero drawable area but an advance of four base pixels. These are all-cap bitmap metrics, not a conventional font with ascenders/descenders. Center by **ink width**, excluding the last interglyph gap, to reproduce the references exactly.

Logical usage: menu Best Score uses display ×3; result numerals normally ×5; huge headlines ×9; primary labels and MENU ×3; small text ×2. The logo is a fixed lock-up with GET ×6 and CANNED ×10 plus its existing bespoke punctuation; use its PNG. The manufacturer now also uses small ×2.

For BMFont use, start at base font sizes 9 (display) and 7 (small) and integer multiples, with nearest filtering and no mipmaps. Ensure Label line-box/baseline handling does not add offsets relative to the manifest's **visible glyph top**. Prebaked lettering avoids that ambiguity for static elements. Atlas metrics provide a deterministic fallback for dynamic digit rendering if the engine importer uses different scaling. Do not fake unsupported lowercase by falling back character-by-character to another novelty font.

The text BMFont format and variable-size bitmap glyph support are documented by [Godot's BMFont importer](https://docs.godotengine.org/en/stable/classes/class_resourceimporterbmfont.html), with general sizing/filtering guidance in [Godot's font guide](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html). Field definitions follow the [AngelCode text format](https://www.angelcode.com/products/bmfont/doc/file_format.html). These are implementation documentation references, not incorporated art/font sources. Descriptors and atlas reconstruction were validated locally; actual Godot import has not been performed because the task forbids modifying or implementing in Godot.

## Source rights and attribution

The new lettering, logo construction and simple UI geometry are project-authored work from this project's refinement/production passes. No third-party font license or attribution requirement is introduced by them. This package does not assert a new third-party license over the project's work or claim trademark registration. VENTASTIC remains the user-selected provisional in-world wordmark; no trademark clearance was performed in this visual production task.

The five gameplay source sheets are supplied project assets reused with the user's explicit authorization. Their filenames, original absolute paths and SHA-256 values appear in [source-provenance.json](source-provenance.json). Existing project provenance/rights remain attached to those assets; this pass does not relicense them. Byte copies are included for a self-contained review, and Codex should reference the identical existing resources at integration.

The locked source refinement is `../vm060_get_canned_c_refinement/source/build_study.py` relative to the production package's parent artifact directory. The copied glyph definitions preserve its source pixel matrices. The preceding generated concept study and Sawblades reference are not runtime asset sources. No reference-game assets, images or fonts have been incorporated.

Pillow's bundled default report font is used only for explanatory labels on comparison/inspection sheets. It is not a gameplay font, is not packaged as a font file, and does not create a runtime font dependency. The HTML viewer uses the viewer's system sans-serif font for navigation only.

No audio file, soundtrack conversion, paid font service or random third-party game UI asset is included.
