extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const CONVEYOR := preload("res://scenes/prototypes/conveyor.tscn")
const AUDIO_PATH := "/tmp/vms-vm064-audio.cfg"
const SCORE_PATH := "/tmp/vms-vm064-score.cfg"
const TEST_SEEDS := [401, 1701, 4202]
const OLD_BASELINE_TOTALS := {401: 54, 1701: 55, 4202: 55}

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func run() -> void:
	root.size = Vector2i(1152, 648)
	await _test_audio_settings_and_ui()
	await _test_pause_and_touch()
	await _test_scatter_contract()
	await _test_natural_scatter_metrics()
	DirAccess.remove_absolute(AUDIO_PATH)
	DirAccess.remove_absolute(SCORE_PATH)
	print("VM064_PRE_EXTERNAL_FAILURES=", failures)
	quit(failures)


func _test_audio_settings_and_ui() -> void:
	DirAccess.remove_absolute(AUDIO_PATH)
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "music_enabled", false)
	legacy.set_value("audio", "sfx_enabled", true)
	legacy.save(AUDIO_PATH)
	var session := SESSION.instantiate() as StandardSession
	session.audio_settings_path = AUDIO_PATH
	session.score_storage_path = SCORE_PATH
	session.auto_focus_pause_enabled = false
	root.add_child(session)
	await process_frame
	var audio := session.audio
	check(
		audio.settings_migrated_from_booleans
		and audio.user_volume_percent(&"Music") == 0.0
		and audio.user_volume_percent(&"SFX") == 100.0,
		"Legacy Music OFF/SFX ON preferences migrate to 0/100 percent"
	)
	var migrated := ConfigFile.new()
	migrated.load(AUDIO_PATH)
	check(
		float(migrated.get_value("volume", "music_percent")) == 0.0
		and float(migrated.get_value("volume", "sfx_percent")) == 100.0,
		"Migrated percentages become the authoritative persisted schema"
	)
	check(
		audio.sfx_volume_db[&"jump"] == 10.0
		and audio.sfx_volume_db[&"coin_pickup"] == -8.0
		and audio.sfx_volume_db[&"landing"] == 2.0,
		"Jump rises from +6 to +10 dB while representative authored SFX gains stay fixed"
	)
	audio.set_user_volume_percent(&"Music", 50.0)
	audio.set_user_volume_percent(&"SFX", 25.0)
	var music_index := AudioServer.get_bus_index(&"Music")
	var sfx_index := AudioServer.get_bus_index(&"SFX")
	check(
		absf(AudioServer.get_bus_volume_db(music_index) - linear_to_db(0.5)) < 0.01
		and absf(AudioServer.get_bus_volume_db(sfx_index) - linear_to_db(0.25)) < 0.01,
		"Independent user percentages apply as live bus-level scaling"
	)
	audio.set_user_volume_percent(&"Music", 0.0)
	audio.set_user_volume_percent(&"SFX", 0.0)
	check(
		AudioServer.is_bus_mute(music_index) and AudioServer.is_bus_mute(sfx_index),
		"Zero percent fully mutes each bus"
	)
	audio.set_user_volume_percent(&"Music", 100.0)
	audio.set_user_volume_percent(&"SFX", 100.0)
	check(
		absf(AudioServer.get_bus_volume_db(music_index)) < 0.01
		and absf(AudioServer.get_bus_volume_db(sfx_index)) < 0.01
		and not AudioServer.is_bus_mute(music_index)
		and not AudioServer.is_bus_mute(sfx_index),
		"One hundred percent restores the authored reference mix"
	)
	var music_rect := session._music_slider.slider.get_global_rect()
	_send_slider_touch(session._music_slider, 41, Vector2(music_rect.position.x + music_rect.size.x * 0.35, music_rect.get_center().y), true)
	_send_slider_touch(session._music_slider, 41, Vector2(music_rect.position.x + music_rect.size.x * 0.35, music_rect.get_center().y), false)
	await process_frame
	check(
		absf(audio.user_volume_percent(&"Music") - 35.0) <= 2.0,
		"Music slider updates live from an emulated touch gesture"
	)
	var sfx_rect := session._sfx_slider.slider.get_global_rect()
	_send_mouse(Vector2(sfx_rect.position.x + sfx_rect.size.x * 0.65, sfx_rect.get_center().y), true)
	_send_mouse(Vector2(sfx_rect.position.x + sfx_rect.size.x * 0.65, sfx_rect.get_center().y), false)
	await process_frame
	check(
		absf(audio.user_volume_percent(&"SFX") - 65.0) <= 2.0,
		"SFX slider updates live from a mouse gesture"
	)
	audio.set_user_volume_percent(&"Music", 100.0)
	audio.set_user_volume_percent(&"SFX", 100.0)
	var confirm_before := audio.played_count(&"clock_in_confirm")
	var credits := session._c2.get_node("credits") as Button
	credits.mouse_entered.emit()
	credits.grab_focus()
	check(audio.played_count(&"clock_in_confirm") == confirm_before, "Hover and focus do not play UI confirmation")
	credits.pressed.emit()
	check(
		session.state == StandardSession.State.CREDITS
		and audio.played_count(&"clock_in_confirm") == confirm_before + 1,
		"CREDITS activation plays the common confirmation exactly once"
	)
	var back := session._c2.get_node("back") as Button
	back.pressed.emit()
	check(
		session.state == StandardSession.State.MENU
		and audio.played_count(&"clock_in_confirm") == confirm_before + 2,
		"BACK activation uses the same confirmation exactly once"
	)
	var persisted := ConfigFile.new()
	check(
		session._music_slider.slider.min_value == 0.0
		and session._music_slider.slider.max_value == 100.0
		and session._sfx_slider.slider.min_value == 0.0
		and session._sfx_slider.slider.max_value == 100.0,
		"C2 Music/SFX sliders expose the complete 0-100 range"
	)
	var preview_before := audio.played_count(&"clock_in_confirm")
	session._sfx_slider.set_percent(73.0)
	session._sfx_slider.slider.drag_ended.emit(true)
	session._sfx_slider.slider.drag_ended.emit(false)
	check(
		audio.played_count(&"clock_in_confirm") == preview_before + 1,
		"Finishing one SFX adjustment plays one preview without release spam"
	)
	session._sfx_slider.set_percent(100.0)
	persisted.load(AUDIO_PATH)
	check(
		float(persisted.get_value("volume", "music_percent")) == 100.0
		and float(persisted.get_value("volume", "sfx_percent")) == 100.0,
		"Slider-authoritative percentages persist across screen transitions"
	)
	session.queue_free()
	await process_frame


