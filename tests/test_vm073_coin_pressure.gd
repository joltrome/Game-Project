extends SceneTree

const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const STANDARD_SESSION := preload("res://scenes/presentation/standard_session.tscn")
const FIXED_STEP := 1.0 / 120.0
const RUN_SECONDS := 60.0
const TEST_SEED := 7303

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func run() -> void:
	root.size = Vector2i(1152, 648)
	await _test_release_configuration_and_frozen_contract()
	await _test_zone_geometry_and_bounded_fallback()
	await _test_deterministic_fixed_campsite_comparison()
	print("VM073_COIN_PRESSURE_FAILURES=", failures)
	quit(failures)


func _test_release_configuration_and_frozen_contract() -> void:
	var defaults := StandardSession.new()
	var release := STANDARD_SESSION.instantiate() as StandardSession
	check(
		not defaults.coin_pressure_enabled
		and release.coin_pressure_enabled
		and release.refund_system_enabled
		and release.mobile_arcade_deck_enabled,
		"VM-0.7.3 is release-opt-in while previous constructor paths remain unchanged"
	)
	var conveyor := await _make_fixture(TEST_SEED, true)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		director.coin_event_interval_range == Vector2(1.10, 2.10)
		and director.coin_event_size_weights == PackedInt32Array([55, 35, 10])
		and director.maximum_active_independent_coins == 5
		and director.refund_chute_enabled
		and director.refund_chute_nominal_launch_position == Vector2(732.0, 374.0),
		"Cadence, 55/35/10 composition, active cap, and single refund-chute origin are unchanged"
	)
	check(
		director.ballistic_flight_durations == PackedFloat32Array([0.72, 0.90, 1.10])
		and is_equal_approx(director.ballistic_gravity, 1250.0),
		"Shallow, medium, and high trajectory timing/physics remain the accepted authored profiles"
	)
	conveyor.queue_free()
	await process_frame
	defaults.free()
	release.free()


func _test_zone_geometry_and_bounded_fallback() -> void:
	var conveyor := await _make_fixture(TEST_SEED + 1, true)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	for archetype in range(3):
		var target_bounds := director.coin_pressure_target_bounds_for_test(archetype)
		print("VM073_ZONE_BOUNDS ", archetype, " ", target_bounds)
		var previous_end := target_bounds.x
		var zones_are_contiguous := true
		for zone in range(4):
			var zone_bounds := director.coin_pressure_zone_bounds_for_test(archetype, zone)
			zones_are_contiguous = (
				zones_are_contiguous
				and is_equal_approx(zone_bounds.x, previous_end)
				and zone_bounds.y > zone_bounds.x
			)
			previous_end = zone_bounds.y
		zones_are_contiguous = zones_are_contiguous and is_equal_approx(previous_end, target_bounds.y)
		check(
			zones_are_contiguous
			and target_bounds.x >= conveyor.conveyor_support_left_x
			and target_bounds.y <= conveyor.control_band_right,
			"%s uses four contiguous zones derived from its valid conveyor landing envelope"
			% director.ballistic_archetype_name(archetype)
		)
	director._coin_pressure_recent_zones.assign([
		CollectibleDirector.DestinationZone.FAR_LEFT,
		CollectibleDirector.DestinationZone.MID_LEFT,
	])
	var profiles := director._coin_pressure_profile_plan(
		1,
		[CollectibleDirector.BallisticArchetype.SHALLOW],
		99
	)
	check(
		profiles.size() == 1
		and int(profiles[0].preferred_zone)
		!= CollectibleDirector.DestinationZone.MID_LEFT,
		"Two-event memory penalizes an immediate repeat while still allowing a more useful older zone"
	)
	var impossible_profile := profiles[0].duplicate(true)
	impossible_profile.minimum_displacement = 5000.0
	impossible_profile.committed = true
	var sample := director._sample_independent_candidate(
		2.5,
		false,
		"event",
		CollectibleDirector.OfferSide.AHEAD,
		[],
		[],
		CollectibleDirector.BallisticArchetype.SHALLOW,
		[],
		0.15,
		24,
		director.refund_chute_nominal_launch_position,
		impossible_profile
	)
	check(
		not Dictionary(sample.get("candidate", {})).is_empty()
		and bool(Dictionary(sample.get("pressure_profile", {})).get("preference_clamped", false))
		and int(sample.get("attempts", 0)) <= 24,
		"An impossible preferred displacement is clamped to a safe valid destination within the existing bounded budget"
	)
	conveyor.queue_free()
	await process_frame


