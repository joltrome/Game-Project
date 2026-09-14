extends SceneTree

const COIN_SCENE := preload("res://scenes/collectibles/conveyor_collectible.tscn")
const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const STANDARD_SESSION := preload("res://scenes/presentation/standard_session.tscn")
const BALLISTIC_SESSION := preload("res://scenes/presentation/standard_session.tscn")
const TEST_SEEDS := [401, 1701, 4202]
const TEST_SAVE := "/tmp/vms-vm067-score.cfg"
const TEST_AUDIO := "/tmp/vms-vm067-audio.cfg"

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
	await _test_control_and_prototype_configuration()
	await _test_deterministic_trajectory_archetypes()
	await _test_airborne_collection_and_audio_once()
	await _test_bounce_lifetime_warning_and_conveyor_motion()
	await _test_multi_coin_differentiation_cap_and_expiry()
	await _test_natural_metrics_and_d3_priority()
	await _test_round_end_and_retry_cleanup()
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_AUDIO)
	print("VM067_BALLISTIC_COIN_FAILURES=", failures)
	quit(failures)


func _test_control_and_prototype_configuration() -> void:
	var control := StandardSession.new()
	var prototype := BALLISTIC_SESSION.instantiate() as StandardSession
	check(
		not control.ballistic_coins_enabled and prototype.ballistic_coins_enabled,
		"VM-0.6.6 control defaults to static-entry coins while the isolated VM-0.6.7 scene enables ballistic entry"
	)
	var conveyor := await _make_fixture(6701)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		director.coin_event_interval_range == Vector2(1.10, 2.10)
		and director.coin_event_size_weights == PackedInt32Array([55, 35, 10])
		and director.maximum_active_independent_coins == 5
		and is_equal_approx(director.first_spawn_time, 1.75)
		and director.ballistic_flight_durations == PackedFloat32Array([0.72, 0.90, 1.10])
		and director.ballistic_post_contact_lifetime_range == Vector2(2.0, 3.0)
		and is_equal_approx(director.independent_expiry_warning_duration, 0.70),
		"Ballistic prototype preserves VM-0.6.6 cadence, weights, cap, teaching time, score value, and warning while exposing its own motion tuning"
	)
	var count_samples := PackedInt32Array([0, 0, 0, 0])
	for _sample in range(10000):
		count_samples[director._select_coin_event_size()] += 1
	check(
		absf(float(count_samples[1]) / 10000.0 - 0.55) < 0.02
		and absf(float(count_samples[2]) / 10000.0 - 0.35) < 0.02
		and absf(float(count_samples[3]) / 10000.0 - 0.10) < 0.02,
		"Deterministic selection continues to reproduce the configured 55/35/10 event weights"
	)
	conveyor.queue_free()
	await process_frame
	control.free()
	prototype.free()


func _test_deterministic_trajectory_archetypes() -> void:
	var first := await _make_fixture(6711)
	var second := await _make_fixture(6711)
	var first_director := first.get_node("CollectibleDirector") as CollectibleDirector
	var second_director := second.get_node("CollectibleDirector") as CollectibleDirector
	var signatures: Array = []
	for archetype in [
		CollectibleDirector.BallisticArchetype.SHALLOW,
		CollectibleDirector.BallisticArchetype.MEDIUM,
		CollectibleDirector.BallisticArchetype.HIGH,
	]:
		var landing := Vector2(640.0 - archetype * 56.0, first_director._ballistic_contact_y())
		var first_plan := first_director._build_ballistic_plan(landing, archetype, 2.5)
		var second_plan := second_director._build_ballistic_plan(landing, archetype, 2.5)
		check(first_plan == second_plan, "%s trajectory is deterministic from identical inputs" % first_director.ballistic_archetype_name(archetype))
		check(
			float(first_plan.flight_duration) >= 0.6
			and float(first_plan.flight_duration) <= 1.2
			and (first_plan.launch_position as Vector2).y < (first_plan.landing_position as Vector2).y,
			"%s uses a visible upper-playfield source and a 0.6–1.2 second first flight" % first_director.ballistic_archetype_name(archetype)
		)
		var midpoint := first_director._ballistic_plan_position_at(
			first_plan,
			float(first_plan.flight_duration) * 0.5
		)
		check(
			midpoint.y < lerpf(
				(first_plan.launch_position as Vector2).y,
				(first_plan.landing_position as Vector2).y,
				0.5
			),
			"%s follows an upward-curving ballistic path rather than a straight or vertical D3 drop" % first_director.ballistic_archetype_name(archetype)
		)
		signatures.append([
			first_plan.launch_position,
			first_plan.launch_velocity,
			first_plan.flight_duration,
		])
	check(
		signatures[0] != signatures[1]
		and signatures[1] != signatures[2]
		and signatures[0] != signatures[2],
		"SHALLOW, MEDIUM, and HIGH use differentiated sources, velocities, and durations"
	)
	first.queue_free()
	second.queue_free()
	await process_frame


