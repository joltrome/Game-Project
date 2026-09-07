extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const STANDARD_SCENE_PATH := "res://scenes/experiments/motion_vis04_pa_ca.tscn"
const BASELINE_TOTALS := {401: 54, 1701: 55, 4202: 55}

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
	await _test_selected_standard_baseline_and_topology()
	await _test_whole_offer_player_safe_relocation()
	await _test_buffer_rejection_retry_and_collection()
	await _test_delayed_spawn_retry_is_bounded()
	await _test_natural_economy_and_instrumentation()
	print("VM060_STANDARD_COIN_MICRO_PASS_FAILURES=%d" % _failures)
	quit(_failures)


func _test_selected_standard_baseline_and_topology() -> void:
	var shell := (load(STANDARD_SCENE_PATH) as PackedScene).instantiate() as MotionExperimentShell
	root.add_child(shell)
	await physics_frame
	var conveyor := shell.conveyor
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var risk_tail := director.template_candidates_for_test(
		CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK,
		4
	)
	var validation := director.route_action_validation_for_test(
		CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK,
		4
	)
	var results: Dictionary = validation.results
	_check(
		shell.vis04_runtime_art_enabled
		and is_equal_approx(conveyor.sweeper_altitude, 518.0)
		and director.collectible_size == Vector2(24.0, 24.0)
		and conveyor.effective_product_falling_collision_size() == Vector2(60.0, 60.0)
		and conveyor.landed_product_size == Vector2(72.0, 48.0),
		"Selected Standard baseline remains VIS-04 P-A/C-A with frozen product geometry"
	)
	_check(
		director.route_archetype_name(CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK)
			== "RISK_TAIL"
		and risk_tail.size() == 4
		and risk_tail[0].band == CollectibleDirector.PlacementBand.GROUND
		and risk_tail[1].band == CollectibleDirector.PlacementBand.GROUND
		and risk_tail[2].band == CollectibleDirector.PlacementBand.LOW_AIR
		and risk_tail[3].band == CollectibleDirector.PlacementBand.LOW_AIR
		and float(risk_tail[0].position.x) > float(risk_tail[1].position.x)
		and float(risk_tail[1].position.x) > float(risk_tail[2].position.x)
		and float(risk_tail[3].position.x) > float(risk_tail[1].position.x)
		and is_equal_approx(float(risk_tail[0].position.y), float(risk_tail[1].position.y))
		and float(risk_tail[2].position.y) < float(risk_tail[1].position.y)
		and float(risk_tail[3].position.y) < float(risk_tail[2].position.y),
		"Safe-versus-risk route now adds a jump and modest reverse-direction tail"
	)
	_check(
		bool(validation.valid)
		and int(results[CollectibleDirector.RouteTrajectory.NO_FURTHER_INPUT].collected_count) < 4
		and int(results[CollectibleDirector.RouteTrajectory.SAME_INPUT_CONTINUATION].collected_count) < 4
		and int(results[CollectibleDirector.RouteTrajectory.PASSIVE_JUMP].collected_count) < 4
		and int(results[CollectibleDirector.RouteTrajectory.INTENDED_AGGRESSIVE].collected_count) == 4
		and int(results[CollectibleDirector.RouteTrajectory.SAFE_ABANDONMENT].collected_count) == 1,
		"Risk tail needs another movement choice, remains collectible, and permits abandonment"
	)
	var compact := director.route_action_validation_for_test(
		CollectibleDirector.OfferTemplate.COMPACT_BURST,
		3
	)
	_check(
		director.route_archetype_name(CollectibleDirector.OfferTemplate.COMPACT_BURST)
			== "CLUSTER"
		and int(compact.results[CollectibleDirector.RouteTrajectory.NO_FURTHER_INPUT].collected_count) == 3,
		"Compact jackpot remains an intentionally simple reward cluster"
	)
	shell.queue_free()
	await process_frame


