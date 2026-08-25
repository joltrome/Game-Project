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
	await _test_natural_d3_replacement_lifecycle()
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
		(d3.conveyor.get_node("HUD/BuildId") as Label).text == "BUILD VM-0.5.0-MOTION-01-D3",
		"D3 exposes its neutral internal build ID"
	)
	_check(
		d2.background_drop_director == null
		and not d2.conveyor.product_event_replacement_handler_is_set(),
		"D2 contains no background-drop scheduler or replacement hook"
	)
	_check(
		d3.background_drop_director != null
		and d3.conveyor.product_event_replacement_handler_is_set(),
		"Only D3 installs the background-drop replacement hook"
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
	_check(
		director.configured_event_times() == PackedFloat32Array([16.0, 28.0, 40.0, 52.0]),
		"D3 configures four reservations across the 60-second round"
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
	d3.queue_free()
	await process_frame


func _test_natural_d3_replacement_lifecycle() -> void:
	var d3 := await _make_shell(D3_SCENE_PATH)
	var conveyor := d3.conveyor
	var director := d3.background_drop_director
	conveyor.left_failure_enabled = false
	conveyor.player.position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	d3.instrumentation.print_events = false
	var released_state_records: Array[Dictionary] = []
	var landed_state_records: Array[Dictionary] = []
	director.product_released.connect(func(
		_schedule_index: int,
		_lane_index: int,
		product: ConveyorProduct,
		_released_at: float
	) -> void:
		released_state_records.append({
			"falling": product.is_falling(),
			"lethal": product.is_falling_lethal(),
			"solid": product.is_landed_solid(),
		})
	)
	director.product_landed.connect(func(
		_schedule_index: int,
		_lane_index: int,
		product: ConveyorProduct,
		_landed_at: float
	) -> void:
		landed_state_records.append({
			"falling": product.is_falling(),
			"lethal": product.is_falling_lethal(),
			"solid": product.is_landed_solid(),
			"support_velocity": product.intended_platform_velocity(),
		})
	)
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 8.0
	var maximum_falling := 0
	while conveyor.survival_time < 59.5 and not conveyor.gameplay_is_stopped():
		await physics_frame
		maximum_falling = maxi(maximum_falling, conveyor.falling_product_count())
	Engine.time_scale = previous_time_scale
	var log := director.event_log()
	var warnings := _events_named(log, "warning")
	var releases := _events_named(log, "release")
	var landings := _events_named(log, "landing")
	var resets := _events_named(log, "reset")
	var replacements := _events_named(conveyor.encounter_log(), "ordinary_can_replaced")
	var external_spawns := _events_named(conveyor.encounter_log(), "external_can_spawn")
	_check(
		warnings.size() >= 3 and warnings.size() <= 5,
		"Natural D3 run selects three to five background products"
	)
	_check(
		warnings.size() == releases.size()
		and releases.size() == landings.size()
		and landings.size() == resets.size(),
		"Every D3 warning resolves through release, landing, and visual reset"
	)
	_check(
		replacements.size() == releases.size()
		and external_spawns.size() == releases.size(),
		"Each D3 product replaces exactly one ordinary product event"
	)
	_check(maximum_falling <= 1, "D3 preserves the frozen one-falling-product cap")
	var released_states_are_correct := true
	for record in released_state_records:
		released_states_are_correct = (
			released_states_are_correct
			and record.falling
			and record.lethal
			and not record.solid
		)
	_check(
		released_state_records.size() == releases.size()
		and released_states_are_correct,
		"Every released D3 product uses the existing falling-lethal state"
	)
	var landed_states_are_correct := true
	for record in landed_state_records:
		landed_states_are_correct = (
			landed_states_are_correct
			and not record.falling
			and not record.lethal
			and record.solid
			and record.support_velocity.x < 0.0
		)
	_check(
		landed_state_records.size() == landings.size()
		and landed_states_are_correct,
		"Every landed D3 product becomes the existing solid non-lethal moving platform"
	)
	if not warnings.is_empty():
		var first_warning_time := float(warnings[0].time)
		print("VM050_D3_FIRST_WARNING=%.3f" % first_warning_time)
		_check(
			first_warning_time >= 15.0 and first_warning_time <= 20.0,
			"First D3 background warning occurs in the approved 15-20 second window"
		)
	for index in range(mini(warnings.size(), releases.size())):
		var warning_to_release := float(releases[index].time) - float(warnings[index].time)
		_check(
			absf(warning_to_release - director.warning_duration) <= 0.16,
			"D3 warning %d retains the configured generous duration" % index
		)
		var release_to_landing := float(landings[index].time) - float(releases[index].time)
		_check(
			absf(release_to_landing - director.target_fall_duration) <= 0.16,
			"D3 fall %d derives the requested chute-to-belt duration" % index
		)
	_check(
		d3.instrumentation.count_event("d3_warning") == warnings.size()
		and d3.instrumentation.count_event("d3_release") == releases.size()
		and d3.instrumentation.count_event("d3_landing") == landings.size(),
		"Local instrumentation records the D3 schedule and lifecycle"
	)
	print(
		"VM050_D3_NATURAL_METRICS warnings=%d releases=%d landings=%d resets=%d rejections=%d max_falling=%d"
		% [
			warnings.size(),
			releases.size(),
			landings.size(),
			resets.size(),
			_events_named(log, "rejection").size(),
			maximum_falling,
		]
	)
	d3.queue_free()
	await process_frame


func _test_fresh_scene_resets_local_state() -> void:
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
		and d3.instrumentation.count_event("run_start") == 1,
		"Fresh scene starts with no products and one local run-start record"
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
