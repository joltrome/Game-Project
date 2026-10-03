class_name C2Screen
extends Control

const ART := "res://assets/ui/get_canned_c2/"
const OVERLOAD_ART := "res://assets/ui/vm081_overload/buttons/"
const RUN := preload("res://assets/vm050_vis04/VM050_VIS04_S1_50x60_run_sheet.png")
const IDLE := preload("res://assets/vm050_d3_vis03/VM050_VIS03_technician_rigid_block_limbs_sheet.png")
const COIN := preload("res://assets/vm050_vis04/VM050_VIS04_C1_16x16_coin_sheet.png")
const CAN := preload("res://assets/vm050_d3_vis02/VM050_D3_VIS02_landed_red_soda_runtime_sheet.png")
const BELT := preload("res://assets/vm050_d3_v2/VM050_D3_V2_conveyor_tile_sheet.png")

var is_result: bool = false
var headline: String = "game-over"
var show_menu_static_lettering: bool = true
var show_result_static_lettering: bool = true
var elapsed: float = 0.0
var _textures: Dictionary = {}
var buttons: Array[Button] = []


func _ready() -> void:
	size = Vector2(1152, 648)
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	for path in ["menu/chassis.png", "menu/common-lettering.png", "menu/static-lettering.png", "results/static-lettering.png", "logo/get-canned-L1.png", "ventastic/ventastic.png", "results/headlines/%s.png" % headline]:
		if headline == "fried" and path.begins_with("results/headlines/"):
			_textures[path] = load("res://assets/visuals/vm081_overload/emergency/headline-fried.png")
		else:
			_textures[path] = load(ART + path)
	if not is_result and show_menu_static_lettering:
		# Cover only the old SPACE hint and use supplied glyphs for the added aliases.
		var legend := C2PixelText.new()
		legend.family = "small"
		legend.text = "SPACE / W / UP"
		legend.glyph_scale = 2
		legend.color = Color("0d1424")
		legend.position = Vector2(304, 577)
		add_child(legend)


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	draw_texture(_textures["menu/chassis.png"], Vector2.ZERO)
	draw_texture(_textures["menu/common-lettering.png"], Vector2.ZERO)
	if is_result and show_result_static_lettering:
		draw_texture(_textures["results/static-lettering.png"], Vector2.ZERO)
	elif not is_result and show_menu_static_lettering:
		draw_texture(_textures["menu/static-lettering.png"], Vector2.ZERO)
	if not is_result and show_menu_static_lettering:
		draw_rect(Rect2(304, 577, 60, 14), Color("f2e7c9"))
	var belt_frame := 3 - int(elapsed / 0.100) % 4
	for tile in 15:
		var width := 16 if tile == 14 else 64
		draw_texture_rect_region(BELT, Rect2(136 + tile * 64, 412, width, 32), Rect2(belt_frame * 32, 0, width / 2.0, 16))
	if is_result:
		draw_texture_rect_region(IDLE, Rect2(504, 352, 50, 60), Rect2(0, 0, 40, 48))
	else:
		draw_texture_rect_region(RUN, Rect2(504, 352, 50, 60), Rect2((int(elapsed / 0.060) % 6) * 50, 0, 50, 60))
	draw_texture_rect_region(CAN, Rect2(582, 364, 72, 48), Rect2(72, 0, 36, 24))
	draw_texture_rect_region(COIN, Rect2(689, 376, 32, 32), Rect2((int(elapsed / 0.090) % 6) * 16, 0, 16, 16))
	if is_result:
		draw_texture(_textures["results/headlines/%s.png" % headline], Vector2(144, 112))
	else:
		draw_texture(_textures["logo/get-canned-L1.png"], Vector2(300, 96))
		draw_texture(_textures["ventastic/ventastic.png"], Vector2(1006, 609))


