class_name ConveyorCollectible
extends Area2D

signal collected(collectible: ConveyorCollectible)
signal expired(collectible: ConveyorCollectible)
signal expiry_warning_started(collectible: ConveyorCollectible)
signal first_conveyor_contact(collectible: ConveyorCollectible)
signal bounce_started(collectible: ConveyorCollectible, bounce_number: int)
signal settled(collectible: ConveyorCollectible)
signal landed_can_ricochet(
	collectible: ConveyorCollectible,
	ricochet_count: int,
	contact_kind: String
)
signal supported_on_can(collectible: ConveyorCollectible, can_id: int)
signal support_lost(collectible: ConveyorCollectible, can_id: int, resolution: String)
signal world_overlap_corrected(collectible: ConveyorCollectible, reason: String)

enum MotionState {
	CONVEYOR,
	PENDING_LAUNCH,
	AIRBORNE,
	BOUNCING,
	RICOCHETING,
	SUPPORTED_ON_CAN,
	SETTLED,
}

@export_category("Gameplay")
@export var lifetime: float = 3.0
@export var scroll_speed: float = 140.0
@export var collectible_size: Vector2 = Vector2(24.0, 24.0)
@export var placement_band: int = 0

@export_category("Expiry Warning")
@export var expiry_warning_duration: float = 0.70
@export_range(0.5, 4.0, 0.1) var expiry_warning_start_pulses_per_second: float = 1.5
@export_range(1.0, 5.0, 0.1) var expiry_warning_end_pulses_per_second: float = 4.0
@export_range(0.25, 0.9, 0.05) var expiry_warning_minimum_alpha: float = 0.45

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

@export_category("Ballistic Prototype")
@export var ballistic_gravity: float = 1250.0
@export var bounce_restitutions := Vector2(0.38, 0.16)
@export var world_physics_size := Vector2(32.0, 32.0)
@export var can_support_maximum_vertical_speed: float = 260.0

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
var _c2_typography_enabled: bool = false
var _expiry_warning_active: bool = false
var _expiry_warning_elapsed: float = 0.0
var _expiry_warning_start_count: int = 0
var _current_warning_pulses_per_second: float = 0.0
var _ballistic_enabled: bool = false
var _motion_state: MotionState = MotionState.CONVEYOR
var _launch_position := Vector2.ZERO
var _launch_velocity := Vector2.ZERO
var _flight_duration: float = 0.0
var _flight_elapsed: float = 0.0
var _landing_position := Vector2.ZERO
var _post_contact_lifetime: float = 0.0
var _first_contact_occurred: bool = false
var _first_contact_incoming_speed: float = 0.0
var _first_contact_time: float = -1.0
var _bounce_number: int = 0
var _bounce_elapsed: float = 0.0
var _bounce_duration: float = 0.0
var _bounce_launch_velocity_y: float = 0.0
var _settled_count: int = 0
var _launch_delay_remaining: float = 0.0
var _launch_age: float = 0.0
var _collection_phase: String = ""
var _collection_time_from_launch: float = -1.0
var _resolution_reason: String = ""
var _left_exit_x: float = -INF
var _landed_can_query := Callable()
var _maximum_landed_can_ricochets: int = 0
var _landed_can_ricochet_count: int = 0
var _ricochet_velocity := Vector2.ZERO
var _ricochet_contact_cooldown: float = 0.0
var _last_ricochet_can_id: int = -1
var _can_top_restitution: float = 0.34
var _can_side_horizontal_restitution: float = 0.35
var _can_side_upward_speed: float = 180.0
var _can_horizontal_deflection: float = 70.0
var _escape_x_bounds := Vector2(-INF, INF)
var _support_claim := Callable()
var _support_release := Callable()
var _supported_can_id: int = -1
var _supported_can_offset_x: float = 0.0
var _support_loss_fall: bool = false

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
	_update_expiry_warning(delta)
	_update_teaching_cue(delta)


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	if _ballistic_enabled:
		_update_ballistic_motion(maxf(delta, 0.0))
		_check_left_exit()
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
	visual_seed: int = 1,
	warning_duration: float = -1.0
) -> void:
	_ballistic_enabled = false
	_motion_state = MotionState.CONVEYOR
	lifetime = maxf(duration, 0.0)
	scroll_speed = maxf(conveyor_scroll_speed, 0.0)
	collectible_size = size
	placement_band = band
	_visual_seed = maxi(visual_seed, 1)
	if warning_duration >= 0.0:
		expiry_warning_duration = warning_duration
	time_remaining = lifetime
	_resolved = false
	_resolution_reason = ""
	_collection_phase = ""
	_collection_time_from_launch = -1.0
	monitoring = true
	visible = true
	set_process(true)
	set_physics_process(true)
	if is_node_ready():
		_apply_dimensions()
		_reset_visual_animation()


