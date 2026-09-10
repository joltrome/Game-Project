class_name StandardSession
extends Control

enum State { MENU, GAME, RESULTS, CREDITS, DEATH_BEAT, PAUSED }

const DEATH_BEAT_SECONDS := 0.75

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
var result_headline: String = ""
var last_death_cause: ConveyorPrototype.DeathCause = ConveyorPrototype.DeathCause.UNKNOWN
var result_transition_count: int = 0
var _run_serial: int = 0
var _death_ready_at_msec: int = 0
var _death_timer: Timer
var auto_focus_pause_enabled: bool = true
var hud: CohesionHUD
var pause_count: int = 0
var death_reaction: StandardDeathReaction
var _c2: C2Screen
var touch: StandardTouchControls
var result_score: C2PixelText
var best_label: C2PixelText

@onready var audio: SessionAudio = $Audio


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().title = "GET CANNED!"
	scores.storage_path = score_storage_path
	scores.load_best()
	_ui = Control.new()
	_ui.name = "Presentation"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.size = DESIGN_SIZE
	add_child(_ui)
	_death_timer = Timer.new()
	_death_timer.one_shot = true
	_death_timer.ignore_time_scale = true
	_death_timer.wait_time = DEATH_BEAT_SECONDS
	_death_timer.timeout.connect(_finish_death_beat)
	add_child(_death_timer)
	touch = StandardTouchControls.new()
	add_child(touch)
	touch.pause_requested.connect(pause_game)
	resized.connect(_layout)
	get_window().size_changed.connect(_layout)
	show_menu()
	_layout()


func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (
		event is InputEventKey and event.pressed and not event.echo
	):
		audio.start_music_once()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_P]:
		if state == State.GAME:
			pause_game()
		elif state == State.PAUSED:
			resume_game()
		elif event.keycode == KEY_ESCAPE and state in [State.RESULTS,State.CREDITS]:
			show_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and state in [State.GAME, State.RESULTS, State.PAUSED]:
		start_game()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and auto_focus_pause_enabled and state == State.GAME:
		call_deferred("pause_game")


func pause_game() -> void:
	if state != State.GAME or not is_instance_valid(game) or game.conveyor.gameplay_is_stopped():
		return
	state=State.PAUSED
	pause_count+=1
	touch.set_game_active(false)
	_release_gameplay_actions()
	get_tree().paused=true
	_c2=CohesionScreen.new()
	(_c2 as CohesionScreen).kind="pause"
	_ui.add_child(_c2)
	var panel := _c2 as CohesionScreen
	var resume := panel.add_action("resume",resume_game)
	panel.add_action("pause-retry",start_game)
	panel.add_action("pause-menu",show_menu)
	_add_cohesion_sound_controls(panel)
	panel.wire_focus()
	resume.grab_focus()


func resume_game() -> void:
	if state != State.PAUSED:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()
	_ui.remove_child(_c2)
	_c2.queue_free()
	_c2=null
	_music_button=null
	_sfx_button=null
	_release_gameplay_actions()
	state=State.GAME
	get_tree().paused=false
	touch.set_game_active(true)


func _release_gameplay_actions() -> void:
	for action in [&"move_left",&"move_right",&"jump"]:
		Input.action_release(action)


