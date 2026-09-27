extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const INTERNAL_SIZE := Vector2i(1152, 648)
const EPSILON := 0.05

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
	await _verify_real_standard_lifecycle(Vector2(1152.0, 648.0), "16:9")
	await _verify_real_standard_lifecycle(Vector2(1404.0, 648.0), "iPhone-like 19.5:9")
	await _verify_real_standard_lifecycle(Vector2(1440.0, 648.0), "Samsung-like 20:9")
	print("VM0721_MOBILE_MONITOR_HOTFIX_FAILURES=", failures)
	quit(failures)


func _verify_real_standard_lifecycle(host_size: Vector2, label: String) -> void:
	var session := SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = "/tmp/vm0721-score.cfg"
	root.add_child(session)
	await process_frame
	session.set_anchors_preset(Control.PRESET_TOP_LEFT)
	session.position = Vector2.ZERO
	session.size = host_size
	session.touch.touch_available = true
	session.start_game()
	await _settle_frames(3)
	_verify_monitor(session, label + " CLOCK IN")

	session.pause_game()
	await _settle_frames(2)
	session.resume_game()
	await _settle_frames(3)
	_verify_monitor(session, label + " Pause/Resume")

	# Exercise the orientation/reflow lifecycle without treating portrait as a
	# playable layout, then return to the original landscape host.
	session.size = Vector2(host_size.y, host_size.x)
	session._layout()
	await _settle_frames(2)
	check(not session.touch.arcade_layout_supported(), label + " portrait disables arcade layout")
	session.size = host_size
	session._layout()
	await _settle_frames(3)
	_verify_monitor(session, label + " portrait-to-landscape")

	session.start_game()
	await _settle_frames(3)
	_verify_monitor(session, label + " Retry")

	session.show_menu()
	session.queue_free()
	await process_frame


func _verify_monitor(session: StandardSession, label: String) -> void:
	var game := session.game
	check(is_instance_valid(game), label + " real StandardRun exists")
	if not is_instance_valid(game):
		return
	var monitor := session.touch.gameplay_bounds
	var frame := game.displayed_viewport_rect()
	var global_frame := Rect2(game.position + frame.position, frame.size)
	check(is_equal_approx(monitor.size.aspect(), 16.0 / 9.0), label + " monitor remains 16:9")
	check_rect(Rect2(game.position, game.size), monitor, label + " outer StandardRun matches monitor")
	check_rect(frame, Rect2(Vector2.ZERO, game.size), label + " displayed ViewportFrame reflowed locally")
	check_rect(global_frame, monitor, label + " actual displayed viewport matches monitor")
	check(
		game._viewport_frame.size == Vector2(INTERNAL_SIZE),
		label + " SubViewportContainer retains authored logical size"
	)
	check(
		is_equal_approx(game._viewport_frame.scale.x, game._viewport_frame.scale.y),
		label + " SubViewportContainer uses uniform display scale"
	)
	check(game._internal_viewport.size == INTERNAL_SIZE, label + " InternalViewport remains 1152x648")
	check(game.internal_size == INTERNAL_SIZE, label + " logical gameplay remains 1152x648")


func _settle_frames(count: int) -> void:
	for _index in range(count):
		await process_frame
