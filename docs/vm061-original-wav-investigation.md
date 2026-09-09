# VM-0.6.1 — original WAV loop investigation

2026-09-09 JST. **Audio gate passed.** Startup Lab validated the untouched original in Audacity. The founder then listened to the corrected native Godot capture and answered: “Yes — matches cleanly; resume RC1”. A/B/C and all alternate trimmed endpoints are rejected permanently for this milestone.

## Source and reference

- Original: `/Users/jeromenicholaz/Downloads/2026 09 08 miraie joltrome VENDING MACHINE BGM fade-wav/2026 09 08 miraie joltrome VENDING MACHINE BGM.wav`.
- Miraie; reported metadata: 104 BPM, C Major, Camelot 8B.
- Stereo float32, 48 kHz; **4,542,981 frames, 94.6454375 s**, 36,343,964 bytes.
- Original and repository byte-copy SHA-256: `1e12cc678e944c2ea1aa560653c1c07e3b26a1dbdd9dfead40d3deced3b391d4`.
- Audacity reference: `/Users/jeromenicholaz/Downloads/2026 09 08 miraie joltrome LoopedVENDING MACHINE BGMLooped.wav`; 9,085,962 frames, exactly two original durations; SHA-256 `94ccc1c9d18273751e480b692427bd74bae2cc3ad89f1f56294358dcb46420fd`.
- The supplied reference is a different PCM encoding/quantization, so it is human listening evidence rather than a byte-exact numerical oracle. The numerical comparison uses the engine-imported original PCM concatenated directly.

The approximately 30 ms export tail is retained. Its presence alone did **not** establish a defective musical loop. Earlier boundary excerpts and A/B/C musical edits did not test the required full-file native playback. The prior source-defect/phrase-boundary hypotheses are superseded by the founder's end-to-end listening evidence.

## Isolation and findings

Engine: Godot **4.7.1 stable**, `a13da4feb8d8aefc283c3763d33a2f170a18d541`.

| Path | Observation | Decision |
|---|---|---|
| Audacity original → original | Founder reports seamless, no processing | Authoritative musical boundary is full file → frame 0 |
| Default WAV import | QOA compression, loop detection/default rather than explicit full-file forward loop | Explicit uncompressed PCM import and endpoints |
| Native full-file WAV, unguarded | One incorrect decoded stereo frame per wrap; no extra 30 ms restart gap | Isolate decoder endpoint behavior |
| Native WAV with decoder guard | Zero differing frames against direct concatenation across three wraps | Accepted numerical path; founder also accepted listening capture |
| Web default sample playback | AudioBufferSourceNode did not loop; near-end audition restarted at the same near-end offset repeatedly | Explicit `AudioServer.PLAYBACK_TYPE_STREAM` |
| Web explicit stream playback | Seven native wraps, one user start, no harness console errors | Same continuous mixer path used in RC1 |
| RC0 game | Temporary MP3, once per session; no finished callback; original WAV was not used | Prior audition did not demonstrate a game lifecycle restart bug |

The native discrepancy was at output frames N+2, 2N+2 and 3N+2, where N=4,542,981 (including the mixer's initial sample latency). The unguarded endpoint was zero instead of the first original sample, about -0.04047. All other frames matched the concatenated comparator. This is distinct from the rejected musical trims.

Godot's pinned [WAV mixer source](https://raw.githubusercontent.com/godotengine/godot/a13da4feb8d8aefc283c3763d33a2f170a18d541/scene/resources/audio_stream_wav.cpp) explains the inclusive endpoint read followed by resuming at original frame 1. The contained workaround supplies frame 0 at that decoder read. The [Web audio backend](https://raw.githubusercontent.com/godotengine/godot/a13da4feb8d8aefc283c3763d33a2f170a18d541/platform/web/js/libs/library_godot_audio.js) was also inspected; no engine/backend source was changed.

## Exact runtime handling

`assets/audio/miraie_main_theme_ORIGINAL_MASTER.wav` is a byte-for-byte copy. Import: `compress/mode=0`, `edit/loop_mode=2`, begin 0, end 4,542,981; trim, normalization, mono, 8-bit and forced rate are all off. Godot imports this float WAV to stereo PCM16 at 48 kHz. This built-in conversion is explicit; the source file is not rewritten.

`SessionAudio.prepare_music_stream()` duplicates only the decoded in-memory resource and appends a four-byte copy of its first stereo frame as a decoder guard. The first 18,171,924 decoded bytes remain unchanged. **Loop end remains N.** The extra storage is not an extra audible frame; the loop period remains exactly 94.6454375 seconds. No sample value is faded, blended, trimmed or rewritten. Revalidate the comparison on an engine upgrade.

The one MusicPlayer explicitly uses STREAM, starts once, and has no manual `finished → play()` callback. Menu, game, results and retries keep that player and position. Mute only affects its bus. Native starts on launch; Web starts on the first key/mouse/touch gesture. The temporary MP3 remains historical repository material but is excluded from the RC1 export.

No OGG was created. Local FFmpeg lacks libvorbis; the founder's later instruction permits keeping WAV. Any future compressed replacement must come directly from the original and receive its own listening validation.

## Reproduction and evidence

- Standalone recipes: `tools/audio/original_loop_harness/`; no game dependency.
- Isolated project, captures and JSON: `builds/audio-original-loop-investigation/` (ignored QA output).
- `guarded-native-comparison.json`: 13,680,000 mixed frames, three wraps, zero differing frames, maximum error 0.
- `native-loop-join-24s.wav`: founder-approved capture; join at 12 seconds.
- `native-two-full-copies.wav`: complete continuous native capture.
- Runtime regression: `tests/test_vm061_music.gd` compares the actual SessionAudio-prepared resource against four direct copies through three wraps, verifies source hash and the explicit STREAM mode.

The native listening gate is passed. This does not assert physical iPhone/Safari or Android audio validation; those remain part of the external-device review. No A/B/C material is referenced by the runtime.
