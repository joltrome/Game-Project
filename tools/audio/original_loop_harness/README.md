# Original WAV native-loop harness

Copy these files into a separate directory and rename `project.godot.template` to `project.godot` (audio/driver/mix_rate=48000). Copy the ORIGINAL non-fade WAV byte-for-byte as original.wav. Set its importer: trim=false, normalize=false, max-rate=false, mono=false, 8-bit=false, compress/mode=0, edit/loop_mode=2, loop_begin=0, loop_end=4542981. Never use A/B/C.

Run verify_unguarded.gd first, then verify_guarded.gd with Godot 4.7.1. Unguarded returns exit 1 when it detects a mismatch; that is the expected diagnostic. Guarded must report zero differing frames against direct concatenation. Each mixes three wraps. Generated PCM and JSON belong in the parent QA directory. Use a writable --log-file; a sandbox data/log-directory failure can crash this engine build at startup.

The runtime-only four-byte guard copies the first stereo PCM16 frame to the exclusive endpoint. Godot 4.7.1 reads that endpoint, then continues at original frame 1. The guard produces original frame 0 at the correct time; it is not an extra audible frame. Loop period remains 4542981 frames. The original WAV stays unchanged. This is tied to the verified engine decoder behavior, not a musical edit. Recheck on an engine upgrade.

The GUI harness uses the same native stream/player, with start/near-end/stop buttons and no finished callback. It does not load game code.

Use explicit `AudioServer.PLAYBACK_TYPE_STREAM` for Web exports. The default sample backend repeated the near-end start offset instead of the full loop in the isolated experiment; STREAM completed seven wraps from one start.
