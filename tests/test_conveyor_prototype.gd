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
	await _test_independent_scene_loading_and_configuration()
	await _test_belt_scroll_and_control_band()
	await _test_warning_drop_and_contact_states()
	await _test_moving_platform_support_and_jump()
	await _test_natural_stationary_pressure_and_overlapping_lifecycle()
	await _test_offscreen_cleanup_and_left_failure()
	await _test_restart_cleanup()
	_release_movement_actions()
	print("CONVEYOR_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_independent_scene_loading_and_configuration() -> void:
	var arena_scene := load(ARENA_SCENE_PATH) as PackedScene
	var conveyor_scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	_check(arena_scene != null, "Prototype A scene still loads independently")
	_check(conveyor_scene != null, "Prototype B scene loads independently")

	var arena := arena_scene.instantiate() as CompactArena
	var conveyor := conveyor_scene.instantiate() as ConveyorPrototype
	root.add_child(arena)
	root.add_child(conveyor)
	await physics_frame

	_check(
		ProjectSettings.get_setting("application/run/main_scene")
			== "res://scenes/presentation/standard_session.tscn",
		"F5 enters Standard presentation while both prototypes remain loadable"
	)
	_check(
		conveyor.player.maximum_speed == 300.0
		and conveyor.player.gravity == 2400.0
		and conveyor.player.jump_velocity == -700.0
		and conveyor.player.coyote_time == 0.10
		and conveyor.player.jump_buffering == 0.12,
		"Prototype B uses the locked VM-0.1.2 movement values"
	)
	_check(
		is_equal_approx(conveyor.conveyor_speed, 140.0),
		"Initial conveyor speed is 140 pixels per second"
	)
	_check(
		conveyor.control_band_left == 280.0
		and conveyor.control_band_right == 760.0,
		"Initial player-center control band is x=280 through x=760"
	)
	_check(
		conveyor.initial_warning_delay == 1.00
		and conveyor.telegraph_duration == 0.45
		and conveyor.target_fall_duration == 0.55
		and conveyor.pattern_cooldown_at(0.0) == 2.20,
		"Initial warning, telegraph, fall, and director cooldown are separate"
	)
	_check(
		conveyor.maximum_concurrent_falling_cans == 1
		and conveyor.drop_lane_is_geometrically_valid(0)
		and conveyor.drop_lane_is_geometrically_valid(1)
		and conveyor.drop_lane_is_geometrically_valid(2),
		"Single-drop cap and all natural lanes fit the conveyor right of the control band"
	)
	_check(
		conveyor.landed_can_is_jump_clearable(),
		"Locked normal jump height exceeds the landed-can height"
	)
	_check(
		conveyor.first_warning_time_estimate() >= 1.0
		and conveyor.first_warning_time_estimate() <= 2.0
		and conveyor.first_impact_time_estimate() >= 1.8
		and conveyor.first_impact_time_estimate() <= 2.1
		and conveyor.passive_failure_time_estimate() >= 3.0
		and conveyor.passive_failure_time_estimate() <= 4.0,
		"Configured first warning, impact, and passive-response estimates meet the approved windows"
	)

	arena.queue_free()
	conveyor.queue_free()
	await process_frame


func _test_belt_scroll_and_control_band() -> void:
	var conveyor := await _make_conveyor(true)
	var stripe := conveyor.get_node("ConveyorBelt/Stripes/Stripe3") as Polygon2D
	var stripe_start_x := stripe.position.x
	conveyor._scroll_belt_presentation(0.25)
	_check(
		absf(
			stripe.position.x
			- (stripe_start_x - conveyor.conveyor_speed * 0.25)
		) <= FLOAT_TOLERANCE,
		"Conveyor presentation scrolls left at the configured world speed"
	)
	for child in conveyor.get_node("ConveyorBelt/Stripes").get_children():
		_check(
			child.position.x >= conveyor.belt_left_x
			and child.position.x <= conveyor.belt_right_x,
			"Wrapped belt stripe remains inside the visible conveyor span"
		)

	conveyor.left_failure_enabled = false
	conveyor.player.position.x = 100.0
	conveyor._enforce_control_band()
	_check(
		conveyor.player.position.x
			== conveyor.conveyor_support_left_x + _player_half_width(),
		"Failure-disabled tests constrain the player at the last supported center"
	)
	conveyor.player.position.x = 1000.0
	conveyor._enforce_control_band()
	_check(
		conveyor.player.position.x == conveyor.control_band_right,
		"Player center is constrained at the right control-band bound"
	)
	_free_conveyor(conveyor)


func _test_warning_drop_and_contact_states() -> void:
	var conveyor := await _make_conveyor(true)
	conveyor.force_warning_for_test(1)
	_check(conveyor.warning_is_visible(), "A forced single drop shows its warning")
	_check(conveyor.warning_is_aligned(), "Warning and chute align to the drop lane")
	var product := conveyor.force_drop_for_test(1)
	_check(product != null, "Single-can drop instantiates a conveyor product")
	_check(
		conveyor.falling_product_count() == 1,
		"Single scheduler creates one falling can"
	)
	_check(product.is_falling_lethal(), "Falling conveyor can is lethal")
	_check(
		conveyor.chute_is_visible()
		and conveyor.chute_is_aligned_with_active_drop(),
		"Chute remains visible and aligned throughout the falling state"
	)

	product.position.x = conveyor.player.position.x
	product.position.y = conveyor.player.position.y
	await physics_frame
	await physics_frame
	_check(conveyor.is_dead, "Player contact with a falling conveyor can is lethal")
	_free_conveyor(conveyor)

	conveyor = await _make_conveyor(true)
	conveyor.product_spawn_y = conveyor.floor_y - conveyor.product_size.y * 0.5 - 1.0
	conveyor.target_fall_duration = 0.02
	product = conveyor.force_drop_for_test(0)
	await _wait_for_landed(product)
	_check(product.is_landed(), "Valid conveyor-floor contact enters landed state")
	_check(
		not product.is_falling_lethal(),
		"Landed conveyor contact is non-lethal"
	)
	_check(product.is_landed_solid(), "Landed conveyor can is solid")
	_check(
		product.intended_platform_velocity()
			== Vector2(-conveyor.conveyor_speed, 0.0),
		"Landed can reports the configured leftward platform velocity"
	)
	var first_landed_x := product.conveyor_center_x()
	await _wait_physics_frames(30)
	var measured_speed := (
		(first_landed_x - product.conveyor_center_x())
		* Engine.physics_ticks_per_second
		/ 30.0
	)
	_check(
		absf(measured_speed - conveyor.conveyor_speed) <= 2.0,
		"Landed can moves at the intended conveyor speed"
	)

	conveyor.product_spawn_y = 176.0
	conveyor.target_fall_duration = 0.65
	var second_product := conveyor.force_drop_for_test(1)
	_check(
		conveyor.landed_product_count() == 1
		and conveyor.falling_product_count() == 1
		and second_product.is_falling(),
		"A new drop can begin while an earlier landed can remains active"
	)
	_free_conveyor(conveyor)


func _test_moving_platform_support_and_jump() -> void:
	var conveyor := await _make_conveyor(true)
	conveyor.drop_lane_positions = PackedFloat32Array([520.0])
	conveyor.player.position.x = 700.0
	await physics_frame
	conveyor.product_spawn_y = conveyor.floor_y - conveyor.product_size.y * 0.5 - 1.0
	conveyor.target_fall_duration = 0.02
	var product := conveyor.force_drop_for_test(0)
	await _wait_for_landed(product)

	conveyor.player.position = Vector2(
		product.conveyor_center_x(),
		product.position.y
			- conveyor.landed_product_size.y * 0.5
			- _player_half_height()
			- 1.0
	)
	conveyor.player.velocity = Vector2.ZERO
	await _wait_physics_frames(8)
	_check(
		conveyor.player.is_on_floor(),
		"Player stands stably on top of a moving landed can"
	)
	var player_start_x := conveyor.player.position.x
	var product_start_x := product.conveyor_center_x()
	await _wait_physics_frames(20)
	var player_displacement := conveyor.player.position.x - player_start_x
	var product_displacement := product.conveyor_center_x() - product_start_x
	_check(
		player_displacement < -20.0
		and absf(player_displacement - product_displacement) <= 5.0,
		"Moving landed can consistently carries a standing player"
	)

	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame
	_check(
		conveyor.player.velocity.y < 0.0,
		"Locked normal jump launches from the moving landed can"
	)
	_release_movement_actions()
	_free_conveyor(conveyor)


func _test_natural_stationary_pressure_and_overlapping_lifecycle() -> void:
	var conveyor := await _make_conveyor(false)
	conveyor.left_failure_enabled = false
	var observation := {
		"warning": -1.0,
		"impact": -1.0,
	}
	var saw_new_drop_while_landed := false
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
	var maximum_frames := ceili(8.0 * Engine.physics_ticks_per_second)
	for _frame in range(maximum_frames):
		await physics_frame
		if (
			conveyor.landed_product_count() > 0
			and conveyor.falling_product_count() > 0
		):
			saw_new_drop_while_landed = true
		if saw_new_drop_while_landed and observation.impact >= 0.0:
			break

	_check(
		observation.warning >= 0.9 and observation.warning <= 1.1,
		"Natural first warning begins inside the approved early window"
	)
	_check(
		observation.impact >= 1.8 and observation.impact <= 2.1,
		"Natural first can reaches the belt inside the approved early window"
	)
	_check(
		saw_new_drop_while_landed,
		"Natural scheduling continues while a landed can travels"
	)
	print(
		"CONVEYOR_NATURAL_METRICS warning=%.3fs impact=%.3fs"
		% [observation.warning, observation.impact]
	)
	_free_conveyor(conveyor)


func _test_offscreen_cleanup_and_left_failure() -> void:
	var conveyor := await _make_conveyor(true)
	conveyor.product_spawn_y = conveyor.floor_y - conveyor.product_size.y * 0.5 - 1.0
	conveyor.target_fall_duration = 0.02
	var product := conveyor.force_drop_for_test(0)
	await _wait_for_landed(product)
	product.cleanup_left_x = product.conveyor_center_x() + 100.0
	await physics_frame
	await process_frame
	_check(
		conveyor.active_product_count() == 0,
		"Landed can is removed after fully leaving the left playable edge"
	)

	conveyor.left_failure_enabled = true
	conveyor.player.position = Vector2(80.0, 620.0)
	await _wait_physics_frames(3)
	_check(
		conveyor.is_dead
		and conveyor.get_node("HUD/DeathMessage").visible,
		"Explicit off-belt kill region triggers the death flow"
	)
	_free_conveyor(conveyor)


func _test_restart_cleanup() -> void:
	var scene_change_error := change_scene_to_file(CONVEYOR_SCENE_PATH)
	_check(scene_change_error == OK, "Restart test loads Prototype B as current scene")
	await scene_changed
	await physics_frame
	var conveyor := current_scene as ConveyorPrototype
	conveyor.force_pattern_for_test(
		ConveyorPrototype.PatternType.SWEEPER_ONLY
	)
	conveyor.force_warning_for_test(0)
	var product := conveyor.force_drop_for_test(0)
	_check(
		conveyor.has_pending_pattern_events(),
		"Restart fixture contains a pending sweeper cue"
	)
	conveyor.survival_time = 4.0
	var previous_instance_id := conveyor.get_instance_id()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	conveyor._unhandled_input(restart_event)
	await scene_changed
	await physics_frame
	var restarted := current_scene as ConveyorPrototype
	_check(
		restarted != null
		and restarted.get_instance_id() != previous_instance_id,
		"Player-triggered restart reloads Prototype B"
	)
	_check(
		restarted.current_warning_lane() == -1
		and restarted.falling_product_count() == 0
		and restarted.landed_product_count() == 0
		and restarted.active_sweeper_count() == 0
		and restarted.active_pattern_type() == -1
		and restarted.reserved_pattern_type() == -1
		and not restarted.has_pending_pattern_events()
		and restarted.survival_time < 0.1
		and not restarted.is_dead,
		"Restart clears warnings, chute, cans, sweepers, patterns, scroll session, and timer"
	)
	_check(
		not is_instance_valid(product),
		"Restart frees products from the previous conveyor session"
	)
	restarted.player.position = Vector2(
		restarted.conveyor_support_left_x + _player_half_width(),
		552.0
	)
	await _wait_physics_frames(3)
	_check(
		not restarted.is_dead
		and restarted.belt_support_velocity()
			== restarted.conveyor_support_velocity(),
		"Restart restores non-lethal belt edge and conveyor support state"
	)


func _make_conveyor(disable_scheduler: bool) -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	if disable_scheduler:
		conveyor.initial_warning_delay = 999.0
	root.add_child(conveyor)
	await physics_frame
	return conveyor


func _free_conveyor(conveyor: ConveyorPrototype) -> void:
	if is_instance_valid(conveyor):
		conveyor.queue_free()
	await process_frame
	_release_movement_actions()


func _wait_for_landed(product: ConveyorProduct) -> void:
	for _frame in range(30):
		if not is_instance_valid(product) or product.is_landed():
			return
		await physics_frame


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _release_movement_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")


func _player_half_height() -> float:
	return 24.0


func _player_half_width() -> float:
	return 16.0