func configure_ballistic(
	launch_position: Vector2,
	landing_position: Vector2,
	launch_velocity: Vector2,
	flight_duration: float,
	gravity: float,
	post_contact_duration: float,
	conveyor_scroll_speed: float,
	restitutions: Vector2,
	launch_delay: float = 0.0,
	left_exit_x: float = -INF
) -> void:
	_ballistic_enabled = true
	_launch_delay_remaining = maxf(launch_delay, 0.0)
	_motion_state = (
		MotionState.PENDING_LAUNCH
		if _launch_delay_remaining > 0.0
		else MotionState.AIRBORNE
	)
	_launch_position = launch_position
	_landing_position = landing_position
	_launch_velocity = launch_velocity
	_flight_duration = maxf(flight_duration, 0.01)
	_flight_elapsed = 0.0
	ballistic_gravity = maxf(gravity, 1.0)
	_post_contact_lifetime = maxf(post_contact_duration, 0.0)
	lifetime = _post_contact_lifetime
	time_remaining = _post_contact_lifetime
	scroll_speed = maxf(conveyor_scroll_speed, 0.0)
	bounce_restitutions = Vector2(
		clampf(restitutions.x, 0.0, 1.0),
		clampf(restitutions.y, 0.0, 1.0)
	)
	_first_contact_occurred = false
	_first_contact_incoming_speed = 0.0
	_first_contact_time = -1.0
	_bounce_number = 0
	_bounce_elapsed = 0.0
	_bounce_duration = 0.0
	_bounce_launch_velocity_y = 0.0
	_settled_count = 0
	_launch_age = 0.0
	_collection_phase = ""
	_collection_time_from_launch = -1.0
	_resolution_reason = ""
	_left_exit_x = left_exit_x
	_landed_can_ricochet_count = 0
	_ricochet_velocity = Vector2.ZERO
	_ricochet_contact_cooldown = 0.0
	_last_ricochet_can_id = -1
	_release_supported_can()
	_support_loss_fall = false
	position = launch_position
	_resolved = false
	monitoring = _launch_delay_remaining <= 0.0
	visible = _launch_delay_remaining <= 0.0
	set_process(true)
	set_physics_process(true)
	_cancel_expiry_warning()


func configure_landed_can_collision(
	query: Callable,
	escape_x_bounds: Vector2,
	maximum_ricochets: int = 2,
	top_restitution: float = 0.34,
	side_horizontal_restitution: float = 0.35,
	side_upward_speed: float = 180.0,
	horizontal_deflection: float = 70.0,
	physical_size: Vector2 = Vector2(32.0, 32.0),
	support_maximum_vertical_speed: float = 260.0,
	support_claim: Callable = Callable(),
	support_release: Callable = Callable()
) -> void:
	_landed_can_query = query
	_escape_x_bounds = escape_x_bounds
	_maximum_landed_can_ricochets = maxi(maximum_ricochets, 0)
	_can_top_restitution = clampf(top_restitution, 0.0, 1.0)
	_can_side_horizontal_restitution = clampf(
		side_horizontal_restitution,
		0.0,
		1.0
	)
	_can_side_upward_speed = maxf(side_upward_speed, 0.0)
	_can_horizontal_deflection = maxf(horizontal_deflection, 0.0)
	world_physics_size = Vector2(
		maxf(physical_size.x, collectible_size.x),
		maxf(physical_size.y, collectible_size.y)
	)
	can_support_maximum_vertical_speed = maxf(support_maximum_vertical_speed, 0.0)
	_support_claim = support_claim
	_support_release = support_release


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
	_release_supported_can()
	set_deferred("monitoring", false)
	set_physics_process(false)
	set_process(false)
	hide_teaching_cue()
	_collection_feedback.visible = false
	_cancel_expiry_warning()
	visible = false


func is_resolved() -> bool:
	return _resolved


func is_ballistic() -> bool:
	return _ballistic_enabled


func motion_state() -> MotionState:
	return _motion_state


func motion_state_name() -> String:
	match _motion_state:
		MotionState.PENDING_LAUNCH:
			return "PENDING_LAUNCH"
		MotionState.AIRBORNE:
			return "AIRBORNE"
		MotionState.BOUNCING:
			return "BOUNCING"
		MotionState.RICOCHETING:
			return "RICOCHETING"
		MotionState.SUPPORTED_ON_CAN:
			return "SUPPORTED_ON_CAN"
		MotionState.SETTLED:
			return "SETTLED"
	return "CONVEYOR"


