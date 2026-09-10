class_name C2PixelText
extends Control

# Use Work's atlas metrics directly so ink-top alignment is independent of font import.
var text: String = ""
var glyph_scale: int = 3
var color := Color("f2e7c9")
var family: String = "display"
var _glyphs: Dictionary = {}
var _atlas: Texture2D

const CUSTOM_PLUS_ADVANCE := {
	"display": 6,
	"small": 4,
}


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
		advance += _glyph_advance(character)
	return maxi(advance - 1, 0) * at_scale


func supports_text(value: String) -> bool:
	for character in value:
		if character != "+" and not _glyphs.has(character):
			return false
	return true


func _draw() -> void:
	var x := 0.0
	for character in text:
		if character == "+":
			_draw_plus(x)
			x += float(_glyph_advance(character)) * glyph_scale
			continue
		var glyph: Dictionary = _glyphs[character]
		var region := Rect2(glyph.x, glyph.y, glyph.width, glyph.height)
		if region.has_area():
			draw_texture_rect_region(_atlas, Rect2(Vector2(x, 0), region.size * glyph_scale), region, color)
		x += float(glyph.xadvance) * glyph_scale


func _glyph_advance(character: String) -> int:
	if character == "+":
		return int(CUSTOM_PLUS_ADVANCE.get(family, CUSTOM_PLUS_ADVANCE.display))
	return int(_glyphs[character].xadvance)


func _draw_plus(x: float) -> void:
	# The approved atlases contain every required letter and numeral but no plus.
	# Keep the operator on the same integer grid instead of falling back to a
	# second font or adding a new font asset.
	var scale_value := float(glyph_scale)
	if family == "small":
		draw_rect(Rect2(x + scale_value, scale_value, scale_value, 5.0 * scale_value), color)
		draw_rect(Rect2(x, 3.0 * scale_value, 3.0 * scale_value, scale_value), color)
		return
	draw_rect(Rect2(x + 2.0 * scale_value, scale_value, scale_value, 7.0 * scale_value), color)
	draw_rect(Rect2(x, 4.0 * scale_value, 5.0 * scale_value, scale_value), color)
