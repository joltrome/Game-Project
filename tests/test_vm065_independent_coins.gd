extends SceneTree

const COIN_SCENE := preload("res://scenes/collectibles/conveyor_collectible.tscn")
const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const STANDARD_GAME_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const TEST_SEEDS := [401, 1701, 4202]
const VM064_TOTALS := {401: 53, 1701: 54, 4202: 52}

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
	await _test_independent_expiry_warning()
	await _test_stream_configuration_and_bonus()
	await _test_seeded_stream_metrics_and_determinism()
	await _test_d3_hazard_priority()
	print("VM065_INDEPENDENT_COINS_FAILURES=", failures)
	quit(failures)


func _test_independent_expiry_warning() -> void:
	var first := COIN_SCENE.instantiate() as ConveyorCollectible
	var second := COIN_SCENE.instantiate() as ConveyorCollectible
	root.add_child(first)
	root.add_child(second)
	first.configure(2.5, 0.0, Vector2(24.0, 24.0), 0, 101, 0.70)
	second.configure(4.0, 0.0, Vector2(24.0, 24.0), 0, 202, 0.70)
	first._physics_process(1.79)
	first._process(1.79)
	check(not first.expiry_warning_is_active(), "Expiry warning remains off before the final 0.70 seconds")
	first._physics_process(0.02)
	first._process(0.02)
	var early_rate := first.current_warning_pulses_per_second()
	check(
		first.expiry_warning_is_active()
		and first.expiry_warning_start_count() == 1
		and first.time_remaining <= 0.70,
		"Each coin starts one warning at its own configured remaining lifetime"
	)
	first._physics_process(0.50)
	first._process(0.50)
	check(
		first.current_warning_pulses_per_second() > early_rate
		and first.current_warning_pulses_per_second() <= 4.001,
		"Expiry warning accelerates while remaining capped at four pulses per second"
	)
	check(
		first.current_visual_alpha() >= first.expiry_warning_minimum_alpha - 0.001
		and first.current_visual_alpha() <= 1.001,
		"Expiry warning uses restrained opacity and never flashes fully off"
	)
	second._physics_process(3.31)
	second._process(3.31)
	check(
		second.expiry_warning_is_active()
		and not is_equal_approx(first.glint_phase_offset(), second.glint_phase_offset())
		and not is_equal_approx(first.current_visual_alpha(), second.current_visual_alpha()),
		"Different coin seeds keep overlapping expiry warnings independently phased"
	)
	var collected_count := [0]
	first.collected.connect(func(_coin: ConveyorCollectible): collected_count[0] += 1)
	first._resolve(true)
	first._resolve(true)
	check(
		collected_count[0] == 1
		and first.is_resolved()
		and not first.expiry_warning_is_active()
		and is_equal_approx(first.current_visual_alpha(), 1.0),
		"Collection resolves exactly once and cancels expiry presentation cleanly"
	)
	first.queue_free()
	second.queue_free()
	await process_frame


