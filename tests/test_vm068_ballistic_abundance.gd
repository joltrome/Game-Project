extends SceneTree

const COIN_SCENE := preload("res://scenes/collectibles/conveyor_collectible.tscn")
const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const STANDARD_SESSION := preload("res://scenes/presentation/standard_session.tscn")
const MOTION_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const TEST_SEEDS := [401, 1701, 4202]

var failures := 0
var _test_can_rects: Array[Dictionary] = []


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
	await _test_isolated_configuration_and_rhythm()
	await _test_variation_and_independent_lifecycle()
	await _test_controlled_landed_can_collision()
	await _test_collection_telemetry()
	await _test_natural_abundance_and_d3_priority()
	await _test_cleanup()
	print("VM068_BALLISTIC_ABUNDANCE_FAILURES=", failures)
	quit(failures)


func _test_isolated_configuration_and_rhythm() -> void:
	var control := StandardSession.new()
	var prototype := STANDARD_SESSION.instantiate() as StandardSession
	check(
		not control.ballistic_coins_enabled
		and not control.ballistic_abundance_enabled
		and prototype.ballistic_coins_enabled
		and prototype.ballistic_abundance_enabled,
		"VM-0.6.8 is isolated while constructor defaults preserve VM-0.6.6 and VM-0.6.7 configuration paths"
	)
	var conveyor := await _make_fixture(6801)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		director.coin_event_interval_range == Vector2(1.10, 2.10)
		and director.coin_event_size_weights == PackedInt32Array([55, 35, 10])
		and director.maximum_active_independent_coins == 5
		and director.ballistic_post_contact_lifetime_range == Vector2(2.0, 3.0)
		and is_equal_approx(director.independent_expiry_warning_duration, 0.70),
		"Abundance experiment preserves cadence, 55/35/10 weights, cap, post-contact lifetime, and expiry warning"
	)
	director.ballistic_double_stagger_probability = 0.0
	check(
		director._ballistic_launch_delay_plan(2) == PackedFloat32Array([0.0, 0.0]),
		"Double events support a deterministic simultaneous launch mode"
	)
	director.ballistic_double_stagger_probability = 1.0
	var double_delays := director._ballistic_launch_delay_plan(2)
	check(
		double_delays[0] == 0.0
		and double_delays[1] >= 0.10
		and double_delays[1] <= 0.30,
		"Double events support a configurable 0.10–0.30 second stagger"
	)
	director.ballistic_triple_stagger_probability = 1.0
	var triple_delays := director._ballistic_launch_delay_plan(3)
	check(
		triple_delays[0] == 0.0
		and triple_delays[1] >= 0.10
		and triple_delays[1] <= 0.25
		and triple_delays[2] - triple_delays[1] >= 0.10
		and triple_delays[2] - triple_delays[1] <= 0.25,
		"Triple events support independently spaced 0.10–0.25 second staggered launches"
	)
	conveyor.queue_free()
	await process_frame
	control.free()
	prototype.free()


func _test_variation_and_independent_lifecycle() -> void:
	var first := await _make_fixture(6811)
	var second := await _make_fixture(6811)
	var a := first.get_node("CollectibleDirector") as CollectibleDirector
	var b := second.get_node("CollectibleDirector") as CollectibleDirector
	var landing := Vector2(650.0, a._ballistic_contact_y())
	var plan_a := a._build_ballistic_plan(
		landing, CollectibleDirector.BallisticArchetype.MEDIUM, 2.5, 0.2, true
	)
	var plan_b := b._build_ballistic_plan(
		landing, CollectibleDirector.BallisticArchetype.MEDIUM, 2.5, 0.2, true
	)
	var authored_origin := a.ballistic_launch_origins[CollectibleDirector.BallisticArchetype.MEDIUM]
	var origin_delta := (plan_a.launch_position as Vector2) - authored_origin
	check(plan_a == plan_b, "Identical deterministic seeds reproduce trajectory variation exactly")
	check(
		absf(origin_delta.x) <= a.ballistic_launch_origin_variance.x + 0.001
		and absf(origin_delta.y) <= a.ballistic_launch_origin_variance.y + 0.001
		and float(plan_a.flight_duration) >= 0.90 * 0.925 - 0.001
		and float(plan_a.flight_duration) <= 0.90 * 1.075 + 0.001,
		"Controlled launch-origin and duration variation stays inside configured bounds"
	)
	var first_coin := _configured_coin_from_plan(a, plan_a, 2.05)
	var second_plan := a._build_ballistic_plan(
		Vector2(760.0, a._ballistic_contact_y()),
		CollectibleDirector.BallisticArchetype.HIGH,
		2.95,
		0.0,
		true
	)
	var second_coin := _configured_coin_from_plan(a, second_plan, 2.95)
	first_coin._physics_process(10.0)
	check(
		first_coin.is_resolved() and not second_coin.is_resolved(),
		"Sibling coins retain independent flight, bounce, lifetime, warning, and cleanup state"
	)
	first.queue_free()
	second.queue_free()
	await process_frame


