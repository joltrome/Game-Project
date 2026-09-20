class_name StandardTouchControls
extends Control

signal pause_requested

const PAUSE_ART := "res://assets/ui/get_canned_rc2/hud/mobile-pause-%s.png"
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump"]
const LABELS := ["L", "R", "JUMP"]

@export var safe_padding_css: float = 14.0
@export var movement_hit_size_css := Vector2(68.0, 78.0)
@export var jump_hit_size_css := Vector2(86.0, 92.0)
@export var movement_visual_size_css := Vector2(38.0, 38.0)
@export var jump_visual_size_css := Vector2(50.0, 50.0)
@export var meaningful_gutter_css: float = 48.0
@export_range(1.0, 4.0, 0.1) var maximum_effective_dpr: float = 3.0
@export_range(0.5, 2.5, 0.05) var minimum_logical_per_css: float = 0.70
@export_range(0.5, 2.5, 0.05) var maximum_logical_per_css: float = 1.80

var pause_button: Button
var touch_available: bool = false
var game_active: bool = false
var buttons: Array[TouchScreenButton] = []
var rectangles: Array[Rect2] = []
var visual_rectangles: Array[Rect2] = []
var gameplay_bounds := Rect2(Vector2.ZERO, Vector2(1152.0, 648.0))
var uses_side_gutters: bool = false
var effective_dpr: float = 1.0
var logical_per_css: float = 1.0
var _css_viewport_size := Vector2(1152.0, 648.0)
var _labels: Array[C2PixelText] = []
var _rotate: C2PixelText


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	touch_available = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		touch_available = touch_available or bool(JavaScriptBridge.eval(
			"navigator.maxTouchPoints > 0 || matchMedia('(pointer: coarse)').matches",
			true
		))
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
		label.color = Color("f2e7c9")
		add_child(label)
		_labels.append(label)
	_build_pause_button()
	_rotate = C2PixelText.new()
	_rotate.name = "RotateGuidance"
	_rotate.family = "small"
	_rotate.text = "ROTATE DEVICE"
	_rotate.glyph_scale = 3
	_rotate.color = Color("f2e7c9")
	add_child(_rotate)
	resized.connect(_layout)
	_layout()


func _build_pause_button() -> void:
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.size = Vector2(48.0, 48.0)
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		pause_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art := TextureRect.new()
	art.name = "Artwork"
	art.mouse_filter = MOUSE_FILTER_IGNORE
	art.texture_filter = TEXTURE_FILTER_NEAREST
	art.position = Vector2(8.0, 8.0)
	art.size = Vector2(32.0, 32.0)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pause_button.add_child(art)
	for event in [
		pause_button.mouse_entered,
		pause_button.mouse_exited,
		pause_button.button_down,
		pause_button.button_up,
	]:
		event.connect(_refresh_pause_art)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	add_child(pause_button)
	_refresh_pause_art()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not touch_available:
		touch_available = true
		_layout()


func configure_viewport(
	host_size: Vector2,
	game_rect: Rect2,
	css_viewport_size: Vector2,
	raw_device_pixel_ratio: float
) -> void:
	position = Vector2.ZERO
	scale = Vector2.ONE
	size = host_size
	gameplay_bounds = game_rect
	_css_viewport_size = css_viewport_size
	effective_dpr = clampf(raw_device_pixel_ratio, 1.0, maximum_effective_dpr)
	var usable_css := css_viewport_size
	if usable_css.x <= 1.0 or usable_css.y <= 1.0:
		usable_css = host_size / effective_dpr
	logical_per_css = clampf(
		minf(host_size.x / usable_css.x, host_size.y / usable_css.y),
		minimum_logical_per_css,
		maximum_logical_per_css
	)
	_layout()


func set_game_active(active: bool) -> void:
	release_all()
	game_active = active
	if is_node_ready():
		_layout()


