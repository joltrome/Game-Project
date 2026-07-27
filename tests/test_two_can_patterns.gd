extends SceneTree

const ARENA_SCENE := preload("res://scenes/prototypes/arena.tscn")
const FLOAT_TOLERANCE := 0.01
const MAX_TEST_FRAMES := 300

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return

	failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	await _test_phase_configuration_and_pattern_enumeration()
	await _test_single_pattern_launch()
	await _test_two_can_pattern_launch_and_occupied_lanes()
	await _test_invalid_pattern_retry()
	await _test_pending_pattern_restart_cleanup()
	print("Two-can pattern validation finished with %d failure(s)." % failures)
	quit(failures)


func _test_phase_configuration_and_pattern_enumeration() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	root.add_child(arena)
	await process_frame
	_disable_player(arena)

	_check(
		absf(arena.two_can_probability_at(0.0)) <= FLOAT_TOLERANCE,
		"Early phase probability is zero"
	)
	_check(
		absf(arena.two_can_probability_at(arena.early_phase_end_seconds) - 0.35)
		<= FLOAT_TOLERANCE,
		"Middle phase probability is 35 percent"
	)
	_check(
		absf(arena.two_can_probability_at(arena.middle_phase_end_seconds) - 0.70)
		<= FLOAT_TOLERANCE,
		"Later phase probability is 70 percent"
	)
	_check(arena.maximum_concurrent_falling_cans == 2, "Concurrent falling cap is two")

	var valid_pair_count := 0
	for first_lane in range(arena.drop_lane_positions.size()):
		for second_lane in range(first_lane + 1, arena.drop_lane_positions.size()):
			var pattern := PackedInt32Array([first_lane, second_lane])
			if not arena.is_pattern_valid(pattern):
				continue
			valid_pair_count += 1
			_check(
				arena.pattern_has_reachable_safe_region(pattern),
				"Every accepted pair has a reachable safe region"
			)
			var separation := absf(
				arena.drop_lane_positions[first_lane]
				- arena.drop_lane_positions[second_lane]
			)
			_check(
				separation >= arena.minimum_landed_spacing,
				"Every accepted pair preserves future platform spacing"
			)
	_check(valid_pair_count > 0, "At least one fair two-can pattern is available")

	arena.queue_free()
	await process_frame


func _test_single_pattern_launch() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	_configure_fast_pattern_test(arena, false)
	var observation := _connect_pattern_observation(arena)
	root.add_child(arena)
	_disable_player(arena)

	await _wait_for_pattern_drop(observation)
	var committed_lanes: PackedInt32Array = observation.committed_lanes
	var dropped_lanes: PackedInt32Array = observation.dropped_lanes
	_check(committed_lanes.size() == 1, "Forced early phase commits a single-can pattern")
	_check(dropped_lanes == committed_lanes, "Single pattern drops its committed lane")
	_check(observation.telegraph_lanes == Array(committed_lanes), "Single drop has one matching warning")
	_check(observation.drop_lanes == Array(committed_lanes), "Single warning produces one matching can")
	_check(observation.valid_at_commit, "Single pattern passes validation before commitment")

	arena.queue_free()
	await process_frame


func _test_two_can_pattern_launch_and_occupied_lanes() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	_configure_fast_pattern_test(arena, true)
	var observation := _connect_pattern_observation(arena)
	root.add_child(arena)
	_disable_player(arena)

	await _wait_for_pattern_drop(observation)
	var committed_lanes: PackedInt32Array = observation.committed_lanes
	var dropped_lanes: PackedInt32Array = observation.dropped_lanes
	_check(committed_lanes.size() == 2, "Forced later phase commits a two-can pattern")
	_check(dropped_lanes == committed_lanes, "Two-can pattern drops both committed lanes")
	_check(observation.telegraph_lanes == Array(committed_lanes), "Each falling can has one matching warning")
	_check(observation.drop_lanes == Array(committed_lanes), "Each warning produces its matching can")
	_check(observation.all_warnings_visible, "Both warning lanes are simultaneously visible")
	_check(observation.all_warning_positions_match, "Both warning chutes match their logical lanes")
	_check(observation.falling_count_at_drop == 2, "Two cans become concurrent on pattern drop")
	_check(observation.valid_at_commit, "Two-can pattern passes validation before commitment")
	_check(not arena.has_pending_pattern(), "Pending pattern clears after spawning")

	var spawn_positions: Array[float] = []
	for child in arena.get_node("Hazards").get_children():
		if child is FallingProduct:
			spawn_positions.append(child.position.x)
	_check(spawn_positions.size() == 2, "Two product instances launch")
	_check(
		spawn_positions.size() == 2
		and absf(spawn_positions[0] - spawn_positions[1]) >= arena.product_size.x,
		"Spawn collision footprints do not overlap"
	)

	var maximum_falling_seen := arena.falling_product_count()
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		maximum_falling_seen = maxi(maximum_falling_seen, arena.falling_product_count())
		if arena.landed_product_count() == 2:
			break
	_check(
		maximum_falling_seen <= arena.maximum_concurrent_falling_cans,
		"Runtime never exceeds concurrent falling cap"
	)
	_check(arena.landed_product_count() == 2, "Both cans can complete the pattern as platforms")

	for lane_index in committed_lanes:
		_check(
			arena.lane_footprint_overlaps_landed(lane_index),
			"Occupied landed-can lane reports footprint overlap"
		)
		_check(not arena.is_lane_available(lane_index), "Occupied landed-can lane is unavailable")
		_check(
			not arena.is_pattern_valid(PackedInt32Array([lane_index])),
			"Pattern validator rejects an occupied landed-can lane"
		)

	arena.queue_free()
	await process_frame