func flight_duration() -> float:
	return _flight_duration


func flight_elapsed() -> float:
	return _flight_elapsed


func first_contact_occurred() -> bool:
	return _first_contact_occurred


func first_contact_time() -> float:
	return _first_contact_time


func bounce_count() -> int:
	return _bounce_number


func settled_count() -> int:
	return _settled_count


func landing_position() -> Vector2:
	return _landing_position


func post_contact_lifetime() -> float:
	return _post_contact_lifetime


func total_collectible_time_remaining() -> float:
	if _ballistic_enabled and _motion_state == MotionState.PENDING_LAUNCH:
		return _launch_delay_remaining + _flight_duration + time_remaining
	if _ballistic_enabled and _motion_state == MotionState.AIRBORNE:
		return maxf(_flight_duration - _flight_elapsed, 0.0) + time_remaining
	return time_remaining


func launch_delay_remaining() -> float:
	return _launch_delay_remaining


func landed_can_ricochet_count() -> int:
	return _landed_can_ricochet_count


func collection_phase() -> String:
	return _collection_phase


func collection_time_from_launch() -> float:
	return _collection_time_from_launch


func resolution_reason() -> String:
	return _resolution_reason


func is_inside_landed_can() -> bool:
	return not _overlapping_landed_can().is_empty()


func world_collision_size() -> Vector2:
	return world_physics_size


func supported_can_id() -> int:
	return _supported_can_id


func is_supported_on_can() -> bool:
	return _motion_state == MotionState.SUPPORTED_ON_CAN and _supported_can_id >= 0


func launch_velocity() -> Vector2:
	return _launch_velocity


func projected_horizontal_interval(
	seconds_from_now: float,
	duration: float
) -> Vector2:
	var start := maxf(seconds_from_now, 0.0)
	var end := start + maxf(duration, 0.0)
	var samples := PackedFloat32Array([start, end])
	if _ballistic_enabled and _motion_state == MotionState.PENDING_LAUNCH:
		if _launch_delay_remaining > start and _launch_delay_remaining < end:
			samples.append(_launch_delay_remaining)
		var delayed_landing := _launch_delay_remaining + _flight_duration
		if delayed_landing > start and delayed_landing < end:
			samples.append(delayed_landing)
	elif _ballistic_enabled and _motion_state == MotionState.AIRBORNE:
		var remaining_flight := maxf(_flight_duration - _flight_elapsed, 0.0)
		if remaining_flight > start and remaining_flight < end:
			samples.append(remaining_flight)
	var minimum_x := INF
	var maximum_x := -INF
	for sample_time in samples:
		var projected_x := _projected_x_after(float(sample_time))
		minimum_x = minf(minimum_x, projected_x)
		maximum_x = maxf(maximum_x, projected_x)
	return Vector2(minimum_x, maximum_x)


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


func expiry_warning_is_active() -> bool:
	return _expiry_warning_active


func expiry_warning_progress() -> float:
	if not _expiry_warning_active:
		return 0.0
	var duration := minf(maxf(expiry_warning_duration, 0.0), maxf(lifetime, 0.0))
	if duration <= 0.0:
		return 1.0
	return clampf(1.0 - time_remaining / duration, 0.0, 1.0)


func current_warning_pulses_per_second() -> float:
	return _current_warning_pulses_per_second


func current_visual_alpha() -> float:
	return modulate.a


func expiry_warning_start_count() -> int:
	return _expiry_warning_start_count


func enable_c2_typography() -> void:
	if _c2_typography_enabled:
		return
	_c2_typography_enabled = true
	var teaching_label := $TeachingCue/Label as Label
	teaching_label.offset_left = -78.0
	teaching_label.offset_right = 78.0
	_make_font_ink_transparent(teaching_label)
	var teaching_text := C2PixelText.new()
	teaching_text.name = "C2Text"
	teaching_text.family = "small"
	teaching_text.text = "REFUND COIN +1"
	teaching_text.glyph_scale = 2
	teaching_text.color = Color(1.0, 0.91, 0.31, 1.0)
	teaching_label.add_child(teaching_text)
	teaching_text.position = Vector2(
		floorf((teaching_label.size.x - teaching_text.ink_width(teaching_text.text, 2)) * 0.5),
		2.0
	)
	_make_font_ink_transparent(_plus_one_label)
	var feedback_text := C2PixelText.new()
	feedback_text.name = "C2Text"
	feedback_text.family = "display"
	feedback_text.text = "+1"
	feedback_text.glyph_scale = 2
	feedback_text.color = Color(1.0, 0.92, 0.36, 1.0)
	_plus_one_label.add_child(feedback_text)
	feedback_text.position = Vector2(
		floorf((_plus_one_label.size.x - feedback_text.ink_width(feedback_text.text, 2)) * 0.5),
		4.0
	)


