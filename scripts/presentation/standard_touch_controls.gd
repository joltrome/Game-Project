class_name StandardTouchControls
extends Control

signal pause_requested

enum CabinetLayout { BOTTOM_DECK, SIDE_WINGS }

const DESIGN_SIZE := Vector2(1152.0, 648.0)
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump"]
const IDLE := 0
const PRESSED := 1
const FOCUS := 2
const CONTROL_ART: Array = [
	[
		preload("res://assets/ui/vm072_mobile_deck/controls/left-idle.png"),
		preload("res://assets/ui/vm072_mobile_deck/controls/left-pressed.png"),
		preload("res://assets/ui/vm072_mobile_deck/controls/left-focus.png"),
	],
	[
		preload("res://assets/ui/vm072_mobile_deck/controls/right-idle.png"),
		preload("res://assets/ui/vm072_mobile_deck/controls/right-pressed.png"),
		preload("res://assets/ui/vm072_mobile_deck/controls/right-focus.png"),
	],
	[
		preload("res://assets/ui/vm072_mobile_deck/controls/action-idle.png"),
		preload("res://assets/ui/vm072_mobile_deck/controls/action-pressed.png"),
		preload("res://assets/ui/vm072_mobile_deck/controls/action-focus.png"),
	],
]
const PAUSE_ART: Array[Texture2D] = [
	preload("res://assets/ui/vm072_mobile_deck/controls/pause-idle.png"),
	preload("res://assets/ui/vm072_mobile_deck/controls/pause-pressed.png"),
	preload("res://assets/ui/vm072_mobile_deck/controls/pause-focus.png"),
]

const INK := Color("0d1424")
const CAP := Color("37505a")
const DECK := Color("7f2634")
const SEAM := Color("1b2a40")
const CREAM := Color("f2e7c9")

@export var deck_height_css: float = 96.0
@export var movement_hit_size_css := Vector2(72.0, 88.0)
@export var action_hit_size_css := Vector2(96.0, 96.0)
@export var movement_visual_size_css := Vector2(64.0, 64.0)
@export var action_visual_size_css := Vector2(80.0, 80.0)
@export var responsive_side_wings_enabled: bool = false
@export var minimum_wing_monitor_height_css: float = 240.0
@export var minimum_wing_area_gain_ratio: float = 1.15
@export_range(1.0, 4.0, 0.1) var maximum_effective_dpr: float = 3.0
@export var debug_overlay_enabled: bool = false

var pause_button: Button
var touch_available: bool = false
var game_active: bool = false
var buttons: Array[TouchScreenButton] = []
var rectangles: Array[Rect2] = []
var visual_rectangles: Array[Rect2] = []
var gameplay_bounds := Rect2(Vector2.ZERO, DESIGN_SIZE)
var deck_surface_rect := Rect2()
var deck_control_rect := Rect2()
var left_wing_rect := Rect2()
var right_wing_rect := Rect2()
var pause_hit_rect := Rect2(Vector2(8.0, 8.0), Vector2(48.0, 48.0))
var safe_host_rect := Rect2(Vector2.ZERO, DESIGN_SIZE)
var effective_dpr: float = 1.0
var logical_per_css: float = 1.0
var is_landscape: bool = true
var cabinet_layout: CabinetLayout = CabinetLayout.BOTTOM_DECK
var _css_viewport_size := DESIGN_SIZE
var _host_per_css := Vector2.ONE
var _art: Array[TextureRect] = []
var _pause_art: TextureRect
var _rotate: C2PixelText
var _hovered_control := -1
var _last_layout_signature := ""
var overload_hud: CohesionHUD
var _overload_host_labels: Array[C2PixelText] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	touch_available = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		touch_available = touch_available or bool(JavaScriptBridge.eval(
			"navigator.maxTouchPoints > 0 || matchMedia('(pointer: coarse)').matches",
			true
		))
		# Explicit local QA override. Production phones still use capability
		# detection; this query only lets the real Web release be reviewed in a
		# desktop mobile-sized browser without creating a second gameplay scene.
		touch_available = touch_available or bool(JavaScriptBridge.eval(
			"new URLSearchParams(location.search).has('mobile_touch_review')",
			true
		))
	for i in ACTIONS.size():
		var button := TouchScreenButton.new()
		button.action = ACTIONS[i]
		button.passby_press = true
		button.shape = RectangleShape2D.new()
		button.z_index = 2
		button.pressed.connect(_refresh_control_art.bind(i))
		button.released.connect(_refresh_control_art.bind(i))
		add_child(button)
		buttons.append(button)

		var art := TextureRect.new()
		art.name = "%sArtwork" % String(ACTIONS[i]).to_pascal_case()
		art.mouse_filter = MOUSE_FILTER_IGNORE
		art.texture_filter = TEXTURE_FILTER_NEAREST
		art.z_index = 3
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(art)
		_art.append(art)

	_build_pause_button()
	_build_overload_host_hud()
	_rotate = C2PixelText.new()
	_rotate.name = "RotateGuidance"
	_rotate.family = "small"
	_rotate.text = "ROTATE DEVICE"
	_rotate.glyph_scale = 3
	_rotate.color = CREAM
	add_child(_rotate)
	resized.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	if is_instance_valid(overload_hud) and _overload_host_labels.size() == 6:
		_overload_host_labels[3].text = overload_hud.score_text.text
		_overload_host_labels[4].text = overload_hud.timer_text.text
		_overload_host_labels[5].text = overload_hud.refund_text.text
		for label in _overload_host_labels:
			label.queue_redraw()


