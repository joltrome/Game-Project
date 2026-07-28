extends SceneTree

const ARENA_SCENE := preload("res://scenes/prototypes/arena.tscn")
const PRODUCT_SCENE := preload("res://scenes/hazards/falling_product.tscn")
const FLOAT_TOLERANCE := 0.02
const MAX_TEST_FRAMES := 420

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
	await _test_derived_lane_geometry_and_complete_coverage()
	await _test_edge_dwell_threshold_and_reset()
	var left_wait := await _test_natural_edge_launch(CompactArena.EdgeSide.LEFT)
	var right_wait := await _test_natural_edge_launch(CompactArena.EdgeSide.RIGHT)
	await _test_paired_edge_pattern_preserves_inward_escape()
	await _test_temporarily_invalid_edge_request_retries()
	await _test_wall_adjacent_landed_platforms()
	await _test_restart_clears_edge_state()
	print(
		"EDGE_TARGETING_METRICS left_wait=%.3fs right_wait=%.3fs maximum_wait=%.3fs"
		% [left_wait, right_wait, maxf(left_wait, right_wait)]
	)
	print("Edge coverage validation finished with %d failure(s)." % failures)
	quit(failures)


func _test_derived_lane_geometry_and_complete_coverage() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	root.add_child(arena)
	await process_frame
	_disable_player(arena)

	_check(
		absf(arena.player_minimum_center_x() - 112.0) <= FLOAT_TOLERANCE
		and absf(arena.player_maximum_center_x() - 1040.0) <= FLOAT_TOLERANCE,
		"Playable player-center interval is derived from walls and player width"
	)
	_check(
		arena.minimum_coverage_lane_count() == 14
		and arena.drop_lane_positions.size() == 14,
		"Can width and arena bounds derive the minimum fourteen logical lanes"
	)
	_check(
		absf(arena.drop_lane_positions[0] - 132.0) <= FLOAT_TOLERANCE
		and absf(arena.drop_lane_positions[-1] - 1020.0) <= FLOAT_TOLERANCE,
		"Outer lane centers are flush-safe at 132 and 1020 pixels"
	)
	var left_footprint := arena.lane_footprint(0)
	var right_footprint := arena.lane_footprint(arena.drop_lane_positions.size() - 1)
	_check(
		absf(left_footprint.x - 96.0) <= FLOAT_TOLERANCE
		and absf(right_footprint.y - 1056.0) <= FLOAT_TOLERANCE,
		"Outer can footprints reach each inner wall without overlap"
	)
	_check(
		arena.player_minimum_center_x() >= left_footprint.x
		and arena.player_minimum_center_x() <= left_footprint.y,
		"Player touching the left wall is inside the left-edge can footprint"
	)
	_check(
		arena.player_maximum_center_x() >= right_footprint.x
		and arena.player_maximum_center_x() <= right_footprint.y,
		"Player touching the right wall is inside the right-edge can footprint"
	)
	_check(
		arena.has_complete_player_center_coverage(),
		"Analytical lane union covers the complete traversable center interval"
	)

	var sample_x := arena.player_minimum_center_x()
	var sampled_gap := false
	while sample_x <= arena.player_maximum_center_x() + FLOAT_TOLERANCE:
		var covered := false
		for lane_index in range(arena.drop_lane_positions.size()):
			var footprint := arena.lane_footprint(lane_index)
			if sample_x >= footprint.x and sample_x <= footprint.y:
				covered = true
				break
		if not covered:
			sampled_gap = true
			break
		sample_x += 0.5
	_check(not sampled_gap, "Half-pixel coverage sampling finds no untargetable gap")

	var mirrored := true
	var symmetry_sum := 96.0 + 1056.0
	for lane_index in range(arena.drop_lane_positions.size()):
		var mirror_index := arena.drop_lane_positions.size() - 1 - lane_index
		mirrored = (
			mirrored
			and absf(
				arena.drop_lane_positions[lane_index]
				+ arena.drop_lane_positions[mirror_index]
				- symmetry_sum
			) <= FLOAT_TOLERANCE
		)
	_check(mirrored, "Left and right lane coverage is geometrically mirrored")

	arena.queue_free()
	await process_frame


