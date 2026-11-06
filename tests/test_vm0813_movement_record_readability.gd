extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SESSION_SCENE := preload("res://scenes/presentation/standard_session.tscn")
const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const REVIEW_SCENE := preload("res://scenes/tests/vm081_overload_review.tscn")
const SCORE_PATH := "/tmp/vms-vm0813-standard.cfg"
const AUDIO_PATH := "/tmp/vms-vm0813-audio.cfg"
const OVERLOAD_PATH := "/tmp/vms-vm0813-overload.cfg"
const FLOOR_TOP := 480.0

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
	await _test_single_and_double_jump_contracts()
	await _test_coyote_and_ground_reset_contracts()
	await _test_conveyor_and_landed_can_budget_reset()
	await _test_touch_uses_the_same_second_jump()
	await _test_record_readability_structure()
	await _test_session_movement_wiring()
	await _test_review_record_protection()
	await _test_real_review_keys()
	_cleanup()
	print("VM0813_MOVEMENT_RECORD_READABILITY_FAILURES=", failures)
	quit(failures)


func _test_single_and_double_jump_contracts() -> void:
	var single_fixture := await _make_grounded_player(0)
	var single := single_fixture.player as SharedPlayerController
	var original_values := [single.maximum_speed, single.air_acceleration, single.gravity, single.jump_velocity, single.coyote_time, single.jump_buffering]
	await _press_jump()
	check(single.accepted_jump_count == 1 and is_equal_approx(single.velocity.y, single.jump_velocity), "Single Jump keeps the frozen first impulse")
	await _press_jump()
	check(single.accepted_jump_count == 1 and single.accepted_airborne_jump_count == 0, "Single Jump rejects an airborne second impulse")
	check(
		original_values == [single.maximum_speed, single.air_acceleration, single.gravity, single.jump_velocity, single.coyote_time, single.jump_buffering],
		"Single Jump leaves horizontal movement, gravity, first jump, coyote time, and buffering unchanged"
	)
	await _free_fixture(single_fixture)

	var double_fixture := await _make_grounded_player(1)
	var double := double_fixture.player as SharedPlayerController
	await _press_jump()
	var first_velocity := double.velocity.y
	await _press_jump()
	var second_velocity := double.velocity.y
	check(
		double.accepted_jump_count == 2
		and double.accepted_airborne_jump_count == 1
		and is_equal_approx(first_velocity, double.jump_velocity)
		and is_equal_approx(second_velocity, double.jump_velocity),
		"Double Jump accepts exactly one 100-percent airborne impulse after the unchanged first jump"
	)
	await _press_jump()
	check(double.accepted_jump_count == 2 and double.airborne_jumps_remaining() == 0, "Double Jump rejects a third impulse before landing")
	await _free_fixture(double_fixture)


func _test_coyote_and_ground_reset_contracts() -> void:
	var fixture := await _make_grounded_player(1)
	var player := fixture.player as SharedPlayerController
	var floor := fixture.floor as StaticBody2D
	floor.queue_free()
	await process_frame
	player.set_physics_process(false)
	player.position.y -= 50.0
	player.move_and_slide()
	player._coyote_time_remaining = player.coyote_time
	player._air_jumps_remaining = 1
	check(not player.is_on_floor() and player._coyote_time_remaining > 0.0, "The airborne controller can enter the existing coyote window")
	player._jump_buffer_remaining = player.jump_buffering
	player._try_to_jump()
	player._jump_buffer_remaining = player.jump_buffering
	player._try_to_jump()
	player._jump_buffer_remaining = player.jump_buffering
	player._try_to_jump()
	check(
		player.accepted_jump_count == 2 and player.accepted_airborne_jump_count == 1,
		"Coyote first jump plus one airborne jump cannot become a three-impulse chain"
	)

	var replacement_floor := _make_floor()
	fixture.world.add_child(replacement_floor)
	player._jump_buffer_remaining = player.jump_buffering
	player.position = Vector2(0.0, FLOOR_TOP - 55.0)
	player.velocity = Vector2(0.0, 500.0)
	player.set_physics_process(true)
	for frame in 20:
		await physics_frame
		if player.accepted_jump_count == 3:
			break
	check(
		player.accepted_jump_count == 3
		and player.accepted_airborne_jump_count == 1
		and player.velocity.y < 0.0
		and player.airborne_jumps_remaining() == 1,
		"A buffered landing replenishes the budget and starts a new grounded takeoff, not a third airborne jump"
	)
	await _free_fixture(fixture)