func _build_overload_host_hud() -> void:
	for value in ["SCORE","SURVIVAL","REFUNDS"]:
		var label := C2PixelText.new()
		label.family="small"
		label.text=value
		label.glyph_scale=2
		label.color=CREAM
		label.z_index=5
		add_child(label)
		_overload_host_labels.append(label)
	for value in ["0","00:00.00","0"]:
		var label := C2PixelText.new()
		label.text=value
		label.glyph_scale=2
		label.color=CREAM
		label.z_index=5
		add_child(label)
		_overload_host_labels.append(label)


func _build_pause_button() -> void:
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.z_index = 4
	pause_button.size = Vector2(48.0, 48.0)
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		pause_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_pause_art = TextureRect.new()
	_pause_art.name = "Artwork"
	_pause_art.mouse_filter = MOUSE_FILTER_IGNORE
	_pause_art.texture_filter = TEXTURE_FILTER_NEAREST
	_pause_art.position = Vector2(8.0, 8.0)
	_pause_art.size = Vector2(32.0, 32.0)
	_pause_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pause_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pause_button.add_child(_pause_art)
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
	if event is InputEventScreenTouch:
		_hovered_control = -1
		if event.pressed and not touch_available:
			touch_available = true
			_layout()
	elif event is InputEventMouseMotion and touch_available and game_active:
		var next_hover := -1
		for i in rectangles.size():
			if rectangles[i].has_point(event.position):
				next_hover = i
				break
		if next_hover != _hovered_control:
			var previous := _hovered_control
			_hovered_control = next_hover
			if previous >= 0:
				_refresh_control_art(previous)
			if next_hover >= 0:
				_refresh_control_art(next_hover)


