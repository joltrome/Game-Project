class_name C2VolumeSlider
extends Control

signal percent_changed(percent: float)
signal adjustment_finished(percent: float)

const INK := Color("172b3d")
const CREAM := Color("f2e7c9")
const GOLD := Color("f2ba45")
const TEAL := Color("2ca6a4")

var slider: HSlider
var name_label: C2PixelText
var value_label: Label
var _last_finished_value: float = -1.0
var _active_touch_index: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 44.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	name_label = C2PixelText.new()
	name_label.family = "small"
	name_label.glyph_scale = 2
	name_label.color = CREAM
	name_label.position = Vector2(8.0, 15.0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	slider = HSlider.new()
	slider.name = "Percent"
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.scrollable = false
	slider.focus_mode = Control.FOCUS_ALL
	slider.position = Vector2(92.0, 4.0)
	slider.size = Vector2(162.0, 36.0)
	_apply_slider_theme()
	slider.value_changed.connect(_on_value_changed)
	slider.drag_ended.connect(_on_drag_ended)
	slider.gui_input.connect(_on_slider_gui_input)
	add_child(slider)
	value_label = Label.new()
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", GOLD)
	value_label.add_theme_color_override("font_outline_color", INK)
	value_label.add_theme_constant_override("outline_size", 2)
	value_label.position = Vector2(260.0, 8.0)
	value_label.size = Vector2(54.0, 28.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value_label)
	_update_value_label()


func configure(label_text: String, initial_percent: float) -> void:
	if not is_node_ready():
		await ready
	name_label.text = label_text
	slider.set_value_no_signal(clampf(initial_percent, 0.0, 100.0))
	_last_finished_value = slider.value
	_update_value_label()


func percent() -> float:
	return slider.value if is_instance_valid(slider) else 100.0


func set_percent(value: float, emit_change: bool = true) -> void:
	if not is_instance_valid(slider):
		return
	var clamped := clampf(value, 0.0, 100.0)
	if emit_change:
		slider.value = clamped
	else:
		slider.set_value_no_signal(clamped)
		_update_value_label()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.14, 0.92))
	draw_rect(Rect2(Vector2.ZERO, size), CREAM, false, 2.0)


func _apply_slider_theme() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("314a5a")
	track.set_content_margin_all(5.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = TEAL
	fill.set_content_margin_all(5.0)
	var fill_focus := fill.duplicate() as StyleBoxFlat
	fill_focus.border_color = GOLD
	fill_focus.set_border_width_all(2)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_focus)
	var knob_image := Image.create(14, 24, false, Image.FORMAT_RGBA8)
	knob_image.fill(GOLD)
	var knob := ImageTexture.create_from_image(knob_image)
	for icon_name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(icon_name, knob)


func _on_value_changed(value: float) -> void:
	_update_value_label()
	percent_changed.emit(value)


func _on_drag_ended(_changed: bool) -> void:
	_emit_adjustment_finished()


func _on_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_active_touch_index = touch.index
			slider.value = _percent_from_viewport_position(touch.position)
			slider.grab_focus()
		elif touch.index == _active_touch_index:
			slider.value = _percent_from_viewport_position(touch.position)
			_active_touch_index = -1
			_emit_adjustment_finished()
	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		slider.value = _percent_from_viewport_position(event.position)
	elif event is InputEventKey and not event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END]:
		_emit_adjustment_finished()


func _percent_from_viewport_position(viewport_position: Vector2) -> float:
	var local := slider.get_global_transform_with_canvas().affine_inverse() * viewport_position
	return clampf(local.x / maxf(slider.size.x, 1.0) * 100.0, 0.0, 100.0)


func _emit_adjustment_finished() -> void:
	if is_equal_approx(_last_finished_value, slider.value):
		return
	_last_finished_value = slider.value
	adjustment_finished.emit(slider.value)


func _update_value_label() -> void:
	if is_instance_valid(value_label) and is_instance_valid(slider):
		value_label.text = "%3d%%" % roundi(slider.value)
