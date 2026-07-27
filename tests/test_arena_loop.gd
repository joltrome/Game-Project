extends SceneTree

const ARENA_SCENE := preload("res://scenes/prototypes/arena.tscn")
const PRODUCT_SCENE := preload("res://scenes/hazards/falling_product.tscn")
const PHYSICS_FRAMES_TO_OBSERVE := 720
const FLOAT_TOLERANCE := 0.01

var failures: int = 0
var _telegraph_events: Array[Dictionary] = []
var _drop_events: Array[Dictionary] = []
var _observed_arena: CompactArena
var _observed_drop_while_landed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return

	failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	root.add_child(arena)
	await process_frame
	_observed_arena = arena

	_check(
		arena.player.get_script().resource_path == "res://scripts/player.gd",
		"Prototype A instantiates the shared player controller"
	)
	_check(
		is_equal_approx(arena.player.maximum_speed, 300.0),
		"Prototype A preserves the locked VM-0.1.2 maximum speed"
	)
	_check(
		arena.get_node("HUD/BuildId").text.contains(CompactArena.BUILD_ID),
		"Visible HUD includes the Prototype A build ID"
	)
	_check(arena.get_node("HUD/Timer").visible, "Survival timer is visible")
	_check(arena.get_node("SourceRack").visible, "Vending drop source is visible")
	_check(arena.drop_lane_positions.size() >= 3, "Arena exposes multiple drop lanes")
	for lane_x in arena.drop_lane_positions:
		_check(lane_x >= 96.0 and lane_x <= 1056.0, "Drop lane %.1f stays inside the walls" % lane_x)

	_check(
		arena.minimum_reaction_distance() + FLOAT_TOLERANCE >= arena.required_clearance_distance(),
		"Minimum telegraph permits enough maximum-speed ground travel to clear one product"
	)
	_check(arena.has_reachable_ground_response(), "Arena reports a reachable grounded response")

	_check(
		absf(arena.telegraph_duration_at(999.0) - arena.minimum_telegraph_duration) <= FLOAT_TOLERANCE,
		"Telegraph duration stops at its configured minimum"
	)
	_check(
		absf(arena.drop_cooldown_at(999.0) - arena.minimum_drop_cooldown) <= FLOAT_TOLERANCE,
		"Drop cooldown stops at its configured minimum"
	)
	_check(
		absf(arena.fall_speed_at(999.0) - arena.maximum_fall_speed) <= FLOAT_TOLERANCE,
		"Fall speed stops at its configured maximum"
	)

	arena.telegraph_started.connect(_on_telegraph_started)
	arena.product_dropped.connect(_on_product_dropped)
	arena.player.collision_layer = 0

	var maximum_falling_products := 0
	var maximum_landed_products := 0
	for frame in range(PHYSICS_FRAMES_TO_OBSERVE):
		await physics_frame
		maximum_falling_products = maxi(maximum_falling_products, arena.falling_product_count())
		maximum_landed_products = maxi(maximum_landed_products, arena.landed_product_count())

	_check(_drop_events.size() >= 3, "Observed at least three complete drops")
	_check(
		_telegraph_events.size() == _drop_events.size() or _telegraph_events.size() == _drop_events.size() + 1,
		"Every observed drop has exactly one preceding telegraph"
	)
	for index in range(_drop_events.size()):
		var telegraph := _telegraph_events[index]
		var drop := _drop_events[index]
		var elapsed_frames: int = drop.frame - telegraph.frame
		var required_frames: int = floori(telegraph.duration * Engine.physics_ticks_per_second)
		_check(telegraph.warning_visible, "Telegraph %d makes its warning visible" % index)
		_check(telegraph.lane == drop.lane, "Drop %d uses its telegraphed lane" % index)
		_check(
			absf(telegraph.carriage_x - arena.drop_lane_positions[drop.lane]) <= FLOAT_TOLERANCE,
			"Drop %d originates at its visible source carriage" % index
		)
		_check(
			elapsed_frames + 1 >= required_frames,
			"Drop %d waits for its configured telegraph duration" % index
		)
	_check(maximum_falling_products <= 1, "At most one product falls at a time")
	_check(
		maximum_landed_products <= arena.maximum_landed_cans,
		"Landed products remain within the configured cap"
	)
	_check(_observed_drop_while_landed, "A new product can drop while a landed can remains")

	arena.queue_free()
	_observed_arena = null
	await process_frame
	await _test_immediate_collision_death()
	await _test_restart_path()

	print("Compact arena validation finished with %d failure(s)." % failures)
	quit(failures)


func _test_immediate_collision_death() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	root.add_child(arena)
	await physics_frame

	var product := PRODUCT_SCENE.instantiate() as FallingProduct
	product.position = arena.player.position
	product.configure(
		0.0,
		arena.floor_y,
		arena.landed_lifetime,
		arena.product_size,
		arena.landed_product_size
	)
	product.player_hit.connect(arena._on_product_hit)
	arena.get_node("Hazards").add_child(product)

	await physics_frame
	await physics_frame
	_check(arena.is_dead, "Player-product overlap causes immediate death")
	_check(not arena.player.is_physics_processing(), "Death immediately stops player movement processing")

	var stopped_time := arena.survival_time
	for frame in range(5):
		await physics_frame
	_check(
		absf(arena.survival_time - stopped_time) <= FLOAT_TOLERANCE,
		"Survival timer stops on death"
	)

	arena.queue_free()
	await process_frame


func _test_restart_path() -> void:
	var arena := ARENA_SCENE.instantiate() as CompactArena
	root.add_child(arena)
	current_scene = arena
	await process_frame

	var previous_instance_id := arena.get_instance_id()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	var restart_started_at := Time.get_ticks_msec()
	arena._unhandled_input(restart_event)

	await process_frame
	await process_frame
	var restart_elapsed_ms := Time.get_ticks_msec() - restart_started_at
	_check(
		current_scene != null and current_scene.get_instance_id() != previous_instance_id,
		"Restart action reloads the current arena scene"
	)
	_check(restart_elapsed_ms < 1000, "Headless restart completes in under one second")

	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _on_telegraph_started(lane_index: int, duration: float) -> void:
	_telegraph_events.append({
		"lane": lane_index,
		"duration": duration,
		"frame": Engine.get_physics_frames(),
		"warning_visible": _observed_arena.get_node("SourceRack/SourceCarriage/WarningColumn").visible,
		"carriage_x": _observed_arena.get_node("SourceRack/SourceCarriage").position.x,
	})


func _on_product_dropped(lane_index: int, fall_speed: float) -> void:
	if _observed_arena.landed_product_count() > 0:
		_observed_drop_while_landed = true
	_drop_events.append({
		"lane": lane_index,
		"fall_speed": fall_speed,
		"frame": Engine.get_physics_frames(),
	})