func _test_whole_offer_player_safe_relocation() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	var template := CollectibleDirector.OfferTemplate.HORIZONTAL_LINE
	var original := director.template_candidates_for_test(template, 3)
	conveyor.player.global_position = original[0].position
	var score_before := director.score
	var relocated := director.try_spawn_template_for_test(template, 3)
	_check(
		relocated,
		"A player-blocked authored route selects a safe whole-offer placement"
	)
	var spawned := director.active_collectibles()
	var accepted_entry := _latest_accepted_attempt(director)
	var geometry_preserved := spawned.size() == original.size()
	if geometry_preserved:
		for index in range(1, original.size()):
			geometry_preserved = geometry_preserved and (
				spawned[index].global_position - spawned[0].global_position
				== original[index].position - original[0].position
			)
	var all_player_safe := true
	for coin in spawned:
		all_player_safe = (
			all_player_safe
			and director.player_spawn_rejection_reason_for_test(coin.global_position).is_empty()
		)
	_check(
		geometry_preserved
		and all_player_safe
		and bool(accepted_entry.alternate_placement_selected)
		and absf(float(accepted_entry.placement_shift_x)) > 0.0
		and int(accepted_entry.player_safety_rejections) >= 1,
		"Relocation shifts every sibling equally and records the player-safety decision"
	)
	await physics_frame
	_check(
		director.score == score_before,
		"A newly spawned safe route cannot increment score on its spawn frame"
	)
	_free_conveyor(conveyor)


func _test_buffer_rejection_retry_and_collection() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	director.candidate_x_positions = PackedFloat32Array([610.0])
	var ground_y := director.band_center_y(CollectibleDirector.PlacementBand.GROUND)
	conveyor.player.global_position = Vector2(645.0, ground_y)
	var buffer_reason := director.player_spawn_rejection_reason_for_test(
		Vector2(610.0, ground_y)
	)
	var accepted_with_alternate := director.try_spawn_template_for_test(
		CollectibleDirector.OfferTemplate.GROUND_SINGLE,
		1
	)
	var alternate_entry := _latest_accepted_attempt(director)
	_check(
		buffer_reason == CollectibleDirector.REJECTION_PLAYER_BUFFER
		and accepted_with_alternate
		and director.active_collectible_count() == 1
		and director.score == 0,
		"Configured 8 px buffer detects adjacency and selects a visible safe alternative"
	)
	_check(
		bool(alternate_entry.alternate_placement_selected)
		and int(alternate_entry.player_safety_rejections) >= 1,
		"Buffer-triggered alternate placement is recorded in developer instrumentation"
	)
	var coin := director.active_collectible()
	_check(director.score == 0, "Alternate placement spawns visibly before collection")
	conveyor.player.global_position = coin.global_position
	coin._on_body_entered(conveyor.player)
	coin._on_body_entered(conveyor.player)
	_check(
		director.score == 1,
		"Subsequent player movement collects normally and still scores exactly once"
	)
	await process_frame
	director.player_spawn_safety_padding = 500.0
	conveyor.player.global_position = Vector2(610.0, ground_y)
	_check(
		not director.try_spawn_template_for_test(
			CollectibleDirector.OfferTemplate.GROUND_SINGLE,
			1
		)
		and director.active_collectible_count() == 0,
		"An offer rejects cleanly when no player-safe whole-route placement exists"
	)
	director.player_spawn_safety_padding = 8.0
	conveyor.player.global_position = Vector2(720.0, ground_y)
	_check(
		director.try_spawn_template_for_test(
			CollectibleDirector.OfferTemplate.GROUND_SINGLE,
			1
		),
		"A rejected offer can retry successfully after spatial conditions change"
	)
	_free_conveyor(conveyor)


