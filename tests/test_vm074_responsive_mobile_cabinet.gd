extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const INTERNAL_SIZE := Vector2i(1152, 648)
const EPSILON := 0.06

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


func run() -> void:
	root.size = INTERNAL_SIZE
	await _test_responsive_geometry()
	await _test_real_standard_render_surface()
	await _test_layout_switch_releases_input()
	print("VM074_RESPONSIVE_MOBILE_CABINET_FAILURES=", failures)
	quit(failures)


func _new_touch() -> StandardTouchControls:
	var touch := StandardTouchControls.new()
	root.add_child(touch)
	await process_frame
	touch.touch_available = true
	touch.responsive_side_wings_enabled = true
	touch.set_game_active(true)
	return touch


func _configure(touch: StandardTouchControls, viewport: Vector2, insets: Vector4) -> void:
	touch.configure_viewport(
		viewport,
		Rect2(Vector2.ZERO, viewport),
		viewport,
		3.0,
		insets
	)


func _test_responsive_geometry() -> void:
	var touch := await _new_touch()
	_configure(touch, Vector2(640.0, 360.0), Vector4(16.0, 8.0, 16.0, 12.0))
	_verify_layout(touch, StandardTouchControls.CabinetLayout.BOTTOM_DECK, "16:9")
	check_rect(touch.gameplay_bounds, Rect2(110.222, 8.0, 419.556, 236.0), "16:9 retains approved bottom monitor")
	_print_metrics(touch, "16:9")

	_configure(touch, Vector2(780.0, 390.0), Vector4(20.5714, 8.0, 20.5714, 14.2857))
	_verify_layout(touch, StandardTouchControls.CabinetLayout.BOTTOM_DECK, "18:9")
	check_rect(touch.gameplay_bounds, Rect2(155.587, 8.0, 468.825, 263.714), "18:9 chooses the larger bottom-deck fit")
	_print_metrics(touch, "18:9")

	_configure(touch, Vector2(844.0, 390.0), Vector4(24.0, 8.0, 24.0, 16.0))
	_verify_layout(touch, StandardTouchControls.CabinetLayout.SIDE_WINGS, "19.5:9")
	check_rect(touch.gameplay_bounds, Rect2(200.0, 50.375, 500.0, 281.25), "19.5:9 uses the approved side-wing monitor")
	check_rect(touch.rectangles[0], Rect2(32.0, 270.0, 72.0, 88.0), "19.5:9 LEFT wing hit")
	check_rect(touch.rectangles[1], Rect2(112.0, 270.0, 72.0, 88.0), "19.5:9 RIGHT wing hit")
	check_rect(touch.rectangles[2], Rect2(716.0, 266.0, 96.0, 96.0), "19.5:9 action wing hit")
	check_rect(touch.pause_hit_rect, Rect2(740.0, 20.0, 48.0, 48.0), "19.5:9 Pause remains separate in upper-right bezel wing")
	var bottom_195_area := 465.7778 * 262.0
	var wing_195_area := touch.gameplay_bounds.size.x * touch.gameplay_bounds.size.y
	check(wing_195_area / bottom_195_area >= 1.15, "19.5:9 wing monitor gains at least 15 percent area")
	_print_metrics(touch, "19.5:9")

	_configure(touch, Vector2(880.0, 396.0), Vector4(24.0, 8.0, 24.0, 16.0))
	_verify_layout(touch, StandardTouchControls.CabinetLayout.SIDE_WINGS, "20:9")
	check_rect(touch.gameplay_bounds, Rect2(200.0, 43.25, 536.0, 301.5), "20:9 uses the approved side-wing monitor")
	var bottom_20_area := 476.4444 * 268.0
	var wing_20_area := touch.gameplay_bounds.size.x * touch.gameplay_bounds.size.y
	check(wing_20_area / bottom_20_area >= 1.26, "20:9 wing monitor gains at least 26 percent area")
	_print_metrics(touch, "20:9")

	touch.queue_free()
	await process_frame


