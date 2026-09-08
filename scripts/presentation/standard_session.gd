class_name StandardSession
extends Control

enum State { MENU, GAME, RESULTS, CREDITS }

const STANDARD_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const DESIGN_SIZE := Vector2(1152, 648)
const CREAM := Color("f2e7c9")
const INK := Color("172b3d")
const RED := Color("b93743")
const TEAL := Color("2ca6a4")
const GOLD := Color("f2ba45")

@export var score_storage_path: String = "user://standard_best.cfg"

var state: State = State.MENU
var game: MotionExperimentShell
var scores := StandardScoreStore.new()
var last_score: int = 0
var last_survived: bool = false
var _ui: Control
var _music_button: Button
var _sfx_button: Button
var result_title: Label
var result_score: Label
var best_label: Label

@onready var audio: SessionAudio = $Audio


func _ready() -> void:
	scores.storage_path = score_storage_path
	scores.load_best()
	_ui = Control.new()
	_ui.name = "Presentation"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.size = DESIGN_SIZE
	add_child(_ui)
	resized.connect(_layout)
	show_menu()
	_layout()


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (
		event is InputEventKey and event.pressed and not event.echo
	):
		audio.start_music_once()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and state in [State.GAME, State.RESULTS]:
		start_game()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and state in [State.RESULTS, State.CREDITS]:
			show_menu()
			get_viewport().set_input_as_handled()


func start_game() -> void:
	audio.start_music_once()
	audio.request_sfx(&"ui_confirm")
	_dispose_game()
	state = State.GAME
	game = STANDARD_SCENE.instantiate() as MotionExperimentShell
	game.name = "StandardRun"
	game.clean_tester_presentation = true
	game.clean_control_hint_duration = 0.0
	game.local_instrumentation_enabled = false
	# Both flags are required. A normal release can never enable the overlay.
	game.debug_overlay_toggle_allowed = OS.is_debug_build() and OS.has_feature("standard_debug")
	game.v2_debug_overlay_enabled = false
	add_child(game)
	move_child(game, 0)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.conveyor.set_process_unhandled_input(false)
	var round_controller := game.conveyor.get_node("RoundController") as FixedRoundController
	# Death can originate inside a physics collision callback. Finish that callback
	# before disabling the complete run and its collision objects.
	round_controller.round_ended_by_death.connect(_on_death, CONNECT_DEFERRED)
	round_controller.round_completed.connect(_on_completion, CONNECT_DEFERRED)
	var hooks := StandardSFXHooks.new()
	hooks.name = "SFXHooks"
	game.add_child(hooks)
	hooks.bind(game, audio)
	_apply_hud_style()
	_clear_ui()
	_add_sound_controls(Vector2(24, 18), true)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func show_menu() -> void:
	if state != State.MENU:
		audio.request_sfx(&"ui_back")
	_dispose_game()
	state = State.MENU
	_clear_ui()
	_frame("VENDING MACHINE SURVIVAL")
	_label("VENDING\nMACHINE\nSURVIVAL", Rect2(90, 118, 640, 240), 60, CREAM)
	_label("DODGE THE PRODUCTS.\nCOLLECT REFUND COINS.\nMAKE IT TO 60 SECONDS.", Rect2(94, 373, 600, 100), 22, GOLD)
	_rect(Rect2(760, 112, 306, 373), Color("233e50"))
	_label("READY TO CLOCK IN?", Rect2(784, 136, 258, 30), 18, CREAM, true)
	var play := _button("PLAY", Rect2(784, 188, 258, 76), start_game, GOLD)
	best_label = _label("BEST SCORE  %02d" % scores.best_score, Rect2(784, 290, 258, 44), 23, CREAM, true)
	_button("CREDITS", Rect2(784, 378, 258, 52), show_credits, TEAL)
	_controls()
	_add_sound_controls(Vector2(760, 530))
	play.grab_focus()


func show_credits() -> void:
	state = State.CREDITS
	audio.request_sfx(&"ui_confirm")
	_clear_ui()
	_frame("CREDITS")
	_label("MADE FOR ONE MORE TRY.", Rect2(90, 137, 960, 60), 36, CREAM)
	_label("ORIGINAL MUSIC", Rect2(94, 237, 800, 35), 18, GOLD)
	_label("MIRAIE", Rect2(94, 282, 800, 60), 44, CREAM)
	_label("Composed for Vending Machine Survival.\nCurrent music is a temporary composer demo.", Rect2(94, 369, 900, 76), 22, CREAM)
	var back := _button("BACK", Rect2(94, 504, 260, 64), show_menu, TEAL)
	_add_sound_controls(Vector2(760, 530))
	back.grab_focus()


func _on_death(score: int, _remaining: float) -> void:
	_show_results(score, false)


func _on_completion(score: int) -> void:
	_show_results(score, true)


