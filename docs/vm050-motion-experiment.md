# VM-0.5.0-MOTION-01 — D2 vs D3 Structural Motion Experiment

Recorded: 2026-08-26

Branch: `visual/vm-0.5.0-motion-01`

Status: implemented and technically validated; manual comparison pending. This document records implementation facts, not evidence that either direction is more readable, fair, or enjoyable.

## Controlled baseline

Both variants instantiate the existing `scenes/prototypes/conveyor.tscn` rather than duplicating gameplay. The shared player controller, jump/gravity values, conveyor behavior and speed curve, 60-second round, coin value and authored offer system, hazard timings and intensity, death/restart rules, horizontal play width, and Prototype A remain unchanged. The project-wide main scene also remains the frozen conveyor.

The only shared gameplay-script change is a disabled-by-default external-product replacement seam in `scripts/conveyor.gd`. With no handler installed, as in the frozen scene, it does nothing. D3 installs the handler at runtime; D2 and the frozen scene do not.

## Variant configuration

| Property | D2 | D3 |
|---|---|---|
| Build ID | `VM-0.5.0-MOTION-01-D2` | `VM-0.5.0-MOTION-01-D3` |
| Internal viewport | 1152×480, exactly 2.4:1 | 1152×648, exactly 16:9 |
| Host scaling | contained, centred, nearest filtered | contained, centred, nearest filtered |
| Gameplay scene | frozen conveyor instance | frozen conveyor instance |
| Background-product mechanic | absent | installed at runtime |
| Ordinary product interaction | unchanged | an eligible ordinary product event is replaced one-for-one |

D2 changes presentation only. It uses the same world coordinates and physics, moves the camera centre to y=412, and relays existing HUD nodes into the 480-pixel-tall frame. It does not install D3 scheduling code.

D3 retains the original camera centre at y=324 and adds three visible stored product slots in the background product bay. A reserved product changes from muted stored state to a gold pulsing selected state, displays an aligned `DROP` warning column, leaves its source slot dark when released, then resets the slot only after the foreground product lands.

## D3 schedule and replacement lifecycle

Initial hypothesis values:

- Reservation times: 16.0, 28.0, 40.0, and 52.0 seconds.
- Maximum: four background products per 60-second round.
- Warning duration: 1.10 seconds.
- Target release-to-belt duration: 0.85 seconds, with fall speed derived from the actual release-to-floor distance.
- Retry delay after an ineligible ordinary event or invalid lane: 0.12 seconds.
- Candidate lane centres: x=406, 526, and 646.

The reservation does not create a second product in addition to the frozen director's event. It waits for the next eligible, untargeted ordinary product event, validates a lane against the current state, marks the ordinary event as replaced, holds the existing one-falling-product slot through warning and release, and registers the released product in the original conveyor product collection. Targeted right-edge pressure events are not replaced. A rejected attempt stays reserved for a later eligible event.

The released product uses the existing state machine: contact while falling is lethal; valid belt contact converts it into the same solid, non-lethal, left-moving support used by ordinary products. Restart creates a fresh wrapper and clears reservations, warnings, products, and in-memory instrumentation.

## Fairness validation boundary

Deterministic/exact checks performed before committing a D3 lane:

- product footprint remains inside the frozen belt/control-band bounds;
- the maximum one-falling-product cap is available and remains reserved;
- no projected landed-product footprint overlaps the candidate at impact;
- no current falling product exists;
- active Refund Coin paths do not intersect the candidate fall corridor;
- the current Sweeper configuration still preserves the known grounded-clearance response;
- warning-to-release timing and warning-to-product correspondence are one-to-one;
- fall speed is derived from actual release height, floor height, product height, and target duration.

Heuristic checks:

- player escape reach uses current player x, frozen net left/right world speeds, warning plus fall time, collision half-widths, eight pixels of clearance, and a 0.18-second reserve;
- projected constant conveyor motion approximates where an existing landed product will be at impact;
- Refund Coin route overlap is conservatively treated as invalid, but this is not a complete future trajectory solver;
- human recognition time, perceived depth, visual clutter, preferred action, and unavoidable-feeling deaths require manual playtesting.

## Local-only instrumentation

