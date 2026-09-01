# VM-0.5.0-VIS-02-RT Runtime Integration and Collision Retest

Recorded: 2026-09-02 JST

This report records implementation and technical validation. It does not
select a collision, claim that either build is fair or balanced, or replace
the required Startup Lab manual comparison.

## Scope and isolation

- Branch: `visual/vm-0.5.0-vis-02`
- Parent branch: `visual/vm-0.5.0-vis-01`
- Parent commit: `efb91bcd29544eda290ba6460c26bd5b98ed7870`
- Build A: `VM-0.5.0-VIS-02-D3-FALL72`
- Build B: `VM-0.5.0-VIS-02-D3-FALL60`

Both scenes instantiate the same D3 shell and use the same visual adapter,
art, player, conveyor, product source, warning, scheduler, trajectory, speed,
carriage, Refund Coin system, round, and landed-product behavior. The only
intended gameplay difference is falling lethal collision size.

Prototype A, the original Conveyor scene, D2, and the VIS-01 D3 scene remain
independently loadable. No collision winner was selected.

## VIS-02 assets integrated

Eleven approved PNG sheets were copied to `assets/vm050_d3_vis02/`:

- one chunky technician sheet;
- three eight-frame rotational falling-product sheets;
- three revised landed-product sheets;
- three product-specific rack lifecycle sheets; and
- one eight-frame machine-warning sheet.

The delta manifest, Godot handoff, envelope metrics, and runtime-review lessons
were copied to `docs/visual-assets/`. Aseprite masters were inspected read-only
but not copied. See
`docs/visual-assets/VM050_D3_VIS02_runtime_provenance.md` for hashes and policy.

## Runtime mappings

### Technician

- logical/runtime canvas: `32×48` at `1×`;
- frozen collision: `32×48`;
- bottom-centre anchor: `(16,48)`;
- IDLE: frames 0–2, 160 ms each;
- RUN: frames 3–8, 80 ms each;
- JUMP: frames 9–10, 120 ms each;
- FALL: frames 11–12, 120 ms each;
- LAND: frames 13–15 at 70/70/120 ms;
- DEATH: frames 16–18, 140 ms each.

LAND remains visual-only and is interrupted by input/airborne state. The
existing noninteractive death gate remains unchanged.

### Rack and warning

Ten non-colliding rack sprites use the same safe NORMAL presentation at rest.
The three existing eligible D3 lanes map to columns 4, 6, and 8; eligibility is
unchanged. Only the selected column changes to SELECTED, then RELEASE and RESET.

The eight-frame rack-mounted machine warning loops at 100 ms per frame while
the existing 1.10-second gameplay warning is active. It is aligned with the
selected D3 lane and hidden on release. Visual playback conforms to gameplay;
the warning duration was not retimed.

### Falling products

- logical canvas: `36×36`;
- rendered visual: `72×72` at exact `2×`;
- eight frames at 75 ms each (`0.60 s` loop);
- stable centred origin;
- identical art, translation, fall speed, and landing trigger in A and B.

Variant A uses a centred `72×72` lethal falling collision. Variant B uses a
centred `60×60` lethal falling collision. Product visual/fairness footprints,
floor contact, schedule validation, and fall-distance calculations remain
based on the frozen `72×72` product size, so the collision experiment does not
alter trajectory, speed, landing point, or scheduler geometry.

### Landed products

- logical canvas: `36×24`;
- rendered/collision size: `72×48` at exact `2×`;
- IMPACT: 70/80 ms;
- SETTLED: two-frame 160/160 ms loop;
- existing solidity, support velocity, conveyor movement, warning, and cleanup.

The 60×60 falling state transitions to the same 72×48 landed state as the
72×72 build.

### Unchanged VIS-01 elements

The approved V2 retrieval carriage, Refund Coin, and conveyor tile remain
unchanged. Their visuals, collisions, score/route logic, movement, and timing
were not part of VIS-02.

## Landed-source Y bug

### Root cause

The landed platform is a child `AnimatableBody2D` with physics synchronization.
While falling, that child collision is disabled. When an externally released
D3 product moved its parent `Area2D` from the rack release height to the landed
height, the child could retain its disabled physics-server release transform.
The ordinary and D3 parents reached the same Y, but the synchronized landed
body—and therefore its sprite child—could expose a source-dependent settled Y.

### Fix

All sources keep the existing parent landing rule:

`product centre Y = floor Y - landed height / 2 = 584 - 24 = 560`

On the first landed physics frame, `ConveyorProduct` submits one corrected
global transform directly to the landed `AnimatableBody2D` through
`PhysicsServer2D`, then leaves the original synchronization and per-frame
horizontal platform movement intact. This avoids source-specific art padding
and does not disable moving-platform support.

### Regression result

Both the ordinary/right-source and D3/background-source paths reported:

- parent Y: `560`;
- landed body/sprite Y: `560`;
- collision: `72×48`;
- collision bottom: `584` exactly;
- identical non-lethal solidity and conveyor support velocity.

The existing edge-support regression also confirms the player can stand on the
moving landed product before it carries them into the existing failure region.

