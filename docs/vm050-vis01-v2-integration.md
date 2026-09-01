# VM-0.5.0-VIS-01-D3-V2 Integration Report

Recorded: 2026-09-01 JST

This report records implementation and technical validation. It does not claim that the V2 art is final, readable in every play condition, or preferable before Startup Lab manual review.

## Scope and branch

- Integration branch: `visual/vm-0.5.0-vis-01`
- Parent frozen-art branch: `visual/vm-0.5.0-motion-01`
- Parent commit: `d9bdcfd34708defbb9d8b0504cd8d66451a50303`
- Runtime build ID: `VM-0.5.0-VIS-01-D3-V2`
- Prototype A, the original conveyor, and D2 were not edited.
- The D3 gameplay scheduler, cadence, collisions, physics, score, and round rules were not changed.

## Mandatory death-interactivity check

The integration proceeded because the existing death sequence is already noninteractive before the DEATH sprite begins:

- player input and physics processing stop;
- the player's position remains fixed;
- the player collision shape is not changed;
- active product and carriage processing stops;
- active Refund Coins stop monitoring, stop processing, and become hidden;
- the collectible director stops; and
- the run score remains frozen.

The focused check reported `VM050_VIS01_DEATH_CHECK_FAILURES=0`. This authorizes the visually collapsed `29×19` DEATH pose without changing collision or death semantics.

## Provenance and files moved

The authoritative package was inspected at:

`/Users/jeromenicholaz/.codex/.chatgpt-projects/g-p-6a620f9598f48191b1f5f1a94286b5cd/artifacts/vm050_d3_runtime_assets_v2/`

Twelve approved runtime PNG sheets were copied into `assets/vm050_d3_v2/`. The runtime manifest, Godot handoff, and envelope metrics were copied into `docs/visual-assets/`. No Aseprite master, raw third-party art pack, `.local_art_sources/` content, or unrelated Work scratch file was copied into the repository. Editable V2 masters remain outside the public repository; this follows the existing source policy while the game commits only approved runtime derivatives and provenance documentation.

All twelve primary Aseprite masters were opened read-only before integration. Their frame counts, tags, and logical canvases matched the V2 handoff.

## Runtime mappings

### Technician

- Runtime canvas: `32×48`
- Runtime scale: `1×`
- Collision retained: `32×48`
- Bottom-centre anchor: `(16,48)`; Godot sprite offset is `(-16,-48)` from the player body's bottom-centre origin.
- Mapping: grounded/still → IDLE; grounded/moving → RUN; upward airborne → JUMP; downward airborne → FALL; optional visual landing transition → LAND; terminal death signal → DEATH.
- LAND is visual-only. Directional input or airborne state interrupts it immediately; movement is never paused for animation.
- Restart restores the live animation state.

### Background rack and products

- Three non-colliding rack groups represent red soda, blue coffee, and green sports drink.
- D3 logical lanes map deterministically to those three variants.
- Stored, selected-warning, released-empty, and reset/restock logical states drive the supplied rack lifecycle frames.
- The same selected variant is retained for foreground FALL_TUMBLE, IMPACT, and SETTLED states; foreground variants are not independently randomized.
- The selected warning column is aligned with the D3 logical lane. Existing D3 gameplay timing drives visual playback; gameplay timing was not retimed to match the editorial sheet.

### Falling products

- Logical canvas: `36×36`
- Exact runtime scale: `2×`
- Rendered size: `72×72`
- Collision retained: `72×72`
- Origin: centred on the existing product body.
- FALL_TUMBLE changes only the visual frame. Translation, speed, landing point, collision, and timing remain controlled by existing gameplay code.

### Landed products

- Logical canvas: `36×24`
- Exact runtime scale: `2×`
- Rendered size: `72×48`
- Collision retained: `72×48`
- Origin: centred on the existing landed body.
- IMPACT transitions to SETTLED without changing solidity, support velocity, conveyor movement, or cleanup.
- The despawn-warning outline remains a separate non-colliding visual.

### Retrieval carriage

- Logical canvas: `48×14`
- Exact runtime scale: `2×`
- Rendered size: `96×28`
- Collision retained: `96×28`
- Origin: centred on the existing carriage body.
- Existing cue, sweep, and exit states map to TELEGRAPH, ACTIVE_SWEEP, and visual RETURN.
- The rail remains a separate safe background visual with no lethal collision. Only the existing moving carriage hitbox is lethal.

