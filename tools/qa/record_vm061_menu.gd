extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1152,648)
	var s := preload("res://scenes/presentation/standard_session.tscn").instantiate() as StandardSession
	s.score_storage_path="/tmp/vms-rc1-animation.cfg"
	root.add_child(s)
	s.audio.music.volume_db=-80
	DirAccess.make_dir_recursive_absolute("res://builds/validation-vm061/menu-frames")
	for i in 60:
		await create_timer(0.06).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/validation-vm061/menu-frames/%03d.png" % i)
	s.queue_free()
	await process_frame
	quit()
