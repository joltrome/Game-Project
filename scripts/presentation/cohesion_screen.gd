class_name CohesionScreen
extends C2Screen

const ROOT := "res://assets/ui/get_canned_rc2/"
var kind: String = "credits"
var layout: Dictionary
var credit_entries: Array = []

func _ready() -> void:
	size = Vector2(1152,648)
	mouse_filter = MOUSE_FILTER_STOP if kind == "pause" else MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	layout = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"layout.json"))
	credit_entries = layout.credits.current_content
	for entry: Dictionary in layout.layers[kind]:
		if "/buttons/" not in str(entry.asset):
			_textures[entry.asset] = load(ROOT+entry.asset)
	set_process(false)

func _draw() -> void:
	for entry: Dictionary in layout.layers[kind]:
		if "/buttons/" not in str(entry.asset):
			draw_texture(_textures[entry.asset],Vector2(entry.position[0],entry.position[1]))

func add_action(key: String, callback: Callable) -> Button:
	var entry: Dictionary = layout.buttons[key]
	var rect := Rect2(entry.hit[0],entry.hit[1],entry.hit[2],entry.hit[3])
	var texture_at := Vector2(entry.texture_position[0],entry.texture_position[1])
	var art_key := str(entry.states.idle).split("/")[2]
	return add_button(art_key,entry.label,rect,callback,false,ROOT+kind+"/",texture_at-rect.position)
