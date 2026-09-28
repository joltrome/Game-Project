# VM-0.7.4 — Responsive Mobile Cabinet

## Scope and decision

VM-0.7.4 is a presentation-only mobile-layout milestone based on exact
VM-0.7.3 HEAD `c6839c578c813acce00341d66d72e6d5147cacca`. It preserves the
1152×648 game, VM-0.7.3 coin pressure, player, hazards, D3, score, 60-second
round and audio. The approved decision is to retain the bottom deck near 16:9
and use horizontal side wings on sufficiently wide landscape phones.

The breakpoint is geometry-derived rather than a fixed aspect-ratio label. The
side-wing candidate must:

- retain at least a 240 CSS px-high 16:9 monitor; and
- provide at least 1.15 times the area of the bottom-deck monitor candidate.

Otherwise the accepted VM-0.7.2 bottom deck remains active. Portrait continues
to show `ROTATE DEVICE`; ordinary desktop does not show mobile cabinet controls.
On Web, browser width/height select the cabinet topology, while all generated
rectangles are converted once into the Godot host coordinate system. The real
game remains a fixed 1152×648 SubViewport and is uniformly displayed within the
selected Godot monitor rectangle.

## Reference geometry

All values below are CSS-reference coordinates used by the deterministic test.
Touch artwork remains contained by its larger hit target.

| Host | Layout | Monitor rect | Scale | LEFT | RIGHT | JUMP | Pause | Technician estimate |
|---|---|---|---:|---|---|---|---|---|
| 640×360 (16:9) | bottom deck | 110.222,8 / 419.556×236 | 0.364198 | 24,256 / 72×88 | 104,256 / 72×88 | 520,252 / 96×96 | 541.778,12 / 48×48 | 18.210×21.852 |
| 780×390 (18:9) | bottom deck | 155.587,8 / 468.825×263.714 | 0.406967 | 28.571,283.714 / 72×88 | 108.571,283.714 / 72×88 | 655.429,279.714 / 96×96 | 636.413,12 / 48×48 | 20.348×24.418 |
| 844×390 (19.5:9) | side wings | 200,50.375 / 500×281.25 | 0.434028 | 32,270 / 72×88 | 112,270 / 72×88 | 716,266 / 96×96 | 740,20 / 48×48 | 21.701×26.042 |
| 880×396 (20:9) | side wings | 200,43.25 / 536×301.5 | 0.465278 | 32,276 / 72×88 | 112,276 / 72×88 | 752,272 / 96×96 | 776,20 / 48×48 | 23.264×27.917 |

Against the same host's always-bottom candidate, 19.5:9 gains approximately
15.23% monitor area and 20:9 gains approximately 26.58%. At 19.5:9 the
technician estimate rises from approximately 20.22×24.26 CSS px to
21.70×26.04; at 20:9 it rises from approximately 20.68×24.82 to
23.26×27.92. These are geometry measurements, not physical-phone readability
results.

The side layout uses a 168 px left burgundy wing and a 112 px right burgundy
wing. LEFT and RIGHT occupy the lower left wing; JUMP occupies the lower right
wing. Pause remains a separate 48×48 control near the upper-right monitor/bezel,
not in the primary action cluster.

## Rendering evidence

The permanent four-layer gate passed:

1. Deterministic outer monitor, deck/wing, hit and Pause rectangles match the
   expected geometry for all four reference hosts.
2. A real `StandardSession` creates the real `StandardRun` /
   `MotionExperimentShell`, whose displayed `ViewportFrame` fills the selected
   monitor with a uniform 16:9 transform.
3. The raw `SubViewportContainer` and `InternalViewport` stay exactly
   1152×648 for every layout.
4. The exported Web build was loaded at 640×360, 780×390, 844×390 and 880×396.
   Every screenshot visibly contained the real technician, vending-machine
   environment and conveyor. Pixel smoke checks found 52–54 quantized colour
   bins and 77.5–96.8% non-near-black content in the broad gameplay crop, with
   no browser console or page errors.

Screenshots are local QA artifacts under
`builds/validation-vm074/web/`. They are not committed build inputs.

## Input and lifecycle validation

Existing VM-0.7.1/0.7.2 tests preserve LEFT, RIGHT, direction reversal, JUMP,
direction+JUMP, repeated JUMP while holding direction, focus loss,
Pause/Resume, death, Retry and orientation cleanup. VM-0.7.4 additionally
proves that switching between bottom and wing layouts releases held touch
actions, preventing stuck input.

## Performance and regression results

The existing five-seed VM071 natural profile (401, 1701, 4202, 7007, 9011)
remained within the established local bounds:

- maximum p95 step: 0.049 ms;
- maximum p99 step: 0.108 ms;
- worst simulated step: 12.827 ms;
- maximum planning event: 12.796 ms;
- zero steps above 16.67, 25, 33.33 or 50 ms; and
- all six deterministic D3 warnings present in every seed.

All 49 test scripts passed in one complete run. Standard, frozen Prototype A,
frozen Prototype B and the real responsive review scene each launched for 180
headless frames without a script/scene error.

## Build

- Preset: `Web GET CANNED VM-0.7.4 Responsive Mobile Cabinet`
- Directory: `builds/VM-0.7.4-RESPONSIVE-MOBILE-CABINET/`
- ZIP: `builds/VM-0.7.4-RESPONSIVE-MOBILE-CABINET.zip`
- ZIP SHA-256: `eb83aabab81683804a7c8c12fed23dfb033c2ae38f7fa236c8cf33bc3d1799a5`
- ZIP contains nine generated Godot files with `index.html` at archive root.

## Manual physical review

This build is ready for, but has not passed, physical mobile validation.

1. Upload the VM-0.7.4 ZIP to a private itch.io HTML project or serve it over a
   phone-compatible secure local origin.
2. On a near-16:9 landscape device/window, confirm the bottom deck remains and
   the complete real game is visible.
3. On iPhone 14 Pro- and Galaxy S25-like wide landscape devices, confirm side
   wings appear and the monitor is materially larger.
4. Hold RIGHT and repeatedly press JUMP; confirm the technician, landed cans
   and incoming hazards remain visible around the thumbs.
5. Test LEFT/RIGHT reversal, both direction+JUMP combinations, Pause/Resume,
   death, Retry, rotate out/back and browser focus loss.
6. Confirm no input remains stuck after an orientation or responsive-layout
   switch and that Pause is reachable without being mistaken for JUMP.

Remaining risks are physical safe-area behavior, thumb comfort, technician
readability on high-DPI screens, browser chrome/fullscreen differences and
sustained device pacing/thermals. Automated/browser evidence does not establish
physical acceptance.

## Evidence / decision / hypothesis / result

**Evidence:** VM-0.7.2.1 fixed the real render surface, but founder phone review
found the monitor too small when a bottom deck always consumed vertical space.
The approved study measured larger contained monitors on wide phones when
controls move to side wings.

**Decision:** Preserve the accepted bottom deck when it is the better fit; use
side wings only when the measured candidate preserves a 240 px monitor height
and gains at least 15% area. Keep gameplay and desktop behavior frozen.

**Hypothesis:** A materially larger wide-phone monitor will improve active-play
readability without sacrificing comfortable touch controls.

**Result:** Geometry, real render surface, fixed internal viewport, actual Web
pixels, browser console, performance and regression tests pass. Physical-phone
readability and comfort remain unverified.
