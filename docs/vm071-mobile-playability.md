# VM-0.7.1 Mobile Playability and Frame Pacing

Date: 2026-09-20  
Branch: `release/vm-0.7.1-mobile-playability`

## Evidence, hypothesis, and decision

**Evidence:** The founder and a second player independently reported that the
VM-0.7.0 phone controls obscured bottom-screen gameplay and that the itch Web
build occasionally appeared to hitch. VM-0.7.0 used the complete 72×72 LEFT and
RIGHT hit regions and 96×72 JUMP region as opaque artwork; pressed fill rose to
72 percent. Its Web layout also divided overlay scale by devicePixelRatio with
no clamp. Fresh profiling found that VM-0.7.0's slowest optional-coin events
made up to 1,008 placement attempts. Candidate generation consumed 33–40 ms of
the measured 35–48 ms tail; combination search was at most about 1.2 ms.

**Hypothesis:** Compact low-opacity visuals over generous independent hit areas,
adaptive gutter placement, CSS-viewport sizing, and a deterministic total
operation budget for optional coin planning may remove the two mobile-test
contaminants without changing gameplay.

**Decision:** Preserve Standard difficulty, D3, player/conveyor/hazard behavior,
the complete VM-0.7.0 Refund system, event weights, cadence and score. Apply the
planning budget only in VM-0.7.1. Optional rewards may degrade or skip before
hazard work is delayed. Do not upload, merge, tune difficulty, or add gameplay.

## Touch layout

Hit regions and rendered artwork are now independent:

| Control | Hit region (CSS target) | Visible artwork |
|---|---:|---:|
| LEFT | 68×78 | 38×38 |
| RIGHT | 68×78 | 38×38 |
| JUMP | 86×92 | 50×50 |
| Pause | 48×48 | 32×32 |

Control backgrounds use 12 percent opacity while idle and 32 percent while
pressed. Outlines use 55 and 90 percent respectively. Pressing therefore gives
feedback without turning the full hit region opaque. L/R/JUMP labels stay
compact and ASCII-safe.

Sizing uses:

`logical_per_css = clamp(min(host_width / CSS_width, host_height / CSS_height), 0.70, 1.80)`

The Web path reads `window.innerWidth`/`innerHeight`, so DPR is not multiplied
into visual size. DPR is clamped to 1–3 only for the fallback when CSS viewport
dimensions are unavailable. This replaces VM-0.7.0's unbounded DPR division.

Fourteen CSS pixels of configurable edge padding protects controls from common
browser and gesture edges. Godot Web does not expose a reliable cross-browser
cutout safe area here; this conservative padding is the documented limitation.
Desktop keeps the prior 8 px Pause position.

When both horizontal gutters are at least 48 CSS pixels, visible controls are
placed entirely in the gutters while their larger invisible hit regions extend
toward the thumb area. Near 16:9, compact visuals use the outermost edges and
remain outside the central player/hazard region. Gameplay is not shifted,
cropped, or reduced.

## Frame-pacing telemetry

VM-0.7.1 accumulates samples without per-frame logging and prints one
`VM071_FRAME_SUMMARY` at death, completion, or active-run restart. It includes:

- median, p95, p99 and worst frame time;
- frame counts over 16.67, 25, 33.33 and 50 ms;
- average/maximum process and physics time and approximate FPS;
- planning average/maximum and planning counts above 8, 16.67, 33.33 and 50 ms;
- slow-frame proximity to coin planning, D3 release and support-on-can entry.

Coin planning events retain timestamp, request/delivery size, placement and
trajectory counts, D3 state, and candidate/combination/fallback phase duration.
Only new planning records are copied into frame telemetry; the full log is not
duplicated every frame.

## Confirmed slow path and correction

The measured culprit was candidate generation. A configured 12-attempt search
was previously allowed 12 attempts for each of three side preferences, then
repeated for every six-member candidate pool. A failed group plus final single
could reach 1,008 attempts.

VM-0.7.1 interprets the attempt limit as a total search budget across all side
preferences. Its release-only bounds are eight attempts per group-member
sample, at most eight pool calls for the six desired samples, and 24 attempts
for the final single fallback. The deterministic maximum observed/covered is
216 attempts for an event. Search ordering and correctness remain deterministic;
wall-clock time is measurement only.

## Deterministic comparison

Fresh VM-0.7.0 control measurements reproduced the same tail shape: slowest
five-seed planning reached 48.298 ms, up to 1,008 attempts, while candidate
generation dominated the event. In the three-seed phase profile, candidate
generation reached 38.975 ms and combination search remained at or below
1.144 ms.

VM-0.7.1 five-seed natural results (401, 1701, 4202, 7007, 9011):

- 275 requested / 185 delivered;
- 36/61 complete doubles (59.0 percent);
- 1/18 complete triples (5.6 percent);
- maximum planning approximately 12.1 ms across repeated validation runs;
- zero planning/frame steps over 16.67, 25, 33.33 or 50 ms in the final gate;
- p95 step 0.044–0.047 ms and p99 step 0.080–0.090 ms;
- worst simulated step approximately 12.1 ms;
- all six natural D3 warnings preserved at approximately 8.50, 17.04, 24.61,
  33.40, 40.60 and 48.36 seconds, with no coin-caused delay.

