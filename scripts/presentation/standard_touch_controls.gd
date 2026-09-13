class_name StandardTouchControls
extends Control

signal pause_requested

const PAUSE_ART := "res://assets/ui/get_canned_rc2/hud/mobile-pause-%s.png"
var pause_button: Button

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump"]
const LABELS := ["LEFT", "RIGHT", "JUMP"]
var touch_available: bool = false
var game_active: bool = false
var buttons: Array[TouchScreenButton] = []
var rectangles: Array[Rect2] = []
var _labels: Array[C2PixelText] = []
var _rotate: C2PixelText

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	touch_available = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		touch_available = touch_available or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 || matchMedia('(pointer: coarse)').matches", true))
	for i in ACTIONS.size():
		var button := TouchScreenButton.new()
		button.action = ACTIONS[i]
		button.passby_press = true
		button.shape = RectangleShape2D.new()
		button.pressed.connect(queue_redraw)
		button.released.connect(queue_redraw)
		add_child(button)
		buttons.append(button)
		var label := C2PixelText.new()
		label.family = "small"
		label.text = LABELS[i]
		label.glyph_scale = 2
		add_child(label)
		_labels.append(label)
	pause_button=Button.new()
	pause_button.name="PauseButton"
	pause_button.focus_mode=Control.FOCUS_NONE
	pause_button.position=Vector2(8,8)
	pause_button.size=Vector2(48,48)
	for state in ["normal","hover","pressed","focus","hover_pressed"]:
		pause_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var art := TextureRect.new()
	art.name="Artwork"
	art.mouse_filter=MOUSE_FILTER_IGNORE
	art.texture_filter=TEXTURE_FILTER_NEAREST
	pause_button.add_child(art)
	for event in [pause_button.mouse_entered,pause_button.mouse_exited,pause_button.button_down,pause_button.button_up]:
		event.connect(_refresh_pause_art)
	pause_button.pressed.connect(func(): pause_requested.emit())
	add_child(pause_button)
	_refresh_pause_art()
	_rotate = C2PixelText.new()
	_rotate.name = "RotateGuidance"
	_rotate.family = "small"
	_rotate.text = "ROTATE DEVICE"
	_rotate.glyph_scale = 3
	_rotate.color = Color("f2e7c9")
	add_child(_rotate)
	resized.connect(_layout)
	_layout()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not touch_available:
		touch_available = true
		_layout()

func set_game_active(active: bool) -> void:
	release_all()
	game_active = active
	if is_node_ready():
		_layout()

func release_all() -> void:
	# Native TouchScreenButton owns each finger/action and releases when hidden.
	# Never globally release keyboard actions merely because a run is replaced.
	for button in buttons:
		button.hide()
	if pause_button != null:
		pause_button.hide()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN and is_node_ready():
		_layout()

func _layout() -> void:
	if not is_node_ready():
		return
	var side := 72.0
	var y := maxf(12,size.y-side-12)
	rectangles.assign([Rect2(16,y,side,side),Rect2(100,y,side,side),Rect2(maxf(184,size.x-112),y,96,side)])
	for i in buttons.size():
		var rect := rectangles[i]
		(buttons[i].shape as RectangleShape2D).size = rect.size
		buttons[i].position = rect.get_center()
		buttons[i].visible = touch_available and game_active
		_labels[i].visible = touch_available and game_active
		_labels[i].position = rect.get_center()-Vector2(floorf(_labels[i].ink_width(LABELS[i],2)/2),7)
	# This one control serves desktop mouse and mobile touch; never duplicate it.
	pause_button.visible=game_active
	_rotate.position = Vector2(
		floorf((size.x - _rotate.ink_width(_rotate.text, _rotate.glyph_scale)) * 0.5),
		12.0
	)
	_rotate.visible = touch_available and (size.y > size.x or get_window().size.y > get_window().size.x)
	queue_redraw()

func _draw() -> void:
	if not touch_available or not game_active:
		return
	for i in rectangles.size():
		var pressed := buttons[i].is_pressed()
		draw_rect(rectangles[i],Color(0.05,0.08,0.14,0.72 if pressed else 0.36))
		draw_rect(rectangles[i],Color(0.95,0.73,0.27,1.0) if pressed else Color(0.95,0.91,0.79,0.68),false,2)

func _refresh_pause_art() -> void:
	var state := "pressed" if pause_button.is_pressed() else "focus" if pause_button.is_hovered() else "idle"
	(pause_button.get_node("Artwork") as TextureRect).texture=load(PAUSE_ART % state)
