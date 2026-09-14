extends SceneTree

const COIN_SCENE := preload("res://scenes/collectibles/conveyor_collectible.tscn")
const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const STANDARD_GAME_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const TEST_SEEDS := [401, 1701, 4202]

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
	await _test_configuration_and_event_sizes()
	await _test_visible_lifetime_and_player_relative_sides()
	await _test_cap_truncation()
	await _test_seeded_event_metrics_and_determinism()
	await _test_d3_hazard_priority()
	print("VM066_VARIABLE_COIN_EVENT_FAILURES=", failures)
	quit(failures)


func _test_configuration_and_event_sizes() -> void:
	var conveyor := await _make_fixture(6601)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		director.variable_coin_events_enabled
		and director.coin_event_interval_range == Vector2(1.10, 2.10)
		and director.coin_event_size_weights == PackedInt32Array([55, 35, 10])
		and director.maximum_active_independent_coins == 5
		and is_equal_approx(director.minimum_guaranteed_visible_lifetime, 1.65)
		and is_equal_approx(director.coin_event_minimum_separation, 110.0)
		and is_equal_approx(director.coin_event_sibling_minimum_separation, 96.0),
		"Variable events expose the tuned interval, approved 55/35/10 weights, cap, and minimum visible lifetime"
	)
	_advance_fixture(conveyor, 1.76)
	var teaching := _accepted_coin_entries(director, "INDEPENDENT_STREAM")
	check(
		teaching.size() == 1
		and String(teaching[0].spawn_kind) == "teaching"
		and absf(float(teaching[0].spawn_timestamp) - 1.75) <= 0.02,
		"The teaching coin remains one straightforward coin around 1.75 seconds"
	)
	_resolve_all_coins(director)

	for requested_count in [1, 2, 3]:
		var weights := PackedInt32Array([0, 0, 0])
		weights[requested_count - 1] = 100
		director.coin_event_size_weights = weights
		var event: Dictionary = {}
		var delivered_requested_size := false
		# A selected multi-coin event may truncate rather than violate placement
		# safety. Bounded retries prove each supported size can still be delivered.
		for _attempt in range(8):
			director._try_spawn_variable_coin_event()
			event = director.coin_event_log()[-1]
			delivered_requested_size = int(event.spawned_count) == requested_count
			if delivered_requested_size:
				break
			_resolve_all_coins(director)
		check(
			int(event.requested_count) == requested_count
			and delivered_requested_size
			and int(event.spawned_count) <= 3,
			"Bounded empty-arena attempts can deliver a selected %d-coin event and never create more than three coins" % requested_count
		)
		if requested_count >= 2 and int(event.spawned_count) >= 2:
			check(
				_unique_int_count(event.spawned_sides) >= 2,
				"A %d-coin event creates competing player-relative directions" % requested_count
			)
			check(
				_values_are_independent(event.requested_lifetimes),
				"Coins sharing one event receive independent requested lifetimes"
			)
		_resolve_all_coins(director)
	conveyor.queue_free()
	await process_frame