func _test_airborne_collection_and_audio_once() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_AUDIO)
	var session := BALLISTIC_SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = TEST_SAVE
	session.audio_settings_path = TEST_AUDIO
	root.add_child(session)
	await process_frame
	session.start_game()
	await process_frame
	var conveyor := session.game.conveyor
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.set_process(false)
	session.game.background_drop_director.set_process(false)
	conveyor.set_physics_process(false)
	var accepted := director._try_spawn_independent_coin(
		"event", 2.5, false,
		CollectibleDirector.OfferSide.AHEAD, [], 67, 1, 0, [],
		CollectibleDirector.BallisticArchetype.MEDIUM, []
	)
	check(accepted, "A deterministic airborne coin can be launched through the real director")
	if accepted:
		var coin := director.active_collectible()
		var score_before := director.score
		var sound_before := session.audio.played_count(&"coin_pickup")
		check(
			coin.motion_state() == ConveyorCollectible.MotionState.AIRBORNE
			and not coin.first_contact_occurred(),
			"Refund Coin is collectible during its AIRBORNE state before conveyor contact"
		)
		coin._on_body_entered(conveyor.player)
		coin._on_body_entered(conveyor.player)
		check(
			director.score == score_before + 1
			and session.audio.played_count(&"coin_pickup") == sound_before + 1,
			"Airborne interception increments score and requests the existing Refund Coin SFX exactly once"
		)
		coin._physics_process(2.0)
		check(
			coin.is_resolved() and director.ballistic_first_contact_count() == 0,
			"Aerial collection stops motion cleanly without a stale landing callback"
		)
	session.queue_free()
	await process_frame


func _test_bounce_lifetime_warning_and_conveyor_motion() -> void:
	var conveyor := await _make_fixture(6721)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var plan := director._build_ballistic_plan(
		Vector2(680.0, director._ballistic_contact_y()),
		CollectibleDirector.BallisticArchetype.HIGH,
		2.5
	)
	var coin := COIN_SCENE.instantiate() as ConveyorCollectible
	director.add_child(coin)
	coin.configure(2.5, conveyor.conveyor_speed, director.collectible_size, 0, 6721, 0.70)
	coin.configure_ballistic(
		plan.launch_position, plan.landing_position, plan.launch_velocity,
		plan.flight_duration, plan.gravity, 2.5, conveyor.conveyor_speed,
		director.ballistic_bounce_restitutions
	)
	var initial_ttl := coin.time_remaining
	coin._physics_process(float(plan.flight_duration) - 0.01)
	coin._process(float(plan.flight_duration) - 0.01)
	check(
		not coin.first_contact_occurred()
		and is_equal_approx(coin.time_remaining, initial_ttl)
		and not coin.expiry_warning_is_active(),
		"Flight time does not consume the post-contact collectible window or trigger expiry blinking"
	)
	coin._physics_process(0.02)
	coin._process(0.02)
	check(
		coin.first_contact_occurred()
		and coin.motion_state() == ConveyorCollectible.MotionState.BOUNCING
		and coin.bounce_count() == 1,
		"First valid conveyor contact deterministically starts the visible first bounce"
	)
	var x_after_contact := coin.global_position.x
	var elapsed_after_contact := 0.0
	while not coin.is_resolved() and coin.motion_state() != ConveyorCollectible.MotionState.SETTLED and elapsed_after_contact < 3.0:
		coin._physics_process(1.0 / 240.0)
		coin._process(1.0 / 240.0)
		elapsed_after_contact += 1.0 / 240.0
	check(
		coin.motion_state() == ConveyorCollectible.MotionState.SETTLED
		and coin.bounce_count() == 2
		and coin.settled_count() == 1,
		"Bounce lifecycle performs one clear bounce, one smaller bounce, then settles without infinite jitter"
	)
	check(
		coin.global_position.x < x_after_contact - 1.0,
		"The conveyor carries the coin left during bounce and settled states"
	)
	var before_warning := maxf(coin.time_remaining - coin.expiry_warning_duration - 0.02, 0.0)
	coin._physics_process(before_warning)
	coin._process(before_warning)
	check(not coin.expiry_warning_is_active(), "Post-contact expiry warning remains off before its final 0.70 seconds")
	coin._physics_process(0.03)
	coin._process(0.03)
	check(
		coin.expiry_warning_is_active() and coin.expiry_warning_start_count() == 1,
		"Accepted accelerating expiry warning begins once in the final post-contact window"
	)
	coin._physics_process(1.0)
	check(coin.is_resolved(), "Settled ballistic coin expires cleanly after its post-contact lifetime")
	conveyor.queue_free()
	await process_frame