func _test_invalid_pattern_retry() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	_configure_fast_pattern_test(arena, true)
	arena.minimum_safe_region_width = 2000.0
	var retry_observation := {"count": 0}
	arena.pattern_retry_scheduled.connect(
		func() -> void: retry_observation.count += 1
	)
	root.add_child(arena)
	_disable_player(arena)

	for frame in range(30):
		await physics_frame
		if retry_observation.count > 0:
			break
	_check(retry_observation.count > 0, "No-valid-pattern state schedules a delayed retry")
	_check(not arena.has_pending_pattern(), "Invalid pattern is never committed")
	_check(arena.falling_product_count() == 0, "Invalid pattern spawns no cans")

	arena.queue_free()
	await process_frame


func _test_pending_pattern_restart_cleanup() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	_configure_fast_pattern_test(arena, true)
	arena.initial_telegraph_duration = 1.0
	arena.minimum_telegraph_duration = 1.0
	root.add_child(arena)
	_disable_player(arena)

	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if arena.has_pending_pattern():
			break
	_check(arena.has_pending_pattern(), "Restart test begins with a pending pattern")
	var pending_lanes := arena.pending_pattern_lanes()
	_check(pending_lanes.size() == 2, "Restart test has two pending warning lanes")

	current_scene = arena
	var previous_instance_id := arena.get_instance_id()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	arena._unhandled_input(restart_event)
	await process_frame
	await process_frame

	var restarted_arena := current_scene as CompactArena
	_check(
		restarted_arena != null and restarted_arena.get_instance_id() != previous_instance_id,
		"Restart replaces patterned arena instance"
	)
	_check(
		restarted_arena != null
		and not restarted_arena.has_pending_pattern()
		and restarted_arena.falling_product_count() == 0
		and restarted_arena.landed_product_count() == 0,
		"Restart clears warnings, falling cans, platforms, and pending state"
	)
	_check(
		restarted_arena != null
		and not restarted_arena.get_node(
			"SourceRack/SourceCarriage/WarningColumn"
		).visible
		and not restarted_arena.get_node(
			"SourceRack/SourceCarriage2/WarningColumn"
		).visible,
		"Restart hides both warning lanes"
	)

	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _configure_fast_pattern_test(arena: CompactArena, force_two: bool) -> void:
	arena.initial_drop_delay = 0.0
	arena.initial_telegraph_duration = 0.10
	arena.minimum_telegraph_duration = 0.10
	arena.initial_drop_cooldown = 0.05
	arena.minimum_drop_cooldown = 0.05
	arena.initial_fall_speed = 1200.0
	arena.maximum_fall_speed = 1200.0
	arena.landed_lifetime = 2.0
	arena.despawn_warning_duration = 0.25
	if force_two:
		arena.early_phase_end_seconds = 0.0
		arena.middle_phase_end_seconds = 0.0
		arena.late_two_can_probability = 1.0
	else:
		arena.early_phase_end_seconds = 999.0
		arena.middle_two_can_probability = 0.0
		arena.late_two_can_probability = 0.0


func _connect_pattern_observation(arena: CompactArena) -> Dictionary:
	var observation := {
		"committed_lanes": PackedInt32Array(),
		"dropped_lanes": PackedInt32Array(),
		"telegraph_lanes": [],
		"drop_lanes": [],
		"all_warnings_visible": true,
		"all_warning_positions_match": true,
		"falling_count_at_drop": 0,
		"valid_at_commit": false,
	}
	arena.pattern_committed.connect(_on_pattern_committed.bind(observation, arena))
	arena.telegraph_started.connect(_on_telegraph_started.bind(observation, arena))
	arena.product_dropped.connect(_on_product_dropped.bind(observation))
	arena.pattern_dropped.connect(_on_pattern_dropped.bind(observation, arena))
	return observation


func _wait_for_pattern_drop(observation: Dictionary) -> void:
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if not observation.dropped_lanes.is_empty():
			return
	_check(false, "Pattern drops within test frame budget")


func _disable_player(arena: CompactArena) -> void:
	arena.player.collision_layer = 0
	arena.player.collision_mask = 0
	arena.player.set_physics_process(false)


func _on_pattern_committed(
	lane_indices: PackedInt32Array,
	_duration: float,
	observation: Dictionary,
	arena: CompactArena
) -> void:
	observation.committed_lanes = lane_indices.duplicate()
	observation.valid_at_commit = arena.is_pattern_valid(lane_indices)


func _on_telegraph_started(
	lane_index: int,
	_duration: float,
	observation: Dictionary,
	arena: CompactArena
) -> void:
	observation.telegraph_lanes.append(lane_index)
	observation.all_warnings_visible = (
		observation.all_warnings_visible
		and arena.warning_is_visible_for_lane(lane_index)
	)
	observation.all_warning_positions_match = (
		observation.all_warning_positions_match
		and absf(
			arena.warning_position_for_lane(lane_index)
			- arena.drop_lane_positions[lane_index]
		) <= FLOAT_TOLERANCE
	)


func _on_product_dropped(
	lane_index: int,
	_speed: float,
	observation: Dictionary
) -> void:
	observation.drop_lanes.append(lane_index)


func _on_pattern_dropped(
	lane_indices: PackedInt32Array,
	observation: Dictionary,
	arena: CompactArena
) -> void:
	observation.dropped_lanes = lane_indices.duplicate()
	observation.falling_count_at_drop = arena.falling_product_count()