func _test_visible_lifetime_and_player_relative_sides() -> void:
	var conveyor := await _make_fixture(6611)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	conveyor.survival_time = 20.0
	conveyor._update_continuous_speed_ramps()
	var minimum_x := director._minimum_event_spawn_x()
	var minimum_effective := director._event_effective_visible_lifetime(minimum_x, 4.0)
	check(
		absf(minimum_effective - 1.65) <= 0.02,
		"The left placement boundary guarantees approximately 1.65 seconds rather than a full requested TTL"
	)
	var observed_effective_truncation := false
	for side in [
		CollectibleDirector.OfferSide.BEHIND,
		CollectibleDirector.OfferSide.CENTRED,
		CollectibleDirector.OfferSide.AHEAD,
	]:
		var sampled := director._sample_independent_candidate(4.0, false, "event", side, [])
		var candidate: Dictionary = sampled.get("candidate", {})
		check(not candidate.is_empty(), "%s placement has a valid deliberate sampling region" % director.offer_side_name(side))
		if candidate.is_empty():
			continue
		var actual_side := director.classify_offer_side_for_test(
			[candidate],
			conveyor.player.global_position.x
		)
		var effective := float(sampled.effective_lifetime)
		check(actual_side == side, "%s sample is genuinely player-relative" % director.offer_side_name(side))
		check(
			effective + 0.001 >= director.minimum_guaranteed_visible_lifetime
			and effective <= 4.001,
			"%s sample respects minimum and requested visible-lifetime bounds" % director.offer_side_name(side)
		)
		observed_effective_truncation = observed_effective_truncation or effective < 3.999
	check(
		observed_effective_truncation,
		"At least one left/near sample uses conveyor-exit-limited effective lifetime instead of being forced right"
	)

	var accepted := director._try_spawn_independent_coin(
		"event",
		4.0,
		false,
		CollectibleDirector.OfferSide.BEHIND,
		[],
		99,
		1,
		0
	)
	check(accepted, "A behind-player event coin can spawn through the complete runtime path")
	if accepted:
		var coin := director.active_collectible()
		var warning_lead := minf(director.independent_expiry_warning_duration, coin.lifetime)
		check(
			coin.lifetime + 0.001 >= director.minimum_guaranteed_visible_lifetime
			and coin.lifetime <= 4.001,
			"Runtime coin lifetime is configured from actual visible time"
		)
		coin._physics_process(maxf(coin.lifetime - warning_lead - 0.01, 0.0))
		coin._process(maxf(coin.lifetime - warning_lead - 0.01, 0.0))
		check(not coin.expiry_warning_is_active(), "Effective-lifetime warning remains off before its final window")
		coin._physics_process(0.02)
		coin._process(0.02)
		check(coin.expiry_warning_is_active(), "Effective-lifetime warning begins relative to the actual exit-limited lifetime")
	conveyor.queue_free()
	await process_frame


func _test_cap_truncation() -> void:
	var conveyor := await _make_fixture(6621)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	for index in range(4):
		var coin := COIN_SCENE.instantiate() as ConveyorCollectible
		director.add_child(coin)
		coin.global_position = Vector2(420.0 + index * 82.0, 548.0 if index % 2 == 0 else 492.0)
		coin.configure(4.0, 0.0, Vector2(24.0, 24.0), 0, 900 + index, 0.70)
		director._active_offers.append({
			"id": 900 + index,
			"coins": [coin],
			"pending_candidates": [],
			"spawn_time": 0.0,
			"log_index": -1,
		})
	director._natural_offer_count = 1
	director.coin_event_size_weights = PackedInt32Array([0, 0, 100])
	director._try_spawn_variable_coin_event()
	var event: Dictionary = director.coin_event_log()[-1]
	check(
		int(event.requested_count) == 3
		and int(event.capacity_at_event) == 1
		and int(event.cap_truncated_count) == 2
		and int(event.spawned_count) <= 1
		and director.active_collectible_count() <= 5,
		"Four active coins truncate a selected triple to at most one new coin without deleting existing coins"
	)
	check(
		director.coin_event_cap_truncated_event_count() == 1
		and director.coin_event_cap_truncated_coin_count() == 2,
		"Cap truncation is recorded for deterministic QA"
	)
	conveyor.queue_free()
	await process_frame