func c2_typography_is_enabled() -> bool:
	return _c2_typography_enabled


func palette() -> Dictionary:
	return {
		"outline": outline_color,
		"body": body_color,
		"rim": rim_color,
		"mark": mark_color,
	}


func _make_font_ink_transparent(label: Label) -> void:
	label.add_theme_color_override("font_color", Color.TRANSPARENT)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)


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
	_cancel_expiry_warning()
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
	var visual_bob := sin(cycle_progress * TAU) * bob_amplitude
	# A supported coin may visually rise from its support, but never bob down into it.
	_visual_root.position.y = (
		minf(visual_bob, 0.0)
		if _motion_state == MotionState.SUPPORTED_ON_CAN
		else visual_bob
	)
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


func _update_expiry_warning(delta: float) -> void:
	var warning_duration := minf(
		maxf(expiry_warning_duration, 0.0),
		maxf(lifetime, 0.0)
	)
	if warning_duration <= 0.0 or time_remaining > warning_duration + 0.0001:
		return
	if not _expiry_warning_active:
		_expiry_warning_active = true
		_expiry_warning_elapsed = 0.0
		_expiry_warning_start_count += 1
		expiry_warning_started.emit(self)
	_expiry_warning_elapsed += delta
	var progress := expiry_warning_progress()
	_current_warning_pulses_per_second = lerpf(
		maxf(expiry_warning_start_pulses_per_second, 0.5),
		maxf(expiry_warning_end_pulses_per_second, expiry_warning_start_pulses_per_second),
		progress
	)
	# Continuous opacity modulation keeps the warning readable without an
	# aggressive full-on/full-off strobe. The per-coin seed prevents deliberate
	# synchronization when two warning windows overlap.
	var phase := (
		_expiry_warning_elapsed * _current_warning_pulses_per_second * TAU
		+ _animation_phase * TAU
	)
	var pulse := 0.5 + 0.5 * sin(phase)
	var minimum_alpha := lerpf(0.78, expiry_warning_minimum_alpha, progress)
	modulate.a = lerpf(minimum_alpha, 1.0, pulse)


func _cancel_expiry_warning() -> void:
	_expiry_warning_active = false
	_expiry_warning_elapsed = 0.0
	_current_warning_pulses_per_second = 0.0
	modulate.a = 1.0


func _update_teaching_cue(delta: float) -> void:
	if not _teaching_cue.visible:
		return
	_teaching_cue_remaining = maxf(_teaching_cue_remaining - delta, 0.0)
	if _teaching_cue_remaining <= 0.0:
		hide_teaching_cue()


func _begin_collection_feedback() -> void:
	hide_teaching_cue()
	_cancel_expiry_warning()
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


func _update_ballistic_motion(delta: float) -> void:
	var remaining := delta
	var guard := 0
	while remaining > 0.000001 and not _resolved and guard < 512:
		guard += 1
		match _motion_state:
			MotionState.PENDING_LAUNCH:
				remaining = _step_pending_launch(remaining)
			MotionState.AIRBORNE:
				remaining = _step_airborne(remaining)
			MotionState.BOUNCING:
				remaining = _step_bounce(remaining)
			MotionState.RICOCHETING:
				remaining = _step_ricochet(remaining)
			MotionState.SUPPORTED_ON_CAN:
				remaining = _step_supported_on_can(remaining)
			MotionState.SETTLED:
				_step_post_contact_lifetime(remaining)
				if _resolved:
					return
				_launch_age += remaining
				position.x -= scroll_speed * remaining
				remaining = 0.0
			_:
				remaining = 0.0



func _step_pending_launch(delta: float) -> float:
	var step := minf(delta, _launch_delay_remaining)
	_launch_delay_remaining = maxf(_launch_delay_remaining - step, 0.0)
	if _launch_delay_remaining > 0.000001:
		return 0.0
	_motion_state = MotionState.AIRBORNE
	monitoring = true
	visible = true
	return maxf(delta - step, 0.0)


