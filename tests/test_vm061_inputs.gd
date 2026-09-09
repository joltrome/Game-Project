extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ",message)
func finger(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index=index; e.position=at; e.pressed=pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func drag(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index=index; e.position=at
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func run() -> void:
	root.size = Vector2i(1152,648)
	var player := SharedPlayerController.new()
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame
	for key in [KEY_SPACE,KEY_W,KEY_UP]:
		var e := InputEventKey.new()
		e.physical_keycode=key; e.keycode=key; e.pressed=true
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		check(Input.is_action_just_pressed("jump"), "Key %d maps to the existing jump action" % key)
		player._coyote_time_remaining = 0.1
		player._update_jump_windows(0.001)
		player._try_to_jump()
		check(player.velocity.y == player.jump_velocity and player.velocity.y == -700, "Key %d uses identical jump velocity" % key)
		e=e.duplicate()
		e.pressed=false
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame
	player.queue_free()
	var touch := StandardTouchControls.new()
	root.add_child(touch)
	touch.size=Vector2(1152,648)
	touch.touch_available=true
	touch.set_game_active(true)
	await process_frame
	var left := touch.rectangles[0].get_center()
	var right := touch.rectangles[1].get_center()
	var jump := touch.rectangles[2].get_center()
	finger(0,left,true)
	check(Input.is_action_pressed("move_left"), "Left press")
	finger(0,left,false)
	check(not Input.is_action_pressed("move_left"), "Left release")
	finger(0,right,true)
	finger(1,jump,true)
	check(Input.is_action_pressed("move_right") and Input.is_action_pressed("jump"), "Simultaneous right and jump")
	finger(1,jump,false)
	check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"), "Jump release keeps direction held")
	drag(0,left)
	check(Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "Finger direction change")
	drag(0,Vector2(400,300))
	check(not Input.is_action_pressed("move_left"), "Dragging outside releases")
	finger(0,Vector2(400,300),false)
	for boundary in ["death/results","retry","menu","focus loss"]:
		finger(0,left,true)
		finger(1,jump,true)
		if boundary == "focus loss": touch.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		else: touch.set_game_active(false)
		check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("jump"), "No held touch after " + boundary)
		finger(0,left,false); finger(1,jump,false)
		touch.set_game_active(true)
	touch.size=Vector2(390,844)
	check(touch._rotate.visible, "Portrait rotation guidance")
	touch.size=Vector2(844,390)
	check(not touch._rotate.visible and touch.rectangles[2].end.x <= 844, "Landscape target remains on screen")
	touch.queue_free()
	await process_frame
	print("VM061_INPUT_FAILURES=",failures)
	quit(failures)
