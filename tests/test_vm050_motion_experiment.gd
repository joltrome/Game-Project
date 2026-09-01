extends SceneTree

const D2_SCENE_PATH := "res://scenes/experiments/motion_d2.tscn"
const D3_SCENE_PATH := "res://scenes/experiments/motion_d3.tscn"
const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const ARENA_SCENE_PATH := "res://scenes/prototypes/arena.tscn"
const FLOAT_TOLERANCE := 0.05

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	await _test_isolated_profiles_and_frozen_values()
	await _test_aspect_containment_matrix()
	await _test_d3_exact_and_heuristic_fairness_checks()
	await _test_invalid_reservation_retries_without_stalling()
	await _test_multi_seed_stress_scheduler_reports()
	await _test_background_collision_instrumentation()
	await _test_death_and_completion_clear_schedule_state()
	await _test_fresh_scene_resets_local_state()
	print("VM050_MOTION_EXPERIMENT_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_isolated_profiles_and_frozen_values() -> void:
	var base := (load(CONVEYOR_SCENE_PATH) as PackedScene).instantiate() as ConveyorPrototype
	root.add_child(base)
	await physics_frame
	var frozen_values := _gameplay_snapshot(base)

	var d2 := await _make_shell(D2_SCENE_PATH)
	var d3 := await _make_shell(D3_SCENE_PATH)
	_check(d2.internal_size == Vector2i(1152, 480), "D2 owns an exact 1152x480 internal viewport")
	_check(d3.internal_size == Vector2i(1152, 648), "D3 owns an exact 1152x648 internal viewport")
	_check(absf(d2.internal_aspect_ratio() - 2.4) <= 0.0001, "D2 internal presentation is exactly 2.4:1")
	_check(absf(d3.internal_aspect_ratio() - (16.0 / 9.0)) <= 0.0001, "D3 internal presentation is exactly 16:9")
	_check(d2.uses_nearest_filtering() and d3.uses_nearest_filtering(), "Both profiles use nearest texture filtering")
	_check(
		(d2.conveyor.get_node("HUD/BuildId") as Label).text == "BUILD VM-0.5.0-MOTION-01-D2",
		"D2 exposes its neutral internal build ID"
	)
	_check(
		(d3.conveyor.get_node("HUD/BuildId") as Label).text
			== "BUILD VM-0.5.0-VIS-01-D3-V2",
		"D3 exposes the VIS-01 V2 integration build ID"
	)
	_check(
		d2.background_drop_director == null
		and not d2.conveyor.product_event_replacement_handler_is_set(),
		"D2 contains no background-drop scheduler or replacement hook"
	)
	_check(
		d3.background_drop_director != null
		and not d3.conveyor.product_event_replacement_handler_is_set()
		and d3.conveyor.reserved_ordinary_product_suppression_count() == 0,
		"D3 starts with an isolated director and no unresolved suppression debt"
	)
	_check(
		_gameplay_snapshot(d2.conveyor) == frozen_values
		and _gameplay_snapshot(d3.conveyor) == frozen_values,
		"Both motion variants preserve the frozen VM-0.4.7 gameplay values"
	)
	_check(
		ProjectSettings.get_setting("application/run/main_scene") == CONVEYOR_SCENE_PATH,
		"The project-wide default scene remains the frozen conveyor"
	)
	_check(
		load(ARENA_SCENE_PATH) != null,
		"Frozen Prototype A remains independently loadable"
	)
	_check(
		d2.conveyor.get_node_or_null("MotionArcadeBackground") is MotionArcadeVisual
		and d2.conveyor.get_node_or_null("MotionArcadeForeground") is MotionArcadeVisual,
		"D2 uses project-owned code-native background and frame visuals"
	)
	base.queue_free()
	d2.queue_free()
	d3.queue_free()
	await process_frame


func _test_aspect_containment_matrix() -> void:
	var content := Vector2(1152.0, 480.0)
	var hosts := {
		"16:9": Vector2(1152.0, 648.0),
		"16:10": Vector2(1152.0, 720.0),
		"2.4:1": Vector2(1152.0, 480.0),
		"20:9": Vector2(1200.0, 540.0),
		"narrow_tablet": Vector2(900.0, 700.0),
	}
	for host_name in hosts:
		var host: Vector2 = hosts[host_name]
		var rect := MotionExperimentShell.contained_rect(host, content)
		var unused_ratio := 1.0 - ((rect.size.x * rect.size.y) / (host.x * host.y))
		print(
			"VM050_D2_ASPECT host=%s host_size=%s display=%s origin=%s unused_ratio=%.4f"
			% [host_name, host, rect.size, rect.position, unused_ratio]
		)
		_check(
			absf(rect.size.x / rect.size.y - 2.4) <= 0.0001,
			"D2 remains unstretched in %s host" % host_name
		)
		_check(
			rect.position.x >= -FLOAT_TOLERANCE
			and rect.position.y >= -FLOAT_TOLERANCE
			and rect.end.x <= host.x + FLOAT_TOLERANCE
			and rect.end.y <= host.y + FLOAT_TOLERANCE,
			"D2 remains inside %s host bounds" % host_name
		)
		_check(
			rect.position.distance_to((host - rect.size) * 0.5) <= FLOAT_TOLERANCE,
			"D2 is centred in %s host" % host_name
		)
	var exact_rect := MotionExperimentShell.contained_rect(content, content)
	_check(
		exact_rect.position == Vector2.ZERO and exact_rect.size == content,
		"The native 2.4:1 host uses exact 1:1 pixels with no unused area"
	)


func _test_d3_exact_and_heuristic_fairness_checks() -> void:
	var d3 := await _make_shell(D3_SCENE_PATH)
	var director := d3.background_drop_director
	d3.conveyor.left_failure_enabled = false
	d3.conveyor.player.set_physics_process(false)
	d3.conveyor.player.position = Vector2(640.0, 420.0)
	d3.conveyor.player.collision_layer = 0
	var configured_times := director.configured_event_times()
	_check(configured_times.size() == 6, "D3 configures six stress-test reservations")
	_check(
		configured_times[0] >= 8.0 and configured_times[0] <= 10.0,
		"D3 first reservation is configured inside the 8-10 second window"
	)
	for index in range(1, configured_times.size()):
		var configured_gap := configured_times[index] - configured_times[index - 1]
		_check(
			configured_gap >= director.minimum_repeat_interval - 0.001
			and configured_gap <= director.maximum_repeat_interval + 0.001,
			"D3 configured interval %d stays inside the 7-9 second range" % index
		)
	_check(
		director.candidate_rejection_reason(420.0).is_empty(),
		"An empty-arena D3 lane passes bounds, overlap, and response validation"
	)
	var original_x := d3.conveyor.player.position.x
	d3.conveyor.player.position.x = 560.0
	_check(
		not director.safe_response_exists(560.0, 0.0),
		"Zero-time player overlap is rejected as unreachable"
	)
	d3.conveyor.player.position.x = original_x
	_check(
		director.candidate_rejection_reason(790.0) == "outside_player_band",
		"D3 rejects a release outside the frozen player control band"
	)
	director.reservation_pending = true
	director._active_schedule_index = 0
	var replacement_id := director._try_start_reserved_sequence()
	_check(
		not replacement_id.is_empty()
		and director.state == MotionBackgroundDropDirector.VisualState.SELECTED
		and is_equal_approx(director.warning_time_remaining, director.warning_duration),
		"A committed D3 selection starts the exact configured warning countdown"
	)
	director.set_process(false)
	director._process(0.40)
	_check(
		absf(director.warning_time_remaining - 0.70) <= 0.001,
		"D3 warning countdown advances deterministically"
	)
	director._process(0.71)
	_check(
		director.state == MotionBackgroundDropDirector.VisualState.RELEASED
		and d3.conveyor.falling_product_count() == 1,
		"D3 releases exactly when its configured warning reaches zero"
	)
	var direct_products := d3.conveyor.active_falling_products()
	var released_product: ConveyorProduct = direct_products[0] if not direct_products.is_empty() else null
	var expected_fall_speed := (
		d3.conveyor.floor_y
		- d3.conveyor.product_size.y * 0.5
		- director.release_y
	) / director.target_fall_duration
	_check(
		released_product != null
		and absf(released_product.fall_speed - expected_fall_speed) <= 0.001,
		"D3 derives falling speed from actual release-to-floor distance and target duration"
	)
	d3.queue_free()
	await process_frame


func _test_invalid_reservation_retries_without_stalling() -> void:
	var d3 := await _make_shell(D3_SCENE_PATH)
	var director := d3.background_drop_director
	d3.conveyor.left_failure_enabled = false
	d3.conveyor.player.position = Vector2(640.0, 420.0)
	d3.conveyor.player.collision_layer = 0
	director.reservation_pending = true
	director._active_schedule_index = 0
	var original_lanes := director.candidate_lane_x
	director.candidate_lane_x = PackedFloat32Array([790.0])
	var rejected_id := director._try_start_reserved_sequence()
	_check(
		rejected_id.is_empty()
		and director.reservation_pending
		and director.visual_state_name() == "stored",
		"An invalid stress reservation remains pending instead of spawning or stalling"
	)
	director.candidate_lane_x = original_lanes
	director._replacement_retry_remaining = 0.0
	var accepted_id := director._try_start_reserved_sequence()
	_check(
		not accepted_id.is_empty()
		and director.visual_state_name() == "selected",
		"The retained reservation succeeds on the next valid retry"
	)
	_check(
		director.rejection_counts_by_reason().get("no_valid_background_lane", 0) == 1,
		"The invalid attempt records its exact rejection reason"
	)
	d3.queue_free()
	await process_frame


func _test_multi_seed_stress_scheduler_reports() -> void:
	var baseline_product_count := await _run_frozen_baseline_product_count()
	for seed in [5002, 6011, 7907]:
		var report := await _run_stress_seed(seed)
		var drop_count := int(report.background_drops)
		var warning_times: PackedFloat32Array = report.warning_times
		var lanes: PackedInt32Array = report.lanes
		_check(
			drop_count == 6,
			"Seed %d naturally completes the configured six-drop stress target" % seed
		)
		_check(
			not warning_times.is_empty()
			and warning_times[0] >= 8.0
			and warning_times[0] <= 10.5,
			"Seed %d starts its first successful warning in the early window" % seed
		)
		for index in range(1, warning_times.size()):
			_check(
				warning_times[index] - warning_times[index - 1] >= 6.95,
				"Seed %d successful event %d respects the minimum gap" % [seed, index]
			)
		_check(
			float(report.longest_gap) < 15.0,
			"Seed %d has no scheduler-starvation gap of 15 seconds" % seed
		)
		_check(
			int(report.maximum_active_sequences) <= 1
			and int(report.maximum_falling_products) <= 1,
			"Seed %d never overlaps background sequences or falling products" % seed
		)
		_check(
			int(report.replacements) == drop_count
			and int(report.external_spawns) == drop_count
			and int(report.instrumented_suppressions) == drop_count,
			"Seed %d suppresses exactly one ordinary product per background drop" % seed
		)
		_check(
			int(report.total_product_hazards) <= baseline_product_count
			and int(report.total_product_hazards) >= baseline_product_count - 2,
			"Seed %d never increases total product pressure above baseline" % seed
		)
		var unique_lanes := {}
		var repeated_previous_lane := false
		for lane_index in range(lanes.size()):
			var lane := lanes[lane_index]
			unique_lanes[lane] = true
			if lane_index > 0 and lane == lanes[lane_index - 1]:
				repeated_previous_lane = true
		_check(
			unique_lanes.size() >= 2,
			"Seed %d uses multiple visible background lanes" % seed
		)
		_check(
			not repeated_previous_lane,
			"Seed %d avoids consecutive same-lane background drops" % seed
		)
		_check(
			int(report.releases) == int(report.landings)
			and int(report.landings) == int(report.resets)
			and int(report.warnings) == int(report.releases),
			"Seed %d completes every released background lifecycle" % seed
		)
		print("VM050_MOTION02_SCHEDULER_REPORT %s" % JSON.stringify(report))
	print("VM050_MOTION02_BASELINE_PRODUCTS=%d" % baseline_product_count)


func _run_frozen_baseline_product_count() -> int:
	var conveyor := (load(CONVEYOR_SCENE_PATH) as PackedScene).instantiate() as ConveyorPrototype
	root.add_child(conveyor)
	await physics_frame
	conveyor.left_failure_enabled = false
	conveyor.player.position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 12.0
	while not conveyor.gameplay_is_stopped():
		await physics_frame
	Engine.time_scale = previous_time_scale
	var count := _events_named(conveyor.encounter_log(), "can_spawn").size()
	conveyor.queue_free()
	await process_frame
	return count


func _run_stress_seed(seed: int) -> Dictionary:
	var d3 := await _make_shell(D3_SCENE_PATH)
	var conveyor := d3.conveyor
	var director := d3.background_drop_director
	director.configure_schedule_seed(seed)
	conveyor.left_failure_enabled = false
	conveyor.player.position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	d3.instrumentation.print_events = false
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 12.0
	var maximum_active_sequences := 0
	var maximum_falling_products := 0
	while not conveyor.gameplay_is_stopped():
		await physics_frame
		maximum_active_sequences = maxi(
			maximum_active_sequences,
			director.active_sequence_count()
		)
		maximum_falling_products = maxi(
			maximum_falling_products,
			conveyor.falling_product_count()
		)
	Engine.time_scale = previous_time_scale
	await process_frame
	await process_frame
	var director_log := director.event_log()
	var encounter_log := conveyor.encounter_log()
	var normal_spawns := _events_named(encounter_log, "can_spawn").size()
	var external_spawns := _events_named(encounter_log, "external_can_spawn").size()
	var report := {
		"seed": seed,
		"background_drops": director.released_event_count(),
		"warning_times": director.successful_warning_times(),
		"lanes": director.selected_lane_indices(),
		"rejected_attempts": _events_named(director_log, "rejection").size(),
		"rejection_reasons": director.rejection_counts_by_reason(),
		"candidate_rejection_reasons": director.candidate_rejection_counts_by_reason(),
		"longest_gap": director.longest_successful_warning_gap(),
		"replacements": _events_named(encounter_log, "ordinary_can_replaced").size(),
		"external_spawns": external_spawns,
		"instrumented_suppressions": d3.instrumentation.count_event(
			"d3_ordinary_product_suppressed"
		),
		"normal_product_spawns": normal_spawns,
		"total_product_hazards": normal_spawns + external_spawns,
		"releases": _events_named(director_log, "release").size(),
		"warnings": _events_named(director_log, "warning").size(),
		"landings": _events_named(director_log, "landing").size(),
		"resets": _events_named(director_log, "reset").size(),
		"maximum_active_sequences": maximum_active_sequences,
		"maximum_falling_products": maximum_falling_products,
	}
	d3.queue_free()
	await process_frame
	return report


func _test_background_collision_instrumentation() -> void:
	var d3 := await _make_shell(D3_SCENE_PATH)
	var director := d3.background_drop_director
	d3.instrumentation.print_events = false
	d3.conveyor.left_failure_enabled = false
	d3.conveyor.player.position = Vector2(640.0, 420.0)
	director.reservation_pending = true
	director._active_schedule_index = 0
	var replacement_id := director._try_start_reserved_sequence()
	_check(not replacement_id.is_empty(), "Collision test begins with a valid D3 warning")
	director.set_process(false)
	director._process(director.warning_duration + 0.01)
	var products := d3.conveyor.active_falling_products()
	_check(products.size() == 1, "Collision test releases one background product")
	if products.size() == 1:
		products[0].player_hit.emit(products[0])
	await process_frame
	await process_frame
	var run_ends := _events_named(d3.instrumentation.entries(), "run_end")
	_check(
		director.background_player_collision_count() == 1
		and d3.instrumentation.count_event("d3_player_collision") == 1,
		"Background-product collision is recorded exactly once"
	)
	_check(
		run_ends.size() == 1
		and String(run_ends[0].death_cause) == "background_product",
		"The deferred run summary attributes the resulting death to D3"
	)
	d3.queue_free()
	await process_frame


func _test_death_and_completion_clear_schedule_state() -> void:
	for outcome in ["death", "complete"]:
		var d3 := await _make_shell(D3_SCENE_PATH)
		var director := d3.background_drop_director
		d3.instrumentation.print_events = false
		d3.conveyor.left_failure_enabled = false
		d3.conveyor.player.position = Vector2(640.0, 420.0)
		d3.conveyor.player.collision_layer = 0
		director.reservation_pending = true
		director._active_schedule_index = 0
		var replacement_id := director._try_start_reserved_sequence()
		_check(not replacement_id.is_empty(), "%s stop test begins with an active warning" % outcome)
		d3.conveyor.set_external_product_event_pending(true)
		if outcome == "death":
			d3.conveyor._kill_player()
		else:
			d3.conveyor.stop_for_round_completion()
		await process_frame
		await process_frame
		_check(
			director.visual_state_name() == "stopped"
			and not director.reservation_pending
			and director.selected_lane_index == -1
			and is_nan(director.selected_lane_x)
			and is_inf(director.next_reservation_time)
			and not d3.conveyor.external_product_event_is_pending()
			and d3.conveyor.reserved_ordinary_product_suppression_count() == 0,
			"%s clears every pending D3 schedule and warning field" % outcome
		)
		var summaries := _events_named(director.event_log(), "summary")
		_check(
			summaries.size() == 1 and String(summaries[0].outcome) == outcome,
			"%s records one terminal local schedule summary" % outcome
		)
		d3.queue_free()
		await process_frame


func _test_fresh_scene_resets_local_state() -> void:
	var previous_d3 := await _make_shell(D3_SCENE_PATH)
	previous_d3.conveyor.left_failure_enabled = false
	previous_d3.conveyor.player.position = Vector2(640.0, 420.0)
	previous_d3.conveyor.player.collision_layer = 0
	previous_d3.background_drop_director.reservation_pending = true
	previous_d3.background_drop_director._active_schedule_index = 0
	var previous_replacement_id := (
		previous_d3.background_drop_director._try_start_reserved_sequence()
	)
	_check(
		not previous_replacement_id.is_empty()
		and previous_d3.conveyor.reserved_ordinary_product_suppression_count() == 1,
		"Restart-style reset test begins with live D3 warning and suppression state"
	)
	previous_d3.queue_free()
	await process_frame
	var d3 := await _make_shell(D3_SCENE_PATH)
	_check(
		d3.background_drop_director.visual_state_name() == "stored"
		and not d3.background_drop_director.reservation_pending
		and d3.background_drop_director.released_event_count() == 0,
		"A fresh D3 scene resets selection, reservation, and release state"
	)
	_check(
		d3.conveyor.falling_product_count() == 0
		and d3.conveyor.landed_product_count() == 0
		and d3.conveyor.reserved_ordinary_product_suppression_count() == 0
		and d3.instrumentation.count_event("run_start") == 1,
		"Fresh restart scene clears products, suppression debt, and local state"
	)
	d3.queue_free()
	await process_frame


func _make_shell(scene_path: String) -> MotionExperimentShell:
	var shell := (load(scene_path) as PackedScene).instantiate() as MotionExperimentShell
	root.add_child(shell)
	await physics_frame
	return shell


func _gameplay_snapshot(conveyor: ConveyorPrototype) -> Dictionary:
	var round_controller := conveyor.get_node("RoundController") as FixedRoundController
	var coin_director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	return {
		"player_maximum_speed": conveyor.player.maximum_speed,
		"player_gravity": conveyor.player.gravity,
		"player_jump_velocity": conveyor.player.jump_velocity,
		"player_coyote_time": conveyor.player.coyote_time,
		"player_jump_buffering": conveyor.player.jump_buffering,
		"conveyor_speed_start": conveyor.conveyor_speed_at(0.0),
		"conveyor_speed_end": conveyor.conveyor_speed_at(60.0),
		"conveyor_end_multiplier": conveyor.conveyor_speed_end_multiplier,
		"sweeper_speed": conveyor.sweeper_speed,
		"sweeper_end_multiplier": conveyor.sweeper_speed_end_multiplier,
		"hazard_speed_multiplier": conveyor.maximum_hazard_speed_multiplier,
		"telegraph_duration": conveyor.telegraph_duration,
		"target_fall_duration": conveyor.target_fall_duration,
		"product_size": conveyor.product_size,
		"landed_product_size": conveyor.landed_product_size,
		"control_band": Vector2(conveyor.control_band_left, conveyor.control_band_right),
		"round_duration": round_controller.round_duration,
		"coin_value_behavior": 1,
		"coin_first_spawn": coin_director.first_spawn_time,
		"coin_weights_phase_four": coin_director.phase_four_template_weights,
	}


func _events_named(entries: Array, event_name: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry in entries:
		if String(entry.get("event", "")) == event_name:
			matches.append(entry)
	return matches