func start_game() -> void:
	audio.start_music_once()
	audio.request_sfx(&"ui_confirm")
	_dispose_game()
	state = State.GAME
	_run_serial += 1
	last_death_cause = ConveyorPrototype.DeathCause.UNKNOWN
	game = STANDARD_SCENE.instantiate() as MotionExperimentShell
	game.name = "StandardRun"
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	game.v2_visual_integration.external_death_presentation_enabled=true
	game.v2_visual_integration.live_death_pose.connect(_capture_death_pose)
	# Settled art has a two-source-pixel transparent top (4 logical pixels).
	# Shift only the support position; retain its frozen 72x48 shape.
	game.v2_visual_integration.landed_contact_offset_y=4.0
	var round_controller := game.conveyor.get_node("RoundController") as FixedRoundController
	# Death can originate inside a physics collision callback. Finish that callback
	# before disabling the complete run and its collision objects.
	round_controller.round_ended_by_death.connect(_on_death.bind(_run_serial), CONNECT_DEFERRED)
	round_controller.round_completed.connect(_on_completion.bind(_run_serial), CONNECT_DEFERRED)
	var hooks := StandardSFXHooks.new()
	hooks.name = "SFXHooks"
	game.add_child(hooks)
	hooks.bind(game, audio)
	_apply_hud_style()
	_clear_ui()
	hud=CohesionHUD.new()
	hud.round_controller=round_controller
	hud.coins=game.conveyor.get_node("CollectibleDirector")
	_ui.add_child(hud)
	touch.set_game_active(true)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func show_menu() -> void:
	if state != State.MENU:
		audio.request_sfx(&"ui_back")
	_dispose_game()
	state = State.MENU
	_clear_ui()
	_c2 = C2Screen.new()
	_ui.add_child(_c2)
	var play := _c2.add_button("clock-in", "CLOCK IN", Rect2(416,472,320,70), start_game, true)
	best_label = _score_text(scores.best_score)
	var scale_value := 3
	while best_label.ink_width(best_label.text, scale_value) > 176 and scale_value > 1:
		scale_value -= 1
	best_label.glyph_scale = scale_value
	best_label.position = Vector2(1048-best_label.ink_width(best_label.text,scale_value),376)
	_c2.add_button("credits", "CREDITS", Rect2(660,557,112,44), show_credits)
	_add_c2_sound_controls()
	_c2.wire_focus()
	play.grab_focus()


func show_credits() -> void:
	state = State.CREDITS
	audio.request_sfx(&"ui_confirm")
	_clear_ui()
	var panel := CohesionScreen.new()
	panel.kind="credits"
	_c2=panel
	_ui.add_child(panel)
	var back := panel.add_action("back",show_menu)
	_add_cohesion_sound_controls(panel)
	panel.wire_focus()
	back.grab_focus()


func _add_cohesion_sound_controls(panel: CohesionScreen) -> void:
	var prefix := "pause-" if panel.kind == "pause" else "credits-"
	_music_button=panel.add_action(prefix+"music-on",_toggle_music)
	_sfx_button=panel.add_action(prefix+"sfx-on",_toggle_sfx)
	_music_button.set_meta(&"audio_art_prefix","pause-music" if panel.kind == "pause" else "music")
	_sfx_button.set_meta(&"audio_art_prefix","pause-sfx" if panel.kind == "pause" else "sfx")
	_refresh_sound_labels()


func _capture_death_pose(snapshot: Dictionary) -> void:
	if state != State.GAME or is_instance_valid(death_reaction):
		return
	death_reaction=StandardDeathReaction.new()
	game.conveyor.add_child(death_reaction)
	death_reaction.setup(snapshot,game.conveyor.death_cause)


func _on_death(score: int, _remaining: float, serial: int) -> void:
	if serial != _run_serial or state != State.GAME:
		return
	state = State.DEATH_BEAT
	last_score = score
	last_survived = false
	last_death_cause = game.conveyor.death_cause
	touch.set_game_active(false)
	game.conveyor.get_node("HUD/DeathMessage").hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	audio.request_sfx(&"player_death")
	_death_ready_at_msec = (death_reaction.started_at_msec if is_instance_valid(death_reaction) else Time.get_ticks_msec()) + roundi(DEATH_BEAT_SECONDS * 1000)
	_death_timer.start(DEATH_BEAT_SECONDS)


func _finish_death_beat() -> void:
	if state == State.DEATH_BEAT and is_instance_valid(game):
		# A Timer can consume the current frame delta immediately after start.
		# Keep the visible hold at least 0.75 real seconds, including a slow frame.
		var remaining := _death_ready_at_msec - Time.get_ticks_msec()
		if remaining > 0:
			_death_timer.start(remaining / 1000.0)
			return
		_show_results(last_score, false)


func _on_completion(score: int, serial: int) -> void:
	if serial == _run_serial and state == State.GAME:
		_show_results(score, true)


static func headline_for(cause: ConveyorPrototype.DeathCause, survived: bool) -> String:
	if survived:
		return "CLOCKED OUT."
	match cause:
		ConveyorPrototype.DeathCause.FALLING_PRODUCT, ConveyorPrototype.DeathCause.BACKGROUND_PRODUCT:
			return "CANNED."
		ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE:
			return "GRABBED."
		ConveyorPrototype.DeathCause.LEFT_OUT:
			return "VENDED."
		_:
			return "GAME OVER."


