extends SceneTree

const ARENA_SCENE := preload("res://scenes/prototypes/arena.tscn")
const PRODUCT_SCENE := preload("res://scenes/hazards/falling_product.tscn")
const FLOAT_TOLERANCE := 0.05
const MAX_TEST_FRAMES := 300

var failures: int = 0
var _product_landed_frame: int = -1
var _warning_started_frame: int = -1
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
	await _test_valid_floor_transition_and_warning()
	await _test_falling_contact_is_lethal()
	await _test_landed_platform_physics()
	await _test_arena_cap_spacing_and_restart()
	_release_movement_actions()
	print("Solid landed-can validation finished with %d failure(s)." % failures)
	quit(failures)


func _test_valid_floor_transition_and_warning() -> void:
	var product := PRODUCT_SCENE.instantiate() as FallingProduct
	product.position = Vector2(200.0, 0.0)
	product.configure(
		0.0,
		100.0,
		0.30,
		0.10,
		Vector2(72.0, 72.0),
		Vector2(72.0, 48.0)
	)
	product.landed.connect(_on_unit_product_landed)
	product.despawn_warning_started.connect(_on_unit_warning_started)
	product.cleared.connect(_on_unit_product_cleared)
	root.add_child(product)

	for frame in range(5):
		await physics_frame
	_check(product.is_falling(), "Product remains falling without downward floor contact")
	_check(product.is_falling_lethal(), "Falling state keeps the lethal sensor enabled")

	product.fall_speed = 600.0
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if _product_landed_frame >= 0:
			break

	_check(_product_landed_frame >= 0, "Downward crossing of the floor triggers landed state")
	_check(product.is_landed(), "Product reports a landed state after valid floor contact")
	_check(product.is_landed_solid(), "Landed state enables solid collision")
	_check(not product.is_falling_lethal(), "Landed state disables lethal collision")
	_check(
		absf(product.position.y - 76.0) <= FLOAT_TOLERANCE,
		"Landed product rests exactly on the configured floor"
	)
	var landed_shape := product.get_node("LandedBody/CollisionShape2D").shape as RectangleShape2D
	_check(landed_shape.size == Vector2(72.0, 48.0), "Solid platform uses configured dimensions")
	_check(product.get_node("Label").text == "PLATFORM", "Landed visual explicitly reads PLATFORM")

	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if _warning_started_frame >= 0:
			break
	_check(_warning_started_frame >= 0, "Despawn warning begins before removal")
	_check(product.is_in_despawn_warning(), "Product enters explicit despawn-warning state")
	_check(product.is_landed_solid(), "Product remains solid throughout despawn warning")
	_check(product.get_node("Label").text == "DESPAWN", "Warning visual explicitly reads DESPAWN")

	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if _product_cleared_frame >= 0:
			break
	_check(_product_cleared_frame >= 0, "Product disappears after configured landed lifetime")

	var warning_delay_frames := _warning_started_frame - _product_landed_frame
	var expected_warning_delay := roundi(0.20 * Engine.physics_ticks_per_second)
	_check(
		abs(warning_delay_frames - expected_warning_delay) <= 1,
		"Despawn warning begins within one frame of configured timing"
	)
	var warning_frames := _product_cleared_frame - _warning_started_frame
	var expected_warning_frames := roundi(0.10 * Engine.physics_ticks_per_second)
	_check(
		abs(warning_frames - expected_warning_frames) <= 1,
		"Warning duration stays within one frame of configured duration"
	)
	await process_frame

	var invalid_product := PRODUCT_SCENE.instantiate() as FallingProduct
	invalid_product.position = Vector2(200.0, 80.0)
	invalid_product.configure(
		600.0,
		100.0,
		1.0,
		0.2,
		Vector2(72.0, 72.0),
		Vector2(72.0, 48.0)
	)
	root.add_child(invalid_product)
	await physics_frame
	await physics_frame
	_check(
		invalid_product.is_falling(),
		"A product already below the floor cannot create a landed platform"
	)
	invalid_product.queue_free()
	await process_frame


