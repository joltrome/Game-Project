# Pending Gameplay QA

This list preserves gameplay observations during the visual transition. It does not authorize tuning while VM-0.4.7 gameplay is frozen.

## Refund Coin route footprint

- **Source:** external/manual observation carried into the VM-0.5.0 art audit.
- **Evidence:** some multi-coin offers have been perceived as locally clustered. The available observation is not a measured failure rate and does not isolate a specific authored template.
- **Hypothesis:** routes containing three or more coins may need an overall footprint around 35–60 percent of the usable horizontal playfield, or clearer vertical branching, to require an additional decision after the first coin.
- **Current decision:** do not modify `scripts/collectible_director.gd` during the art audit or visual vertical slice. First test whether the new visual treatment makes current branches more or less legible.
- **Future validation:** label the accepted offer type, capture its coin coordinates and player position, and record whether the player collects siblings without renewed horizontal input, jump timing, or continued exposure. Change geometry only after a reproducible template-specific problem is established.
- **Visual-integration risk:** background detail, machine framing, or product art could make an already compact route harder to parse. That is a readability bug to correct visually, not automatic permission to retune the director.