func _test_delayed_spawn_retry_is_bounded() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	conveyor.player.global_position = Vector2(720.0, 560.0)
	var candidates := director.template_candidates_for_test(
		CollectibleDirector.OfferTemplate.STAGGERED_ROUTE,
		4
	)
	_check(
		director.try_spawn_template_for_test(
			CollectibleDirector.OfferTemplate.STAGGERED_ROUTE,
			4
		),
		"Staggered safety fixture reserves its authored route"
	)
	conveyor.player.global_position = candidates[1].position
	conveyor.survival_time += director.staggered_coin_interval
	for retry_index in range(director.maximum_delayed_coin_spawn_retries + 1):
		director._process(director.failed_spawn_retry_delay)
		if retry_index < director.maximum_delayed_coin_spawn_retries:
			conveyor.survival_time += director.failed_spawn_retry_delay
	_check(
		director.delayed_player_safety_retry_count()
			== director.maximum_delayed_coin_spawn_retries + 1
		and director.delayed_candidate_skip_count() == 1
		and director.pending_staggered_coin_count() == 2,
		"A blocked delayed sibling retries a bounded number of times, then skips cleanly"
	)
	conveyor.player.global_position = Vector2(720.0, 560.0)
	conveyor.survival_time += director.failed_spawn_retry_delay
	director._process(director.failed_spawn_retry_delay)
	_check(
		director.active_collectible_count() == 2
		and director.pending_staggered_coin_count() == 1,
		"A skipped sibling does not permanently starve later route coins"
	)
	_free_conveyor(conveyor)