func _test_falling_contact_is_lethal() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	arena.initial_drop_delay = 999.0
	root.add_child(arena)
	await _wait_until_grounded(arena.player)

	var product := PRODUCT_SCENE.instantiate() as FallingProduct
	product.position = Vector2(200.0, arena.player.position.y)
	product.configure(
		0.0,
		arena.floor_y,
		arena.landed_lifetime,
		arena.despawn_warning_duration,
		arena.product_size,
		arena.landed_product_size
	)
	product.player_hit.connect(arena._on_product_hit)
	arena.get_node("Hazards").add_child(product)
	await physics_frame
	_check(product.is_falling_lethal(), "Falling collision test starts in lethal state")

	product.position.x = arena.player.position.x
	await physics_frame
	await physics_frame
	_check(arena.is_dead, "Player contact with a falling product causes immediate death")

	arena.queue_free()
	await process_frame


func _test_landed_platform_physics() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	arena.initial_drop_delay = 999.0
	root.add_child(arena)
	await _wait_until_grounded(arena.player)
	arena.player.position.x = 400.0
	await physics_frame

	var product := PRODUCT_SCENE.instantiate() as FallingProduct
	product.position = Vector2(576.0, arena.floor_y - arena.product_size.y * 0.5 - 1.0)
	product.configure(
		120.0,
		arena.floor_y,
		99.0,
		1.0,
		arena.product_size,
		arena.landed_product_size
	)
	product.player_hit.connect(arena._on_product_hit)
	arena.get_node("Hazards").add_child(product)
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if product.is_landed():
			break
	_check(product.is_landed_solid(), "Platform physics test uses a solid landed product")
	_check(not arena.is_dead, "Floor transition away from the player is non-lethal")

	arena.player.position = Vector2(480.0, arena.floor_y - 24.0)
	arena.player.velocity = Vector2.ZERO
	await physics_frame
	Input.action_press("move_right")
	for frame in range(45):
		await physics_frame
	Input.action_release("move_right")
	_check(not arena.is_dead, "Horizontal contact with landed platform is non-lethal")
	_check(
		arena.player.position.x <= 524.1,
		"Solid landed platform blocks horizontal movement"
	)

	arena.player.position = Vector2(576.0, 450.0)
	arena.player.velocity = Vector2.ZERO
	var stable_y_min := INF
	var stable_y_max := -INF
	for frame in range(90):
		await physics_frame
		if frame >= 60:
			stable_y_min = minf(stable_y_min, arena.player.position.y)
			stable_y_max = maxf(stable_y_max, arena.player.position.y)
	_check(arena.player.is_on_floor(), "Player can stand on top of landed platform")
	_check(
		absf(arena.player.position.y - 512.0) <= FLOAT_TOLERANCE,
		"Player settles at the expected platform-top height"
	)
	_check(stable_y_max - stable_y_min <= FLOAT_TOLERANCE, "Platform standing has no visible jitter")
	_check(not arena.is_dead, "Standing on landed platform remains non-lethal")

	arena.player.position = Vector2(480.0, arena.floor_y - 24.0)
	arena.player.velocity = Vector2.ZERO
	await physics_frame
	await _wait_until_grounded(arena.player)
	Input.action_press("move_right")
	arena.player._jump_buffer_remaining = arena.player.jump_buffering
	var cleared_platform := false
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if arena.is_dead:
			break
		if arena.player.position.x > 640.0:
			cleared_platform = true
			break
	Input.action_release("move_right")
	_check(
		cleared_platform and not arena.is_dead,
		"Locked VM-0.1.2 jump comfortably clears solid landed platform"
	)

	arena.queue_free()
	await process_frame


