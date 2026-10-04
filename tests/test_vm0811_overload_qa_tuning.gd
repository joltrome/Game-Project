extends SceneTree

const SESSION_SCENE := preload("res://scenes/presentation/standard_session.tscn")
const SHELL_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const SCORE_PATH := "/tmp/vms-vm0811-standard.cfg"
const AUDIO_PATH := "/tmp/vms-vm0811-audio.cfg"
const OVERLOAD_PATH := "/tmp/vms-vm0811-overload.cfg"

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
	_cleanup()
	await _test_mode_select_interactions()
	await _test_real_intensity_review_and_record_protection()
	await _test_late_d3_overlap_and_standard_freeze()
	_cleanup()
	print("VM0811_OVERLOAD_QA_TUNING_FAILURES=", failures)
	quit(failures)


func _test_mode_select_interactions() -> void:
	var session := _make_session()
	root.add_child(session)
	await process_frame
	(session._c2.get_node("clock_in") as Button).pressed.emit()
	await process_frame
	var screen := session._c2
	var standard := screen.get_node("standard") as Button
	var overload := screen.get_node("overload") as Button
	var back := screen.get_node("back") as Button
	check(
		_art_state(standard) == "idle" and _art_state(overload) == "idle" and _art_state(back) == "idle",
		"Mode Select opens visually neutral even though keyboard focus remains available"
	)
	check(
		not screen.keyboard_focus_visuals_enabled()
		and screen.active_overload_visual_button() == null,
		"Initial logical focus is hidden until a navigation modality is used"
	)
	overload.mouse_entered.emit()
	check(
		_art_state(overload) == "focus" and _art_state(standard) == "idle",
		"Mouse hover gives visual precedence to only the hovered mode"
	)
	check(
		(screen.get_node("ModeRecordLabel") as C2PixelText).text == "OVERLOAD BEST",
		"Overload hover updates the persistent record display in place"
	)
	overload.mouse_exited.emit()
	check(
		_art_state(overload) == "idle" and _art_state(standard) == "idle",
		"Mouse exit restores the neutral visual state"
	)
	_push_key(KEY_RIGHT)
	await process_frame
	check(
		overload.has_focus() and _art_state(overload) == "focus" and _art_state(standard) == "idle",
		"Actual directional input activates keyboard focus and moves to Overload"
	)
	_push_key(KEY_LEFT)
	await process_frame
	check(
		standard.has_focus() and _art_state(standard) == "focus" and _art_state(overload) == "idle",
		"Keyboard focus movement never leaves two mode choices highlighted"
	)
	overload.button_down.emit()
	check(
		_art_state(overload) == "pressed" and _art_state(standard) == "idle",
		"Pressed artwork is exclusive to the activated control"
	)
	overload.button_up.emit()
	for index in 8:
		var target := standard if index % 2 == 0 else overload
		target.mouse_entered.emit()
		check(
			screen.get_children().filter(func(child: Node) -> bool: return child.name == "ModeRecordLabel").size() == 1
			and screen.get_children().filter(func(child: Node) -> bool: return child.name == "ModeRecordValue").size() == 1,
			"Rapid record switching keeps exactly one persistent label/value pair"
		)
		target.mouse_exited.emit()

	# Exercise the displayed hint through the real viewport input path. Escape is
	# also mapped to Pause, so this catches the original branch-order regression.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	Input.flush_buffered_events()
	await process_frame
	check(session.state == StandardSession.State.MENU, "Actual Escape input performs MODE_SELECT -> MENU")

	(session._c2.get_node("clock_in") as Button).pressed.emit()
	await process_frame
	(session._c2.get_node("back") as Button).pressed.emit()
	await process_frame
	check(session.state == StandardSession.State.MENU, "Back button click returns Mode Select to Main Menu")

	(session._c2.get_node("clock_in") as Button).pressed.emit()
	await process_frame
	standard = session._c2.get_node("standard") as Button
	_push_key(KEY_ENTER)
	await process_frame
	await physics_frame
	check(session.state == StandardSession.State.GAME and session.current_mode == StandardSession.RunMode.STANDARD, "Enter activates the focused Standard control")
	session.show_menu()
	await process_frame
	(session._c2.get_node("clock_in") as Button).pressed.emit()
	await process_frame
	overload = session._c2.get_node("overload") as Button
	overload.grab_focus()
	session._c2.activate_keyboard_focus_visuals()
	_push_key(KEY_SPACE)
	await process_frame
	await physics_frame
	check(session.state == StandardSession.State.GAME and session.current_mode == StandardSession.RunMode.OVERLOAD, "Space activates the focused Overload control")
	session.queue_free()
	await process_frame


