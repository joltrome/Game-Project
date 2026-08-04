extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	await _test_explicit_templates_and_siblings()
	await _test_rejection_rotation_and_invariant()
	await _test_speed_curve()
	print("VM042_OFFER_DIRECTOR_FAILURES=%d" % _failures)
	quit(_failures)


func _test_explicit_templates_and_siblings() -> void:
	for template in range(CollectibleDirector.OfferTemplate.size()):
		var conveyor := await _make_conveyor()
		var director := _director(conveyor)
		var requested: int = [1, 3, 4, 3, 4, 5, 4][template]
		_check(
			director.try_spawn_template_for_test(template, requested),
			"%s template spawns from authored coordinates" % director.template_name(template)
		)
		if template == CollectibleDirector.OfferTemplate.STAGGERED_ROUTE:
			while director.pending_staggered_coin_count() > 0:
				conveyor.survival_time += director.staggered_coin_interval
				director._process(director.staggered_coin_interval)
		var coins := director.active_collectibles()
		_check(coins.size() == requested, "%s creates the intended independent coin count" % director.template_name(template))
		var no_overlap := true
		for first in range(coins.size()):
			for second in range(first + 1, coins.size()):
				if absf(coins[first].global_position.x - coins[second].global_position.x) < director.collectible_size.x:
					no_overlap = false
		_check(no_overlap, "%s siblings do not overlap" % director.template_name(template))
		if coins.size() > 1:
			coins[0]._resolve(true)
			await process_frame
			_check(director.score == 1 and director.active_collectible_count() == coins.size() - 1, "Collecting one sibling scores once and leaves the route intact")
			for coin in director.active_collectibles():
				coin._resolve(false)
			await process_frame
			_check(director.score == 1 and director.active_collectible_count() == 0, "Sibling expiration changes no score and clears offer state")
		_free_conveyor(conveyor)


func _test_rejection_rotation_and_invariant() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	director.candidate_x_positions = PackedFloat32Array([180.0])
	_check(
		not director.try_spawn_template_for_test(CollectibleDirector.OfferTemplate.GROUND_SINGLE, 1),
		"Invalid authored placement is rejected"
	)
	var last_entry: Dictionary = director.offer_log()[-1]
	_check(last_entry.rejection_reason == CollectibleDirector.REJECTION_OFF_BELT, "Rejected placement has an explicit known category")
	_check(director.next_spawn_time() < INF, "Director always retains a finite next attempt")
	_check(not director.known_rejection_reasons().has(""), "Known rejection taxonomy contains no blank fallback")
	_free_conveyor(conveyor)


func _test_speed_curve() -> void:
	var conveyor := await _make_conveyor()
	var previous_belt := -INF
	var previous_sweeper := -INF
	for checkpoint in [0.0, 15.0, 30.0, 45.0, 60.0]:
		var belt := conveyor.conveyor_speed_at(checkpoint)
		var sweeper := conveyor.sweeper_speed_at(checkpoint)
		_check(belt >= previous_belt and sweeper >= previous_sweeper, "Belt and Sweeper curves are non-decreasing at %.0fs" % checkpoint)
		previous_belt = belt
		previous_sweeper = sweeper
		print("VM042_SPEED_CHECKPOINT t=%.0f conveyor=%.3f sweeper=%.3f recovery=%.3f" % [checkpoint, belt, sweeper, conveyor.player_rightward_recovery_speed_at(checkpoint)])
	_check(is_equal_approx(conveyor.conveyor_speed_at(60.0), 175.0), "Conveyor reaches exactly 125 percent by 60 seconds")
	_check(is_equal_approx(conveyor.sweeper_speed_at(60.0), 598.0), "Sweeper reaches exactly 115 percent by 60 seconds")
	_check(conveyor.player_rightward_recovery_speed_at(60.0) > 0.0, "Rightward recovery remains positive at maximum intensity")
	for boundary in [15.0, 30.0, 45.0, 60.0]:
		_check(absf(conveyor.conveyor_speed_at(boundary + 0.001) - conveyor.conveyor_speed_at(boundary - 0.001)) < 0.01, "Conveyor curve has no abrupt reset at %.0fs" % boundary)
	_free_conveyor(conveyor)


func _make_conveyor() -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	root.add_child(conveyor)
	await physics_frame
	(conveyor.get_node("CollectibleDirector") as CollectibleDirector).set_process(false)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	return conveyor


func _director(conveyor: ConveyorPrototype) -> CollectibleDirector:
	return conveyor.get_node("CollectibleDirector") as CollectibleDirector


func _free_conveyor(conveyor: ConveyorPrototype) -> void:
	conveyor.queue_free()
	await process_frame
