extends SceneTree

const COIN_SCENE := preload("res://scenes/collectibles/conveyor_collectible.tscn")
const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const STANDARD_SESSION := preload("res://scenes/presentation/standard_session.tscn")
const MOTION_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const FIXED_STEP := 1.0 / 120.0
const TEST_SEEDS := [401, 1701, 4202, 7007, 9011]

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
	await _test_release_configuration_and_static_teaching()
	await _test_world_footprint_support_and_loss()
	await _test_multi_event_fallback_contract()
	await _test_natural_integrity_performance_and_frozen_d3()
	await _test_touch_control_layout_regression()
	print("VM070_REFUND_SYSTEM_FAILURES=", failures)
	quit(failures)


func _test_release_configuration_and_static_teaching() -> void:
	var defaults := StandardSession.new()
	var release := STANDARD_SESSION.instantiate() as StandardSession
	check(
		not defaults.refund_system_enabled
		and release.refund_system_enabled
		and release.refund_chute_enabled
		and release.ballistic_integrity_enabled,
		"VM-0.7.0 is release-opt-in while constructor defaults preserve earlier configuration paths"
	)
	var conveyor := await _make_fixture(7001)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var spawned := director._try_spawn_variable_coin_event()
	var teaching := director.active_collectible()
	check(
		spawned
		and teaching != null
		and not teaching.is_ballistic()
		and teaching.teaching_cue_is_visible()
		and teaching.placement_band == CollectibleDirector.PlacementBand.GROUND,
		"The first opportunity is a visible, cued, reachable static ground coin"
	)
	conveyor.survival_time = director.next_spawn_time()
	director._try_spawn_variable_coin_event()
	var later_ballistic := false
	for coin in director.active_collectibles():
		later_ballistic = later_ballistic or coin.is_ballistic()
	check(later_ballistic, "Normal ballistic events begin after the static teaching opportunity")
	conveyor.queue_free()
	await process_frame
	defaults.free()
	release.free()


func _test_world_footprint_support_and_loss() -> void:
	var conveyor := await _make_fixture(7002)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	_test_can_rects = [{
		"id": 91,
		"center": Vector2(620.0, 548.0),
		"size": Vector2(72.0, 48.0),
	}]
	var coin := _make_support_coin(director, conveyor, 7002)
	var contact := {
		"id": 91,
		"center": Vector2(620.0, 548.0),
		"size": Vector2(72.0, 48.0),
		"position": Vector2(620.0, 508.0),
		"normal": Vector2.UP,
	}
	coin.position = contact.position
	coin._handle_landed_can_contact(Vector2(0.0, 520.0), contact)
	check(
		coin.motion_state() == ConveyorCollectible.MotionState.RICOCHETING
		and coin.landed_can_ricochet_count() == 1,
		"First hard top impact always produces the readable bounce"
	)
	coin.position = contact.position
	coin._handle_landed_can_contact(Vector2(0.0, 120.0), contact)
	check(
		coin.motion_state() == ConveyorCollectible.MotionState.SUPPORTED_ON_CAN
		and coin.supported_can_id() == 91
		and coin.collision_geometry_size() == Vector2(24.0, 24.0)
		and coin.world_collision_size() == Vector2(32.0, 32.0)
		and not coin.is_inside_landed_can(),
		"A later low-energy top contact supports with 32x32 world clearance while pickup remains 24x24"
	)
	_test_can_rects[0].center.x += 18.0
	coin._physics_process(FIXED_STEP)
	check(
		is_equal_approx(coin.position.x, 638.0)
		and is_equal_approx(coin.position.y, 508.0),
		"Supported coin follows its specific moving can without sinking or visual overlap"
	)
	var competing := _make_support_coin(director, conveyor, 7003)
	competing._landed_can_ricochet_count = 1
	var moved_contact := contact.duplicate(true)
	moved_contact.center = Vector2(638.0, 548.0)
	moved_contact.position = Vector2(638.0, 508.0)
	competing.position = moved_contact.position
	competing._handle_landed_can_contact(Vector2(0.0, 100.0), moved_contact)
	check(
		competing.motion_state() == ConveyorCollectible.MotionState.RICOCHETING,
		"A landed can deterministically supports at most one coin"
	)
	competing._ricochet_contact_cooldown = 0.0
	competing._last_ricochet_can_id = -1
	var high_speed_side := competing._landed_can_contact(
		Vector2(500.0, 548.0),
		Vector2(720.0, 548.0),
		Vector2(220.0, 0.0)
	)
	check(
		not high_speed_side.is_empty()
		and absf(float((high_speed_side.position as Vector2).x) - 586.0) <= 0.01
		and (high_speed_side.normal as Vector2).x < -0.5,
		"High-speed side contact uses the 32 px world footprint rather than the 24 px pickup footprint"
	)
	coin._resolve(true)
	check(
		coin.collection_phase() == "SUPPORTED_ON_CAN"
		and coin.supported_can_id() == -1,
		"Collection while supported records its state and releases the can claim exactly once"
	)
	competing.stop()
	var loss_coin := _make_support_coin(director, conveyor, 7004)
	loss_coin._landed_can_ricochet_count = 1
	loss_coin.position = moved_contact.position
	loss_coin._handle_landed_can_contact(Vector2(0.0, 100.0), moved_contact)
	_test_can_rects.clear()
	loss_coin._physics_process(FIXED_STEP)
	var loss_started := (
		loss_coin.supported_can_id() == -1
		and loss_coin.motion_state() == ConveyorCollectible.MotionState.RICOCHETING
	)
	for _step in range(240):
		if loss_coin.is_resolved() or loss_coin.motion_state() == ConveyorCollectible.MotionState.SETTLED:
			break
		loss_coin._physics_process(FIXED_STEP)
	check(
		loss_started
		and (loss_coin.is_resolved() or loss_coin.motion_state() == ConveyorCollectible.MotionState.SETTLED)
		and not loss_coin.is_inside_landed_can(),
		"Can removal releases support, falls to a valid conveyor settle, and leaves no stale reference"
	)
	_test_can_rects = [{
		"id": 92,
		"center": Vector2(700.0, 548.0),
		"size": Vector2(72.0, 48.0),
	}]
	var expiry_coin := _make_support_coin(director, conveyor, 7006)
	expiry_coin._landed_can_ricochet_count = 1
	var expiry_contact := {
		"id": 92,
		"center": Vector2(700.0, 548.0),
		"size": Vector2(72.0, 48.0),
		"position": Vector2(700.0, 508.0),
		"normal": Vector2.UP,
	}
	expiry_coin.position = expiry_contact.position
	expiry_coin._handle_landed_can_contact(Vector2(0.0, 100.0), expiry_contact)
	expiry_coin.time_remaining = 0.001
	expiry_coin._physics_process(FIXED_STEP)
	check(
		expiry_coin.is_resolved()
		and expiry_coin.supported_can_id() == -1
		and director._supported_can_claims.is_empty(),
		"Supported lifetime expiry resolves normally and releases the support claim"
	)
	conveyor.queue_free()
	await process_frame


