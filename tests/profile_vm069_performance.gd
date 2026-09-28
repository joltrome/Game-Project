extends SceneTree

const MOTION_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const PRODUCT_SCENE := preload("res://scenes/hazards/conveyor_product.tscn")
const TEST_SEEDS := [401, 1701, 4202]
const EXTENDED_TEST_SEEDS := [401, 1701, 4202, 7007, 9011]
const FIXED_STEP := 1.0 / 120.0
const PROFILE_SECONDS := 60.0

var _stress_enabled := true
var _mode_filter := ""
var _extended_seeds := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--natural":
			_stress_enabled = false
		elif argument.begins_with("--mode="):
			_mode_filter = argument.trim_prefix("--mode=")
		elif argument == "--five-seeds":
			_extended_seeds = true
	var integrity_available := await _director_has_integrity_property()
	for mode in [
		{"name": "VM066", "ballistic": false, "abundance": false, "integrity": false, "refund_chute": false},
		{"name": "VM068", "ballistic": true, "abundance": true, "integrity": false, "refund_chute": false},
		{"name": "VM069", "ballistic": true, "abundance": true, "integrity": true, "refund_chute": false},
		{"name": "VM0610", "ballistic": true, "abundance": true, "integrity": true, "refund_chute": true, "refund_system": false},
		{"name": "VM070", "ballistic": true, "abundance": true, "integrity": true, "refund_chute": true, "refund_system": true},
		{"name": "VM071", "ballistic": true, "abundance": true, "integrity": true, "refund_chute": true, "refund_system": true, "mobile_budget": true},
		{"name": "VM073", "ballistic": true, "abundance": true, "integrity": true, "refund_chute": true, "refund_system": true, "mobile_budget": true, "coin_pressure": true},
		{"name": "VM080", "ballistic": true, "abundance": true, "integrity": true, "refund_chute": true, "refund_system": true, "mobile_budget": true, "coin_pressure": true, "overload": true},
	]:
		if not _mode_filter.is_empty() and String(mode.name) != _mode_filter:
			continue
		if bool(mode.integrity) and not integrity_available:
			continue
		for seed in EXTENDED_TEST_SEEDS if _extended_seeds else TEST_SEEDS:
			var result := await _profile_mode(mode, seed)
			print("VM069_NATIVE_PROFILE ", JSON.stringify(result))
	quit()


