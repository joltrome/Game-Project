extends SceneTree
const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const OUT := "res://builds/validation-vm061/screenshots/"
var s: StandardSession
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	if s._c2 != null:
		s._c2.set_process(false)
		s._c2.elapsed=0.06
		s._c2.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
	print(name, " window=",root.size," viewport=",root.get_visible_rect().size," session=",s.size," touch=",s.touch.size," touch_scale=",s.touch.scale," screen=",s.touch.get_screen_transform())
func run() -> void:
	root.size=Vector2i(1152,648)
	s=SESSION.instantiate()
	s.score_storage_path="/tmp/vms-rc1-screenshot-best.cfg"
	DirAccess.remove_absolute(s.score_storage_path)
	root.add_child(s)
	s.audio.set_muted(&"Music",true)
	s.scores.best_score=12
	s.show_menu()
	await shot("menu")
	for cause in ConveyorPrototype.DeathCause.values():
		s.start_game()
		s.last_death_cause=cause
		s._show_results(1,false)
		await shot(s._c2.headline)
	s.start_game()
	s._show_results(14,true)
	await shot("clocked-out")
	s.show_credits()
	await shot("credits")
	s.start_game()
	s.touch.touch_available=true
	s.touch.set_game_active(true)
	await shot("touch-game")
	s.game.conveyor._kill_player(ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE)
	await process_frame
	await shot("death-beat")
	s.show_menu()
	root.size=Vector2i(844,390)
	await process_frame
	await shot("menu-844x390")
	s.start_game()
	await shot("touch-844x390")
	s.show_menu()
	root.size=Vector2i(390,844)
	await process_frame
	await shot("portrait-390x844")
	s.queue_free()
	await process_frame
	DirAccess.remove_absolute("/tmp/vms-rc1-screenshot-best.cfg")
	quit()
