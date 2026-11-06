extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const OUT := "res://builds/validation-vm0813/native/"
const STANDARD_PATH := "/tmp/vms-vm0813-capture-standard.cfg"
const OVERLOAD_PATH := "/tmp/vms-vm0813-capture-overload.cfg"
const AUDIO_PATH := "/tmp/vms-vm0813-capture-audio.cfg"

var session: StandardSession


func _initialize() -> void:
	call_deferred("run")


func capture(name: String) -> void:
	if session._c2 != null:
		session._c2.set_process(false)
		session._c2.elapsed = 0.06
		session._c2.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("VM0813_CAPTURE ", name, " window=", root.size, " state=", session.state)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for path in [STANDARD_PATH, OVERLOAD_PATH, AUDIO_PATH]:
		DirAccess.remove_absolute(path)
	var standard_store := StandardScoreStore.new()
	standard_store.storage_path = STANDARD_PATH
	standard_store.record_score(7)
	var overload_store := OverloadRecordStore.new()
	overload_store.storage_path = OVERLOAD_PATH
	overload_store.record_run(40.0, 10, 6500)

	root.size = Vector2i(1152, 648)
	session = SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = STANDARD_PATH
	session.overload_storage_path = OVERLOAD_PATH
	session.audio_settings_path = AUDIO_PATH
	root.add_child(session)
	session.audio.set_muted(&"Music", true)
	await process_frame

	await _capture_mode_states("desktop")
	root.size = Vector2i(844, 390)
	await process_frame
	await process_frame
	await _capture_mode_states("mobile-844x390")
	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	await _capture_mode_states("mobile-640x360")

	session.queue_free()
	await process_frame
	for path in [STANDARD_PATH, OVERLOAD_PATH, AUDIO_PATH]:
		DirAccess.remove_absolute(path)
	quit()


func _capture_mode_states(prefix: String) -> void:
	session.show_mode_select()
	await process_frame
	root.gui_release_focus()
	await capture(prefix + "-neutral")
	session._c2.activate_keyboard_focus_visuals()
	(session._c2.get_node("standard") as Button).grab_focus()
	await capture(prefix + "-standard-focus")
	(session._c2.get_node("overload") as Button).grab_focus()
	await capture(prefix + "-overload-focus")