func _profile_mode(mode: Dictionary, seed: int) -> Dictionary:
	var shell := MOTION_SCENE.instantiate() as MotionExperimentShell
	shell.local_instrumentation_enabled = false
	root.add_child(shell)
	await process_frame
	var conveyor := shell.conveyor
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var d3 := shell.background_drop_director
	var overload_enabled := bool(mode.get("overload", false))
	conveyor.configure_overload_mode(overload_enabled)
	d3.endless_schedule_enabled = overload_enabled
	director.ballistic_coin_events_enabled = bool(mode.ballistic)
	director.ballistic_abundance_enabled = bool(mode.abundance)
	if _has_property(director, &"ballistic_integrity_enabled"):
		director.set("ballistic_integrity_enabled", bool(mode.integrity))
	if _has_property(director, &"refund_chute_enabled"):
		director.set("refund_chute_enabled", bool(mode.refund_chute))
	if _has_property(director, &"refund_system_enabled"):
		director.set("refund_system_enabled", bool(mode.get("refund_system", false)))
	if _has_property(director, &"static_teaching_coin_enabled"):
		director.set(
			"static_teaching_coin_enabled",
			bool(mode.get("refund_system", false)) and not overload_enabled
		)
	if _has_property(director, &"bounded_optional_planning_enabled"):
		director.set("bounded_optional_planning_enabled", bool(mode.get("mobile_budget", false)))
	if _has_property(director, &"coin_pressure_enabled"):
		director.set("coin_pressure_enabled", bool(mode.get("coin_pressure", false)))
	director.performance_profiling_enabled = true
	director.placement_seed = seed
	director._placement_rng_state = seed
	director._stream_rng_state = maxi(
		posmod(seed * 1664525 + 1013904223, 0x7fffffff),
		1
	)
	conveyor.initial_warning_delay = 999.0 if not overload_enabled else 0.0
	conveyor.left_failure_enabled = false
	conveyor.set_physics_process(false)
	if overload_enabled:
		conveyor._pattern_cooldown_remaining = 0.0
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director.set_process(false)
	d3.set_process(false)
	conveyor.player.global_position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)

	var frame_cpu_ms := PackedFloat32Array()
	var planning_frame_cpu_ms := PackedFloat32Array()
	var ricochet_frame_cpu_ms := PackedFloat32Array()
	var active_coin_total := 0
	var active_coin_maximum := 0
	var landed_can_total := 0
	var landed_can_maximum := 0
	var active_hazard_total := 0
	var active_hazard_maximum := 0
	var ricochet_steps := 0
	var injected_stress := false
	var profile_seconds := 120.0 if overload_enabled else PROFILE_SECONDS
	while conveyor.survival_time < profile_seconds - 0.0001:
		if (
			_stress_enabled
			and not injected_stress
			and conveyor.survival_time >= 20.0
		):
			_inject_landed_can_stress(conveyor)
			injected_stress = true
		var event_count_before := director.performance_event_log().size()
		var started_usec := Time.get_ticks_usec()
		if overload_enabled:
			conveyor._physics_process(FIXED_STEP)
		else:
			conveyor.survival_time += FIXED_STEP
			conveyor._update_continuous_speed_ramps()
		if bool(mode.integrity):
			director.invalidate_landed_can_collision_cache_for_test()
		var ricocheting_this_step := 0
		for coin in director.active_collectibles():
			if coin.motion_state() == ConveyorCollectible.MotionState.RICOCHETING:
				ricocheting_this_step += 1
			coin._physics_process(FIXED_STEP)
			coin._process(FIXED_STEP)
		director._process(FIXED_STEP)
		d3._process(FIXED_STEP)
		for product in conveyor.active_falling_products():
			product._physics_process(FIXED_STEP)
		for product in conveyor.active_landed_products():
			# The profiler advances fixed steps synchronously without yielding to
			# PhysicsServer2D. Disable transform synchronization only in this test
			# fixture so the moving support accumulates the same leftward positions
			# that normal engine-driven physics commits between frames.
			var support := product.get_node_or_null("LandedBody") as AnimatableBody2D
			if support != null:
				support.sync_to_physics = false
			product._physics_process(FIXED_STEP)
		for sweeper in conveyor._active_sweepers:
			if is_instance_valid(sweeper):
				sweeper._physics_process(FIXED_STEP)
		var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
		frame_cpu_ms.append(elapsed_ms)
		if director.performance_event_log().size() > event_count_before:
			planning_frame_cpu_ms.append(elapsed_ms)
		if ricocheting_this_step > 0:
			ricochet_frame_cpu_ms.append(elapsed_ms)
			ricochet_steps += ricocheting_this_step
		var active_coins := director.active_collectible_count()
		var landed_cans := conveyor.landed_product_count()
		var active_hazards := (
			conveyor.falling_product_count()
			+ conveyor.active_sweeper_count()
		)
		active_coin_total += active_coins
		active_coin_maximum = maxi(active_coin_maximum, active_coins)
		landed_can_total += landed_cans
		landed_can_maximum = maxi(landed_can_maximum, landed_cans)
		active_hazard_total += active_hazards
		active_hazard_maximum = maxi(active_hazard_maximum, active_hazards)

	var result := _frame_summary(frame_cpu_ms)
	result.mode = String(mode.name)
	result.scenario = "STRESS" if _stress_enabled else "NATURAL"
	result.seed = seed
	result.samples = frame_cpu_ms.size()
	result.average_active_coins = float(active_coin_total) / float(maxi(frame_cpu_ms.size(), 1))
	result.maximum_active_coins = active_coin_maximum
	result.average_landed_cans = float(landed_can_total) / float(maxi(frame_cpu_ms.size(), 1))
	result.maximum_landed_cans = landed_can_maximum
	result.average_active_hazards = float(active_hazard_total) / float(maxi(frame_cpu_ms.size(), 1))
	result.maximum_active_hazards = active_hazard_maximum
	result.ricochet_steps = ricochet_steps
	result.planning_frame_average_ms = _average(planning_frame_cpu_ms)
	result.ricochet_frame_average_ms = _average(ricochet_frame_cpu_ms)
	result.planning = director.performance_profile_summary()
	result.delivered = director.spawn_count
	result.event_count = director.coin_event_count()
	result.placement_rejections = director.rejection_counts()
	result.observed_integrity = _event_integrity_from_log(
		director.coin_event_log()
	)
	result.ballistic_run = director.ballistic_run_summary()
	result.coin_pressure = director.coin_pressure_summary()
	var integrity_summary: Dictionary = result.ballistic_run
	result.requested = (
		int(integrity_summary.get("selected_singles", 0))
		+ int(integrity_summary.get("selected_doubles", 0)) * 2
		+ int(integrity_summary.get("selected_triples", 0)) * 3
	)
	result.d3_warning_times = d3.successful_warning_times()
	result.d3_longest_gap = d3.longest_successful_warning_gap()
	result.d3_rejections = d3.candidate_rejection_counts_by_reason()
	if overload_enabled:
		result.overload_intensity = conveyor.overload_intensity_snapshot(conveyor.survival_time)
	if _has_method(director, &"ballistic_integrity_summary"):
		result.integrity = director.call("ballistic_integrity_summary")
	shell.queue_free()
	await process_frame
	return result


