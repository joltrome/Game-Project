extends SceneTree

const ARENA_SCENE := preload("res://scenes/prototypes/arena.tscn")
const PRODUCT_SCENE := preload("res://scenes/hazards/falling_product.tscn")
const FLOAT_TOLERANCE := 0.02
const MAX_TEST_FRAMES := 420
const NATURAL_LIFECYCLE_LIMIT_SECONDS := 21.0

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
	await _test_piecewise_pacing_configuration()
	await _test_natural_scheduler_pressure_and_chutes()
	await _test_pair_chutes_resolve_independently()
	await _test_invalid_pair_retries_without_single_downgrade()
	await _test_two_existing_plus_pair_rolls_to_three()
	await _test_three_existing_plus_pair_evicts_oldest_two()
	await _test_player_support_avoidance()
	await _test_restart_clears_all_pattern_and_eviction_state()
	print("VM-0.2.3-A pacing validation finished with %d failure(s)." % failures)
	quit(failures)


func _test_piecewise_pacing_configuration() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	root.add_child(arena)
	await process_frame
	_disable_player(arena)

	var checkpoints := [0.0, 5.0, 12.0, 20.0, 30.0]
	var expected_telegraphs := [0.70, 0.55, 0.40, 0.32, 0.28]
	var expected_fall_durations := [0.75, 0.60, 0.40, 0.30, 0.25]
	var expected_delays := [0.40, 0.30, 0.20, 0.20, 0.15]
	var previous_speed := 0.0
	for index in range(checkpoints.size()):
		var checkpoint: float = checkpoints[index]
		_check(
			absf(arena.telegraph_duration_at(checkpoint) - expected_telegraphs[index])
			<= FLOAT_TOLERANCE,
			"Telegraph duration matches the %.0f-second pacing checkpoint" % checkpoint
		)
		_check(
			absf(
				arena.target_fall_duration_at(checkpoint)
				- expected_fall_durations[index]
			) <= FLOAT_TOLERANCE,
			"Target fall duration matches the %.0f-second pacing checkpoint" % checkpoint
		)
		_check(
			absf(arena.drop_cooldown_at(checkpoint) - expected_delays[index])
			<= FLOAT_TOLERANCE,
			"Post-drop delay matches the %.0f-second pacing checkpoint" % checkpoint
		)
		var speed := arena.fall_speed_at(checkpoint)
		_check(
			absf(
				speed * arena.target_fall_duration_at(checkpoint)
				- arena.drop_distance()
			) <= FLOAT_TOLERANCE,
			"Fall speed at %.0f seconds is derived from actual drop distance" % checkpoint
		)
		_check(
			speed + FLOAT_TOLERANCE >= previous_speed,
			"Fall speed does not reset at the %.0f-second phase boundary" % checkpoint
		)
		previous_speed = speed

	_check(
		arena.two_can_probability_at(11.99) == 0.0
		and arena.two_can_probability_at(12.0) == 1.0,
		"Pattern sequence switches from singles to guaranteed pairs at 12 seconds"
	)
	_check(arena.maximum_landed_cans == 3, "Rolling terrain cap is three platforms")
	_check(
		absf(arena.landed_lifetime - 2.0) <= FLOAT_TOLERANCE
		and absf(arena.despawn_warning_duration - 0.35) <= FLOAT_TOLERANCE,
		"Natural platform lifetime and final warning use the approved hypotheses"
	)

	arena.queue_free()
	await process_frame