func _test_stream_configuration_and_bonus() -> void:
	var conveyor := await _make_fixture(8501)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		director.independent_stream_enabled
		and director.independent_spawn_interval_range == Vector2(0.75, 1.70)
		and director.maximum_active_independent_coins == 4
		and director.independent_lifetime_range == Vector2(2.50, 4.00)
		and is_equal_approx(director.independent_expiry_warning_duration, 0.70),
		"Independent stream exposes the approved interval, cap, TTL, and warning values"
	)
	director.independent_bonus_probability = 1.0
	director.independent_bonus_delay_range = Vector2(0.10, 0.30)
	_advance_fixture(conveyor, 1.76)
	var first_entries := _accepted_stream_entries(director)
	check(
		first_entries.size() == 1
		and String(first_entries[0].spawn_kind) == "teaching"
		and absf(float(first_entries[0].spawn_timestamp) - 1.75) <= 0.02,
		"The existing teaching coin remains a single entity around 1.75 seconds"
	)
	for coin in director.active_collectibles():
		coin._resolve(false)
	director._refresh_active_offers()
	while director.normal_stream_spawn_count() < 1 and conveyor.survival_time < 5.0:
		_advance_fixture(conveyor, 1.0 / 120.0)
	var normal_time := _first_spawn_time(director, "normal")
	var bonus_due := director.pending_bonus_spawn_time()
	check(
		is_finite(normal_time)
		and bonus_due >= normal_time + 0.10 - 0.001
		and bonus_due <= normal_time + 0.30 + 0.001,
		"A selected bonus is independently delayed by 0.10-0.30 seconds"
	)
	while director.bonus_stream_spawn_count() < 1 and conveyor.survival_time < bonus_due + 0.5:
		_advance_fixture(conveyor, 1.0 / 120.0)
	var bonus_time := _first_spawn_time(director, "bonus")
	check(
		is_finite(bonus_time)
		and bonus_time > normal_time
		and bonus_time - normal_time >= 0.10 - 0.02
		and bonus_time - normal_time <= 0.30 + 0.02,
		"Bonus creates one later independent coin rather than a synchronized offer"
	)
	var bonus_entry := _first_spawn_entry(director, "bonus")
	var normal_entry := _first_spawn_entry(director, "normal")
	check(
		bonus_entry.size() > 0
		and normal_entry.size() > 0
		and (bonus_entry.candidate_positions[0] as Vector2).distance_to(
			normal_entry.candidate_positions[0]
		) + 0.001 >= director.independent_bonus_minimum_separation,
		"Bonus position is independently sampled at least 96 px from its predecessor"
	)
	conveyor.queue_free()
	await process_frame


func _test_seeded_stream_metrics_and_determinism() -> void:
	for seed in TEST_SEEDS:
		var first := await _simulate_stream(seed)
		var second := await _simulate_stream(seed)
		check(
			first.signature == second.signature,
			"Seed %d reproduces spawn times, positions, kinds, and lifetimes" % seed
		)
		check(
			abs(int(first.total) - int(VM064_TOTALS[seed])) <= 8,
			"Seed %d keeps offered coins broadly comparable to VM-0.6.4" % seed
		)
		check(
			int(first.max_active) <= 4,
			"Seed %d never exceeds the four-coin active cap" % seed
		)
		check(
			int(first.synchronized_three_count) == 0,
			"Seed %d never creates a synchronized three-coin burst" % seed
		)
		check(
			int(first.invalid_lifetime_count) == 0
			and int(first.invalid_interval_count) == 0
			and int(first.invalid_geometry_count) == 0,
			"Seed %d respects TTL, interval, player, geometry, and separation bounds" % seed
		)
		print(
			"VM065_STREAM seed=%d old=%d new=%d average_active=%.3f max_active=%d normal=%d bonus=%d cap_skips=%d priority_skips=%d interval_min=%.3f interval_max=%.3f ttl_min=%.3f ttl_max=%.3f"
			% [
				seed,
				VM064_TOTALS[seed],
				first.total,
				first.average_active,
				first.max_active,
				first.normal,
				first.bonus,
				first.cap_skips,
				first.priority_skips,
				first.interval_min,
				first.interval_max,
				first.ttl_min,
				first.ttl_max,
			]
		)
		if seed == 401:
			print("VM065_TIMELINE_SAMPLE=", first.signature.slice(0, 12))


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
		conveyor.player.global_position = Vector2(720.0, 420.0)
		conveyor.player.collision_layer = 0
		conveyor.player.set_physics_process(false)
		var step := 1.0 / 120.0
		while conveyor.survival_time < 59.95:
			conveyor.survival_time += step
			# The fixture owns the real VM-0.6.4 speed ramp, but its physics
			# process is disabled so the deterministic test can advance manually.
			# Keep the support/coin speed synchronized exactly as runtime does.
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
			"Seed %d preserves six D3 events without coin-caused warning delay" % seed
		)
		print(
			"VM065_D3 seed=%d warnings=%s longest_gap=%.3f collectible_rejections=%d coin_priority_skips=%d offered=%d rejections=%s"
			% [
				seed,
				d3.successful_warning_times(),
				d3.longest_successful_warning_gap(),
				int(candidate_rejections.get("collectible_path_overlap", 0)),
				coins.stream_priority_skip_count(),
				coins.spawn_count,
				_d3_rejection_entries(d3),
			]
		)
		shell.queue_free()
		await process_frame


