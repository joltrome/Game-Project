extends SceneTree

const MOTION_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const CHECKPOINTS := [0.0, 10.0, 20.0, 30.0, 45.0, 60.0, 75.0, 90.0]
const FIXED_STEP := 1.0 / 120.0
const PROFILE_END := 100.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var shell := MOTION_SCENE.instantiate() as MotionExperimentShell
	shell.local_instrumentation_enabled = false
	shell.overload_mode_enabled = true
	shell.vm081_presentation_enabled = true
	root.add_child(shell)
	await process_frame
	var conveyor := shell.conveyor
	var d3 := shell.background_drop_director
	var coins := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	coins.ballistic_coin_events_enabled = true
	coins.ballistic_abundance_enabled = true
	coins.ballistic_integrity_enabled = true
	coins.refund_chute_enabled = true
	coins.refund_system_enabled = true
	coins.static_teaching_coin_enabled = false
	coins.bounded_optional_planning_enabled = true
	coins.bounded_event_total_attempts = 112
	coins.coin_pressure_enabled = true
	coins.performance_profiling_enabled = true
	conveyor.left_failure_enabled = false
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	conveyor.player.position = Vector2(640.0, 420.0)
	conveyor.set_physics_process(false)
	(coins as Node).set_process(false)
	d3.set_process(false)
	var windows: Array[Dictionary] = []
	for checkpoint in CHECKPOINTS:
		windows.append(_new_window(checkpoint))
	var all_step_ms := PackedFloat32Array()
	while conveyor.survival_time < PROFILE_END - 0.0001:
		var started_usec := Time.get_ticks_usec()
		conveyor._physics_process(FIXED_STEP)
		coins._process(FIXED_STEP)
		d3._process(FIXED_STEP)
		for product in conveyor.active_falling_products():
			product._physics_process(FIXED_STEP)
		for product in conveyor.active_landed_products():
			var support := product.get_node_or_null("LandedBody") as AnimatableBody2D
			if support != null:
				support.sync_to_physics = false
			product._physics_process(FIXED_STEP)
		for sweeper in conveyor.active_sweepers():
			if is_instance_valid(sweeper):
				sweeper._physics_process(FIXED_STEP)
		var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
		all_step_ms.append(elapsed_ms)
		_sample_window(windows, conveyor, d3, elapsed_ms)

	var encounter_log := conveyor.encounter_log()
	var d3_log := d3.event_log()
	print("VM0812_EFFECTIVE_PRESSURE_STATE ", JSON.stringify({
		"reserved_pattern": conveyor.reserved_pattern_type(),
		"active_pattern": conveyor.active_pattern_type(),
		"external_pending": conveyor.external_product_event_is_pending(),
		"external_active": conveyor.external_product_sequence_is_active(),
		"encounter_count": encounter_log.size(),
		"d3_rejections": d3.rejection_counts_by_reason(),
		"d3_candidate_rejections": d3.candidate_rejection_counts_by_reason(),
	}))
	for index in windows.size():
		var end_time: float = float(CHECKPOINTS[index + 1]) if index + 1 < CHECKPOINTS.size() else PROFILE_END
		var summary := _finish_window(windows[index], end_time, encounter_log, d3_log)
		print("VM0812_EFFECTIVE_PRESSURE ", JSON.stringify(summary))
	print("VM0812_EFFECTIVE_PRESSURE_PERFORMANCE ", JSON.stringify(_frame_summary(all_step_ms)))
	shell.queue_free()
	await process_frame
	quit()


func _new_window(start_time: float) -> Dictionary:
	return {
		"checkpoint": start_time,
		"samples": 0,
		"at_least_one": 0,
		"at_least_two": 0,
		"maximum_threats": 0,
		"hazard_free_seconds": 0.0,
		"current_hazard_free_seconds": 0.0,
		"maximum_hazard_free_seconds": 0.0,
		"step_ms": PackedFloat32Array(),
	}


func _sample_window(
	windows: Array[Dictionary],
	conveyor: ConveyorPrototype,
	d3: MotionBackgroundDropDirector,
	elapsed_ms: float
) -> void:
	var index := _window_index(conveyor.survival_time)
	var window: Dictionary = windows[index]
	var threats := (
		conveyor.active_sweeper_count()
		+ conveyor.falling_product_count()
		+ conveyor.landed_product_count()
		+ (1 if conveyor.sweeper_cue_is_visible() else 0)
		+ (1 if conveyor.warning_is_visible() else 0)
		+ d3.active_sequence_count()
	)
	window.samples = int(window.samples) + 1
	window.maximum_threats = maxi(int(window.maximum_threats), threats)
	window.step_ms.append(elapsed_ms)
	if threats >= 1:
		window.at_least_one = int(window.at_least_one) + 1
		window.current_hazard_free_seconds = 0.0
	else:
		window.hazard_free_seconds = float(window.hazard_free_seconds) + FIXED_STEP
		window.current_hazard_free_seconds = float(window.current_hazard_free_seconds) + FIXED_STEP
		window.maximum_hazard_free_seconds = maxf(
			float(window.maximum_hazard_free_seconds),
			float(window.current_hazard_free_seconds)
		)
	if threats >= 2:
		window.at_least_two = int(window.at_least_two) + 1
	windows[index] = window


