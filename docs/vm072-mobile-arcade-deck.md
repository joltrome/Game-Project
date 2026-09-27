# VM-0.7.2 Mobile Arcade Deck

Date: 2026-09-27  
Branch: `release/vm-0.7.2-mobile-arcade-deck`

## Evidence, hypothesis and decision

**Evidence:** Early overlaid mobile controls obscured gameplay. The later
compact overlays were reported too small or uncomfortable. The approved Work
study therefore treats the problem as layout competition rather than another
button-size adjustment. The founder selected its dark burgundy, hefty physical
arcade treatment.

**Hypothesis:** Moving every gameplay-control hit region and visible control
entirely below the monitor may preserve a clear view of the character, cans,
Refund Coins and incoming hazards while retaining comfortable touch targets.

**Decision:** Mobile landscape uses a proportional 16:9 gameplay monitor above
a dedicated bottom control deck. The deck contains LEFT, RIGHT and a larger
gold up-arrow action button only. Pause remains separate beside the monitor's
upper-right bezel. Desktop remains full-size. Standard gameplay, difficulty,
D3, Refund Coin behavior, audio and physics are frozen.

## Work authority and provenance

Visual authority:
`vm071_bottom_deck_refinement/HANDOFF.md` and its final 16:9/19.5:9 mockups.
The 12 final transparent PNG states were copied into
`assets/ui/vm072_mobile_deck/controls/`; runtime has no dependency on the Work
directory. They are project-created derivatives using existing project arrow
glyphs. No third-party art or font was added. See the asset-local
`PROVENANCE.md`.

## Responsive geometry

All values below are CSS-reference pixels before host-to-CSS mapping. Visible
art and touch targets are separate. All textures use nearest-neighbor filtering.

| Element | 16:9 at 640×360 | 19.5:9 at 844×390 |
|---|---:|---:|
| Gameplay monitor | `(110.222, 8, 419.556, 236)` | `(189.111, 8, 465.778, 262)` |
| Deck surface | `(8, 252, 624, 96)` | `(8, 278, 828, 96)` |
| Deck control-safe area | `(16, 252, 608, 96)` | `(24, 278, 796, 96)` |
| LEFT hit / art | `(24,256,72,88)` / `(28,268,64,64)` | `(32,282,72,88)` / `(36,294,64,64)` |
| RIGHT hit / art | `(104,256,72,88)` / `(108,268,64,64)` | `(112,282,72,88)` / `(116,294,64,64)` |
| Action hit / art | `(520,252,96,96)` / `(528,260,80,80)` | `(716,278,96,96)` / `(724,286,80,80)` |
| Pause hit / art | `(541.778,12,48,48)` / inset 8, `32×32` | `(666.889,12,48,48)` / inset 8, `32×32` |

The monitor is always 16:9 and centered above the deck without cropping or
distortion. The deck is 96 CSS px high and `#7f2634`; its seam uses `#1b2a40`.
Safe horizontal insets interpolate from 16 px at 16:9 to 24 px on the approved
wide layout. Direction art presses 6 px downward; action presses 8 px. Pause is
not inside the deck.

The calculated technician envelope is approximately 18.21×21.85 CSS px at
640×360 and 20.22×24.26 CSS px at 844×390. These are implementation facts, not
evidence of physical-phone readability.

Portrait mode hides the deck/gameplay controls and retains `ROTATE DEVICE`.
Desktop does not instantiate the mobile composition: Standard remains full-size
with its prior keyboard and Pause behavior.

## Input lifecycle

LEFT and RIGHT remain independent Godot actions with pass-by touch handling.
The action button maps to the unchanged jump action. Synthetic regression covers
both directional holds, both direction switches, jump, LEFT+JUMP, RIGHT+JUMP,
five repeated jumps while holding RIGHT, finger release, focus loss, Pause,
Resume, death, Retry and repeated-session node cleanup. Reflow and focus loss
explicitly release held actions to prevent stuck input.

## Performance and validation