func _show_results(score: int, survived: bool) -> void:
	if state != State.GAME:
		return
	state = State.RESULTS
	last_score = score
	last_survived = survived
	scores.record_score(score)
	# Freeze the complete scene including D3, delayed coins and visual warnings.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.hide()
	audio.request_sfx(&"round_complete" if survived else &"player_death")
	_clear_ui()
	_frame("SHIFT COMPLETE" if survived else "SHIFT ENDED")
	result_title = _label("SURVIVED" if survived else "GAME OVER", Rect2(90, 132, 970, 88), 68, GOLD if survived else CREAM)
	_label("THE MACHINE STOPPED. YOU DIDN'T." if survived else "THE MACHINE WINS THIS ROUND.", Rect2(94, 232, 940, 40), 22, CREAM)
	_label("REFUND COINS", Rect2(94, 317, 390, 36), 21, GOLD)
	result_score = _label("%02d" % score, Rect2(94, 355, 390, 88), 68, CREAM)
	_label("BEST SCORE", Rect2(584, 317, 390, 36), 21, GOLD)
	best_label = _label("%02d" % scores.best_score, Rect2(584, 355, 390, 88), 68, CREAM)
	var retry := _button("RETRY", Rect2(94, 500, 270, 68), start_game, GOLD)
	_button("MENU", Rect2(386, 500, 270, 68), show_menu, TEAL)
	_add_sound_controls(Vector2(760, 530))
	_label("R: RETRY     ESC: MENU", Rect2(94, 588, 620, 25), 15, CREAM)
	retry.grab_focus()


func _dispose_game() -> void:
	if is_instance_valid(game):
		game.process_mode = Node.PROCESS_MODE_DISABLED
		remove_child(game)
		game.queue_free()
	game = null


func _apply_hud_style() -> void:
	var hud := game.conveyor.get_node("HUD")
	for node_name in ["BuildId", "ExperimentId", "Hypothesis", "Controls", "CollectibleLegend"]:
		var item := hud.get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.hide()
	var timer := hud.get_node("Timer") as Label
	timer.add_theme_color_override("font_outline_color", INK)
	# Retain the existing central timer, score hierarchy and urgency timings.
	var score := hud.get_node("ScoreGroup/CollectibleScore") as Label
	score.add_theme_color_override("font_outline_color", INK)


func _layout() -> void:
	var fitted := MotionExperimentShell.contained_rect(size, DESIGN_SIZE)
	_ui.position = fitted.position
	_ui.scale = fitted.size / DESIGN_SIZE


func _clear_ui() -> void:
	for child in _ui.get_children():
		_ui.remove_child(child)
		child.queue_free()
	result_title = null
	result_score = null
	best_label = null


func _frame(heading: String) -> void:
	_rect(Rect2(0, 0, 1152, 648), INK)
	_rect(Rect2(32, 28, 1088, 592), RED)
	_rect(Rect2(48, 82, 1056, 524), INK)
	_rect(Rect2(48, 82, 1056, 6), GOLD)
	_label(heading, Rect2(66, 39, 970, 30), 20, CREAM)
	for x in [52, 1090]:
		for y in [46, 590]:
			_rect(Rect2(x, y, 10, 10), GOLD)


func _controls() -> void:
	_rect(Rect2(94, 501, 620, 2), TEAL)
	_label("MOVE: A / D OR LEFT / RIGHT\nJUMP: SPACE", Rect2(94, 525, 620, 66), 20, CREAM)


func _add_sound_controls(at: Vector2, in_game: bool = false) -> void:
	_music_button = _button("", Rect2(at, Vector2(146, 44)), _toggle_music, CREAM)
	_sfx_button = _button("", Rect2(at + Vector2(160, 0), Vector2(146, 44)), _toggle_sfx, CREAM)
	if in_game:
		_music_button.focus_mode = Control.FOCUS_NONE
		_sfx_button.focus_mode = Control.FOCUS_NONE
	_refresh_sound_labels()


func _toggle_music() -> void:
	audio.set_muted(&"Music", not audio.is_muted(&"Music"))
	_refresh_sound_labels()


func _toggle_sfx() -> void:
	audio.set_muted(&"SFX", not audio.is_muted(&"SFX"))
	audio.request_sfx(&"ui_confirm")
	_refresh_sound_labels()


func _refresh_sound_labels() -> void:
	_music_button.text = "MUSIC: OFF" if audio.is_muted(&"Music") else "MUSIC: ON"
	_sfx_button.text = "SFX: OFF" if audio.is_muted(&"SFX") else "SFX: ON"


func _rect(rect: Rect2, color: Color) -> void:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(node)


func _label(value: String, rect: Rect2, font_size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(label)
	return label


func _button(value: String, rect: Rect2, action: Callable, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 28 if rect.size.y >= 60 else 17)
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.darkened(0.16) if style_name == "pressed" else color
		style.border_color = CREAM if style_name == "focus" else INK
		style.set_border_width_all(3 if style_name == "focus" else 2)
		if style_name == "focus":
			style.draw_center = false
			style.set_expand_margin_all(4)
		button.add_theme_stylebox_override(style_name, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, INK)
	button.pressed.connect(action)
	_ui.add_child(button)
	return button
