extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const ARENA_SCENE_PATH := "res://scenes/prototypes/arena.tscn"
const FLOAT_TOLERANCE := 0.05

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	await _test_round_countdown_death_and_completion()
	await _test_band_configuration_and_distribution()
	await _test_ground_and_low_air_collection()
	await _test_coin_motion_score_and_expiration()
	await _test_active_and_reserved_hazard_validation()
	await _test_restart_and_endless_recovery()
	await _test_prototype_a_unchanged()
	print("FIXED_ROUND_REFUND_COIN_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_round_countdown_death_and_completion() -> void:
	var conveyor := await _make_conveyor(true)
	var round_controller := _round_controller(conveyor)
	var initial_remaining := round_controller.round_time_remaining
	_check(
		round_controller.round_duration == 60.0
		and round_controller.round_time_remaining > 59.9
		and round_controller.is_running(),
		"Round begins from the configured 60-second duration"
	)
	_check(
		conveyor.get_node("HUD/Timer").text == "00:60",
		"Initial timer uses the approved stable countdown format"
	)
	round_controller._process(0.25)
	_check(
		absf(round_controller.round_time_remaining - (initial_remaining - 0.25)) <= 0.0001,
		"Countdown decreases by the supplied elapsed time"
	)
	conveyor._kill_player()
	var frozen_death_time := round_controller.round_time_remaining
	round_controller._process(1.0)
	_check(
		round_controller.ended_by_death()
		and round_controller.round_time_remaining == frozen_death_time,
		"Death ends the round immediately and freezes remaining time"
	)
	_check(
		conveyor.get_node("HUD/DeathMessage").text.contains("COINS COLLECTED: 0")
		and conveyor.get_node("HUD/DeathMessage").text.contains("SHUTDOWN:"),
		"Death result reports coins and time remaining"
	)
	_free_conveyor(conveyor)

	conveyor = await _make_conveyor(true)
	round_controller = _round_controller(conveyor)
	var director := _director(conveyor)
	director.score = 4
	director._update_score_label()
	var product := conveyor.force_drop_for_test(0)
	conveyor.sweeper_entry_cue_duration = 0.0
	conveyor.force_pattern_for_test(ConveyorPrototype.PatternType.SWEEPER_ONLY)
	var sweeper := (
		conveyor.active_sweepers()[0]
		if conveyor.active_sweeper_count() > 0
		else null
	)
	conveyor.player.position = Vector2(760.0, 552.0)
	director.candidate_x_positions = PackedFloat32Array([600.0])
	director.try_spawn_band_for_test(CollectibleDirector.PlacementBand.GROUND)
	var coin := director.active_collectible()
	round_controller.force_time_remaining_for_test(0.01)
	round_controller._process(0.02)
	_check(
		round_controller.is_complete()
		and round_controller.round_time_remaining == 0.0
		and round_controller.completion_count == 1,
		"Reaching zero completes the round exactly once"
	)
	round_controller._process(1.0)
	_check(
		round_controller.completion_count == 1,
		"Completed round cannot complete a second time"
	)
	_check(
		conveyor.is_round_complete
		and conveyor.gameplay_is_stopped()
		and not conveyor.player.is_physics_processing()
		and conveyor.belt_support_velocity() == Vector2.ZERO,
		"Completion safely stops player and conveyor gameplay"
	)
	_check(
		product != null
		and product.state == FallingProduct.ProductState.STOPPED
		and sweeper != null
		and not sweeper.is_physics_processing()
		and coin != null
		and not coin.is_physics_processing()
		and not conveyor.warning_is_visible()
		and not conveyor.has_pending_pattern_events(),
		"Completion stops cans, Sweepers, coins, warnings, and pending patterns"
	)
	_check(
		conveyor.get_node("HUD/DeathMessage").text
			== "MACHINE SHUTDOWN\nCOINS COLLECTED: 4\nPRESS R TO RESTART",
		"Successful completion shows the approved result text"
	)
	_free_conveyor(conveyor)


func _test_band_configuration_and_distribution() -> void:
	var conveyor := await _make_conveyor(true)
	var director := _director(conveyor)
	_check(
		director.ground_band_center_y_range == Vector2(548.0, 552.0)
		and director.low_air_band_center_y_range == Vector2(488.0, 500.0),
		"Ground and low-air center ranges are independently configurable"
	)
	_check(
		is_equal_approx(director.ground_probability_after_first, 0.50),
		"Subsequent band distribution begins at 50 percent ground"
	)
	var sequence := director.preview_band_sequence_for_test(24)
	_check(
		sequence[0] == CollectibleDirector.PlacementBand.GROUND,
		"First Refund Coin always uses the ground band"
	)
	_check(
		sequence.has(CollectibleDirector.PlacementBand.GROUND)
		and sequence.has(CollectibleDirector.PlacementBand.LOW_AIR),
		"Later deterministic selection produces both placement bands"
	)
	var low_air_y := director.band_center_y(
		CollectibleDirector.PlacementBand.LOW_AIR
	)
	var intervals := director.normal_jump_collection_intervals(low_air_y)
	_check(
		director.normal_jump_collection_margin(low_air_y) >= 48.0
		and intervals.size() == 2
		and intervals[0].y - intervals[0].x >= 0.10,
		"Normal jump reaches the low-air band with margin and a non-apex window"
	)
	print(
		"REFUND_COIN_GEOMETRY ground_center_range=%s low_air_center_range=%s jump_margin=%.3f ascent_window=%s"
		% [
			director.ground_band_center_y_range,
			director.low_air_band_center_y_range,
			director.normal_jump_collection_margin(low_air_y),
			intervals[0],
		]
	)
	_free_conveyor(conveyor)


func _test_ground_and_low_air_collection() -> void:
	var conveyor := await _make_conveyor(true)
	var director := _director(conveyor)
	conveyor.player.position = Vector2(600.0, 552.0)
	director.candidate_x_positions = PackedFloat32Array([600.0])
	_check(
		director.try_spawn_band_for_test(
			CollectibleDirector.PlacementBand.GROUND
		),
		"Ground Refund Coin spawns in a valid empty state"
	)
	var ground_coin := director.active_collectible()
	_check(
		director.score == 0
		and director.player_spawn_rejection_reason_for_test(ground_coin.global_position).is_empty(),
		"Ground Refund Coin appears outside the player safety buffer before collection"
	)
	conveyor.player.global_position = ground_coin.global_position
	await _wait_physics_frames(3)
	_check(
		director.score == 1,
		"Ground Refund Coin can be collected without jumping"
	)
	_free_conveyor(conveyor)

	conveyor = await _make_conveyor(true)
	director = _director(conveyor)
	conveyor.player.position = Vector2(600.0, 552.0)
	director.candidate_x_positions = PackedFloat32Array([600.0])
	_check(
		director.try_spawn_band_for_test(
			CollectibleDirector.PlacementBand.LOW_AIR
		),
		"Low-air Refund Coin spawns when its path is valid"
	)
	await _wait_physics_frames(3)
	_check(
		director.score == 0
		and director.active_collectible_count() == 1,
		"Simply remaining grounded cannot collect the low-air coin"
	)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for _frame in range(30):
		await physics_frame
		if director.score == 1:
			break
	_check(
		director.score == 1,
		"Locked normal single jump collects the low-air coin"
	)
	_free_conveyor(conveyor)


func _test_coin_motion_score_and_expiration() -> void:
	var conveyor := await _make_conveyor(true)
	var director := _director(conveyor)
	var round_controller := _round_controller(conveyor)
	conveyor.player.position = Vector2(760.0, 552.0)
	director.candidate_x_positions = PackedFloat32Array([600.0])
	_check(director.try_spawn_for_test(), "Refund Coin fixture spawns")
	var coin := director.active_collectible()
	var start_x := coin.position.x
	await _wait_physics_frames(12)
	var measured_speed := (
		(start_x - coin.position.x) * Engine.physics_ticks_per_second / 12.0
	)
	_check(
		absf(measured_speed - conveyor.conveyor_speed) <= 2.0,
		"Refund Coin moves at the conveyor speed"
	)
	_check(
		coin.is_non_solid() and not conveyor.is_dead,
		"Refund Coin remains non-solid and cannot push or carry the player"
	)
	var timer_before_expiration := round_controller.round_time_remaining
	coin.monitoring = false
	coin.time_remaining = 0.05
	await _wait_physics_frames(8)
	_check(
		director.score == 0
		and absf(round_controller.round_time_remaining - timer_before_expiration)
			<= 0.0001,
		"Expiration changes neither score nor shutdown time"
	)
	_free_conveyor(conveyor)

	conveyor = await _make_conveyor(true)
	director = _director(conveyor)
	round_controller = _round_controller(conveyor)
	conveyor.player.position = Vector2(600.0, 552.0)
	director.candidate_x_positions = PackedFloat32Array([600.0])
	var timer_before_collection := round_controller.round_time_remaining
	_check(director.try_spawn_for_test(), "Collection timer fixture spawns")
	var collection_coin := director.active_collectible()
	_check(director.score == 0, "Collection timer fixture does not score on its spawn frame")
	conveyor.player.global_position = collection_coin.global_position
	await _wait_physics_frames(3)
	_check(
		director.score == 1
		and absf(round_controller.round_time_remaining - timer_before_collection)
			<= 0.0001,
		"Collection increments exactly once without adding shutdown time"
	)
	await _wait_physics_frames(3)
	_check(director.score == 1, "Collected Refund Coin cannot score twice")
	_free_conveyor(conveyor)


func _test_active_and_reserved_hazard_validation() -> void:
	var conveyor := await _make_conveyor(true)
	var director := _director(conveyor)
	var low_air_candidate := Vector2(
		600.0,
		director.band_center_y(CollectibleDirector.PlacementBand.LOW_AIR)
	)
	conveyor.force_pattern_for_test(ConveyorPrototype.PatternType.SWEEPER_ONLY)
	_check(
		director.try_spawn_band_for_test(
			CollectibleDirector.PlacementBand.LOW_AIR
		)
		and director.candidate_is_valid(
			low_air_candidate,
			CollectibleDirector.PlacementBand.LOW_AIR
		),
		"A planned Sweeper no longer starves an otherwise valid low-air offer"
	)
	_free_conveyor(conveyor)

	conveyor = await _make_conveyor(true)
	director = _director(conveyor)
	conveyor.drop_lane_positions = PackedFloat32Array([600.0])
	conveyor.maximum_concurrent_falling_cans = 0
	_check(
		not conveyor.force_pattern_for_test(
			ConveyorPrototype.PatternType.CAN_ONLY
		)
		and conveyor.reserved_pattern_type()
			== ConveyorPrototype.PatternType.CAN_ONLY,
		"Can pattern remains reserved while its active cap is unavailable"
	)
	var ground_candidate := Vector2(
		600.0,
		director.band_center_y(CollectibleDirector.PlacementBand.GROUND)
	)
	_check(
		not director.candidate_is_valid(
			ground_candidate,
			CollectibleDirector.PlacementBand.GROUND
		),
		"Placement validation includes reserved falling-can lanes"
	)
	_free_conveyor(conveyor)


func _test_restart_and_endless_recovery() -> void:
	var change_error := change_scene_to_file(CONVEYOR_SCENE_PATH)
	_check(change_error == OK, "Restart fixture loads the fixed-round scene")
	await scene_changed
	await physics_frame
	var conveyor := current_scene as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	var director := _director(conveyor)
	var round_controller := _round_controller(conveyor)
	round_controller.set_process(false)
	conveyor.player.position = Vector2(600.0, 552.0)
	director.candidate_x_positions = PackedFloat32Array([600.0])
	director.try_spawn_template_for_test(
		CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK,
		4
	)
	director.score = 3
	round_controller.force_time_remaining_for_test(20.0)
	var old_coin := director.active_collectible()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	conveyor._unhandled_input(restart_event)
	await scene_changed
	await physics_frame
	var restarted := current_scene as ConveyorPrototype
	_round_controller(restarted).set_process(false)
	_check(
		_round_controller(restarted).round_time_remaining > 59.9
		and _round_controller(restarted).is_running()
		and restarted.get_node("HUD/Timer").text == "00:60"
		and restarted.get_node("HUD/Timer").scale == Vector2.ONE
		and _director(restarted).score == 0
		and _director(restarted).active_collectible_count() == 0
		and restarted.falling_product_count() == 0
		and restarted.active_sweeper_count() == 0,
		"Restart resets timer text, visuals, score, coin, hazards, and round state"
	)
	_check(not is_instance_valid(old_coin), "Restart frees the previous Refund Coin")

	var endless := await _make_conveyor(false)
	var endless_round := _round_controller(endless)
	_check(
		not endless_round.fixed_round_enabled
		and not endless.external_timer_display_enabled,
		"Exported development toggle restores endless survival presentation"
	)
	endless.survival_time = 61.0
	endless_round._process(5.0)
	_check(
		not endless.is_round_complete
		and endless_round.is_running(),
		"Endless development configuration has no countdown completion"
	)
	_free_conveyor(endless)


func _test_prototype_a_unchanged() -> void:
	var arena_scene := load(ARENA_SCENE_PATH) as PackedScene
	var arena := arena_scene.instantiate() as CompactArena
	root.add_child(arena)
	await physics_frame
	_check(
		not arena.has_node("RoundController")
		and not arena.has_node("CollectibleDirector"),
		"Prototype A remains outside the round and Refund Coin experiment"
	)
	_check(
		arena.player.maximum_speed == 300.0
		and arena.player.gravity == 2400.0
		and arena.player.jump_velocity == -700.0,
		"Prototype A retains the locked shared movement controller"
	)
	arena.queue_free()
	await process_frame


func _make_conveyor(fixed_round: bool) -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	var round_controller := conveyor.get_node("RoundController") as FixedRoundController
	round_controller.fixed_round_enabled = fixed_round
	round_controller.set_process(false)
	root.add_child(conveyor)
	await physics_frame
	round_controller.set_process(false)
	return conveyor


func _director(conveyor: ConveyorPrototype) -> CollectibleDirector:
	return conveyor.get_node("CollectibleDirector") as CollectibleDirector


func _round_controller(conveyor: ConveyorPrototype) -> FixedRoundController:
	return conveyor.get_node("RoundController") as FixedRoundController


func _free_conveyor(conveyor: ConveyorPrototype) -> void:
	if is_instance_valid(conveyor) and conveyor != current_scene:
		conveyor.queue_free()
	await process_frame
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame
