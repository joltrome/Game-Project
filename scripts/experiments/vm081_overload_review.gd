extends Control

const SESSION_SCENE := preload("res://scenes/presentation/standard_session.tscn")

var session: StandardSession
var _review_stage := 0
var _checkpoint_index := 0
var _capture_path := ""

const CHECKPOINTS := [0.0, 15.0, 30.0, 45.0, 60.0, 90.0]


func _ready() -> void:
	_read_command_line_review_options()
	session = SESSION_SCENE.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.debug_intensity_review_enabled = true
	session.debug_intensity_checkpoint_seconds = CHECKPOINTS[_checkpoint_index]
	add_child(session)
	session.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	session.start_overload_game()
	if not _capture_path.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		if image != null:
			image.save_png(ProjectSettings.globalize_path(_capture_path))
		else:
			push_warning("Screenshot capture requires a real rendering display; headless dummy rendering has no pixels")
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F9:
			_review_stage = posmod(_review_stage + 1, OverloadEmergencyVisual.STAGE_NAMES.size())
			_apply_review_stage()
			get_viewport().set_input_as_handled()
		KEY_F10:
			if is_instance_valid(session.game):
				session.game.conveyor._start_sweeper_entry_cue()
			get_viewport().set_input_as_handled()
		KEY_F11:
			_select_checkpoint(posmod(_checkpoint_index - 1, CHECKPOINTS.size()))
			get_viewport().set_input_as_handled()
		KEY_F12:
			_select_checkpoint(posmod(_checkpoint_index + 1, CHECKPOINTS.size()))
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			_select_checkpoint(int(event.keycode - KEY_1))
			get_viewport().set_input_as_handled()


func _apply_review_stage() -> void:
	if is_instance_valid(session.game) and is_instance_valid(session.game.overload_emergency_visual):
		session.game.overload_emergency_visual.set_review_stage(_review_stage)


func _select_checkpoint(index: int) -> void:
	_checkpoint_index = clampi(index, 0, CHECKPOINTS.size() - 1)
	session.debug_intensity_checkpoint_seconds = CHECKPOINTS[_checkpoint_index]
	session.start_overload_game()


func _read_command_line_review_options() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--checkpoint="):
			var requested := float(argument.trim_prefix("--checkpoint="))
			for index in CHECKPOINTS.size():
				if is_equal_approx(CHECKPOINTS[index], requested):
					_checkpoint_index = index
					break
		elif argument.begins_with("--capture-path="):
			_capture_path = argument.trim_prefix("--capture-path=")