func _test_natural_scheduler_pressure_and_chutes() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	var observation := {
		"pending_size": 0,
		"single_speeds": [],
		"first_pair_commit": -1.0,
		"first_pair_drop": -1.0,
		"first_pair_speed": -1.0,
		"pair_chutes_visible": false,
		"pair_chutes_aligned": false,
		"drop_while_landed": false,
		"last_all_landed_time": -1.0,
		"longest_idle_gap": 0.0,
		"pattern_count": 0,
	}
	arena.pattern_committed.connect(
		func(lanes: PackedInt32Array, _duration: float) -> void:
			observation.pending_size = lanes.size()
			observation.pattern_count += 1
			if observation.last_all_landed_time >= 0.0:
				observation.longest_idle_gap = maxf(
					observation.longest_idle_gap,
					arena.survival_time - observation.last_all_landed_time
				)
				observation.last_all_landed_time = -1.0
			if lanes.size() == 2 and observation.first_pair_commit < 0.0:
				observation.first_pair_commit = arena.survival_time
	)
	arena.product_dropped.connect(
		func(_lane_index: int, speed: float) -> void:
			if observation.pending_size == 1:
				observation.single_speeds.append(speed)
			elif observation.pending_size == 2 and observation.first_pair_speed < 0.0:
				observation.first_pair_speed = speed
	)
	arena.pattern_dropped.connect(
		func(lanes: PackedInt32Array) -> void:
			if arena.landed_product_count() > 0:
				observation.drop_while_landed = true
			if lanes.size() == 2 and observation.first_pair_drop < 0.0:
				observation.first_pair_drop = arena.survival_time
				observation.pair_chutes_visible = arena.active_chute_count() == 2
				observation.pair_chutes_aligned = true
				for lane_index in lanes:
					observation.pair_chutes_aligned = (
						observation.pair_chutes_aligned
						and arena.chute_is_visible_for_lane(lane_index)
						and absf(
							arena.chute_position_for_lane(lane_index)
							- arena.drop_lane_positions[lane_index]
						) <= FLOAT_TOLERANCE
					)
	)
	arena.falling_product_landed.connect(
		func(_product: FallingProduct) -> void:
			if (
				arena.falling_product_count() == 0
				and not arena.has_pending_pattern()
			):
				observation.last_all_landed_time = arena.survival_time
	)
	root.add_child(arena)
	await process_frame
	_disable_player(arena)

	while arena.survival_time < NATURAL_LIFECYCLE_LIMIT_SECONDS:
		await physics_frame

	_check(observation.pattern_count >= 8, "Natural lifecycle launches repeated patterns")
	_check(
		observation.single_speeds.size() >= 3,
		"Single phase produces enough drops to exercise its speed ramp"
	)
	var singles_accelerate := true
	for index in range(1, observation.single_speeds.size()):
		singles_accelerate = (
			singles_accelerate
			and observation.single_speeds[index]
				+ FLOAT_TOLERANCE >= observation.single_speeds[index - 1]
		)
	_check(singles_accelerate, "Single phase ramps fall speed before paired play")
	_check(
		observation.first_pair_commit >= arena.paired_pattern_start_seconds
		and observation.first_pair_commit <= 13.5,
		"First pair commits naturally near the approved 12-second transition"
	)
	_check(
		observation.first_pair_drop > observation.first_pair_commit
		and observation.first_pair_drop <= 14.0,
		"First paired drop begins during the intended early pressure window"
	)
	_check(
		not observation.single_speeds.is_empty()
		and observation.first_pair_speed
			+ FLOAT_TOLERANCE >= observation.single_speeds.back(),
		"Paired drops retain the speed reached by the single phase"
	)
	_check(
		observation.drop_while_landed,
		"Scheduler launches new hazards while landed terrain exists"
	)
	_check(
		observation.longest_idle_gap <= 0.15,
		"No scheduler idle gap is caused by waiting for landed capacity"
	)
	_check(
		observation.pair_chutes_visible,
		"A paired drop keeps two chute instances visible while both cans fall"
	)
	_check(
		observation.pair_chutes_aligned,
		"Each paired chute aligns with its own warning lane and can"
	)
	print(
		(
			"NATURAL_PACING_METRICS first_pair_commit=%.3fs "
			+ "first_pair_drop=%.3fs longest_idle_gap=%.3fs"
		) % [
			observation.first_pair_commit,
			observation.first_pair_drop,
			observation.longest_idle_gap,
		]
	)

	arena.queue_free()
	await process_frame


func _test_pair_chutes_resolve_independently() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	_configure_fast_pair_test(arena)
	var observation := {"dropped_lanes": PackedInt32Array()}
	arena.pattern_dropped.connect(
		func(lanes: PackedInt32Array) -> void:
			if observation.dropped_lanes.is_empty():
				observation.dropped_lanes = lanes.duplicate()
	)
	root.add_child(arena)
	await process_frame
	_disable_player(arena)

	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if observation.dropped_lanes.size() == 2:
			break
	var dropped_lanes: PackedInt32Array = observation.dropped_lanes
	_check(dropped_lanes.size() == 2, "Forced pair launches two cans")
	_check(arena.active_chute_count() == 2, "Both chute instances remain active after drop")

	var products: Array[FallingProduct] = []
	for child in arena.get_node("Hazards").get_children():
		if child is FallingProduct and child.is_falling():
			products.append(child)
	_check(products.size() == 2, "Independent chute test finds both falling products")
	if products.size() == 2:
		products[0].position.y = arena.floor_y - arena.product_size.y * 0.5 - 1.0
		await physics_frame
		await physics_frame
		_check(
			arena.active_chute_count() == 1,
			"Landing one can resolves only its corresponding chute"
		)
		var remaining_lane := dropped_lanes[1]
		if not products[1].is_falling():
			remaining_lane = dropped_lanes[0]
		_check(
			arena.chute_is_visible_for_lane(remaining_lane),
			"The other can keeps its own chute visible"
		)

	arena.queue_free()
	await process_frame


