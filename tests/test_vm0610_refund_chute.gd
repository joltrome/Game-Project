extends SceneTree

const MOTION_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const STANDARD_SESSION := preload("res://scenes/presentation/standard_session.tscn")
const REVIEW_SCENE := preload("res://scenes/tests/refund_chute_trajectory_review.tscn")
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
	await _test_release_isolation_and_visual_contract()
	await _test_chute_state_lifecycle()
	await _test_shared_origin_and_trajectory_families()
	await _test_bounded_launch_grace_and_groups()
	await _test_natural_run_preserves_caps_and_d3()
	await _test_cleanup_and_review_scene()
	print("VM0610_REFUND_CHUTE_FAILURES=", failures)
	quit(failures)


func _test_release_isolation_and_visual_contract() -> void:
	var default_session := StandardSession.new()
	var release := STANDARD_SESSION.instantiate() as StandardSession
	check(
		not default_session.refund_chute_enabled
		and release.refund_chute_enabled
		and release.ballistic_integrity_enabled,
		"VM-0.6.10 chute integration is opt-in and the release retains VM-0.6.9 integrity"
	)
	var shell := await _make_fixture(6101)
	var chute := shell.v2_visual_integration.refund_chute_visual()
	check(
		chute != null
		and chute.position == Vector2(692.0, 338.0)
		and chute.runtime_size() == Vector2(84.0, 66.0)
		and chute.get_node("Body").z_index == 2
		and chute.get_node("FrontLip").z_index == 13,
		"Approved 84x66 Concept C location and base/foreground layering are exact"
	)
	check(
		chute.find_children("*", "CollisionObject2D", true, false).is_empty(),
		"Refund Chute is a non-colliding visual mechanism"
	)
	shell.queue_free()
	await process_frame
	default_session.free()
	release.free()


func _test_chute_state_lifecycle() -> void:
	var shell := await _make_fixture(6102)
	var director := shell.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var chute := shell.v2_visual_integration.refund_chute_visual()
	chute.set_process(false)
	director.refund_chute_sequence_cued.emit(0.15, 0.43)
	check(chute.current_state_name() == "PRE_EJECT", "Committed event enters PRE-EJECT")
	chute._process(0.149)
	check(chute.current_state_name() == "PRE_EJECT", "PRE-EJECT remains visible for the configured anticipation")
	chute._process(0.002)
	check(chute.current_state_name() == "OPEN", "Chute opens at the first launch boundary")
	chute._process(0.42)
	check(chute.current_state_name() == "OPEN", "Chute remains open through the final sibling plus hold")
	chute._process(0.02)
	check(chute.current_state_name() == "IDLE", "Chute returns directly to IDLE after the final hold")
	check(
		chute.process_mode == Node.PROCESS_MODE_INHERIT,
		"Chute timing inherits the game's pause state instead of advancing while paused"
	)
	director.refund_chute_sequence_cued.emit(0.15, 0.29)
	director.stop_for_round_end()
	check(chute.current_state_name() == "IDLE", "Round end cancels and resets an active chute cue")
	shell.queue_free()
	await process_frame


func _test_shared_origin_and_trajectory_families() -> void:
	var shell := await _make_fixture(6103)
	var director := shell.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var landing := Vector2(430.0, director._ballistic_contact_y())
	var apexes := PackedFloat32Array()
	for archetype in [
		CollectibleDirector.BallisticArchetype.SHALLOW,
		CollectibleDirector.BallisticArchetype.MEDIUM,
		CollectibleDirector.BallisticArchetype.HIGH,
	]:
		var plan := director._build_ballistic_plan(
			landing,
			archetype,
			2.5,
			0.15,
			false,
			director.refund_chute_nominal_launch_position
		)
		var duration := float(plan.flight_duration)
		var apex_time := clampf(
			-float((plan.launch_velocity as Vector2).y) / director.ballistic_gravity,
			0.0,
			duration
		)
		apexes.append(director._ballistic_plan_position_at(plan, 0.15 + apex_time).y)
		var endpoint := director._ballistic_plan_position_at(plan, 0.15 + duration)
		check(
			(plan.launch_position as Vector2) == Vector2(732.0, 374.0)
			and endpoint.distance_to(landing) < 0.05,
			"%s uses the common mouth and reaches its validated landing target" % director.ballistic_archetype_name(archetype)
		)
	check(
		apexes[0] > apexes[1] and apexes[1] > apexes[2],
		"SHALLOW, MEDIUM, and HIGH remain visibly distinct flight-height families"
	)
	for member_index in range(12):
		var origin := director._refund_chute_origin_for_member(
			1,
			member_index,
			PackedFloat32Array([0.15])
		)
		check(_origin_is_in_approved_mouth(director, origin), "Single-origin variation stays inside the approved mouth locus")
	shell.queue_free()
	await process_frame


