class_name ConveyorCollectible
extends Area2D

signal collected(collectible: ConveyorCollectible)
signal expired(collectible: ConveyorCollectible)

@export_category("Gameplay")
@export var lifetime: float = 3.0
@export var scroll_speed: float = 140.0
@export var collectible_size: Vector2 = Vector2(24.0, 24.0)
@export var placement_band: int = 0

@export_category("Visual Identity")
@export var visual_diameter: float = 32.0
@export var outline_width: float = 2.5
@export var outline_color := Color(0.12, 0.085, 0.025, 1.0)
@export var body_color := Color(1.0, 0.69, 0.06, 1.0)
@export var rim_color := Color(1.0, 0.91, 0.31, 1.0)
@export var mark_color := Color(0.46, 0.25, 0.015, 1.0)

@export_category("Visual Animation")
@export var spin_cycle: float = 0.75
@export_range(0.05, 1.0, 0.01) var spin_minimum_horizontal_scale: float = 0.28
@export var bob_amplitude: float = 3.0
@export var glint_interval_range := Vector2(0.8, 1.4)
@export var glint_duration: float = 0.12
@export var spawn_pop_duration: float = 0.20

@export_category("Feedback")
@export var collection_feedback_duration: float = 0.34
@export var teaching_cue_timeout: float = 2.0

var time_remaining: float = 0.0
var _resolved: bool = false
var _visual_seed: int = 1
var _animation_elapsed: float = 0.0
var _animation_phase: float = 0.0
var _next_glint_time: float = 1.0
var _glint_remaining: float = 0.0
var _teaching_cue_remaining: float = 0.0
var _collection_feedback_remaining: float = 0.0
var _normal_visual_scale := Vector2.ONE

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual_root: Node2D = $VisualRoot
@onready var _outline_visual: Polygon2D = $VisualRoot/Outline
@onready var _body_visual: Polygon2D = $VisualRoot/Body
@onready var _rim_visual: Polygon2D = $VisualRoot/Rim
@onready var _center_mark: Polygon2D = $VisualRoot/CenterMark
@onready var _glint_visual: Polygon2D = $VisualRoot/Glint
@onready var _teaching_cue: Node2D = $TeachingCue
@onready var _teaching_highlight: Polygon2D = $TeachingCue/Highlight
@onready var _collection_feedback: Node2D = $CollectionFeedback
@onready var _burst_visual: Polygon2D = $CollectionFeedback/Burst
@onready var _plus_one_label: Label = $CollectionFeedback/PlusOne


func _ready() -> void:
	_collision_shape.shape = _collision_shape.shape.duplicate()
	_apply_dimensions()
	time_remaining = maxf(lifetime, 0.0)
	_reset_visual_animation()


func _process(delta: float) -> void:
	if _collection_feedback_remaining > 0.0:
		_update_collection_feedback(delta)
		return
	if _resolved:
		return
	_animation_elapsed += delta
	_update_looping_visuals(delta)
	_update_teaching_cue(delta)


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	position.x -= scroll_speed * delta
	time_remaining = maxf(time_remaining - delta, 0.0)
	if time_remaining <= 0.0:
		_resolve(false)


func configure(
	duration: float,
	conveyor_scroll_speed: float,
	size: Vector2,
	band: int = 0,
	visual_seed: int = 1
) -> void:
	lifetime = maxf(duration, 0.0)
	scroll_speed = maxf(conveyor_scroll_speed, 0.0)
	collectible_size = size
	placement_band = band
	_visual_seed = maxi(visual_seed, 1)
	time_remaining = lifetime
	_resolved = false
	monitoring = true
	visible = true
	set_process(true)
	set_physics_process(true)
	if is_node_ready():
		_apply_dimensions()
		_reset_visual_animation()


func show_teaching_cue(duration: float = -1.0) -> void:
	if _resolved:
		return
	_teaching_cue_remaining = maxf(
		teaching_cue_timeout if duration < 0.0 else duration,
		0.0
	)
	_teaching_cue.visible = _teaching_cue_remaining > 0.0


func hide_teaching_cue() -> void:
	_teaching_cue_remaining = 0.0
	_teaching_cue.visible = false


func stop() -> void:
	set_deferred("monitoring", false)
	set_physics_process(false)
	set_process(false)
	hide_teaching_cue()
	_collection_feedback.visible = false
	visible = false


func is_resolved() -> bool:
	return _resolved


func is_non_solid() -> bool:
	return collision_layer == 0 and not monitorable


func collision_geometry_size() -> Vector2:
	var rectangle := _collision_shape.shape as RectangleShape2D
	return rectangle.size


func visual_size() -> Vector2:
	return Vector2(visual_diameter, visual_diameter)


func visual_offset() -> Vector2:
	return _visual_root.position


func current_visual_scale() -> Vector2:
	return _visual_root.scale


func glint_phase_offset() -> float:
	return _animation_phase


func next_glint_time() -> float:
	return _next_glint_time


func teaching_cue_is_visible() -> bool:
	return _teaching_cue.visible


func teaching_cue_blocks_input() -> bool:
	return ($TeachingCue/Label as Label).mouse_filter != Control.MOUSE_FILTER_IGNORE


func collection_feedback_is_visible() -> bool:
	return _collection_feedback.visible


func floating_plus_one_is_visible() -> bool:
	return _collection_feedback.visible and _plus_one_label.visible


func palette() -> Dictionary:
	return {
		"outline": outline_color,
		"body": body_color,
		"rim": rim_color,
		"mark": mark_color,
	}


