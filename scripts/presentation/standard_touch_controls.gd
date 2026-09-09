class_name StandardTouchControls
extends Control

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump"]
const LABELS := ["LEFT", "RIGHT", "JUMP"]
var touch_available: bool = false
var game_active: bool = false
var buttons: Array[TouchScreenButton] = []
var rectangles: Array[Rect2] = []
var _labels: Array[C2PixelText] = []
var _rotate: Label

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
	_rotate = Label.new()
	_rotate.text = "ROTATE DEVICE"
	_rotate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate.add_theme_font_size_override("font_size",22)
	_rotate.add_theme_color_override("font_outline_color",Color.BLACK)
	_rotate.add_theme_constant_override("outline_size",8)
	_rotate.mouse_filter = MOUSE_FILTER_IGNORE
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
	_rotate.position = Vector2(0,12)
	_rotate.size = Vector2(size.x,34)
	_rotate.visible = touch_available and (size.y > size.x or get_window().size.y > get_window().size.x)
	queue_redraw()

func _draw() -> void:
	if not touch_available or not game_active:
		return
	for i in rectangles.size():
		var pressed := buttons[i].is_pressed()
		draw_rect(rectangles[i],Color(0.05,0.08,0.14,0.72 if pressed else 0.36))
		draw_rect(rectangles[i],Color(0.95,0.73,0.27,1.0) if pressed else Color(0.95,0.91,0.79,0.68),false,2)
