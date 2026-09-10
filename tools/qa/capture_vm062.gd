extends SceneTree
const SESSION:=preload("res://scenes/presentation/standard_session.tscn")
const OUT:="res://builds/validation-vm062/native/"
var s: StandardSession
func _initialize() -> void: call_deferred("run")
func shot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+path+".png")
func quiet_run() -> void:
	s.start_game()
	s.game.conveyor.set_physics_process(false)
	s.game.conveyor.left_failure_enabled=false
	s.game.background_drop_director.set_process(false)
func run() -> void:
	auto_accept_quit=false
	root.close_requested.connect(func(): print("QA CLOSE REQUEST IGNORED"))
	root.size=Vector2i(1152,648)
	DirAccess.make_dir_recursive_absolute(OUT)
	s=SESSION.instantiate()
	s.auto_focus_pause_enabled=false
	s.score_storage_path="/tmp/vms-rc2-captures.cfg"
	root.add_child(s)
	s.audio.music.volume_db=-80
	await shot("menu")
	s.show_credits();await shot("credits")
	quiet_run()
	for i in 25: await physics_frame
	s.hud.coins.try_spawn_band_for_test(CollectibleDirector.PlacementBand.GROUND)
	s.game.conveyor.force_warning_for_test(0)
	await shot("gameplay")
	s.pause_game();await shot("pause")
	s.resume_game()
	var cases:=OS.get_cmdline_user_args()
	if cases.is_empty(): cases=PackedStringArray(["product","airborne","carriage","left-edge","right-edge","near-can","out"])
	for label in cases:
		quiet_run()
		var c:=s.game.conveyor
		for i in 20: await physics_frame
		c.player.set_physics_process(false)
		c.player.position=Vector2(480,560)
		var cause:=ConveyorPrototype.DeathCause.FALLING_PRODUCT
		if label=="airborne": c.player.position=Vector2(480,325)
		if label=="left-edge": c.player.position=Vector2(145,520)
		if label=="right-edge": c.player.position=Vector2(704,560)
		if label=="out":
			c.player.position=Vector2(98,580)
			cause=ConveyorPrototype.DeathCause.LEFT_OUT
		if label=="carriage":
			c._sweeper_spawn_pending=true
			var a:=c._spawn_sweeper()
			a.position.x=480
			a.set_physics_process(false)
			c.player.position.y=a.position.y
			cause=ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE
		if label=="near-can":
			var p:=c.spawn_external_conveyor_product(480,c.product_spawn_y,0.85,"ko-capture")
			p.position.y=p.floor_y-p.falling_size.y/2-1
			p.fall_speed=120
			while not p.is_landed(): await physics_frame
			for i in 15: await physics_frame
			c.player.position=Vector2(p.conveyor_center_x(),516)
		await process_frame
		await shot(label+"-live")
		c._kill_player(cause)
		var began:=Time.get_ticks_msec()
		var index:=0
		var timestamps:=[]
		while Time.get_ticks_msec()-began<1000:
			timestamps.append(Time.get_ticks_msec()-began)
			await shot("%s-%03d"%[label,index])
			index+=1
			await create_timer(0.025).timeout
		var f:=FileAccess.open(OUT+label+"-timing.json",FileAccess.WRITE)
		f.store_string(JSON.stringify(timestamps))
		f.close()
		print("CAPTURED ",label," ",index," frames")
	s.show_menu();s.queue_free()
	await process_frame
	quit()
