extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const PRODUCT := preload("res://scenes/hazards/conveyor_product.tscn")
const SAVE_PATH := "/tmp/vms-vm063-audio-test.cfg"
const COIN_MASTER := "res://assets/audio/sfx/masters/CoinRefund1.wav"
const COIN_RUNTIME := "res://assets/audio/sfx/runtime/CoinRefund1_trimmed.wav"
const COIN_TRIM_FRAMES := 8126

var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func run() -> void:
	_check_source_assets_and_trim()
	await _check_runtime_audio()
	DirAccess.remove_absolute(SAVE_PATH)
	print("VM063_AUDIO_PASS_FAILURES=", failures)
	quit(failures)


func _check_source_assets_and_trim() -> void:
	var expected_hashes := {
		"Drop1.wav": "223d8eebedf35c6bcef8315aec90995fa40c8f391519b5936fe643c8253cd6dd",
		"Jump1.wav": "8b4a78b15ee297be30cb6a3346f75ff57d17e551c51cd6c5187dfa38256fc0c8",
		"ClockedOut1.wav": "31905b2b6b86c96802ce68dfe225d65f9ce8bb0a30a8eebc76ce718f376c36e9",
		"DeathSound1.wav": "6bedd8a26ee32dbfef5f6436e4118dcf17e9b242636937183ee4f263c466e647",
		"WarningSound1.wav": "1def6901eb79f40b8a86bfe370ff1a70df4e39a8345c2e77ad914c94bad09a65",
		"CanDrop1.wav": "007ae1e6255eee4277267b195f1e7d5a911b17cd9bc0f45f9415d5c1fc484402",
		"ClockInUiConfirm1.wav": "d37a14c4bcca6bf825d36090f3f158104f6371db73722873a0b9b45e67ec3769",
		"CoinRefund1.wav": "cd2f783815ac8ae304d380fc9520b86029bab725be08ded030769e30bf852e81",
	}
	var hashes_match := true
	for file_name: String in expected_hashes:
		var path := "res://assets/audio/sfx/masters/" + file_name
		hashes_match = hashes_match and FileAccess.get_sha256(path) == expected_hashes[file_name]
	check(hashes_match, "All eight founder source masters remain byte-identical, including rejected WarningSound1")
	var master := load(COIN_MASTER) as AudioStreamWAV
	var runtime := load(COIN_RUNTIME) as AudioStreamWAV
	check(
		master != null
		and runtime != null
		and master.format == AudioStreamWAV.FORMAT_16_BITS
		and runtime.format == AudioStreamWAV.FORMAT_16_BITS
		and master.mix_rate == 48000
		and runtime.mix_rate == 48000
		and master.stereo
		and runtime.stereo,
		"Refund Coin source and runtime derivative retain 48 kHz stereo PCM16"
	)
	check(
		runtime.data == master.data.slice(COIN_TRIM_FRAMES * 4),
		"Refund Coin derivative remains an exact frame-boundary trim with no signal processing"
	)
	check(
		runtime.data.size() == 34675 * 4
		and absi(_pcm16(runtime.data, 0)) <= 2
		and absi(_pcm16(runtime.data, 1)) <= 2,
		"169.291667 ms trim still starts on the reviewed near-zero stereo frame"
	)