func _test_controlled_landed_can_collision() -> void:
	var conveyor := await _make_fixture(6821)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	_test_can_rects = [{"id": 91, "center": Vector2(620.0, 548.0), "size": Vector2(72.0, 48.0)}]
	var coin := COIN_SCENE.instantiate() as ConveyorCollectible
	director.add_child(coin)
	coin.configure(2.5, conveyor.conveyor_speed, Vector2(24.0, 24.0), 0, 6821, 0.70)
	var launch := Vector2(620.0, 420.0)
	var landing := Vector2(620.0, director._ballistic_contact_y())
	var duration := 0.55
	var velocity := Vector2(
		0.0,
		(landing.y - launch.y - 0.5 * director.ballistic_gravity * duration * duration) / duration
	)
	coin.configure_ballistic(
		launch, landing, velocity, duration, director.ballistic_gravity, 2.5,
		conveyor.conveyor_speed, director.ballistic_bounce_restitutions
	)
	coin.configure_landed_can_collision(
		Callable(self, "_landed_can_rects"), Vector2(260.0, 960.0), 2
	)
	var elapsed := 0.0
	while coin.landed_can_ricochet_count() == 0 and elapsed < 1.0:
		coin._physics_process(1.0 / 240.0)
		elapsed += 1.0 / 240.0
	check(
		coin.landed_can_ricochet_count() == 1
		and coin.motion_state() == ConveyorCollectible.MotionState.RICOCHETING
		and not coin.is_inside_landed_can(),
		"Top contact produces one bounded upward ricochet without embedding the coin"
	)
	coin._ricochet_contact_cooldown = 0.0
	coin._last_ricochet_can_id = -1
	var side_contact := coin._landed_can_contact(
		Vector2(500.0, 548.0), Vector2(590.0, 548.0), Vector2(240.0, 0.0)
	)
	check(
		not side_contact.is_empty()
		and (side_contact.normal as Vector2).x < -0.5,
		"Side contact is detected from the landed-can AABB and returns a deterministic outward normal"
	)
	coin._begin_can_ricochet(Vector2(240.0, 0.0), side_contact)
	check(
		coin.landed_can_ricochet_count() == 2
		and coin._ricochet_velocity.x < 0.0
		and coin._ricochet_velocity.y < 0.0,
		"Side contact applies a small horizontal reflection plus a readable upward component"
	)
	coin.position = Vector2(620.0, 548.0)
	coin._begin_can_ricochet(Vector2(0.0, 200.0), {"id": 91, "center": Vector2(620.0, 548.0), "normal": Vector2.UP})
	check(
		coin.landed_can_ricochet_count() == 2
		and (coin.is_resolved() or not coin.is_inside_landed_can()),
		"Ricochet limit forces a deterministic clear settle or expiry instead of jitter or permanent trapping"
	)
	conveyor.queue_free()
	await process_frame


func _test_collection_telemetry() -> void:
	var conveyor := await _make_fixture(6831)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	for phase in ["AIRBORNE", "BOUNCING", "SETTLED"]:
		var coin := COIN_SCENE.instantiate() as ConveyorCollectible
		director.add_child(coin)
		coin.configure(2.5, 0.0, Vector2(24.0, 24.0), 0, 6831, 0.70)
		coin.configure_ballistic(
			Vector2(700.0, 300.0), Vector2(620.0, 572.0), Vector2(-80.0, -30.0),
			0.9, 1250.0, 2.5, 140.0, Vector2(0.38, 0.16)
		)
		coin._motion_state = ConveyorCollectible.MotionState.get(phase, ConveyorCollectible.MotionState.AIRBORNE)
		if phase == "BOUNCING":
			coin._motion_state = ConveyorCollectible.MotionState.BOUNCING
		elif phase == "SETTLED":
			coin._motion_state = ConveyorCollectible.MotionState.SETTLED
		coin._launch_age = 1.25
		coin._resolve(true)
		director._on_collectible_collected(coin, -1)
	var expired := COIN_SCENE.instantiate() as ConveyorCollectible
	director.add_child(expired)
	expired.configure(1.0, 0.0, Vector2(24.0, 24.0))
	expired.configure_ballistic(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 1.0, 1.0, 1.0, 0.0, Vector2.ZERO)
	expired._resolve(false, "EXPIRED")
	director._on_collectible_expired(expired, -1)
	var exited := COIN_SCENE.instantiate() as ConveyorCollectible
	director.add_child(exited)
	exited.configure(1.0, 0.0, Vector2(24.0, 24.0))
	exited.configure_ballistic(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 1.0, 1.0, 1.0, 0.0, Vector2.ZERO)
	exited._resolve(false, "EXITED_LEFT")
	director._on_collectible_expired(exited, -1)
	var counts := director.ballistic_collection_counts()
	var summary := director.ballistic_run_summary()
	check(
		int(counts.AIRBORNE) == 1
		and int(counts.BOUNCING) == 1
		and int(counts.SETTLED) == 1
		and director.ballistic_expired_count() == 1
		and director.ballistic_exited_left_count() == 1
		and is_equal_approx(director.ballistic_average_launch_to_collection_time(), 1.25)
		and int(summary.collected) == 3,
		"Telemetry separates AIRBORNE, BOUNCING, SETTLED, EXPIRED, EXITED_LEFT, and launch-to-collection time"
	)
	conveyor.queue_free()
	await process_frame


