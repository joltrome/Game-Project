# Audio source inventory

**Current RC1:** untouched non-fade master accepted and integrated; temporary MP3 excluded from RC1 export. All A/B/C candidates rejected. See [native investigation and exact settings](vm061-original-wav-investigation.md). Earlier entries below remain historical records.

Recorded: 2026-09-08. No stock, generated, purchased, or placeholder SFX used.

## Founder-selected V1 SFX — VM-0.6.3

Recorded: 2026-09-12. The eight local files supplied by the founder were copied byte-for-byte into `assets/audio/sfx/masters/`. They are 48 kHz, stereo, signed 16-bit PCM WAVs. Godot imports the masters and derivative losslessly; the Web release includes only project-local files and performs no network audio fetch.

| Master | Runtime event | Duration | SHA-256 |
|---|---|---:|---|
| `CoinRefund1.wav` | Refund Coin pickup (via derivative below) | 0.891688 s | `cd2f783815ac8ae304d380fc9520b86029bab725be08ded030769e30bf852e81` |
| `Jump1.wav` | Accepted jump | 2.307688 s | `8b4a78b15ee297be30cb6a3346f75ff57d17e551c51cd6c5187dfa38256fc0c8` |
| `Drop1.wav` | Airborne-to-grounded landing | 2.307688 s | `223d8eebedf35c6bcef8315aec90995fa40c8f391519b5936fe643c8253cd6dd` |
| `CanDrop1.wav` | Product's landed transition | 0.527604 s | `007ae1e6255eee4277267b195f1e7d5a911b17cd9bc0f45f9415d5c1fc484402` |
| `WarningSound1.wav` | Preserved unused candidate; removed from carriage-warning runtime after founder listening | 1.683396 s | `1def6901eb79f40b8a86bfe370ff1a70df4e39a8345c2e77ad914c94bad09a65` |
| `DeathSound1.wav` | First impact death only | 0.500042 s | `6bedd8a26ee32dbfef5f6436e4118dcf17e9b242636937183ee4f263c466e647` |
| `ClockInUiConfirm1.wav` | CLOCK IN / run start | 0.278333 s | `d37a14c4bcca6bf825d36090f3f158104f6371db73722873a0b9b45e67ec3769` |
| `ClockedOut1.wav` | Genuine 60-second completion | 1.880625 s | `31905b2b6b86c96802ce68dfe225d65f9ce8bb0a30a8eebc76ce718f376c36e9` |

The source location at integration time was `/Users/jeromenicholaz/Downloads/`; it is not a runtime dependency and was not committed. Startup Lab describes these sounds as founder-created/selected masters. No replacement, download, synthesis, normalization, resampling, or creative processing was performed.

### Refund Coin runtime derivative

`assets/audio/sfx/runtime/CoinRefund1_trimmed.wav` is the sole derived SFX. The reproducible tool `tools/audio/create_vm063_coin_refund_trim.py` verifies the master hash/format, discards exactly the first 8,126 stereo frames (169.291667 ms), and copies every remaining PCM frame unchanged. It begins at source stereo sample values `[-2, 1]`, a reviewed near-zero crossing, leaving approximately 3.60 ms before the measured -40 dBFS onset. It contains 34,675 frames, lasts 0.722396 seconds, and has SHA-256 `92e8ca71cfb2fedf1d70a7d9abce1255656d43f49b7d58ec66327c2182c77378`. There is no fade, gain change, filtering, resampling, compression, or overwrite of the master.

## Miraie — historical RC0 temporary main theme

- Working filename: `2026 09 03 miraie joltrome VENDING MACHINE BGM demo v2.mp3`.
- Composer: **Miraie**; supplied directly by the composer to the founder, composed specifically while watching **Vending Machine Survival**.
- Original supplied file: `/Users/jeromenicholaz/Downloads/2026 09 03 miraie joltrome VENDING MACHINE BGM demo v2.mp3` (preserved unchanged).
- Runtime: `res://assets/audio/miraie_main_theme_TEMPORARY_DEMO.mp3`.
- Status: **TEMPORARY COMPOSER DEMO**, not a final production loop.
- Permission evidence: founder reports composer replied “of course bro!! i made this for you” when asked to use it as the main theme. This milestone's temporary runtime integration is authorized by the founder.
- Explicit commercial-use confirmation: **pending**. Do not describe the demo as commercially cleared on this evidence alone.
- Credit: **Miraie** provisionally displayed; preferred final credit name pending composer confirmation.
- Modifications/conversions: filename change and byte-for-byte copy only; standard Godot MP3 import. No trimming, remastering, conversion, reconstruction, or speculative loop edit.
- Original and runtime SHA-256: `6d5fe498d000d2d0aff5fea232b3ec9b007da89908b9598d094324c61e5ca001`.
- Size: 4,361,338 bytes; browser-decoded duration approximately 109.032 seconds.
- Demo behavior: play through **once per application/page session**, including its quiet/faded ending. Menu, Play, results, Retry and menu return never restart it. After it ends, music stays silent until a fresh launch. Mute changes gain only, not play position.
- The soda/can-opening sound is part of the composition; it is not a gameplay SFX trigger.

## Final asset swap

1. Obtain composer commercial-use confirmation, preferred credit, lossless master WAV, explicit seamless-loop WAV/OGG, BPM and exact loop point/bar (optional stems).
2. Keep the lossless master as a production source outside the Web payload when a suitable compressed OGG runtime export is supplied.
3. Add the approved seamless asset under `assets/audio/`. Set its Godot import loop option to the composer's exact intended behavior; verify the boundary by listening.
4. Change **Audio → music_stream** in `scenes/presentation/standard_session.tscn` to that resource. The menu and gameplay lifecycle require no changes.
5. Remove the superseded demo from the shipped resource set once no longer required, update this inventory with hashes/permission evidence and repeat Web start/mute/retry/loop QA.

