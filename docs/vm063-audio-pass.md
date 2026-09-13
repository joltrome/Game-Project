# VM-0.6.3 — audio integration and founder-listening correction

Recorded: 2026-09-12

> Historical checkpoint note: VM-0.6.4 later raises only Jump from +6 dB to +10 dB, maps the existing confirm sound to ordinary actual button activations, and replaces binary Music/SFX settings with independent persistent 0–100% sliders. The VM-0.6.3 values below remain the factual record of this checkpoint.

Branch: `release/vm-0.6.3-audio-pass`

Accepted gameplay base: `699f9ed4080a0e955357793eb58fd1ba38d37eb0`

Original audio candidate before correction: `2ac502cfd7e4149417c929cfe4460ab48ffb1050`

## Scope and baseline synchronization

The accepted VM-0.6.2 typography checkpoint was a clean true descendant of the stale remote `master`. `master` was fast-forwarded without a merge commit or force push and verified at `699f9ed4080a0e955357793eb58fd1ba38d37eb0`. Audio work remains isolated on `release/vm-0.6.3-audio-pass`; it is not merged into `master`.

Frozen Standard gameplay, C2 screens, UI layout, typography, death presentation, Pause mechanics, touch controls, settings, score, timer, collisions, Miraie's source/loop point, and all movement/hazard/director values remain unchanged.

## Evidence and decisions

Founder gameplay listening rejected two parts of the first VM-0.6.3 candidate:

- `WarningSound1.wav` was distracting and repetitive at the existing carriage-warning cadence, creating fatigue and masking other audio. Decision: preserve the master and provenance but remove it from the Standard runtime mapping; the unchanged visual warning is sufficient.
- Screen-level gain changes around one application-global Miraie playhead still sounded like the OST marched continuously through Menu, run outcomes, and Results. Decision: Miraie's OST is run-owned and represents the technician being clocked in.

This listening evidence supersedes the earlier global-continuous-playhead decision. It does not authorize other SFX changes or broader audio redesign.

## Source and derivative handling

All eight founder-supplied WAVs remain byte-identical in `assets/audio/sfx/masters/`, including rejected `WarningSound1.wav`. Exact hashes and durations are in [audio-source-inventory.md](audio-source-inventory.md). Godot imports the SFX losslessly.

The only SFX derivative remains `CoinRefund1_trimmed.wav`: exactly 8,126 frames / 169.291667 ms are removed from the beginning. The new first stereo sample is `[-2, 1]`, leaving approximately 3.60 ms before the measured -40 dBFS onset. Every retained PCM frame is unchanged; there is no fade, gain, normalization, resampling, filtering, or compression.

## Final runtime architecture

`SessionAudio` owns one reusable Miraie `AudioStreamPlayer`, one fixed run-start `Timer`, and 12 reusable SFX voices. It never creates a new music player on CLOCK IN or Retry.

Music lifecycle:

1. Menu and Credits keep the music player stopped.
2. CLOCK IN plays its SFX and starts gameplay immediately; it does not delay input, physics, timer, or presentation.
3. A real-time deadline enforces a configurable 0.20-second quiet separation, then the existing music player starts Miraie's accepted OST at position 0 with the existing gameplay reference gain.
4. Pause keeps the same playhead running and moves its gain to -12 dB over 0.18 seconds. Resume restores 0 dB over 0.18 seconds without seeking or restarting.
5. Death and successful completion fade the run player toward -80 dB over 0.10 seconds, then call `stop()`. Results stay silent.
6. Retry cancels any pending/fading prior-run state, plays CLOCK IN once, observes a new 0.20-second gap, and starts the same music player from position 0.
7. Results → Menu and Menu → Credits remain stopped.

Music OFF/ON remains a Music-bus mute. During a run, OFF does not pause or reset the underlying playhead; ON reveals the same run position. On silent screens it cannot start music. SFX mute remains independent.