func release_all() -> void:
	# Native TouchScreenButton owns each finger/action and releases when hidden.
	# Never release keyboard actions merely because a run is replaced.
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
	var unit := logical_per_css
	var safe := safe_padding_css * unit
	var move_hit := movement_hit_size_css * unit
	var jump_hit := jump_hit_size_css * unit
	var move_visual := movement_visual_size_css * unit
	var jump_visual := jump_visual_size_css * unit
	var left_gutter := maxf(gameplay_bounds.position.x, 0.0)
	var right_gutter := maxf(size.x - gameplay_bounds.end.x, 0.0)
	uses_side_gutters = (
		left_gutter >= meaningful_gutter_css * unit
		and right_gutter >= meaningful_gutter_css * unit
	)

	# Hit zones stay generous and occupy the thumb edges. Their artwork is a
	# separate compact rectangle, so pressing never paints over gameplay.
	var hit_bottom := size.y - safe
	var movement_cluster_width := move_hit.x * 2.0
	var movement_left := safe
	var jump_left := size.x - safe - jump_hit.x
	if uses_side_gutters:
		movement_left = maxf(
			safe,
			gameplay_bounds.position.x - movement_cluster_width + move_hit.x * 0.35
		)
		jump_left = minf(
			size.x - safe - jump_hit.x,
			gameplay_bounds.end.x - jump_hit.x * 0.35
		)
	var movement_y := hit_bottom - move_hit.y
	var jump_y := hit_bottom - jump_hit.y
	rectangles.assign([
		Rect2(Vector2(movement_left, movement_y), move_hit),
		Rect2(Vector2(movement_left + move_hit.x, movement_y), move_hit),
		Rect2(Vector2(jump_left, jump_y), jump_hit),
	])

	visual_rectangles.clear()
	for i in rectangles.size():
		var visual_size := jump_visual if i == 2 else move_visual
		var visual_center := rectangles[i].get_center()
		if uses_side_gutters:
			if i < 2:
				visual_center.x = (
					gameplay_bounds.position.x
					- visual_size.x * (1.5 - float(i))
				)
			else:
				visual_center.x = maxf(
					visual_center.x,
					gameplay_bounds.end.x + visual_size.x * 0.50
				)
		visual_center.x = clampf(
			visual_center.x,
			safe + visual_size.x * 0.5,
			size.x - safe - visual_size.x * 0.5
		)
		visual_rectangles.append(Rect2(visual_center - visual_size * 0.5, visual_size))

	for i in buttons.size():
		var hit_rect := rectangles[i]
		(buttons[i].shape as RectangleShape2D).size = hit_rect.size
		buttons[i].position = hit_rect.get_center()
		buttons[i].visible = touch_available and game_active
		_labels[i].visible = touch_available and game_active
		var glyph_scale := 2
		_labels[i].glyph_scale = glyph_scale
		_labels[i].position = visual_rectangles[i].get_center() - Vector2(
			floorf(_labels[i].ink_width(LABELS[i], glyph_scale) * 0.5),
			7.0
		)

	# The 48 px pause hit target remains shared by desktop and touch, while its
	# artwork is only 32 px. Safe padding keeps it away from browser cut-outs.
	var pause_safe := safe if touch_available else 8.0
	pause_button.position = Vector2(pause_safe, pause_safe)
	pause_button.visible = game_active
	_rotate.position = Vector2(
		floorf((size.x - _rotate.ink_width(_rotate.text, _rotate.glyph_scale)) * 0.5),
		maxf(safe, 12.0)
	)
	_rotate.visible = touch_available and (
		size.y > size.x or _css_viewport_size.y > _css_viewport_size.x
	)
	queue_redraw()


func _draw() -> void:
	if not touch_available or not game_active:
		return
	for i in visual_rectangles.size():
		var pressed := buttons[i].is_pressed()
		var fill := Color(0.05, 0.08, 0.14, 0.32 if pressed else 0.12)
		var outline := Color(0.95, 0.73, 0.27, 0.90 if pressed else 0.55)
		draw_rect(visual_rectangles[i], fill)
		draw_rect(visual_rectangles[i], outline, false, 2.0)


func visible_area_ratio(index: int) -> float:
	if index < 0 or index >= rectangles.size() or index >= visual_rectangles.size():
		return 1.0
	var hit_area := rectangles[index].size.x * rectangles[index].size.y
	var visual_area := visual_rectangles[index].size.x * visual_rectangles[index].size.y
	return visual_area / hit_area if hit_area > 0.0 else 1.0


func _refresh_pause_art() -> void:
	if pause_button == null:
		return
	var state := (
		"pressed"
		if pause_button.is_pressed()
		else "focus" if pause_button.is_hovered() else "idle"
	)
	var art := pause_button.get_node("Artwork") as TextureRect
	art.texture = load(PAUSE_ART % state)
	art.modulate.a = 0.90 if pause_button.is_pressed() else 0.62
