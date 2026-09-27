# VM-0.7.2.1 mobile monitor rendering hotfix

## Scope

VM-0.7.2.1 corrects the failed integration between the approved VM-0.7.2 mobile arcade deck and the real Standard gameplay renderer. It changes responsive presentation only. Player movement, hazards, D3, Refund Coins, score, timing, difficulty, audio and desktop gameplay are unchanged.

## Evidence and verified root cause

VM-0.7.2 passed rectangle, input, desktop and browser-start checks, but founder recordings from a Samsung Galaxy S25 and iPhone 14 Pro showed that after `CLOCK IN` the deck and controls remained visible while the gameplay monitor was missing or displaced.

Runtime inspection reproduced the architectural failure:

1. `StandardSession` resized and repositioned the outer `StandardRun` (`MotionExperimentShell`).
2. `MotionExperimentShell` refreshed its nested `SubViewportContainer` only when the root viewport emitted `size_changed`.
3. Resizing the outer Control did not require the root Window to resize, so the nested display surface could retain its old 1152×648 presentation state.
4. VM-0.7.2 also mixed browser-window CSS dimensions, device-pixel ratio, Godot host coordinates, canvas stretching and nested viewport sizing when computing the monitor.

The earlier tests falsely passed because they asserted the intended monitor rectangle and touch geometry, but did not assert the real nested render surface or rendered gameplay pixels. A correctly positioned outer rectangle therefore masked a stale or displaced inner surface.

## Rendering architecture correction

The internal gameplay invariant is permanent: **1152×648 logical pixels, 16:9**.

- `MotionExperimentShell` now listens to its own `resized` lifecycle as well as the root viewport.
- `StandardSession` explicitly requests a reflow after applying or removing the mobile monitor layout.
- The `SubViewportContainer` stays at 1152×648 with stretch disabled.
- `InternalViewport` stays at 1152×648.
- One uniform Control scale presents the authored surface inside the requested monitor; there is no crop, non-uniform stretch or collision-coordinate change.
- Layout geometry now derives from the Godot host Control. Browser `window.innerWidth`, `window.innerHeight` and `devicePixelRatio` no longer compete with Godot coordinates for gameplay layout.

Representative real-session monitor rectangles after `CLOCK IN`:

| Host | StandardRun / displayed viewport |
|---|---|
| 1152×648 (16:9) | position 198.4, 14.4; size 755.2×424.8 |
| 1404×648 (19.5:9) | position 315.0462, 13.29231; size 773.9077×435.3231 |
| 1440×648 (20:9) | position 333.0462, 13.29231; size 773.9077×435.3231 |

In every case the raw `SubViewportContainer` and `InternalViewport` remain 1152×648 and the displayed result is uniformly scaled to the tabled rectangle.

## Real-render regression surface

`res://scenes/tests/mobile_standard_monitor_review.tscn` embeds the real Standard session instead of a placeholder. Use keys `1`, `2`, and `3` for 16:9, iPhone-like 19.5:9 and Samsung-like 20:9, then press Enter to `CLOCK IN`.

`tools/capture_mobile_web.cjs` launches the exported build in a touch-enabled browser viewport, starts the real Standard run, saves a screenshot and applies a deliberately broad non-uniform-content smoke check to the monitor area. It is not screenshot-perfect matching.

Saved validation evidence (generated and ignored with builds):

- `builds/validation-vm0721/web/phone-recording-848x384.png`
- `builds/validation-vm0721/web/phone-recording-1024x464.png`
- `builds/validation-vm0721/web/samsung-like-844x390.png`

At 848×384 the monitor crop had 53 quantized color bins and 86.10% non-near-black pixels. At 1024×464 it had 53 bins and 86.54% non-near-black pixels. Both screenshots visibly contain the technician, vending-machine background, conveyor and current gameplay environment above the mobile deck. Browser console and page-error arrays were empty.

## Lifecycle and regression result

The real instantiated Standard session passes monitor-surface checks after:

- menu to `CLOCK IN`;
- Pause and Resume;
- portrait to landscape;
- Retry;
- each of 16:9, 19.5:9 and 20:9 layouts.

The tests independently assert the outer StandardRun, displayed viewport rectangle, raw container size, uniform scale, `InternalViewport` size and logical gameplay size.

Five-seed VM071 performance on the hotfix remains within the accepted tail: maximum p95 0.052 ms, maximum p99 0.129 ms, worst simulated step 12.718 ms, maximum planning 12.689 ms, and zero steps above 16.67/25/33.33/50 ms. The small difference from VM-0.7.2's recorded 12.456/12.432 ms maxima is ordinary local-run variance; no gameplay or planner code changed.

## Build and physical review

Export preset:

`Web GET CANNED VM-0.7.2.1 Mobile Monitor Hotfix`

Output:

`builds/VM-0.7.2.1-MOBILE-MONITOR-HOTFIX/index.html`

This browser evidence qualifies the build as **ready for physical mobile validation**, not mobile-validated. Final acceptance still requires founder review on the Samsung Galaxy S25 and iPhone 14 Pro.

## Permanent rendering regression rule

The durable project rule is in `AGENTS.md`: layout/viewport changes must distinguish the intended outer rectangle, actual internal render surface and actual rendered gameplay pixels. Geometry alone is insufficient; a correctly positioned empty rectangle is a failure.
