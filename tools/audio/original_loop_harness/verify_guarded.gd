extends SceneTree

const N := 4542981
const RATE := 48000

func _initialize() -> void:
	var stream := load("res://original.wav") as AudioStreamWAV
	assert(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS)
	assert(stream.stereo and stream.mix_rate == RATE and stream.data.size() == N*4)
	assert(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_begin == 0 and stream.loop_end == N)
	var concatenated := AudioStreamWAV.new()
	concatenated.format = stream.format
	concatenated.mix_rate = stream.mix_rate
	concatenated.stereo = stream.stereo
	concatenated.data = stream.data + stream.data + stream.data + stream.data
	# Guard the decoder read at the exclusive endpoint; this frame replaces,
	# rather than adds to, the next cycle's frame zero in Godot 4.7.1.
	stream.data = stream.data + stream.data.slice(0,4)
	var native := stream.instantiate_playback()
	var direct := concatenated.instantiate_playback()
	native.start()
	direct.start()
	var recorded := FileAccess.open("res://../guarded-native-three-wraps.f32",FileAccess.WRITE)
	var decoded := FileAccess.open("res://../imported-original.s16",FileAccess.WRITE)
	decoded.store_buffer(stream.data)
	decoded.close()
	var mixed := 0
	var wraps := 0
	var previous := 0.0
	var max_error := 0.0
	var differing_frames := 0
	var differences: Array[Dictionary] = []
	while mixed < N * 3 + RATE:
		var a := native.mix_audio(1.0,4800)
		var b := direct.mix_audio(1.0,4800)
		assert(a.size() == 4800 and b.size() == a.size())
		recorded.store_buffer(a.to_byte_array())
		for i in a.size():
			var d := a[i]-b[i]
			if d != Vector2.ZERO:
				differing_frames += 1
				if differences.size() < 12:
					differences.append({"frame": mixed+i,"native":[a[i].x,a[i].y],"direct":[b[i].x,b[i].y]})
				max_error = maxf(max_error,maxf(absf(d.x),absf(d.y)))
		mixed += a.size()
		var current := native.get_playback_position()
		if current < previous-1:
			wraps += 1
		previous = current
	recorded.close()
	assert(wraps == 3 and native.is_playing())
	var report := {"engine":Engine.get_version_info().string,"frames_mixed":mixed,
		"native_wraps":wraps,"format":stream.format,"mix_rate":AudioServer.get_mix_rate(),
		"loop_begin":stream.loop_begin,"loop_end":stream.loop_end,
		"source_frame_count":N,"stream_buffer_duration":stream.get_length(),"loop_period_seconds":float(N)/RATE,
		"differences":differences,"native_vs_direct_concatenation_differing_frames":differing_frames,
		"native_vs_direct_concatenation_max_error":max_error}
	var out := FileAccess.open("res://../guarded-native-comparison.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"  ")+"\n")
	out.close()
	print(JSON.stringify(report))
	native.stop()
	direct.stop()
	quit(0 if max_error == 0.0 else 1)