func _test_natural_abundance_and_d3_priority() -> void:
	for seed in TEST_SEEDS:
		var shell := MOTION_SCENE.instantiate() as MotionExperimentShell
		root.add_child(shell)
		await process_frame
		var conveyor := shell.conveyor
		var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		var d3 := shell.background_drop_director
		director.ballistic_coin_events_enabled = true
		director.ballistic_abundance_enabled = true
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
		var active_total := 0.0
		var active_samples := 0
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
			var active := director.active_collectible_count()
			max_active = maxi(max_active, active)
			active_total += active
			active_samples += 1
		var requested := 1
		var event_sizes := PackedInt32Array([0, 0, 0, 0])
		var invalid_intervals := 0
		for event in director.coin_event_log():
			requested += int(event.requested_count)
			event_sizes[clampi(int(event.requested_count), 0, 3)] += 1
			var interval := float(event.next_event_interval)
			if interval < 1.10 - 0.001 or interval > 2.10 + 0.001:
				invalid_intervals += 1
		var delivery_rate := float(director.spawn_count) / float(maxi(requested, 1))
		var d3_rejections := d3.candidate_rejection_counts_by_reason()
		check(
			d3.released_event_count() == 6
			and d3.longest_successful_warning_gap() <= 8.80
			and int(d3_rejections.get("collectible_path_overlap", 0)) == 0,
			"Seed %d keeps all six D3 warnings on the frozen schedule with zero coin-caused delay" % seed
		)
		check(
			invalid_intervals == 0
			and max_active <= 5
			and director.spawn_count >= 30,
			"Seed %d preserves cadence/cap and materially reduces the VM-0.6.7 abundance confound" % seed
		)
		print(
			"VM068_METRICS seed=%d events=%d requested=%d delivered=%d delivery_pct=%.1f selected_1/2/3=%d/%d/%d simultaneous=%d staggered=%d archetypes=%s avg_active=%.3f max_active=%d cap_skips=%d cap_trunc_events=%d cap_trunc_coins=%d placement_failures=%d ricochets=%d rejections=%s d3_times=%s d3_longest_gap=%.3f d3_rejections=%s"
			% [
				seed, director.coin_event_count(), requested, director.spawn_count,
				delivery_rate * 100.0, event_sizes[1], event_sizes[2], event_sizes[3],
				director.ballistic_simultaneous_multi_event_count(),
				director.ballistic_staggered_multi_event_count(),
				director.ballistic_archetype_counts(),
				active_total / float(maxi(active_samples, 1)), max_active,
				director.stream_cap_skip_count(),
				director.coin_event_cap_truncated_event_count(),
				director.coin_event_cap_truncated_coin_count(),
				director.coin_event_placement_failure_count(),
				director.ballistic_total_ricochet_count(), director.rejection_counts(),
				d3.successful_warning_times(), d3.longest_successful_warning_gap(),
				d3_rejections,
			]
		)
		shell.queue_free()
		await process_frame


func _test_cleanup() -> void:
	var conveyor := await _make_fixture(6841)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director._try_spawn_variable_coin_event()
	check(director.active_collectible_count() > 0, "Cleanup fixture starts with live VM-0.6.8 ballistic state")
	director.stop_for_round_end()
	var stopped := true
	for coin in director.active_collectibles():
		stopped = stopped and not coin.visible and not coin.is_physics_processing()
	check(stopped, "Round end disables pending, airborne, bouncing, ricocheting, and settled coin state")
	conveyor.queue_free()
	await process_frame


func _make_fixture(seed: int) -> ConveyorPrototype:
	var conveyor := CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.placement_seed = seed
	director.ballistic_coin_events_enabled = true
	director.ballistic_abundance_enabled = true
	root.add_child(conveyor)
	await physics_frame
	conveyor.set_physics_process(false)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director.set_process(false)
	conveyor.player.global_position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	return conveyor


func _configured_coin_from_plan(
	director: CollectibleDirector,
	plan: Dictionary,
	lifetime: float
) -> ConveyorCollectible:
	var coin := COIN_SCENE.instantiate() as ConveyorCollectible
	director.add_child(coin)
	coin.configure(lifetime, 140.0, Vector2(24.0, 24.0), 0, 6811, 0.70)
	coin.configure_ballistic(
		plan.launch_position, plan.landing_position, plan.launch_velocity,
		plan.flight_duration, plan.gravity, lifetime, 140.0, Vector2(0.38, 0.16),
		float(plan.launch_delay)
	)
	return coin


func _landed_can_rects() -> Array[Dictionary]:
	return _test_can_rects