func _test_multi_coin_differentiation_cap_and_expiry() -> void:
	var conveyor := await _make_fixture(6731)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director._natural_offer_count = 1
	director.coin_event_size_weights = PackedInt32Array([0, 0, 100])
	var delivered_triple := false
	for _attempt in range(12):
		director._try_spawn_variable_coin_event()
		var event: Dictionary = director.coin_event_log()[-1]
		if int(event.spawned_count) == 3:
			delivered_triple = true
			check(
				_unique_int_count(event.trajectory_archetypes) == 3
				and event.flight_durations == PackedFloat32Array([0.72, 0.90, 1.10]),
				"A delivered triple uses differentiated SHALLOW, MEDIUM, and HIGH trajectories"
			)
			break
		_resolve_all_coins(director)
	check(delivered_triple, "Bounded safe placement attempts can deliver a complete ballistic triple")
	check(director.active_collectible_count() <= 5, "Ballistic events preserve the five-coin active cap")
	if delivered_triple:
		var siblings := director.active_collectibles()
		var distinct_ttls := {}
		for coin in siblings:
			distinct_ttls[snappedf(coin.post_contact_lifetime(), 0.001)] = true
		check(distinct_ttls.size() >= 2, "Siblings retain independently randomized post-contact lifetimes")
		var earliest := siblings[0]
		var latest := siblings[0]
		for coin in siblings:
			if coin.post_contact_lifetime() < earliest.post_contact_lifetime():
				earliest = coin
			if coin.post_contact_lifetime() > latest.post_contact_lifetime():
				latest = coin
		for coin in siblings:
			coin._physics_process(coin.flight_duration() + earliest.post_contact_lifetime() + 0.02)
		check(earliest.is_resolved() and (earliest == latest or not latest.is_resolved()), "Sibling expiry remains independent after separate first-contact timers")
	_resolve_all_coins(director)
	for index in range(4):
		var dummy := COIN_SCENE.instantiate() as ConveyorCollectible
		director.add_child(dummy)
		dummy.configure(5.0, 0.0, Vector2(24.0, 24.0), 0, 6800 + index, 0.70)
		dummy.global_position = Vector2(420.0 + index * 80.0, 520.0)
		director._active_offers.append({"id": 6800 + index, "coins": [dummy], "pending_candidates": [], "log_index": -1})
	director.coin_event_size_weights = PackedInt32Array([0, 0, 100])
	director._try_spawn_variable_coin_event()
	check(
		director.active_collectible_count() <= 5
		and director.coin_event_cap_truncated_coin_count() >= 2,
		"A selected triple truncates at the existing cap rather than exceeding five active coins"
	)
	conveyor.queue_free()
	await process_frame


