extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const ARENA_SCENE_PATH := "res://scenes/prototypes/arena.tscn"
const EXPECTED_FIRST_SPAWN := 6.5
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
	await _test_configuration_and_timing()
	await _test_single_instance_collection_and_expiration()
	await _test_reachability_and_placement_rejection()
	await _test_restart_cleanup()
	await _test_frozen_gameplay_boundaries()
	print("COLLECTIBLE_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_configuration_and_timing() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	_check(
		director.first_spawn_window_min == 5.0
		and director.first_spawn_window_max == 8.0
		and director.first_spawn_time == EXPECTED_FIRST_SPAWN,
		"First collectible is configured inside the approved 5–8 second window"
	)
	_check(
		director.collectible_lifetime == 3.0
		and director.recurring_spawn_interval == 7.0,
		"Collectible lifetime and recurring interval are independently configurable"
	)
	conveyor.survival_time = EXPECTED_FIRST_SPAWN - 0.01
	director._process(0.0)
	_check(
		director.active_collectible_count() == 0,
		"Collectible does not spawn before its configured first time"
	)
	conveyor.survival_time = EXPECTED_FIRST_SPAWN
	director._process(0.0)
	_check(
		director.active_collectible_count() == 1
		and absf(director.first_actual_spawn_time - EXPECTED_FIRST_SPAWN)
			<= FLOAT_TOLERANCE,
		"Collectible spawns at 6.5 seconds within the configured window"
	)
	_check(
		not director.try_spawn_for_test()
		and director.active_collectible_count() == 1,
		"Only one collectible can exist at a time"
	)
	_free_conveyor(conveyor)


func _test_single_instance_collection_and_expiration() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	conveyor.player.position = Vector2(600.0, 552.0)
	director.candidate_x_positions = PackedFloat32Array([600.0])
	_check(director.try_spawn_for_test(), "Reachable collectible can be forced for physics validation")
	var collectible := director.active_collectible()
	_check(
		collectible != null
		and collectible.is_non_solid()
		and collectible.collision_mask == 1,
		"Collectible detects the player without adding a solid collision layer"
	)
	await _wait_physics_frames(3)
	_check(
		director.score == 1
		and director.active_collectible_count() == 0,
		"Collection increments the current-run score exactly once and removes the pickup"
	)
	await _wait_physics_frames(3)
	_check(director.score == 1, "Resolved collectible cannot increment score twice")

	director.candidate_x_positions = PackedFloat32Array([600.0])
	conveyor.player.position = Vector2(760.0, 552.0)
	_check(director.try_spawn_for_test(), "A second pickup can spawn after collection")
	director.active_collectible().monitoring = false
	director.active_collectible().time_remaining = 0.05
	await _wait_physics_frames(8)
	_check(
		director.active_collectible_count() == 0,
		"Expiration removes the uncollected pickup"
	)
	_check(
		director.score == 1,
		"Expiration does not change score"
	)
	_free_conveyor(conveyor)


func _test_reachability_and_placement_rejection() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	var candidate := Vector2(600.0, 552.0)
	_check(
		director.candidate_is_reachable(candidate),
		"Placement is reachable using locked relative speed and conveyor motion"
	)
	_check(
		candidate.x
			<= conveyor.right_edge_zone_left() - director.safe_edge_exclusion,
		"Default placement lies outside the safest right-edge zone"
	)
	_check(
		director.candidate_is_valid(candidate),
		"Default placement is on-belt and valid in an empty current state"
	)
	_check(
		not director.candidate_is_valid(Vector2(180.0, 552.0)),
		"Placement that would enter the off-belt region before expiry is rejected"
	)

	conveyor.drop_lane_positions = PackedFloat32Array([600.0])
	conveyor.force_warning_for_test(0)
	_check(
		not director.candidate_is_valid(candidate),
		"Candidate overlapping an active warning/drop footprint is rejected"
	)
	var product := conveyor.force_drop_for_test(0)
	_check(
		product != null and not director.candidate_is_valid(candidate),
		"Candidate in a falling can path is rejected even before vertical overlap"
	)
	_free_conveyor(conveyor)


func _test_restart_cleanup() -> void:
	var change_error := change_scene_to_file(CONVEYOR_SCENE_PATH)
	_check(change_error == OK, "Restart fixture loads Prototype B")
	await scene_changed
	await physics_frame
	var conveyor := current_scene as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	var director := _director(conveyor)
	conveyor.player.position = Vector2(600.0, 552.0)
	director.candidate_x_positions = PackedFloat32Array([600.0])
	_check(director.try_spawn_for_test(), "Restart fixture contains a collectible")
	director.score = 3
	director._update_score_label()
	var old_collectible := director.active_collectible()
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	conveyor._unhandled_input(restart_event)
	await scene_changed
	await physics_frame
	var restarted := current_scene as ConveyorPrototype
	var restarted_director := _director(restarted)
	_check(
		restarted_director.score == 0
		and restarted_director.active_collectible_count() == 0
		and restarted.get_node("HUD/CollectibleScore").text
			== "COLLECTIBLES  0",
		"Restart clears the collectible and resets current-run score"
	)
	_check(not is_instance_valid(old_collectible), "Restart frees the old pickup instance")


func _test_frozen_gameplay_boundaries() -> void:
	var arena_scene := load(ARENA_SCENE_PATH) as PackedScene
	var arena := arena_scene.instantiate() as CompactArena
	root.add_child(arena)
	await physics_frame
	_check(
		not arena.has_node("CollectibleDirector"),
		"Prototype A remains free of the VM-0.4.0 experiment"
	)
	_check(
		arena.player.maximum_speed == 300.0
		and arena.player.gravity == 2400.0
		and arena.player.jump_velocity == -700.0,
		"Prototype A retains the locked shared movement values"
	)
	arena.queue_free()
	await process_frame

	var conveyor := await _make_conveyor()
	_check(
		conveyor.conveyor_speed == 140.0
		and conveyor.telegraph_duration == 0.45
		and conveyor.target_fall_duration == 0.55
		and conveyor.sweeper_speed == 520.0,
		"Collectible experiment leaves conveyor and hazard baseline values unchanged"
	)
	_check(
		conveyor.player.maximum_speed == 300.0
		and conveyor.player.gravity == 2400.0
		and conveyor.player.jump_velocity == -700.0,
		"Collectible experiment does not modify player movement parameters"
	)
	_free_conveyor(conveyor)


func _make_conveyor() -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	root.add_child(conveyor)
	await physics_frame
	return conveyor


func _director(conveyor: ConveyorPrototype) -> CollectibleDirector:
	return conveyor.get_node("CollectibleDirector") as CollectibleDirector


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