func _test_conveyor_and_landed_can_budget_reset() -> void:
	_release_actions()
	var conveyor := CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	root.add_child(conveyor)
	await _wait_until_grounded(conveyor.player)
	conveyor.player.configure_airborne_jump_experiment(1, 1.0)
	check(
		conveyor.player.get_platform_velocity() == conveyor.conveyor_support_velocity()
		and conveyor.player.airborne_jumps_remaining() == 1,
		"Grounded conveyor support replenishes the one airborne jump"
	)

	conveyor.drop_lane_positions = PackedFloat32Array([520.0])
	conveyor.player.position.x = 700.0
	await physics_frame
	conveyor.product_spawn_y = conveyor.floor_y - conveyor.product_size.y * 0.5 - 1.0
	conveyor.target_fall_duration = 0.02
	var product := conveyor.force_drop_for_test(0)
	for frame in 30:
		await physics_frame
		if product.is_landed():
			break
	conveyor.player.position = Vector2(
		product.conveyor_center_x(),
		product.position.y - conveyor.landed_product_size.y * 0.5 - 25.0
	)
	conveyor.player.velocity = Vector2.ZERO
	conveyor.player._air_jumps_remaining = 0
	for frame in 12:
		await physics_frame
		if conveyor.player.is_on_floor() and conveyor.player.position.y < 530.0:
			break
	check(
		conveyor.player.is_on_floor()
		and conveyor.player.position.y < 530.0
		and conveyor.player.airborne_jumps_remaining() == 1,
		"Landing on a moving landed can replenishes the one airborne jump"
	)
	conveyor.queue_free()
	await process_frame


func _test_touch_uses_the_same_second_jump() -> void:
	var fixture := await _make_grounded_player(1)
	var player := fixture.player as SharedPlayerController
	var touch := StandardTouchControls.new()
	root.add_child(touch)
	touch.size = Vector2(1152, 648)
	touch.touch_available = true
	touch.set_game_active(true)
	await process_frame
	touch.configure_viewport(Vector2(1152,648), Rect2(0,0,1152,648), Vector2(1152,648), 1.0)
	var jump_position := touch.rectangles[2].get_center()
	var direction_press := InputEventScreenTouch.new()
	direction_press.index = 0
	direction_press.position = touch.rectangles[1].get_center()
	direction_press.pressed = true
	Input.parse_input_event(direction_press)
	Input.flush_buffered_events()
	await _touch_jump(jump_position)
	await _touch_jump(jump_position)
	await _touch_jump(jump_position)
	check(
		player.accepted_jump_count == 2 and player.accepted_airborne_jump_count == 1
		and Input.is_action_pressed("move_right"),
		"Mobile RIGHT remains held through first, second and rejected third Jump presses"
	)
	touch.set_game_active(false)
	await _free_fixture(fixture)
	fixture = await _make_grounded_player(1)
	player = fixture.player as SharedPlayerController
	touch.set_game_active(true)
	direction_press.position = touch.rectangles[0].get_center()
	Input.parse_input_event(direction_press)
	Input.flush_buffered_events()
	await _touch_jump(jump_position)
	await _touch_jump(jump_position)
	check(
		player.accepted_jump_count == 2 and player.accepted_airborne_jump_count == 1
		and Input.is_action_pressed("move_left"),
		"Mobile LEFT remains held through first and second Jump presses"
	)
	touch.set_game_active(false)
	touch.queue_free()
	await _free_fixture(fixture)


