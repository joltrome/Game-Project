class_name MotionExperimentShell
extends Control

const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")

@export_enum("D2", "D3") var variant_id: String = "D2"
@export var internal_size := Vector2i(1152, 480)
@export var build_id_override: String = ""

var conveyor: ConveyorPrototype
var background_drop_director: MotionBackgroundDropDirector
var instrumentation: MotionLocalInstrumentation

@onready var _viewport_frame: SubViewportContainer = $ViewportFrame
@onready var _internal_viewport: SubViewport = $ViewportFrame/InternalViewport


func _ready() -> void:
	# Each variant scene owns its SubViewport size. Keeping stretch enabled lets
	# the outer container scale it without mutating any project-wide setting.
	if _internal_viewport.size != internal_size:
		push_error("Motion experiment SubViewport size does not match its profile")
	_internal_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().size_changed.connect(_update_contained_viewport)
	_update_contained_viewport()
	_build_variant()
	set_process(true)


func _process(_delta: float) -> void:
	if conveyor == null:
		return
	_apply_runtime_hazard_skin()


static func contained_rect(host_size: Vector2, content_size: Vector2) -> Rect2:
	if host_size.x <= 0.0 or host_size.y <= 0.0 or content_size.x <= 0.0 or content_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var scale_factor := minf(
		host_size.x / content_size.x,
		host_size.y / content_size.y
	)
	var displayed_size := content_size * scale_factor
	return Rect2((host_size - displayed_size) * 0.5, displayed_size)


func displayed_viewport_rect() -> Rect2:
	return Rect2(_viewport_frame.position, _viewport_frame.size)


func internal_aspect_ratio() -> float:
	return float(internal_size.x) / float(internal_size.y)


func uses_nearest_filtering() -> bool:
	return (
		_viewport_frame.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and _internal_viewport.canvas_item_default_texture_filter
			== Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)


func _update_contained_viewport() -> void:
	if not is_node_ready():
		return
	var rect := contained_rect(size, Vector2(internal_size))
	_viewport_frame.position = rect.position
	_viewport_frame.size = rect.size


func _build_variant() -> void:
	conveyor = CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	_internal_viewport.add_child(conveyor)
	_configure_camera_and_hud()
	_install_project_owned_visuals()
	if variant_id == "D3":
		background_drop_director = MotionBackgroundDropDirector.new()
		background_drop_director.name = "BackgroundDropDirector"
		conveyor.add_child(background_drop_director)
	instrumentation = MotionLocalInstrumentation.new()
	instrumentation.name = "MotionLocalInstrumentation"
	instrumentation.variant_id = variant_id
	conveyor.add_child(instrumentation)
	_apply_runtime_hazard_skin()


func _configure_camera_and_hud() -> void:
	var camera := conveyor.get_node("Camera2D") as Camera2D
	camera.position = Vector2(576.0, 412.0 if variant_id == "D2" else 324.0)

	var build_label := conveyor.get_node("HUD/BuildId") as Label
	var build_id := (
		build_id_override
		if not build_id_override.is_empty()
		else "VM-0.5.0-MOTION-01-%s" % variant_id
	)
	build_label.text = "BUILD %s" % build_id
	build_label.add_theme_color_override("font_color", Color("f2e7c9"))
	build_label.add_theme_color_override("font_outline_color", Color("0d1424"))
	build_label.add_theme_constant_override("outline_size", 3)
	build_label.add_theme_font_size_override("font_size", 12)
	build_label.offset_right = 286.0

	var experiment_label := conveyor.get_node("HUD/ExperimentId") as Label
	experiment_label.text = "INTERNAL MOTION STUDY  %s" % variant_id
	experiment_label.add_theme_color_override("font_color", Color("2ca6a4"))
	experiment_label.offset_right = 286.0

	var timer := conveyor.get_node("HUD/Timer") as Label
	timer.offset_top = 14.0
	timer.offset_bottom = 74.0
	timer.add_theme_color_override("font_outline_color", Color("0d1424"))

	var score_group := conveyor.get_node("HUD/ScoreGroup") as Control
	score_group.anchor_left = 1.0
	score_group.anchor_right = 1.0
	score_group.offset_left = -220.0
	score_group.offset_top = 16.0
	score_group.offset_right = -20.0
	score_group.offset_bottom = 74.0

	var hypothesis := conveyor.get_node("HUD/Hypothesis") as Label
	hypothesis.visible = false
	var controls := conveyor.get_node("HUD/Controls") as Label
	controls.offset_top = 420.0 if variant_id == "D2" else 590.0
	controls.offset_bottom = 476.0 if variant_id == "D2" else 646.0
	controls.add_theme_color_override("font_color", Color("f2e7c9"))
	controls.add_theme_color_override("font_outline_color", Color("0d1424"))
	controls.add_theme_constant_override("outline_size", 3)

	var death_message := conveyor.get_node("HUD/DeathMessage") as Label
	if variant_id == "D2":
		death_message.offset_top = 174.0
		death_message.offset_bottom = 306.0


