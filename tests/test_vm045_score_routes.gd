extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const REQUIRED_ROUTE_TEMPLATES := [
	CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK,
	CollectibleDirector.OfferTemplate.HORIZONTAL_LINE,
	CollectibleDirector.OfferTemplate.MIXED_ROUTE,
	CollectibleDirector.OfferTemplate.LOW_AIR_ARC,
	CollectibleDirector.OfferTemplate.STAGGERED_ROUTE,
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
	await _test_central_score_hierarchy()
	await _test_route_geometry_and_weights()
	await _test_routes_at_maximum_conveyor_speed()
	await _test_staggered_lifecycle()
	await _test_minimal_movement_does_not_sweep_route()
	await _test_route_expiration_cleanup()
	await _test_sibling_resolution_and_rapid_score()
	await _test_restart_clears_score_and_pending_route()
	print("VM045_SCORE_ROUTE_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_central_score_hierarchy() -> void:
	var conveyor := await _make_conveyor()
	var timer := conveyor.get_node("HUD/Timer") as Label
	var score_group := conveyor.get_node("HUD/ScoreGroup") as Control
	var score := conveyor.get_node("HUD/ScoreGroup/CollectibleScore") as Label
	var caption := conveyor.get_node("HUD/ScoreGroup/CoinCaption") as Label
	var ratio := float(score.get_theme_font_size("font_size")) / float(timer.get_theme_font_size("font_size"))
	_check(
		is_equal_approx(score_group.anchor_left, 0.5)
		and is_equal_approx(score_group.anchor_right, 0.5)
		and score_group.position.y >= timer.position.y + timer.size.y,
		"Coin score is centred and directly beneath the primary countdown"
	)
	_check(
		ratio >= 0.55 and ratio <= 0.70
		and caption.get_theme_font_size("font_size") < score.get_theme_font_size("font_size"),
		"Score numeral is 55–70 percent of timer size and COINS remains subordinate"
	)
	_check(
		conveyor.get_node("HUD/ScoreGroup/CoinFace") is Polygon2D
		and score_group.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Central score uses a geometric Refund Coin icon and cannot intercept input"
	)
	var build_label := conveyor.get_node("HUD/BuildId") as Label
	_check(
		score.get_theme_font_size("font_size") > build_label.get_theme_font_size("font_size"),
		"Coin score remains larger than build/debug information"
	)
	for viewport_width in [720.0, 800.0, 1152.0, 1440.0]:
		var left: float = viewport_width * score_group.anchor_left + score_group.offset_left
		var right: float = viewport_width * score_group.anchor_right + score_group.offset_right
		_check(
			left >= 16.0 and right <= viewport_width - 16.0,
			"Central score remains inside safe bounds at %d px" % int(viewport_width)
		)
	_free_conveyor(conveyor)


func _test_route_geometry_and_weights() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	var player_width := conveyor.player_collision_size().x
	var typical_spacing := director.route_spacing_pixels()
	_check(
		typical_spacing >= player_width * 1.25
		and typical_spacing <= player_width * 1.75,
		"Typical sibling spacing is derived from 1.25–1.75 player widths"
	)
	var trail := director.template_candidates_for_test(
		CollectibleDirector.OfferTemplate.HORIZONTAL_LINE,
		4
	)
	var trail_span := absf(trail[0].position.x - trail[-1].position.x)
	_check(
		absf(trail_span / director.valid_route_width() - director.horizontal_trail_span_ratio) <= 0.001
		and director.horizontal_trail_span_ratio >= 0.30
		and director.horizontal_trail_span_ratio <= 0.50,
		"Horizontal trail spans the configured 30–50 percent of valid belt width"
	)

	for template in REQUIRED_ROUTE_TEMPLATES:
		var candidates := director.template_candidates_for_test(template, 4)
		var all_valid := not candidates.is_empty()
		var separated := true
		for first in range(candidates.size()):
			all_valid = all_valid and director.candidate_is_valid(
				candidates[first].position,
				candidates[first].band
			)
			for second in range(first + 1, candidates.size()):
				if candidates[first].position.distance_to(candidates[second].position) < director.collectible_size.x:
					separated = false
		_check(all_valid and separated, "%s is reachable and has no sibling overlap" % director.template_name(template))

	var safe_risk := director.template_candidates_for_test(CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK, 4)
	var fork := director.template_candidates_for_test(CollectibleDirector.OfferTemplate.MIXED_ROUTE, 4)
	var arc := director.template_candidates_for_test(CollectibleDirector.OfferTemplate.LOW_AIR_ARC, 4)
	_check(
		safe_risk[0].band == CollectibleDirector.PlacementBand.GROUND
		and safe_risk[1].band == CollectibleDirector.PlacementBand.LOW_AIR
		and safe_risk[0].position.x - safe_risk[-1].position.x >= typical_spacing * 2.5,
		"Safe coin is followed by a materially spaced risky extension"
	)
	_check(
		fork[0].band == CollectibleDirector.PlacementBand.GROUND
		and fork[1].band == CollectibleDirector.PlacementBand.LOW_AIR
		and fork[-1].band == CollectibleDirector.PlacementBand.GROUND,
		"Ground-versus-air route exposes distinct grounded and jumping paths"
	)
	_check(
		arc[1].position.y < arc[0].position.y
		and arc[2].position.y < arc[-1].position.y,
		"Aerial route rises and falls within the normal jump envelope"
	)
	var compact_index := CollectibleDirector.OfferTemplate.COMPACT_BURST
	for weights in [
		director.phase_one_template_weights,
		director.phase_two_template_weights,
		director.phase_three_template_weights,
		director.phase_four_template_weights,
	]:
		var total := 0
		for weight in weights:
			total += weight
		var compact_share := float(weights[compact_index]) / float(total)
		_check(compact_share >= 0.10 and compact_share <= 0.15, "Compact offers remain a 10–15 percent minority")
	_free_conveyor(conveyor)


func _test_routes_at_maximum_conveyor_speed() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	conveyor.survival_time = 60.0
	conveyor.conveyor_speed = conveyor.conveyor_speed_at(60.0)
	for template in REQUIRED_ROUTE_TEMPLATES:
		var candidates := director.template_candidates_for_test(template, 4)
		var valid := not candidates.is_empty()
		for candidate in candidates:
			valid = valid and director.candidate_is_valid(candidate.position, candidate.band)
		_check(valid, "%s remains valid at maximum conveyor speed" % director.template_name(template))
	_free_conveyor(conveyor)


func _test_staggered_lifecycle() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	_check(
		director.staggered_coin_interval >= 0.20
		and director.staggered_coin_interval <= 0.40
		and director.try_spawn_template_for_test(CollectibleDirector.OfferTemplate.STAGGERED_ROUTE, 4),
		"Staggered route starts with a configurable 0.20–0.40 second interval"
	)
	_check(
		director.active_collectible_count() == 1
		and director.pending_staggered_coin_count() == 3,
		"Staggered route initially exposes one coin and retains three scheduled siblings"
	)
	conveyor.survival_time += director.staggered_coin_interval - 0.01
	director._process(director.staggered_coin_interval - 0.01)
	_check(director.active_collectible_count() == 1, "No staggered sibling appears before its delay")
	for expected_count in range(2, 5):
		conveyor.survival_time += director.staggered_coin_interval
		director._process(director.staggered_coin_interval)
		_check(director.active_collectible_count() == expected_count, "Staggered sibling %d appears on schedule" % expected_count)
	_check(director.pending_staggered_coin_count() == 0, "Staggered route clears pending lifecycle state")
	_free_conveyor(conveyor)


func _test_minimal_movement_does_not_sweep_route() -> void:
	for template in REQUIRED_ROUTE_TEMPLATES:
		var conveyor := await _make_conveyor()
		var director := _director(conveyor)
		var candidates := director.template_candidates_for_test(template, 4)
		conveyor.player.position.x = candidates[0].position.x
		_check(
			director.try_spawn_template_for_test(template, 4),
			"%s minimal-action fixture spawns" % director.template_name(template)
		)
		await physics_frame
		await physics_frame
		_check(
			director.score <= 1,
			"Standing at one %s coin cannot auto-collect all route siblings" % director.template_name(template)
		)
		_free_conveyor(conveyor)


func _test_route_expiration_cleanup() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	_check(
		director.try_spawn_template_for_test(CollectibleDirector.OfferTemplate.HORIZONTAL_LINE, 4),
		"Route expiration fixture spawns"
	)
	var expires_no_later_than_left_edge := true
	for coin in director.active_collectibles():
		var time_to_left_edge := (
			coin.global_position.x
			- director.collectible_size.x * 0.5
			- conveyor.conveyor_support_left_x
		) / conveyor.conveyor_speed
		expires_no_later_than_left_edge = (
			expires_no_later_than_left_edge
			and coin.lifetime <= time_to_left_edge + 0.0001
		)
		coin._physics_process(coin.time_remaining + 0.01)
	await process_frame
	_check(
		expires_no_later_than_left_edge
		and director.active_collectible_count() == 0
		and director.active_offer_count() == 0,
		"Expired route siblings resolve before leaving support and clean up their offer"
	)
	_free_conveyor(conveyor)


func _test_sibling_resolution_and_rapid_score() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	_check(director.try_spawn_template_for_test(CollectibleDirector.OfferTemplate.HORIZONTAL_LINE, 4), "Spaced route score fixture spawns")
	var route := director.active_collectibles()
	route[0]._resolve(true)
	await process_frame
	_check(
		director.score == 1 and director.active_collectible_count() == 3,
		"Collecting one spaced-route coin does not remove or auto-collect siblings"
	)
	_free_conveyor(conveyor)

	conveyor = await _make_conveyor()
	director = _director(conveyor)
	_check(director.try_spawn_template_for_test(CollectibleDirector.OfferTemplate.COMPACT_BURST, 3), "Rapid-score fixture spawns")
	var pulse_before := director.score_hud_pulse_count()
	for coin in director.active_collectibles():
		coin._resolve(true)
	_check(
		director.score == 3
		and director.score_hud_pulse_count() == pulse_before + 3
		and director.score_hud_is_pulsing()
		and conveyor.get_node("HUD/ScoreGroup/CollectibleScore").text == "3",
		"Rapid collections increment once each and retrigger the central-number pulse safely"
	)
	director._process(director.score_hud_pulse_duration + 0.01)
	_check(
		conveyor.get_node("HUD/ScoreGroup/CollectibleScore").scale == Vector2.ONE,
		"Rapid collection pulse returns to the stable base scale"
	)
	_free_conveyor(conveyor)


func _test_restart_clears_score_and_pending_route() -> void:
	var change_error := change_scene_to_file(CONVEYOR_SCENE_PATH)
	_check(change_error == OK, "Restart fixture loads VM-0.4.5")
	await scene_changed
	await physics_frame
	var conveyor := current_scene as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	var director := _director(conveyor)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director.set_process(false)
	director.try_spawn_template_for_test(CollectibleDirector.OfferTemplate.STAGGERED_ROUTE, 4)
	director.active_collectible()._resolve(true)
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
		and restarted_director.pending_staggered_coin_count() == 0
		and restarted.get_node("HUD/ScoreGroup/CollectibleScore").text == "0"
		and restarted.get_node("HUD/ScoreGroup/CollectibleScore").scale == Vector2.ONE,
		"Restart clears score, pulse, active coins, and staggered pending state"
	)
	current_scene.queue_free()
	await process_frame


func _make_conveyor() -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	root.add_child(conveyor)
	await physics_frame
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	director_set_process(conveyor, false)
	return conveyor


func director_set_process(conveyor: ConveyorPrototype, enabled: bool) -> void:
	(conveyor.get_node("CollectibleDirector") as CollectibleDirector).set_process(enabled)


func _director(conveyor: ConveyorPrototype) -> CollectibleDirector:
	return conveyor.get_node("CollectibleDirector") as CollectibleDirector


func _free_conveyor(conveyor: ConveyorPrototype) -> void:
	if is_instance_valid(conveyor) and conveyor != current_scene:
		conveyor.queue_free()
	await process_frame
