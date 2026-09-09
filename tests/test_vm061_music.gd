extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var source := load("res://assets/audio/miraie_main_theme_ORIGINAL_MASTER.wav") as AudioStreamWAV
	assert(FileAccess.get_sha256("res://assets/audio/miraie_main_theme_ORIGINAL_MASTER.wav") == "1e12cc678e944c2ea1aa560653c1c07e3b26a1dbdd9dfead40d3deced3b391d4")
	assert(source.format == AudioStreamWAV.FORMAT_16_BITS and source.mix_rate == 48000 and source.stereo)
	assert(source.loop_mode == AudioStreamWAV.LOOP_FORWARD and source.loop_begin == 0 and source.loop_end == 4542981)
	var original_data := source.data
	var prepared := SessionAudio.prepare_music_stream(source) as AudioStreamWAV
	assert(source.data == original_data and source.data.size() == 4542981*4)
	assert(prepared.data.size() == source.data.size()+4 and prepared.loop_end == source.loop_end)
	assert(prepared.data.slice(0,source.data.size()) == original_data and prepared.data.slice(-4) == original_data.slice(0,4))
	var direct := source.duplicate() as AudioStreamWAV
	direct.loop_mode = AudioStreamWAV.LOOP_DISABLED
	direct.data = original_data+original_data+original_data+original_data
	var native_playback := prepared.instantiate_playback()
	var direct_playback := direct.instantiate_playback()
	native_playback.start(); direct_playback.start()
	# Engine mixer output compared frame-for-frame through three full wraps.
	var frames := 0
	while frames < 4542981*3+48000:
		var count := mini(4096,4542981*3+48000-frames)
		assert(native_playback.mix_audio(1.0,count) == direct_playback.mix_audio(1.0,count), "Native stream differs from direct original concatenation")
		frames += count
	native_playback.stop(); direct_playback.stop()
	var audio := SessionAudio.new()
	audio.music_stream=source
	root.add_child(audio)
	assert(audio.music.playback_type == AudioServer.PLAYBACK_TYPE_STREAM)
	audio.free()
	print("VM061_MUSIC_PASS: unchanged source, one decoder guard, 3 wraps identical, explicit STREAM")
	quit()