func _step_airborne(delta: float) -> float:
	var flight_remaining := maxf(_flight_duration - _flight_elapsed, 0.0)
	var step := minf(delta, flight_remaining)
	var previous_position := position
	_flight_elapsed += step
	_launch_age += step
	var next_position := Vector2(
		_launch_position.x + _launch_velocity.x * _flight_elapsed,
		_launch_position.y
		+ _launch_velocity.y * _flight_elapsed
		+ 0.5 * ballistic_gravity * _flight_elapsed * _flight_elapsed
	)
	var current_velocity := Vector2(
		_launch_velocity.x,
		_launch_velocity.y + ballistic_gravity * _flight_elapsed
	)
	var can_contact := _landed_can_contact(
		previous_position,
		next_position,
		current_velocity
	)
	if not can_contact.is_empty():
		position = can_contact.position
		_handle_landed_can_contact(current_velocity, can_contact)
		return maxf(delta - step, 0.0)
	position = next_position
	if _flight_elapsed + 0.000001 < _flight_duration:
		return 0.0
	position = _landing_position
	_register_first_conveyor_contact(absf(current_velocity.y))
	_start_bounce(1)
	return maxf(delta - step, 0.0)


func _start_bounce(number: int) -> void:
	_bounce_number = number
	_motion_state = MotionState.BOUNCING
	_bounce_elapsed = 0.0
	var restitution := (
		bounce_restitutions.x if number == 1 else bounce_restitutions.y
	)
	_bounce_launch_velocity_y = -_first_contact_incoming_speed * restitution
	_bounce_duration = (
		2.0 * absf(_bounce_launch_velocity_y) / ballistic_gravity
		if ballistic_gravity > 0.0
		else 0.0
	)
	bounce_started.emit(self, number)


func _step_bounce(delta: float) -> float:
	var bounce_remaining := maxf(_bounce_duration - _bounce_elapsed, 0.0)
	var step := minf(delta, bounce_remaining)
	_step_post_contact_lifetime(step)
	if _resolved:
		return 0.0
	var previous_position := position
	var next_x := position.x - scroll_speed * step
	_bounce_elapsed += step
	_launch_age += step
	var next_y := (
		_landing_position.y
		+ _bounce_launch_velocity_y * _bounce_elapsed
		+ 0.5 * ballistic_gravity * _bounce_elapsed * _bounce_elapsed
	)
	var current_velocity := Vector2(
		-scroll_speed,
		_bounce_launch_velocity_y + ballistic_gravity * _bounce_elapsed
	)
	var next_position := Vector2(next_x, next_y)
	var can_contact := _landed_can_contact(
		previous_position,
		next_position,
		current_velocity
	)
	if not can_contact.is_empty():
		position = can_contact.position
		_handle_landed_can_contact(current_velocity, can_contact)
		return maxf(delta - step, 0.0)
	position = next_position
	if _bounce_elapsed + 0.000001 < _bounce_duration:
		return 0.0
	position.y = _landing_position.y
	var leftover := maxf(delta - step, 0.0)
	if _bounce_number < 2:
		_start_bounce(_bounce_number + 1)
	else:
		_settle()
	return leftover


func _register_first_conveyor_contact(incoming_speed: float) -> void:
	if _first_contact_occurred:
		return
	_first_contact_occurred = true
	_first_contact_time = _launch_age
	_first_contact_incoming_speed = absf(incoming_speed)
	time_remaining = _post_contact_lifetime
	first_conveyor_contact.emit(self)


func _settle() -> void:
	if not _overlapping_landed_can().is_empty():
		_force_clear_settle()
		return
	_motion_state = MotionState.SETTLED
	_settled_count += 1
	settled.emit(self)


func _handle_landed_can_contact(
	incoming_velocity: Vector2,
	contact: Dictionary
) -> void:
	var normal := contact.get("normal", Vector2.UP) as Vector2
	var is_later_low_energy_top := (
		normal.y < -0.5
		and (_landed_can_ricochet_count > 0 or _bounce_number > 0)
		and absf(incoming_velocity.y) <= can_support_maximum_vertical_speed
	)
	if is_later_low_energy_top and _begin_can_support(contact):
		return
	_begin_can_ricochet(incoming_velocity, contact)


