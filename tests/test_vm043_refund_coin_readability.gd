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
	await _test_visual_identity_and_animation_geometry()
	await _test_desynchronized_dense_offer()
	await _test_collection_feedback_and_siblings()
	await _test_first_offer_teaching_cue()
	await _test_teaching_cue_timeout()
	await _test_restart_clears_visual_state()
	print("VM043_REFUND_COIN_READABILITY_FAILURES=%d" % _failures)
	quit(_failures)


func _test_visual_identity_and_animation_geometry() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	_check(director.try_spawn_for_test(), "Visual fixture spawns one Refund Coin")
	var coin := director.active_collectible()
	coin.set_physics_process(false)
	var collision_before := coin.collision_geometry_size()
	var world_position_before := coin.global_position
	var palette := coin.palette()
	_check(
		coin.visual_size() == Vector2(32.0, 32.0)
		and collision_before == Vector2(24.0, 24.0),
		"Round visual grows to 32 px while collection geometry remains 24 px"
	)
	_check(
		_luminance(palette.body) > 0.55
		and _luminance(palette.outline) < 0.15
		and palette.body.r > palette.body.g
		and palette.body.g > palette.body.b,
		"Gold face and dark outline retain contrast on representative backgrounds"
	)
	_check(
		palette.body != Color(0.24, 0.86, 0.82, 1.0)
		and palette.body != Color(0.92, 0.24, 0.20, 1.0),
		"Coin palette is distinct from the former cyan marker and red warnings"
	)
	coin._process(0.10)
	var spawn_scale := coin.current_visual_scale()
	coin._process(0.15)
	var settled_scale := coin.current_visual_scale()
	_check(
		spawn_scale.y != settled_scale.y
		and is_equal_approx(settled_scale.y, 1.0),
		"Spawn scale-pop settles into the normal looping state"
	)
	for _step in range(20):
		coin._process(0.05)
	_check(
		coin.collision_geometry_size() == collision_before
		and coin.global_position == world_position_before,
		"Spin, bob, glint, and spawn animation never move or resize collision geometry"
	)
	_check(
		absf(coin.visual_offset().y) <= coin.bob_amplitude + 0.001,
		"Visual bob remains inside its configured three-pixel amplitude"
	)
	_check(
		director._grounded_player_overlaps_y(
			director.band_center_y(CollectibleDirector.PlacementBand.GROUND)
		)
		and not director._grounded_player_overlaps_y(
			director.band_center_y(CollectibleDirector.PlacementBand.LOW_AIR)
		),
		"Visual bob preserves ground and low-air collision classifications"
	)
	_free_conveyor(conveyor)


func _test_desynchronized_dense_offer() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	_check(
		director.try_spawn_template_for_test(
			CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK,
			4
		),
		"Dense visual fixture spawns four sibling coins"
	)
	var coins := director.active_collectibles()
	var phases := PackedFloat32Array()
	var glint_times := PackedFloat32Array()
	for coin in coins:
		phases.append(coin.glint_phase_offset())
		glint_times.append(coin.next_glint_time())
	_check(
		phases[0] != phases[1]
		and glint_times[0] != glint_times[1],
		"Sibling spin and glint schedules are desynchronized"
	)
	var uniform_visuals := true
	for coin in coins:
		if (
			coin.visual_size() != Vector2(32.0, 32.0)
			or coin.collision_geometry_size() != Vector2(24.0, 24.0)
		):
			uniform_visuals = false
	_check(
		uniform_visuals,
		"Dense offers retain uniform readable visuals and unchanged hit areas"
	)
	_free_conveyor(conveyor)


