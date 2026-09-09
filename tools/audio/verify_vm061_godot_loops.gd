extends SceneTree

# Isolated offline mixer test. Does not load/change the game's project or audio nodes.
const FRAME_COUNT := 4541538
const RATE := 48000

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Supply the candidate directory after --")
		quit(1)
		return
	var results: Array[Dictionary] = []
	for candidate in ["A_trim_only", "B_trim_2ms_declick"]:
		var stream := AudioStreamWAV.load_from_file(args[0].path_join(candidate + ".wav"), {
			"edit/trim": false, "edit/normalize": false,
			"force/max_rate": false, "force/8_bit": false,
			"compress/mode": 0,
		})
		assert(stream != null)
		assert(stream.mix_rate == RATE and stream.stereo)
		assert(absf(stream.get_length() - float(FRAME_COUNT)/RATE) < 1.0/RATE)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = FRAME_COUNT
		var playback := stream.instantiate_playback()
		playback.start()
		var frames_mixed := 0
		var wraps := 0
		var previous := 0.0
		while frames_mixed < FRAME_COUNT * 3 + 4800:
			var audio := playback.mix_audio(1.0, 4800)
			assert(audio.size() == 4800)
			frames_mixed += audio.size()
			var current := playback.get_playback_position()
			if current < previous - 1.0:
				wraps += 1
			previous = current
		assert(wraps == 3 and playback.is_playing())
		results.append({"candidate": candidate, "frames_mixed": frames_mixed,
			"detected_end_to_start_wraps": wraps, "still_playing": playback.is_playing(),
			"length_seconds": stream.get_length(), "engine_pcm_format": stream.format,
			"engine_mix_rate": AudioServer.get_mix_rate(), "loop_begin": 0, "loop_end": stream.loop_end})
		playback.stop()
		print("PASS: ", candidate, " three complete native mixer wraps; no restart/seek between cycles")
	var out := FileAccess.open(args[0].path_join("godot-loop-validation.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"engine": Engine.get_version_info(), "results": results,
		"scope": "Offline native Godot mixer; no speakers, Web device or perceptual claim"}, "  ") + "\n")
	out.close()
	quit(0)