func _begin_can_support(contact: Dictionary) -> bool:
	var can_id := int(contact.get("id", -1))
	if can_id < 0:
		return false
	if _support_claim.is_valid() and not bool(_support_claim.call(can_id, self)):
		return false
	var center := contact.get("center", position) as Vector2
	var size := contact.get("size", Vector2.ZERO) as Vector2
	_supported_can_id = can_id
	_supported_can_offset_x = position.x - center.x
	position.y = center.y - size.y * 0.5 - world_physics_size.y * 0.5
	_motion_state = MotionState.SUPPORTED_ON_CAN
	_ricochet_velocity = Vector2.ZERO
	_support_loss_fall = false
	if not _first_contact_occurred:
		_register_first_conveyor_contact(0.0)
	supported_on_can.emit(self, can_id)
	return true


func _release_supported_can() -> int:
	var released_id := _supported_can_id
	if released_id >= 0 and _support_release.is_valid():
		_support_release.call(released_id, self)
	_supported_can_id = -1
	_supported_can_offset_x = 0.0
	return released_id


func _begin_can_ricochet(incoming_velocity: Vector2, contact: Dictionary) -> void:
	var can_id := int(contact.get("id", -1))
	if (
		_landed_can_ricochet_count >= _maximum_landed_can_ricochets
		or _maximum_landed_can_ricochets <= 0
	):
		_force_clear_settle()
		return
	_landed_can_ricochet_count += 1
	_last_ricochet_can_id = can_id
	_ricochet_contact_cooldown = 0.08
	var normal := contact.get("normal", Vector2.UP) as Vector2
	var can_center := contact.get("center", position) as Vector2
	var away_sign := signf(position.x - can_center.x)
	if is_zero_approx(away_sign):
		away_sign = -1.0 if _landed_can_ricochet_count % 2 == 1 else 1.0
	var contact_kind := "TOP"
	if absf(normal.x) > 0.5:
		contact_kind = "SIDE"
		_ricochet_velocity = Vector2(
			-incoming_velocity.x * _can_side_horizontal_restitution
			+ normal.x * _can_horizontal_deflection,
			-_can_side_upward_speed
		)
	else:
		_ricochet_velocity = Vector2(
			incoming_velocity.x + away_sign * _can_horizontal_deflection,
			-maxf(
				absf(incoming_velocity.y) * _can_top_restitution,
				_can_side_upward_speed
			)
		)
	_motion_state = MotionState.RICOCHETING
	landed_can_ricochet.emit(
		self,
		_landed_can_ricochet_count,
		contact_kind
	)


func _force_clear_settle() -> void:
	_release_supported_can()
	var clear_x := _nearest_clear_conveyor_x(position.x)
	position = Vector2(clear_x, _landing_position.y)
	if not _overlapping_landed_can().is_empty():
		_resolve(false, "EXPIRED")
		return
	if not _first_contact_occurred:
		_register_first_conveyor_contact(absf(_ricochet_velocity.y))
	_motion_state = MotionState.SETTLED
	_settled_count += 1
	settled.emit(self)


func _landed_can_contact(
	previous_position: Vector2,
	next_position: Vector2,
	velocity: Vector2
) -> Dictionary:
	if not _landed_can_query.is_valid():
		return {}
	var coin_half := world_physics_size * 0.5
	for can_data in _landed_can_query.call():
		var can_id := int(can_data.get("id", -1))
		if can_id == _last_ricochet_can_id and _ricochet_contact_cooldown > 0.0:
			continue
		var center := can_data.get("center", Vector2.ZERO) as Vector2
		var size := can_data.get("size", Vector2.ZERO) as Vector2
		var expanded_half := size * 0.5 + coin_half
		var left := center.x - expanded_half.x
		var right := center.x + expanded_half.x
		var top := center.y - expanded_half.y
		var bottom := center.y + expanded_half.y
		if (
			velocity.y > 0.0
			and previous_position.y <= top + 0.001
			and next_position.y >= top - 0.001
		):
			var denominator := next_position.y - previous_position.y
			var ratio := (
				clampf((top - previous_position.y) / denominator, 0.0, 1.0)
				if not is_zero_approx(denominator)
				else 0.0
			)
			var contact_x := lerpf(previous_position.x, next_position.x, ratio)
			if contact_x >= left and contact_x <= right:
				return {
					"id": can_id,
					"center": center,
					"size": size,
					"position": Vector2(contact_x, top),
					"normal": Vector2.UP,
				}
		var crossed_side := false
		var side_x := 0.0
		var side_normal_x := 0.0
		if velocity.x > 0.0 and previous_position.x <= left and next_position.x >= left:
			crossed_side = true
			side_x = left
			side_normal_x = -1.0
		elif velocity.x < 0.0 and previous_position.x >= right and next_position.x <= right:
			crossed_side = true
			side_x = right
			side_normal_x = 1.0
		if crossed_side:
			var denominator := next_position.x - previous_position.x
			var ratio := (
				clampf((side_x - previous_position.x) / denominator, 0.0, 1.0)
				if not is_zero_approx(denominator)
				else 0.0
			)
			var contact_y := lerpf(previous_position.y, next_position.y, ratio)
			if contact_y >= top and contact_y <= bottom:
				return {
					"id": can_id,
					"center": center,
					"size": size,
					"position": Vector2(side_x, contact_y),
					"normal": Vector2(side_normal_x, 0.0),
				}
		if (
			next_position.x >= left
			and next_position.x <= right
			and next_position.y >= top
			and next_position.y <= bottom
		):
			var normal_x := -1.0 if previous_position.x <= center.x else 1.0
			return {
				"id": can_id,
				"center": center,
				"size": size,
				"position": Vector2(
					left if normal_x < 0.0 else right,
					clampf(next_position.y, top, bottom)
				),
				"normal": Vector2(normal_x, 0.0),
			}
	return {}