func _test_deterministic_fixed_campsite_comparison() -> void:
	var control := await _simulate_fixed_campsite(TEST_SEED, false)
	var experiment := await _simulate_fixed_campsite(TEST_SEED, true)
	var pressure_summary: Dictionary = experiment.pressure
	var control_displacements: Array = control.displacements
	var experiment_displacements: Array = experiment.displacements
	var control_median := _median(control_displacements)
	var experiment_median := _median(experiment_displacements)
	var zone_counts: PackedInt32Array = pressure_summary.zone_counts
	var occupied_zones := 0
	for count in zone_counts:
		if count > 0:
			occupied_zones += 1
	check(
		int(experiment.selected_counts[1]) > 0
		and int(experiment.selected_counts[2]) > 0
		and int(experiment.selected_counts[3]) > 0,
		"The pressure run preserves the configured single/double/triple event families"
	)
	check(
		absf(float(experiment.event_count - control.event_count)) <= 1.0
		and absf(float(experiment.delivered - control.delivered))
		/ float(maxi(control.delivered, 1)) <= 0.15,
		"The destination experiment keeps 60-second event cadence and delivered volume approximately stable"
	)
	check(
		int(pressure_summary.spawned) >= 12
		and occupied_zones >= 3
		and experiment_median > control_median + 20.0,
		"Measured destinations at a fixed right campsite span the arena and increase median required displacement"
	)
	check(
		int(pressure_summary.consecutive_zone_repeats)
		<= maxi(ceili(float(pressure_summary.spawned) / 3.0), 2),
		"Two-event destination memory prevents persistent same-zone repetition without forcing strict alternation"
	)
	check(
		int(experiment.maximum_active) <= 5
		and bool(experiment.all_ballistic)
		and bool(experiment.all_refund_chute_launches),
		"Natural pressure runs retain the active cap, ballistic trajectories, and one-source refund-chute launch contract"
	)
	print(
		"VM073_FIXED_CAMPSITE control_median=%.3f experiment_median=%.3f control=%s experiment=%s pressure=%s"
		% [
			control_median,
			experiment_median,
			JSON.stringify(control),
			JSON.stringify(experiment),
			JSON.stringify(pressure_summary),
		]
	)


func _simulate_fixed_campsite(seed: int, pressure_enabled: bool) -> Dictionary:
	var conveyor := await _make_fixture(seed, pressure_enabled)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var maximum_active := 0
	while conveyor.survival_time < RUN_SECONDS - 0.0001:
		conveyor.survival_time += FIXED_STEP
		conveyor._update_continuous_speed_ramps()
		director.invalidate_landed_can_collision_cache_for_test()
		for coin in director.active_collectibles():
			coin._physics_process(FIXED_STEP)
			coin._process(FIXED_STEP)
		director._process(FIXED_STEP)
		maximum_active = maxi(maximum_active, director.active_collectible_count())
	var displacements: Array[float] = []
	var all_ballistic := true
	var all_refund_chute_launches := true
	for event in director.coin_event_log():
		for position in Array(event.get("spawned_positions", [])):
			displacements.append(absf((position as Vector2).x - 640.0))
	for offer in director.offer_log():
		if String(offer.get("spawn_kind", "")) != "event" or not bool(offer.get("accepted", false)):
			continue
		all_ballistic = all_ballistic and bool(offer.get("ballistic", false))
		var launch := offer.get("launch_position", Vector2.ZERO) as Vector2
		all_refund_chute_launches = (
			all_refund_chute_launches
			and launch.x >= director.refund_chute_launch_segment_start.x - 0.01
			and launch.x <= director.refund_chute_launch_segment_end.x + 0.01
		)
	var result := {
		"event_count": director.coin_event_count(),
		"delivered": director.spawn_count,
		"selected_counts": director.coin_event_size_counts(),
		"maximum_active": maximum_active,
		"displacements": displacements,
		"pressure": director.coin_pressure_summary(),
		"all_ballistic": all_ballistic,
		"all_refund_chute_launches": all_refund_chute_launches,
	}
	conveyor.queue_free()
	await process_frame
	return result


func _make_fixture(seed: int, pressure_enabled: bool) -> ConveyorPrototype:
	var conveyor := CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.placement_seed = seed
	director.ballistic_coin_events_enabled = true
	director.ballistic_abundance_enabled = true
	director.ballistic_integrity_enabled = true
	director.refund_chute_enabled = true
	director.refund_system_enabled = true
	director.static_teaching_coin_enabled = true
	director.bounded_optional_planning_enabled = true
	director.coin_pressure_enabled = pressure_enabled
	root.add_child(conveyor)
	await physics_frame
	conveyor.set_physics_process(false)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director.set_process(false)
	conveyor.player.global_position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	return conveyor


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	var middle := ordered.size() / 2
	if ordered.size() % 2 == 0:
		return (float(ordered[middle - 1]) + float(ordered[middle])) * 0.5
	return float(ordered[middle])