func _install_project_owned_visuals() -> void:
	(conveyor.get_node("Background") as CanvasItem).visible = false
	(conveyor.get_node("ControlBand/BandGuide") as CanvasItem).visible = false
	(conveyor.get_node("ConveyorEnd/Opening") as CanvasItem).visible = false
	(conveyor.get_node("ConveyorEnd/Lip") as CanvasItem).visible = false
	(conveyor.get_node("ConveyorEnd/Label") as CanvasItem).visible = false
	(conveyor.get_node("SourceRack/Cabinet") as CanvasItem).visible = false
	(conveyor.get_node("SourceRack/DisplayWindow") as CanvasItem).visible = false
	(conveyor.get_node("SourceRack/MachineLabel") as CanvasItem).visible = false

	var background := MotionArcadeVisual.new()
	background.name = "MotionArcadeBackground"
	background.compact_crop = variant_id == "D2"
	conveyor.add_child(background)
	var foreground := MotionArcadeVisual.new()
	foreground.name = "MotionArcadeForeground"
	foreground.foreground = true
	foreground.compact_crop = variant_id == "D2"
	conveyor.add_child(foreground)

	var floor_visual := conveyor.get_node("ConveyorBelt/Floor/Visual") as Polygon2D
	floor_visual.color = Color("3978c5")
	var floor_top := conveyor.get_node("ConveyorBelt/Floor/TopSurface") as Polygon2D
	floor_top.color = Color("f2ba45")
	for stripe in conveyor.get_node("ConveyorBelt/Stripes").get_children():
		if stripe is Polygon2D:
			(stripe as Polygon2D).color = Color("173251")

	var player_body := conveyor.get_node("Player/Body") as Polygon2D
	player_body.color = Color("f2e7c9")
	player_body.polygon = PackedVector2Array([
		Vector2(-16.0, -24.0),
		Vector2(12.0, -24.0),
		Vector2(16.0, -14.0),
		Vector2(16.0, 24.0),
		Vector2(-16.0, 24.0),
	])

	var source_head := conveyor.get_node("SourceRack/SourceCarriage/Head") as Polygon2D
	source_head.color = Color("c93c45")
	var source_chute := conveyor.get_node("SourceRack/SourceCarriage/Chute") as Polygon2D
	source_chute.color = Color("f2ba45")
	var warning_text := conveyor.get_node("SourceRack/SourceCarriage/WarningText") as Label
	warning_text.add_theme_color_override("font_color", Color("f2e7c9"))

	var entry_housing := conveyor.get_node("SweeperEntry/Housing") as Polygon2D
	entry_housing.color = Color("7f2634")
	var entry_slot := conveyor.get_node("SweeperEntry/Slot") as Polygon2D
	entry_slot.color = Color("17243a")
	var cue := conveyor.get_node("SweeperEntry/ActivationCue") as Polygon2D
	cue.color = Color("f2ba45")


func _apply_runtime_hazard_skin() -> void:
	for child in conveyor.get_node("Hazards").get_children():
		if child is AirSweeper:
			_skin_carriage(child as AirSweeper)
		elif child is ConveyorProduct:
			_skin_product(child as ConveyorProduct)


func _skin_carriage(sweeper: AirSweeper) -> void:
	if sweeper.has_meta("motion_skin_applied"):
		return
	sweeper.set_meta("motion_skin_applied", true)
	var half := sweeper.hazard_size * 0.5
	var arm := sweeper.get_node("Arm") as Polygon2D
	arm.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	arm.color = Color("5ba85a")
	var housing := sweeper.get_node("Housing") as Polygon2D
	housing.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(-half.x + 22.0, -half.y),
		Vector2(-half.x + 22.0, half.y),
		Vector2(-half.x, half.y),
	])
	housing.color = Color("f2ba45")
	var label := sweeper.get_node("Label") as Label
	label.text = ""


func _skin_product(product: ConveyorProduct) -> void:
	var visual_state := "landed" if product.is_landed() else "falling"
	if product.get_meta("motion_skin_state", "") == visual_state:
		return
	product.set_meta("motion_skin_state", visual_state)
	var body := product.get_node("Body") as Polygon2D
	var band := product.get_node("Band") as Polygon2D
	body.color = Color("2ca6a4") if visual_state == "falling" else Color("3978c5")
	band.color = Color("f2ba45")
	var label := product.get_node("Label") as Label
	label.text = "DRINK"
	label.add_theme_color_override("font_color", Color("f2e7c9"))
	label.add_theme_color_override("font_outline_color", Color("0d1424"))
	label.add_theme_constant_override("outline_size", 2)
