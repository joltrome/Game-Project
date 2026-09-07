# Pending Gameplay QA

This list preserves gameplay observations during the visual transition. It does not authorize tuning while VM-0.4.7 gameplay is frozen.

## Refund Coin route footprint

- **Source:** external/manual observation carried into the VM-0.5.0 art audit.
- **Evidence:** some multi-coin offers have been perceived as locally clustered. The available observation is not a measured failure rate and does not isolate a specific authored template.
- **Hypothesis:** routes containing three or more coins may need an overall footprint around 35–60 percent of the usable horizontal playfield, or clearer vertical branching, to require an additional decision after the first coin.
- **Current decision:** Startup Lab authorized one narrow final Standard Mode correction after VIS-04 external testing. The safe-versus-risk template now keeps two accessible ground coins and adds a leftward low-air jump followed by an optional modest rightward tail. Simple horizontal trails and compact reward clusters remain intentionally unchanged. No other gameplay tuning is authorized.
- **Automated result:** the revised route is collectible with the locked controller, is not completed by no input, unchanged left input, or one passive jump, and preserves a one-coin abandonment path. Three deterministic 60-second seeds retained the exact 54/55/55 offered-coin totals and 22-offer cadence from the measured baseline.
- **Pending manual validation:** during natural and coin-greedy runs, record whether later coins sometimes require another jump, horizontal adjustment, or continue/abandon choice after the first pickup; also record if the route is confusing, exhausting, or effectively automatic. Freeze Standard Mode coin gameplay after acceptance.
- **Visual-integration risk:** background detail, machine framing, or product art could make an already compact route harder to parse. That is a readability bug to correct visually, not automatic permission to retune the director.