func _test_real_intensity_review_and_record_protection() -> void:
	var expected_conveyor := PackedFloat32Array([1.25, 1.35, 1.425, 1.47, 1.50, 1.50])
	var expected_sweeper := PackedFloat32Array([1.15, 1.25, 1.35, 1.45, 1.55, 1.60])
	var expected_hazard := PackedFloat32Array([1.12, 1.25, 1.35, 1.45, 1.52, 1.58])
	var expected_cooldown := PackedFloat32Array([0.50, 0.42, 0.35, 0.30, 0.27, 0.25])
	var expected_margin := PackedFloat32Array([0.50, 0.44, 0.39, 0.35, 0.32, 0.30])
	var expected_stages := [
		OverloadEmergencyVisual.Stage.UNSTABLE,
		OverloadEmergencyVisual.Stage.WARNING,
		OverloadEmergencyVisual.Stage.CRITICAL,
		OverloadEmergencyVisual.Stage.SEVERE,
		OverloadEmergencyVisual.Stage.CATASTROPHIC,
		OverloadEmergencyVisual.Stage.MAX,
	]
	var checkpoints := PackedFloat32Array([0.0, 15.0, 30.0, 45.0, 60.0, 90.0])
	var session := _make_session()
	session.debug_intensity_review_enabled = true
	root.add_child(session)
	await process_frame
	for index in checkpoints.size():
		session.debug_intensity_checkpoint_seconds = checkpoints[index]
		session.start_overload_game()
		await process_frame
		await physics_frame
		var conveyor := session.game.conveyor
		var snapshot := conveyor.overload_intensity_snapshot(checkpoints[index])
		check(
			is_equal_approx(float(snapshot.conveyor_multiplier), expected_conveyor[index])
			and is_equal_approx(float(snapshot.sweeper_multiplier), expected_sweeper[index])
			and is_equal_approx(float(snapshot.hazard_multiplier), expected_hazard[index])
			and is_equal_approx(float(snapshot.pattern_cooldown), expected_cooldown[index])
			and is_equal_approx(float(snapshot.compound_margin), expected_margin[index]),
			"Review checkpoint %.0f applies the complete authored mechanical intensity" % checkpoints[index]
		)
		check(
			absf(conveyor.survival_time - checkpoints[index]) <= 0.05
			and session.game.overload_emergency_visual.current_stage == expected_stages[index]
			and session.game.background_drop_director.endless_schedule_enabled
			and session.game.background_drop_director.next_reservation_time > checkpoints[index],
			"Review checkpoint %.0f seeks actual visual and endless D3 scheduler state" % checkpoints[index]
		)
		check(
			session._debug_intensity_label.text.contains("RECORDS DISABLED"),
			"Review checkpoint %.0f is immediately playable and clearly marked development-only" % checkpoints[index]
		)

	var best_before := session.overload_records.best_score
	session.last_survival_seconds = 90.0
	session._show_results(12, false)
	check(
		session.overload_records.best_score == best_before
		and not session.last_overload_new_best,
		"Forced-intensity outcomes never update Overload records"
	)
	session.queue_free()
	await process_frame


func _test_late_d3_overlap_and_standard_freeze() -> void:
	var shell := SHELL_SCENE.instantiate() as MotionExperimentShell
	shell.overload_mode_enabled = true
	shell.vm081_presentation_enabled = true
	root.add_child(shell)
	await process_frame
	shell.apply_overload_review_checkpoint(45.0)
	var conveyor := shell.conveyor
	conveyor.set_physics_process(false)
	conveyor._clear_pattern_state()
	conveyor.set_external_product_event_pending(true)
	conveyor.set_external_product_sequence_active(true)
	var launched := conveyor._try_start_reserved_pattern()
	check(
		launched
		and conveyor._sweeper_spawn_pending
		and conveyor._pending_sweeper_pattern_type == ConveyorPrototype.PatternType.SWEEPER_ONLY
		and conveyor.pattern_is_solvable(ConveyorPrototype.PatternType.SWEEPER_ONLY, 45.0),
		"Late Overload can overlap one validator-approved electrical sweep with an active D3 sequence"
	)
	check(
		conveyor.maximum_active_sweepers == 1
		and conveyor.maximum_concurrent_falling_cans == 1
		and conveyor.sweeper_size == Vector2(96, 28)
		and is_equal_approx(conveyor.sweeper_entry_cue_duration, 0.20),
		"Concurrency tuning preserves the single-sweeper/single-falling limits and frozen electrical geometry/timing"
	)
	shell.queue_free()
	await process_frame

	var standard_shell := SHELL_SCENE.instantiate() as MotionExperimentShell
	root.add_child(standard_shell)
	await process_frame
	var standard := standard_shell.conveyor
	var director := standard.get_node("CollectibleDirector") as CollectibleDirector
	check(
		not standard.overload_mode_enabled
		and is_equal_approx(standard.conveyor_speed_at(0.0), 140.0)
		and is_equal_approx(standard.conveyor_speed_at(60.0), 175.0)
		and standard.pattern_weights_at(60.0) == PackedInt32Array([0, 0, 50, 50])
		and director.bounded_event_total_attempts == 0,
		"Standard difficulty and coin-planning behavior retain their frozen values"
	)
	standard_shell.queue_free()
	await process_frame


func _make_session() -> StandardSession:
	var session := SESSION_SCENE.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = SCORE_PATH
	session.audio_settings_path = AUDIO_PATH
	session.overload_storage_path = OVERLOAD_PATH
	return session


func _art_state(button: Button) -> String:
	var path := (button.get_node("Artwork") as TextureRect).texture.resource_path
	for state in ["pressed", "focus", "idle"]:
		if path.contains("-%s" % state):
			return state
	return "unknown"


func _cleanup() -> void:
	for path in [SCORE_PATH, AUDIO_PATH, OVERLOAD_PATH]:
		DirAccess.remove_absolute(path)


func _push_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event, true)
	Input.flush_buffered_events()
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)
	Input.flush_buffered_events()
