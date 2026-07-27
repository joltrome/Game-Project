extends SceneTree

const ARENA_SCENE := preload("res://scenes/prototypes/arena.tscn")
const PRODUCT_SCENE := preload("res://scenes/hazards/falling_product.tscn")
const FLOAT_TOLERANCE := 0.01
const MAX_TEST_FRAMES := 240

var failures: int = 0
var _product_landed_frame: int = -1
var _product_cleared_frame: int = -1
var _spawn_distances_from_landed: Array[float] = []
var _observed_spawn_while_landed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return

	failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	await _test_product_landing_and_despawn()
	await _test_landed_can_is_lethal()
	await _test_locked_controller_clears_landed_can()
	await _test_arena_cap_spacing_and_restart()
	print("Landed-can persistence validation finished with %d failure(s)." % failures)
	quit(failures)


func _test_product_landing_and_despawn() -> void:
	var product := PRODUCT_SCENE.instantiate() as FallingProduct
	product.position = Vector2(200.0, 0.0)
	product.configure(
		600.0,
		100.0,
		0.20,
		Vector2(72.0, 72.0),
		Vector2(72.0, 48.0)
	)
	product.landed.connect(_on_unit_product_landed)
	product.cleared.connect(_on_unit_product_cleared)
	root.add_child(product)

	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if _product_landed_frame >= 0:
			break

	_check(_product_landed_frame >= 0, "Falling product enters its landed state at the floor")
	_check(product.is_landed(), "Product reports the landed state")
	_check(
		absf(product.position.y - 76.0) <= FLOAT_TOLERANCE,
		"Landed product rests on the configured floor"
	)
	var landed_shape := product.get_node("CollisionShape2D").shape as RectangleShape2D
	_check(
		landed_shape.size == Vector2(72.0, 48.0),
		"Landed product applies its configured low obstacle dimensions"
	)

	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if _product_cleared_frame >= 0:
			break

	_check(_product_cleared_frame >= 0, "Landed product despawns after its lifetime")
	var landed_frames := _product_cleared_frame - _product_landed_frame
	var expected_landed_frames := ceili(0.20 * Engine.physics_ticks_per_second)
	_check(
		abs(landed_frames - expected_landed_frames) <= 1,
		"Landed lifetime stays within one physics frame of the configured duration"
	)
	await process_frame


func _test_landed_can_is_lethal() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	arena.initial_drop_delay = 999.0
	root.add_child(arena)
	await physics_frame

	var product := PRODUCT_SCENE.instantiate() as FallingProduct
	product.position = Vector2(200.0, 0.0)
	product.configure(
		0.0,
		arena.floor_y,
		arena.landed_lifetime,
		arena.product_size,
		arena.landed_product_size
	)
	product.player_hit.connect(arena._on_product_hit)
	arena.get_node("Hazards").add_child(product)
	product._land()
	_check(product.is_landed(), "Collision test begins with a landed can")

	product.position.x = arena.player.position.x
	await physics_frame
	await physics_frame
	_check(arena.is_dead, "Touching a landed can causes immediate death")

	arena.queue_free()
	await process_frame


func _test_locked_controller_clears_landed_can() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	arena.initial_drop_delay = 999.0
	root.add_child(arena)
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if arena.player.is_on_floor():
			break
	_check(arena.player.is_on_floor(), "Jump-clearance scenario starts with a grounded player")
	arena.player.position.x = 480.0
	await physics_frame

	var product := PRODUCT_SCENE.instantiate() as FallingProduct
	product.position = Vector2(576.0, 0.0)
	product.configure(
		0.0,
		arena.floor_y,
		99.0,
		arena.product_size,
		arena.landed_product_size
	)
	product.player_hit.connect(arena._on_product_hit)
	arena.get_node("Hazards").add_child(product)
	product._land()

	Input.action_press("move_right")
	arena.player._jump_buffer_remaining = arena.player.jump_buffering
	var cleared_obstacle := false
	var minimum_player_y := arena.player.position.y
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		minimum_player_y = minf(minimum_player_y, arena.player.position.y)
		if arena.is_dead:
			break
		if arena.player.position.x > 640.0:
			cleared_obstacle = true
			break
	Input.action_release("move_right")
	print(
		"JUMP CLEARANCE METRICS: x=%.3f y=%.3f apex_y=%.3f dead=%s"
		% [arena.player.position.x, arena.player.position.y, minimum_player_y, arena.is_dead]
	)

	_check(
		cleared_obstacle and not arena.is_dead,
		"Locked VM-0.1.2 controller can jump across a landed can"
	)

	arena.queue_free()
	await process_frame


