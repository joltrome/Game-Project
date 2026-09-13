extends SceneTree
const SESSION := preload("res://scenes/presentation/standard_session.tscn")
var failures := 0
var s: StandardSession
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
	else: print("PASS: ",message)
func snapshot() -> Array:
	var c:=s.game.conveyor
	var product_state:=[]
	for p in c.active_falling_products()+c.active_landed_products():
		product_state.append([p.position,p.landed_time_remaining,p.get_node("LandedBody").global_position])
	var sweep_state:=[]
	for a in c.active_sweepers(): sweep_state.append(a.position)
	var coin_state:=[]
	for child in c.get_node("CollectibleDirector").get_children():
		if child is Node2D: coin_state.append(child.position)
	var sprite:=s.game.v2_visual_integration.technician_sprite()
	return [c.player.position,c.player.velocity,c.survival_time,c._telegraph_remaining,s.hud.round_controller.round_time_remaining,s.hud.coins.score,product_state,sweep_state,coin_state,sprite.frame,sprite.frame_progress,s.game.background_drop_director.state,s.game.background_drop_director.warning_time_remaining,s.game.background_drop_director._pulse_elapsed]
func run() -> void:
	root.size=Vector2i(1152,648)
	s=SESSION.instantiate()
	s.auto_focus_pause_enabled=false
	s.score_storage_path="/tmp/vms-rc2-test.cfg"
	root.add_child(s)
	var audio_id:=s.audio.music.get_instance_id()
	s.show_credits()
	var credits:=s._c2 as CohesionScreen
	check(credits.kind=="credits" and credits.credit_entries.size()==2,"Credits has exactly two authored blocks")
	check(str(credits.credit_entries).contains("JOLTROME") and str(credits.credit_entries).contains("MIRAIE"),"Credits content")
	check(credits.buttons[0].get_rect()==Rect2(416,463,320,88),"Back keeps expanded Work hit region")
	s._music_slider.set_percent(0.0)
	check(s.audio.is_muted(&"Music"),"Credits music slider reaches full mute")
	s._music_slider.set_percent(100.0)
	credits.buttons[0].pressed.emit()
	check(s.state==StandardSession.State.MENU,"Credits Back")
	s.start_game()
	check(not s.game.conveyor.get_node("HUD/Timer").visible and not s.game.conveyor.get_node("HUD/ScoreGroup").visible,"Old timer/score presentation hidden")
	check(s._c2==null and s.hud!=null,"Live HUD has no audio buttons")
	s.hud.round_controller.force_time_remaining_for_test(15.2)
	s.hud.refresh()
	check(s.hud.timer_text.text=="00:16","HUD rounds remaining time up")
	s.hud.coins.score=9223372036854775807
	s.hud.refresh()
	check(s.hud.score_text.text=="9223372036854775807" and s.hud.score_text.position.x>=952,"HUD preserves full int64 score")
	s.start_game()
	var c:=s.game.conveyor
	c.left_failure_enabled=false
	c.force_warning_for_test(0)
	c.spawn_external_conveyor_product(650,150,1.0,"pause-test")
	s.hud.coins.try_spawn_band_for_test(CollectibleDirector.PlacementBand.GROUND)
	c.player.velocity.y=-400
	await physics_frame
	s.pause_game()
	var frozen:=snapshot()
	await create_timer(0.3,true).timeout
	check(snapshot()==frozen,"Pause freezes player, fall, warning, coins, timer and animation exactly")
	check(paused and s.state==StandardSession.State.PAUSED,"Real SceneTree physics pause")
	check(s._c2.buttons.size()==3 and s._c2.buttons[0].has_focus(),"Pause focus order begins with Resume and has no duplicate audio buttons")
	s._music_slider.set_percent(0.0)
	s._sfx_slider.set_percent(0.0)
	check(s.audio.is_muted(&"Music") and s.audio.is_muted(&"SFX"),"Pause audio controls process while simulation is paused")
	s._music_slider.set_percent(100.0);s._sfx_slider.set_percent(100.0)
	Input.action_press("jump");Input.action_press("move_left")
	s.resume_game()
	check(not paused and snapshot()==frozen,"Resume preserves exact frozen state before next frame")
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("move_left"),"No stale held actions")
	await create_timer(0.08).timeout
	check(snapshot()!=frozen,"Simulation advances after Resume")
	for i in 30:
		s.pause_game()
		check(s.state==StandardSession.State.PAUSED,"Pause stress %d"%i)
		s.resume_game()
		await process_frame
	check(s.audio.music.get_instance_id()==audio_id,"30 pause/resume cycles retain one music player")
	for i in 20:
		var old:=s.game.get_instance_id()
		s.pause_game()
		s._c2.buttons[1].pressed.emit()
		check(s.state==StandardSession.State.GAME and not paused and s.game.get_instance_id()!=old and s.hud.coins.score==0,"Fresh Retry from Pause %d"%i)
		await process_frame
	s.pause_game();s._c2.buttons[2].pressed.emit()
	check(s.game==null and not paused and s.state==StandardSession.State.MENU,"Menu exits paused run")
	s.start_game()
	var d:=s.game.background_drop_director
	d.reservation_pending=true
	d._active_schedule_index=0
	d._try_start_reserved_sequence()
	check(d.state==MotionBackgroundDropDirector.VisualState.SELECTED,"Actual D3 warning active for pause fixture")
	s.game.conveyor._sweeper_spawn_pending=true
	var carriage:=s.game.conveyor._spawn_sweeper()
	carriage.position.x=s.game.conveyor.player.position.x+60
	check(carriage!=null,"Actual carriage active near player for pause fixture")
	s.pause_game()
	var warning_frozen:=snapshot()
	await create_timer(0.2,true).timeout
	check(snapshot()==warning_frozen,"D3 warning and nearby carriage freeze exactly")
	s.resume_game()
	s.start_game()
	s.auto_focus_pause_enabled=true
	s._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await process_frame
	check(s.state==StandardSession.State.PAUSED,"Focus loss pauses")
	s._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(s.state==StandardSession.State.PAUSED,"Focus return does not auto resume")
	s.resume_game()
	s.game.conveyor._kill_player(ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE)
	s.pause_game()
	check(not paused,"Late pause cannot override lethal contact")
	await process_frame
	await process_frame
	check(s.state==StandardSession.State.DEATH_BEAT,"Death wins before pause")
	check(s.audio.music.get_instance_id()==audio_id,"Retries retain persistent music")
	s.show_menu()
	s.queue_free()
	await process_frame
	DirAccess.remove_absolute("/tmp/vms-rc2-test.cfg")
	print("VM062_COHESION_FAILURES=",failures)
	quit(failures)