func add_button(key: String, label: String, rect: Rect2, callback: Callable, padded: bool = false, art_root: String = ART, artwork_offset: Vector2 = Vector2.INF) -> Button:
	var button := Button.new()
	button.text = label
	button.name = key.replace("-", "_")
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 12)
	for style in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var art := TextureRect.new()
	art.name = "Artwork"
	art.mouse_filter = MOUSE_FILTER_IGNORE
	art.position = artwork_offset if artwork_offset != Vector2.INF else Vector2(-12, -12) if padded else Vector2.ZERO
	button.add_child(art)
	button.set_meta(&"art_key", key)
	button.set_meta(&"art_root", art_root)
	var refresh := func() -> void: refresh_button(button)
	for event in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited, button.button_down, button.button_up]:
		event.connect(refresh)
	button.pressed.connect(callback)
	add_child(button)
	buttons.append(button)
	refresh_button(button)
	return button


func add_text_button(key: String, label: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.name = key.replace("-", "_")
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	for style in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	add_child(button)
	var plate := ColorRect.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2.ZERO
	plate.size = rect.size
	plate.color = Color("172b3d")
	button.add_child(plate)
	var caption := C2PixelText.new()
	caption.name = "Caption"
	caption.family = "small"
	caption.text = label
	caption.glyph_scale = 3
	caption.color = Color("f2e7c9")
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The approved label is fixed and short. Avoid consulting glyph metrics while
	# this button is still being assembled inside the parent's ready callback.
	caption.position = Vector2(74.0, floorf((rect.size.y - 27.0) * 0.5))
	button.add_child(caption)
	var refresh := func() -> void:
		var active := button.is_pressed() or button.has_focus() or button.is_hovered()
		plate.color = Color("b93743") if active else Color("172b3d")
		caption.color = Color("f2ba45") if active else Color("f2e7c9")
	for event in [
		button.mouse_entered,
		button.mouse_exited,
		button.focus_entered,
		button.focus_exited,
		button.button_down,
		button.button_up,
	]:
		event.connect(refresh)
	button.pressed.connect(callback)
	buttons.append(button)
	refresh.call()
	return button


func add_overload_button(
	key: String,
	asset_stem: String,
	hit_rect: Rect2,
	art_position: Vector2,
	callback: Callable,
	compact: bool = false
) -> Button:
	var button := Button.new()
	button.text = key.to_upper()
	button.name = key.replace("-", "_")
	button.position = hit_rect.position
	button.size = hit_rect.size
	button.focus_mode = Control.FOCUS_ALL
	for style in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var art := TextureRect.new()
	art.name = "Artwork"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.position = art_position - hit_rect.position
	button.add_child(art)
	button.set_meta(&"overload_asset_stem", asset_stem)
	button.set_meta(&"overload_compact", compact)
	var refresh := func() -> void: refresh_overload_button(button)
	for event in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited, button.button_down, button.button_up]:
		event.connect(refresh)
	button.pressed.connect(callback)
	add_child(button)
	buttons.append(button)
	refresh_overload_button(button)
	return button


func refresh_overload_button(button: Button) -> void:
	var state_name := "pressed" if button.is_pressed() else "focus" if button.has_focus() or button.is_hovered() else "idle"
	var suffix := "-compact" if bool(button.get_meta(&"overload_compact", false)) else ""
	var path := "%s%s-%s%s.png" % [
		OVERLOAD_ART,
		str(button.get_meta(&"overload_asset_stem")),
		state_name,
		suffix,
	]
	(button.get_node("Artwork") as TextureRect).texture = load(path)


func refresh_button(button: Button) -> void:
	var state := "pressed" if button.is_pressed() else "focus" if button.has_focus() or button.is_hovered() else "idle"
	(button.get_node("Artwork") as TextureRect).texture = load(str(button.get_meta(&"art_root", ART)) + "buttons/%s/%s.png" % [button.get_meta(&"art_key"), state])


func wire_focus() -> void:
	for i in buttons.size():
		var previous := buttons[i].get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		var next := buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
		buttons[i].focus_previous = previous
		buttons[i].focus_next = next
		buttons[i].focus_neighbor_left = previous
		buttons[i].focus_neighbor_top = previous
		buttons[i].focus_neighbor_right = next
		buttons[i].focus_neighbor_bottom = next
