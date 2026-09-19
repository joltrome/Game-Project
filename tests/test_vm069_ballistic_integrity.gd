extends SceneTree

const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const STANDARD_SESSION := preload("res://scenes/presentation/standard_session.tscn")
const MOTION_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const TEST_SEEDS := [401, 1701, 4202]
const FIXED_STEP := 1.0 / 120.0

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
	await _test_isolated_runtime_configuration()
	await _test_bounded_group_planning_and_fallback()
	await _test_per_physics_frame_landed_can_cache()
	await _test_integrity_telemetry_and_idempotent_stop()
	await _test_natural_integrity_and_d3_priority()
	print("VM069_BALLISTIC_INTEGRITY_FAILURES=", failures)
	quit(failures)


func _test_isolated_runtime_configuration() -> void:
	var constructor_default := StandardSession.new()
	var release := STANDARD_SESSION.instantiate() as StandardSession
	check(
		not constructor_default.ballistic_integrity_enabled
		and release.ballistic_coins_enabled
		and release.ballistic_abundance_enabled
		and release.ballistic_integrity_enabled,
		"VM-0.6.9 is opt-in while constructor defaults preserve older release paths"
	)
	var conveyor := await _make_fixture(6901)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		director.coin_event_interval_range == Vector2(1.10, 2.10)
		and director.coin_event_size_weights == PackedInt32Array([55, 35, 10])
		and director.maximum_active_independent_coins == 5
		and director.ballistic_post_contact_lifetime_range == Vector2(2.0, 3.0),
		"Integrity planning leaves cadence, 55/35/10 event weights, active cap, and lifetime unchanged"
	)
	conveyor.queue_free()
	await process_frame
	constructor_default.free()
	release.free()


func _test_bounded_group_planning_and_fallback() -> void:
	var conveyor := await _make_fixture(6902)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var double_plan := director._plan_ballistic_event_group(
		2,
		[CollectibleDirector.OfferSide.BEHIND, CollectibleDirector.OfferSide.AHEAD],
		[CollectibleDirector.BallisticArchetype.SHALLOW, CollectibleDirector.BallisticArchetype.HIGH],
		PackedFloat32Array([0.0, 0.0]),
		PackedFloat32Array([2.4, 2.6])
	)
	var double_samples: Array[Dictionary] = []
	double_samples.assign(double_plan.get("samples", []))
	check(
		double_samples.size() == 2
		and director._ballistic_group_combination_rejection_reason(double_samples).is_empty(),
		"A selected simultaneous double is planned and validated as one complete group"
	)
	var triple_plan := director._plan_ballistic_event_group(
		3,
		[
			CollectibleDirector.OfferSide.BEHIND,
			CollectibleDirector.OfferSide.CENTRED,
			CollectibleDirector.OfferSide.AHEAD,
		],
		[
			CollectibleDirector.BallisticArchetype.SHALLOW,
			CollectibleDirector.BallisticArchetype.MEDIUM,
			CollectibleDirector.BallisticArchetype.HIGH,
		],
		PackedFloat32Array([0.0, 0.18, 0.38]),
		PackedFloat32Array([2.3, 2.5, 2.7])
	)
	var triple_samples: Array[Dictionary] = []
	triple_samples.assign(triple_plan.get("samples", []))
	check(
		triple_samples.size() == 3
		and director._ballistic_group_combination_rejection_reason(triple_samples).is_empty(),
		"A selected staggered triple can survive as a valid shallow/medium/high group"
	)
	director.ballistic_minimum_trajectory_separation = 5000.0
	var impossible_double := director._plan_ballistic_event_group(
		2,
		[CollectibleDirector.OfferSide.BEHIND, CollectibleDirector.OfferSide.AHEAD],
		[CollectibleDirector.BallisticArchetype.SHALLOW, CollectibleDirector.BallisticArchetype.HIGH],
		PackedFloat32Array([0.0, 0.0]),
		PackedFloat32Array([2.4, 2.6])
	)
	check(
		Array(impossible_double.get("samples", [])).size() <= 1
		and int(impossible_double.get("group_attempts", 0))
		<= director.ballistic_group_combination_checks + 2,
		"Invalid full groups degrade through bounded search instead of forcing overlap or looping indefinitely"
	)
	conveyor.queue_free()
	await process_frame


func _test_per_physics_frame_landed_can_cache() -> void:
	var conveyor := await _make_fixture(6903)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.performance_profiling_enabled = true
	director.invalidate_landed_can_collision_cache_for_test()
	director._landed_can_collision_rects()
	director._landed_can_collision_rects()
	var profile := director.performance_profile_summary()
	check(
		int(profile.landed_can_queries) == 2
		and int(profile.landed_can_cache_rebuilds) == 1,
		"Repeated landed-can queries in one physics frame reuse one current geometry snapshot"
	)
	director.invalidate_landed_can_collision_cache_for_test()
	director._landed_can_collision_rects()
	profile = director.performance_profile_summary()
	check(
		int(profile.landed_can_cache_rebuilds) == 2,
		"Explicit next-step invalidation rebuilds the cache so stale can geometry is not retained"
	)
	conveyor.queue_free()
	await process_frame