func _apply_dimensions() -> void:
	var rectangle := _collision_shape.shape as RectangleShape2D
	rectangle.size = collectible_size
	var radius := visual_diameter * 0.5
	_outline_visual.polygon = _circle_polygon(radius, 20)
	_body_visual.polygon = _circle_polygon(maxf(radius - outline_width, 1.0), 20)
	_rim_visual.polygon = _circle_polygon(maxf(radius - outline_width - 3.0, 1.0), 20)
	_center_mark.polygon = PackedVector2Array([
		Vector2(-1.7, -7.0),
		Vector2(1.7, -7.0),
		Vector2(1.7, 7.0),
		Vector2(-1.7, 7.0),
	])
	_glint_visual.polygon = _spark_polygon(4.2, 1.2)
	_teaching_highlight.polygon = _circle_polygon(radius + 5.0, 20)
	_burst_visual.polygon = _spark_polygon(radius + 7.0, radius * 0.45, 8)
	_outline_visual.color = outline_color
	_body_visual.color = body_color
	_rim_visual.color = rim_color
	_center_mark.color = mark_color


func _reset_visual_animation() -> void:
	_animation_elapsed = 0.0
	_animation_phase = _seed_unit(_visual_seed)
	_next_glint_time = lerpf(
		glint_interval_range.x,
		glint_interval_range.y,
		_seed_unit(_visual_seed * 31 + 7)
	)
	_glint_remaining = 0.0
	_glint_visual.visible = false
	_collection_feedback_remaining = 0.0
	_collection_feedback.visible = false
	_plus_one_label.visible = true
	_visual_root.visible = true
	_visual_root.position = Vector2.ZERO
	_visual_root.scale = Vector2.ONE * 0.65
	_normal_visual_scale = Vector2.ONE
	hide_teaching_cue()


func _update_looping_visuals(delta: float) -> void:
	var cycle_progress := (
		fmod(_animation_elapsed / spin_cycle + _animation_phase, 1.0)
		if spin_cycle > 0.0
		else 0.0
	)
	var spin_width := lerpf(
		spin_minimum_horizontal_scale,
		1.0,
		absf(cos(cycle_progress * PI))
	)
	var pop_scale := _spawn_pop_scale()
	_normal_visual_scale = Vector2(spin_width * pop_scale, pop_scale)
	_visual_root.scale = _normal_visual_scale
	_visual_root.position.y = sin(cycle_progress * TAU) * bob_amplitude
	_glint_remaining = maxf(_glint_remaining - delta, 0.0)
	if _animation_elapsed + 0.0001 >= _next_glint_time:
		_glint_remaining = glint_duration
		var interval_seed := _visual_seed + roundi(_next_glint_time * 1000.0)
		_next_glint_time += lerpf(
			glint_interval_range.x,
			glint_interval_range.y,
			_seed_unit(interval_seed)
		)
	_glint_visual.visible = _glint_remaining > 0.0


func _spawn_pop_scale() -> float:
	if spawn_pop_duration <= 0.0 or _animation_elapsed >= spawn_pop_duration:
		return 1.0
	var progress := clampf(_animation_elapsed / spawn_pop_duration, 0.0, 1.0)
	if progress < 0.70:
		return lerpf(0.65, 1.12, progress / 0.70)
	return lerpf(1.12, 1.0, (progress - 0.70) / 0.30)


func _update_teaching_cue(delta: float) -> void:
	if not _teaching_cue.visible:
		return
	_teaching_cue_remaining = maxf(_teaching_cue_remaining - delta, 0.0)
	if _teaching_cue_remaining <= 0.0:
		hide_teaching_cue()


func _begin_collection_feedback() -> void:
	hide_teaching_cue()
	_visual_root.visible = false
	_collection_feedback_remaining = maxf(collection_feedback_duration, 0.01)
	_collection_feedback.visible = true
	_collection_feedback.scale = Vector2.ONE * 0.55
	_collection_feedback.modulate = Color.WHITE
	_plus_one_label.position = Vector2.ZERO
	_plus_one_label.visible = true
	set_process(true)


func _update_collection_feedback(delta: float) -> void:
	_collection_feedback_remaining = maxf(
		_collection_feedback_remaining - delta,
		0.0
	)
	var duration := maxf(collection_feedback_duration, 0.01)
	var progress := 1.0 - _collection_feedback_remaining / duration
	_collection_feedback.scale = Vector2.ONE * lerpf(0.55, 1.35, progress)
	_collection_feedback.modulate.a = 1.0 - progress
	_plus_one_label.position.y = -24.0 * progress
	if _collection_feedback_remaining <= 0.0:
		_collection_feedback.visible = false
		queue_free()


func _resolve(was_collected: bool) -> void:
	if _resolved:
		return
	_resolved = true
	set_deferred("monitoring", false)
	set_physics_process(false)
	if was_collected:
		_begin_collection_feedback()
		collected.emit(self)
	else:
		hide_teaching_cue()
		expired.emit(self)
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _resolved or not body is SharedPlayerController:
		return
	_resolve(true)


func _circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(segments, 3)):
		var angle := TAU * float(index) / float(maxi(segments, 3))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _spark_polygon(
	outer_radius: float,
	inner_radius: float,
	points_count: int = 4
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(points_count, 2) * 2):
		var radius := outer_radius if index % 2 == 0 else inner_radius
		var angle := -PI * 0.5 + PI * float(index) / float(maxi(points_count, 2))
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _seed_unit(seed_value: int) -> float:
	var hashed := posmod(seed_value * 1103515245 + 12345, 10000)
	return float(hashed) / 9999.0
