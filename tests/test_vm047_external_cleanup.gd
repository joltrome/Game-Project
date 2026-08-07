extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const ARENA_SCENE_PATH := "res://scenes/prototypes/arena.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const TEST_SEEDS := [401, 1701, 4202]
const ASCII_CONTROLS := "MOVE: A/D or LEFT/RIGHT\nJUMP: SPACE\nRESTART: R"

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
	await _test_visual_cleanup_and_ascii_controls()
	await _test_baseline_and_corrected_side_distribution()
	print("VM047_EXTERNAL_CLEANUP_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_visual_cleanup_and_ascii_controls() -> void:
	var conveyor := (load(CONVEYOR_SCENE_PATH) as PackedScene).instantiate() as ConveyorPrototype
	root.add_child(conveyor)
	await physics_frame
	_check(
		conveyor.get_node_or_null("ControlBand/LeftMarker") == null
		and conveyor.get_node_or_null("ControlBand/RightWall/Visual") == null,
		"Nonfunctional orange side-pillar visuals are absent"
	)
	var right_wall := conveyor.get_node_or_null("ControlBand/RightWall") as StaticBody2D
	var right_shape := conveyor.get_node_or_null("ControlBand/RightWall/CollisionShape2D") as CollisionShape2D
	_check(
		right_wall != null
		and right_shape != null
		and right_shape.shape is RectangleShape2D
		and (right_shape.shape as RectangleShape2D).size == Vector2(16.0, 208.0),
		"Right control-band collision remains unchanged after visual removal"
	)
	var background := conveyor.get_node("Background") as Polygon2D
	_check(
		background.polygon.has(Vector2(96.0, 150.0))
		and background.polygon.has(Vector2(1056.0, 584.0)),
		"Existing background still covers the playfield behind removed pillars"
	)
	_check(
		(conveyor.get_node("HUD/Controls") as Label).text == ASCII_CONTROLS,
		"Prototype B displays the exact ASCII-safe controls"
	)
	_check(
		(conveyor.get_node("HUD/BuildId") as Label).text == "BUILD VM-0.4.7",
		"Prototype B exposes the VM-0.4.7 build ID"
	)
	conveyor.queue_free()
	await process_frame

	var arena := (load(ARENA_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	_check(
		(arena.get_node("HUD/Controls") as Label).text == ASCII_CONTROLS,
		"Frozen Prototype A uses the same ASCII-safe controls without gameplay changes"
	)
	arena.queue_free()
	await process_frame

	var movement_lab := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(movement_lab)
	await physics_frame
	var movement_controls := (
		movement_lab.get_node("HUD/Margin/Readout/Controls") as Label
	).text
	_check(
		movement_controls == ASCII_CONTROLS
		and _is_ascii_safe(movement_controls),
		"Movement laboratory control text contains no Unicode or replacement glyph"
	)
	movement_lab.queue_free()
	await process_frame


func _test_baseline_and_corrected_side_distribution() -> void:
	var baseline_directors: Array[CollectibleDirector] = []
	var corrected_directors: Array[CollectibleDirector] = []
	var conveyors: Array[ConveyorPrototype] = []
	for seed in TEST_SEEDS:
		var baseline := await _make_natural_fixture(seed, false)
		conveyors.append(baseline)
		baseline_directors.append(baseline.get_node("CollectibleDirector") as CollectibleDirector)
		var corrected := await _make_natural_fixture(seed, true)
		conveyors.append(corrected)
		corrected_directors.append(corrected.get_node("CollectibleDirector") as CollectibleDirector)

	while conveyors[0].survival_time < 59.95:
		await physics_frame
		for director in baseline_directors + corrected_directors:
			for coin in director.active_collectibles():
				coin._resolve(true)

	var baseline_max_behind := 0
	var corrected_max_behind := 0
	var corrected_low_risk_offers := 0
	var corrected_risky_multi_offers := 0
	for index in range(TEST_SEEDS.size()):
		var baseline_metrics := _side_metrics(baseline_directors[index])
		var corrected_metrics := _side_metrics(corrected_directors[index])
		baseline_max_behind = maxi(baseline_max_behind, int(baseline_metrics.longest_behind))
		corrected_max_behind = maxi(corrected_max_behind, int(corrected_metrics.longest_behind))
		corrected_low_risk_offers += int(corrected_metrics.low_risk_offers)
		corrected_risky_multi_offers += int(corrected_metrics.risky_multi_offers)
		print(
			"VM047_SIDE_AUDIT mode=baseline seed=%d ahead=%d centred=%d behind=%d longest_behind=%d behind_types=%s longest_ahead=%d ahead_types=%s"
			% [
				TEST_SEEDS[index],
				baseline_metrics.counts[CollectibleDirector.OfferSide.AHEAD],
				baseline_metrics.counts[CollectibleDirector.OfferSide.CENTRED],
				baseline_metrics.counts[CollectibleDirector.OfferSide.BEHIND],
				baseline_metrics.longest_behind,
				baseline_metrics.longest_behind_types,
				baseline_metrics.longest_ahead,
				baseline_metrics.longest_ahead_types,
			]
		)
		print(
			"VM047_SIDE_AUDIT mode=corrected seed=%d ahead=%d centred=%d behind=%d longest_behind=%d behind_types=%s longest_ahead=%d ahead_types=%s corrections=%d"
			% [
				TEST_SEEDS[index],
				corrected_metrics.counts[CollectibleDirector.OfferSide.AHEAD],
				corrected_metrics.counts[CollectibleDirector.OfferSide.CENTRED],
				corrected_metrics.counts[CollectibleDirector.OfferSide.BEHIND],
				corrected_metrics.longest_behind,
				corrected_metrics.longest_behind_types,
				corrected_metrics.longest_ahead,
				corrected_metrics.longest_ahead_types,
				corrected_metrics.low_risk_offers,
			]
		)

	_check(
		baseline_max_behind > 2,
		"Uncorrected natural scheduler reproduces more than two consecutive behind offers"
	)
	_check(
		corrected_max_behind <= 2,
		"Configured anti-streak correction caps deterministic behind streaks at two"
	)
	_check(
		corrected_low_risk_offers > 0,
		"Anti-streak correction naturally launches centred/ahead one-coin opportunities"
	)
	_check(
		corrected_risky_multi_offers > 0,
		"Rearward commitment routes retain multi-coin upside"
	)
	for conveyor in conveyors:
		conveyor.queue_free()
	await process_frame


func _make_natural_fixture(
	seed: int,
	correction_enabled: bool
) -> ConveyorPrototype:
	var conveyor := (load(CONVEYOR_SCENE_PATH) as PackedScene).instantiate() as ConveyorPrototype
	conveyor.left_failure_enabled = false
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.placement_seed = seed
	director.side_distribution_correction_enabled = correction_enabled
	root.add_child(conveyor)
	await physics_frame
	conveyor.player.position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	return conveyor


func _side_metrics(director: CollectibleDirector) -> Dictionary:
	var counts := PackedInt32Array([0, 0, 0])
	var current_behind: Array[String] = []
	var current_ahead: Array[String] = []
	var longest_behind: Array[String] = []
	var longest_ahead: Array[String] = []
	var low_risk_offers := 0
	var risky_multi_offers := 0
	for entry in director.offer_log():
		if entry.event != "attempt" or not entry.accepted:
			continue
		_check(
			entry.has("player_x")
			and entry.has("offer_primary_x")
			and entry.has("offer_side")
			and entry.has("offer_side_name"),
			"Accepted natural offer records actionable player-relative side instrumentation"
		)
		var side := int(entry.offer_side)
		counts[side] += 1
		if side == CollectibleDirector.OfferSide.BEHIND:
			current_behind.append(String(entry.template_name))
			current_ahead.clear()
			if current_behind.size() > longest_behind.size():
				longest_behind = current_behind.duplicate()
			if int(entry.intended_count) >= 3:
				risky_multi_offers += 1
		elif side == CollectibleDirector.OfferSide.AHEAD:
			current_ahead.append(String(entry.template_name))
			current_behind.clear()
			if current_ahead.size() > longest_ahead.size():
				longest_ahead = current_ahead.duplicate()
		else:
			current_behind.clear()
			current_ahead.clear()
		if bool(entry.anti_streak_requested):
			_check(
				side != CollectibleDirector.OfferSide.BEHIND
				and int(entry.intended_count) == 1
				and int(entry.ground_count) == 1
				and int(entry.air_count) == 0,
				"Accepted correction is centred/ahead, grounded, and worth exactly one coin"
			)
			low_risk_offers += 1
	return {
		"counts": counts,
		"longest_behind": longest_behind.size(),
		"longest_behind_types": longest_behind,
		"longest_ahead": longest_ahead.size(),
		"longest_ahead_types": longest_ahead,
		"low_risk_offers": low_risk_offers,
		"risky_multi_offers": risky_multi_offers,
	}


func _is_ascii_safe(value: String) -> bool:
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint > 127 or codepoint == 0xfffd:
			return false
	return true