func _verify_layout(touch: StandardTouchControls, expected: int, label: String) -> void:
	check(touch.cabinet_layout == expected, label + " selects " + touch.cabinet_layout_name())
	check(is_equal_approx(touch.gameplay_bounds.size.aspect(), 16.0 / 9.0), label + " monitor stays 16:9")
	var clear := true
	var contained := true
	for index in touch.rectangles.size():
		clear = clear and not touch.rectangles[index].intersects(touch.gameplay_bounds)
		contained = contained and touch.rectangles[index].encloses(touch.visual_rectangles[index])
	check(clear, label + " touch hits stay outside gameplay")
	check(contained, label + " visible art stays inside hit targets")
	check(not touch.pause_hit_rect.intersects(touch.gameplay_bounds), label + " Pause stays outside gameplay")
	if expected == StandardTouchControls.CabinetLayout.SIDE_WINGS:
		check(
			touch.left_wing_rect.encloses(touch.rectangles[0])
			and touch.left_wing_rect.encloses(touch.rectangles[1])
			and touch.right_wing_rect.encloses(touch.rectangles[2])
			and touch.right_wing_rect.encloses(touch.pause_hit_rect),
			label + " controls stay inside their wing"
		)
	else:
		check(
			touch.deck_control_rect.encloses(touch.rectangles[0])
			and touch.deck_control_rect.encloses(touch.rectangles[1])
			and touch.deck_control_rect.encloses(touch.rectangles[2]),
			label + " controls stay inside bottom deck"
		)


func _print_metrics(touch: StandardTouchControls, label: String) -> void:
	var scale_value := touch.gameplay_bounds.size.x / 1152.0
	var technician := Vector2(50.0, 60.0) * scale_value
	print("VM074_LAYOUT %s mode=%s monitor=%s scale=%.6f left=%s right=%s action=%s pause=%s technician=%s" % [
		label,
		touch.cabinet_layout_name(),
		touch.gameplay_bounds,
		scale_value,
		touch.rectangles[0],
		touch.rectangles[1],
		touch.rectangles[2],
		touch.pause_hit_rect,
		technician,
	])


func _test_real_standard_render_surface() -> void:
	for scenario in [
		{"host": Vector2(1152.0, 648.0), "mode": StandardTouchControls.CabinetLayout.BOTTOM_DECK, "label": "16:9"},
		{"host": Vector2(1296.0, 648.0), "mode": StandardTouchControls.CabinetLayout.BOTTOM_DECK, "label": "18:9"},
		{"host": Vector2(1404.0, 648.0), "mode": StandardTouchControls.CabinetLayout.SIDE_WINGS, "label": "19.5:9"},
		{"host": Vector2(1440.0, 648.0), "mode": StandardTouchControls.CabinetLayout.SIDE_WINGS, "label": "20:9"},
	]:
		var session := SESSION.instantiate() as StandardSession
		session.auto_focus_pause_enabled = false
		session.score_storage_path = "/tmp/vm074-score.cfg"
		root.add_child(session)
		await process_frame
		session.set_anchors_preset(Control.PRESET_TOP_LEFT)
		session.position = Vector2.ZERO
		session.size = scenario.host
		session.touch.touch_available = true
		session.start_game()
		await _settle(3)
		var game := session.game
		var monitor := session.touch.gameplay_bounds
		var displayed := game.displayed_viewport_rect()
		check(session.touch.cabinet_layout == scenario.mode, scenario.label + " real Standard chooses expected cabinet")
		check(Rect2(game.position, game.size).is_equal_approx(monitor), scenario.label + " StandardRun outer rectangle matches monitor")
		check_rect(displayed, Rect2(Vector2.ZERO, game.size), scenario.label + " real ViewportFrame fills monitor")
		check(game._viewport_frame.size == Vector2(INTERNAL_SIZE), scenario.label + " raw SubViewportContainer remains 1152x648")
		check(game._internal_viewport.size == INTERNAL_SIZE, scenario.label + " InternalViewport remains 1152x648")
		check(is_equal_approx(game._viewport_frame.scale.x, game._viewport_frame.scale.y), scenario.label + " real render uses uniform scaling")
		session.show_menu()
		session.queue_free()
		await process_frame


func _test_layout_switch_releases_input() -> void:
	var touch := await _new_touch()
	_configure(touch, Vector2(640.0, 360.0), Vector4(16.0, 8.0, 16.0, 12.0))
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = touch.rectangles[1].get_center()
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	check(Input.is_action_pressed("move_right"), "Direction is active before responsive switch")
	_configure(touch, Vector2(844.0, 390.0), Vector4(24.0, 8.0, 24.0, 16.0))
	check(not Input.is_action_pressed("move_right"), "Responsive bottom-to-wing switch releases held input")
	check(touch.cabinet_layout == StandardTouchControls.CabinetLayout.SIDE_WINGS, "Responsive transition completes after release")
	touch.queue_free()
	await process_frame


func _settle(count: int) -> void:
	for _index in range(count):
		await process_frame
