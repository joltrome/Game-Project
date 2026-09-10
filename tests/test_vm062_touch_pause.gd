extends SceneTree
const SESSION:=preload("res://scenes/presentation/standard_session.tscn")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1;push_error(message)
	else: print("PASS: ",message)
func finger(index: int,at: Vector2,pressed: bool) -> void:
	var e:=InputEventScreenTouch.new()
	e.index=index;e.position=at;e.pressed=pressed
	Input.parse_input_event(e);Input.flush_buffered_events()
func run() -> void:
	root.size=Vector2i(1152,648)
	var s:=SESSION.instantiate() as StandardSession
	s.auto_focus_pause_enabled=false
	s.score_storage_path="/tmp/vms-rc2-touch.cfg"
	root.add_child(s)
	s.start_game()
	s.touch.touch_available=true
	s.touch.set_game_active(true)
	await process_frame
	var transform:=s.touch.get_global_transform_with_canvas()
	var right:=transform*s.touch.rectangles[1].get_center()
	var jump:=transform*s.touch.rectangles[2].get_center()
	var pause_at:=transform*s.touch.pause_button.get_rect().get_center()
	check(s.touch.pause_button.size==Vector2(48,48),"48 CSS-pixel overlay target")
	finger(0,right,true);finger(1,jump,true)
	check(Input.is_action_pressed("move_right") and Input.is_action_pressed("jump"),"Held movement and jump before third touch")
	finger(2,pause_at,true)
	finger(2,pause_at,false)
	check(s.state==StandardSession.State.PAUSED,"Third finger activates Pause")
	check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"),"Pause clears both held actions")
	finger(0,right,false);finger(1,jump,false)
	if s.state==StandardSession.State.PAUSED: s.resume_game()
	check(s.touch.pause_button.visible and not s.touch.buttons[0].is_pressed() and not s.touch.buttons[1].is_pressed() and not s.touch.buttons[2].is_pressed(),"Resume restores touch layer with no stuck fingers")
	finger(3,right,true)
	check(Input.is_action_pressed("move_right"),"A fresh touch works after Resume")
	finger(3,right,false)
	s.show_menu();s.queue_free()
	await process_frame
	print("VM062_TOUCH_PAUSE_FAILURES=",failures)
	quit(failures)