func configure_viewport(
	host_size: Vector2,
	legacy_game_rect: Rect2,
	css_viewport_size: Vector2,
	raw_device_pixel_ratio: float,
	safe_insets_override := Vector4(-1.0, -1.0, -1.0, -1.0)
) -> void:
	position = Vector2.ZERO
	scale = Vector2.ONE
	size = host_size
	_css_viewport_size = css_viewport_size
	if _css_viewport_size.x <= 1.0 or _css_viewport_size.y <= 1.0:
		_css_viewport_size = host_size
	_host_per_css = host_size / _css_viewport_size
	logical_per_css = minf(_host_per_css.x, _host_per_css.y)
	effective_dpr = clampf(raw_device_pixel_ratio, 1.0, maximum_effective_dpr)
	is_landscape = _css_viewport_size.x >= _css_viewport_size.y

	var signature := "%s|%s|%s" % [host_size, _css_viewport_size, is_landscape]
	if signature != _last_layout_signature and _last_layout_signature != "":
		release_all()
	_last_layout_signature = signature

	if not is_landscape:
		gameplay_bounds = legacy_game_rect
		deck_surface_rect = Rect2()
		deck_control_rect = Rect2()
		left_wing_rect = Rect2()
		right_wing_rect = Rect2()
		pause_hit_rect = Rect2(
			Vector2(maxf(host_size.x - 56.0, 8.0), 8.0),
			Vector2(48.0, 48.0)
		)
		_layout()
		return

	var insets := (
		_default_safe_insets(_css_viewport_size)
		if safe_insets_override.x < 0.0
		else safe_insets_override
	)
	var safe_css := Rect2(
		Vector2(insets.x, insets.y),
		Vector2(
			maxf(_css_viewport_size.x - insets.x - insets.z, 1.0),
			maxf(_css_viewport_size.y - insets.y - insets.w, 1.0)
		)
	)
	var safe_right := safe_css.end.x
	var safe_bottom := safe_css.end.y
	var deck_monitor_height := minf(
		safe_css.size.y - deck_height_css - 8.0,
		safe_css.size.x * 9.0 / 16.0
	)
	deck_monitor_height = maxf(deck_monitor_height, 1.0)
	var deck_monitor_size := Vector2(deck_monitor_height * 16.0 / 9.0, deck_monitor_height)
	var deck_monitor_css := Rect2(
		Vector2(
			safe_css.position.x + (safe_css.size.x - deck_monitor_size.x) * 0.5,
			safe_css.position.y
		),
		deck_monitor_size
	)
	var wing_monitor_width := maxf(minf(
		safe_css.size.x - 296.0,
		safe_css.size.y * 16.0 / 9.0
	), 1.0)
	var wing_monitor_size := Vector2(wing_monitor_width, wing_monitor_width * 9.0 / 16.0)
	var wing_monitor_css := Rect2(
		Vector2(
			safe_css.position.x + 176.0 + (safe_css.size.x - 296.0 - wing_monitor_width) * 0.5,
			safe_css.position.y + (safe_css.size.y - wing_monitor_size.y) * 0.5
		),
		wing_monitor_size
	)
	var deck_area := deck_monitor_size.x * deck_monitor_size.y
	var wing_area := wing_monitor_size.x * wing_monitor_size.y
	var use_wings := (
		responsive_side_wings_enabled
		and wing_monitor_size.y >= minimum_wing_monitor_height_css
		and wing_area >= deck_area * minimum_wing_area_gain_ratio
	)
	cabinet_layout = CabinetLayout.SIDE_WINGS if use_wings else CabinetLayout.BOTTOM_DECK
	var monitor_css := wing_monitor_css if use_wings else deck_monitor_css
	var deck_css := Rect2(
		Vector2(8.0, safe_bottom - deck_height_css),
		Vector2(maxf(_css_viewport_size.x - 16.0, 1.0), deck_height_css)
	)
	var control_deck_css := Rect2(
		Vector2(safe_css.position.x, safe_bottom - deck_height_css),
		Vector2(safe_css.size.x, deck_height_css)
	)
	var deck_hit_css: Array[Rect2] = [
		Rect2(
			Vector2(safe_css.position.x + 8.0, safe_bottom - 92.0),
			movement_hit_size_css
		),
		Rect2(
			Vector2(safe_css.position.x + 88.0, safe_bottom - 92.0),
			movement_hit_size_css
		),
		Rect2(
			Vector2(safe_right - 104.0, safe_bottom - deck_height_css),
			action_hit_size_css
		),
	]
	var wing_hit_css: Array[Rect2] = [
		Rect2(Vector2(safe_css.position.x + 8.0, safe_bottom - 104.0), movement_hit_size_css),
		Rect2(Vector2(safe_css.position.x + 88.0, safe_bottom - 104.0), movement_hit_size_css),
		Rect2(Vector2(safe_right - 104.0, safe_bottom - 108.0), action_hit_size_css),
	]
	var hit_css := wing_hit_css if use_wings else deck_hit_css
	var visual_css: Array[Rect2] = [
		Rect2(hit_css[0].position + Vector2(4.0, 12.0), movement_visual_size_css),
		Rect2(hit_css[1].position + Vector2(4.0, 12.0), movement_visual_size_css),
		Rect2(hit_css[2].position + Vector2(8.0, 8.0), action_visual_size_css),
	]
	var pause_css := Rect2(
		Vector2(
			safe_right - 80.0 if use_wings else monitor_css.end.x + 12.0,
			safe_css.position.y + (12.0 if use_wings else 4.0)
		),
		Vector2(48.0, 48.0)
	)
	var left_wing_css := Rect2(safe_css.position, Vector2(168.0, safe_css.size.y))
	var right_wing_css := Rect2(
		Vector2(safe_right - 112.0, safe_css.position.y),
		Vector2(112.0, safe_css.size.y)
	)

	safe_host_rect = _css_to_host(safe_css)
	gameplay_bounds = _css_to_host(monitor_css)
	deck_surface_rect = _css_to_host(deck_css) if not use_wings else Rect2()
	deck_control_rect = _css_to_host(control_deck_css) if not use_wings else Rect2()
	left_wing_rect = _css_to_host(left_wing_css) if use_wings else Rect2()
	right_wing_rect = _css_to_host(right_wing_css) if use_wings else Rect2()
	pause_hit_rect = _css_to_host(pause_css)
	rectangles.clear()
	visual_rectangles.clear()
	for rect in hit_css:
		rectangles.append(_css_to_host(rect))
	for rect in visual_css:
		visual_rectangles.append(_css_to_host(rect))
	_layout()


