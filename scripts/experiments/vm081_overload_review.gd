extends Control

const SESSION_SCENE := preload("res://scenes/presentation/standard_session.tscn")

var session: StandardSession
var _review_stage := 0
var _checkpoint_index := 0
var _capture_path := ""
var _saturated := false
var _double_jump := false
var _standard_mode := false

const CHECKPOINTS := [0.0, 10.0, 20.0, 30.0, 45.0, 60.0, 75.0, 90.0]


func _ready() -> void:
	_read_command_line_review_options()
	session = SESSION_SCENE.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.debug_intensity_review_enabled = true
	session.debug_movement_review_enabled = true
	session.experimental_additional_air_jumps = 1 if _double_jump else 0
	session.debug_intensity_checkpoint_seconds = CHECKPOINTS[_checkpoint_index]
	session.debug_intensity_saturated_fixture = _saturated
	add_child(session)
	session.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	_start_selected_mode()
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
		KEY_J:
			_double_jump = not _double_jump
			session.experimental_additional_air_jumps = 1 if _double_jump else 0
			_start_selected_mode()
			get_viewport().set_input_as_handled()
		KEY_F8:
			_standard_mode = not _standard_mode
			_start_selected_mode()
			get_viewport().set_input_as_handled()
		KEY_F9:
			_review_stage = posmod(_review_stage + 1, OverloadEmergencyVisual.STAGE_NAMES.size())
			_apply_review_stage()
			get_viewport().set_input_as_handled()
		KEY_F10:
			_saturated = not _saturated
			_select_checkpoint(_checkpoint_index)
			get_viewport().set_input_as_handled()
		KEY_F11:
			_select_checkpoint(posmod(_checkpoint_index - 1, CHECKPOINTS.size()))
			get_viewport().set_input_as_handled()
		KEY_F12:
			_select_checkpoint(posmod(_checkpoint_index + 1, CHECKPOINTS.size()))
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			_select_checkpoint(int(event.keycode - KEY_1))
			get_viewport().set_input_as_handled()


func _apply_review_stage() -> void:
	if is_instance_valid(session.game) and is_instance_valid(session.game.overload_emergency_visual):
		session.game.overload_emergency_visual.set_review_stage(_review_stage)


func _select_checkpoint(index: int) -> void:
	_checkpoint_index = clampi(index, 0, CHECKPOINTS.size() - 1)
	session.debug_intensity_checkpoint_seconds = CHECKPOINTS[_checkpoint_index]
	session.debug_intensity_saturated_fixture = _saturated
	_start_selected_mode()


func _start_selected_mode() -> void:
	if _standard_mode:
		session.start_standard_game()
	else:
		session.start_overload_game()
	print(
		"VM0813_REVIEW mode=",
		"STANDARD" if _standard_mode else "OVERLOAD",
		" movement=",
		"DOUBLE" if _double_jump else "SINGLE"
	)


func _read_command_line_review_options() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--checkpoint="):
			var requested := float(argument.trim_prefix("--checkpoint="))
			for index in CHECKPOINTS.size():
				if is_equal_approx(CHECKPOINTS[index], requested):
					_checkpoint_index = index
					break
		elif argument == "--saturated":
			_saturated = true
		elif argument == "--double-jump":
			_double_jump = true
		elif argument == "--standard":
			_standard_mode = true
		elif argument.begins_with("--capture-path="):
			_capture_path = argument.trim_prefix("--capture-path=")