func _test_arena_cap_spacing_and_restart() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	_check(
		absf(arena.initial_telegraph_duration - 0.85) <= FLOAT_TOLERANCE
		and absf(arena.minimum_telegraph_duration - 0.50) <= FLOAT_TOLERANCE,
		"VM-0.2.0-A telegraph values remain unchanged"
	)
	_check(
		absf(arena.initial_fall_speed - 360.0) <= FLOAT_TOLERANCE
		and absf(arena.maximum_fall_speed - 620.0) <= FLOAT_TOLERANCE,
		"VM-0.2.0-A fall-speed curve remains unchanged"
	)

	arena.initial_drop_delay = 0.0
	arena.initial_telegraph_duration = 0.01
	arena.minimum_telegraph_duration = 0.01
	arena.initial_drop_cooldown = 0.01
	arena.minimum_drop_cooldown = 0.01
	arena.initial_fall_speed = 3000.0
	arena.maximum_fall_speed = 3000.0
	arena.landed_lifetime = 1.5
	arena.product_dropped.connect(_on_fast_product_dropped.bind(arena))
	root.add_child(arena)
	await process_frame
	arena.player.collision_layer = 0

	_check(arena.maximum_landed_cans == 2, "Initial landed-can cap is two")
	_check(
		absf(arena.landed_lifetime - 1.5) <= FLOAT_TOLERANCE,
		"Test arena accepts a configurable landed lifetime"
	)
	_check(arena.is_landed_can_jump_clearable(), "Landed dimensions are clearable by the locked jump")
	_check(arena.has_safe_landed_spacing(), "Minimum spacing leaves a traversable gap")

	var maximum_landed_seen := 0
	var observed_two_landed := false
	var minimum_pair_distance := INF
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		maximum_landed_seen = maxi(maximum_landed_seen, arena.landed_product_count())
		var positions := arena.landed_positions()
		if positions.size() == 2:
			observed_two_landed = true
			minimum_pair_distance = minf(minimum_pair_distance, absf(positions[0] - positions[1]))

	_check(observed_two_landed, "Accelerated validation reaches two simultaneous landed cans")
	_check(
		maximum_landed_seen <= arena.maximum_landed_cans,
		"Arena never exceeds the configured landed-can cap"
	)
	_check(
		minimum_pair_distance + FLOAT_TOLERANCE >= arena.minimum_landed_spacing,
		"Simultaneous landed cans remain outside the prohibited spacing"
	)
	_check(_observed_spawn_while_landed, "Additional cans spawn while a landed can remains")
	for distance in _spawn_distances_from_landed:
		_check(
			distance + FLOAT_TOLERANCE >= arena.minimum_landed_spacing,
			"New drop avoids overlap with every existing landed can"
		)

	_check(arena.active_product_count() > 0, "Restart test begins with persisted hazard state")
	current_scene = arena
	var previous_instance_id := arena.get_instance_id()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	arena._unhandled_input(restart_event)
	await process_frame
	await process_frame

	var restarted_arena := current_scene as CompactArena
	_check(
		restarted_arena != null and restarted_arena.get_instance_id() != previous_instance_id,
		"Restart replaces the arena instance"
	)
	_check(
		restarted_arena != null
		and restarted_arena.falling_product_count() == 0
		and restarted_arena.landed_product_count() == 0
		and restarted_arena.get_node("Hazards").get_child_count() == 0,
		"Restart clears falling and landed cans"
	)

	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _on_unit_product_landed(_product: FallingProduct) -> void:
	_product_landed_frame = Engine.get_physics_frames()


func _on_unit_product_cleared(_product: FallingProduct) -> void:
	_product_cleared_frame = Engine.get_physics_frames()


func _on_fast_product_dropped(_lane_index: int, _speed: float, arena: CompactArena) -> void:
	var landed_x_positions := arena.landed_positions()
	if not landed_x_positions.is_empty():
		_observed_spawn_while_landed = true

	var source_carriage := arena.get_node("SourceRack/SourceCarriage") as Node2D
	var drop_x: float = source_carriage.position.x
	for landed_x in landed_x_positions:
		_spawn_distances_from_landed.append(absf(drop_x - landed_x))