VM-0.7.2 changes layout and input presentation only. It does not modify the
VM-0.7.1 planner or frame telemetry. The five-seed natural VM071 profile recorded
p95 at most 0.050 ms, p99 at most 0.134 ms, a 12.456 ms worst simulated step,
12.432 ms maximum planning and zero steps above 16.67/25/33.33/50 ms. One
earlier sequential targeted run, while other validation had just loaded the
engine repeatedly, produced a 29.332 ms planner maximum; an isolated rerun was
12.228 ms. Both recorded zero steps above 33.33 or 50 ms. This does not indicate
a layout-specific tail regression.

- Exact VM-0.7.2 geometry/input suite: passed.
- Existing VM-0.6.1, VM-0.6.2, VM-0.6.4, VM-0.7.0 and VM-0.7.1 targeted
  regressions: passed.
- Complete repository suite: 46/46 test scripts passed.
- Headless launch: Standard, Prototype A, Prototype B, Refund Chute trajectory
  review and touch-layout review passed.
- Native visual review: 16:9, 19.5:9 and 20:9 showed the approved artwork,
  monitor/deck separation and Pause placement.
- Single-threaded Web export: passed.
- Localhost browser: menu and active desktop gameplay loaded; browser console
  contained no warnings or errors during the smoke run.

The recurring native macOS system-CA diagnostic is unrelated to project parsing,
scene launch or export.

## Local review

Standard desktop launch:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  res://scenes/presentation/standard_session.tscn
```

Touch-layout review:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  res://scenes/tests/touch_layout_review.tscn
```

Use `1`, `2`, `3`, `4` for 16:9, 18:9, 19.5:9 and 20:9. Press `D` to cycle
DPR 1/2/3. Debug outlines show the monitor, deck, visible art, touch targets and
Pause; they are off in the release build.

## Web and physical-phone review

Export with preset `Web GET CANNED VM-0.7.2 Mobile Arcade Deck`. Generated Web
files belong in `builds/VM-0.7.2-MOBILE-ARCADE-DECK/` and remain ignored by Git.
For the easiest secure phone test, upload the root-level ZIP to the existing
unlisted itch.io test page. Do not open `index.html` directly.

- Web directory: `builds/VM-0.7.2-MOBILE-ARCADE-DECK/`
- Itch-ready ZIP: `builds/VM-0.7.2-MOBILE-ARCADE-DECK.zip`
- Archive: nine generated files, with `index.html` at the root
- ZIP SHA-256: `c2d4f274a8ebc2a956ec82f1dcf38ca512aa3e642b9a60193016ad51fb09d387`

For LAN HTTPS, replace the example address with `ipconfig getifaddr en0`, create
a locally trusted certificate, and ensure the phone trusts the mkcert root CA:

```sh
brew install mkcert
mkcert -install
mkdir -p /tmp/vm072-cert
mkcert -cert-file /tmp/vm072-cert/cert.pem \
  -key-file /tmp/vm072-cert/key.pem \
  192.168.0.206 localhost 127.0.0.1
python3 tools/serve_https.py \
  --directory builds/VM-0.7.2-MOBILE-ARCADE-DECK \
  --cert /tmp/vm072-cert/cert.pem \
  --key /tmp/vm072-cert/key.pem
```

Open `https://MAC_IP:8170/index.html`. Plain LAN HTTP is not a Secure Context
and cannot run this Godot Web build. Remove the temporary phone trust/profile
after testing.

Physical review checklist:

1. Landscape and monitor readability.
2. Technician, cans, Refund Coins and incoming hazards remain visible.
3. LEFT, RIGHT and gold action comfort.
4. LEFT+JUMP and RIGHT+JUMP.
5. Hold RIGHT and repeatedly press action without any control artwork covering
   gameplay.
6. Direction switching, release and no stuck input.
7. Deck reads as separate physical controls.
8. Pause beside the upper-right bezel, Resume and Retry.
9. Audio starts correctly after interaction.
10. Smoothness across several runs and phone temperature.

## Deferred and unverified

- Physical-phone thumb comfort, player readability, browser safe areas,
  multitouch policy, audio policy, compositor pacing and thermal behavior.
- The observed camp-below-chute → chase → return strategy. A future controlled
  experiment may retain one chute while varying player-relative destinations;
  VM-0.7.2 does not change targeting.
- A second chute, Standard difficulty tuning, Endless/Overload, new items and
  progression.
- Side-wing controls, retained only as a fallback if the bottom deck fails the
  physical monitor-readability gate.