func _test_collection_feedback_and_siblings() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	director.try_spawn_template_for_test(
		CollectibleDirector.OfferTemplate.HORIZONTAL_LINE,
		3
	)
	var coins := director.active_collectibles()
	var collected_coin := coins[0]
	collected_coin._resolve(true)
	_check(
		director.score == 1
		and collected_coin.collection_feedback_is_visible()
		and collected_coin.floating_plus_one_is_visible(),
		"Collection scores once and starts one burst plus floating +1"
	)
	_check(
		director.active_collectible_count() == 2,
		"Collecting one route coin leaves sibling coins active"
	)
	_check(
		director.score_hud_is_pulsing()
		and is_equal_approx(
			conveyor.get_node("HUD/ScoreGroup/CollectibleScore").scale.x,
			director.score_hud_pulse_scale
		),
		"Collection briefly emphasizes the COINS HUD"
	)
	collected_coin._resolve(true)
	_check(director.score == 1, "Feedback cannot retrigger scoring")
	director._process(director.score_hud_pulse_duration + 0.01)
	_check(
		not director.score_hud_is_pulsing()
		and conveyor.get_node("HUD/ScoreGroup/CollectibleScore").get_theme_font_size("font_size")
			== director.score_hud_normal_font_size,
		"HUD pulse returns to its normal state"
	)
	collected_coin._process(collected_coin.collection_feedback_duration + 0.01)
	await process_frame
	_check(not is_instance_valid(collected_coin), "Floating +1 and burst clean themselves up")
	_free_conveyor(conveyor)


func _test_first_offer_teaching_cue() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	conveyor.survival_time = director.first_spawn_time
	director._process(0.0)
	var first_coin := director.active_collectible()
	_check(
		director.teaching_cue_was_shown()
		and director.active_teaching_cue_count() == 1
		and first_coin != null
		and not first_coin.teaching_cue_blocks_input(),
		"First natural ground offer shows one non-blocking local teaching cue"
	)
	_check(
		first_coin.global_position.x + 72.0
			< conveyor.drop_lane_positions[0] - conveyor.product_size.x * 0.5,
		"Teaching cue remains spatially separate from hazard warning lanes"
	)
	first_coin._resolve(true)
	_check(
		not first_coin.teaching_cue_is_visible(),
		"Collecting the first coin immediately removes its teaching cue"
	)
	conveyor.survival_time = director.next_spawn_time()
	director._process(0.0)
	_check(
		director.active_teaching_cue_count() == 0,
		"Later offers do not duplicate the per-run teaching cue"
	)
	_free_conveyor(conveyor)


func _test_teaching_cue_timeout() -> void:
	var conveyor := await _make_conveyor()
	var director := _director(conveyor)
	conveyor.survival_time = director.first_spawn_time
	director._process(0.0)
	var coin := director.active_collectible()
	_check(coin.teaching_cue_is_visible(), "Timeout fixture starts with a visible cue")
	coin._process(director.first_offer_teaching_cue_timeout + 0.01)
	_check(not coin.teaching_cue_is_visible(), "Teaching cue removes itself at its configured timeout")
	_free_conveyor(conveyor)


func _test_restart_clears_visual_state() -> void:
	var change_error := change_scene_to_file(CONVEYOR_SCENE_PATH)
	_check(change_error == OK, "Visual restart fixture loads Prototype B")
	await scene_changed
	await physics_frame
	var conveyor := current_scene as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	var director := _director(conveyor)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	conveyor.survival_time = director.first_spawn_time
	director._process(0.0)
	var old_coin := director.active_collectible()
	old_coin._resolve(true)
	_check(
		director.score_hud_is_pulsing()
		and old_coin.collection_feedback_is_visible(),
		"Restart fixture contains active HUD and collection feedback"
	)
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
		and not restarted_director.score_hud_is_pulsing()
		and restarted_director.active_teaching_cue_count() == 0
		and restarted.get_node("HUD/ScoreGroup/CollectibleScore").get_theme_font_size("font_size")
			== restarted_director.score_hud_normal_font_size,
		"Restart clears score, cue state, feedback state, and HUD animation"
	)
	_check(not is_instance_valid(old_coin), "Restart frees the previous visual-effect instance")


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


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
