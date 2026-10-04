class_name MotionExperimentShell
extends Control

const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const VIS03_FALLING_COLLISION_SIZE := Vector2(60.0, 60.0)
const VIS04_BASELINE_COIN_COLLISION_SIZE := Vector2(24.0, 24.0)
const OVERLOAD_EMERGENCY_VISUAL := preload("res://scripts/experiments/overload_emergency_visual.gd")

@export_enum("D2", "D3") var variant_id: String = "D2"
@export var internal_size := Vector2i(1152, 480)
@export var build_id_override: String = ""
@export var v2_runtime_art_enabled: bool = false
@export var vis02_runtime_art_enabled: bool = false
@export var vis02_falling_collision_size := Vector2(72.0, 72.0)
@export var vis03_runtime_art_enabled: bool = false
@export var vis04_runtime_art_enabled: bool = false
@export var vis04_carriage_raise_pixels: float = 0.0
@export var vis04_coin_collision_size := VIS04_BASELINE_COIN_COLLISION_SIZE
@export var vis04_configuration_id: String = ""
@export var refund_chute_enabled: bool = false
@export var v2_debug_overlay_enabled: bool = false
@export var debug_overlay_toggle_allowed: bool = true
@export var clean_tester_presentation: bool = false
@export var clean_control_hint_duration: float = 4.0
@export var local_instrumentation_enabled: bool = true
@export var overload_mode_enabled: bool = false
@export var vm081_presentation_enabled: bool = false

var conveyor: ConveyorPrototype
var background_drop_director: MotionBackgroundDropDirector
var instrumentation: MotionLocalInstrumentation
var v2_visual_integration: MotionV2VisualIntegration
var overload_emergency_visual: Node2D
var _clean_control_hint_remaining: float = 0.0

@onready var _viewport_frame: SubViewportContainer = $ViewportFrame
@onready var _internal_viewport: SubViewport = $ViewportFrame/InternalViewport


func _ready() -> void:
	# Each variant scene owns its SubViewport size. Keep container stretching off;
	# presentation uses a uniform Control transform so the logical render surface
	# remains exactly the authored size.
	if _internal_viewport.size != internal_size:
		push_error("Motion experiment SubViewport size does not match its profile")
	_viewport_frame.stretch = false
	_internal_viewport.size = internal_size
	_internal_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Rendering regression rule: changing this Control's outer rect does not
	# prove that its nested SubViewport display surface reflowed. Mobile shells
	# resize StandardRun without resizing the root Window, so listen to our own
	# Control lifecycle as the authoritative display-size signal.
	resized.connect(_update_contained_viewport)
	get_viewport().size_changed.connect(_update_contained_viewport)
	_update_contained_viewport()
	_build_variant()
	set_process(true)


func _process(delta: float) -> void:
	if conveyor == null:
		return
	_update_clean_control_hint(delta)
	if (
		v2_runtime_art_enabled
		or vis02_runtime_art_enabled
		or vis03_runtime_art_enabled
		or vis04_runtime_art_enabled
	):
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
	return Rect2(_viewport_frame.position, _viewport_frame.size * _viewport_frame.scale)


func reflow_display() -> void:
	_update_contained_viewport()


func internal_aspect_ratio() -> float:
	return float(internal_size.x) / float(internal_size.y)


func uses_nearest_filtering() -> bool:
	return (
		_viewport_frame.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and _internal_viewport.canvas_item_default_texture_filter
			== Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)


func falling_collision_variant_id() -> String:
	if vis04_runtime_art_enabled:
		return "VIS04-FALL-60"
	if vis03_runtime_art_enabled:
		return "VIS03-FALL-60"
	if not vis02_runtime_art_enabled:
		return ""
	return (
		"VIS02-FALL-60"
		if vis02_falling_collision_size == Vector2(60.0, 60.0)
		else "VIS02-FALL-72"
	)


func _update_contained_viewport() -> void:
	if not is_node_ready():
		return
	var rect := contained_rect(size, Vector2(internal_size))
	_viewport_frame.position = rect.position
	# Preserve the gameplay render at its authored logical resolution. The
	# SubViewportContainer itself remains the same size as InternalViewport and
	# receives one uniform display transform; resizing the container would make
	# `stretch` mutate the child SubViewport resolution.
	_viewport_frame.size = Vector2(internal_size)
	var uniform_scale := rect.size.x / maxf(float(internal_size.x), 1.0)
	_viewport_frame.scale = Vector2(uniform_scale, uniform_scale)
	_internal_viewport.size = internal_size


