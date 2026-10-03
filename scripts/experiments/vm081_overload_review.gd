extends Control

const SESSION_SCENE := preload("res://scenes/presentation/standard_session.tscn")

var session: StandardSession
var _review_stage := 0


func _ready() -> void:
	session = SESSION_SCENE.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	add_child(session)
	session.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	session.start_overload_game()
	await get_tree().process_frame
	_apply_review_stage()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F9:
			_review_stage = posmod(_review_stage + 1, 4)
			_apply_review_stage()
			get_viewport().set_input_as_handled()
		KEY_F10:
			if is_instance_valid(session.game):
				session.game.conveyor._start_sweeper_entry_cue()
			get_viewport().set_input_as_handled()


func _apply_review_stage() -> void:
	if is_instance_valid(session.game) and is_instance_valid(session.game.overload_emergency_visual):
		session.game.overload_emergency_visual.set_review_stage(_review_stage)
