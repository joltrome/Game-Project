extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const FLOOR_TOP := 480.0
const FLOOR_CENTER := Vector2(0.0, 500.0)
const FLOOR_SIZE := Vector2(2000.0, 40.0)
const START_X := 0.0
const DIRECTION_HOLD_FRAMES := 12
const MAX_SCENARIO_FRAMES := 180
const VELOCITY_TOLERANCE := 0.01
const POSITION_TOLERANCE := 0.1

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return

	failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	var stationary_left := await _run_jump_scenario(-1.0, 0.0, "stationary_left")
	var landing_right_to_left := await _run_jump_scenario(-1.0, 1.0, "landing_right_to_left")
	_compare_scenarios(stationary_left, landing_right_to_left, -1.0, "left")

	var stationary_right := await _run_jump_scenario(1.0, 0.0, "stationary_right")
	var landing_left_to_right := await _run_jump_scenario(1.0, -1.0, "landing_left_to_right")
	_compare_scenarios(stationary_right, landing_left_to_right, 1.0, "right")

	print("Movement reversal validation finished with %d failure(s)." % failures)
	quit(failures)


func _run_jump_scenario(takeoff_direction: float, incoming_direction: float, scenario_name: String) -> Dictionary:
	var world := Node2D.new()
	world.name = "TestWorld_%s" % scenario_name
	root.add_child(world)

	var floor := StaticBody2D.new()
	floor.position = FLOOR_CENTER
	var floor_collision := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = FLOOR_SIZE
	floor_collision.shape = floor_shape
	floor.add_child(floor_collision)
	world.add_child(floor)

	var player := PLAYER_SCENE.instantiate() as SharedPlayerController
	world.add_child(player)

	_release_movement_actions()
	if is_zero_approx(incoming_direction):
		player.position = Vector2(START_X, FLOOR_TOP - 30.0)
		await _wait_until_grounded(player, scenario_name)
		player.velocity.x = 0.0
	else:
		player.position = Vector2(START_X, FLOOR_TOP - 150.0)
		player.velocity = Vector2(incoming_direction * player.maximum_speed, 0.0)
		await _wait_until_grounded(player, scenario_name)
		_check(
			is_equal_approx(player.velocity.x, incoming_direction * player.maximum_speed),
			"%s reaches the ground with the scripted incoming velocity" % scenario_name
		)

	player.position.x = START_X
	var takeoff_position := player.position
	_set_horizontal_action(takeoff_direction)
	player._jump_buffer_remaining = player.jump_buffering

	var takeoff_velocity_x := 0.0
	var apex_y := takeoff_position.y
	var landing_position := takeoff_position
	var left_ground := false
	var landed := false

	for frame in range(MAX_SCENARIO_FRAMES):
		await physics_frame

		if frame == 0:
			takeoff_velocity_x = player.velocity.x
			_check(player.velocity.y < 0.0, "%s starts a jump on its first scripted frame" % scenario_name)

		apex_y = minf(apex_y, player.position.y)

		if frame + 1 == DIRECTION_HOLD_FRAMES:
			_release_movement_actions()

		if not player.is_on_floor():
			left_ground = true
		elif left_ground:
			landing_position = player.position
			landed = true
			break

	_check(landed, "%s lands within the scenario frame budget" % scenario_name)
	_release_movement_actions()

	var metrics := {
		"name": scenario_name,
		"takeoff_velocity_x": takeoff_velocity_x,
		"apex_height": takeoff_position.y - apex_y,
		"horizontal_displacement": landing_position.x - takeoff_position.x,
		"landing_x": landing_position.x,
	}
	print(
		"METRICS %s: takeoff_vx=%.3f apex=%.3f displacement=%.3f landing_x=%.3f"
		% [
			scenario_name,
			metrics.takeoff_velocity_x,
			metrics.apex_height,
			metrics.horizontal_displacement,
			metrics.landing_x,
		]
	)

	world.queue_free()
	await process_frame
	return metrics


func _wait_until_grounded(player: SharedPlayerController, scenario_name: String) -> void:
	for frame in range(MAX_SCENARIO_FRAMES):
		await physics_frame
		if player.is_on_floor():
			return

	_check(false, "%s reaches the floor before the frame budget expires" % scenario_name)


func _compare_scenarios(
	stationary: Dictionary,
	landing_reversal: Dictionary,
	expected_direction: float,
	direction_name: String
) -> void:
	var expected_velocity := expected_direction * 300.0
	_check(
		absf(stationary.takeoff_velocity_x - expected_velocity) <= VELOCITY_TOLERANCE,
		"Stationary %s jump uses current-input takeoff velocity" % direction_name
	)
	_check(
		absf(landing_reversal.takeoff_velocity_x - expected_velocity) <= VELOCITY_TOLERANCE,
		"Landing-reversal %s jump has no opposite carry" % direction_name
	)
	_check(
		absf(stationary.takeoff_velocity_x - landing_reversal.takeoff_velocity_x) <= VELOCITY_TOLERANCE,
		"%s takeoff velocities match" % direction_name.capitalize()
	)
	_check(
		absf(stationary.apex_height - landing_reversal.apex_height) <= POSITION_TOLERANCE,
		"%s jump apex heights match" % direction_name.capitalize()
	)
	_check(
		absf(stationary.horizontal_displacement - landing_reversal.horizontal_displacement) <= POSITION_TOLERANCE,
		"%s horizontal displacements match" % direction_name.capitalize()
	)
	_check(
		absf(stationary.landing_x - landing_reversal.landing_x) <= POSITION_TOLERANCE,
		"%s landing points match" % direction_name.capitalize()
	)


func _set_horizontal_action(direction: float) -> void:
	_release_movement_actions()
	if direction < 0.0:
		Input.action_press("move_left")
	elif direction > 0.0:
		Input.action_press("move_right")


func _release_movement_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