## Active SFX mapping

All gains are configurable and unchanged from the first candidate.

| Runtime event | File | Gain |
|---|---|---:|
| Refund Coin collected exactly once | `CoinRefund1_trimmed.wav` | -8 dB |
| Accepted jump | `Jump1.wav` | +6 dB |
| Genuine airborne-to-grounded landing | `Drop1.wav` | +2 dB |
| Product enters landed state | `CanDrop1.wav` | -3 dB |
| CLOCK IN / run start | `ClockInUiConfirm1.wav` | 0 dB |
| First impact death | `DeathSound1.wav` | -6 dB |
| Genuine 60-second completion | `ClockedOut1.wav` | +2 dB |

`WarningSound1.wav` is preserved but unreferenced by the Standard scene and has no carriage-warning hook or gain entry. OUT/VENDED intentionally has no impact-death sound. No other SFX was added.

## Technical validation

- Corrected audio-focused test: **36/36 checks passed**. It covers the eight hashes, sample-exact coin derivative, seven active mappings, silent Menu/Credits/Results, CLOCK IN cardinality, measured run-start delay, position-zero start/Retry, Pause/Resume continuity, outcome fades, carriage-warning silence, independent toggles, player-event cardinality, one reusable music player, one delay timer, fixed SFX pool, timer-zero race, and frozen representative gameplay values.
- Presentation/audio lifecycle regression: passed, including 12 fast death/Retry cycles and a natural deterministic 60-second completion.
- Single full regression run: **36/36 scripts passed**.
- Configured Standard entry scene: launched headlessly for 180 frames with exit code 0.
- Corrected single-threaded Web export: succeeded at `builds/VM-0.6.3-AUDIO-CORRECTION/index.html`.
- Export inspection: no `WarningSound1.wav` resource was packed.
- Local browser: Menu and Gameplay loaded; all generated resources returned HTTP 200 and the warning/error console stayed empty.
- ZIP: `builds/VM-0.6.3-AUDIO-CORRECTION.zip`, with `index.html` and its generated siblings at archive root.

Godot's sandboxed headless process reported the known macOS system-CA diagnostic and some non-failing test teardown resource/object warnings. No parser, scene-launch, export, browser, or test failure remained.

## How to test locally

1. In Terminal:

   ```sh
   cd /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter
   /Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --editor project.godot
   ```

2. Press **F5**. If launching only the scene, open `scenes/presentation/standard_session.tscn` and press **F6**.
3. Controls: **A/D or Left/Right** move, **Space/W/Up** jump, **Esc/P** pause, **R** restart.
4. Expected music sequence:
   - Menu: silence.
   - Credits: silence.
   - CLOCK IN: confirmation SFX, immediate gameplay, approximately 0.20 seconds of quiet, then Miraie from the beginning.
   - Gameplay: music at the accepted reference level.
   - Pause: same playhead continues quietly at -12 dB; Resume restores it without restarting.
   - Death: music fades/stops in approximately 0.10 seconds; impact SFX and KO continue; Results are silent.
   - Retry: fresh CLOCK IN and quiet gap, then Miraie restarts from the beginning.
   - CLOCKED OUT: music fades/stops in approximately 0.10 seconds while the completion SFX plays; Results are silent.
   - Results → Menu → Credits: silence.
5. To check carriage warning removal, play until the horizontal retrieval carriage's existing visual warning appears. The warning must remain visually unchanged and produce no warning sound.
6. Also exercise Refund Coin, jump/landing, landed can, impact death, OUT, Music OFF/ON, and SFX OFF/ON. The other seven active effects should retain their first-candidate gains.

For the corrected Web build, run `python3 -m http.server 8000 --directory builds/VM-0.6.3-AUDIO-CORRECTION` from the repository and open `http://127.0.0.1:8000/`. Browser audio requires an initial click/key interaction. Final subjective loudness, musical timing, fatigue, and device translation require founder listening.