The first three VM-0.7.1 runs delivered 109/161 requested, compared with the
recorded VM-0.7.0 three-run 112/170. The planner therefore did not materially
lower availability. Double integrity improved in this sample; triple integrity
remains non-zero but sparse and is not claimed as balanced.

The artificial three-landed-can stress fixture reached approximately 13.8 ms
maximum planning with zero steps over 16.67/25/33.33/50 ms. Its D3 delays remain
an intentional fixture artifact caused by injected overlapping cans, not a
natural scheduling result.

These native deterministic timings identify and remove the known synchronous
game-code tail. They do not prove physical-phone rendering, browser compositor,
thermal, or itch.io performance.

## Validation

- VM-0.7.1 touch, telemetry, planner and D3 targeted suite: passed.
- VM-0.7.0 Refund-system regression: passed unchanged.
- VM-0.6.1 input and multitouch regression: passed.
- VM-0.6.2 Pause/touch regression: passed.
- VM-0.6.4 presentation/touch regression: passed.
- Full repository suite: 45/45 test scripts passed.
- Headless launch validation: Standard Mode, touch-layout review, Prototype A,
  and Prototype B all launched without script or scene errors. The recurring
  macOS system-CA diagnostic did not prevent launch or export.
- Single-threaded Web export: passed. `index.html` is at the ZIP root.
- Local Chromium Web run: menu, gameplay and death/results flow passed with no
  browser-console warnings or errors. Its death summary reported median/p95/p99
  8.333 ms, worst 31.553 ms, one frame over 25 ms, zero frames over 33.33 or
  50 ms, and planning maximum 5.0 ms.
- Physical-phone thumb occlusion, touch comfort and device frame pacing remain
  intentionally unverified pending founder review.

## Build artifacts

- Web directory: `builds/VM-0.7.1-MOBILE-PLAYABILITY/`
- Itch-ready ZIP: `builds/VM-0.7.1-MOBILE-PLAYABILITY.zip`
- ZIP SHA-256: `2c7ea0ecfc1710051dc53b31714a503b79e5941a95adf10141afca4c10d74ffd`
- Archive contents: nine generated Web files with `index.html` at the archive
  root; generated artifacts remain ignored by Git.

## Local testing

Normal Standard launch:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  res://scenes/presentation/standard_session.tscn
```

At death, completion, or an active-run restart, copy the
`VM071_FRAME_SUMMARY` and `VM070_COIN_SUMMARY` console lines.

Touch-layout review:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  res://scenes/tests/touch_layout_review.tscn
```

Use `1`–`4` for 16:9, 18:9, 19.5:9 and 20:9. Press `D` to cycle DPR 1/2/3.
Cyan shows the complete touch hit region; gold shows the much smaller visible
artwork.

Native deterministic profile:

```sh
/Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter \
  --script res://tests/profile_vm069_performance.gd -- \
  --mode=VM071 --natural --five-seeds
```

Desktop Web review after export:

```sh
python3 -m http.server 8170 --bind 127.0.0.1 \
  --directory /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter/builds/VM-0.7.1-MOBILE-PLAYABILITY
```

Open `http://127.0.0.1:8170/index.html`. Localhost receives the browser secure-
context exception. A phone opening a LAN `http://192.168…` URL does not.

## Physical-phone HTTPS

The simplest secure phone test is the founder's existing unlisted itch.io page.
For a true LAN comparison, install `mkcert`, create a certificate that includes
the Mac's LAN address, install/trust the mkcert root CA on the test phone, then
use the repository's HTTPS helper. Do not commit certificates or keys.

```sh
brew install mkcert
mkcert -install
mkdir -p /tmp/vm071-cert
mkcert -cert-file /tmp/vm071-cert/cert.pem \
  -key-file /tmp/vm071-cert/key.pem \
  192.168.0.206 localhost 127.0.0.1
python3 tools/serve_https.py \
  --directory builds/VM-0.7.1-MOBILE-PLAYABILITY \
  --cert /tmp/vm071-cert/cert.pem \
  --key /tmp/vm071-cert/key.pem
```

Replace `192.168.0.206` with `ipconfig getifaddr en0`. The phone must trust the
mkcert root CA before opening `https://MAC_IP:8170/index.html`; remove that
temporary trust/profile after testing. If certificate setup is undesirable,
use itch.io HTTPS instead. A plain LAN HTTP server cannot run this Godot build.

## Remaining risks

- Automated geometry and synthetic touch events do not prove thumb comfort.
- Physical-phone multitouch, safe-area behavior, compositor pacing, audio policy,
  and thermal behavior remain unverified until the founder retests.
- Native deterministic p99 is low because planning spikes are rarer than one
  percent; worst time and >33/>50 counts remain the primary gate.
- The visible control correction is technical, not evidence that every phone
  aspect or browser feels ideal.