### Founder listening correction

`WarningSound1.wav` is **rejected from Standard runtime due repetition/fatigue and masking of other audio**. Its bytes, lossless Godot import and provenance remain preserved, but `standard_session.tscn` no longer maps it and the carriage warning no longer emits an SFX request. Carriage timing and the visual warning are unchanged. The other seven active mappings and gains remain as recorded in [the VM-0.6.3 report](vm063-audio-pass.md).

The earlier application-global music lifecycle was also rejected by ear. The accepted Miraie WAV and loop are unchanged, but runtime ownership is now per run: silent Menu/Credits/Results, position-zero start after CLOCK IN, preserved playhead through Pause, stop on outcome, and position-zero Retry.

### VM-0.6.4 pre-external adjustments

The Jump runtime gain changed from **+6 dB to +10 dB** after founder listening found it masked. `Jump1.wav` remains byte-identical; all other per-event gains remain unchanged. `ClockInUiConfirm1.wav` now confirms actual CLOCK IN, CREDITS, BACK, Pause/RESUME, RETRY and MENU activations once, with no hover/focus playback. Finishing a changed SFX-slider adjustment may play one preview at the selected level.

Independent persistent Music/SFX sliders replace the prior booleans. Their 0–100% linear master scale layers over existing music-state and per-event gains: 0% mutes and 100% retains the authored reference. Recognized old OFF/ON preferences migrate to 0/100. The accepted run-owned Miraie lifecycle, Pause ducking, outcome fades, source content and loop point remain unchanged.

## Future SFX slots

`SessionAudio.sfx_streams` currently has seven Standard mappings: `coin_pickup`, `jump`, `landing`, `product_impact`, `clock_in_confirm`, `player_death`, and `round_complete`. `request_sfx()` emits passive instrumentation for local testing and only plays events with supplied resources. No files are fetched or synthesized. The shared confirm is now used for actual ordinary UI activations. Unmapped passive seams include rack warning/release, carriage sweep and final seconds; carriage warning is deliberately disconnected rather than emitted into an empty player.

All future third-party SFX need source, author, license, permission, modifications and runtime-path records before integration. Sourcing and mix approval belong to a later authorized milestone.

## 2026-09-09 — non-fade master received; loop not accepted

The supplied non-fade master is now locally verified at `/Users/jeromenicholaz/Downloads/2026 09 08 miraie joltrome VENDING MACHINE BGM fade-wav/2026 09 08 miraie joltrome VENDING MACHINE BGM.wav`. Miraie / 104 BPM / C Major / 8B is composer metadata reported by Startup Lab. Stereo 48 kHz float32 PCM, 94.6454375 seconds, 36,343,964 bytes. SHA-256: `1e12cc678e944c2ea1aa560653c1c07e3b26a1dbdd9dfead40d3deced3b391d4`. Original preserved unchanged.

Technical inspection found approximately 30.167 ms of trailing silence. The founder heard a gap/click in repeated source boundary excerpts and requested return to Startup Lab. RC1 was stopped under its explicit audio-seam gate. Local FFmpeg lacks libvorbis; the attempted high-quality direct WAV conversion produced no OGG. The temporary MP3 and playback behavior remain unchanged. No musical trim, crossfade or runtime master swap was made. See [RC1 stop report](vm061-rc1-audio-stop.md) for exact measurements, the distinction between audition and runtime validation, and the request for composer-confirmed loop material. This receipt does not establish new commercial permission or a preferred final credit name.

## 2026-09-09 — authorized derived-loop experiment

Startup Lab authorized a separate 41-bar trim and minimal seam experiment. [A/B report](vm061-derived-loop-experiment.md): A retains 4,541,538 original frames; B adds a 96-frame/2 ms raised-cosine offset correction at the start while retaining identical duration. Original source remains unchanged; both candidates passed three continuous native Godot mixer wraps. Listening selection is pending. Candidates stay under ignored `builds/audio-loop-experiment-vm061/`; neither has replaced the runtime demo or been converted to OGG.

## 2026-09-09 — A/B rejected; Candidate C for listening

Startup Lab rejected the 41-bar A/B restart perceptually and authorized the [40-bar Candidate C experiment](vm061-candidate-c-loop.md). Exact C retains frames [0,4430769); a bounded ±2 ms waveform comparison supplies an optional endpoint at 4430863 (+1.958 ms). Both preserve the original non-fade PCM prefix without sample editing or fades, and both passed three native Godot mixer wraps. Repeated previews contain three joins with four-bar context. Human musical approval is pending; if C remains wrong, stop for manual/composer loop markers. Originals and runtime demo remain unchanged.

## 2026-09-09 — original master accepted, RC1 integration

Founder validated original → original in Audacity, then accepted the corrected native Godot capture by ear and authorized RC1. Runtime source: `res://assets/audio/miraie_main_theme_ORIGINAL_MASTER.wav`, byte-identical SHA-256 `1e12cc678e944c2ea1aa560653c1c07e3b26a1dbdd9dfead40d3deced3b391d4`. Full 4,542,981-frame /94.6454375-second loop, original export tail retained; no trim/fade/crossfade/A/B/C. Godot PCM16 import at48kHz; in-memory four-byte first-frame decoder guard, unchanged loop endpoint; explicit STREAM. One persistent music player, no end callback restart. No OGG; no paid service. This technical/music acceptance adds no new commercial-rights claim beyond existing founder-provided permission evidence. See the linked investigation and RC1 report.