func _test_bounded_launch_grace_and_groups() -> void:
	var shell := await _make_fixture(6104)
	var director := shell.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var pair_delays := PackedFloat32Array([0.15, 0.15])
	var pair := director._plan_ballistic_event_group(
		2,
		[CollectibleDirector.OfferSide.BEHIND, CollectibleDirector.OfferSide.AHEAD],
		[CollectibleDirector.BallisticArchetype.SHALLOW, CollectibleDirector.BallisticArchetype.HIGH],
		pair_delays,
		PackedFloat32Array([2.4, 2.6])
	)
	var pair_samples: Array[Dictionary] = []
	pair_samples.assign(pair.get("samples", []))
	check(pair_samples.size() == 2, "Real bounded planner preserves a selected simultaneous double")
	if pair_samples.size() == 2:
		var first_plan: Dictionary = pair_samples[0].ballistic_plan
		var second_plan: Dictionary = pair_samples[1].ballistic_plan
		check(
			(first_plan.launch_position as Vector2).distance_to(second_plan.launch_position) > 34.0
			and director._ballistic_trajectory_separation_is_valid(first_plan, [second_plan]),
			"Approved diagonal double uses only bounded mouth grace and passes the complete trajectory check"
		)
		var normal_check_time := 0.15 + director.refund_chute_launch_grace_duration + 1.0 / 60.0
		check(
			director._ballistic_plan_position_at(first_plan, normal_check_time).distance_to(
				director._ballistic_plan_position_at(second_plan, normal_check_time)
			) >= director.ballistic_minimum_trajectory_separation,
			"The simultaneous pair reaches normal 44px clearance immediately after mouth grace"
		)
	var triple := director._plan_ballistic_event_group(
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
		PackedFloat32Array([0.15, 0.29, 0.43]),
		PackedFloat32Array([2.3, 2.5, 2.7])
	)
	check(Array(triple.get("samples", [])).size() == 3, "Real bounded planner preserves the reference staggered triple")
	check(
		is_equal_approx(director.ballistic_minimum_trajectory_separation, 44.0)
		and is_equal_approx(director.refund_chute_launch_grace_duration, 0.10)
		and is_equal_approx(director.refund_chute_launch_grace_distance, 50.0),
		"Global 44px separation is unchanged; grace is locally bounded to 100ms and 50px"
	)
	shell.queue_free()
	await process_frame


func _test_cleanup_and_review_scene() -> void:
	var review := REVIEW_SCENE.instantiate() as RefundChuteReview
	root.add_child(review)
	await process_frame
	check(
		review.director != null
		and review.director.active_collectible_count() == 1
		and review.director.score == 0,
		"Developer review scene launches its default SHALLOW case"
	)
	review._launch_case(5)
	check(
		review.director.active_collectible_count() == 3
		and review.director.score == 0,
		"Developer review scene reliably triggers the staggered triple without changing score"
	)
	review.queue_free()
	await process_frame


func _test_natural_run_preserves_caps_and_d3() -> void:
	var shell := await _make_fixture(401)
	var conveyor := shell.conveyor
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var d3 := shell.background_drop_director
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
	var all_origins_valid := true
	for event in director.coin_event_log():
		for origin in event.get("launch_positions", []):
			all_origins_valid = all_origins_valid and _origin_is_in_approved_mouth(
				director,
				origin
			)
	# The per-event log stores accepted launch positions in each coin attempt;
	# inspect the authoritative offer log to include teaching and degraded groups.
	for offer in director.offer_log():
		if not bool(offer.get("ballistic", false)):
			continue
		all_origins_valid = all_origins_valid and _origin_is_in_approved_mouth(
			director,
			offer.get("launch_position", Vector2.ZERO)
		)
	check(
		director.spawn_count >= 35
		and director.spawn_count <= 45
		and maximum_active <= director.maximum_active_independent_coins
		and all_origins_valid,
		"Natural 60-second run keeps VM-0.6.9 opportunity/cap bounds and sources every ballistic coin from the chute"
	)
	check(
		d3.released_event_count() == 6
		and d3.longest_successful_warning_gap() <= 8.80
		and int(d3.candidate_rejection_counts_by_reason().get("collectible_path_overlap", 0)) == 0,
		"Natural chute run preserves all six frozen D3 events without coin-caused delay"
	)
	print(
		"VM0610_NATURAL seed=401 delivered=%d max_active=%d integrity=%s d3_times=%s"
		% [
			director.spawn_count,
			maximum_active,
			director.ballistic_integrity_summary(),
			d3.successful_warning_times(),
		]
	)
	shell.queue_free()
	await process_frame


func _make_fixture(seed: int) -> MotionExperimentShell:
	var shell := MOTION_SCENE.instantiate() as MotionExperimentShell
	shell.refund_chute_enabled = true
	shell.local_instrumentation_enabled = false
	root.add_child(shell)
	await process_frame
	var conveyor := shell.conveyor
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.ballistic_coin_events_enabled = true
	director.ballistic_abundance_enabled = true
	director.ballistic_integrity_enabled = true
	director.refund_chute_enabled = true
	director.placement_seed = seed
	director._placement_rng_state = seed
	director._stream_rng_state = maxi(posmod(seed * 1664525 + 1013904223, 0x7fffffff), 1)
	return shell


func _origin_is_in_approved_mouth(
	director: CollectibleDirector,
	origin: Vector2
) -> bool:
	var expected := director._refund_chute_point_on_segment(origin.x)
	return (
		origin.x >= director.refund_chute_launch_segment_start.x - 0.001
		and origin.x <= director.refund_chute_launch_segment_end.x + 0.001
		and origin.distance_to(expected) <= 1.01
	)