func set_game_active(active: bool) -> void:
	release_all()
	game_active = active
	if is_node_ready():
		_layout()


func arcade_layout_active() -> bool:
	return touch_available and game_active and is_landscape


func arcade_layout_supported() -> bool:
	return touch_available and is_landscape


func cabinet_layout_name() -> String:
	return "SIDE_WINGS" if cabinet_layout == CabinetLayout.SIDE_WINGS else "BOTTOM_DECK"


func release_all() -> void:
	# Hiding each TouchScreenButton releases only its owning touch/action. This
	# preserves keyboard state while preventing stuck movement after reflow,
	# interruption, death, Pause, or Retry.
	for button in buttons:
		button.hide()
	for art in _art:
		art.hide()
	_hovered_control = -1
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
	var show_arcade := arcade_layout_active()
	for i in buttons.size():
		var hit_rect := rectangles[i] if i < rectangles.size() else Rect2()
		var art_rect := visual_rectangles[i] if i < visual_rectangles.size() else Rect2()
		(buttons[i].shape as RectangleShape2D).size = hit_rect.size
		buttons[i].position = hit_rect.get_center()
		buttons[i].visible = show_arcade
		_art[i].position = art_rect.position
		_art[i].size = art_rect.size
		_art[i].visible = show_arcade
		_refresh_control_art(i)

	if touch_available and game_active and is_landscape:
		pause_button.position = pause_hit_rect.position
	elif touch_available and game_active:
		pause_button.position = Vector2(maxf(size.x - 56.0, 8.0), 8.0)
	else:
		pause_button.position = Vector2(8.0, 8.0)
	pause_button.size = pause_hit_rect.size if touch_available else Vector2(48.0, 48.0)
	_pause_art.position = Vector2(8.0, 8.0) * _host_per_css if touch_available else Vector2(8.0, 8.0)
	_pause_art.size = Vector2(32.0, 32.0) * _host_per_css if touch_available else Vector2(32.0, 32.0)
	pause_button.visible = game_active
	_refresh_pause_art()

	_rotate.position = Vector2(
		floorf((size.x - _rotate.ink_width(_rotate.text, _rotate.glyph_scale)) * 0.5),
		floorf((size.y - 24.0) * 0.5)
	)
	_rotate.visible = touch_available and game_active and not is_landscape
	_layout_overload_host_hud(show_arcade)
	queue_redraw()


func _layout_overload_host_hud(show_arcade: bool) -> void:
	var show_hud := show_arcade and is_instance_valid(overload_hud) and overload_hud.overload_mode_enabled
	for label in _overload_host_labels:
		label.visible=show_hud
	if not show_hud:
		return
	var css_centers: Array[float]
	var label_y: float
	if cabinet_layout == CabinetLayout.SIDE_WINGS:
		css_centers=[108.0,108.0,_css_viewport_size.x-80.0]
		label_y=64.0
	else:
		css_centers=[_css_viewport_size.x*0.384375,_css_viewport_size.x*0.5875,_css_viewport_size.x*0.740625]
		label_y=_css_viewport_size.y-92.0
	for index in 3:
		var title_y := label_y if cabinet_layout==CabinetLayout.BOTTOM_DECK or index==0 else 132.0
		var value_y := title_y+22.0
		var center_host := _css_to_host(Rect2(Vector2(css_centers[index],title_y),Vector2.ZERO)).position
		var title := _overload_host_labels[index]
		var value := _overload_host_labels[index+3]
		title.scale=_host_per_css
		value.scale=_host_per_css
		title.position=Vector2(center_host.x-title.ink_width(title.text,2)*_host_per_css.x*0.5,center_host.y)
		var value_center := _css_to_host(Rect2(Vector2(css_centers[index],value_y),Vector2.ZERO)).position
		value.position=Vector2(value_center.x-value.ink_width(value.text,2)*_host_per_css.x*0.5,value_center.y)


