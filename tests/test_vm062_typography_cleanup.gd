extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const VIS04 := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
		return
	failures += 1
	push_error(message)


func run() -> void:
	root.size = Vector2i(1152, 648)
	await _check_frozen_experiment_default()
	await _check_standard_typography()
	print("VM062_TYPOGRAPHY_CLEANUP_FAILURES=", failures)
	quit(failures)


func _check_frozen_experiment_default() -> void:
	var experiment := VIS04.instantiate() as MotionExperimentShell
	root.add_child(experiment)
	await process_frame
	var foreground := experiment.conveyor.get_node("MotionArcadeForeground") as MotionArcadeVisual
	check(
		not foreground.c2_typography_is_enabled()
		and foreground.get_node_or_null("C2ProductBay") == null,
		"Standalone VIS-04 keeps its frozen typography default"
	)
	experiment.queue_free()
	await process_frame


func _check_standard_typography() -> void:
	var session := SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = "/tmp/vms-typography-cleanup.cfg"
	root.add_child(session)
	session.audio.music.volume_db = -80.0
	session.start_game()
	await process_frame
	var foreground := session.game.conveyor.get_node("MotionArcadeForeground") as MotionArcadeVisual
	var expected := {
		"C2ProductBay": "PRODUCT BAY",
		"C2VendElevator": "VEND ELEVATOR",
		"C2Out": "OUT",
	}
	var environmental_ok := foreground.c2_typography_is_enabled()
	for node_name: String in expected:
		var label := foreground.get_node_or_null(node_name) as C2PixelText
		environmental_ok = environmental_ok and label != null
		if label != null:
			environmental_ok = (
				environmental_ok
				and label.text == expected[node_name]
				and label.family == "small"
				and label.glyph_scale == 2
				and label.supports_text(label.text)
			)
	check(environmental_ok, "PRODUCT BAY, VEND ELEVATOR and OUT use C2 small text at 2x")

	var director := session.game.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.set_process(false)
	check(director.try_spawn_band_for_test(CollectibleDirector.PlacementBand.GROUND), "Typography fixture spawns a Refund Coin")
	await process_frame
	var coin := director.active_collectible()
	var teaching_parent := coin.get_node("TeachingCue/Label") as Label
	var teaching := teaching_parent.get_node_or_null("C2Text") as C2PixelText
	var feedback_parent := coin.get_node("CollectionFeedback/PlusOne") as Label
	var feedback := feedback_parent.get_node_or_null("C2Text") as C2PixelText
	check(
		coin.c2_typography_is_enabled()
		and teaching != null
		and teaching.text == "REFUND COIN +1"
		and teaching.family == "small"
		and teaching.glyph_scale == 2
		and teaching.supports_text(teaching.text)
		and teaching_parent.size.x == 156.0,
		"Refund Coin teaching cue uses the complete C2 small-text wording without clipping"
	)
	check(
		feedback != null
		and feedback.text == "+1"
		and feedback.family == "display"
		and feedback.glyph_scale == 2
		and feedback.supports_text(feedback.text),
		"Transient +1 uses C2 display numerals and the matching integer-grid plus"
	)
	check(
		teaching_parent.get_theme_color("font_color").a == 0.0
		and feedback_parent.get_theme_color("font_color").a == 0.0,
		"Fallback font ink is hidden only on Standard-mode coin instances"
	)
	coin.show_teaching_cue()
	check(coin.teaching_cue_is_visible() and teaching.is_visible_in_tree(), "C2 teaching cue retains its existing trigger")
	var score_before := director.score
	coin._resolve(true)
	check(
		director.score == score_before + 1
		and coin.collection_feedback_is_visible()
		and feedback.is_visible_in_tree(),
		"Collection still scores exactly once and shows the C2 +1 feedback"
	)
	coin._resolve(true)
	check(director.score == score_before + 1, "Typography migration cannot retrigger scoring")

	var rotate := session.touch.get_node_or_null("RotateGuidance") as C2PixelText
	check(
		rotate != null
		and rotate.text == "ROTATE DEVICE"
		and rotate.family == "small"
		and rotate.glyph_scale == 3,
		"Portrait guidance uses the existing C2 small-text family"
	)
	var player_values := [
		session.game.conveyor.player.maximum_speed,
		session.game.conveyor.player.gravity,
		session.game.conveyor.player.jump_velocity,
		session.game.conveyor.conveyor_speed,
		session.game.conveyor.product_falling_collision_size,
		session.game.conveyor.landed_product_size,
	]
	print("VM062_TYPOGRAPHY_FROZEN_VALUES=", player_values)
	check(
		is_equal_approx(player_values[0], 300.0)
		and is_equal_approx(player_values[1], 2400.0)
		and is_equal_approx(player_values[2], -700.0)
		and absf(player_values[3] - 140.0) < 0.001
		and player_values[4] == Vector2(60.0, 60.0)
		and player_values[5] == Vector2(72.0, 48.0),
		"Standard movement, conveyor and product geometry values remain frozen"
	)
	session.pause_game()
	check(session.state == StandardSession.State.PAUSED, "Pause flow remains available")
	session.resume_game()
	session.game.conveyor._kill_player(ConveyorPrototype.DeathCause.UNKNOWN)
	await process_frame
	await process_frame
	check(session.state == StandardSession.State.DEATH_BEAT, "Game-to-results death flow remains intact")
	session.show_menu()
	session.queue_free()
	await process_frame
	DirAccess.remove_absolute("/tmp/vms-typography-cleanup.cfg")
