# VIS-02 Runtime Review Lessons

## Chunky character readability

A sprite can technically fill its collision and still feel visually small. V2 occupied almost all of 32×48, but its narrow shoulders, thin limbs, and many small proportions made it read like a miniature realistic person against large arcade-appliance shapes.

VIS-02 uses the same canvas, collision, anchor, colors, and identity while redistributing mass into a larger head, broader torso, shorter/thicker limbs, and larger boots. The protagonist now communicates through silhouette and large color blocks at gameplay size.

## Pixel-art rotation

Mirroring a diagonal image changes direction but does not prove physical rotation. V2's ends, highlight, and label did not travel through a continuous cycle, so the object could read as a plank flipping between two diagonals.

VIS-02 uses eight angle states. Metal ends exchange position, an asymmetric pull-tab travels with one end, the body highlight changes side, and each product label rotates with the can. That reads more clearly as rotation.

The exercise also exposed a geometry conflict: a cylindrical can necessarily becomes narrower on one screen axis when vertical or horizontal. A square 72×72 collision cannot remain within a 4px invisible-margin standard through a convincing full rotation unless the art becomes nearly square and crate-like.

## Interactive background consistency

If mechanically active slots have unique framing, brighter products, or different construction while safe, players can see implementation structure rather than a believable storage system.

VIS-02 gives every decorative and active slot the exact same NORMAL module. Only after selection does one lane gain a local lamp, shake, highlighted frame, moving gate, and temporary empty state. The scene now behaves like a normal machine developing a malfunction.

## Diegetic telegraphing

A warning can be readable yet still feel detached from the world. V2's large `DROP` label and stacked chevrons dominated the chamber like debugging graphics.

VIS-02 keeps the information path but attaches it to machine hardware: the rack slot changes first, a small `DROP` plate activates, then paired segmented lamps travel down fixed guide rails. This still identifies the dangerous column while preserving the vending-machine fiction and existing telegraph duration.