func _test_multi_event_fallback_contract() -> void:
	var conveyor := await _make_fixture(7005)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		director._ballistic_launch_delay_plan(2) == PackedFloat32Array([0.0, 0.0])
		and director._ballistic_launch_delay_plan(3) == PackedFloat32Array([0.0, 0.10, 0.20]),
		"Consolidated hierarchy tries simultaneous doubles and a complete triple stagger first"
	)
	var simultaneous := PackedFloat32Array([0.15, 0.15])
	var short_delays := PackedFloat32Array([0.15, 0.27])
	var origins := [
		director._refund_chute_origin_for_member(2, 0, simultaneous),
		director._refund_chute_origin_for_member(2, 1, simultaneous),
	]
	var found_short_stagger_case := false
	for first_archetype in range(3):
		for second_archetype in range(3):
			for first_x in [400.0, 460.0, 520.0, 580.0]:
				for second_x in [640.0, 700.0, 760.0, 820.0]:
					var first := director._build_ballistic_plan(
						Vector2(first_x, director._ballistic_contact_y()),
						first_archetype, 2.5, simultaneous[0], false, origins[0]
					)
					var second := director._build_ballistic_plan(
						Vector2(second_x, director._ballistic_contact_y()),
						second_archetype, 2.5, simultaneous[1], false, origins[1]
					)
					var original_valid := (
						director._ballistic_trajectory_separation_is_valid(second, [first])
						and director._ballistic_post_contact_separation_is_valid(second, [first])
					)
					var retimed_second := second.duplicate(true)
					retimed_second.launch_delay = short_delays[1]
					var retimed_valid := (
						director._ballistic_trajectory_separation_is_valid(retimed_second, [first])
						and director._ballistic_post_contact_separation_is_valid(retimed_second, [first])
					)
					if not original_valid and retimed_valid:
						found_short_stagger_case = true
						break
				if found_short_stagger_case:
					break
			if found_short_stagger_case:
				break
		if found_short_stagger_case:
			break
	check(
		found_short_stagger_case,
		"A controlled mouth-conflict pair is rejected simultaneously and accepted at the 120 ms fallback without moving its landings"
	)
	conveyor.queue_free()
	await process_frame