func _test_record_readability_structure() -> void:
	var session := _make_session()
	root.add_child(session)
	await process_frame
	session.show_mode_select()
	await process_frame
	var standard_label := session._c2.get_node("StandardRecordLabel") as C2PixelText
	var standard_value := session._c2.get_node("StandardRecordValue") as C2PixelText
	var overload_label := session._c2.get_node("OverloadRecordLabel") as C2PixelText
	var overload_value := session._c2.get_node("OverloadRecordValue") as C2PixelText
	check(standard_value.text == "0" and overload_value.text == "--", "Mode Select visibly distinguishes a zero Standard record from a missing Overload record")
	check(
		standard_label.text.contains("BEST") and overload_label.text.contains("BEST")
		and standard_label.position.y >= 560.0 and overload_label.position.y >= 560.0
		and standard_value.position.y == 576.0 and overload_value.position.y == 576.0
		and standard_label.color == StandardSession.INK and overload_label.color == StandardSession.INK,
		"Each Best is attached below its own mode control on the high-contrast cream control region"
	)
	var positions := [standard_label.position, standard_value.position, overload_label.position, overload_value.position]
	(session._c2.get_node("standard") as Button).mouse_entered.emit()
	(session._c2.get_node("overload") as Button).mouse_entered.emit()
	check(positions == [standard_label.position, standard_value.position, overload_label.position, overload_value.position], "Record anchors remain fixed across mode focus changes")
	for viewport_size in [Vector2i(844,390), Vector2i(640,360)]:
		var fitted := MotionExperimentShell.contained_rect(Vector2(viewport_size), Vector2(1152,648))
		var bottom := fitted.position.y + (standard_value.position.y + 36.0) * fitted.size.y / 648.0
		check(bottom <= viewport_size.y and bottom > 0.0, "%dx%d scaling keeps both Best values inside the visible viewport" % [viewport_size.x, viewport_size.y])
	session.queue_free()
	await process_frame


func _test_review_record_protection() -> void:
	var session := _make_session()
	session.debug_movement_review_enabled = true
	root.add_child(session)
	await process_frame
	session.start_standard_game()
	await process_frame
	session._show_results(12, false)
	check(session.scores.best_score == 0, "Movement review Standard runs cannot write records")
	session.start_overload_game()
	await process_frame
	session.last_survival_seconds = 65.0
	session._show_results(9, false)
	check(not session.overload_records.has_best_score, "Movement review Overload runs cannot write records")
	session.start_overload_game()
	await process_frame
	check(
		session._debug_intensity_label.text.contains("MOVEMENT: SINGLE")
		and session._debug_intensity_label.text.contains("RECORDS DISABLED"),
		"Review gameplay explicitly identifies movement and record-write isolation"
	)
	session.queue_free()
	await process_frame


func _test_session_movement_wiring() -> void:
	var single_session := _make_session()
	root.add_child(single_session)
	await process_frame
	single_session.start_standard_game()
	await process_frame
	check(
		single_session.game.conveyor.player.additional_air_jumps == 0
		and single_session.game.build_id_override == "VM-0.8.1.3-SINGLE-JUMP",
		"The default candidate session wires the frozen Single Jump controller"
	)
	single_session.queue_free()
	await process_frame

	var double_session := _make_session()
	double_session.experimental_additional_air_jumps = 1
	double_session.experimental_airborne_jump_multiplier = 1.0
	root.add_child(double_session)
	await process_frame
	double_session.start_standard_game()
	await process_frame
	check(
		double_session.game.conveyor.player.additional_air_jumps == 1
		and is_equal_approx(double_session.game.conveyor.player.airborne_jump_velocity_multiplier, 1.0)
		and double_session.game.build_id_override == "VM-0.8.1.3-DOUBLE-JUMP-EXPERIMENT",
		"The isolated experiment session wires exactly one full-strength airborne jump"
	)
	var previous_player_id := double_session.game.conveyor.player.get_instance_id()
	double_session.game.conveyor.player.accepted_jump_count = 2
	double_session.game.conveyor.player.accepted_airborne_jump_count = 1
	double_session.start_standard_game()
	await process_frame
	await physics_frame
	check(
		double_session.game.conveyor.player.get_instance_id() != previous_player_id
		and double_session.game.conveyor.player.accepted_jump_count == 0
		and double_session.game.conveyor.player.accepted_airborne_jump_count == 0,
		"Retry or mode recreation clears all movement-experiment state"
	)
	double_session._show_results(99, false)
	check(double_session.scores.best_score == 0, "Standalone Double Jump experiment cannot write Standard records")
	double_session.start_overload_game()
	await process_frame
	double_session.last_survival_seconds = 120.0
	double_session._show_results(99, false)
	check(not double_session.overload_records.has_best_score, "Standalone Double Jump experiment cannot write Overload records")
	double_session.queue_free()
	await process_frame


