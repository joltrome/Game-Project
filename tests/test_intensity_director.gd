extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const FLOAT_TOLERANCE := 0.005

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
	await _test_phase_configuration_and_distribution()
	await _test_continuous_timing_and_speed_curves()
	await _test_natural_director_lifecycle()
	await _test_restart_resets_director()
	print("INTENSITY_DIRECTOR_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_phase_configuration_and_distribution() -> void:
	var conveyor := await _make_conveyor(false)
	_check(
		conveyor.teaching_phase_end == 5.0
		and conveyor.conflict_phase_end == 12.0
		and conveyor.dominant_phase_end == 20.0,
		"Director uses the approved 5s, 12s, and 20s phase thresholds"
	)
	_check(
		conveyor.pattern_weights_at(8.0)
			== PackedInt32Array([20, 20, 30, 30]),
		"Conflict phase weights are 40% simple and 60% compound"
	)
	_check(
		conveyor.pattern_weights_at(16.0)
			== PackedInt32Array([10, 10, 40, 40]),
		"Dominant phase weights are 20% simple and 80% compound"
	)
	_check(
		conveyor.pattern_weights_at(30.0)
			== PackedInt32Array([0, 0, 50, 50]),
		"Late phase uses only the two compound templates"
	)

	var phase_two_counts := conveyor.director_distribution_sample(8.0, 10000)
	var phase_three_counts := conveyor.director_distribution_sample(16.0, 10000)
	var phase_four_counts := conveyor.director_distribution_sample(30.0, 10000)
	_check(
		_ratio_of_simple(phase_two_counts) >= 0.37
		and _ratio_of_simple(phase_two_counts) <= 0.43,
		"Deterministic conflict-phase sample approximates 40% simple"
	)
	_check(
		_ratio_of_compound(phase_two_counts) >= 0.57
		and _ratio_of_compound(phase_two_counts) <= 0.63,
		"Deterministic conflict-phase sample approximates 60% compound"
	)
	_check(
		_ratio_of_simple(phase_three_counts) >= 0.17
		and _ratio_of_simple(phase_three_counts) <= 0.23,
		"Deterministic dominant-phase sample approximates 20% simple"
	)
	_check(
		_ratio_of_compound(phase_three_counts) >= 0.77
		and _ratio_of_compound(phase_three_counts) <= 0.83,
		"Deterministic dominant-phase sample approximates 80% compound"
	)
	_check(
		phase_four_counts[0] == 0
		and phase_four_counts[1] == 0
		and _ratio_of_compound(phase_four_counts) == 1.0,
		"Deterministic late-phase sample is entirely compound"
	)
	print(
		"DIRECTOR_DISTRIBUTION_METRICS phase2=%s phase3=%s phase4=%s"
		% [phase_two_counts, phase_three_counts, phase_four_counts]
	)
	await _free_conveyor(conveyor)


func _test_continuous_timing_and_speed_curves() -> void:
	var conveyor := await _make_conveyor(false)
	var checkpoints := [5.0, 12.0, 20.0, 40.0]
	var expected_margins := [1.10, 0.825, 0.60, 0.50]
	var expected_cooldowns := [1.60, 0.90, 0.70, 0.50]
	for index in range(checkpoints.size()):
		var checkpoint: float = checkpoints[index]
		var configured_margin := conveyor.compound_margin_at(checkpoint)
		_check(
			absf(configured_margin - expected_margins[index])
				<= FLOAT_TOLERANCE,
			"Compound margin matches the %.0fs checkpoint" % checkpoint
		)
		_check(
			absf(
				conveyor.pattern_cooldown_at(checkpoint)
				- expected_cooldowns[index]
			) <= FLOAT_TOLERANCE,
			"Pattern cooldown matches the %.0fs checkpoint" % checkpoint
		)
		for pattern_type in [
			ConveyorPrototype.PatternType.SWEEPER_THEN_CAN,
			ConveyorPrototype.PatternType.CAN_THEN_SWEEPER,
		]:
			var actual_margin := (
				conveyor.compound_response_margin_for_pattern(
					pattern_type,
					checkpoint
				)
			)
			_check(
				actual_margin + 0.0001 >= configured_margin,
				"Pattern %d retains its minimum margin at %.0fs"
				% [pattern_type, checkpoint]
			)
			_check(
				conveyor.pattern_is_solvable(pattern_type, checkpoint),
				"Pattern %d remains feasible at %.0fs"
				% [pattern_type, checkpoint]
			)
		print(
			"DIRECTOR_CHECKPOINT t=%.0fs margin=%.3fs cooldown=%.3fs conveyor=%.3f sweeper=%.3f fall=%.3f"
			% [
				checkpoint,
				configured_margin,
				conveyor.pattern_cooldown_at(checkpoint),
				conveyor.conveyor_speed,
				conveyor.sweeper_speed_at(checkpoint),
				conveyor.fall_speed_at(checkpoint),
			]
		)

	for boundary in [
		conveyor.teaching_phase_end,
		conveyor.conflict_phase_end,
		conveyor.dominant_phase_end,
		conveyor.speed_ramp_start,
		conveyor.speed_ramp_end,
	]:
		var boundary_time: float = boundary
		var before: float = boundary_time - 0.001
		var after: float = boundary_time + 0.001
		_check(
			absf(
				conveyor.pattern_cooldown_at(after)
				- conveyor.pattern_cooldown_at(before)
			) < 0.001,
			"Cooldown remains continuous across %.0fs" % boundary_time
		)
		_check(
			absf(
				conveyor.compound_margin_at(after)
				- conveyor.compound_margin_at(before)
			) < 0.001,
			"Compound margin remains continuous across %.0fs" % boundary_time
		)
		_check(
			absf(
				conveyor.sweeper_speed_at(after)
				- conveyor.sweeper_speed_at(before)
			) < 0.1,
			"Hazard speed remains continuous across %.0fs" % boundary_time
		)
	_check(
		conveyor.sweeper_speed_at(12.0) > conveyor.sweeper_speed
		and conveyor.target_fall_duration_at(12.0)
			== conveyor.target_fall_duration,
		"Sweeper ramps smoothly while the existing can fall curve is preserved"
	)
	_check(
		conveyor.sweeper_speed_at(60.0)
			== conveyor.sweeper_speed * 1.15
		and conveyor.hazard_speed_multiplier_at(40.0) == 1.12,
		"Sweeper caps at 115 percent while the can fall curve remains capped at 12 percent"
	)
	await _free_conveyor(conveyor)


func _test_natural_director_lifecycle() -> void:
	var conveyor := await _make_conveyor(true)
	var pattern_records: Array[Dictionary] = []
	var longest_reservation_wait := 0.0
	var reservation_started_at := -1.0
	conveyor.pattern_started.connect(
		func(pattern_type: int, started_at: float) -> void:
			pattern_records.append({
				"type": pattern_type,
				"time": started_at,
			})
	)

	var maximum_frames := ceili(25.0 * Engine.physics_ticks_per_second)
	for _frame in range(maximum_frames):
		await physics_frame
		if conveyor.reserved_pattern_type() >= 0:
			if reservation_started_at < 0.0:
				reservation_started_at = conveyor.survival_time
			else:
				longest_reservation_wait = maxf(
					longest_reservation_wait,
					conveyor.survival_time - reservation_started_at
				)
		else:
			reservation_started_at = -1.0

	_check(not pattern_records.is_empty(), "Natural director launches patterns")
	var first_interaction_time: float = (
		pattern_records[0].time if not pattern_records.is_empty() else INF
	)
	_check(
		first_interaction_time >= 1.0 and first_interaction_time <= 2.0,
		"First interaction starts inside the approved 1–2 second window"
	)

	var teaching_types: Array[int] = []
	var first_compound_time := INF
	var compound_count_by_twenty := 0
	var maximum_sweeper_gap := 0.0
	var prior_sweeper_time := -1.0
	var has_repeated_can_only := false
	var previous_type := -1
	for record in pattern_records:
		var pattern_type: int = record.type
		var started_at: float = record.time
		if started_at < conveyor.teaching_phase_end:
			teaching_types.append(pattern_type)
		if pattern_type >= ConveyorPrototype.PatternType.SWEEPER_THEN_CAN:
			first_compound_time = minf(first_compound_time, started_at)
			if started_at <= 20.0:
				compound_count_by_twenty += 1
		if pattern_type != ConveyorPrototype.PatternType.CAN_ONLY:
			if prior_sweeper_time >= 0.0 and started_at >= 5.0:
				maximum_sweeper_gap = maxf(
					maximum_sweeper_gap,
					started_at - prior_sweeper_time
				)
			prior_sweeper_time = started_at
		if (
			pattern_type == ConveyorPrototype.PatternType.CAN_ONLY
			and previous_type == ConveyorPrototype.PatternType.CAN_ONLY
		):
			has_repeated_can_only = true
		previous_type = pattern_type

	_check(
		teaching_types.has(ConveyorPrototype.PatternType.CAN_ONLY)
		and teaching_types.has(ConveyorPrototype.PatternType.SWEEPER_ONLY),
		"Teaching phase naturally presents both simple hazard rules"
	)
	_check(
		first_compound_time >= 5.0 and first_compound_time <= 8.0,
		"First compound naturally commits by the approved deadline"
	)
	_check(
		conveyor.both_compound_templates_presented(),
		"Both compound templates naturally appear"
	)
	_check(
		compound_count_by_twenty >= 4,
		"Several compound decisions commit by twenty seconds"
	)
	_check(
		not has_repeated_can_only,
		"Natural director never repeats can-only consecutively"
	)
	_check(
		maximum_sweeper_gap <= 4.05,
		"Natural sweeper-related gap remains inside the four-second ceiling"
	)
	_check(
		longest_reservation_wait <= 3.0,
		"Compound reservation wait remains bounded"
	)
	print(
		"DIRECTOR_NATURAL_METRICS first_interaction=%.3fs first_compound=%.3fs max_sweeper_gap=%.3fs max_reservation_wait=%.3fs compound_by_20=%d patterns=%d"
		% [
			first_interaction_time,
			first_compound_time,
			maximum_sweeper_gap,
			longest_reservation_wait,
			compound_count_by_twenty,
			pattern_records.size(),
		]
	)
	print("DIRECTOR_PATTERN_TRACE ", pattern_records)
	await _free_conveyor(conveyor)


func _test_restart_resets_director() -> void:
	var error := change_scene_to_file(CONVEYOR_SCENE_PATH)
	_check(error == OK, "Director restart fixture loads Prototype B")
	await scene_changed
	await physics_frame
	var conveyor := current_scene as ConveyorPrototype
	conveyor.left_failure_enabled = false
	conveyor.player.collision_layer = 0
	for _frame in range(240):
		await physics_frame
		if conveyor.teaching_patterns_presented():
			break
	_check(
		conveyor.teaching_patterns_presented()
		and conveyor.last_pattern_type() >= 0,
		"Restart fixture records director history"
	)
	conveyor.maximum_active_sweepers = 0
	conveyor.player.position.x = conveyor.control_band_right
	Input.action_press("move_right")
	for _frame in range(
		ceili(
			(conveyor.right_edge_dwell_threshold + 0.1)
			* Engine.physics_ticks_per_second
		)
	):
		await physics_frame
	Input.action_release("move_right")
	_check(
		conveyor.right_pressure_is_requested()
		or conveyor.reserved_pattern_type()
			== ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE,
		"Restart fixture contains right-edge dwell or a reserved pressure pattern"
	)

	var prior_instance_id := conveyor.get_instance_id()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	conveyor._unhandled_input(restart_event)
	await scene_changed
	await physics_frame
	var restarted := current_scene as ConveyorPrototype
	_check(
		restarted.get_instance_id() != prior_instance_id,
		"Restart replaces the director session"
	)
	_check(
		not restarted.teaching_patterns_presented()
		and restarted.first_compound_pattern_time() < 0.0
		and restarted.last_pattern_type() == -1
		and restarted.reserved_pattern_type() == -1
		and restarted.active_pattern_type() == -1
		and not restarted.has_pending_pattern_events()
		and restarted.active_product_count() == 0
		and restarted.active_sweeper_count() == 0
		and restarted.right_edge_dwell_time() == 0.0
		and not restarted.right_pressure_is_requested()
		and restarted.encounter_log().is_empty()
		and restarted.survival_time < 0.1,
		"Restart clears director, edge dwell, encounter logs, warnings, and hazards"
	)


func _make_conveyor(disable_player_hazards: bool) -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	conveyor.left_failure_enabled = false
	root.add_child(conveyor)
	await physics_frame
	if disable_player_hazards:
		conveyor.player.collision_layer = 0
	return conveyor


func _free_conveyor(conveyor: ConveyorPrototype) -> void:
	if is_instance_valid(conveyor):
		conveyor.queue_free()
	await process_frame


func _ratio_of_simple(counts: PackedInt32Array) -> float:
	var total := _count_total(counts)
	if total <= 0:
		return 0.0
	return float(counts[0] + counts[1]) / total


func _ratio_of_compound(counts: PackedInt32Array) -> float:
	var total := _count_total(counts)
	if total <= 0:
		return 0.0
	return float(counts[2] + counts[3]) / total


func _count_total(counts: PackedInt32Array) -> int:
	var total := 0
	for count in counts:
		total += count
	return total