func _overlapping_landed_can(at_position: Vector2 = Vector2.INF) -> Dictionary:
	if not _landed_can_query.is_valid():
		return {}
	var candidate := position if at_position == Vector2.INF else at_position
	var coin_half := world_physics_size * 0.5
	for can_data in _landed_can_query.call():
		var center := can_data.get("center", Vector2.ZERO) as Vector2
		var size := can_data.get("size", Vector2.ZERO) as Vector2
		var half := size * 0.5 + coin_half
		if (
			absf(candidate.x - center.x) < half.x
			and absf(candidate.y - center.y) < half.y
		):
			return can_data
	return {}


func _nearest_clear_conveyor_x(preferred_x: float) -> float:
	var minimum_x := minf(_escape_x_bounds.x, _escape_x_bounds.y)
	var maximum_x := maxf(_escape_x_bounds.x, _escape_x_bounds.y)
	var clamped := clampf(preferred_x, minimum_x, maximum_x)
	if not _landed_can_query.is_valid():
		return clamped
	var coin_half := world_physics_size.x * 0.5
	var candidates := PackedFloat32Array([clamped])
	for can_data in _landed_can_query.call():
		var center := can_data.get("center", Vector2.ZERO) as Vector2
		var size := can_data.get("size", Vector2.ZERO) as Vector2
		var clearance := size.x * 0.5 + coin_half + 4.0
		candidates.append(clampf(center.x - clearance, minimum_x, maximum_x))
		candidates.append(clampf(center.x + clearance, minimum_x, maximum_x))
	var best := clamped
	var best_distance := INF
	for candidate_x in candidates:
		var candidate_position := Vector2(candidate_x, _landing_position.y)
		if not _overlapping_landed_can(candidate_position).is_empty():
			continue
		var distance := absf(candidate_x - preferred_x)
		if distance < best_distance:
			best_distance = distance
			best = candidate_x
	return best


func _step_ricochet(delta: float) -> float:
	var step := minf(delta, 1.0 / 120.0)
	if _first_contact_occurred:
		_step_post_contact_lifetime(step)
		if _resolved:
			return 0.0
	_launch_age += step
	_ricochet_contact_cooldown = maxf(_ricochet_contact_cooldown - step, 0.0)
	var previous_position := position
	var next_position := (
		position
		+ _ricochet_velocity * step
		+ Vector2(0.0, 0.5 * ballistic_gravity * step * step)
	)
	_ricochet_velocity.y += ballistic_gravity * step
	var can_contact := _landed_can_contact(
		previous_position,
		next_position,
		_ricochet_velocity
	)
	if not can_contact.is_empty():
		position = can_contact.position
		_handle_landed_can_contact(_ricochet_velocity, can_contact)
		return maxf(delta - step, 0.0)
	position = next_position
	if position.y + 0.0001 < _landing_position.y:
		return maxf(delta - step, 0.0)
	position.y = _landing_position.y
	if _support_loss_fall:
		_support_loss_fall = false
		_settle()
		return maxf(delta - step, 0.0)
	if not _overlapping_landed_can().is_empty():
		_force_clear_settle()
		return maxf(delta - step, 0.0)
	if not _first_contact_occurred:
		_register_first_conveyor_contact(absf(_ricochet_velocity.y))
		_start_bounce(1)
	elif _bounce_number < 2:
		_start_bounce(_bounce_number + 1)
	else:
		_settle()
	return maxf(delta - step, 0.0)