func _test_seeded_event_metrics_and_determinism() -> void:
	var total_delivered_triples := 0
	var aggregate_single_sides := PackedInt32Array([0, 0, 0])
	for seed in TEST_SEEDS:
		var first := await _simulate_events(seed)
		var second := await _simulate_events(seed)
		check(first.signature == second.signature, "Seed %d reproduces event timing, size, side, position, and TTL" % seed)
		check(int(first.total_coins) >= 48 and int(first.total_coins) <= 54, "Seed %d stays within the 48-54 offered-coin target" % seed)
		check(int(first.max_active) <= 5, "Seed %d never exceeds the five-coin active cap" % seed)
		check(int(first.single_events) > 0 and int(first.double_events) > 0 and int(first.triple_events) > 0, "Seed %d exercises single, double, and triple event intensity" % seed)
		total_delivered_triples += int(first.delivered_triples)
		aggregate_single_sides[CollectibleDirector.OfferSide.BEHIND] += int(first.single_behind)
		aggregate_single_sides[CollectibleDirector.OfferSide.CENTRED] += int(first.single_centred)
		aggregate_single_sides[CollectibleDirector.OfferSide.AHEAD] += int(first.single_ahead)
		check(int(first.behind) > 0 and int(first.centred) > 0 and int(first.ahead) > 0, "Seed %d genuinely produces behind, centred, and ahead coins" % seed)
		check(int(first.multi_direction_failures) == 0, "Seed %d multi-coin events retain competing directions when at least two spawn" % seed)
		check(int(first.invalid_event_size) == 0 and int(first.invalid_interval) == 0, "Seed %d respects event size and randomized interval bounds" % seed)
		check(int(first.invalid_ttl) == 0 and int(first.invalid_geometry) == 0 and int(first.invalid_separation) == 0, "Seed %d respects requested/effective TTL, geometry, player safety, and separation" % seed)
		check(int(first.independent_multi_ttl_failures) == 0, "Seed %d multi-coin events retain independent lifetimes and cleanup timing" % seed)
		print(
			"VM066_EVENTS seed=%d events=%d selected_1/2/3=%d/%d/%d delivered_0/1/2/3=%d/%d/%d/%d coins=%d side_all=%d/%d/%d side_single=%d/%d/%d requested_ttl=%.3f..%.3f effective_ttl=%.3f..%.3f exit_limited=%d average_active=%.3f max_active=%d cap_events=%d cap_coins=%d placement_failures=%d priority_skips=%d interval=%.3f..%.3f"
			% [
				seed, first.events, first.single_events, first.double_events, first.triple_events,
				first.delivered_zero, first.delivered_singles, first.delivered_doubles, first.delivered_triples,
				first.total_coins, first.behind, first.centred, first.ahead,
				first.single_behind, first.single_centred, first.single_ahead,
				first.requested_ttl_min, first.requested_ttl_max,
				first.effective_ttl_min, first.effective_ttl_max,
				first.exit_limited,
				first.average_active, first.max_active, first.cap_events, first.cap_coins,
				first.placement_failures, first.priority_skips,
				first.interval_min, first.interval_max,
			]
		)
		if seed == 401:
			print("VM066_TIMELINE_SAMPLE=", first.signature.slice(0, 12))
	check(
		total_delivered_triples > 0,
		"Representative natural seeds include complete simultaneous triple events without overriding cap or safety"
	)
	var aggregate_single_count := (
		aggregate_single_sides[CollectibleDirector.OfferSide.BEHIND]
		+ aggregate_single_sides[CollectibleDirector.OfferSide.CENTRED]
		+ aggregate_single_sides[CollectibleDirector.OfferSide.AHEAD]
	)
	var aggregate_single_ratios := Vector3(
		float(aggregate_single_sides[CollectibleDirector.OfferSide.BEHIND]) / aggregate_single_count,
		float(aggregate_single_sides[CollectibleDirector.OfferSide.CENTRED]) / aggregate_single_count,
		float(aggregate_single_sides[CollectibleDirector.OfferSide.AHEAD]) / aggregate_single_count
	)
	check(
		absf(aggregate_single_ratios.x - 0.35) <= 0.12
		and absf(aggregate_single_ratios.y - 0.20) <= 0.12
		and absf(aggregate_single_ratios.z - 0.45) <= 0.12,
		"Aggregate single-event sides broadly reproduce the configured 35/20/45 weighting"
	)
	print(
		"VM066_SINGLE_SIDE_AGGREGATE counts=%d/%d/%d ratios=%.3f/%.3f/%.3f"
		% [
			aggregate_single_sides[0], aggregate_single_sides[1], aggregate_single_sides[2],
			aggregate_single_ratios.x, aggregate_single_ratios.y, aggregate_single_ratios.z,
		]
	)