### Refund Coin

- Logical canvas: `12×12`
- Exact runtime scale: `2×`
- Rendered size: `24×24`
- Existing pickup collision retained: `24×24`
- SPIN is visual-only; score value, routes, spawn cadence, collection logic, and exactly-once scoring are unchanged.

### Conveyor and environment

- The approved `32×16` belt tile is shown at `2×`, producing stable `64×32` visual tiles.
- Belt animation follows the established leftward direction but does not drive or modify support physics.
- The D3 chassis, product bay, left retrieval structure, right product/elevator structure, under-belt machinery, timer, score, and build ID remain in the approved close-up composition.
- Sprite filtering is nearest-neighbour and all primary runtime scales are integer values. Frame canvases and origins remain stable across animations.

## Developer collision overlay

The overlay is OFF by default and unavailable as a tester control in release exports. In a local debug run of `motion_d3.tscn`, press `F8` to toggle:

- technician, falling-product, landed-product, carriage, and coin collision boxes;
- sprite pivots/origins;
- selected D3 rack lane; and
- current D3 logical state.

Representative captures:

- `docs/screenshots/vm050-vis01/01-technician-overlay.png`
- `docs/screenshots/vm050-vis01/02-falling-product-overlay.png`
- `docs/screenshots/vm050-vis01/03-landed-product-overlay.png`
- `docs/screenshots/vm050-vis01/04-carriage-coin-overlay.png`

## Automated validation

- Mandatory death-interactivity check: 0 failures.
- VIS-01 integration suite: `VM050_VIS01_INTEGRATION_TEST_FAILURES=0`.
- Existing motion suite: `VM050_MOTION_EXPERIMENT_TEST_FAILURES=0`.
- Full project suite: all 22 `tests/test_*.gd` scripts exited successfully.
- Prototype A, original Conveyor, D2, and D3 completed 180-frame headless launches.
- D2 has no V2 adapter and remains unchanged.
- Frozen gameplay snapshots verified unchanged player, product, landed-product, carriage, coin, conveyor, round, and D3 timing values.

### D3 cadence regression

The three deterministic seeds each produced six D3 drops, maximum one active D3 sequence, and no starvation:

| Seed | Warning times (seconds) | Longest gap |
|---:|---|---:|
| 5002 | 9.8167, 19.0167, 28.0167, 36.0167, 44.0167, 51.8167 | 9.20 s |
| 6011 | 9.8167, 19.0167, 28.0167, 36.0167, 44.0167, 51.8167 | 9.20 s |
| 7907 | 9.8167, 19.0167, 28.2167, 36.4167, 44.4167, 52.2167 | 9.20 s |

These match the expected D3 architecture and do not establish human warning readability.

## Builds and browser verification

- Local scene: `scenes/experiments/motion_d3.tscn`
- Web directory: `builds/web-vis01-d3-v2/`
- Web archive: `builds/VM-0.5.0-VIS-01-D3-V2-web.zip`
- Export preset: `Web VIS-01 D3 V2`
- Export mode: single-threaded Godot Web

The final Web export loaded from a local HTTP server. The browser reported Godot 4.7.1, WebGL 2, Emscripten 4.0.20, and a single-threaded build. The canvas rendered, restart generated a second run-start event, and the browser console contained zero warnings and zero errors.

## Manual review protocol

1. Open `scenes/experiments/motion_d3.tscn` in Godot and run the current scene with `F6`.
2. Run once survival-first, once coin-greedy, and once naturally.
3. Use `A/D` or `LEFT/RIGHT`, `SPACE`, and `R`.
4. For collision QA only, press `F8` in the local debug build.
5. Review technician prominence and animation, stable pixel scaling, rack-warning alignment, rack-to-foreground depth transition, variant continuity, falling/landing attribution, carriage-versus-safe-rail communication, coin readability, conveyor motion, HUD hierarchy, and clutter.

## Still unverified

- technician prominence during active play;
- whether the product depth transition reads as coming toward the foreground rather than magically growing;
- finished rack-warning readability;
- carriage readability at gameplay speed;
- overall clutter and identity during active play;
- whether the V2 art preserves fair perceived hitboxes for human players; and
- whether the visual slice still feels like the validated game.

No subjective tuning was performed after implementation.