func _test_natural_integrity_performance_and_frozen_d3() -> void:
	var selected_doubles := 0
	var full_doubles := 0
	var selected_triples := 0
	var full_triples := 0
	var maximum_planning_ms := 0.0
	var d3_ok := true
	for seed in TEST_SEEDS:
		var shell := MOTION_SCENE.instantiate() as MotionExperimentShell
		shell.refund_chute_enabled = true
		shell.local_instrumentation_enabled = false
		root.add_child(shell)
		await process_frame
		var conveyor := shell.conveyor
		var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		var d3 := shell.background_drop_director
		director.ballistic_coin_events_enabled = true
		director.ballistic_abundance_enabled = true
		director.ballistic_integrity_enabled = true
		director.refund_chute_enabled = true
		director.refund_system_enabled = true
		director.static_teaching_coin_enabled = true
		director.performance_profiling_enabled = true
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
		var integrity := director.ballistic_integrity_summary()
		var performance := director.performance_profile_summary()
		selected_doubles += int(integrity.selected_doubles)
		full_doubles += int(integrity.full_doubles)
		selected_triples += int(integrity.selected_triples)
		full_triples += int(integrity.full_triples)
		maximum_planning_ms = maxf(maximum_planning_ms, float(performance.maximum_planning_ms))
		d3_ok = d3_ok and d3.released_event_count() == 6 and d3.longest_successful_warning_gap() <= 8.80
		print("VM070_SEED ", seed, " integrity=", integrity, " performance=", performance)
		shell.queue_free()
		await process_frame
	var double_rate := float(full_doubles) / float(maxi(selected_doubles, 1))
	check(
		double_rate >= 0.50 and full_triples > 0,
		"Five deterministic rounds retain at least 50% full doubles and nonzero complete triples"
	)
	check(d3_ok, "All deterministic rounds preserve the frozen six-event D3 schedule")
	check(
		maximum_planning_ms < 100.0,
		"Bounded fallback planning produces no 100–200 ms planning spike"
	)
	print(
		"VM070_AGGREGATE selected_2=%d full_2=%d rate_2=%.3f selected_3=%d full_3=%d max_planning_ms=%.3f"
		% [selected_doubles, full_doubles, double_rate, selected_triples, full_triples, maximum_planning_ms]
	)


func _test_touch_control_layout_regression() -> void:
	var touch := StandardTouchControls.new()
	root.add_child(touch)
	touch.touch_available = true
	touch.size = Vector2(1152.0, 648.0)
	touch.set_game_active(true)
	await process_frame
	touch.configure_viewport(Vector2(1152,648),Rect2(0,0,1152,648),Vector2(1152,648),1.0)
	var landscape_distinct := (
		touch.buttons.size() == 3
		and touch.buttons.all(func(button: TouchScreenButton) -> bool: return button.visible)
		and not touch._rotate.visible
	)
	touch.configure_viewport(Vector2(648,1152),Rect2(0,0,648,1152),Vector2(648,1152),3.0)
	var portrait_guidance := touch._rotate.visible
	touch.set_game_active(false)
	var released := touch.buttons.all(
		func(button: TouchScreenButton) -> bool:
			return not button.visible and not button.is_pressed()
	)
	check(landscape_distinct, "Landscape touch layout preserves separate left, right, and jump controls")
	check(portrait_guidance, "Portrait layout displays rotate guidance rather than overlapping controls")
	check(released, "Death/menu/retry deactivation hides controls and releases every touch action")
	touch.queue_free()
	await process_frame


func _make_fixture(seed: int) -> ConveyorPrototype:
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
	root.add_child(conveyor)
	await physics_frame
	conveyor.set_physics_process(false)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director.set_process(false)
	conveyor.player.global_position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	return conveyor


func _make_support_coin(
	director: CollectibleDirector,
	conveyor: ConveyorPrototype,
	seed: int
) -> ConveyorCollectible:
	var coin := COIN_SCENE.instantiate() as ConveyorCollectible
	director.add_child(coin)
	coin.configure(2.5, conveyor.conveyor_speed, Vector2(24.0, 24.0), 0, seed, 0.70)
	coin.configure_ballistic(
		Vector2(620.0, 420.0), Vector2(620.0, 572.0), Vector2.ZERO,
		0.55, director.ballistic_gravity, 2.5, conveyor.conveyor_speed,
		director.ballistic_bounce_restitutions
	)
	coin.configure_landed_can_collision(
		Callable(self, "_landed_can_rects"), Vector2(260.0, 960.0), 2,
		0.34, 0.35, 180.0, 70.0, Vector2(32.0, 32.0), 260.0,
		Callable(director, "_claim_landed_can_support"),
		Callable(director, "_release_landed_can_support")
	)
	return coin


func _landed_can_rects() -> Array[Dictionary]:
	return _test_can_rects