func _test_real_review_keys() -> void:
	var review := REVIEW_SCENE.instantiate() as Control
	root.add_child(review)
	await process_frame
	await process_frame
	var session := review.get("session") as StandardSession
	_push_review_key(KEY_J)
	await process_frame
	check(
		session.experimental_additional_air_jumps == 1
		and session.game.conveyor.player.additional_air_jumps == 1
		and session._debug_intensity_label.text.contains("MOVEMENT: DOUBLE"),
		"Actual J input recreates the review state with Double Jump and a visible label"
	)
	_push_review_key(KEY_F8)
	await process_frame
	check(
		session.current_mode == StandardSession.RunMode.STANDARD
		and session.game.conveyor.player.additional_air_jumps == 1
		and session._debug_records_disabled(),
		"Actual F8 input switches to Standard while preserving the isolated movement condition"
	)
	_push_review_key(KEY_J)
	await process_frame
	check(
		session.game.conveyor.player.additional_air_jumps == 0
		and session._debug_intensity_label.text.contains("MOVEMENT: SINGLE")
		and session._debug_records_disabled(),
		"Actual J input returns to Single Jump without enabling record writes"
	)
	review.queue_free()
	await process_frame


func _push_review_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	Input.flush_buffered_events()
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)
	Input.flush_buffered_events()


func _make_grounded_player(extra_jumps: int) -> Dictionary:
	_release_actions()
	var world := Node2D.new()
	root.add_child(world)
	var floor := _make_floor()
	world.add_child(floor)
	var player := PLAYER_SCENE.instantiate() as SharedPlayerController
	player.position = Vector2(0.0, FLOOR_TOP - 30.0)
	player.configure_airborne_jump_experiment(extra_jumps, 1.0)
	world.add_child(player)
	await _wait_until_grounded(player)
	return {"world": world, "floor": floor, "player": player}


func _make_floor() -> StaticBody2D:
	var floor := StaticBody2D.new()
	floor.position = Vector2(0.0, 500.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000.0, 40.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _wait_until_grounded(player: SharedPlayerController) -> void:
	for frame in 180:
		await physics_frame
		if player.is_on_floor():
			return
	check(false, "Player reaches support within the physics-frame budget")


func _press_jump() -> void:
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame


func _touch_jump(position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 4
	press.position = position
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await physics_frame
	var release := press.duplicate() as InputEventScreenTouch
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await physics_frame


func _free_fixture(fixture: Dictionary) -> void:
	_release_actions()
	(fixture.world as Node).queue_free()
	await process_frame


func _make_session() -> StandardSession:
	var session := SESSION_SCENE.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = SCORE_PATH
	session.audio_settings_path = AUDIO_PATH
	session.overload_storage_path = OVERLOAD_PATH
	return session


func _release_actions() -> void:
	for action in [&"move_left", &"move_right", &"jump"]:
		Input.action_release(action)


func _cleanup() -> void:
	_release_actions()
	for path in [SCORE_PATH, AUDIO_PATH, OVERLOAD_PATH]:
		DirAccess.remove_absolute(path)
