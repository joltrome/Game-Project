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
	check(hashes_match, "All eight founder source masters remain byte-identical")
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
		"Refund Coin derivative is an exact frame-boundary trim with no signal processing"
	)
	check(
		runtime.data.size() == 34675 * 4
		and absi(_pcm16(runtime.data, 0)) <= 2
		and absi(_pcm16(runtime.data, 1)) <= 2,
		"169.291667 ms trim starts on the reviewed near-zero stereo frame"
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
		audio.sfx_streams.size() == 8
		and audio.sfx_player_count() == 12
		and audio.sfx.bus == &"SFX"
		and audio.music.bus == &"Music",
		"Eight event streams use a fixed 12-voice SFX pool and separate Music/SFX buses"
	)
	check(
		audio.sfx_volume_db == {
			&"coin_pickup": -8.0,
			&"jump": 6.0,
			&"landing": 2.0,
			&"product_impact": -3.0,
			&"carriage_warning": 12.0,
			&"clock_in_confirm": 0.0,
			&"player_death": -6.0,
			&"round_complete": 2.0,
		},
		"Initial per-event gains remain explicit and configurable"
	)
	check(
		audio.current_music_state == SessionAudio.MusicState.MENU
		and is_equal_approx(audio.music.volume_db, -6.0),
		"Menu begins at the configured -6 dB relative music state"
	)

	session.show_credits()
	await create_timer(0.35, true, false, true).timeout
	check(
		audio.current_music_state == SessionAudio.MusicState.CREDITS
		and absf(audio.music.volume_db - -8.0) < 0.10,
		"Credits reaches -8 dB without restarting music"
	)
	session.show_menu()
	await create_timer(0.30, true, false, true).timeout
	check(absf(audio.music.volume_db - -6.0) < 0.05, "Credits to Menu returns smoothly to -6 dB")

	var clock_in_before := audio.played_count(&"clock_in_confirm")
	session.start_game()
	await create_timer(0.30, true, false, true).timeout
	check(
		audio.played_count(&"clock_in_confirm") == clock_in_before + 1
		and audio.current_music_state == SessionAudio.MusicState.GAMEPLAY
		and absf(audio.music.volume_db) < 0.05,
		"CLOCK IN plays once and music reaches the 0 dB gameplay-relative state"
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
	var accepted_jump_signals: Array[int] = []
	conveyor.player.jump_accepted.connect(func() -> void: accepted_jump_signals.append(1))
	Input.action_press(&"jump")
	await physics_frame
	Input.action_release(&"jump")
	await physics_frame
	check(
		accepted_jump_signals.size() == 1
		and audio.played_count(&"jump") == jump_before + 1,
		"Actual accepted jump emits and plays exactly once"
	)
	for index in 6:
		await physics_frame
	check(audio.played_count(&"jump") == jump_before + 1, "Held/airborne frames do not duplicate jump audio")
	for index in 120:
		await physics_frame
		if audio.played_count(&"landing") > landing_before:
			break
	check(audio.played_count(&"landing") == landing_before + 1, "Genuine airborne-to-grounded transition plays one landing")
	for index in 12:
		await physics_frame
	check(audio.played_count(&"landing") == landing_before + 1, "Continuous grounded contact does not spam landing audio")

	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.set_process(false)
	var coin_before := audio.played_count(&"coin_pickup")
	check(director.try_spawn_band_for_test(CollectibleDirector.PlacementBand.GROUND), "Audio fixture spawns a real Refund Coin")
	var coin := director.active_collectible()
	coin._on_body_entered(conveyor.player)
	coin._on_body_entered(conveyor.player)
	check(
		director.score == 1 and audio.played_count(&"coin_pickup") == coin_before + 1,
		"A real Refund Coin pickup scores and sounds exactly once"
	)

	var played_voice_indices: Array[int] = []
	audio.sfx_played.connect(
		func(event: StringName, voice_index: int) -> void:
			if event == &"product_impact":
				played_voice_indices.append(voice_index)
	)
	var product_before := audio.played_count(&"product_impact")
	var dummy := PRODUCT.instantiate() as ConveyorProduct
	root.add_child(dummy)
	conveyor.conveyor_product_landed.emit(dummy)
	conveyor.conveyor_product_landed.emit(dummy)
	check(
		audio.played_count(&"product_impact") == product_before + 2
		and played_voice_indices.size() == 2
		and played_voice_indices[0] != played_voice_indices[1],
		"Near-simultaneous can impacts use separate reusable voices"
	)
	dummy.queue_free()
	var warning_before := audio.played_count(&"carriage_warning")
	conveyor.sweeper_entry_cue_started.emit(518.0, 0.8)
	check(audio.played_count(&"carriage_warning") == warning_before + 1, "Existing carriage cue maps once to WarningSound1")

	session.pause_game()
	await create_timer(0.22, true, false, true).timeout
	check(
		audio.current_music_state == SessionAudio.MusicState.PAUSE
		and absf(audio.music.volume_db - -12.0) < 0.05,
		"Pause tween continues while simulation is paused and reaches -12 dB"
	)
	session.resume_game()
	await create_timer(0.22, true, false, true).timeout
	check(absf(audio.music.volume_db) < 0.05, "Resume smoothly restores gameplay gain")

	var death_before := audio.played_count(&"player_death")
	conveyor._kill_player(ConveyorPrototype.DeathCause.FALLING_PRODUCT)
	await process_frame
	await process_frame
	check(
		session.state == StandardSession.State.DEATH_BEAT
		and audio.played_count(&"player_death") == death_before + 1,
		"First impact death plays DeathSound1 exactly once"
	)
	await create_timer(0.13, true, false, true).timeout
	check(absf(audio.music.volume_db - -15.0) < 0.10, "Impact death quickly ducks music to -15 dB")
	var suppressed_counts := {
		&"jump": audio.played_count(&"jump"),
		&"landing": audio.played_count(&"landing"),
		&"coin_pickup": audio.played_count(&"coin_pickup"),
		&"product_impact": audio.played_count(&"product_impact"),
	}
	audio.request_sfx(&"jump")
	audio.request_sfx(&"landing")
	audio.request_sfx(&"coin_pickup")
	audio.request_sfx(&"product_impact")
	conveyor._kill_player(ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE)
	check(
		audio.played_count(&"jump") == suppressed_counts[&"jump"]
		and audio.played_count(&"landing") == suppressed_counts[&"landing"]
		and audio.played_count(&"coin_pickup") == suppressed_counts[&"coin_pickup"]
		and audio.played_count(&"product_impact") == suppressed_counts[&"product_impact"]
		and audio.played_count(&"player_death") == death_before + 1,
		"Post-death gameplay sounds and duplicate death playback are suppressed"
	)

	session.start_game()
	await process_frame
	var out_death_before := audio.played_count(&"player_death")
	session.game.conveyor._kill_player(ConveyorPrototype.DeathCause.LEFT_OUT)
	await process_frame
	await process_frame
	check(
		session.last_death_cause == ConveyorPrototype.DeathCause.LEFT_OUT
		and audio.played_count(&"player_death") == out_death_before,
		"OUT/VENDED remains intentionally free of the impact-death sound"
	)

	session.start_game()
	await process_frame
	var complete_before := audio.played_count(&"round_complete")
	var race_death_before := audio.played_count(&"player_death")
	var complete_round := session.game.conveyor.get_node("RoundController") as FixedRoundController
	complete_round._complete_round()
	await process_frame
	check(
		session.state == StandardSession.State.RESULTS
		and session.last_survived
		and audio.played_count(&"round_complete") == complete_before + 1,
		"Genuine completion plays ClockedOut1 exactly once"
	)
	session.game.conveyor._kill_player(ConveyorPrototype.DeathCause.FALLING_PRODUCT)
	await process_frame
	check(
		audio.played_count(&"round_complete") == complete_before + 1
		and audio.played_count(&"player_death") == race_death_before,
		"Completion wins the timer-zero race without death or duplicate success audio"
	)
	await create_timer(0.13, true, false, true).timeout
	check(audio.music.volume_db <= -14.8, "Successful completion briefly ducks music for ClockedOut1")
	await create_timer(0.55, true, false, true).timeout
	check(
		audio.current_music_state == SessionAudio.MusicState.RESULTS
		and absf(audio.music.volume_db - -7.0) < 0.05,
		"Outcome duck settles smoothly to the -7 dB Results state"
	)

	var music_index := AudioServer.get_bus_index(&"Music")
	var sfx_index := AudioServer.get_bus_index(&"SFX")
	audio.set_muted(&"Music", true)
	check(AudioServer.is_bus_mute(music_index) and not AudioServer.is_bus_mute(sfx_index), "Music toggle mutes only the Music bus")
	audio.set_muted(&"SFX", true)
	check(AudioServer.is_bus_mute(music_index) and AudioServer.is_bus_mute(sfx_index), "SFX toggle independently mutes the SFX bus")
	audio.set_muted(&"Music", false)
	audio.set_muted(&"SFX", false)

	for index in 10:
		session.start_game()
		await process_frame
	var voices_unchanged := audio.sfx_voices.size() == voice_ids.size()
	for index in mini(audio.sfx_voices.size(), voice_ids.size()):
		voices_unchanged = voices_unchanged and audio.sfx_voices[index].get_instance_id() == voice_ids[index]
	var playing_voices := 0
	for voice in audio.sfx_voices:
		if voice.playing:
			playing_voices += 1
	check(
		audio.music.get_instance_id() == music_id
		and audio.music_start_count == 1
		and voices_unchanged
		and audio.sfx_player_count() == 12
		and playing_voices == 1,
		"Ten retries retain one music player, reuse the fixed SFX pool, and stop prior-run SFX"
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