func _window_index(time_seconds: float) -> int:
	var result := 0
	for index in CHECKPOINTS.size():
		if time_seconds + 0.0001 >= CHECKPOINTS[index]:
			result = index
	return result


func _finish_window(
	window: Dictionary,
	end_time: float,
	encounters: Array[Dictionary],
	d3_events: Array[Dictionary]
) -> Dictionary:
	var start_time := float(window.checkpoint)
	var duration := maxf(end_time - start_time, 0.001)
	var attempts := 0
	var accepted := 0
	var sweeps := 0
	var ordinary_drops := 0
	var compounds := 0
	var rejection_reasons := {}
	for entry in encounters:
		var time := float(entry.get("time", -INF))
		if time < start_time or time >= end_time:
			continue
		match String(entry.get("event", "")):
			"pattern_attempt":
				attempts += 1
			"pattern_commit":
				accepted += 1
				var pattern := int(entry.get("pattern_type", -1))
				if pattern in [ConveyorPrototype.PatternType.SWEEPER_THEN_CAN, ConveyorPrototype.PatternType.CAN_THEN_SWEEPER, ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE]:
					compounds += 1
			"sweeper_spawn":
				sweeps += 1
			"can_warning":
				ordinary_drops += 1
			"pattern_rejected":
				var reason := String(entry.get("reason", "unknown"))
				rejection_reasons[reason] = int(rejection_reasons.get(reason, 0)) + 1
	var d3_warnings := 0
	var d3_overlaps := 0
	for entry in d3_events:
		var time := float(entry.get("time", -INF))
		if time < start_time or time >= end_time:
			continue
		if String(entry.get("event", "")) == "warning":
			d3_warnings += 1
			for encounter in encounters:
				if String(encounter.get("event", "")) == "sweeper_spawn" and absf(float(encounter.get("time", -INF)) - time) <= 2.0:
					d3_overlaps += 1
					break
	var samples := maxi(int(window.samples), 1)
	var frame := _frame_summary(window.step_ms)
	return {
		"checkpoint": start_time,
		"window_seconds": duration,
		"attempted_patterns_per_minute": float(attempts) * 60.0 / duration,
		"accepted_patterns_per_minute": float(accepted) * 60.0 / duration,
		"rejected_patterns_per_minute": float(maxi(attempts - accepted, 0)) * 60.0 / duration,
		"rejection_reasons": rejection_reasons,
		"sweeps_per_minute": float(sweeps) * 60.0 / duration,
		"ordinary_drops_per_minute": float(ordinary_drops) * 60.0 / duration,
		"d3_warnings_per_minute": float(d3_warnings) * 60.0 / duration,
		"compound_patterns_per_minute": float(compounds) * 60.0 / duration,
		"accepted_d3_electrical_overlaps_per_minute": float(d3_overlaps) * 60.0 / duration,
		"average_no_hazard_seconds_per_second": float(window.hazard_free_seconds) / duration,
		"maximum_hazard_free_interval_seconds": float(window.maximum_hazard_free_seconds),
		"percent_at_least_one_threat": float(window.at_least_one) * 100.0 / float(samples),
		"percent_at_least_two_threats": float(window.at_least_two) * 100.0 / float(samples),
		"maximum_simultaneous_threats": int(window.maximum_threats),
		"planner_frame_mean_ms": frame.average_cpu_ms,
		"planner_frame_p95_ms": frame.p95_cpu_ms,
		"planner_frame_p99_ms": frame.p99_cpu_ms,
		"planner_frame_worst_ms": frame.worst_cpu_ms,
	}


func _frame_summary(samples: PackedFloat32Array) -> Dictionary:
	var ordered := Array(samples)
	ordered.sort()
	var total := 0.0
	var over_16 := 0
	var over_33 := 0
	var over_50 := 0
	for value in samples:
		total += value
		if value > 16.67:
			over_16 += 1
		if value > 33.33:
			over_33 += 1
		if value > 50.0:
			over_50 += 1
	return {
		"average_cpu_ms": total / float(maxi(samples.size(), 1)),
		"p95_cpu_ms": _percentile(ordered, 0.95),
		"p99_cpu_ms": _percentile(ordered, 0.99),
		"worst_cpu_ms": _percentile(ordered, 1.0),
		"steps_over_16_67_ms": over_16,
		"steps_over_33_33_ms": over_33,
		"steps_over_50_ms": over_50,
	}


func _percentile(ordered: Array, percentile: float) -> float:
	if ordered.is_empty():
		return 0.0
	return float(ordered[clampi(roundi((ordered.size() - 1) * percentile), 0, ordered.size() - 1)])
