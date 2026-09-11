# VM-0.6.3 — SFX integration and reactive music pass

Recorded: 2026-09-12

Branch: `release/vm-0.6.3-audio-pass`

Accepted base: `699f9ed4080a0e955357793eb58fd1ba38d37eb0`

## Scope and baseline synchronization

The accepted VM-0.6.2 typography checkpoint was clean, was a true descendant of the stale remote `master`, and was 34 commits ahead / 0 behind. `master` was fast-forwarded without a merge commit or force push and the GitHub reference was verified at exactly `699f9ed4080a0e955357793eb58fd1ba38d37eb0`. This audio work was then isolated on `release/vm-0.6.3-audio-pass`; it is not merged into `master`.

Frozen Standard gameplay, C2 screens, UI layout, typography, death presentation, Pause, touch controls, settings, score, timing, collisions, Miraie's source/loop point, and all movement/hazard/director values remain unchanged.

## Source and derivative handling

All eight founder-supplied WAVs are preserved byte-identically in `assets/audio/sfx/masters/`. Exact hashes and durations are recorded in [audio-source-inventory.md](audio-source-inventory.md). Godot imports the SFX as lossless PCM16.

The only runtime edit is `CoinRefund1_trimmed.wav`: exactly 8,126 frames / 169.291667 ms are removed from the beginning. The new first stereo sample is `[-2, 1]`, leaving approximately 3.60 ms before the measured -40 dBFS onset. Every retained source byte is unchanged; there is no fade, gain, normalization, resampling, filtering, or compression. The deterministic generator verifies the master hash and exact output.

## Runtime architecture

`SessionAudio` owns one continuous Miraie `AudioStreamPlayer` on the `Music` bus and a fixed pool of 12 reusable one-shot players on the `SFX` bus. Screen transitions change only the music player's gain; they never seek, restart, replace, trim, or crossfade the accepted music. Retry stops any unfinished SFX in that fixed pool before playing the new clock-in confirmation, so old outcome audio does not bleed into the next run and no nodes accumulate.

`Player` exposes passive `jump_accepted` and `landed` signals at the already-existing state transitions. They do not change movement calculations. `StandardSFXHooks` subscribes to those signals and to existing coin, product-landed, and carriage-warning signals. Gameplay-event playback is disabled immediately after death/completion, suppressing late jump, landing, coin, or product sounds.

### Event mapping and initial gain

All gains are configurable and relative to the SFX bus.

| Runtime event | File | Gain |
|---|---|---:|
| Refund Coin collected exactly once | `CoinRefund1_trimmed.wav` | -8 dB |
| Accepted jump | `Jump1.wav` | +6 dB |
| Genuine airborne-to-grounded landing | `Drop1.wav` | +2 dB |
| Product enters landed state | `CanDrop1.wav` | -3 dB |
| Existing carriage danger-warning cue | `WarningSound1.wav` | +12 dB |
| CLOCK IN / run start | `ClockInUiConfirm1.wav` | 0 dB |
| First impact death | `DeathSound1.wav` | -6 dB |
| Genuine 60-second completion | `ClockedOut1.wav` | +2 dB |

OUT/VENDED intentionally has no impact-death sound. There are no additional UI, final-countdown, rack, product-release, carriage-sweep, or menu-navigation SFX in this milestone.

### Music states

Levels are relative to the accepted gameplay music level. Existing audio-bus settings remain the base mix.

| State | Relative gain |
|---|---:|
| Gameplay | 0 dB |
| Main Menu | -6 dB |
| Credits | -8 dB |
| Pause | -12 dB |
| Results | -7 dB |
| Death/completion duck | -15 dB |

Normal screen ramps are 0.25 s; Pause transitions use 0.18 s. Outcome duck-in is 0.10 s. Completion holds the duck for 0.35 s and settles to Results over 0.25 s. Impact death remains ducked during the existing 0.75-second KO beat, then the Results transition settles normally.

## Verification contract

Targeted automation covers the eight byte-identical masters, sample-exact Refund Coin derivative, buses, pool identity, event cardinality, real jump/landing transitions, overlapping impacts, warning mapping, impact-vs-OUT death mapping, timer-zero success race, independent mute controls, state gains, continuous music instance/start count, ten Retry cycles, and representative frozen movement/conveyor values.

### Validation results

- Audio-targeted check: **33/33 checks passed**.
- Full real-time regression suite: **36/36 scripts passed** in the single requested run.
- Configured Standard entry scene: launched headlessly for 180 frames with exit code 0.
- Web preset: `Web GET CANNED VM-0.6.3 Audio`, single-threaded (`variant/thread_support=false`), exported successfully.
- Web build: `builds/VM-0.6.3-AUDIO-PASS/index.html`.
- ZIP: `builds/VM-0.6.3-AUDIO-PASS.zip`, with `index.html` and its generated sibling files at archive root.
- Local browser: Menu and Gameplay loaded through localhost; browser warning/error console was empty before and after CLOCK IN.
- Environment-only diagnostics: Godot could not query the macOS system CA store or save editor settings from its sandboxed headless process; the scene, tests, and export nevertheless returned success. Known test teardown resource/object warnings remain non-failing.

Subjective balance—latency, perceived loudness, fatigue, masking, and whether each sound suits the action—cannot be approved by automated, headless, or silent browser inspection and remains founder listening work.

## How to test locally

1. In Terminal, run:

   ```sh
   cd /Users/jeromenicholaz/Documents/GameProject/vending-machine-survival-starter
   /Users/jeromenicholaz/Downloads/Godot.app/Contents/MacOS/Godot --editor project.godot
   ```

2. Press **F6** only if `scenes/presentation/standard_session.tscn` is open, or press **F5** to launch the configured Standard build.
3. Controls: **A/D or Left/Right** move, **Space/W/Up** jump, **Esc/P** pause, **R** restart. Touch controls remain available on supported landscape devices.
4. Listen in this order: Menu music → CLOCK IN → repeated jump/land → landed can → Refund Coin → carriage warning → impact death → Retry → Pause/Resume → survive to CLOCKED OUT → Results → Retry → Results/Menu → Credits/Menu.
5. Expected: one sound per actual event; landing is subtler than jump; impacts may overlap without cutting one another off; OUT has no impact-death cue; post-death gameplay is silent; music moves smoothly between levels without restarting; Music and SFX toggles remain independent; Retry begins cleanly.

For the generated Web build, from the repository run `python3 -m http.server 8000 --directory builds/VM-0.6.3-AUDIO-PASS`, then open `http://127.0.0.1:8000/`. Browser audio begins after the first click/key interaction. Final loudness and artistic fit require human listening on representative speakers/headphones; Codex cannot certify them subjectively.