func _inject_landed_can_stress(conveyor: ConveyorPrototype) -> void:
	for x in [620.0, 760.0, 900.0]:
		var product := PRODUCT_SCENE.instantiate() as ConveyorProduct
		product.position = Vector2(x, conveyor.floor_y - conveyor.landed_product_size.y * 0.5)
		product.configure_conveyor(
			0.0,
			conveyor.floor_y,
			30.0,
			conveyor.despawn_warning_duration,
			conveyor.product_size,
			conveyor.landed_product_size,
			conveyor.conveyor_speed,
			conveyor.offscreen_cleanup_x,
			conveyor.effective_product_falling_collision_size()
		)
		product.landed.connect(conveyor._on_product_landed)
		product.cleared.connect(conveyor._on_product_cleared)
		conveyor.get_node("Hazards").add_child(product)
		product._land()


func _frame_summary(samples: PackedFloat32Array) -> Dictionary:
	var ordered := Array(samples)
	ordered.sort()
	var total := 0.0
	var over_16 := 0
	var over_25 := 0
	var over_33 := 0
	var over_50 := 0
	for value in samples:
		total += value
		if value > 16.67:
			over_16 += 1
		if value > 25.0:
			over_25 += 1
		if value > 33.33:
			over_33 += 1
		if value > 50.0:
			over_50 += 1
	var average_ms := total / float(maxi(samples.size(), 1))
	return {
		"average_cpu_ms": average_ms,
		"median_cpu_ms": _percentile(ordered, 0.50),
		"p95_cpu_ms": _percentile(ordered, 0.95),
		"p99_cpu_ms": _percentile(ordered, 0.99),
		"worst_cpu_ms": _percentile(ordered, 1.0),
		"steps_over_16_67_ms": over_16,
		"steps_over_25_ms": over_25,
		"steps_over_33_33_ms": over_33,
		"steps_over_50_ms": over_50,
		"cpu_steps_per_second": 1000.0 / average_ms if average_ms > 0.0 else INF,
	}


func _event_integrity_from_log(events: Array[Dictionary]) -> Dictionary:
	var selected_doubles := 0
	var full_doubles := 0
	var selected_triples := 0
	var full_triples := 0
	for event in events:
		var requested := int(event.get("requested_count", 0))
		var spawned := int(event.get("spawned_count", 0))
		if requested == 2:
			selected_doubles += 1
			if spawned == 2:
				full_doubles += 1
		elif requested == 3:
			selected_triples += 1
			if spawned == 3:
				full_triples += 1
	return {
		"selected_doubles": selected_doubles,
		"full_doubles": full_doubles,
		"double_integrity_rate": (
			float(full_doubles) / float(selected_doubles)
			if selected_doubles > 0
			else 0.0
		),
		"selected_triples": selected_triples,
		"full_triples": full_triples,
		"triple_integrity_rate": (
			float(full_triples) / float(selected_triples)
			if selected_triples > 0
			else 0.0
		),
	}


func _percentile(ordered: Array, percentile: float) -> float:
	if ordered.is_empty():
		return 0.0
	var index := clampi(
		roundi((ordered.size() - 1) * clampf(percentile, 0.0, 1.0)),
		0,
		ordered.size() - 1
	)
	return float(ordered[index])


func _average(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _director_has_integrity_property() -> bool:
	var shell := MOTION_SCENE.instantiate() as MotionExperimentShell
	root.add_child(shell)
	await process_frame
	var director := shell.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var result := _has_property(director, &"ballistic_integrity_enabled")
	shell.queue_free()
	await process_frame
	return result


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false


func _has_method(object: Object, method_name: StringName) -> bool:
	return object.has_method(method_name)