func _show_results(score: int, survived: bool) -> void:
	if state not in [State.GAME, State.DEATH_BEAT]:
		return
	state = State.RESULTS
	result_transition_count += 1
	last_score = score
	last_survived = survived
	scores.record_score(score)
	touch.set_game_active(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.hide()
	if survived:
		audio.request_sfx(&"round_complete")
	_clear_ui()
	result_headline = headline_for(last_death_cause, survived)
	_c2 = C2Screen.new()
	_c2.is_result = true
	_c2.headline = result_headline.trim_suffix(".").to_lower().replace(" ", "-")
	_ui.add_child(_c2)
	result_score = _score_text(score)
	best_label = _score_text(scores.best_score)
	var scale_value := 5
	while maxf(result_score.ink_width(result_score.text,scale_value), best_label.ink_width(best_label.text,scale_value)) > 232 and scale_value > 1:
		scale_value -= 1
	for item: Array in [[result_score,450],[best_label,714]]:
		var label := item[0] as C2PixelText
		label.glyph_scale = scale_value
		label.position = Vector2(item[1]-floorf(label.ink_width(label.text,scale_value)/2),291)
	var retry := _c2.add_button("retry", "RETRY", Rect2(336,472,280,70), start_game, true)
	_c2.add_button("menu", "MENU", Rect2(644,478,144,64), show_menu)
	_add_c2_sound_controls()
	_c2.wire_focus()
	retry.grab_focus()


func _score_text(value: int) -> C2PixelText:
	var label := C2PixelText.new()
	label.text = "%02d" % value
	_c2.add_child(label)
	return label


func _add_c2_sound_controls() -> void:
	_music_button = _c2.add_button("music-on", "MUSIC ON", Rect2(808,557,136,44), _toggle_music)
	_sfx_button = _c2.add_button("sfx-on", "SFX ON", Rect2(962,557,122,44), _toggle_sfx)
	_refresh_sound_labels()


func _dispose_game() -> void:
	get_tree().paused=false
	if _death_timer != null:
		_death_timer.stop()
	if touch != null:
		touch.set_game_active(false)
	if is_instance_valid(game):
		game.process_mode = Node.PROCESS_MODE_DISABLED
		remove_child(game)
		game.queue_free()
	game = null
	death_reaction=null


func _apply_hud_style() -> void:
	var hud := game.conveyor.get_node("HUD")
	for node_name in ["BuildId", "ExperimentId", "Hypothesis", "Controls", "CollectibleLegend"]:
		var item := hud.get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.hide()
	var timer := hud.get_node("Timer") as Label
	timer.hide()
	# Retain the existing central timer, score hierarchy and urgency timings.
	var score := hud.get_node("ScoreGroup/CollectibleScore") as Label
	score.get_parent().hide()


func _layout() -> void:
	var fitted := MotionExperimentShell.contained_rect(size, DESIGN_SIZE)
	_ui.position = fitted.position
	_ui.scale = fitted.size / DESIGN_SIZE
	if touch != null:
		# The game canvas keeps its logical size under window stretch. Counter-scale
		# only the touch overlay so its targets remain large on a phone.
		touch.scale = Vector2.ONE
		var window_size := Vector2(get_window().size)
		var pixel_ratio := float(JavaScriptBridge.eval("window.devicePixelRatio || 1", true)) if OS.has_feature("web") else 1.0
		var display_scale := Vector2.ONE * minf(window_size.x / size.x, window_size.y / size.y) / pixel_ratio
		touch.scale = Vector2.ONE / display_scale
		touch.size = size * display_scale


func _clear_ui() -> void:
	hud=null
	_c2 = null
	for child in _ui.get_children():
		_ui.remove_child(child)
		child.queue_free()
	result_headline = ""
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
	if _c2 != null:
		for entry: Array in [[_music_button,"Music","music"],[_sfx_button,"SFX","sfx"]]:
			var button := entry[0] as Button
			var on := not audio.is_muted(entry[1])
			button.text = str(entry[2]).to_upper() + (" ON" if on else " OFF")
			button.set_meta(&"art_key", str(button.get_meta(&"audio_art_prefix",entry[2])) + ("-on" if on else "-off"))
			_c2.refresh_button(button)
		return
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
