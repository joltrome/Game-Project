extends SceneTree
func _initialize() -> void:
	assert(ResourceLoader.exists("res://scenes/presentation/standard_session.tscn"))
	assert(ResourceLoader.exists("res://assets/audio/miraie_main_theme_ORIGINAL_MASTER.wav"))
	assert(not ResourceLoader.exists("res://assets/audio/miraie_main_theme_TEMPORARY_DEMO.mp3"))
	assert(FileAccess.file_exists("res://assets/ui/get_canned_c2/glyphs/display-metrics.json"))
	assert(FileAccess.file_exists("res://assets/ui/get_canned_c2/glyphs/small-metrics.json"))
	assert(not DirAccess.dir_exists_absolute("res://builds"))
	assert(not DirAccess.dir_exists_absolute("res://tests"))
	assert(not DirAccess.dir_exists_absolute("res://tools"))
	assert(not DirAccess.dir_exists_absolute("res://docs"))
	assert(OS.has_feature("standard_release") and not OS.has_feature("standard_debug"))
	print("RC1_EXPORT_CONTENT_PASS")
	quit()