func _test_natural_economy_and_instrumentation() -> void:
	var seeds := [401, 1701, 4202]
	var conveyors: Array[ConveyorPrototype] = []
	var directors: Array[CollectibleDirector] = []
	for seed in seeds:
		var conveyor := (load(CONVEYOR_SCENE_PATH) as PackedScene).instantiate() as ConveyorPrototype
		conveyor.left_failure_enabled = false
		var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		director.placement_seed = seed
		root.add_child(conveyor)
		await physics_frame
		conveyor.player.position = Vector2(640.0, 420.0)
		conveyor.player.collision_layer = 0
		conveyor.player.set_physics_process(false)
		conveyors.append(conveyor)
		directors.append(director)
	while conveyors[0].survival_time < 59.95:
		await physics_frame
		for director in directors:
			for coin in director.active_collectibles():
				coin._resolve(true)
	for index in range(directors.size()):
		var director := directors[index]
		var accepted := _accepted_attempts(director)
		var offered := 0
		var archetype_counts := {}
		var multi_archetype_counts := {}
		var multi_coin_sizes := {}
		for entry in accepted:
			offered += int(entry.intended_count)
			var archetype := String(entry.route_archetype)
			archetype_counts[archetype] = int(archetype_counts.get(archetype, 0)) + 1
			if int(entry.intended_count) > 1:
				multi_archetype_counts[archetype] = int(
					multi_archetype_counts.get(archetype, 0)
				) + 1
				var coin_count := int(entry.intended_count)
				multi_coin_sizes[coin_count] = int(multi_coin_sizes.get(coin_count, 0)) + 1
		var seed := int(seeds[index])
		_check(
			abs(offered - int(BASELINE_TOTALS[seed])) <= 3
			and accepted.size() >= 21
			and accepted.size() <= 23
			and float(accepted[0].time) >= 1.5
			and float(accepted[0].time) <= 2.0
			and archetype_counts.has("RISK_TAIL")
			and archetype_counts.has("CLUSTER"),
			"Seed %d preserves economy/cadence and exercises decision plus simple routes" % seed
		)
		print(
			"VM060_COIN_ECONOMY seed=%d offered=%d offers=%d first=%.3f archetypes=%s multi_archetypes=%s multi_sizes=%s player_overlap=%d player_buffer=%d alternates=%d delayed_retries=%d delayed_skips=%d"
			% [
				seed,
				offered,
				accepted.size(),
				float(accepted[0].time),
				archetype_counts,
				multi_archetype_counts,
				multi_coin_sizes,
				int(director.rejection_counts().get(CollectibleDirector.REJECTION_PLAYER_OVERLAP, 0)),
				int(director.rejection_counts().get(CollectibleDirector.REJECTION_PLAYER_BUFFER, 0)),
				director.alternate_placement_count(),
				director.delayed_player_safety_retry_count(),
				director.delayed_candidate_skip_count(),
			]
		)
	for conveyor in conveyors:
		conveyor.queue_free()
	await process_frame

	for seed in seeds:
		var safety_conveyor := (load(CONVEYOR_SCENE_PATH) as PackedScene).instantiate() as ConveyorPrototype
		safety_conveyor.left_failure_enabled = false
		var safety_director := safety_conveyor.get_node("CollectibleDirector") as CollectibleDirector
		safety_director.placement_seed = seed
		root.add_child(safety_conveyor)
		await physics_frame
		safety_conveyor.set_physics_process(false)
		(safety_conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
		safety_director.set_process(false)
		safety_conveyor.player.position = Vector2(
			610.0,
			safety_director.band_center_y(CollectibleDirector.PlacementBand.GROUND)
		)
		safety_conveyor.player.collision_layer = 0
		safety_conveyor.player.set_physics_process(false)
		var spawn_safety_violations := 0
		var simulation_step := 1.0 / 120.0
		while safety_conveyor.survival_time < 59.95:
			safety_conveyor.survival_time += simulation_step
			safety_director._process(simulation_step)
			for coin in safety_director.active_collectibles():
				if not safety_director.player_spawn_rejection_reason_for_test(
					coin.global_position
				).is_empty():
					spawn_safety_violations += 1
				coin._resolve(true)
		var safety_accepted := _accepted_attempts(safety_director)
		_check(
			not safety_conveyor.is_dead
			and spawn_safety_violations == 0
			and safety_accepted.size() >= 20
			and safety_director.alternate_placement_count() > 0,
			"Seed %d avoids spawn-frame player intersections without starving offers" % seed
		)
		print(
			"VM060_PLAYER_SAFETY seed=%d offers=%d player_overlap=%d player_buffer=%d alternates=%d delayed_retries=%d delayed_skips=%d spawn_violations=%d rejections=%s"
			% [
				seed,
				safety_accepted.size(),
				int(safety_director.player_safety_encounter_counts().get(CollectibleDirector.REJECTION_PLAYER_OVERLAP, 0)),
				int(safety_director.player_safety_encounter_counts().get(CollectibleDirector.REJECTION_PLAYER_BUFFER, 0)),
				safety_director.alternate_placement_count(),
				safety_director.delayed_player_safety_retry_count(),
				safety_director.delayed_candidate_skip_count(),
				spawn_safety_violations,
				safety_director.rejection_counts(),
			]
		)
		safety_conveyor.queue_free()
		await process_frame


func _accepted_attempts(director: CollectibleDirector) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in director.offer_log():
		if String(entry.get("event", "")) == "attempt" and bool(entry.get("accepted", false)):
			result.append(entry)
	return result


func _latest_accepted_attempt(director: CollectibleDirector) -> Dictionary:
	var accepted := _accepted_attempts(director)
	return accepted[-1] if not accepted.is_empty() else {}


func _make_conveyor() -> ConveyorPrototype:
	var conveyor := (load(CONVEYOR_SCENE_PATH) as PackedScene).instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	root.add_child(conveyor)
	await physics_frame
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	(conveyor.get_node("CollectibleDirector") as CollectibleDirector).set_process(false)
	return conveyor


func _director(conveyor: ConveyorPrototype) -> CollectibleDirector:
	return conveyor.get_node("CollectibleDirector") as CollectibleDirector


func _free_conveyor(conveyor: ConveyorPrototype) -> void:
	conveyor.queue_free()
	await process_frame
