class_name C2PixelText
extends Control

# Use Work's atlas metrics directly so ink-top alignment is independent of font import.
var text: String = ""
var glyph_scale: int = 3
var color := Color("f2e7c9")
var family: String = "display"
var _glyphs: Dictionary = {}
var _atlas: Texture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	_atlas = load("res://assets/ui/get_canned_c2/glyphs/%s.png" % family)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/get_canned_c2/glyphs/%s-metrics.json" % family))
	for glyph: Dictionary in data.glyphs:
		_glyphs[glyph.character] = glyph
	queue_redraw()


func ink_width(value: String, at_scale: int) -> float:
	var advance := 0
	for character in value:
		advance += int(_glyphs[character].xadvance)
	return maxi(advance - 1, 0) * at_scale


func _draw() -> void:
	var x := 0.0
	for character in text:
		var glyph: Dictionary = _glyphs[character]
		var region := Rect2(glyph.x, glyph.y, glyph.width, glyph.height)
		if region.has_area():
			draw_texture_rect_region(_atlas, Rect2(Vector2(x, 0), region.size * glyph_scale), region, color)
		x += float(glyph.xadvance) * glyph_scale