func _draw() -> void:
	if not touch_available or not game_active:
		return
	if not is_landscape:
		draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.96))
		return
	# Deck and bezel are host-space presentation only. The monitor content itself
	# remains the unchanged 16:9 Standard scene rendered inside gameplay_bounds.
	if cabinet_layout == CabinetLayout.SIDE_WINGS:
		draw_rect(left_wing_rect, DECK)
		draw_rect(right_wing_rect, DECK)
	else:
		draw_rect(deck_surface_rect, DECK)
		var seam_height := maxf(2.0 * _host_per_css.y, 1.0)
		draw_rect(Rect2(deck_surface_rect.position, Vector2(deck_surface_rect.size.x, seam_height)), SEAM)
	var outer := gameplay_bounds.grow(3.0 * logical_per_css)
	var inner := gameplay_bounds.grow(2.0 * logical_per_css)
	draw_rect(outer, CAP, false, maxf(logical_per_css, 1.0))
	draw_rect(inner, INK, false, maxf(2.0 * logical_per_css, 1.0))
	if debug_overlay_enabled:
		draw_rect(gameplay_bounds, Color(0.20, 0.85, 0.92, 0.85), false, 2.0)
		if cabinet_layout == CabinetLayout.SIDE_WINGS:
			draw_rect(left_wing_rect, Color(0.95, 0.73, 0.27, 0.85), false, 2.0)
			draw_rect(right_wing_rect, Color(0.95, 0.73, 0.27, 0.85), false, 2.0)
		else:
			draw_rect(deck_surface_rect, Color(0.95, 0.73, 0.27, 0.85), false, 2.0)
		for rect in rectangles:
			draw_rect(rect, Color(0.20, 0.85, 0.92, 0.12))
			draw_rect(rect, Color(0.20, 0.85, 0.92, 0.90), false, 1.0)
		for rect in visual_rectangles:
			draw_rect(rect, Color(0.95, 0.73, 0.27, 0.95), false, 1.0)
		draw_rect(pause_hit_rect, Color(0.95, 0.35, 0.70, 0.90), false, 1.0)


func visible_area_ratio(index: int) -> float:
	if index < 0 or index >= rectangles.size() or index >= visual_rectangles.size():
		return 1.0
	var hit_area := rectangles[index].size.x * rectangles[index].size.y
	var visual_area := visual_rectangles[index].size.x * visual_rectangles[index].size.y
	return visual_area / hit_area if hit_area > 0.0 else 1.0


func _refresh_control_art(index: int) -> void:
	if index < 0 or index >= _art.size() or index >= buttons.size():
		return
	var state := PRESSED if buttons[index].is_pressed() else FOCUS if index == _hovered_control else IDLE
	_art[index].texture = CONTROL_ART[index][state]
	queue_redraw()


func _refresh_pause_art() -> void:
	if pause_button == null or _pause_art == null:
		return
	var state := PRESSED if pause_button.is_pressed() else FOCUS if pause_button.is_hovered() else IDLE
	_pause_art.texture = PAUSE_ART[state]


func _css_to_host(rect: Rect2) -> Rect2:
	return Rect2(rect.position * _host_per_css, rect.size * _host_per_css)


static func _default_safe_insets(css_size: Vector2) -> Vector4:
	var aspect := css_size.x / maxf(css_size.y, 1.0)
	var blend := clampf(
		(aspect - 16.0 / 9.0) / (19.5 / 9.0 - 16.0 / 9.0),
		0.0,
		1.0
	)
	var horizontal := lerpf(16.0, 24.0, blend)
	var bottom := lerpf(12.0, 16.0, blend)
	return Vector4(horizontal, 8.0, horizontal, bottom)


static func layout_reference_size(host_size: Vector2) -> Vector2:
	# One authoritative coordinate system: layout comes from the actual Godot
	# host Control. A same-aspect reference height retains Work's physical target
	# proportions without treating browser-window CSS as the game render surface.
	if host_size.x <= 1.0 or host_size.y <= 1.0:
		return host_size
	var aspect := host_size.x / host_size.y
	var reference_height := 360.0 if aspect <= 16.0 / 9.0 + 0.001 else 390.0
	return Vector2(reference_height * aspect, reference_height)
