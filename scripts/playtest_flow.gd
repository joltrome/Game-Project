class_name NeutralPlaytestFlow
extends Control

const SHARED_CONTROLS_TEXT := (
	"CLICK TO FOCUS\n\n"
	+ "ARROW KEYS: MOVE\n"
	+ "SPACE: JUMP\n"
	+ "R: RESTART"
)

@onready var build_id_label: Label = $Backdrop/Panel/Layout/BuildId
@onready var title_label: Label = $Backdrop/Panel/Layout/Title
@onready var status_label: Label = $Backdrop/Panel/Layout/Status
@onready var instructions_label: Label = $Backdrop/Panel/Layout/Instructions
@onready var prompt_label: Label = $Backdrop/Panel/Layout/Prompt


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	_render_current_state()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("begin_playtest") or event.is_echo():
		return
	if (
		PlaytestSession.session_state()
		not in [
			PlaytestSessionController.SessionState.INTRO,
			PlaytestSessionController.SessionState.TRANSITION,
		]
	):
		return
	get_viewport().set_input_as_handled()
	PlaytestSession.advance_from_screen()


func _render_current_state() -> void:
	build_id_label.text = PlaytestSession.neutral_build_id()
	instructions_label.text = SHARED_CONTROLS_TEXT

	match PlaytestSession.session_state():
		PlaytestSessionController.SessionState.INTRO:
			title_label.text = "PLAYTEST SESSION"
			status_label.text = (
				"TWO GAMES · %d SECONDS EACH"
				% roundi(PlaytestSession.game_duration_seconds())
			)
			prompt_label.text = "PRESS ENTER TO BEGIN"
		PlaytestSessionController.SessionState.TRANSITION:
			title_label.text = "GAME 1 COMPLETE"
			status_label.text = "TAKE A BRIEF PAUSE"
			prompt_label.text = "PRESS ENTER WHEN READY FOR GAME 2"
		PlaytestSessionController.SessionState.COMPLETE:
			title_label.text = "SESSION COMPLETE"
			status_label.text = "BOTH GAMES ARE FINISHED"
			instructions_label.text = "PLEASE NOTIFY THE MODERATOR."
			prompt_label.text = ""
		_:
			title_label.text = "PLAYTEST SESSION"
			status_label.text = ""
			prompt_label.text = ""
