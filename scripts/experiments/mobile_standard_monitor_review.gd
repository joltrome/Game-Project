extends Control

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const HOSTS := [
	Vector2(1152.0, 648.0),
	Vector2(1404.0, 648.0),
	Vector2(1440.0, 648.0),
]
const HOST_NAMES := ["16:9", "19.5:9 IPHONE-LIKE", "20:9 SAMSUNG-LIKE"]

var session: StandardSession
var info: Label
var host_index := 2


func _ready() -> void:
	session = SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = "/tmp/vm0721-monitor-review-score.cfg"
	add_child(session)
	session.set_anchors_preset(Control.PRESET_TOP_LEFT)
	session.touch.touch_available = true

	info = Label.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.z_index = 100
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color("f2e7c9"))
	info.add_theme_color_override("font_outline_color", Color("0d1424"))
	info.add_theme_constant_override("outline_size", 3)
	add_child(info)
	resized.connect(_apply_scenario)
	_apply_scenario()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		host_index = int(event.keycode - KEY_1)
		_apply_scenario()


func _apply_scenario() -> void:
	if not is_instance_valid(session):
		return
	var host: Vector2 = HOSTS[host_index]
	var fit := MotionExperimentShell.contained_rect(size, host)
	session.position = fit.position
	session.size = host
	session.scale = fit.size / host
	session.touch.touch_available = true
	session._layout()
	info.position = Vector2(12.0, 8.0)
	info.text = "REAL STANDARD MONITOR REVIEW  %s  |  1-3 ASPECT  ENTER CLOCK IN" % HOST_NAMES[host_index]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d1424"))
