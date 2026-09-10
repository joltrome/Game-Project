extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const OUTPUT := "res://builds/validation-vm062/typography/gameplay.png"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1152, 648)
	var session := SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = "/tmp/vms-typography-capture.cfg"
	root.add_child(session)
	session.audio.music.volume_db = -80.0
	session.start_game()
	var conveyor := session.game.conveyor
	conveyor.set_physics_process(false)
	conveyor.left_failure_enabled = false
	session.game.background_drop_director.set_process(false)
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.set_process(false)
	conveyor.survival_time = director.first_spawn_time
	director._process(0.0)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUTPUT)
	print("VM062_TYPOGRAPHY_CAPTURE=", "PASS" if error == OK else "FAIL", " path=", OUTPUT)
	session.queue_free()
	await process_frame
	DirAccess.remove_absolute("/tmp/vms-typography-capture.cfg")
	quit(0 if error == OK else 1)
