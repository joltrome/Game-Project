extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const POST_TEACHING_TEMPLATES := [
	CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK,
	CollectibleDirector.OfferTemplate.MIXED_ROUTE,
	CollectibleDirector.OfferTemplate.HORIZONTAL_LINE,
	CollectibleDirector.OfferTemplate.STAGGERED_ROUTE,
	CollectibleDirector.OfferTemplate.COMPACT_BURST,
]

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
	await _test_configured_mix_and_geometry()
	await _test_action_trajectory_matrix()
	await _test_maximum_speed_action_validation()
	print("VM046_ROUTE_DECISION_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_configured_mix_and_geometry() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	var expected_weights := PackedInt32Array([0, 0, 30, 20, 25, 10, 15])
	for weights in [
		director.phase_one_template_weights,
		director.phase_two_template_weights,
		director.phase_three_template_weights,
		director.phase_four_template_weights,
	]:
		_check(weights == expected_weights, "Post-teaching route weights are 30/25/20/15/10 percent")
	_check(
		is_equal_approx(director.route_spacing_pixels(), 64.0)
		and is_equal_approx(director.typical_sibling_spacing_player_widths, 2.0),
		"Renewed-commitment spacing is 64 px or two player widths"
	)
	_check(
		is_equal_approx(director.horizontal_trail_span_ratio, 0.45)
		and director.horizontal_trail_span_ratio >= 0.35
		and director.horizontal_trail_span_ratio <= 0.55,
		"Long commitment trail spans the configured 45 percent of valid belt width"
	)
	_check(
		is_equal_approx(director.staggered_coin_interval, 0.50)
		and director.staggered_coin_interval >= 0.35
		and director.staggered_coin_interval <= 0.70,
		"Staggered aerial siblings use the configured 0.50-second interval"
	)
	var fork := director.template_candidates_for_test(CollectibleDirector.OfferTemplate.MIXED_ROUTE, 4)
	_check(
		fork[1].route_branch == "ground"
		and fork[2].route_branch == "air"
		and fork[1].position.x < fork[0].position.x
		and fork[2].position.x > fork[0].position.x,
		"Fork branches diverge horizontally in opposite directions and vertically"
	)
	_free_conveyor(conveyor)


func _test_action_trajectory_matrix() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	for template in POST_TEACHING_TEMPLATES:
		var intended_count := 3 if template == CollectibleDirector.OfferTemplate.COMPACT_BURST else 4
		var validation := director.route_action_validation_for_test(template, intended_count)
		var results: Dictionary = validation.results
		var no_input: Dictionary = results[CollectibleDirector.RouteTrajectory.NO_FURTHER_INPUT]
		var same_input: Dictionary = results[CollectibleDirector.RouteTrajectory.SAME_INPUT_CONTINUATION]
		var passive_jump: Dictionary = results[CollectibleDirector.RouteTrajectory.PASSIVE_JUMP]
		var aggressive: Dictionary = results[CollectibleDirector.RouteTrajectory.INTENDED_AGGRESSIVE]
		var abandonment: Dictionary = results[CollectibleDirector.RouteTrajectory.SAFE_ABANDONMENT]
		_check(bool(validation.valid), "%s passes action-based validation" % validation.template_name)
		if template != CollectibleDirector.OfferTemplate.COMPACT_BURST:
			_check(int(no_input.collected_count) < intended_count, "%s is not completed with no further input" % validation.template_name)
		else:
			_check(int(no_input.collected_count) == intended_count, "Compact jackpot deliberately rewards one easy corridor")
		if template in [CollectibleDirector.OfferTemplate.MIXED_ROUTE, CollectibleDirector.OfferTemplate.STAGGERED_ROUTE]:
			_check(int(same_input.collected_count) < intended_count, "%s is not solved by one unchanged input" % validation.template_name)
		if template in [CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK, CollectibleDirector.OfferTemplate.MIXED_ROUTE, CollectibleDirector.OfferTemplate.STAGGERED_ROUTE]:
			_check(int(passive_jump.collected_count) < intended_count, "%s is not completed by one passive jump" % validation.template_name)
		_check(
			int(aggressive.collected_count) >= int(aggressive.intended_target_count),
			"%s intended aggressive route remains collectible" % validation.template_name
		)
		if template == CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK:
			_check(int(abandonment.collected_count) == 1, "Safe route supports one-coin collection and abandonment")
		print(
			"VM046_ROUTE_METRICS template=%s positions=%s spawn_times=%s spacing_widths=%.3f no_input=%d same_input=%d passive_jump=%d aggressive=%d/%d abandonment=%d"
			% [
				validation.template_name,
				validation.positions,
				validation.spawn_times,
				director.typical_sibling_spacing_player_widths,
				int(no_input.collected_count),
				int(same_input.collected_count),
				int(passive_jump.collected_count),
				int(aggressive.collected_count),
				int(aggressive.intended_target_count),
				int(abandonment.collected_count),
			]
		)
	_free_conveyor(conveyor)


func _test_maximum_speed_action_validation() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	conveyor.survival_time = 60.0
	conveyor.conveyor_speed = conveyor.conveyor_speed_at(60.0)
	for template in POST_TEACHING_TEMPLATES:
		var intended_count := 3 if template == CollectibleDirector.OfferTemplate.COMPACT_BURST else 4
		var validation := director.route_action_validation_for_test(template, intended_count)
		_check(bool(validation.valid), "%s remains action-valid at maximum conveyor speed" % validation.template_name)
	_free_conveyor(conveyor)


func _make_conveyor() -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	root.add_child(conveyor)
	await physics_frame
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	(conveyor.get_node("CollectibleDirector") as CollectibleDirector).set_process(false)
	return conveyor


func _director(conveyor: ConveyorPrototype) -> CollectibleDirector:
	return conveyor.get_node("CollectibleDirector") as CollectibleDirector


func _free_conveyor(conveyor: ConveyorPrototype) -> void:
	conveyor.queue_free()
	await process_frame