func _test_integrity_telemetry_and_idempotent_stop() -> void:
	var conveyor := await _make_fixture(6904)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director._coin_event_size_counts[1] = 2
	director._coin_event_size_counts[2] = 2
	director._coin_event_size_counts[3] = 1
	director._ballistic_full_double_count = 1
	director._ballistic_degraded_double_count = 1
	director._ballistic_full_triple_count = 1
	director._ballistic_collection_counts.AIRBORNE = 2
	director._ballistic_collection_counts.BOUNCING = 1
	director._ballistic_collection_counts.SETTLED = 1
	director._ballistic_expired_count = 2
	director._ballistic_exited_left_count = 1
	var summary := director.ballistic_run_summary()
	check(
		int(summary.selected_singles) == 2
		and int(summary.selected_doubles) == 2
		and int(summary.full_doubles) == 1
		and is_equal_approx(float(summary.double_integrity_rate), 0.5)
		and int(summary.selected_triples) == 1
		and int(summary.full_triples) == 1
		and int(summary.airborne) == 2
		and int(summary.bouncing) == 1
		and int(summary.settled) == 1
		and int(summary.expired) == 2
		and int(summary.exited_left) == 1,
		"One run summary contains collection phase, resolution, and multi-event integrity evidence"
	)
	director.stop_for_round_end()
	director.stop_for_round_end()
	check(director._stopped, "Round-end summary/cleanup guard remains idempotent")
	conveyor.queue_free()
	await process_frame


func _test_natural_integrity_and_d3_priority() -> void:
	var selected_doubles := 0
	var full_doubles := 0
	var selected_triples := 0
	var full_triples := 0
	for seed in TEST_SEEDS:
		var shell := MOTION_SCENE.instantiate() as MotionExperimentShell
		root.add_child(shell)
		await process_frame
		var conveyor := shell.conveyor
		var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		var d3 := shell.background_drop_director
		director.ballistic_coin_events_enabled = true
		director.ballistic_abundance_enabled = true
		director.ballistic_integrity_enabled = true
		director.placement_seed = seed
		director._placement_rng_state = seed
		director._stream_rng_state = maxi(
			posmod(seed * 1664525 + 1013904223, 0x7fffffff),
			1
		)
		conveyor.initial_warning_delay = 999.0
		conveyor.left_failure_enabled = false
		conveyor.set_physics_process(false)
		(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
		director.set_process(false)
		d3.set_process(false)
		conveyor.player.global_position = Vector2(640.0, 420.0)
		conveyor.player.collision_layer = 0
		conveyor.player.set_physics_process(false)
		var maximum_active := 0
		while conveyor.survival_time < 59.95:
			conveyor.survival_time += FIXED_STEP
			conveyor._update_continuous_speed_ramps()
			director.invalidate_landed_can_collision_cache_for_test()
			for coin in director.active_collectibles():
				coin._physics_process(FIXED_STEP)
				coin._process(FIXED_STEP)
			director._process(FIXED_STEP)
			d3._process(FIXED_STEP)
			for product in conveyor.active_falling_products():
				product._physics_process(FIXED_STEP)
			for product in conveyor.active_landed_products():
				product._physics_process(FIXED_STEP)
			maximum_active = maxi(maximum_active, director.active_collectible_count())
		var integrity := director.ballistic_integrity_summary()
		selected_doubles += int(integrity.selected_doubles)
		full_doubles += int(integrity.full_doubles)
		selected_triples += int(integrity.selected_triples)
		full_triples += int(integrity.full_triples)
		var all_event_flags_consistent := true
		for event in director.coin_event_log():
			if bool(event.full_group_success):
				all_event_flags_consistent = (
					all_event_flags_consistent
					and int(event.spawned_count) == int(event.requested_count)
				)
			if bool(event.degraded_fallback):
				all_event_flags_consistent = (
					all_event_flags_consistent
					and int(event.spawned_count) < int(event.requested_count)
					and not String(event.degradation_reason).is_empty()
				)
		check(
			director.spawn_count >= 35
			and director.spawn_count <= 45
			and maximum_active <= director.maximum_active_independent_coins
			and all_event_flags_consistent,
			"Seed %d keeps delivered opportunity near target, respects the active cap, and records every degradation" % seed
		)
		check(
			d3.released_event_count() == 6
			and d3.longest_successful_warning_gap() <= 8.80
			and int(d3.candidate_rejection_counts_by_reason().get("collectible_path_overlap", 0)) == 0,
			"Seed %d preserves all six frozen D3 events without coin-caused delay" % seed
		)
		print(
			"VM069_INTEGRITY seed=%d delivered=%d selected_2=%d full_2=%d selected_3=%d full_3=%d degradation=%s d3_times=%s"
			% [
				seed,
				director.spawn_count,
				int(integrity.selected_doubles),
				int(integrity.full_doubles),
				int(integrity.selected_triples),
				int(integrity.full_triples),
				integrity.degradation_reasons,
				d3.successful_warning_times(),
			]
		)
		shell.queue_free()
		await process_frame
	var double_rate := float(full_doubles) / float(maxi(selected_doubles, 1))
	var triple_rate := float(full_triples) / float(maxi(selected_triples, 1))
	check(
		double_rate >= 0.45
		and full_triples >= 1
		and triple_rate >= 0.10,
		"Three deterministic runs show materially stronger double integrity and at least one complete triple"
	)
	print(
		"VM069_INTEGRITY_AGGREGATE selected_2=%d full_2=%d rate_2=%.3f selected_3=%d full_3=%d rate_3=%.3f"
		% [selected_doubles, full_doubles, double_rate, selected_triples, full_triples, triple_rate]
	)


func _make_fixture(seed: int) -> ConveyorPrototype:
	var conveyor := CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.placement_seed = seed
	director.ballistic_coin_events_enabled = true
	director.ballistic_abundance_enabled = true
	director.ballistic_integrity_enabled = true
	root.add_child(conveyor)
	await physics_frame
	conveyor.set_physics_process(false)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director.set_process(false)
	conveyor.player.global_position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	return conveyor
