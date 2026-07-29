extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const ARENA_SCENE_PATH := "res://scenes/prototypes/arena.tscn"
const POSITION_TOLERANCE := 2.0

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
	await _test_left_edge_is_not_a_lethal_wall()
	await _test_can_support_at_edge_and_off_belt_failure()
	await _test_grounded_sweeper_clearance_and_cleanup()
	await _test_jump_band_contact_kills_once()
	await _test_all_controlled_patterns_and_solvability()
	await _test_reserved_compound_pattern_never_downgrades()
	await _test_prototype_a_and_shared_values_unchanged()
	_release_actions()
	print("AIR_SWEEPER_PATTERN_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_left_edge_is_not_a_lethal_wall() -> void:
	var conveyor := await _make_conveyor(true)
	var last_supported_center := (
		conveyor.conveyor_support_left_x + 16.0
	)
	conveyor.player.position = Vector2(last_supported_center, 552.0)
	conveyor.player.velocity = Vector2.ZERO
	await _wait_physics_frames(4)
	_check(
		not conveyor.is_dead,
		"Merely touching the conveyor's supported left edge is non-lethal"
	)

	conveyor.player.position = Vector2(conveyor.control_band_right, 552.0)
	conveyor.player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await _wait_physics_frames(6)
	Input.action_release("move_right")
	_check(
		not conveyor.is_dead,
		"Collision with the unrelated right control wall does not call death"
	)
	await _free_conveyor(conveyor)


func _test_can_support_at_edge_and_off_belt_failure() -> void:
	var conveyor := await _make_conveyor(true)
	conveyor.drop_lane_positions = PackedFloat32Array([220.0])
	conveyor.product_spawn_y = (
		conveyor.floor_y - conveyor.product_size.y * 0.5 - 1.0
	)
	conveyor.target_fall_duration = 0.02
	var product := conveyor.force_drop_for_test(0)
	await _wait_for_landed(product)
	_place_player_on_can(conveyor, product)
	await _wait_physics_frames(6)
	_check(
		conveyor.player.is_on_floor() and not conveyor.is_dead,
		"Standing on a landed can near the left edge is not immediately lethal"
	)

	var carried_to_failure := false
	for _frame in range(180):
		await physics_frame
		if conveyor.is_dead:
			carried_to_failure = true
			break
	_check(
		carried_to_failure,
		"A moving can can carry the player off support into the kill region"
	)
	_check(
		conveyor.player.position.x < conveyor.conveyor_support_left_x,
		"Failure occurs only after the player visibly crosses the conveyor end"
	)
	await _free_conveyor(conveyor)

	conveyor = await _make_conveyor(true)
	conveyor.player.position = Vector2(80.0, 620.0)
	await _wait_physics_frames(2)
	_check(
		conveyor.is_dead,
		"Entering the explicit recessed off-belt region is lethal"
	)
	await _free_conveyor(conveyor)


func _test_grounded_sweeper_clearance_and_cleanup() -> void:
	var conveyor := await _make_conveyor(false)
	conveyor.player.position = Vector2(176.0, 552.0)
	conveyor.player.velocity = Vector2.ZERO
	var spawn_record := {
		"x": INF,
		"y": INF,
		"cue_y": INF,
	}
	conveyor.sweeper_entry_cue_started.connect(
		func(altitude: float, _duration: float) -> void:
			spawn_record.cue_y = altitude
	)
	conveyor.sweeper_spawned.connect(
		func(sweeper: AirSweeper) -> void:
			spawn_record.x = sweeper.position.x
			spawn_record.y = sweeper.position.y
	)
	_check(
		conveyor.force_pattern_for_test(
			ConveyorPrototype.PatternType.SWEEPER_ONLY
		),
		"Sweeper-only pattern starts from the controlled scheduler"
	)
	_check(
		conveyor.sweeper_cue_is_visible()
		and absf(
			conveyor.sweeper_cue_altitude() - conveyor.sweeper_altitude
		) <= POSITION_TOLERANCE,
		"Left-entry cue is visible and aligned to the physical hazard altitude"
	)

	var saw_sweeper := false
	for _frame in range(240):
		await physics_frame
		saw_sweeper = saw_sweeper or conveyor.active_sweeper_count() > 0
		if saw_sweeper and conveyor.active_sweeper_count() == 0:
			break
	_check(saw_sweeper, "Sweeper visibly enters from the left")
	_check(
		not conveyor.is_dead,
		"Grounded player safely passes beneath the sweeper"
	)
	_check(
		conveyor.active_sweeper_count() == 0,
		"Sweeper exits right and despawns"
	)
	_check(
		absf(spawn_record.x - conveyor.sweeper_spawn_x)
			<= POSITION_TOLERANCE
		and absf(spawn_record.y - spawn_record.cue_y)
			<= POSITION_TOLERANCE,
		"Spawned sweeper begins at the configured entry and cue altitude"
	)
	await _free_conveyor(conveyor)


func _test_jump_band_contact_kills_once() -> void:
	var conveyor := await _make_conveyor(false)
	conveyor.player.position = Vector2(176.0, 552.0)
	conveyor.player.velocity = Vector2.ZERO
	var death_record := {"count": 0}
	conveyor.player_died.connect(
		func() -> void:
			death_record.count += 1
	)
	conveyor.force_pattern_for_test(
		ConveyorPrototype.PatternType.SWEEPER_ONLY
	)
	for _frame in range(30):
		await physics_frame
		if conveyor.active_sweeper_count() > 0:
			break
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for _frame in range(90):
		await physics_frame
		if conveyor.is_dead:
			break
	_check(
		conveyor.is_dead,
		"An ordinary jumping player can collide with the sweeper"
	)
	await _wait_physics_frames(8)
	_check(
		death_record.count == 1,
		"Sweeper contact triggers the death flow exactly once"
	)
	await _free_conveyor(conveyor)


func _test_all_controlled_patterns_and_solvability() -> void:
	var expected_events := {
		ConveyorPrototype.PatternType.CAN_ONLY: [
			ConveyorPrototype.PatternEventType.CAN,
		],
		ConveyorPrototype.PatternType.SWEEPER_ONLY: [
			ConveyorPrototype.PatternEventType.SWEEPER,
		],
		ConveyorPrototype.PatternType.SWEEPER_THEN_CAN: [
			ConveyorPrototype.PatternEventType.SWEEPER,
			ConveyorPrototype.PatternEventType.CAN,
		],
		ConveyorPrototype.PatternType.CAN_THEN_SWEEPER: [
			ConveyorPrototype.PatternEventType.CAN,
			ConveyorPrototype.PatternEventType.SWEEPER,
		],
	}
	for pattern_type in expected_events:
		var conveyor := await _make_conveyor(false)
		var started_types: Array[int] = []
		var triggered_events: Array[int] = []
		conveyor.pattern_started.connect(
			func(started_type: int, _time: float) -> void:
				started_types.append(started_type)
		)
		conveyor.pattern_event_triggered.connect(
			func(
				_started_type: int,
				event_type: int,
				_offset: float
			) -> void:
				triggered_events.append(event_type)
		)
		_check(
			conveyor.pattern_is_solvable(pattern_type),
			"Pattern %d has a validated feasible response" % pattern_type
		)
		_check(
			conveyor.force_pattern_for_test(pattern_type),
			"Pattern %d commits without substitution" % pattern_type
		)
		var wait_seconds := (
			maxf(
				conveyor.compound_offset_for_pattern(
					ConveyorPrototype.PatternType.SWEEPER_THEN_CAN,
					conveyor.survival_time
				),
				conveyor.compound_offset_for_pattern(
					ConveyorPrototype.PatternType.CAN_THEN_SWEEPER,
					conveyor.survival_time
				)
			)
			+ conveyor.sweeper_entry_cue_duration
			+ 0.2
		)
		await _wait_physics_frames(
			ceili(wait_seconds * Engine.physics_ticks_per_second)
		)
		_check(
			not started_types.is_empty()
			and started_types[0] == pattern_type,
			"Selected pattern %d executes first as the same pattern type"
			% pattern_type
		)
		var expected_pattern_events: Array = expected_events[pattern_type]
		_check(
			triggered_events.size() >= expected_pattern_events.size()
			and triggered_events.slice(
				0,
				expected_pattern_events.size()
			) == expected_pattern_events,
			"Pattern %d triggers its exact ordered events" % pattern_type
		)
		await _free_conveyor(conveyor)

	var timing_conveyor := await _make_conveyor(false)
	var timing_checkpoint := 5.0
	_check(
		timing_conveyor.compound_response_margin_for_pattern(
			ConveyorPrototype.PatternType.SWEEPER_THEN_CAN,
			timing_checkpoint
		) + 0.0001
			>= timing_conveyor.compound_margin_at(timing_checkpoint),
		"Sweeper-then-can leaves time to wait before the can response"
	)
	_check(
		timing_conveyor.compound_response_margin_for_pattern(
			ConveyorPrototype.PatternType.CAN_THEN_SWEEPER,
			timing_checkpoint
		) + 0.0001
			>= timing_conveyor.compound_margin_at(timing_checkpoint),
		"Can-then-sweeper leaves time for one normal jump and landing"
	)
	_check(
		timing_conveyor.sweeper_clears_grounded_player()
		and timing_conveyor.sweeper_overlaps_player_on_can()
		and timing_conveyor.sweeper_intersects_jump_arc(),
		"Fixed arm clears ground, threatens can-top standing, and intersects the jump arc"
	)
	await _free_conveyor(timing_conveyor)


func _test_reserved_compound_pattern_never_downgrades() -> void:
	var conveyor := await _make_conveyor(false)
	var started_types: Array[int] = []
	conveyor.pattern_started.connect(
		func(pattern_type: int, _time: float) -> void:
			started_types.append(pattern_type)
	)
	conveyor.force_pattern_for_test(
		ConveyorPrototype.PatternType.SWEEPER_ONLY
	)
	for _frame in range(30):
		await physics_frame
		if conveyor.active_sweeper_count() > 0:
			break
	var reserved_type := ConveyorPrototype.PatternType.SWEEPER_THEN_CAN
	var started_immediately := conveyor.force_pattern_for_test(reserved_type)
	_check(
		not started_immediately
		and conveyor.reserved_pattern_type() == reserved_type,
		"Temporarily blocked compound pattern remains reserved"
	)
	for _frame in range(240):
		await physics_frame
		if started_types.has(reserved_type):
			break
	_check(
		started_types.has(reserved_type)
		and not started_types.has(ConveyorPrototype.PatternType.CAN_ONLY),
		"Reserved compound pattern eventually starts without downgrading to can-only"
	)
	await _free_conveyor(conveyor)


func _test_prototype_a_and_shared_values_unchanged() -> void:
	var arena_scene := load(ARENA_SCENE_PATH) as PackedScene
	var arena := arena_scene.instantiate() as CompactArena
	arena.initial_drop_delay = 999.0
	root.add_child(arena)
	await physics_frame
	_check(
		arena.player.maximum_speed == 300.0
		and arena.player.gravity == 2400.0
		and arena.player.jump_velocity == -700.0
		and arena.player.coyote_time == 0.10
		and arena.player.jump_buffering == 0.12,
		"Prototype A retains the locked VM-0.1.2 shared movement values"
	)
	arena.queue_free()
	await process_frame


func _make_conveyor(failure_enabled: bool) -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = failure_enabled
	root.add_child(conveyor)
	await _wait_physics_frames(3)
	return conveyor


func _place_player_on_can(
	conveyor: ConveyorPrototype,
	product: ConveyorProduct
) -> void:
	conveyor.player.position = Vector2(
		product.conveyor_center_x(),
		product.position.y
			- conveyor.landed_product_size.y * 0.5
			- 25.0
	)
	conveyor.player.velocity = Vector2.ZERO
	await _wait_physics_frames(8)


func _wait_for_landed(product: ConveyorProduct) -> void:
	for _frame in range(30):
		await physics_frame
		if not is_instance_valid(product) or product.is_landed():
			return


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
