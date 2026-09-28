extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const EPSILON := 0.02

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func check_rect(actual: Rect2, expected: Rect2, message: String) -> void:
	check(
		actual.position.distance_to(expected.position) <= EPSILON
		and actual.size.distance_to(expected.size) <= EPSILON,
		message + " actual=%s expected=%s" % [actual, expected]
	)


func finger(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func run() -> void:
	root.size = Vector2i(1152, 648)
	await _test_exact_layouts_and_assets()
	await _test_multitouch_and_lifecycle()
	await _test_session_monitor_and_desktop_behavior()
	print("VM072_MOBILE_ARCADE_DECK_FAILURES=", failures)
	quit(failures)


func _new_touch() -> StandardTouchControls:
	var touch := StandardTouchControls.new()
	root.add_child(touch)
	await process_frame
	touch.touch_available = true
	touch.set_game_active(true)
	return touch


func _configure_exact(touch: StandardTouchControls, viewport: Vector2, insets: Vector4) -> void:
	touch.configure_viewport(
		viewport,
		Rect2(Vector2.ZERO, viewport),
		viewport,
		3.0,
		insets
	)


func _test_exact_layouts_and_assets() -> void:
	var touch := await _new_touch()
	_configure_exact(touch, Vector2(640.0, 360.0), Vector4(16.0, 8.0, 16.0, 12.0))
	check_rect(touch.gameplay_bounds, Rect2(110.222, 8.0, 419.556, 236.0), "16:9 monitor matches Work handoff")
	check_rect(touch.deck_surface_rect, Rect2(8.0, 252.0, 624.0, 96.0), "16:9 deck surface matches Work handoff")
	check_rect(touch.deck_control_rect, Rect2(16.0, 252.0, 608.0, 96.0), "16:9 safe deck region matches Work handoff")
	check_rect(touch.rectangles[0], Rect2(24.0, 256.0, 72.0, 88.0), "16:9 LEFT hit rect matches Work handoff")
	check_rect(touch.rectangles[1], Rect2(104.0, 256.0, 72.0, 88.0), "16:9 RIGHT hit rect matches Work handoff")
	check_rect(touch.rectangles[2], Rect2(520.0, 252.0, 96.0, 96.0), "16:9 action hit rect matches Work handoff")
	check_rect(touch.visual_rectangles[0], Rect2(28.0, 268.0, 64.0, 64.0), "16:9 LEFT art rect matches Work handoff")
	check_rect(touch.visual_rectangles[1], Rect2(108.0, 268.0, 64.0, 64.0), "16:9 RIGHT art rect matches Work handoff")
	check_rect(touch.visual_rectangles[2], Rect2(528.0, 260.0, 80.0, 80.0), "16:9 action art rect matches Work handoff")
	check_rect(touch.pause_hit_rect, Rect2(541.778, 12.0, 48.0, 48.0), "16:9 Pause placement matches Work handoff")
	_check_layout_contract(touch, "16:9")
	var scale_16 := touch.gameplay_bounds.size.x / 1152.0
	var technician_16 := Vector2(50.0, 60.0) * scale_16
	check(
		technician_16.distance_to(Vector2(18.21, 21.85)) < 0.03,
		"16:9 technician estimate remains approximately 18.21x21.85 CSS pixels"
	)
	touch.configure_viewport(
		Vector2(1152.0, 648.0),
		Rect2(Vector2.ZERO, Vector2(1152.0, 648.0)),
		Vector2(640.0, 360.0),
		3.0,
		Vector4(16.0, 8.0, 16.0, 12.0)
	)
	check(
		(touch.pause_hit_rect.size / Vector2(1.8, 1.8)).distance_to(Vector2(48.0, 48.0)) < 0.02
		and (touch._pause_art.size / Vector2(1.8, 1.8)).distance_to(Vector2(32.0, 32.0)) < 0.02,
		"Host-space conversion preserves 48 CSS px Pause hit and 32 CSS px art"
	)

	_configure_exact(touch, Vector2(844.0, 390.0), Vector4(24.0, 8.0, 24.0, 16.0))
	check_rect(touch.gameplay_bounds, Rect2(189.111, 8.0, 465.778, 262.0), "19.5:9 monitor matches Work handoff")
	check_rect(touch.deck_surface_rect, Rect2(8.0, 278.0, 828.0, 96.0), "19.5:9 deck surface matches Work handoff")
	check_rect(touch.rectangles[0], Rect2(32.0, 282.0, 72.0, 88.0), "19.5:9 LEFT hit rect matches Work handoff")
	check_rect(touch.rectangles[1], Rect2(112.0, 282.0, 72.0, 88.0), "19.5:9 RIGHT hit rect matches Work handoff")
	check_rect(touch.rectangles[2], Rect2(716.0, 278.0, 96.0, 96.0), "19.5:9 action hit rect matches Work handoff")
	check_rect(touch.pause_hit_rect, Rect2(666.889, 12.0, 48.0, 48.0), "19.5:9 Pause placement matches Work handoff")
	_check_layout_contract(touch, "19.5:9")
	var scale_wide := touch.gameplay_bounds.size.x / 1152.0
	var technician_wide := Vector2(50.0, 60.0) * scale_wide
	check(
		technician_wide.distance_to(Vector2(20.22, 24.26)) < 0.03,
		"19.5:9 technician estimate remains approximately 20.22x24.26 CSS pixels"
	)

	for scenario in [Vector2(780.0, 390.0), Vector2(866.667, 390.0)]:
		touch.configure_viewport(
			scenario,
			Rect2(Vector2.ZERO, scenario),
			scenario,
			8.0
		)
		_check_layout_contract(touch, "%.3f aspect" % (scenario.x / scenario.y))
		check(touch.effective_dpr == 3.0, "Extreme DPR remains clamped for %s" % scenario)

	check(
		touch._art[0].texture.get_size() == Vector2(64.0, 64.0)
		and touch._art[1].texture.get_size() == Vector2(64.0, 64.0)
		and touch._art[2].texture.get_size() == Vector2(80.0, 80.0),
		"Approved direction/action assets retain exact native canvases"
	)
	check(
		touch._art.all(func(item: TextureRect) -> bool: return item.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST),
		"All arcade control art uses nearest-neighbor filtering"
	)
	check(
		touch.get_children().filter(func(node: Node) -> bool: return node is C2PixelText).size() == 1,
		"Deck contains icon art only; no LEFT/RIGHT/JUMP text labels were added"
	)

	touch.configure_viewport(
		Vector2(390.0, 844.0),
		Rect2(Vector2.ZERO, Vector2(390.0, 844.0)),
		Vector2(390.0, 844.0),
		3.0
	)
	check(
		touch._rotate.visible
		and touch.buttons.all(func(button: TouchScreenButton) -> bool: return not button.visible)
		and touch.deck_surface_rect.size == Vector2.ZERO,
		"Portrait shows ROTATE DEVICE and does not present playable deck controls"
	)
	touch.queue_free()
	await process_frame


func _check_layout_contract(touch: StandardTouchControls, label: String) -> void:
	check(is_equal_approx(touch.gameplay_bounds.size.aspect(), 16.0 / 9.0), label + " monitor preserves 16:9 gameplay aspect")
	var controls_clear := true
	var hits_inside := true
	var art_inside := true
	for i in touch.rectangles.size():
		controls_clear = controls_clear and not touch.rectangles[i].intersects(touch.gameplay_bounds)
		hits_inside = hits_inside and touch.deck_control_rect.encloses(touch.rectangles[i])
		art_inside = art_inside and touch.rectangles[i].encloses(touch.visual_rectangles[i])
	check(controls_clear, label + " hit regions never overlap the gameplay monitor")
	check(hits_inside, label + " hit regions remain within the safe deck")
	check(art_inside, label + " visible art stays inside its larger hit region")
	check(not touch.pause_hit_rect.intersects(touch.deck_surface_rect), label + " Pause remains outside the deck")
	check(
		is_equal_approx(touch.pause_hit_rect.position.x, touch.gameplay_bounds.end.x + 12.0 * touch.logical_per_css),
		label + " Pause remains beside the monitor bezel"
	)


func _test_multitouch_and_lifecycle() -> void:
	var touch := await _new_touch()
	_configure_exact(touch, Vector2(844.0, 390.0), Vector4(24.0, 8.0, 24.0, 16.0))
	var left := touch.rectangles[0].get_center()
	var right := touch.rectangles[1].get_center()
	var jump := touch.rectangles[2].get_center()
	finger(0, right, true)
	for index in range(1, 6):
		finger(index, jump, true)
		check(
			Input.is_action_pressed("move_right") and Input.is_action_pressed("jump"),
			"RIGHT stays held while repeated JUMP press %d is active" % index
		)
		finger(index, jump, false)
		check(
			Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"),
			"JUMP release %d leaves RIGHT held" % index
		)
	drag(0, left)
	check(
		Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"),
		"RIGHT-to-LEFT slide switches direction without overlap"
	)
	drag(0, right)
	check(
		Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"),
		"LEFT-to-RIGHT slide switches direction without overlap"
	)
	finger(1, jump, true)
	check(touch._art[2].texture == touch.CONTROL_ART[2][touch.PRESSED], "Action art enters approved depressed state immediately")
	touch.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(
		not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"),
		"Focus loss clears simultaneous direction and jump"
	)
	finger(0, right, false)
	finger(1, jump, false)
	touch.set_game_active(true)
	check(
		touch.buttons.all(func(button: TouchScreenButton) -> bool: return button.visible and not button.is_pressed()),
		"Resume/retry reinitializes all three input owners cleanly"
	)
	touch.queue_free()
	await process_frame


func _test_session_monitor_and_desktop_behavior() -> void:
	var session := SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = "/tmp/vm072-score.cfg"
	root.add_child(session)
	await process_frame
	check(session.mobile_arcade_deck_enabled, "Release scene opts into VM-0.7.2 mobile arcade deck")
	session.start_game()
	await process_frame
	session.touch.touch_available = true
	session.touch.configure_viewport(
		Vector2(1152.0, 648.0),
		Rect2(Vector2.ZERO, Vector2(1152.0, 648.0)),
		Vector2(640.0, 360.0),
		3.0,
		Vector4(16.0, 8.0, 16.0, 12.0)
	)
	session._layout()
	check(
		session.game.build_id_override == "VM-0.7.3-COIN-PRESSURE",
		"Forward release build ID identifies the VM-0.7.3 experiment"
	)
	check(
		session.game.position.distance_to(session.touch.gameplay_bounds.position) <= EPSILON
		and session.game.size.distance_to(session.touch.gameplay_bounds.size) <= EPSILON,
		"Live Standard scene is proportionally contained in the touch monitor"
	)
	var right := session.touch.rectangles[1].get_center()
	var jump := session.touch.rectangles[2].get_center()
	finger(0, right, true)
	finger(1, jump, true)
	session.pause_game()
	check(
		session.state == StandardSession.State.PAUSED
		and not Input.is_action_pressed("move_right")
		and not Input.is_action_pressed("jump"),
		"Pause clears held mobile inputs"
	)
	session.resume_game()
	check(
		session.state == StandardSession.State.GAME
		and session.touch.buttons.size() == 3
		and session.touch.buttons.all(func(button: TouchScreenButton) -> bool: return not button.is_pressed()),
		"Resume restores exactly three clean gameplay input nodes"
	)
	finger(0, right, false)
	finger(1, jump, false)
	for _retry in range(3):
		session.start_game()
		await process_frame
	check(
		session.touch.buttons.size() == 3
		and session.get_children().filter(func(node: Node) -> bool: return node.name == "StandardRun").size() == 1,
		"Repeated Retry does not accumulate input or game nodes"
	)

	finger(0, session.touch.rectangles[1].get_center(), true)
	session._on_death(0, 30.0, session._run_serial)
	await process_frame
	check(
		session.state == StandardSession.State.DEATH_BEAT
		and not Input.is_action_pressed("move_right"),
		"Death clears held movement before results"
	)
	finger(0, session.touch.rectangles[1].get_center(), false)
	session.start_game()
	await process_frame

	session.touch.touch_available = false
	session._layout()
	check(
		session.game.position == Vector2.ZERO
		and session.game.size == session.size
		and session.touch.buttons.all(func(button: TouchScreenButton) -> bool: return not button.visible)
		and session.touch.pause_button.position == Vector2(8.0, 8.0),
		"Normal desktop layout and keyboard presentation remain unchanged"
	)
	check(
		InputMap.action_has_event("move_left", InputMap.action_get_events("move_left")[0])
		and InputMap.has_action("move_right")
		and InputMap.has_action("jump")
		and InputMap.has_action("pause"),
		"Existing desktop movement, jump, and Pause bindings remain registered"
	)
	session.show_menu()
	session.queue_free()
	await process_frame