func _test_edge_dwell_threshold_and_reset() -> void:
	var arena := await _make_inert_arena()
	arena.player.position.x = arena.player_minimum_center_x()
	arena._update_edge_dwell(0.40)
	_check(
		arena.pending_edge_request() == CompactArena.EdgeSide.NONE,
		"Brief left-edge entry does not reserve anti-camping"
	)
	arena.player.position.x = 576.0
	arena._update_edge_dwell(0.10)
	_check(
		arena.edge_dwell_time(CompactArena.EdgeSide.LEFT) == 0.0,
		"Leaving the left edge zone resets its dwell timer"
	)
	arena.player.position.x = arena.player_minimum_center_x()
	arena._update_edge_dwell(0.99)
	_check(
		arena.pending_edge_request() == CompactArena.EdgeSide.NONE,
		"Sub-threshold continuous left dwell remains untriggered"
	)
	arena._update_edge_dwell(0.02)
	_check(
		arena.pending_edge_request() == CompactArena.EdgeSide.LEFT,
		"Sustained left dwell reserves a left-edge request"
	)

	arena.queue_free()
	await process_frame

	var right_arena := await _make_inert_arena()
	right_arena.player.position.x = right_arena.player_maximum_center_x()
	right_arena._update_edge_dwell(1.01)
	_check(
		right_arena.pending_edge_request() == CompactArena.EdgeSide.RIGHT,
		"Sustained right dwell reserves a right-edge request"
	)
	right_arena.queue_free()
	await process_frame


func _test_natural_edge_launch(edge_side: int) -> float:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	var observation := {
		"reserved_at": -1.0,
		"warning_at": -1.0,
		"warning_duration": -1.0,
		"drop_at": -1.0,
		"launched_at": -1.0,
		"launched_lanes": PackedInt32Array(),
		"reachable": false,
		"warning_aligned": false,
	}
	arena.edge_request_reserved.connect(
		func(reserved_side: int, reserved_at: float) -> void:
			if reserved_side == edge_side:
				observation.reserved_at = reserved_at
	)
	arena.pattern_committed.connect(
		func(lanes: PackedInt32Array, _duration: float) -> void:
			var edge_lane := arena.edge_lane_index(edge_side)
			if observation.reserved_at >= 0.0 and lanes.has(edge_lane):
				observation.launched_lanes = lanes.duplicate()
				observation.reachable = arena.edge_pattern_has_reachable_inward_escape(
					lanes,
					edge_side
				)
	)
	arena.telegraph_started.connect(
		func(lane_index: int, duration: float) -> void:
			if (
				observation.reserved_at >= 0.0
				and lane_index == arena.edge_lane_index(edge_side)
				and observation.warning_at < 0.0
			):
				observation.warning_at = arena.survival_time
				observation.warning_duration = duration
				observation.warning_aligned = (
					arena.warning_is_visible_for_lane(lane_index)
					and absf(
						arena.warning_position_for_lane(lane_index)
						- arena.drop_lane_positions[lane_index]
					) <= FLOAT_TOLERANCE
				)
	)
	arena.product_dropped.connect(
		func(lane_index: int, _speed: float) -> void:
			if (
				observation.warning_at >= 0.0
				and lane_index == arena.edge_lane_index(edge_side)
				and observation.drop_at < 0.0
			):
				observation.drop_at = arena.survival_time
	)
	arena.edge_pattern_launched.connect(
		func(launched_side: int, launched_at: float) -> void:
			if launched_side == edge_side:
				observation.launched_at = launched_at
	)
	root.add_child(arena)
	await process_frame
	_disable_player(arena)
	arena.player.position.x = (
		arena.player_minimum_center_x()
		if edge_side == CompactArena.EdgeSide.LEFT
		else arena.player_maximum_center_x()
	)

	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if observation.launched_at >= 0.0:
			break

	var edge_name := "left" if edge_side == CompactArena.EdgeSide.LEFT else "right"
	_check(
		observation.reserved_at >= arena.edge_dwell_threshold,
		"Sustained %s camping reserves an edge request" % edge_name
	)
	_check(
		not observation.launched_lanes.is_empty()
		and observation.launched_lanes.has(arena.edge_lane_index(edge_side)),
		"Reserved %s request launches a matching edge-containing pattern" % edge_name
	)
	_check(
		observation.warning_aligned,
		"%s edge warning and chute align with the corrected lane" % edge_name.capitalize()
	)
	_check(
		observation.drop_at - observation.warning_at
			+ FLOAT_TOLERANCE >= observation.warning_duration,
		"%s edge request preserves normal warning duration" % edge_name.capitalize()
	)
	_check(
		observation.reachable,
		"%s edge-targeted pattern preserves reachable inward safe space"
		% edge_name.capitalize()
	)
	_check(
		arena.pending_edge_request() == CompactArena.EdgeSide.NONE,
		"Valid %s edge launch clears its pending request" % edge_name
	)
	var activation_to_launch: float = (
		observation.launched_at - observation.reserved_at
	)

	arena.queue_free()
	await process_frame
	return activation_to_launch