func _test_invalid_pair_retries_without_single_downgrade() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	_configure_fast_pair_test(arena)
	arena.minimum_safe_region_width = 2000.0
	var retry_observation := {"count": 0}
	var committed_sizes: Array[int] = []
	arena.pattern_retry_scheduled.connect(
		func() -> void: retry_observation.count += 1
	)
	arena.pattern_committed.connect(
		func(lanes: PackedInt32Array, _duration: float) -> void:
			committed_sizes.append(lanes.size())
	)
	root.add_child(arena)
	await process_frame
	_disable_player(arena)

	for frame in range(60):
		await physics_frame
		if retry_observation.count >= 2:
			break
	_check(
		retry_observation.count >= 2,
		"Temporarily invalid pair schedules repeated short retries"
	)
	_check(arena.has_reserved_pair(), "Invalid pair remains reserved")
	_check(committed_sizes.is_empty(), "Reserved pair never downgrades to a single")

	arena.minimum_safe_region_width = 64.0
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if not committed_sizes.is_empty():
			break
	_check(
		committed_sizes.size() == 1 and committed_sizes[0] == 2,
		"Reserved pair commits as a pair after fairness becomes valid"
	)

	arena.queue_free()
	await process_frame


func _test_two_existing_plus_pair_rolls_to_three() -> void:
	var arena := await _make_scheduler_disabled_arena()
	var oldest := await _spawn_landed_product(arena, 192.0)
	var newer := await _spawn_landed_product(arena, 960.0)
	var planned := arena._select_platform_evictions(2) as Array[FallingProduct]
	_check(
		planned.size() == 1 and planned[0] == oldest,
		"Two existing plus two incoming selects only the oldest platform"
	)

	var timing := {"warning_frame": -1, "clear_frame": -1}
	oldest.rolling_eviction_warning_started.connect(
		func(_product: FallingProduct) -> void:
			timing.warning_frame = Engine.get_physics_frames()
	)
	oldest.cleared.connect(
		func(_product: FallingProduct) -> void:
			timing.clear_frame = Engine.get_physics_frames()
	)
	arena._begin_rolling_evictions(planned)
	_check(
		oldest.is_rolling_eviction_pending()
		and oldest.is_landed_solid()
		and not oldest.is_falling_lethal()
		and oldest.get_node("Label").text == "REMOVE",
		"Rolling eviction gives a readable warning while remaining non-lethal and solid"
	)
	await _wait_for_product_clear(oldest)
	_check(
		timing.warning_frame >= 0 and timing.clear_frame > timing.warning_frame,
		"Rolling eviction warning occurs before disappearance"
	)
	var warning_duration := (
		float(timing.clear_frame - timing.warning_frame)
		/ Engine.physics_ticks_per_second
	)
	_check(
		absf(warning_duration - arena.rolling_eviction_warning_duration) <= 0.03,
		"Rolling eviction uses its configured warning duration"
	)

	var incoming_one := await _spawn_landed_product(arena, 192.0)
	var incoming_two := await _spawn_landed_product(arena, 448.0)
	_check(
		arena.landed_product_count() == 3
		and arena._landed_products.has(newer)
		and arena._landed_products.has(incoming_one)
		and arena._landed_products.has(incoming_two),
		"Two existing plus two incoming finishes with one previous and two new platforms"
	)

	arena.queue_free()
	await process_frame


func _test_three_existing_plus_pair_evicts_oldest_two() -> void:
	var arena := await _make_scheduler_disabled_arena()
	var oldest := await _spawn_landed_product(arena, 192.0)
	var middle := await _spawn_landed_product(arena, 576.0)
	var newest := await _spawn_landed_product(arena, 960.0)
	var planned := arena._select_platform_evictions(2) as Array[FallingProduct]
	_check(
		planned.size() == 2 and planned[0] == oldest and planned[1] == middle,
		"Three existing plus two incoming deterministically selects the two oldest"
	)
	arena._begin_rolling_evictions(planned)
	await _wait_for_product_clear(oldest)
	await _wait_for_product_clear(middle)
	var incoming_one := await _spawn_landed_product(arena, 192.0)
	var incoming_two := await _spawn_landed_product(arena, 448.0)
	_check(
		arena.landed_product_count() == 3
		and arena._landed_products.has(newest)
		and arena._landed_products.has(incoming_one)
		and arena._landed_products.has(incoming_two),
		"Three existing plus two incoming retains the newest old platform and adds both new"
	)

	arena.queue_free()
	await process_frame


