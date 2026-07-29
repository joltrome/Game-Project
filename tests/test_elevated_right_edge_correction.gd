extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const FLOAT_TOLERANCE := 0.02

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	await _test_derived_sweeper_geometry()
	await _test_can_top_contact_and_step_down_response()
	await _test_natural_player_relevant_encounters()
	await _test_right_edge_dwell_and_reservation()
	_release_actions()
	print("ELEVATED_RIGHT_EDGE_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_derived_sweeper_geometry() -> void:
	var conveyor := await _make_conveyor(true)
	var grounded_band := conveyor.grounded_player_band_on_belt()
	var can_band := conveyor.grounded_player_band_on_can()
	var sweeper_band := conveyor.sweeper_collision_band()
	var overlap_duration := conveyor.normal_jump_sweeper_overlap_duration()
	_check(
		grounded_band.is_equal_approx(Vector2(536.0, 584.0)),
		"Grounded player interval is derived from the 48 px collision shape"
	)
	_check(
		can_band.is_equal_approx(Vector2(488.0, 536.0)),
		"Can-top player interval includes the configured 48 px can height"
	)
	_check(
		sweeper_band.is_equal_approx(Vector2(504.0, 532.0)),
		"Sweeper Arm interval is derived instead of visually guessed"
	)
	_check(
		absf(
			conveyor.grounded_sweeper_clearance_actual()
			- conveyor.grounded_sweeper_clearance
		) <= FLOAT_TOLERANCE,
		"Derived arm preserves the configured grounded clearance"
	)
	_check(
		conveyor.sweeper_clears_grounded_player()
		and conveyor.sweeper_overlaps_player_on_can(),
		"One fixed band clears the grounded player and overlaps can-top standing"
	)
	_check(
		overlap_duration >= 0.25
		and conveyor.normal_jump_sweeper_overlap_intervals().size() == 2,
		"Normal jump crosses the arm on ascent and descent for a meaningful interval"
	)
	print(
		"SWEEPER_GEOMETRY_METRICS grounded=%s can_top=%s sweeper=%s clearance=%.3f jump_overlap=%.3f intervals=%s"
		% [
			grounded_band,
			can_band,
			sweeper_band,
			conveyor.grounded_sweeper_clearance_actual(),
			overlap_duration,
			conveyor.normal_jump_sweeper_overlap_intervals(),
		]
	)
	await _free_conveyor(conveyor)

	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var resized := scene.instantiate() as ConveyorPrototype
	resized.initial_warning_delay = 999.0
	resized.left_failure_enabled = false
	resized.landed_product_size = Vector2(72.0, 64.0)
	resized.sweeper_size = Vector2(96.0, 32.0)
	resized.grounded_sweeper_clearance = 6.0
	var player_shape_node := (
		resized.get_node("Player/CollisionShape2D") as CollisionShape2D
	)
	player_shape_node.shape = player_shape_node.shape.duplicate()
	(player_shape_node.shape as RectangleShape2D).size = Vector2(32.0, 56.0)
	root.add_child(resized)
	await physics_frame
	_check(
		absf(resized.grounded_sweeper_clearance_actual() - 6.0)
			<= FLOAT_TOLERANCE
		and resized.sweeper_overlaps_player_on_can()
		and resized.sweeper_intersects_jump_arc(),
		"Derived geometry remains valid for supported player, can, and arm dimensions"
	)
	await _free_conveyor(resized)


func _test_can_top_contact_and_step_down_response() -> void:
	var conveyor := await _make_conveyor(true)
	var product := await _land_product_at(conveyor, 600.0)
	await _place_player_on_can(conveyor, product)
	_check(
		conveyor.player.is_on_floor(),
		"Player stands stably on the moving can before the arm encounter"
	)
	conveyor.force_pattern_for_test(
		ConveyorPrototype.PatternType.SWEEPER_ONLY
	)
	await _wait_until_sweeper_finishes_or_death(conveyor)
	_check(
		conveyor.is_dead,
		"Player standing on a landed can is vulnerable to the Sweeper Arm"
	)
	await _free_conveyor(conveyor)

	conveyor = await _make_conveyor(true)
	product = await _land_product_at(conveyor, 600.0)
	await _place_player_on_can(conveyor, product)
	Input.action_press("move_left")
	await _wait_physics_frames(18)
	Input.action_release("move_left")
	await _wait_physics_frames(18)
	_check(
		conveyor.player.is_on_floor()
		and conveyor.player.position.y > 540.0,
		"Player can step from the can down to the conveyor"
	)
	conveyor.force_pattern_for_test(
		ConveyorPrototype.PatternType.SWEEPER_ONLY
	)
	await _wait_until_sweeper_finishes_or_death(conveyor)
	_check(
		not conveyor.is_dead,
		"Remaining grounded after stepping down passes safely under the arm"
	)
	await _free_conveyor(conveyor)


func _test_natural_player_relevant_encounters() -> void:
	var conveyor := await _make_conveyor(false)
	var relevant_times: Array[float] = []
	var compound_times: Array[float] = []
	conveyor.sweeper_reached_player_region.connect(
		func(
			_pattern_type: int,
			reached_at: float,
			_player_x: float
		) -> void:
			relevant_times.append(reached_at)
	)
	conveyor.compound_decision_reached.connect(
		func(_pattern_type: int, reached_at: float) -> void:
			compound_times.append(reached_at)
	)
	Input.action_press("move_right")
	await _wait_physics_frames(
		ceili(25.0 * Engine.physics_ticks_per_second)
	)
	Input.action_release("move_right")

	var first_relevant := (
		relevant_times[0] if not relevant_times.is_empty() else INF
	)
	var first_compound := (
		compound_times[0] if not compound_times.is_empty() else INF
	)
	var maximum_gap := 0.0
	for index in range(1, relevant_times.size()):
		if relevant_times[index] < conveyor.teaching_phase_end:
			continue
		maximum_gap = maxf(
			maximum_gap,
			relevant_times[index] - relevant_times[index - 1]
		)
	_check(
		first_relevant >= conveyor.first_relevant_sweeper_target_min
		and first_relevant <= conveyor.first_relevant_sweeper_target_max,
		"Natural movement lifecycle reaches the player with the first arm in 3–4 seconds"
	)
	_check(
		first_compound >= conveyor.first_compound_decision_target_min
		and first_compound <= conveyor.first_compound_decision_target_max,
		"First compound decision reaches the player in 5–7 seconds"
	)
	_check(
		maximum_gap <= conveyor.maximum_relevant_sweeper_gap + 0.05,
		"Post-teaching player-relevant arm gaps stay inside the configured bound"
	)
	_check(
		_count_log_event(conveyor.encounter_log(), "pattern_selection") > 0
		and _count_log_event(conveyor.encounter_log(), "sweeper_spawn") > 0
		and _count_log_event(
			conveyor.encounter_log(),
			"sweeper_player_region"
		) > 0
		and _count_log_event(
			conveyor.encounter_log(),
			"compound_decision"
		) > 0,
		"Encounter log distinguishes selection, spawn, player arrival, and compound decision"
	)
	print(
		"PLAYER_RELEVANT_METRICS first_sweeper=%.3f first_compound=%.3f max_gap=%.3f sweeper_count=%d compound_count=%d times=%s"
		% [
			first_relevant,
			first_compound,
			maximum_gap,
			relevant_times.size(),
			compound_times.size(),
			relevant_times,
		]
	)
	await _free_conveyor(conveyor)


func _test_right_edge_dwell_and_reservation() -> void:
	var conveyor := await _make_conveyor(true)
	conveyor.player.position.x = conveyor.control_band_right
	Input.action_press("move_right")
	await _wait_physics_frames(
		floori(
			conveyor.right_edge_dwell_threshold
			* Engine.physics_ticks_per_second
			* 0.5
		)
	)
	_check(
		not conveyor.right_pressure_is_requested(),
		"Brief right-zone entry does not reserve pressure"
	)
	conveyor.player.position.x = conveyor.right_edge_zone_left() - 40.0
	Input.action_release("move_right")
	await _wait_physics_frames(3)
	_check(
		conveyor.right_edge_dwell_time() == 0.0,
		"Leaving before the threshold resets continuous dwell"
	)

	conveyor.player.position.x = conveyor.control_band_right
	Input.action_press("move_right")
	await _wait_physics_frames(
		ceili(
			(conveyor.right_edge_dwell_threshold + 0.1)
			* Engine.physics_ticks_per_second
		)
	)
	Input.action_release("move_right")
	_check(
		conveyor.right_pressure_is_requested()
		and absf(
			conveyor.right_pressure_target_x()
			- conveyor.control_band_right
		) <= FLOAT_TOLERANCE,
		"Sustained right-edge dwell reserves pressure at the actual player region"
	)

	conveyor.maximum_active_sweepers = 0
	var started_while_invalid := conveyor.force_pattern_for_test(
		ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE
	)
	_check(
		not started_while_invalid
		and conveyor.reserved_pattern_type()
			== ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE,
		"Temporarily invalid targeted pressure remains reserved"
	)
	conveyor.maximum_active_sweepers = 1
	for _frame in range(180):
		await physics_frame
		if (
			conveyor.active_pattern_type()
				== ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE
			or conveyor.last_pattern_type()
				== ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE
		):
			break
	_check(
		not conveyor.right_pressure_is_requested()
		and conveyor.last_pattern_type()
			== ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE,
		"Valid targeted launch clears its request without downgrading"
	)

	for _frame in range(180):
		await physics_frame
		if conveyor.warning_is_visible():
			break
	var warning_x := conveyor.current_warning_x()
	var target_x := conveyor.right_pressure_target_x()
	var threat_half_width := (
		conveyor.product_size.x * 0.5
		+ conveyor.player_collision_size().x * 0.5
	)
	_check(
		conveyor.warning_is_visible()
		and absf(warning_x - target_x) <= FLOAT_TOLERANCE
		and absf(warning_x - target_x) <= threat_half_width,
		"Targeted can warning covers the recorded right-side player region"
	)
	var metrics := conveyor.right_pressure_response_metrics(
		conveyor.survival_time,
		target_x
	)
	_check(
		conveyor.jump_time_overlaps_sweeper(
			metrics.blind_jump_intercept
		),
		"Blind immediate jump timing intersects the arm collision band"
	)
	_check(
		metrics.delayed_ground_response_margin
			+ 0.0001 >= conveyor.right_pressure_minimum_margin,
		"Targeted pattern retains a validated grounded-delay response"
	)
	print(
		"RIGHT_PRESSURE_METRICS zone_width=%.3f dwell=%.3f target=%.3f blind_intercept=%.3f delayed_margin=%.3f"
		% [
			conveyor.right_edge_zone_width,
			conveyor.right_edge_dwell_threshold,
			target_x,
			metrics.blind_jump_intercept,
			metrics.delayed_ground_response_margin,
		]
	)
	await _free_conveyor(conveyor)


func _land_product_at(
	conveyor: ConveyorPrototype,
	x_position: float
) -> ConveyorProduct:
	conveyor.player.position.x = clampf(
		x_position + 120.0,
		conveyor.control_band_left,
		conveyor.control_band_right
	)
	await physics_frame
	conveyor.drop_lane_positions = PackedFloat32Array([x_position])
	conveyor.product_spawn_y = (
		conveyor.floor_y - conveyor.product_size.y * 0.5 - 1.0
	)
	conveyor.target_fall_duration = 0.02
	var product := conveyor.force_drop_for_test(0)
	for _frame in range(30):
		await physics_frame
		if is_instance_valid(product) and product.is_landed():
			break
	await _wait_physics_frames(3)
	return product


func _place_player_on_can(
	conveyor: ConveyorPrototype,
	product: ConveyorProduct
) -> void:
	conveyor.player.position = Vector2(
		product.conveyor_center_x(),
		product.position.y
			- conveyor.landed_product_size.y * 0.5
			- conveyor.player_collision_size().y * 0.5
			- 1.0
	)
	conveyor.player.velocity = Vector2.ZERO
	await _wait_physics_frames(8)


func _wait_until_sweeper_finishes_or_death(
	conveyor: ConveyorPrototype
) -> void:
	var saw_sweeper := false
	for _frame in range(300):
		await physics_frame
		saw_sweeper = saw_sweeper or conveyor.active_sweeper_count() > 0
		if conveyor.is_dead:
			return
		if saw_sweeper and conveyor.active_sweeper_count() == 0:
			return


func _count_log_event(log_records: Array[Dictionary], event_name: String) -> int:
	var count := 0
	for record in log_records:
		if record.event == event_name:
			count += 1
	return count


func _make_conveyor(disable_scheduler: bool) -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	conveyor.left_failure_enabled = false
	if disable_scheduler:
		conveyor.initial_warning_delay = 999.0
	root.add_child(conveyor)
	await physics_frame
	if not disable_scheduler:
		conveyor.player.collision_layer = 0
	return conveyor


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _free_conveyor(conveyor: ConveyorPrototype) -> void:
	if is_instance_valid(conveyor):
		conveyor.queue_free()
	await process_frame
	_release_actions()


func _release_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