func _test_paired_edge_pattern_preserves_inward_escape() -> void:
	var arena := await _make_inert_arena()
	arena.survival_time = arena.paired_pattern_start_seconds
	arena.player.position.x = arena.player_minimum_center_x()
	arena._reserve_edge_request(CompactArena.EdgeSide.LEFT)
	arena._cooldown_remaining = 0.0
	var observation := {
		"committed_lanes": PackedInt32Array(),
		"reachable": false,
	}
	arena.pattern_committed.connect(
		func(lanes: PackedInt32Array, _duration: float) -> void:
			if lanes.has(arena.edge_lane_index(CompactArena.EdgeSide.LEFT)):
				observation.committed_lanes = lanes.duplicate()
				observation.reachable = arena.edge_pattern_has_reachable_inward_escape(
					lanes,
					CompactArena.EdgeSide.LEFT
				)
	)
	arena.set_physics_process(true)
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if not observation.committed_lanes.is_empty():
			break
	_check(
		observation.committed_lanes.size() == 2
		and observation.committed_lanes.has(
			arena.edge_lane_index(CompactArena.EdgeSide.LEFT)
		),
		"Paired phase includes the reserved edge lane without adding a third can"
	)
	_check(
		observation.reachable,
		"Paired edge targeting retains an inward reachable destination"
	)

	arena.queue_free()
	await process_frame


func _test_temporarily_invalid_edge_request_retries() -> void:
	var arena := await _make_inert_arena()
	arena.minimum_safe_region_width = 2000.0
	arena.player.position.x = arena.player_minimum_center_x()
	arena._reserve_edge_request(CompactArena.EdgeSide.LEFT)
	arena._cooldown_remaining = 0.0
	var retries := {"count": 0}
	var launched := {"value": false}
	arena.pattern_retry_scheduled.connect(func() -> void: retries.count += 1)
	arena.edge_pattern_launched.connect(
		func(edge_side: int, _time: float) -> void:
			if edge_side == CompactArena.EdgeSide.LEFT:
				launched.value = true
	)
	arena.set_physics_process(true)
	for frame in range(60):
		await physics_frame
		if retries.count >= 2:
			break
	_check(retries.count >= 2, "Invalid edge pattern schedules repeated retries")
	_check(
		arena.pending_edge_request() == CompactArena.EdgeSide.LEFT,
		"Temporarily invalid edge request remains pending"
	)
	_check(not launched.value, "Invalid edge request never bypasses validation")

	arena.minimum_safe_region_width = 64.0
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if launched.value:
			break
	_check(launched.value, "Retained edge request launches after fairness becomes valid")

	arena.queue_free()
	await process_frame