func _check_runtime_audio() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	var session := SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = SAVE_PATH
	root.add_child(session)
	await process_frame
	var audio := session.audio
	var music_id := audio.music.get_instance_id()
	var voice_ids: Array[int] = []
	for voice in audio.sfx_voices:
		voice_ids.append(voice.get_instance_id())
	check(
		audio.sfx_streams.size() == 7
		and not audio.sfx_streams.has(&"carriage_warning")
		and audio.sfx_player_count() == 12
		and audio.sfx.bus == &"SFX"
		and audio.music.bus == &"Music",
		"Seven active SFX mappings omit WarningSound1 and retain fixed Music/SFX routing"
	)
	check(
		audio.sfx_volume_db == {
			&"coin_pickup": -8.0,
			&"jump": 6.0,
			&"landing": 2.0,
			&"product_impact": -3.0,
			&"clock_in_confirm": 0.0,
			&"player_death": -6.0,
			&"round_complete": 2.0,
		},
		"The other seven per-event gains remain unchanged"
	)
	check(
		session.state == StandardSession.State.MENU
		and not audio.music.playing
		and audio.current_music_state == SessionAudio.MusicState.SILENT,
		"Main Menu has no Miraie BGM"
	)

	session.show_credits()
	await create_timer(0.05, true, false, true).timeout
	check(
		session.state == StandardSession.State.CREDITS
		and not audio.music.playing
		and audio.current_music_state == SessionAudio.MusicState.SILENT,
		"Credits has no Miraie BGM"
	)
	session.show_menu()
	check(not audio.music.playing, "Credits to Menu remains silent")

	var clock_in_before := audio.played_count(&"clock_in_confirm")
	var run_start_times: Array[int] = []
	audio.run_music_started.connect(func(_index: int) -> void: run_start_times.append(Time.get_ticks_msec()))
	var clock_in_time := Time.get_ticks_msec()
	session.start_game()
	check(
		audio.played_count(&"clock_in_confirm") == clock_in_before + 1
		and not audio.music.playing
		and audio.run_music_start_pending(),
		"CLOCK IN plays once while gameplay begins inside the intentional quiet gap"
	)
	while run_start_times.is_empty():
		await process_frame
	var start_delay_ms := run_start_times[0] - clock_in_time
	check(
		start_delay_ms >= 150 and start_delay_ms <= 300,
		"Run music begins 150–300 ms after CLOCK IN (observed %d ms)" % start_delay_ms
	)
	check(
		audio.music.playing
		and audio.music_start_count == 1
		and audio.current_music_state == SessionAudio.MusicState.GAMEPLAY
		and audio.music.get_playback_position() < 0.08,
		"Gameplay starts the accepted Miraie OST from position zero"
	)

	await create_timer(0.10, true, false, true).timeout
	var pre_pause_position := audio.music.get_playback_position()
	var pre_pause_starts := audio.music_start_count
	session.pause_game()
	await create_timer(0.22, true, false, true).timeout
	var paused_position := audio.music.get_playback_position()
	check(
		audio.music.playing
		and audio.music_start_count == pre_pause_starts
		and paused_position >= pre_pause_position
		and absf(audio.music.volume_db - -12.0) < 0.05,
		"Pause preserves the run playhead and ducks the same player to -12 dB"
	)
	session.resume_game()
	await create_timer(0.22, true, false, true).timeout
	check(
		audio.music.playing
		and audio.music_start_count == pre_pause_starts
		and audio.music.get_playback_position() >= paused_position
		and absf(audio.music.volume_db) < 0.05,
		"Resume continues the same run playhead and restores gameplay gain"
	)

	var game := session.game
	var conveyor := game.conveyor
	game.background_drop_director.set_process(false)
	conveyor.set_physics_process(false)
	conveyor.left_failure_enabled = false
	for index in 60:
		await physics_frame
		if conveyor.player.is_on_floor():
			break
	check(conveyor.player.is_on_floor(), "Jump fixture establishes grounded support before input")
	var jump_before := audio.played_count(&"jump")
	var landing_before := audio.played_count(&"landing")
	Input.action_press(&"jump")
	await physics_frame
	Input.action_release(&"jump")
	await physics_frame
	check(audio.played_count(&"jump") == jump_before + 1, "Accepted jump plays exactly once")
	for index in 120:
		await physics_frame
		if audio.played_count(&"landing") > landing_before:
			break
	check(audio.played_count(&"landing") == landing_before + 1, "Genuine landing plays exactly once without grounded spam")

	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.set_process(false)
	var coin_before := audio.played_count(&"coin_pickup")
	check(director.try_spawn_band_for_test(CollectibleDirector.PlacementBand.GROUND), "Audio fixture spawns a real Refund Coin")
	var coin := director.active_collectible()
	coin._on_body_entered(conveyor.player)
	coin._on_body_entered(conveyor.player)
	check(director.score == 1 and audio.played_count(&"coin_pickup") == coin_before + 1, "Refund Coin scores and sounds exactly once")

	var product_before := audio.played_count(&"product_impact")
	var dummy := PRODUCT.instantiate() as ConveyorProduct
	root.add_child(dummy)
	conveyor.conveyor_product_landed.emit(dummy)
	conveyor.conveyor_product_landed.emit(dummy)
	check(audio.played_count(&"product_impact") == product_before + 2, "Near-simultaneous can impacts retain overlapping one-shots")
	dummy.queue_free()
	var warning_before := audio.played_count(&"carriage_warning")
	var warning_requests: Array[StringName] = []
	audio.sfx_requested.connect(func(event: StringName) -> void: warning_requests.append(event))
	conveyor.sweeper_entry_cue_started.emit(518.0, 0.8)
	await process_frame
	check(
		audio.played_count(&"carriage_warning") == warning_before
		and not warning_requests.has(&"carriage_warning"),
		"Carriage warning remains visually timed but produces no audio request or playback"
	)

	var death_before := audio.played_count(&"player_death")
	conveyor._kill_player(ConveyorPrototype.DeathCause.FALLING_PRODUCT)
	await process_frame
	await process_frame
	check(
		session.state == StandardSession.State.DEATH_BEAT
		and audio.played_count(&"player_death") == death_before + 1
		and audio.current_music_state == SessionAudio.MusicState.FADING_OUT,
		"Impact death plays once and immediately begins the run-music fade"
	)
	await create_timer(0.13, true, false, true).timeout
	check(
		not audio.music.playing
		and audio.current_music_state == SessionAudio.MusicState.SILENT,
		"Death music is fully stopped after the configured 100 ms fade"
	)
	await create_timer(StandardSession.DEATH_BEAT_SECONDS, true, false, true).timeout
	check(
		session.state == StandardSession.State.RESULTS and not audio.music.playing,
		"Death Results remain silent"
	)

	var retry_start_count := audio.music_start_count
	var retry_clock_in := audio.played_count(&"clock_in_confirm")
	session.start_game()
	check(not audio.music.playing and audio.run_music_start_pending(), "Retry begins a new quiet gap instead of resuming old music")
	while audio.music_start_count == retry_start_count:
		await process_frame
	check(
		audio.played_count(&"clock_in_confirm") == retry_clock_in + 1
		and audio.music.get_playback_position() < 0.08,
		"Retry plays CLOCK IN once and restarts Miraie from position zero"
	)

	var music_index := AudioServer.get_bus_index(&"Music")
	var sfx_index := AudioServer.get_bus_index(&"SFX")
	var mute_start_count := audio.music_start_count
	audio.set_muted(&"Music", true)
	check(AudioServer.is_bus_mute(music_index) and not AudioServer.is_bus_mute(sfx_index), "Music OFF mutes only current run music")
	audio.set_muted(&"Music", false)
	check(not AudioServer.is_bus_mute(music_index) and audio.music_start_count == mute_start_count, "Music ON reveals the same run without restart")
	audio.set_muted(&"SFX", true)
	check(AudioServer.is_bus_mute(sfx_index) and not AudioServer.is_bus_mute(music_index), "SFX toggle remains independent")
	audio.set_muted(&"SFX", false)

	var complete_before := audio.played_count(&"round_complete")
	var race_death_before := audio.played_count(&"player_death")
	var complete_round := session.game.conveyor.get_node("RoundController") as FixedRoundController
	complete_round._complete_round()
	await process_frame
	check(
		session.state == StandardSession.State.RESULTS
		and session.last_survived
		and audio.played_count(&"round_complete") == complete_before + 1
		and audio.current_music_state == SessionAudio.MusicState.FADING_OUT,
		"CLOCKED OUT plays once and begins the same 100 ms run-music fade"
	)
	session.game.conveyor._kill_player(ConveyorPrototype.DeathCause.FALLING_PRODUCT)
	await process_frame
	check(
		audio.played_count(&"round_complete") == complete_before + 1
		and audio.played_count(&"player_death") == race_death_before,
		"Completion still wins the timer-zero race"
	)
	await create_timer(0.13, true, false, true).timeout
	check(
		not audio.music.playing
		and audio.current_music_state == SessionAudio.MusicState.SILENT,
		"Successful Results remain silent after the 100 ms fade"
	)
	session.show_menu()
	check(not audio.music.playing and audio.current_music_state == SessionAudio.MusicState.SILENT, "Results to Menu remains silent")
	session.show_credits()
	check(not audio.music.playing, "Menu to Credits remains silent")
	session.show_menu()

	for index in 10:
		session.start_game()
		await process_frame
	var voices_unchanged := audio.sfx_voices.size() == voice_ids.size()
	for index in mini(audio.sfx_voices.size(), voice_ids.size()):
		voices_unchanged = voices_unchanged and audio.sfx_voices[index].get_instance_id() == voice_ids[index]
	check(
		audio.music.get_instance_id() == music_id
		and voices_unchanged
		and audio.sfx_player_count() == 12
		and audio.get_child_count() == 14,
		"Rapid retries retain one music player, one delay timer, and the fixed SFX pool"
	)
	check(
		session.game.conveyor.player.maximum_speed == 300.0
		and session.game.conveyor.player.gravity == 2400.0
		and session.game.conveyor.player.jump_velocity == -700.0
		and absf(session.game.conveyor.conveyor_speed - 140.0) < 0.001,
		"Representative frozen movement and conveyor values remain unchanged"
	)
	session.queue_free()
	await process_frame


func _pcm16(data: PackedByteArray, sample_index: int) -> int:
	var byte_index := sample_index * 2
	var value := int(data[byte_index]) | (int(data[byte_index + 1]) << 8)
	return value - 65536 if value >= 32768 else value