func _test_arena_cap_spacing_and_restart() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	_check(
		absf(arena.telegraph_at_zero_seconds - 0.70) <= FLOAT_TOLERANCE
		and absf(arena.minimum_telegraph_duration - 0.28) <= FLOAT_TOLERANCE,
		"VM-0.2.3-A telegraph hypotheses are configured"
	)
	_check(
		absf(arena.fall_duration_at_zero_seconds - 0.75) <= FLOAT_TOLERANCE
		and absf(arena.minimum_fall_duration - 0.25) <= FLOAT_TOLERANCE,
		"VM-0.2.3-A target fall-duration hypotheses are configured"
	)
	_check(
		absf(arena.post_drop_delay_before_five_seconds - 0.40) <= FLOAT_TOLERANCE
		and absf(arena.minimum_post_drop_delay - 0.15) <= FLOAT_TOLERANCE,
		"VM-0.2.3-A post-drop delay hypotheses are configured"
	)

	arena.initial_drop_delay = 0.0
	arena.telegraph_at_zero_seconds = 0.01
	arena.telegraph_at_five_seconds = 0.01
	arena.telegraph_at_twelve_seconds = 0.01
	arena.telegraph_at_twenty_seconds = 0.01
	arena.minimum_telegraph_duration = 0.01
	arena.fall_duration_at_zero_seconds = 0.05
	arena.fall_duration_at_five_seconds = 0.05
	arena.fall_duration_at_twelve_seconds = 0.05
	arena.fall_duration_at_twenty_seconds = 0.05
	arena.minimum_fall_duration = 0.05
	arena.post_drop_delay_before_five_seconds = 0.01
	arena.post_drop_delay_at_five_seconds = 0.01
	arena.post_drop_delay_at_twelve_seconds = 0.01
	arena.post_drop_delay_at_twenty_seconds = 0.01
	arena.minimum_post_drop_delay = 0.01
	arena.paired_pattern_start_seconds = 999.0
	arena.landed_lifetime = 1.5
	arena.despawn_warning_duration = 0.3
	arena.rolling_eviction_warning_duration = 0.02
	arena.product_dropped.connect(_on_fast_product_dropped.bind(arena))
	root.add_child(arena)
	await process_frame
	arena.player.collision_layer = 0
	arena.player.collision_mask = 0
	arena.player.set_physics_process(false)

	_check(arena.maximum_landed_cans == 3, "Rolling landed-platform cap is three")
	_check(arena.is_landed_can_jump_clearable(), "Landed dimensions are clearable by locked jump")
	_check(arena.has_safe_landed_spacing(), "Minimum spacing leaves a traversable route")

	var maximum_landed_seen := 0
	var observed_three_landed := false
	var minimum_pair_distance := INF
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		maximum_landed_seen = maxi(maximum_landed_seen, arena.landed_product_count())
		var positions := arena.landed_positions()
		if positions.size() == 3:
			observed_three_landed = true
		for first_index in range(positions.size()):
			for second_index in range(first_index + 1, positions.size()):
				minimum_pair_distance = minf(
					minimum_pair_distance,
					absf(positions[first_index] - positions[second_index])
				)

	_check(observed_three_landed, "Accelerated validation reaches three simultaneous platforms")
	_check(
		maximum_landed_seen <= arena.maximum_landed_cans,
		"Arena never exceeds configured landed-platform cap"
	)
	_check(
		minimum_pair_distance + FLOAT_TOLERANCE >= arena.minimum_landed_spacing,
		"Simultaneous platforms cannot overlap or form an adjacent wall"
	)
	_check(_observed_spawn_while_landed, "Additional products spawn while a platform remains")
	for distance in _spawn_distances_from_landed:
		_check(
			distance + FLOAT_TOLERANCE >= arena.minimum_landed_spacing,
			"New drop avoids every existing landed platform"
		)

	_check(arena.active_product_count() > 0, "Restart test begins with active product state")
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
		"Restart replaces arena instance"
	)
	_check(
		restarted_arena != null
		and restarted_arena.falling_product_count() == 0
		and restarted_arena.landed_product_count() == 0
		and restarted_arena.get_node("Hazards").get_child_count() == 0,
		"Restart clears falling and landed product states"
	)

	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _wait_until_grounded(player: SharedPlayerController) -> void:
	for frame in range(MAX_TEST_FRAMES):
		await physics_frame
		if player.is_on_floor():
			return
	_check(false, "Player reaches a floor within the test frame budget")


func _release_movement_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")


func _on_unit_product_landed(_product: FallingProduct) -> void:
	_product_landed_frame = Engine.get_physics_frames()


func _on_unit_warning_started(_product: FallingProduct) -> void:
	_warning_started_frame = Engine.get_physics_frames()


func _on_unit_product_cleared(_product: FallingProduct) -> void:
	_product_cleared_frame = Engine.get_physics_frames()


func _on_fast_product_dropped(lane_index: int, _speed: float, arena: CompactArena) -> void:
	var landed_x_positions := PackedFloat32Array()
	for product in arena._landed_products:
		if is_instance_valid(product) and not product.is_rolling_eviction_pending():
			landed_x_positions.append(product.position.x)
	if not landed_x_positions.is_empty():
		_observed_spawn_while_landed = true

	var drop_x: float = arena.drop_lane_positions[lane_index]
	for landed_x in landed_x_positions:
		_spawn_distances_from_landed.append(absf(drop_x - landed_x))
