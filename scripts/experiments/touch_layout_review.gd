extends Control

const DESIGN_SIZE := Vector2(1152.0, 648.0)
const ASPECTS := [16.0 / 9.0, 18.0 / 9.0, 19.5 / 9.0, 20.0 / 9.0]
const ASPECT_NAMES := ["16:9", "18:9", "19.5:9", "20:9"]
const DPR_VALUES := [1.0, 2.0, 3.0]

var touch: StandardTouchControls
var info: Label
var aspect_index := 0
var dpr_index := 0


func _ready() -> void:
	touch = StandardTouchControls.new()
	touch.debug_overlay_enabled = true
	add_child(touch)
	# StandardTouchControls detects the actual host during _ready(). Force the
	# development review surface to touch mode only after that detection runs.
	touch.touch_available = true
	touch.set_game_active(true)
	info = Label.new()
	info.position = Vector2(16.0, 12.0)
	info.add_theme_font_size_override("font_size", 18)
	add_child(info)
	resized.connect(_apply_scenario)
	_apply_scenario()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		aspect_index = int(event.keycode - KEY_1)
		_apply_scenario()
	elif event.keycode == KEY_D:
		dpr_index = (dpr_index + 1) % DPR_VALUES.size()
		_apply_scenario()


func _apply_scenario() -> void:
	if not is_instance_valid(touch):
		return
	var host := size
	var game_rect := MotionExperimentShell.contained_rect(host, DESIGN_SIZE)
	var css_height := 360.0 if aspect_index == 0 else 390.0
	var css_size := Vector2(css_height * float(ASPECTS[aspect_index]), css_height)
	touch.configure_viewport(host, game_rect, css_size, float(DPR_VALUES[dpr_index]))
	info.text = (
		"TOUCH REVIEW  %s  DPR %.0f  |  1-4 ASPECT  D DPR\n"
		+ "CYAN = MONITOR/HIT   GOLD = DECK/ART   MAGENTA = PAUSE"
	) % [ASPECT_NAMES[aspect_index], DPR_VALUES[dpr_index]]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101923"))
	if not is_instance_valid(touch):
		return
	draw_rect(touch.gameplay_bounds, Color(0.12, 0.18, 0.25, 0.85))