func _test_natural_metrics_and_d3_priority() -> void:
	for seed in TEST_SEEDS:
		var shell := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn").instantiate() as MotionExperimentShell
		root.add_child(shell)
		await process_frame
		var conveyor := shell.conveyor
		var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		var d3 := shell.background_drop_director
		director.ballistic_coin_events_enabled = true
		director.placement_seed = seed
		director._placement_rng_state = seed
		director._stream_rng_state = maxi(posmod(seed * 1664525 + 1013904223, 0x7fffffff), 1)
		conveyor.initial_warning_delay = 999.0
		conveyor.left_failure_enabled = false
		conveyor.set_physics_process(false)
		(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
		director.set_process(false)
		d3.set_process(false)
		conveyor.player.global_position = Vector2(640.0, 420.0)
		conveyor.player.collision_layer = 0
		conveyor.player.set_physics_process(false)
		var max_active := 0
		var step := 1.0 / 120.0
		while conveyor.survival_time < 59.95:
			conveyor.survival_time += step
			conveyor._update_continuous_speed_ramps()
			for coin in director.active_collectibles():
				coin._physics_process(step)
				coin._process(step)
			director._process(step)
			d3._process(step)
			for product in conveyor.active_falling_products():
				product._physics_process(step)
			for product in conveyor.active_landed_products():
				product._physics_process(step)
			max_active = maxi(max_active, director.active_collectible_count())
		var event_sizes := PackedInt32Array([0, 0, 0, 0])
		var invalid_event_intervals := 0
		for event in director.coin_event_log():
			event_sizes[clampi(int(event.requested_count), 0, 3)] += 1
			var interval := float(event.next_event_interval)
			if (
				interval < director.coin_event_interval_range.x - 0.001
				or interval > director.coin_event_interval_range.y + 0.001
			):
				invalid_event_intervals += 1
		var flights := director.ballistic_flight_log()
		var lifetimes := director.ballistic_post_contact_lifetime_log()
		var flight_average := _average(flights)
		var lifetime_average := _average(lifetimes)
		var candidate_rejections := d3.candidate_rejection_counts_by_reason()
		check(
			d3.released_event_count() == 6
			and d3.longest_successful_warning_gap() <= 10.0
			and int(candidate_rejections.get("collectible_path_overlap", 0)) == 0,
			"Seed %d preserves all six D3 releases without delaying their accepted warning cadence" % seed
		)
		check(
			max_active <= 5
			and invalid_event_intervals == 0
			and not flights.is_empty()
			and _minimum(flights) >= 0.6
			and _maximum(flights) <= 1.2
			and lifetime_average >= 2.0
			and lifetime_average <= 3.0,
			"Seed %d keeps flight, post-contact lifetime, and active-count metrics inside the approved prototype envelope" % seed
		)
		print(
			"VM067_METRICS seed=%d events=%d coins=%d selected_1/2/3=%d/%d/%d archetypes=%s avg_flight=%.3f flight_minmax=%.3f..%.3f launch_sides=%s airborne_player_crossings=%d landing_sides=%s settle_sides=%s avg_post_ttl=%.3f max_active=%d trunc_events=%d trunc_coins=%d placement_failures=%d trajectory_failures=%d coin_rejections=%s d3_longest_gap=%.3f d3_rejections=%s"
			% [
				seed, director.coin_event_count(), director.spawn_count,
				event_sizes[1], event_sizes[2], event_sizes[3],
				director.ballistic_archetype_counts(), flight_average,
				_minimum(flights),
				_maximum(flights),
				director.ballistic_launch_side_counts(),
				director.ballistic_player_crossing_count(),
				director.ballistic_landing_side_counts(),
				director.ballistic_settle_side_counts(),
				lifetime_average, max_active,
				director.coin_event_cap_truncated_event_count(),
				director.coin_event_cap_truncated_coin_count(),
				director.coin_event_placement_failure_count(),
				director.ballistic_trajectory_failure_count(),
				director.rejection_counts(),
				d3.longest_successful_warning_gap(),
				candidate_rejections,
			]
		)
		shell.queue_free()
		await process_frame


func _test_round_end_and_retry_cleanup() -> void:
	var conveyor := await _make_fixture(6741)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director._try_spawn_independent_coin(
		"event", 2.5, false, CollectibleDirector.OfferSide.AHEAD,
		[], 74, 1, 0, [], CollectibleDirector.BallisticArchetype.MEDIUM, []
	)
	check(director.active_collectible_count() == 1, "Cleanup fixture starts with one live ballistic coin")
	director.stop_for_round_end()
	var stopped_cleanly := true
	for coin in director.active_collectibles():
		stopped_cleanly = stopped_cleanly and not coin.visible and not coin.is_physics_processing()
	check(stopped_cleanly, "Round end disables and hides every ballistic coin")
	conveyor.queue_free()
	await process_frame

	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_AUDIO)
	var session := BALLISTIC_SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = TEST_SAVE
	session.audio_settings_path = TEST_AUDIO
	root.add_child(session)
	await process_frame
	session.start_game()
	await process_frame
	var first_game_id := session.game.get_instance_id()
	var first_director := session.game.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	first_director.set_process(false)
	first_director._try_spawn_independent_coin(
		"event", 2.5, false, CollectibleDirector.OfferSide.AHEAD,
		[], 75, 1, 0, [], CollectibleDirector.BallisticArchetype.HIGH, []
	)
	session.start_game()
	await process_frame
	var retry_director := session.game.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		session.game.get_instance_id() != first_game_id
		and retry_director.score == 0
		and retry_director.active_collectible_count() == 0
		and retry_director.ballistic_first_contact_count() == 0,
		"Retry replaces the run and clears score, coins, and ballistic lifecycle state"
	)
	session.queue_free()
	await process_frame


func _make_fixture(seed: int) -> ConveyorPrototype:
	var conveyor := CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.placement_seed = seed
	director.ballistic_coin_events_enabled = true
	root.add_child(conveyor)
	await physics_frame
	conveyor.set_physics_process(false)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director.set_process(false)
	conveyor.player.global_position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	return conveyor


func _resolve_all_coins(director: CollectibleDirector) -> void:
	for coin in director.active_collectibles():
		coin._resolve(false)
	director._refresh_active_offers()


func _unique_int_count(values: Variant) -> int:
	var seen := {}
	for value in values:
		seen[int(value)] = true
	return seen.size()


func _average(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _minimum(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var result := INF
	for value in values:
		result = minf(result, value)
	return result


func _maximum(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var result := -INF
	for value in values:
		result = maxf(result, value)
	return result