func _test_d3_hazard_priority() -> void:
	for seed in TEST_SEEDS:
		var shell := STANDARD_GAME_SCENE.instantiate() as MotionExperimentShell
		root.add_child(shell)
		await process_frame
		var conveyor := shell.conveyor
		var coins := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		var d3 := shell.background_drop_director
		coins.placement_seed = seed
		coins._placement_rng_state = seed
		coins._stream_rng_state = maxi(posmod(seed * 1664525 + 1013904223, 0x7fffffff), 1)
		conveyor.initial_warning_delay = 999.0
		conveyor.left_failure_enabled = false
		conveyor.set_physics_process(false)
		(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
		coins.set_process(false)
		d3.set_process(false)
		conveyor.player.global_position = Vector2(640.0, 420.0)
		conveyor.player.collision_layer = 0
		conveyor.player.set_physics_process(false)
		var step := 1.0 / 120.0
		while conveyor.survival_time < 59.95:
			conveyor.survival_time += step
			conveyor._update_continuous_speed_ramps()
			for coin in coins.active_collectibles():
				coin._physics_process(step)
				coin._process(step)
			coins._process(step)
			d3._process(step)
			for product in conveyor.active_falling_products():
				product._physics_process(step)
			for product in conveyor.active_landed_products():
				product._physics_process(step)
		var candidate_rejections := d3.candidate_rejection_counts_by_reason()
		check(
			d3.released_event_count() == 6
			and int(candidate_rejections.get("collectible_path_overlap", 0)) == 0
			and d3.longest_successful_warning_gap() <= 10.0,
			"Seed %d preserves all six D3 events without optional coins delaying hazards" % seed
		)
		print(
			"VM066_D3 seed=%d warnings=%s longest_gap=%.3f collectible_rejections=%d coin_priority_skips=%d events=%d coins=%d"
			% [
				seed, d3.successful_warning_times(), d3.longest_successful_warning_gap(),
				int(candidate_rejections.get("collectible_path_overlap", 0)),
				coins.stream_priority_skip_count(), coins.coin_event_count(), coins.spawn_count,
			]
		)
		shell.queue_free()
		await process_frame


func _simulate_events(seed: int) -> Dictionary:
	var conveyor := await _make_fixture(seed)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var step := 1.0 / 120.0
	var active_integral := 0.0
	var max_active := 0
	while conveyor.survival_time < 59.95:
		_advance_fixture(conveyor, step)
		var active := director.active_collectible_count()
		active_integral += active * step
		max_active = maxi(max_active, active)
	var events := director.coin_event_log()
	var entries := _accepted_coin_entries(director, "VARIABLE_EVENT")
	var signature: Array = []
	var size_counts := PackedInt32Array([0, 0, 0, 0])
	var delivered_counts := PackedInt32Array([0, 0, 0, 0])
	var sides := PackedInt32Array([0, 0, 0])
	var single_sides := PackedInt32Array([0, 0, 0])
	var requested_ttls: Array[float] = []
	var effective_ttls: Array[float] = []
	var intervals: Array[float] = []
	var invalid_event_size := 0
	var invalid_interval := 0
	var invalid_ttl := 0
	var invalid_geometry := 0
	var invalid_separation := 0
	var multi_direction_failures := 0
	var independent_multi_ttl_failures := 0
	var exit_limited := 0
	for event in events:
		var requested_count := int(event.requested_count)
		if requested_count < 1 or requested_count > 3:
			invalid_event_size += 1
		else:
			size_counts[requested_count] += 1
		var delivered_count := clampi(int(event.spawned_count), 0, 3)
		delivered_counts[delivered_count] += 1
		var interval := float(event.next_event_interval)
		intervals.append(interval)
		if interval < director.coin_event_interval_range.x - 0.001 or interval > director.coin_event_interval_range.y + 0.001:
			invalid_interval += 1
		var event_sides: PackedInt32Array = event.spawned_sides
		if int(event.spawned_count) >= 2 and _unique_int_count(event_sides) < 2:
			multi_direction_failures += 1
		var event_effective: PackedFloat32Array = event.effective_lifetimes
		if int(event.spawned_count) >= 2 and not _values_are_independent(event_effective):
			independent_multi_ttl_failures += 1
		for side in event_sides:
			sides[int(side)] += 1
			if requested_count == 1 and delivered_count == 1:
				single_sides[int(side)] += 1
		var positions: Array = event.spawned_positions
		for first_index in range(positions.size()):
			var position := positions[first_index] as Vector2
			if position.x < conveyor.conveyor_support_left_x + director.collectible_size.x * 0.5 - 0.01 or position.x > conveyor.control_band_right - director.collectible_size.x * 0.5 + 0.01:
				invalid_geometry += 1
			if not director._player_spawn_rejection_reason(position).is_empty():
				invalid_geometry += 1
			for second_index in range(first_index + 1, positions.size()):
				if position.distance_to(positions[second_index]) + 0.001 < director.coin_event_sibling_minimum_separation:
					invalid_separation += 1
	for entry in entries:
		var requested := float(entry.requested_lifetime)
		var effective := float(entry.effective_lifetime)
		requested_ttls.append(requested)
		effective_ttls.append(effective)
		if effective + 0.001 < requested:
			exit_limited += 1
		if requested < director.independent_lifetime_range.x - 0.001 or requested > director.independent_lifetime_range.y + 0.001 or effective < director.minimum_guaranteed_visible_lifetime - 0.01 or effective > requested + 0.001:
			invalid_ttl += 1
	for event in events:
		signature.append([
			int(event.requested_count), int(event.spawned_count),
			snappedf(float(event.time), 0.001),
			Array(event.spawned_sides),
			_snap_vectors(event.spawned_positions),
			_snap_floats(event.requested_lifetimes),
			_snap_floats(event.effective_lifetimes),
		])
	intervals.sort()
	requested_ttls.sort()
	effective_ttls.sort()
	var result := {
		"signature": signature,
		"events": events.size(),
		"single_events": size_counts[1],
		"double_events": size_counts[2],
		"triple_events": size_counts[3],
		"delivered_zero": delivered_counts[0],
		"delivered_singles": delivered_counts[1],
		"delivered_doubles": delivered_counts[2],
		"delivered_triples": delivered_counts[3],
		"total_coins": entries.size(),
		"behind": sides[CollectibleDirector.OfferSide.BEHIND],
		"centred": sides[CollectibleDirector.OfferSide.CENTRED],
		"ahead": sides[CollectibleDirector.OfferSide.AHEAD],
		"single_behind": single_sides[CollectibleDirector.OfferSide.BEHIND],
		"single_centred": single_sides[CollectibleDirector.OfferSide.CENTRED],
		"single_ahead": single_sides[CollectibleDirector.OfferSide.AHEAD],
		"requested_ttl_min": requested_ttls[0] if not requested_ttls.is_empty() else 0.0,
		"requested_ttl_max": requested_ttls[-1] if not requested_ttls.is_empty() else 0.0,
		"effective_ttl_min": effective_ttls[0] if not effective_ttls.is_empty() else 0.0,
		"effective_ttl_max": effective_ttls[-1] if not effective_ttls.is_empty() else 0.0,
		"exit_limited": exit_limited,
		"average_active": active_integral / 59.95,
		"max_active": max_active,
		"cap_events": director.coin_event_cap_truncated_event_count(),
		"cap_coins": director.coin_event_cap_truncated_coin_count(),
		"placement_failures": director.coin_event_placement_failure_count(),
		"priority_skips": director.stream_priority_skip_count(),
		"interval_min": intervals[0] if not intervals.is_empty() else 0.0,
		"interval_max": intervals[-1] if not intervals.is_empty() else 0.0,
		"invalid_event_size": invalid_event_size,
		"invalid_interval": invalid_interval,
		"invalid_ttl": invalid_ttl,
		"invalid_geometry": invalid_geometry,
		"invalid_separation": invalid_separation,
		"multi_direction_failures": multi_direction_failures,
		"independent_multi_ttl_failures": independent_multi_ttl_failures,
	}
	conveyor.queue_free()
	await process_frame
	return result


func _make_fixture(seed: int) -> ConveyorPrototype:
	var conveyor := CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.placement_seed = seed
	root.add_child(conveyor)
	await physics_frame
	conveyor.set_physics_process(false)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director.set_process(false)
	conveyor.player.global_position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	return conveyor


func _advance_fixture(conveyor: ConveyorPrototype, duration: float) -> void:
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	conveyor.survival_time += duration
	conveyor._update_continuous_speed_ramps()
	director._process(duration)
	for coin in director.active_collectibles():
		coin._physics_process(duration)
		coin._process(duration)


func _resolve_all_coins(director: CollectibleDirector) -> void:
	for coin in director.active_collectibles():
		coin._resolve(false)
	director._refresh_active_offers()


func _accepted_coin_entries(director: CollectibleDirector, topology: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in director.offer_log():
		if String(entry.get("event", "")) == "attempt" and bool(entry.get("accepted", false)) and String(entry.get("topology", "")) == topology:
			result.append(entry)
	return result


func _unique_int_count(values: Variant) -> int:
	var seen := {}
	for value in values:
		seen[int(value)] = true
	return seen.size()


func _values_are_independent(values: Variant) -> bool:
	if values.size() < 2:
		return true
	var first := float(values[0])
	for index in range(1, values.size()):
		if not is_equal_approx(first, float(values[index])):
			return true
	return false


func _snap_vectors(values: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for value in values:
		var vector := value as Vector2
		result.append(Vector2(snappedf(vector.x, 0.001), snappedf(vector.y, 0.001)))
	return result


func _snap_floats(values: Variant) -> Array[float]:
	var result: Array[float] = []
	for value in values:
		result.append(snappedf(float(value), 0.001))
	return result