func _test_player_support_avoidance() -> void:
	var arena := await _make_scheduler_disabled_arena(false)
	var supporting_oldest := await _spawn_landed_product(arena, 192.0)
	var alternative := await _spawn_landed_product(arena, 576.0)
	await _spawn_landed_product(arena, 960.0)
	arena.player.position = Vector2(192.0, 512.0)
	arena.player.velocity = Vector2.ZERO
	await physics_frame

	var planned := arena._select_platform_evictions(1) as Array[FallingProduct]
	_check(
		planned.size() == 1
		and planned[0] == alternative
		and planned[0] != supporting_oldest,
		"Eviction avoids the player-supporting oldest platform when another is eligible"
	)

	arena.queue_free()
	await process_frame


func _test_restart_clears_all_pattern_and_eviction_state() -> void:
	var arena := await _make_scheduler_disabled_arena()
	await _spawn_landed_product(arena, 192.0)
	await _spawn_landed_product(arena, 576.0)
	await _spawn_landed_product(arena, 960.0)
	arena.initial_drop_delay = 0.0
	arena.paired_pattern_start_seconds = 0.0
	arena.telegraph_at_zero_seconds = 1.0
	arena.telegraph_at_five_seconds = 1.0
	arena.telegraph_at_twelve_seconds = 1.0
	arena._cooldown_remaining = 0.0
	arena.set_physics_process(true)

	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if arena.has_pending_pattern() and arena.eviction_pending_count() > 0:
			break
	_check(arena.has_pending_pattern(), "Restart test begins with paired warnings")
	_check(arena.eviction_pending_count() == 2, "Restart test begins with rolling evictions")

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
		"Restart replaces the arena instance"
	)
	_check(
		restarted != null
		and not restarted.has_pending_pattern()
		and not restarted.has_reserved_pair()
		and restarted.active_chute_count() == 0
		and restarted.falling_product_count() == 0
		and restarted.landed_product_count() == 0
		and restarted.eviction_pending_count() == 0,
		"Restart clears warnings, chutes, products, terrain, evictions, and reservations"
	)
	_check(
		restarted != null
		and not restarted.get_node(
			"SourceRack/SourceCarriage/WarningColumn"
		).visible
		and not restarted.get_node(
			"SourceRack/SourceCarriage2/WarningColumn"
		).visible,
		"Restart hides both active warning columns"
	)

	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _configure_fast_pair_test(arena: CompactArena) -> void:
	arena.initial_drop_delay = 0.0
	arena.paired_pattern_start_seconds = 0.0
	arena.telegraph_at_zero_seconds = 0.05
	arena.telegraph_at_five_seconds = 0.05
	arena.telegraph_at_twelve_seconds = 0.05
	arena.telegraph_at_twenty_seconds = 0.05
	arena.minimum_telegraph_duration = 0.05
	arena.fall_duration_at_zero_seconds = 0.25
	arena.fall_duration_at_five_seconds = 0.25
	arena.fall_duration_at_twelve_seconds = 0.25
	arena.fall_duration_at_twenty_seconds = 0.25
	arena.minimum_fall_duration = 0.25
	arena.post_drop_delay_before_five_seconds = 0.05
	arena.post_drop_delay_at_five_seconds = 0.05
	arena.post_drop_delay_at_twelve_seconds = 0.05
	arena.post_drop_delay_at_twenty_seconds = 0.05
	arena.minimum_post_drop_delay = 0.05
	arena.pattern_retry_delay = 0.03


func _make_scheduler_disabled_arena(
	disable_player: bool = true
) -> CompactArena:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	arena.initial_drop_delay = 999.0
	arena.landed_lifetime = 99.0
	arena.rolling_eviction_warning_duration = 0.35
	root.add_child(arena)
	await process_frame
	if disable_player:
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
	_check(false, "Test product reaches landed state")
	return product


func _wait_for_product_clear(product: Variant) -> void:
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if not is_instance_valid(product):
			return
	_check(false, "Warned platform clears within the test frame budget")


func _disable_player(arena: CompactArena) -> void:
	arena.player.collision_layer = 0
	arena.player.collision_mask = 0
	arena.player.set_physics_process(false)