func _build_variant() -> void:
	conveyor = CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	conveyor.overload_mode_enabled = overload_mode_enabled
	var round_controller := conveyor.get_node("RoundController") as FixedRoundController
	round_controller.fixed_round_enabled = not overload_mode_enabled
	if vis02_runtime_art_enabled:
		conveyor.product_falling_collision_size = vis02_falling_collision_size
	elif vis03_runtime_art_enabled:
		conveyor.product_falling_collision_size = VIS03_FALLING_COLLISION_SIZE
	elif vis04_runtime_art_enabled:
		conveyor.product_falling_collision_size = VIS03_FALLING_COLLISION_SIZE
		# Godot's positive Y points downward. Increasing the existing grounded
		# clearance therefore derives a smaller sweeper centre Y and raises the
		# complete warning/path/collision configuration without changing its X
		# path, size, speed, or timing.
		conveyor.grounded_sweeper_clearance += maxf(
			vis04_carriage_raise_pixels,
			0.0
		)
	_internal_viewport.add_child(conveyor)
	_configure_camera_and_hud()
	_install_project_owned_visuals()
	if variant_id == "D3":
		background_drop_director = MotionBackgroundDropDirector.new()
		background_drop_director.name = "BackgroundDropDirector"
		background_drop_director.endless_schedule_enabled = overload_mode_enabled
		conveyor.add_child(background_drop_director)
	if (
		v2_runtime_art_enabled
		or vis02_runtime_art_enabled
		or vis03_runtime_art_enabled
		or vis04_runtime_art_enabled
	):
		v2_visual_integration = MotionV2VisualIntegration.new()
		v2_visual_integration.name = "V2VisualIntegration"
		v2_visual_integration.conveyor = conveyor
		v2_visual_integration.background_drop_director = background_drop_director
		v2_visual_integration.vis02_enabled = vis02_runtime_art_enabled
		v2_visual_integration.vis03_enabled = (
			vis03_runtime_art_enabled or vis04_runtime_art_enabled
		)
		v2_visual_integration.vis04_enabled = vis04_runtime_art_enabled
		v2_visual_integration.vis04_coin_collision_size = vis04_coin_collision_size
		v2_visual_integration.vis04_configuration_id = vis04_configuration_id
		v2_visual_integration.refund_chute_enabled = refund_chute_enabled
		v2_visual_integration.vm081_electrical_enabled = vm081_presentation_enabled
		v2_visual_integration.debug_overlay_enabled = v2_debug_overlay_enabled
		v2_visual_integration.debug_overlay_toggle_allowed = debug_overlay_toggle_allowed
		conveyor.add_child(v2_visual_integration)
	if overload_mode_enabled and vm081_presentation_enabled:
		overload_emergency_visual = OVERLOAD_EMERGENCY_VISUAL.new()
		overload_emergency_visual.name = "OverloadEmergencyVisual"
		overload_emergency_visual.conveyor = conveyor
		overload_emergency_visual.background_drop_director = background_drop_director
		overload_emergency_visual.debug_stage_keys_enabled = debug_overlay_toggle_allowed
		conveyor.add_child(overload_emergency_visual)
	if local_instrumentation_enabled:
		instrumentation = MotionLocalInstrumentation.new()
		instrumentation.name = "MotionLocalInstrumentation"
		instrumentation.variant_id = variant_id
		conveyor.add_child(instrumentation)
	if (
		not v2_runtime_art_enabled
		and not vis02_runtime_art_enabled
		and not vis03_runtime_art_enabled
		and not vis04_runtime_art_enabled
	):
		_apply_runtime_hazard_skin()


func overload_visual_stage_name() -> String:
	return overload_emergency_visual.stage_name() if is_instance_valid(overload_emergency_visual) else "STANDARD"


func maximum_overload_visual_stage_name() -> String:
	return overload_emergency_visual.maximum_stage_name() if is_instance_valid(overload_emergency_visual) else "STANDARD"


func apply_overload_review_checkpoint(time_seconds: float) -> void:
	if not overload_mode_enabled or not is_instance_valid(conveyor):
		return
	var checkpoint := clampf(time_seconds, 0.0, conveyor.overload_maximum_intensity_time)
	conveyor.apply_overload_review_checkpoint(checkpoint)
	if is_instance_valid(background_drop_director):
		background_drop_director.seek_endless_schedule_for_review(checkpoint)
	if is_instance_valid(overload_emergency_visual):
		overload_emergency_visual.synchronize_to_time(checkpoint)


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
	if vis04_runtime_art_enabled:
		experiment_label.text = "INTERNAL VIS-04  %s" % vis04_configuration_id
	elif vis03_runtime_art_enabled:
		experiment_label.text = "INTERNAL VIS-03 RUNTIME REVIEW"
	elif vis02_runtime_art_enabled:
		experiment_label.text = (
			"INTERNAL VIS-02 COLLISION RETEST  %s" % falling_collision_variant_id()
		)
	else:
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
	if clean_tester_presentation:
		build_label.visible = false
		experiment_label.visible = false
		controls.text = "MOVE: A/D OR LEFT/RIGHT   JUMP: SPACE\nRESTART: R"
		controls.offset_left = 16.0
		controls.offset_top = 8.0
		controls.offset_right = 330.0
		controls.offset_bottom = 54.0
		controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		controls.add_theme_font_size_override("font_size", 11)
		_clean_control_hint_remaining = maxf(clean_control_hint_duration, 0.0)
		controls.visible = _clean_control_hint_remaining > 0.0

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
	background.vis02_consistent_rack = vis02_runtime_art_enabled
	background.vis03_full_rack = vis03_runtime_art_enabled or vis04_runtime_art_enabled
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


func clean_control_hint_is_visible() -> bool:
	if conveyor == null:
		return false
	return (conveyor.get_node("HUD/Controls") as Label).visible


func _update_clean_control_hint(delta: float) -> void:
	if not clean_tester_presentation or _clean_control_hint_remaining <= 0.0:
		return
	_clean_control_hint_remaining = maxf(_clean_control_hint_remaining - delta, 0.0)
	if _clean_control_hint_remaining <= 0.0:
		(conveyor.get_node("HUD/Controls") as Label).visible = false


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