func _simulate_stream(seed: int) -> Dictionary:
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
	var entries := _accepted_stream_entries(director)
	var signature: Array = []
	var invalid_lifetimes := 0
	var invalid_intervals := 0
	var invalid_geometry := 0
	var simultaneous_counts := {}
	var intervals: Array[float] = []
	var lifetimes: Array[float] = []
	for entry in entries:
		var lifetime := float(entry.coin_lifetime)
		if String(entry.spawn_kind) != "teaching":
			lifetimes.append(lifetime)
			if lifetime < director.independent_lifetime_range.x - 0.001 or lifetime > director.independent_lifetime_range.y + 0.001:
				invalid_lifetimes += 1
		var interval := float(entry.get("next_stream_interval", -1.0))
		if String(entry.spawn_kind) != "bonus":
			intervals.append(interval)
			if interval < director.independent_spawn_interval_range.x - 0.001 or interval > director.independent_spawn_interval_range.y + 0.001:
				invalid_intervals += 1
		var position := entry.candidate_positions[0] as Vector2
		if String(entry.spawn_kind) != "teaching" and not director.candidate_rejection_reason(position, int(entry.ground_count == 0)).is_empty():
			# Runtime hazards may have changed after the historical spawn. Bounds and
			# player exclusion are checked from the immutable log below instead.
			pass
		if position.x < director._route_bounds().x - 0.001 or position.x > conveyor.control_band_right - director.collectible_size.x * 0.5 + 0.001:
			invalid_geometry += 1
		var time_key := roundi(float(entry.spawn_timestamp) * 1000.0)
		simultaneous_counts[time_key] = int(simultaneous_counts.get(time_key, 0)) + 1
		signature.append([
			String(entry.spawn_kind),
			snappedf(float(entry.spawn_timestamp), 0.001),
			Vector2(snappedf(position.x, 0.001), snappedf(position.y, 0.001)),
			snappedf(lifetime, 0.001),
		])
	var synchronized_three := 0
	for count in simultaneous_counts.values():
		if int(count) >= 3:
			synchronized_three += 1
	intervals.sort()
	lifetimes.sort()
	var result := {
		"signature": signature,
		"total": entries.size(),
		"average_active": active_integral / 59.95,
		"max_active": max_active,
		"normal": director.normal_stream_spawn_count(),
		"bonus": director.bonus_stream_spawn_count(),
		"cap_skips": director.stream_cap_skip_count(),
		"priority_skips": director.stream_priority_skip_count(),
		"synchronized_three_count": synchronized_three,
		"invalid_lifetime_count": invalid_lifetimes,
		"invalid_interval_count": invalid_intervals,
		"invalid_geometry_count": invalid_geometry,
		"interval_min": intervals[0] if not intervals.is_empty() else 0.0,
		"interval_max": intervals[-1] if not intervals.is_empty() else 0.0,
		"ttl_min": lifetimes[0] if not lifetimes.is_empty() else 0.0,
		"ttl_max": lifetimes[-1] if not lifetimes.is_empty() else 0.0,
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
	conveyor.player.global_position = Vector2(720.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	return conveyor


func _advance_fixture(conveyor: ConveyorPrototype, duration: float) -> void:
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	conveyor.survival_time += duration
	director._process(duration)
	for coin in director.active_collectibles():
		coin._physics_process(duration)
		coin._process(duration)


func _accepted_stream_entries(director: CollectibleDirector) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in director.offer_log():
		if (
			String(entry.get("event", "")) == "attempt"
			and bool(entry.get("accepted", false))
			and String(entry.get("topology", "")) == "INDEPENDENT_STREAM"
		):
			result.append(entry)
	return result


func _first_spawn_time(director: CollectibleDirector, kind: String) -> float:
	var entry := _first_spawn_entry(director, kind)
	return float(entry.spawn_timestamp) if not entry.is_empty() else INF


func _first_spawn_entry(director: CollectibleDirector, kind: String) -> Dictionary:
	for entry in _accepted_stream_entries(director):
		if String(entry.spawn_kind) == kind:
			return entry
	return {}


func _d3_rejection_entries(d3: MotionBackgroundDropDirector) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in d3.event_log():
		if String(entry.get("event", "")) == "rejection":
			result.append(entry)
	return result