func _step_supported_on_can(delta: float) -> float:
	var step := minf(delta, 1.0 / 120.0)
	_step_post_contact_lifetime(step)
	if _resolved:
		return 0.0
	_launch_age += step
	var support := _landed_can_data(_supported_can_id)
	if support.is_empty():
		var lost_id := _release_supported_can()
		var clear_x := _nearest_clear_conveyor_x(position.x)
		var clear_position := Vector2(clear_x, _landing_position.y)
		if not _overlapping_landed_can(clear_position).is_empty():
			support_lost.emit(self, lost_id, "EXPIRED_NO_CLEAR_FALL")
			_resolve(false, "EXPIRED_NO_CLEAR_FALL")
			return 0.0
		position.x = clear_x
		_ricochet_velocity = Vector2(-scroll_speed, 0.0)
		_motion_state = MotionState.RICOCHETING
		_support_loss_fall = true
		support_lost.emit(self, lost_id, "FALL_TO_CONVEYOR")
		return maxf(delta - step, 0.0)
	var center := support.get("center", position) as Vector2
	var size := support.get("size", Vector2.ZERO) as Vector2
	position = Vector2(
		center.x + _supported_can_offset_x,
		center.y - size.y * 0.5 - world_physics_size.y * 0.5
	)
	var overlap := _overlapping_landed_can()
	if not overlap.is_empty() and int(overlap.get("id", -1)) != _supported_can_id:
		var corrected_x := _nearest_clear_conveyor_x(position.x)
		position.x = corrected_x
		world_overlap_corrected.emit(self, "SUPPORTED_SIBLING_DEPENETRATION")
	return maxf(delta - step, 0.0)


func _landed_can_data(can_id: int) -> Dictionary:
	if can_id < 0 or not _landed_can_query.is_valid():
		return {}
	for can_data in _landed_can_query.call():
		if int(can_data.get("id", -1)) == can_id:
			return can_data
	return {}


func _step_post_contact_lifetime(delta: float) -> void:
	if not _first_contact_occurred:
		return
	time_remaining = maxf(time_remaining - delta, 0.0)
	if time_remaining <= 0.0:
		_resolve(false, "EXPIRED")


func _projected_x_after(seconds: float) -> float:
	var future := maxf(seconds, 0.0)
	if _ballistic_enabled and _motion_state == MotionState.PENDING_LAUNCH:
		if future <= _launch_delay_remaining:
			return position.x
		future -= _launch_delay_remaining
		var airborne_time := minf(future, _flight_duration)
		var projected_pending := _launch_position.x + _launch_velocity.x * airborne_time
		if future > _flight_duration:
			projected_pending -= scroll_speed * (future - _flight_duration)
		return projected_pending
	if not _ballistic_enabled or _motion_state in [
		MotionState.CONVEYOR,
		MotionState.SETTLED,
		MotionState.BOUNCING,
		MotionState.SUPPORTED_ON_CAN,
	]:
		return position.x - scroll_speed * future
	if _motion_state == MotionState.RICOCHETING:
		return position.x + _ricochet_velocity.x * future
	var remaining_flight := maxf(_flight_duration - _flight_elapsed, 0.0)
	var airborne_time := minf(future, remaining_flight)
	var projected := position.x + _launch_velocity.x * airborne_time
	if future > remaining_flight:
		projected -= scroll_speed * (future - remaining_flight)
	return projected


func _resolve(was_collected: bool, reason: String = "") -> void:
	if _resolved:
		return
	if was_collected:
		_collection_phase = _telemetry_motion_phase()
		_collection_time_from_launch = _launch_age
		_resolution_reason = "COLLECTED"
	else:
		_resolution_reason = "EXPIRED" if reason.is_empty() else reason
	_release_supported_can()
	_resolved = true
	set_deferred("monitoring", false)
	set_physics_process(false)
	_cancel_expiry_warning()
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


func _telemetry_motion_phase() -> String:
	match _motion_state:
		MotionState.AIRBORNE:
			return "AIRBORNE"
		MotionState.BOUNCING, MotionState.RICOCHETING:
			return "BOUNCING"
		MotionState.SUPPORTED_ON_CAN:
			return "SUPPORTED_ON_CAN"
		MotionState.SETTLED:
			return "SETTLED"
	return "AIRBORNE"


func _check_left_exit() -> void:
	if (
		_resolved
		or not is_finite(_left_exit_x)
		or _motion_state == MotionState.PENDING_LAUNCH
	):
		return
	if position.x + world_physics_size.x * 0.5 < _left_exit_x:
		_resolve(false, "EXITED_LEFT")


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