## Collision margin measurement

The targeted test reads the actual imported VIS-02 red-product PNG, extracts
each frame's alpha bounds, applies the exact `2×` runtime scale, and compares it
with each centred collision.

| Pose class | Representative visible envelope | 72×72 maximum invisible lethal margin | 60×60 maximum invisible lethal margin | 60×60 maximum visible overhang |
|---|---:|---:|---:|---:|
| Vertical | about 52×70 | 10 px horizontally | 4 px horizontally | 6 px vertically in the asymmetric raster |
| Diagonal | 64×64 | 4 px | 0 px | 2 px |
| Horizontal | about 70×52 | 10 px vertically | 4 px vertically | 6 px horizontally in the asymmetric raster |

The measured 6 px overhang is one pixel above the symmetric five-pixel
arithmetic because individual frames have asymmetric alpha bounds. It is
forgiving visible art outside collision, not hidden lethal collision.

Representative overlays:

- `docs/screenshots/vm050-vis02/fall72-01-vertical-overlay.png`
- `docs/screenshots/vm050-vis02/fall72-02-diagonal-overlay.png`
- `docs/screenshots/vm050-vis02/fall72-03-horizontal-overlay.png`
- `docs/screenshots/vm050-vis02/fall60-01-vertical-overlay.png`
- `docs/screenshots/vm050-vis02/fall60-02-diagonal-overlay.png`
- `docs/screenshots/vm050-vis02/fall60-03-horizontal-overlay.png`

Red outlines show the lethal collision; white crosses show the centred origin.
The developer overlay is OFF by default. Press `F8` in a local debug build to
toggle collision boxes, pivots, selected D3 lane, logical state, and subordinate
collision-build ID.

## Automated validation

- `test_vm050_vis02_runtime_retest.gd`: 0 failures.
- Final project regression: 22 of 23 `tests/test_*.gd` scripts passed in one
  aggregate run. The remaining pre-existing natural-offer lifecycle script
  missed one authored route for seed 1701 in that timing-dependent run, then
  passed independently without a code change (0 failures). The VIS-02 script
  passed both in the aggregate run and independently. The accelerated VIS-02
  cadence bound is derived from the existing 9.0-second repeat ceiling plus
  the frozen 1.10-second warning and frame quantization.
- Existing D3 motion suite: 0 failures across seeds 5002, 6011, and 7907;
  each completed six warnings, releases, landings, resets, and suppressions.
- Prototype A, original Conveyor, D2, VIS-01 D3, VIS-02 Fall 72, and VIS-02
  Fall 60 each completed a 180-frame headless launch.
- The existing player, carriage, coin, conveyor, restart, D2, Prototype A,
  VIS-01, source-continuity, warning, support, and round regressions remained
  green.

Representative VIS-02 natural runs for seed 5002 each produced six D3 events,
maximum one active sequence, maximum one falling product, first warning at
9.8167 seconds, and no repeated adjacent lane. Fairness retries can select
different valid later lanes between independently simulated builds; exact
configuration and controlled gameplay snapshots are identical.

## Web validation and internal builds

Both presets are single-threaded (`GODOT_THREADS_ENABLED = false`) and export
`index.html` at the directory/archive root.

Local directories:

- `builds/web-vis02-fall72/`
- `builds/web-vis02-fall60/`

ZIPs:

- `builds/VM-0.5.0-VIS-02-D3-FALL72-web.zip`
- `builds/VM-0.5.0-VIS-02-D3-FALL60-web.zip`

Both builds loaded through localhost with a 2560×1440 backing canvas displayed
at 1280×720, showed the correct subordinate build ID, and produced zero browser
warnings and zero browser errors. The builds were not uploaded or published.

## Manual comparison protocol

Run locally with F6:

1. `scenes/experiments/motion_vis02_fall72.tscn`
2. `scenes/experiments/motion_vis02_fall60.tscn`

Or serve the Web directories on separate ports. Alternate order to reduce
adaptation bias: 72, 60, 60, 72, 60.

For every run, observe:

- visually inexplicable falling-product deaths;
- whether 60 feels materially too easy or remains decision-relevant;
- whether falling products still constrain movement and coin choices;
- rack-drop repositioning, warning clarity, and drink rotation recognition;
- chunky-technician readability; and
- identical landed height from ordinary and D3 sources.

No automated or author-only result establishes whether 60 is structurally too
forgiving. That remains unverified until Startup Lab plays both builds.

## Unchanged and unverified

No player, 60-second round, D3 cadence, warning duration, product speed,
trajectory, conveyor, carriage, Refund Coin, score, offer, D2, Prototype A, or
other hazard value was retuned. The smaller collision was not compensated.

Still unverified:

- human perceived fairness of each collision;
- whether 60 materially reduces challenge or product decision pressure;
- finished warning/rack readability during active play;
- technician prominence and animation readability;
- whether rotation consistently reads as a drink;
- overall clutter, death attribution, and visual preference.

Return both builds and these observations to Startup Lab. Do not select a
winner or begin another art/gameplay revision in Codex.
