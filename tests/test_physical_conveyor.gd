extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const ARENA_SCENE_PATH := "res://scenes/prototypes/arena.tscn"
const EXPECTED_CONVEYOR_SPEED := 140.0
const EXPECTED_RELATIVE_SPEED := 300.0
const SPEED_TOLERANCE := 5.0

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
	await _test_belt_relative_world_speeds()
	await _test_rightward_recovery_and_passive_failure()
	await _test_landed_can_support_and_transitions()
	await _test_belt_jump_inherits_support_once()
	await _test_can_jump_inherits_support_once_and_tracks_can()
	await _test_prototype_a_zero_support_regression()
	await _test_natural_early_engagement_timings()
	await _test_restart_resets_support_state()
	_release_actions()
	print("PHYSICAL_CONVEYOR_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_belt_relative_world_speeds() -> void:
	var no_input := await _measure_belt_speed("")
	var right_input := await _measure_belt_speed("move_right")
	var left_input := await _measure_belt_speed("move_left")

	_check(
		absf(no_input - -EXPECTED_CONVEYOR_SPEED) <= SPEED_TOLERANCE,
		"No-input grounded player moves left at conveyor speed"
	)
	_check(
		absf(
			right_input
			- (EXPECTED_RELATIVE_SPEED - EXPECTED_CONVEYOR_SPEED)
		) <= SPEED_TOLERANCE,
		"Right input produces support velocity plus rightward relative movement"
	)
	_check(
		absf(
			left_input
			- (-EXPECTED_RELATIVE_SPEED - EXPECTED_CONVEYOR_SPEED)
		) <= SPEED_TOLERANCE,
		"Left input combines player-relative and conveyor motion"
	)
	print(
		"PHYSICAL_CONVEYOR_SPEED_METRICS no_input=%.3f right=%.3f left=%.3f"
		% [no_input, right_input, left_input]
	)


func _test_rightward_recovery_and_passive_failure() -> void:
	var conveyor := await _make_conveyor(true, false)
	_check(
		conveyor.can_recover_rightward()
		and conveyor.maximum_relative_player_speed() > conveyor.conveyor_speed,
		"Relative maximum speed exceeds conveyor speed"
	)
	conveyor.player.position.x = conveyor.control_band_left + 2.0
	await physics_frame
	var start_x := conveyor.player.position.x
	Input.action_press("move_right")
	await _wait_physics_frames(12)
	Input.action_release("move_right")
	_check(
		conveyor.player.position.x > start_x + 25.0,
		"Right input recovers screen position from the left edge of the valid band"
	)
	await _free_conveyor(conveyor)

	conveyor = await _make_conveyor(true, true)
	var failure_time := -1.0
	for _frame in range(240):
		await physics_frame
		if conveyor.is_dead:
			failure_time = conveyor.survival_time
			break
	_check(
		failure_time >= 3.0 and failure_time <= 4.0,
		"Passive conveyor drift reaches the explicit off-belt region deterministically"
	)
	print("PHYSICAL_CONVEYOR_FAILURE_TIME %.3fs" % failure_time)
	await _free_conveyor(conveyor)


func _test_landed_can_support_and_transitions() -> void:
	var setup := await _make_player_on_can()
	var conveyor := setup.conveyor as ConveyorPrototype
	var product := setup.product as ConveyorProduct
	_check(
		conveyor.player.is_on_floor(),
		"Player stands stably on the moving can"
	)
	_check(
		product.intended_platform_velocity() == conveyor.conveyor_support_velocity()
		and conveyor.player.get_platform_velocity()
			== conveyor.conveyor_support_velocity(),
		"Belt and landed can expose the same support velocity"
	)

	var can_speed := await _measure_current_player_world_speed(conveyor, "", 18)
	_check(
		absf(can_speed - -EXPECTED_CONVEYOR_SPEED) <= SPEED_TOLERANCE,
		"No-input player on a landed can moves at conveyor speed"
	)

	var velocity_before_clear := conveyor.player.velocity.x
	product.queue_free()
	await physics_frame
	var maximum_airborne_speed := absf(conveyor.player.velocity.x)
	for _frame in range(60):
		await physics_frame
		maximum_airborne_speed = maxf(
			maximum_airborne_speed,
			absf(conveyor.player.velocity.x)
		)
		if (
			conveyor.player.is_on_floor()
			and conveyor.player.position.y > 540.0
		):
			break
	_check(
		maximum_airborne_speed <= EXPECTED_CONVEYOR_SPEED + SPEED_TOLERANCE,
		"Can-to-belt transition does not add support velocity more than once"
	)
	_check(
		conveyor.player.get_platform_velocity()
			== conveyor.conveyor_support_velocity(),
		"Player reacquires the same support velocity after landing on the belt"
	)
	_check(
		absf(velocity_before_clear) <= SPEED_TOLERANCE,
		"Grounded player velocity remains relative before support removal"
	)
	await _free_conveyor(conveyor)


func _test_belt_jump_inherits_support_once() -> void:
	var conveyor := await _make_conveyor(true, false)
	await _wait_until_grounded(conveyor.player)
	_check(
		conveyor.player.get_platform_velocity()
			== conveyor.conveyor_support_velocity(),
		"Grounded belt reports conveyor support velocity"
	)
	var initial_vertical_values := Vector3(
		conveyor.player.gravity,
		conveyor.player.jump_velocity,
		conveyor.player.coyote_time
	)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame
	var inherited_velocity := conveyor.player.velocity.x
	_check(
		not conveyor.player.is_on_floor()
		and absf(inherited_velocity - -EXPECTED_CONVEYOR_SPEED)
			<= SPEED_TOLERANCE,
		"Jumping from the belt inherits support velocity once"
	)
	conveyor.get_node(
		"ConveyorBelt/Floor"
	).constant_linear_velocity = Vector2(-40.0, 0.0)
	await _wait_physics_frames(5)
	_check(
		absf(conveyor.player.velocity.x - inherited_velocity)
			<= SPEED_TOLERANCE,
		"Airborne player is not linked to later belt-velocity changes"
	)
	_check(
		Vector3(
			conveyor.player.gravity,
			conveyor.player.jump_velocity,
			conveyor.player.coyote_time
		) == initial_vertical_values
		and conveyor.player.jump_buffering == 0.12,
		"Physical support leaves gravity, jump velocity, coyote time, and buffering unchanged"
	)
	await _free_conveyor(conveyor)


func _test_can_jump_inherits_support_once_and_tracks_can() -> void:
	var setup := await _make_player_on_can()
	var conveyor := setup.conveyor as ConveyorPrototype
	var product := setup.product as ConveyorProduct
	var initial_relative_x := (
		conveyor.player.position.x - product.conveyor_center_x()
	)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame
	var inherited_velocity := conveyor.player.velocity.x
	_check(
		not conveyor.player.is_on_floor()
		and absf(inherited_velocity - -EXPECTED_CONVEYOR_SPEED)
			<= SPEED_TOLERANCE,
		"Jumping from a landed can inherits its support velocity once"
	)

	var landed_back_on_can := false
	for _frame in range(120):
		await physics_frame
		if (
			conveyor.player.is_on_floor()
			and conveyor.player.position.y < 530.0
		):
			landed_back_on_can = true
			break
	var final_relative_x := (
		conveyor.player.position.x - product.conveyor_center_x()
	)
	_check(
		landed_back_on_can
		and absf(final_relative_x - initial_relative_x) <= 5.0,
		"No-input jump lands at approximately the same position relative to its moving can"
	)
	await _free_conveyor(conveyor)

	setup = await _make_player_on_can()
	conveyor = setup.conveyor as ConveyorPrototype
	product = setup.product as ConveyorProduct
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame
	inherited_velocity = conveyor.player.velocity.x
	product.conveyor_speed = 40.0
	await _wait_physics_frames(5)
	_check(
		absf(conveyor.player.velocity.x - inherited_velocity)
			<= SPEED_TOLERANCE,
		"Airborne player is not linked to later landed-can velocity changes"
	)
	await _free_conveyor(conveyor)


func _test_prototype_a_zero_support_regression() -> void:
	var arena_scene := load(ARENA_SCENE_PATH) as PackedScene
	var arena := arena_scene.instantiate() as CompactArena
	arena.initial_drop_delay = 999.0
	root.add_child(arena)
	await _wait_until_grounded(arena.player)
	var start_x := arena.player.position.x
	await _wait_physics_frames(30)
	var world_speed := (
		(arena.player.position.x - start_x)
		* Engine.physics_ticks_per_second
		/ 30.0
	)
	_check(
		arena.player.get_platform_velocity() == Vector2.ZERO,
		"Prototype A floor has zero support velocity"
	)
	_check(
		absf(world_speed) <= 1.0,
		"Prototype A no-input grounded movement remains stationary"
	)
	arena.queue_free()
	await process_frame


func _test_natural_early_engagement_timings() -> void:
	var conveyor := await _make_conveyor(false, false)
	var observation := {
		"warning": -1.0,
		"impact": -1.0,
		"overlap": false,
	}
	conveyor.telegraph_started.connect(
		func(_lane_index: int, _duration: float) -> void:
			if observation.warning < 0.0:
				observation.warning = conveyor.survival_time
	)
	conveyor.conveyor_product_landed.connect(
		func(_product: ConveyorProduct) -> void:
			if observation.impact < 0.0:
				observation.impact = conveyor.survival_time
	)
	for _frame in range(480):
		await physics_frame
		if (
			conveyor.landed_product_count() > 0
			and conveyor.falling_product_count() > 0
		):
			observation.overlap = true
		if observation.impact >= 0.0 and observation.overlap:
			break
	_check(
		observation.warning >= 0.75 and observation.warning <= 1.0,
		"Actual first warning begins inside 0.75–1.0 seconds"
	)
	_check(
		observation.impact >= 1.5 and observation.impact <= 2.0,
		"Actual first can impact occurs inside 1.5–2.0 seconds"
	)
	_check(
		observation.overlap,
		"Natural cadence launches a new can while an earlier landed can remains"
	)
	print(
		"PHYSICAL_CONVEYOR_PACING_METRICS warning=%.3fs impact=%.3fs"
		% [observation.warning, observation.impact]
	)
	await _free_conveyor(conveyor)


func _test_restart_resets_support_state() -> void:
	var scene_change_error := change_scene_to_file(CONVEYOR_SCENE_PATH)
	_check(scene_change_error == OK, "Restart support test loads Prototype B")
	await scene_changed
	await physics_frame
	var conveyor := current_scene as ConveyorPrototype
	conveyor.force_warning_for_test(0)
	conveyor.force_drop_for_test(0)
	conveyor.survival_time = 4.0
	conveyor.get_node(
		"ConveyorBelt/Floor"
	).constant_linear_velocity = Vector2(-20.0, 0.0)
	var previous_id := conveyor.get_instance_id()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	conveyor._unhandled_input(restart_event)
	await scene_changed
	await physics_frame
	var restarted := current_scene as ConveyorPrototype
	_check(
		restarted != null and restarted.get_instance_id() != previous_id,
		"Restart replaces the conveyor session"
	)
	_check(
		restarted.player.position == Vector2(640.0, 552.0)
		and restarted.belt_support_velocity()
			== restarted.conveyor_support_velocity()
		and restarted.current_warning_lane() == -1
		and restarted.active_product_count() == 0
		and restarted.survival_time < 0.1,
		"Restart resets player, belt support, warnings, cans, and timer"
	)


func _measure_belt_speed(action: String) -> float:
	var conveyor := await _make_conveyor(true, false)
	await _wait_until_grounded(conveyor.player)
	var speed := await _measure_current_player_world_speed(
		conveyor,
		action,
		12
	)
	await _free_conveyor(conveyor)
	return speed


func _measure_current_player_world_speed(
	conveyor: ConveyorPrototype,
	action: String,
	frame_count: int
) -> float:
	_release_actions()
	if not action.is_empty():
		Input.action_press(action)
	await physics_frame
	var start_x := conveyor.player.position.x
	await _wait_physics_frames(frame_count)
	var elapsed := float(frame_count) / Engine.physics_ticks_per_second
	var speed := (conveyor.player.position.x - start_x) / elapsed
	_release_actions()
	return speed


func _make_conveyor(
	disable_scheduler: bool,
	failure_enabled: bool
) -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	if disable_scheduler:
		conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = failure_enabled
	root.add_child(conveyor)
	await _wait_until_grounded(conveyor.player)
	return conveyor


func _make_player_on_can() -> Dictionary:
	var conveyor := await _make_conveyor(true, false)
	conveyor.drop_lane_positions = PackedFloat32Array([520.0])
	conveyor.player.position.x = 700.0
	await physics_frame
	conveyor.product_spawn_y = (
		conveyor.floor_y - conveyor.product_size.y * 0.5 - 1.0
	)
	conveyor.target_fall_duration = 0.02
	var product := conveyor.force_drop_for_test(0)
	await _wait_for_landed(product)
	conveyor.player.position = Vector2(
		product.conveyor_center_x(),
		product.position.y
			- conveyor.landed_product_size.y * 0.5
			- 25.0
	)
	conveyor.player.velocity = Vector2.ZERO
	await _wait_physics_frames(8)
	return {
		"conveyor": conveyor,
		"product": product,
	}


func _wait_until_grounded(player: SharedPlayerController) -> void:
	for _frame in range(120):
		await physics_frame
		if player.is_on_floor():
			await physics_frame
			return


func _wait_for_landed(product: ConveyorProduct) -> void:
	for _frame in range(30):
		await physics_frame
		if not is_instance_valid(product) or product.is_landed():
			return


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _free_conveyor(conveyor: ConveyorPrototype) -> void:
	if is_instance_valid(conveyor):
		conveyor.queue_free()
	await process_frame
	_release_actions()


func _release_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