func _test_pause_and_touch() -> void:
	var session := SESSION.instantiate() as StandardSession
	session.audio_settings_path = AUDIO_PATH
	session.score_storage_path = SCORE_PATH
	session.auto_focus_pause_enabled = false
	root.add_child(session)
	await process_frame
	(session._c2.get_node("clock_in") as Button).pressed.emit()
	await create_timer(0.25, true, false, true).timeout
	check(session.touch.pause_button.visible, "One upper-left Pause button is visible during desktop gameplay")
	session.audio.set_user_volume_percent(&"Music", 50.0)
	var confirm_before := session.audio.played_count(&"clock_in_confirm")
	session.touch.pause_button.pressed.emit()
	await create_timer(0.22, true, false, true).timeout
	check(
		session.state == StandardSession.State.PAUSED
		and session.audio.played_count(&"clock_in_confirm") == confirm_before + 1
		and absf(session.audio.music.volume_db - -12.0) < 0.05
		and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) - linear_to_db(0.5)) < 0.01,
		"Clickable/touch Pause confirms once and combines -12 dB ducking with user Music level"
	)
	var p_event := InputEventKey.new()
	p_event.pressed = true
	p_event.physical_keycode = KEY_P
	p_event.keycode = KEY_P
	session._unhandled_input(p_event)
	await create_timer(0.22, true, false, true).timeout
	check(
		session.state == StandardSession.State.GAME
		and absf(session.audio.music.volume_db) < 0.05
		and session.audio.user_volume_percent(&"Music") == 50.0,
		"P resumes the same playhead without discarding the user Music level"
	)
	var escape_event := InputEventKey.new()
	escape_event.pressed = true
	escape_event.keycode = KEY_ESCAPE
	escape_event.physical_keycode = KEY_ESCAPE
	session._unhandled_input(escape_event)
	check(session.state == StandardSession.State.PAUSED, "Escape pauses active gameplay")
	escape_event = escape_event.duplicate()
	escape_event.pressed = true
	session._unhandled_input(escape_event)
	check(session.state == StandardSession.State.GAME, "Escape resumes from Pause")
	session.touch.touch_available = true
	session.touch.size = Vector2(1152.0, 648.0)
	session.touch.set_game_active(true)
	await process_frame
	var right := session.touch.rectangles[1].get_center()
	var jump := session.touch.rectangles[2].get_center()
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	session.touch.pause_button.pressed.emit()
	check(
		session.state == StandardSession.State.PAUSED
		and not Input.is_action_pressed(&"move_right")
		and not Input.is_action_pressed(&"jump"),
		"Pause clears simultaneous held mobile movement and jump"
	)
	check(
		session.touch.pause_button.position == Vector2(8.0, 8.0)
		and session.touch.pause_button.size == Vector2(48.0, 48.0)
		and right.y > session.touch.pause_button.position.y + session.touch.pause_button.size.y
		and jump.y > session.touch.pause_button.position.y + session.touch.pause_button.size.y,
		"Pause is a 48x48 upper-left target separated from bottom touch controls"
	)
	session.resume_game()
	session.audio.set_user_volume_percent(&"Music", 100.0)
	session.queue_free()
	await process_frame


func _test_scatter_contract() -> void:
	for count in [1, 2, 3]:
		var conveyor := await _make_scatter_fixture(900 + count)
		var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		check(director.try_spawn_scatter_for_test(count, false), "%d-coin scatter offer can launch" % count)
		var coins := director.active_collectibles()
		check(coins.size() == count, "%d-coin offer creates exactly the intended count" % count)
		var positions: Array[Vector2] = []
		var safe := true
		for coin in coins:
			positions.append(coin.global_position)
			safe = safe and director.player_spawn_rejection_reason_for_test(coin.global_position).is_empty()
		check(safe, "%d-coin scatter respects player exclusion and safety padding" % count)
		if count > 1:
			check(_minimum_distance(positions) + 0.001 >= director.minimum_scatter_separation, "%d-coin scatter respects 120 px minimum separation" % count)
		if count == 3:
			check(not director._scatter_is_trivially_collinear(_positions_as_candidates(positions)), "Three-coin scatter rejects trivial route-like collinearity")
		conveyor.queue_free()
		await process_frame
	var pair_conveyor := await _make_scatter_fixture(1901)
	var pair_director := pair_conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(pair_director.try_spawn_scatter_for_test(3, true), "Three-coin pair-mode offer can launch")
	var pair_positions: Array[Vector2] = []
	for coin in pair_director.active_collectibles():
		pair_positions.append(coin.global_position)
	check(
		absf(pair_positions[0].distance_to(pair_positions[1]) - pair_director.pair_mode_separation) < 0.01
		and pair_positions[2].distance_to(pair_positions[0]) >= pair_director.minimum_scatter_separation
		and pair_positions[2].distance_to(pair_positions[1]) >= pair_director.minimum_scatter_separation,
		"Pair mode keeps exactly two coins at 64 px and separates the third by 120 px"
	)
	pair_conveyor.queue_free()
	await process_frame
	var side_conveyor := await _make_scatter_fixture(2412)
	var side_director := side_conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var centred_pair := side_director._scatter_candidates(2, false, CollectibleDirector.OfferSide.CENTRED)
	check(
		not centred_pair.is_empty()
		and side_director.classify_offer_side_for_test(centred_pair, side_conveyor.player.global_position.x) == CollectibleDirector.OfferSide.CENTRED
		and side_director._scatter_correction_side_preferences() == [CollectibleDirector.OfferSide.CENTRED],
		"Far-right anti-streak correction uses a constructible centred pair instead of impossible ahead space"
	)
	side_conveyor.queue_free()
	await process_frame


func _test_natural_scatter_metrics() -> void:
	for seed in TEST_SEEDS:
		var conveyor := await _make_scatter_fixture(seed)
		var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		var step := 1.0 / 120.0
		while conveyor.survival_time < 59.95:
			conveyor.survival_time += step
			director._process(step)
			for coin in director.active_collectibles():
				coin._resolve(true)
		var accepted := _accepted_attempts(director)
		var counts := PackedInt32Array([0, 0, 0, 0])
		var offered := 0
		var pair_count := 0
		var separations: Array[float] = []
		var violations := 0
		for entry in accepted:
			var count := int(entry.intended_count)
			counts[count] += 1
			offered += count
			if bool(entry.pair_mode):
				pair_count += 1
			if count > 1:
				separations.append(float(entry.minimum_pairwise_separation))
			if String(entry.topology) != "CONSTRAINED_SCATTER" or count < 1 or count > 3:
				violations += 1
		separations.sort()
		var median_separation := separations[separations.size() / 2] if not separations.is_empty() else INF
		check(
			abs(offered - int(OLD_BASELINE_TOTALS[seed])) <= 6,
			"Seed %d keeps total offered coins near the accepted baseline" % seed
		)
		check(counts[1] > 0 and counts[2] > 0 and counts[3] > 0, "Seed %d naturally exercises 1/2/3-coin offers" % seed)
		check(violations == 0, "Seed %d uses only bounded 1-3 coin constrained scatter" % seed)
		print(
			"VM064_SCATTER seed=%d old=%d new=%d offers=%d counts_1_2_3=%s pairs=%d min=%.3f median=%.3f exhausted=%d rejections=%s"
			% [seed, OLD_BASELINE_TOTALS[seed], offered, accepted.size(), [counts[1], counts[2], counts[3]], pair_count, separations[0] if not separations.is_empty() else INF, median_separation, director.scatter_exhausted_count(), director.rejection_counts()]
		)
		conveyor.queue_free()
		await process_frame


func _make_scatter_fixture(seed: int) -> ConveyorPrototype:
	var conveyor := CONVEYOR.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.placement_seed = seed
	root.add_child(conveyor)
	await physics_frame
	conveyor.set_physics_process(false)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director.set_process(false)
	conveyor.player.global_position = Vector2(720.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	return conveyor


func _accepted_attempts(director: CollectibleDirector) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in director.offer_log():
		if String(entry.get("event", "")) == "attempt" and bool(entry.get("accepted", false)):
			result.append(entry)
	return result


func _minimum_distance(positions: Array[Vector2]) -> float:
	var result := INF
	for first in range(positions.size()):
		for second in range(first + 1, positions.size()):
			result = minf(result, positions[first].distance_to(positions[second]))
	return result


func _positions_as_candidates(positions: Array[Vector2]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for position in positions:
		result.append({"position": position})
	return result


func _send_slider_touch(control: C2VolumeSlider, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	control._on_slider_gui_input(event)


func _send_mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
	Input.flush_buffered_events()