func _test_wall_adjacent_landed_platforms() -> void:
	var arena := await _make_inert_arena()
	var left_product := await _spawn_landed_product(
		arena,
		arena.drop_lane_positions[0]
	)
	var right_product := await _spawn_landed_product(
		arena,
		arena.drop_lane_positions[-1]
	)
	var half_width := arena.landed_product_size.x * 0.5
	var left_outer_edge := left_product.position.x - half_width
	var right_outer_edge := right_product.position.x + half_width
	_check(
		absf(left_outer_edge - 96.0) <= FLOAT_TOLERANCE
		and absf(right_outer_edge - 1056.0) <= FLOAT_TOLERANCE,
		"Wall-adjacent landed platforms sit flush without wall overlap"
	)
	_check(
		absf(left_outer_edge - 96.0) < 1.0
		and absf(1056.0 - right_outer_edge) < 1.0,
		"Wall-adjacent platforms leave no trapping pocket"
	)
	_check(
		arena.is_landed_can_jump_clearable(),
		"Wall-adjacent platform remains jumpable from its inward side"
	)
	_check(
		not left_product.is_falling_lethal()
		and not right_product.is_falling_lethal(),
		"Wall-adjacent landed products remain non-lethal terrain"
	)

	arena.queue_free()
	await process_frame


func _test_restart_clears_edge_state() -> void:
	var arena := await _make_inert_arena()
	arena.player.position.x = arena.player_maximum_center_x()
	arena._update_edge_dwell(1.01)
	_check(
		arena.pending_edge_request() == CompactArena.EdgeSide.RIGHT,
		"Restart test begins with a pending right-edge request"
	)

	current_scene = arena
	var previous_instance_id := arena.get_instance_id()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	arena._unhandled_input(restart_event)
	await process_frame
	await process_frame

	var restarted := current_scene as CompactArena
	_check(
		restarted != null and restarted.get_instance_id() != previous_instance_id,
		"Restart replaces edge-targeting arena instance"
	)
	_check(
		restarted != null
		and restarted.pending_edge_request() == CompactArena.EdgeSide.NONE
		and restarted.edge_dwell_time(CompactArena.EdgeSide.LEFT) == 0.0
		and restarted.edge_dwell_time(CompactArena.EdgeSide.RIGHT) == 0.0
		and not restarted.has_pending_pattern()
		and restarted.active_chute_count() == 0,
		"Restart clears edge dwell, request, warning, pattern, and chute state"
	)

	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _make_inert_arena() -> CompactArena:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	arena.initial_drop_delay = 999.0
	arena.landed_lifetime = 99.0
	root.add_child(arena)
	await process_frame
	_disable_player(arena)
	arena.set_physics_process(false)
	return arena


func _spawn_landed_product(
	arena: CompactArena,
	x_position: float
) -> FallingProduct:
	var product := PRODUCT_SCENE.instantiate() as FallingProduct
	product.position = Vector2(
		x_position,
		arena.floor_y - arena.product_size.y * 0.5 - 1.0
	)
	product.configure(
		3000.0,
		arena.floor_y,
		arena.landed_lifetime,
		arena.despawn_warning_duration,
		arena.product_size,
		arena.landed_product_size
	)
	product.landed.connect(arena._on_product_landed)
	product.cleared.connect(arena._on_product_cleared)
	arena.get_node("Hazards").add_child(product)
	arena._falling_products.append(product)
	for frame in range(10):
		await physics_frame
		if product.is_landed():
			return product
	_check(false, "Test edge product reaches landed state")
	return product


func _disable_player(arena: CompactArena) -> void:
	arena.player.collision_layer = 0
	arena.player.collision_mask = 0
	arena.player.set_physics_process(false)
