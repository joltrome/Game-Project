extends SceneTree
const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const Cause := ConveyorPrototype.DeathCause
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)
func run() -> void:
	root.size = Vector2i(1152,648)
	var s := SESSION.instantiate() as StandardSession
	s.score_storage_path = "/tmp/vms-rc1-death-test.cfg"
	DirAccess.remove_absolute(s.score_storage_path)
	root.add_child(s)
	await process_frame
	check(root.title == "GET CANNED!" and s._c2.buttons[0].text == "CLOCK IN", "C2 title and CLOCK IN")
	check(s._c2.buttons[0].get_rect() == Rect2(416,472,320,70), "Work CTA hit region")
	check(s._c2.buttons[0].has_focus(), "Initial keyboard focus")
	check(not s.touch.buttons[0].visible, "Desktop hides touch controls")
	s._music_button.grab_focus()
	s._music_button.pressed.emit()
	check(s.audio.is_muted(&"Music") and s._music_button.has_focus() and s._music_button.get_meta(&"art_key") == "music-off", "Music toggle updates art without losing focus")
	s._music_button.pressed.emit()
	s._sfx_button.pressed.emit()
	check(s.audio.is_muted(&"SFX") and not s.audio.is_muted(&"Music"), "SFX button stays independent")
	s._sfx_button.pressed.emit()
	s._c2.buttons[0].grab_focus()
	var mouse := InputEventMouseButton.new()
	mouse.position=Vector2(576,507)
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.button_mask=MOUSE_BUTTON_MASK_LEFT
	mouse.pressed=true
	root.push_input(mouse,true)
	Input.flush_buffered_events()
	check((s._c2.buttons[0].get_node("Artwork") as TextureRect).texture.resource_path.ends_with("/pressed.png"), "Mouse-down selects exact pressed art")
	mouse=mouse.duplicate()
	mouse.pressed=false
	mouse.button_mask=0
	root.push_input(mouse,true)
	Input.flush_buffered_events()
	check(s.state == StandardSession.State.GAME, "Mouse release on CLOCK IN starts gameplay")
	s.show_menu()
	var mappings := {Cause.FALLING_PRODUCT:"CANNED.", Cause.BACKGROUND_PRODUCT:"CANNED.", Cause.RETRIEVAL_CARRIAGE:"GRABBED.", Cause.LEFT_OUT:"VENDED.", Cause.UNKNOWN:"GAME OVER."}
	for cause: int in mappings:
		s.start_game()
		var c := s.game.conveyor
		var round_controller := c.get_node("RoundController") as FixedRoundController
		var coins := c.get_node("CollectibleDirector") as CollectibleDirector
		coins.try_spawn_band_for_test(CollectibleDirector.PlacementBand.GROUND)
		var coin := coins.active_collectible()
		round_controller.force_time_remaining_for_test(0.001)
		var before := s.result_transition_count
		var began := Time.get_ticks_msec()
		match cause:
			Cause.FALLING_PRODUCT, Cause.BACKGROUND_PRODUCT:
				var product: FallingProduct
				if cause == Cause.BACKGROUND_PRODUCT:
					product = c.spawn_external_conveyor_product(600,200,1.0,"rc1-test")
					check(product != null and product.get_meta(&"background_product",false), "D3 production spawn marks its source")
				else:
					product = preload("res://scenes/hazards/falling_product.tscn").instantiate() as FallingProduct
					c.get_node("Hazards").add_child(product)
				c._on_product_hit(product)
				product.queue_free()
			Cause.RETRIEVAL_CARRIAGE: c._on_sweeper_hit(null)
			Cause.LEFT_OUT: c._on_off_belt_kill_region_body_entered(c.player)
			_: c._kill_player()
		c._kill_player(Cause.LEFT_OUT if cause != Cause.LEFT_OUT else Cause.FALLING_PRODUCT)
		round_controller._process(1.0)
		check(c.death_cause == cause and round_controller.ended_by_death(), "First cause wins over another contact and late completion: %s" % mappings[cause])
		check(s.state != StandardSession.State.RESULTS, "No result on lethal frame")
		await process_frame
		await process_frame
		check(s.state == StandardSession.State.DEATH_BEAT and s.game.visible and not c.player.is_physics_processing(), "Visible death beat disables player")
		check(s.game.process_mode == Node.PROCESS_MODE_DISABLED and not c.get_node("HUD/DeathMessage").visible, "Complete world hold without old death copy")
		if is_instance_valid(coin): coin._on_body_entered(c.player)
		var restart := InputEventAction.new()
		restart.action = "restart"
		restart.pressed = true
		s._unhandled_input(restart)
		check(s.state == StandardSession.State.DEATH_BEAT and coins.score == 0, "Retry input and collection cannot mutate death beat")
		await create_timer(0.3).timeout
		check(s.state == StandardSession.State.DEATH_BEAT, "Death still held after 0.3 seconds")
		while s.state == StandardSession.State.DEATH_BEAT:
			await process_frame
		var duration := (Time.get_ticks_msec()-began)/1000.0
		check(duration >= 0.73 and duration < 0.90, "Death delay %.3f seconds" % duration)
		check(s.result_headline == mappings[cause] and s.result_transition_count == before+1 and not s.last_survived, "Exactly one correct result: %s" % mappings[cause])
		check(round_controller.round_time_remaining == 0.001 and coins.score == 0, "Timer and score frozen through result")
	# Completion first rejects a later lethal callback.
	s.start_game()
	var completed := s.game.conveyor
	(completed.get_node("RoundController") as FixedRoundController)._complete_round()
	completed._kill_player(Cause.LEFT_OUT)
	await process_frame
	await process_frame
	check(s.result_headline == "CLOCKED OUT." and not completed.is_dead, "Completion first stays completion")
	# A stale deferred callback from a disposed run must not affect a new run.
	var old_serial := s._run_serial
	s.start_game()
	s._on_death(999,0,old_serial)
	s._on_completion(999,old_serial)
	check(s.state == StandardSession.State.GAME and s.last_death_cause == Cause.UNKNOWN, "Disposed run callbacks cannot finish retry")
	# Work's widest dynamic values fit, including the entire supported score range.
	s._show_results(9223372036854775807,true)
	check(s.result_score.text == "9223372036854775807" and s.result_score.ink_width(s.result_score.text,s.result_score.glyph_scale) <= 232, "Result int64 score never truncates")
	s.show_menu()
	check(s.best_label.ink_width(s.best_label.text,s.best_label.glyph_scale) <= 176, "Menu int64 best fits")
	s.queue_free()
	await process_frame
	DirAccess.remove_absolute("/tmp/vms-rc1-death-test.cfg")
	print("VM061_DEATH_UI_FAILURES=",failures)
	quit(failures)