`MotionLocalInstrumentation` stores events in memory and optionally prints lines prefixed `MOTION_LOCAL`. It does not write files, send analytics, make network requests, or identify a player. Recorded fields, where applicable, include variant, run time, local timestamp, remaining round time, score, inferred death cause, player position, active carriage/product counts, and D3 reservation/warning/release/landing/reset/rejection events.

## Automated and launch results

- All 21 Godot test files passed with zero reported test failures.
- The dedicated motion suite verified the exact internal sizes/build IDs, nearest filtering, frozen-value equality, D2/D3 isolation, default-scene preservation, Prototype A loading, aspect containment, D3 lane rejection, one-for-one replacement, lifecycle state changes, instrumentation, and fresh-scene reset.
- Deterministic natural D3 lifecycle: four warnings, four releases, four landings, four visual resets, one rejected replacement attempt, and maximum one falling product.
- Observed first D3 warning: 16.95–16.98 seconds across the final deterministic runs, inside the approved 15–20-second window.
- D2 aspect matrix remained centred and unstretched. Unused host area was 25.93% at 16:9, 33.33% at 16:10, 0% at native 2.4:1, 7.41% at 20:9, and 46.43% at 900×700. Scaling may be fractional; native 1152×480 is exact 1:1.
- Original Arena, original Conveyor, D2, and D3 each completed a 180-frame headless launch with exit code 0.
- Both single-threaded Web exports completed and include `index.html` at the directory and ZIP root.
- Browser smoke tests loaded D2 and D3 at their native profiles and at a 900×700 host. Canvas size followed the host, the contained internal viewport stayed centred without aspect stretch, and no browser-console warnings or errors were reported.
- Godot headless runs emitted the known macOS system-CA lookup warning and sandboxed editor-settings save warning; neither caused a failed test, launch, or export.

## Art and provenance decision

The runtime motion-study visuals are project-owned Godot geometry and default-font text. No downloaded art pack, flattened Work mockup, custom font, or third-party asset was integrated or committed. The inspected Aseprite mockup contained a hidden `SOURCE Sports Drink` layer with third-party/unclear provenance, so it remains reference-only outside the repository. The experiment follows the approved Japanese retro vending direction using code-native cream, red, teal, blue, green, gold, and navy shapes.

The former missile/Sweeper presentation is skinned as a retrieval carriage: a safe muted rail, then a bright compact lethal carriage whose visible rectangular body matches the existing 96×28 hazard envelope. There is no decorative lethal tail.

## Run and compare locally

1. Import this repository's `project.godot` into Godot 4.7.1 if it is not already open.
2. Open `scenes/experiments/motion_d2.tscn`; press **F6**.
3. Move with A/D or Left/Right, jump with Space, and restart with R.
4. Check the wide composition at native window size, a normal 16:9 window, a narrower desktop window, and fullscreen. Record unused-space treatment, HUD legibility, hazard/coin readability, and whether the crop hides needed information.
5. Stop the run. Open `scenes/experiments/motion_d3.tscn`; press **F6**.
6. Survive past roughly 17 seconds. Observe the product slot select, the aligned warning, the source slot empty on release, the product fall, and the slot reset after landing.
7. Confirm that the background release replaces rather than accompanies the eligible ordinary product event, falling contact is lethal, and the landed product is the existing solid moving support.
8. Compare how quickly each layout communicates player, timer, Refund Coins, carriage, product source, and safe routes. Do not tune values during the comparison.
9. Bring screenshots or a recording from the same host size for both variants and note any death that felt unavoidable or any warning/source correspondence that was missed.

## Web build commands

```bash
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web Motion D2" builds/web-motion-d2/index.html
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web Motion D3" builds/web-motion-d3/index.html
(cd builds/web-motion-d2 && zip -q -r ../vm-0.5.0-motion-01-d2-web.zip . -x '*.import' '.DS_Store')
(cd builds/web-motion-d3 && zip -q -r ../vm-0.5.0-motion-01-d3-web.zip . -x '*.import' '.DS_Store')
python3 -m http.server 8120 --directory builds/web-motion-d2
python3 -m http.server 8121 --directory builds/web-motion-d3
```

No build directory or ZIP is tracked by Git.
