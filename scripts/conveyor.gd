class_name ConveyorPrototype
extends Node2D

signal telegraph_started(lane_index: int, duration: float)
signal product_dropped(lane_index: int, fall_speed: float)
signal conveyor_product_landed(product: ConveyorProduct)
signal conveyor_product_cleared(product: ConveyorProduct)
signal pattern_started(pattern_type: int, started_at: float)
signal pattern_selected(pattern_type: int, selected_at: float)
signal pattern_event_triggered(pattern_type: int, event_type: int, offset: float)
signal sweeper_entry_cue_started(altitude: float, duration: float)
signal sweeper_spawned(sweeper: AirSweeper)
signal sweeper_reached_player_region(
	pattern_type: int,
	reached_at: float,
	player_region_x: float
)
signal compound_decision_reached(pattern_type: int, reached_at: float)
signal right_pressure_reserved(target_x: float, reserved_at: float)
signal right_pressure_launched(target_x: float, launched_at: float)
signal player_died

enum PatternType {
	CAN_ONLY,
	SWEEPER_ONLY,
	SWEEPER_THEN_CAN,
	CAN_THEN_SWEEPER,
	RIGHT_EDGE_PRESSURE,
}

enum PatternEventType {
	CAN,
	SWEEPER,
}

const BUILD_ID := "VM-0.3.4-B"
const CONVEYOR_PRODUCT_SCENE := preload(
	"res://scenes/hazards/conveyor_product.tscn"
)
const AIR_SWEEPER_SCENE := preload("res://scenes/hazards/air_sweeper.tscn")
const DEFAULT_PLAYER_COLLISION_SIZE := Vector2(32.0, 48.0)

@export_category("Conveyor")
@export var conveyor_speed: float = 140.0
@export var belt_left_x: float = 160.0
@export var belt_right_x: float = 1056.0
@export var offscreen_cleanup_x: float = 96.0
@export var conveyor_support_left_x: float = 160.0

@export_category("Player Control Band")
@export var control_band_left: float = 280.0
@export var control_band_right: float = 760.0
@export var left_failure_enabled: bool = true

@export_category("Single Drop Layout")
@export var drop_lane_positions := PackedFloat32Array([880.0, 952.0, 1020.0])
@export var drop_lane_sequence := PackedInt32Array([0, 1, 2, 1])
@export var maximum_concurrent_falling_cans: int = 1
@export var product_spawn_y: float = 176.0
@export var floor_y: float = 584.0
@export var product_size: Vector2 = Vector2(72.0, 72.0)
@export var landed_product_size: Vector2 = Vector2(72.0, 48.0)

@export_category("Timing")
@export var initial_warning_delay: float = 1.00
@export var telegraph_duration: float = 0.45
@export var target_fall_duration: float = 0.55
@export var landed_lifetime: float = 30.0
@export var despawn_warning_duration: float = 0.35

@export_category("Air Sweeper")
@export var sweeper_spawn_x: float = -48.0
@export var sweeper_exit_x: float = 800.0
@export var grounded_sweeper_clearance: float = 4.0
var sweeper_altitude: float = 518.0
@export var sweeper_speed: float = 520.0
@export var sweeper_size: Vector2 = Vector2(96.0, 28.0)
@export var sweeper_entry_cue_duration: float = 0.20
@export var maximum_active_sweepers: int = 1

@export_category("Player-Relevant Encounters")
@export var first_relevant_sweeper_target_min: float = 3.0
@export var first_relevant_sweeper_target_max: float = 4.0
@export var first_compound_decision_target_min: float = 5.0
@export var first_compound_decision_target_max: float = 7.0
@export var maximum_relevant_sweeper_gap: float = 3.0
@export var teaching_followup_cooldown: float = 0.95

@export_category("Right-Edge Pressure")
@export var right_edge_zone_width: float = 72.0
@export var right_edge_dwell_threshold: float = 1.0
@export var right_pressure_minimum_margin: float = 0.30
@export var right_pressure_jump_intercept_time: float = 0.10

@export_category("Intensity Director Phases")
@export var teaching_phase_end: float = 5.0
@export var conflict_phase_end: float = 12.0
@export var dominant_phase_end: float = 20.0
@export var second_compound_template_deadline: float = 9.0
@export var phase_two_pattern_weights := PackedInt32Array([20, 20, 30, 30])
@export var phase_three_pattern_weights := PackedInt32Array([10, 10, 40, 40])
@export var phase_four_pattern_weights := PackedInt32Array([0, 0, 50, 50])
@export var maximum_sweeper_gap_phase_two: float = 4.0
@export var maximum_sweeper_gap_phase_three: float = 3.5
@export var maximum_sweeper_gap_phase_four: float = 3.0
@export var director_seed: int = 3303

@export_category("Pattern Cooldown")
@export var teaching_cooldown_start: float = 2.20
@export var teaching_cooldown_end: float = 1.60
@export var conflict_cooldown_end: float = 0.90
@export var dominant_cooldown_end: float = 0.70
@export var minimum_pattern_cooldown: float = 0.50
@export var cooldown_floor_time: float = 40.0
@export var pattern_retry_delay: float = 0.10

@export_category("Compound Safe Window")
@export var early_compound_margin: float = 1.10
@export var medium_compound_margin: float = 0.825
@export var later_compound_margin: float = 0.60
@export var minimum_compound_margin: float = 0.50
@export var margin_floor_time: float = 40.0

@export_category("Modest Hazard Speed Ramp")
@export var speed_ramp_start: float = 15.0
@export var speed_ramp_end: float = 40.0
@export var maximum_hazard_speed_multiplier: float = 1.12

var survival_time: float = 0.0
var is_dead: bool = false
var is_round_complete: bool = false
var external_timer_display_enabled: bool = false

var _pattern_cooldown_remaining: float = 0.0
var _telegraph_remaining: float = 0.0
var _pending_lane_index: int = -1
var _pending_drop_x: float = NAN
var _pending_drop_pattern_type: int = -1
var _pending_fall_duration: float = 0.55
var _sequence_cursor: int = 0
var _falling_products: Array[ConveyorProduct] = []
var _landed_products: Array[ConveyorProduct] = []
var _chute_product: ConveyorProduct = null
var _active_sweepers: Array[AirSweeper] = []
var _reserved_pattern_type: int = -1
var _active_pattern_type: int = -1
var _active_pattern_elapsed: float = 0.0
var _active_pattern_started_at: float = 0.0
var _active_pattern_events: Array[Dictionary] = []
var _sweeper_spawn_pending: bool = false
var _sweeper_cue_remaining: float = 0.0
var _pending_sweeper_speed: float = 520.0
var _pending_sweeper_pattern_type: int = -1
var _sweeper_contexts: Dictionary = {}
var _encounter_log: Array[Dictionary] = []
var _first_relevant_sweeper_time: float = -1.0
var _first_compound_decision_time: float = -1.0
var _last_relevant_sweeper_time: float = -1.0
var _director_rng_state: int = 3303
var _last_pattern_type: int = -1
var _last_compound_pattern_type: int = -1
var _last_sweeper_pattern_time: float = -INF
var _first_compound_pattern_time: float = -1.0
var _teaching_can_presented: bool = false
var _teaching_sweeper_presented: bool = false
var _sweeper_then_can_presented: bool = false
var _can_then_sweeper_presented: bool = false
var _consecutive_simple_patterns: int = 0
var _consecutive_compound_patterns: int = 0
var _right_edge_dwell_time: float = 0.0
var _right_pressure_requested: bool = false
var _right_pressure_target_x: float = NAN
var _right_pressure_reserved_at: float = -1.0

@onready var player: SharedPlayerController = $Player
@onready var _hazard_container: Node2D = $Hazards
@onready var _belt_floor: AnimatableBody2D = $ConveyorBelt/Floor
@onready var _belt_stripes: Node2D = $ConveyorBelt/Stripes
@onready var _source_carriage: Node2D = $SourceRack/SourceCarriage
@onready var _source_head: Polygon2D = $SourceRack/SourceCarriage/Head
@onready var _warning_column: Polygon2D = (
	$SourceRack/SourceCarriage/WarningColumn
)
@onready var _warning_text: Label = $SourceRack/SourceCarriage/WarningText
@onready var _sweeper_entry: Node2D = $SweeperEntry
@onready var _sweeper_entry_cue: Polygon2D = $SweeperEntry/ActivationCue
@onready var _timer_label: Label = $HUD/Timer
@onready var _death_label: Label = $HUD/DeathMessage
@onready var _build_label: Label = $HUD/BuildId


func _ready() -> void:
	_refresh_sweeper_geometry()
	_pattern_cooldown_remaining = initial_warning_delay
	_pending_fall_duration = target_fall_duration_at(0.0)
	_pending_sweeper_speed = sweeper_speed_at(0.0)
	_director_rng_state = director_seed
	_apply_conveyor_support_velocity()
	_build_label.text = "BUILD %s" % BUILD_ID
	_update_timer_label()
	_update_source_visuals()
	_sweeper_entry_cue.visible = false


func _physics_process(delta: float) -> void:
	if is_dead or is_round_complete:
		return

	survival_time += delta
	_update_timer_label()
	_scroll_belt_presentation(delta)
	_enforce_control_band()
	if is_dead:
		return
	_update_right_edge_dwell(delta)
	_update_sweeper_encounters()

	_update_sweeper_entry_cue(delta)
	if _has_pending_drop():
		_telegraph_remaining = maxf(_telegraph_remaining - delta, 0.0)
		if _telegraph_remaining <= 0.0:
			_drop_pending_product()

	if _active_pattern_type >= 0:
		_update_active_pattern(delta)

	_pattern_cooldown_remaining = maxf(
		_pattern_cooldown_remaining - delta,
		0.0
	)
	if (
		_active_pattern_type < 0
		and _pattern_cooldown_remaining <= 0.0
	):
		_try_start_reserved_pattern()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func fall_distance() -> float:
	return maxf(
		floor_y - product_size.y * 0.5 - product_spawn_y,
		0.0
	)


func fall_speed() -> float:
	return fall_speed_at(survival_time)


func fall_speed_at(time_seconds: float) -> float:
	var duration := target_fall_duration_at(time_seconds)
	if duration <= 0.0:
		return INF
	return fall_distance() / duration


func director_phase_at(time_seconds: float) -> int:
	if time_seconds < teaching_phase_end:
		return 0
	if time_seconds < conflict_phase_end:
		return 1
	if time_seconds < dominant_phase_end:
		return 2
	return 3


func pattern_weights_at(time_seconds: float) -> PackedInt32Array:
	match director_phase_at(time_seconds):
		1:
			return phase_two_pattern_weights
		2:
			return phase_three_pattern_weights
		3:
			return phase_four_pattern_weights
	return PackedInt32Array([50, 50, 0, 0])


func pattern_cooldown_at(time_seconds: float) -> float:
	if time_seconds <= teaching_phase_end:
		return _interpolate_between(
			time_seconds,
			0.0,
			teaching_phase_end,
			teaching_cooldown_start,
			teaching_cooldown_end
		)
	if time_seconds <= conflict_phase_end:
		return _interpolate_between(
			time_seconds,
			teaching_phase_end,
			conflict_phase_end,
			teaching_cooldown_end,
			conflict_cooldown_end
		)
	if time_seconds <= dominant_phase_end:
		return _interpolate_between(
			time_seconds,
			conflict_phase_end,
			dominant_phase_end,
			conflict_cooldown_end,
			dominant_cooldown_end
		)
	return _interpolate_between(
		time_seconds,
		dominant_phase_end,
		cooldown_floor_time,
		dominant_cooldown_end,
		minimum_pattern_cooldown
	)


func compound_margin_at(time_seconds: float) -> float:
	if time_seconds <= teaching_phase_end:
		return early_compound_margin
	if time_seconds <= conflict_phase_end:
		return _interpolate_between(
			time_seconds,
			teaching_phase_end,
			conflict_phase_end,
			early_compound_margin,
			medium_compound_margin
		)
	if time_seconds <= dominant_phase_end:
		return _interpolate_between(
			time_seconds,
			conflict_phase_end,
			dominant_phase_end,
			medium_compound_margin,
			later_compound_margin
		)
	return _interpolate_between(
		time_seconds,
		dominant_phase_end,
		margin_floor_time,
		later_compound_margin,
		minimum_compound_margin
	)


func hazard_speed_multiplier_at(time_seconds: float) -> float:
	return _interpolate_between(
		time_seconds,
		speed_ramp_start,
		speed_ramp_end,
		1.0,
		maximum_hazard_speed_multiplier
	)


func sweeper_speed_at(time_seconds: float) -> float:
	return sweeper_speed * hazard_speed_multiplier_at(time_seconds)


func target_fall_duration_at(time_seconds: float) -> float:
	var multiplier := hazard_speed_multiplier_at(time_seconds)
	if multiplier <= 0.0:
		return INF
	return target_fall_duration / multiplier


func maximum_sweeper_gap_at(time_seconds: float) -> float:
	match director_phase_at(time_seconds):
		1:
			return maximum_sweeper_gap_phase_two
		2:
			return maximum_sweeper_gap_phase_three
		3:
			return maximum_sweeper_gap_phase_four
	return INF


func _interpolate_between(
	time_seconds: float,
	start_time: float,
	end_time: float,
	start_value: float,
	end_value: float
) -> float:
	if end_time <= start_time:
		return end_value
	var weight := clampf(
		(time_seconds - start_time) / (end_time - start_time),
		0.0,
		1.0
	)
	return lerpf(start_value, end_value, weight)


func conveyor_support_velocity() -> Vector2:
	return Vector2(-conveyor_speed, 0.0)


func belt_support_velocity() -> Vector2:
	return _belt_floor.constant_linear_velocity


func maximum_relative_player_speed() -> float:
	return player.maximum_speed


func net_no_input_world_speed() -> float:
	return -conveyor_speed


func net_left_input_world_speed() -> float:
	return -conveyor_speed - player.maximum_speed


func net_right_input_world_speed() -> float:
	return -conveyor_speed + player.maximum_speed


func can_recover_rightward() -> bool:
	return net_right_input_world_speed() > 0.0


func first_warning_time_estimate() -> float:
	return initial_warning_delay


func first_impact_time_estimate() -> float:
	return (
		initial_warning_delay
		+ telegraph_duration
		+ target_fall_duration_at(initial_warning_delay)
	)


func passive_failure_time_estimate(start_x: float = NAN) -> float:
	if conveyor_speed <= 0.0:
		return INF
	var player_start_x := player.position.x if is_nan(start_x) else start_x
	var last_supported_center_x := (
		conveyor_support_left_x + player_collision_size().x * 0.5
	)
	return (
		maxf(player_start_x - last_supported_center_x, 0.0)
		/ conveyor_speed
	)


func player_collision_size() -> Vector2:
	var player_node := player
	if player_node == null:
		player_node = get_node_or_null("Player") as SharedPlayerController
	if player_node == null:
		return DEFAULT_PLAYER_COLLISION_SIZE
	var collision_shape := (
		player_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	)
	if collision_shape == null:
		return DEFAULT_PLAYER_COLLISION_SIZE
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return DEFAULT_PLAYER_COLLISION_SIZE
	return rectangle.size


func derived_sweeper_altitude() -> float:
	var grounded_top := floor_y - player_collision_size().y
	return (
		grounded_top
		- maxf(grounded_sweeper_clearance, 0.0)
		- sweeper_size.y * 0.5
	)


func _refresh_sweeper_geometry() -> void:
	sweeper_altitude = derived_sweeper_altitude()
	if is_node_ready():
		_sweeper_entry.position.y = sweeper_altitude


func sweeper_collision_band() -> Vector2:
	return Vector2(
		sweeper_altitude - sweeper_size.y * 0.5,
		sweeper_altitude + sweeper_size.y * 0.5
	)


func grounded_player_band_on_belt() -> Vector2:
	return Vector2(
		floor_y - player_collision_size().y,
		floor_y
	)


func grounded_player_band_on_can() -> Vector2:
	var can_top := floor_y - landed_product_size.y
	return Vector2(
		can_top - player_collision_size().y,
		can_top
	)


func jump_apex_player_band() -> Vector2:
	var apex_center_y := (
		floor_y
		- player_collision_size().y * 0.5
		- calculated_jump_height()
	)
	return Vector2(
		apex_center_y - player_collision_size().y * 0.5,
		apex_center_y + player_collision_size().y * 0.5
	)


func sweeper_clears_grounded_player() -> bool:
	return (
		sweeper_collision_band().y < grounded_player_band_on_belt().x
	)


func grounded_sweeper_clearance_actual() -> float:
	return grounded_player_band_on_belt().x - sweeper_collision_band().y


func sweeper_overlaps_player_on_can() -> bool:
	return _bands_overlap(
		sweeper_collision_band(),
		grounded_player_band_on_can()
	)


func sweeper_intersects_jump_arc() -> bool:
	var jump_band := Vector2(
		jump_apex_player_band().x,
		grounded_player_band_on_belt().x
	)
	return (
		sweeper_collision_band().y >= jump_band.x
		and sweeper_collision_band().x <= jump_band.y
	)


func normal_jump_sweeper_overlap_intervals() -> Array[Vector2]:
	var intervals: Array[Vector2] = []
	if player.gravity <= 0.0 or player.jump_velocity >= 0.0:
		return intervals
	var half_player_height := player_collision_size().y * 0.5
	var start_center_y := floor_y - half_player_height
	var center_min_y := sweeper_collision_band().x - half_player_height
	var center_max_y := sweeper_collision_band().y + half_player_height
	var total_duration := normal_jump_duration()
	var ascent_start := _first_jump_time_at_center_y(
		start_center_y,
		center_max_y
	)
	var ascent_end := _first_jump_time_at_center_y(
		start_center_y,
		center_min_y
	)
	var descent_start := total_duration - ascent_end
	var descent_end := total_duration - ascent_start
	if ascent_end > ascent_start:
		intervals.append(Vector2(ascent_start, ascent_end))
	if descent_end > descent_start:
		intervals.append(Vector2(descent_start, descent_end))
	return intervals


func normal_jump_sweeper_overlap_duration() -> float:
	var duration := 0.0
	for interval in normal_jump_sweeper_overlap_intervals():
		duration += maxf(interval.y - interval.x, 0.0)
	return duration


func jump_time_overlaps_sweeper(time_after_takeoff: float) -> bool:
	for interval in normal_jump_sweeper_overlap_intervals():
		if (
			time_after_takeoff + 0.0001 >= interval.x
			and time_after_takeoff <= interval.y + 0.0001
		):
			return true
	return false


func _first_jump_time_at_center_y(
	start_center_y: float,
	target_center_y: float
) -> float:
	var displacement_up := start_center_y - target_center_y
	var launch_speed := absf(player.jump_velocity)
	var discriminant := (
		launch_speed * launch_speed
		- 2.0 * player.gravity * displacement_up
	)
	if discriminant < 0.0:
		return normal_jump_duration() * 0.5
	return (launch_speed - sqrt(discriminant)) / player.gravity


func _bands_overlap(first: Vector2, second: Vector2) -> bool:
	return first.x < second.y and first.y > second.x


func sweeper_center_arrival_time(time_seconds: float = NAN) -> float:
	var evaluation_time := (
		survival_time if is_nan(time_seconds) else time_seconds
	)
	var evaluated_speed := sweeper_speed_at(evaluation_time)
	if evaluated_speed <= 0.0:
		return INF
	return (576.0 - sweeper_spawn_x) / evaluated_speed


func sweeper_player_region_arrival_delay(
	target_player_x: float,
	time_seconds: float = NAN
) -> float:
	var evaluation_time := (
		survival_time if is_nan(time_seconds) else time_seconds
	)
	var evaluated_speed := sweeper_speed_at(evaluation_time)
	if evaluated_speed <= 0.0:
		return INF
	var player_left := target_player_x - player_collision_size().x * 0.5
	var required_sweeper_center := player_left - sweeper_size.x * 0.5
	return (
		sweeper_entry_cue_duration
		+ maxf(required_sweeper_center - sweeper_spawn_x, 0.0)
			/ evaluated_speed
	)


func predicted_relevant_sweeper_time(
	pattern_type: int,
	start_time: float,
	target_player_x: float
) -> float:
	var event_offset := (
		compound_offset_for_pattern(pattern_type, start_time)
		if pattern_type == PatternType.CAN_THEN_SWEEPER
		else 0.0
	)
	return (
		start_time
		+ event_offset
		+ sweeper_player_region_arrival_delay(
			target_player_x,
			start_time + event_offset
		)
	)


func _would_exceed_relevant_sweeper_gap(
	pattern_type: int,
	start_time: float
) -> bool:
	if (
		_last_relevant_sweeper_time < 0.0
		or not _pattern_has_sweeper(pattern_type)
	):
		return false
	return (
		predicted_relevant_sweeper_time(
			pattern_type,
			start_time,
			player.position.x
		)
		- _last_relevant_sweeper_time
		> maximum_relevant_sweeper_gap
	)


func normal_jump_duration() -> float:
	if player.gravity <= 0.0:
		return INF
	return 2.0 * absf(player.jump_velocity) / player.gravity


func earliest_can_contact_delay_from_event(
	time_seconds: float = NAN
) -> float:
	if drop_lane_positions.is_empty() or conveyor_speed <= 0.0:
		return INF
	var evaluation_time := (
		survival_time if is_nan(time_seconds) else time_seconds
	)
	var earliest_lane_x := drop_lane_positions[0]
	for lane_x in drop_lane_positions:
		earliest_lane_x = minf(earliest_lane_x, lane_x)
	var contact_center_x := (
		control_band_right
		+ player_collision_size().x * 0.5
		+ landed_product_size.x * 0.5
	)
	var conveyor_travel_time := (
		maxf(earliest_lane_x - contact_center_x, 0.0)
		/ conveyor_speed
	)
	return (
		telegraph_duration
		+ target_fall_duration_at(evaluation_time)
		+ conveyor_travel_time
	)


func compound_offset_for_pattern(
	pattern_type: int,
	start_time: float
) -> float:
	var target_margin := compound_margin_at(start_time)
	var offset := 0.0
	for _iteration in range(4):
		match pattern_type:
			PatternType.SWEEPER_THEN_CAN:
				var sweeper_center_time := (
					sweeper_entry_cue_duration
					+ sweeper_center_arrival_time(start_time)
				)
				offset = maxf(
					target_margin
						+ sweeper_center_time
						- earliest_can_contact_delay_from_event(
							start_time + offset
						),
					0.0
				)
			PatternType.CAN_THEN_SWEEPER:
				offset = maxf(
					target_margin
						+ earliest_can_contact_delay_from_event(start_time)
						+ normal_jump_duration()
						- sweeper_entry_cue_duration
						- sweeper_center_arrival_time(
							start_time + offset
						),
					0.0
				)
			_:
				return 0.0
	return offset


func compound_response_margin_for_pattern(
	pattern_type: int,
	start_time: float
) -> float:
	var offset := compound_offset_for_pattern(pattern_type, start_time)
	match pattern_type:
		PatternType.SWEEPER_THEN_CAN:
			return (
				offset
				+ earliest_can_contact_delay_from_event(start_time + offset)
				- sweeper_entry_cue_duration
				- sweeper_center_arrival_time(start_time)
			)
		PatternType.CAN_THEN_SWEEPER:
			return (
				offset
				+ sweeper_entry_cue_duration
				+ sweeper_center_arrival_time(start_time + offset)
				- earliest_can_contact_delay_from_event(start_time)
				- normal_jump_duration()
			)
	return INF


func right_edge_zone_left() -> float:
	return control_band_right - maxf(right_edge_zone_width, 0.0)


func is_player_in_right_edge_zone() -> bool:
	return (
		player.position.x >= right_edge_zone_left()
		and player.position.x <= control_band_right + 0.01
	)


func right_pressure_can_warning_offset(
	start_time: float,
	target_x: float
) -> float:
	return maxf(
		sweeper_player_region_arrival_delay(target_x, start_time)
			- right_pressure_jump_intercept_time,
		0.0
	)


func right_pressure_response_metrics(
	start_time: float,
	target_x: float
) -> Dictionary:
	var speed := sweeper_speed_at(start_time)
	var warning_offset := right_pressure_can_warning_offset(
		start_time,
		target_x
	)
	var sweeper_arrival := sweeper_player_region_arrival_delay(
		target_x,
		start_time
	)
	var horizontal_overlap_duration := (
		(sweeper_size.x + player_collision_size().x) / speed
		if speed > 0.0
		else INF
	)
	var sweeper_clear_time := sweeper_arrival + horizontal_overlap_duration
	var fall_duration := target_fall_duration_at(
		start_time + warning_offset
	)
	var can_impact_time := (
		warning_offset + telegraph_duration + fall_duration
	)
	var required_escape_distance := (
		product_size.x * 0.5
		+ player_collision_size().x * 0.5
		+ grounded_sweeper_clearance
	)
	var escape_x := target_x - required_escape_distance
	var left_world_speed := absf(net_left_input_world_speed())
	var escape_move_time := (
		required_escape_distance / left_world_speed
		if left_world_speed > 0.0
		else INF
	)
	var delayed_ground_response_margin := (
		can_impact_time - sweeper_clear_time - escape_move_time
	)
	return {
		"target_x": target_x,
		"warning_offset": warning_offset,
		"sweeper_arrival": sweeper_arrival,
		"sweeper_clear": sweeper_clear_time,
		"can_impact": can_impact_time,
		"escape_x": escape_x,
		"escape_move_time": escape_move_time,
		"delayed_ground_response_margin": delayed_ground_response_margin,
		"blind_jump_intercept": (
			sweeper_arrival - warning_offset
		),
	}


func right_pressure_pattern_is_solvable(
	start_time: float,
	target_x: float
) -> bool:
	if is_nan(target_x):
		return false
	var half_product_width := product_size.x * 0.5
	if (
		target_x - half_product_width < belt_left_x
		or target_x + half_product_width > belt_right_x
	):
		return false
	var metrics := right_pressure_response_metrics(start_time, target_x)
	var last_supported_center := (
		conveyor_support_left_x + player_collision_size().x * 0.5
	)
	if metrics.escape_x < last_supported_center:
		return false
	if (
		not sweeper_clears_grounded_player()
		or not sweeper_overlaps_player_on_can()
		or not jump_time_overlaps_sweeper(metrics.blind_jump_intercept)
		or metrics.delayed_ground_response_margin
			+ 0.0001 < right_pressure_minimum_margin
	):
		return false
	if _right_pressure_landing_overlaps_existing_can(
		target_x,
		metrics.can_impact
	):
		return false
	return not _right_pressure_escape_corridor_is_blocked(
		metrics.escape_x,
		target_x,
		metrics.sweeper_clear
	)


func _right_pressure_landing_overlaps_existing_can(
	target_x: float,
	time_until_impact: float
) -> bool:
	var required_spacing := (
		product_size.x * 0.5 + landed_product_size.x * 0.5
	)
	for product in _landed_products:
		if not is_instance_valid(product):
			continue
		var predicted_x := (
			product.conveyor_center_x()
			- conveyor_speed * maxf(time_until_impact, 0.0)
		)
		if absf(predicted_x - target_x) < required_spacing:
			return true
	return false


func _right_pressure_escape_corridor_is_blocked(
	escape_x: float,
	target_x: float,
	prediction_time: float
) -> bool:
	var corridor_left := minf(escape_x, target_x)
	var corridor_right := maxf(escape_x, target_x)
	var half_spacing := (
		landed_product_size.x * 0.5
		+ player_collision_size().x * 0.5
	)
	for product in _landed_products:
		if not is_instance_valid(product):
			continue
		var predicted_x := (
			product.conveyor_center_x()
			- conveyor_speed * maxf(prediction_time, 0.0)
		)
		if (
			predicted_x + half_spacing > corridor_left
			and predicted_x - half_spacing < corridor_right
		):
			return true
	return false


func pattern_is_solvable(
	pattern_type: int,
	start_time: float = NAN
) -> bool:
	var evaluation_time := (
		survival_time if is_nan(start_time) else start_time
	)
	if pattern_type == PatternType.CAN_ONLY:
		return landed_can_is_jump_clearable()
	if pattern_type == PatternType.RIGHT_EDGE_PRESSURE:
		return right_pressure_pattern_is_solvable(
			evaluation_time,
			_right_pressure_target_x
		)
	if (
		not sweeper_clears_grounded_player()
		or not sweeper_overlaps_player_on_can()
		or not sweeper_intersects_jump_arc()
	):
		return false
	match pattern_type:
		PatternType.SWEEPER_ONLY:
			var visible_arrival_time := sweeper_center_arrival_time(
				evaluation_time
			)
			return (
				visible_arrival_time >= 0.8
				and visible_arrival_time <= 1.2
			)
		PatternType.SWEEPER_THEN_CAN:
			return (
				compound_response_margin_for_pattern(
					pattern_type,
					evaluation_time
				)
				+ 0.0001
				>= compound_margin_at(evaluation_time)
			)
		PatternType.CAN_THEN_SWEEPER:
			return (
				compound_response_margin_for_pattern(
					pattern_type,
					evaluation_time
				)
				+ 0.0001
				>= compound_margin_at(evaluation_time)
			)
	return false


func active_sweeper_count() -> int:
	return _active_sweepers.size()


func active_sweepers() -> Array[AirSweeper]:
	return _active_sweepers.duplicate()


func sweeper_cue_is_visible() -> bool:
	return _sweeper_entry_cue.visible


func sweeper_cue_altitude() -> float:
	return _sweeper_entry.position.y


func active_pattern_type() -> int:
	return _active_pattern_type


func reserved_pattern_type() -> int:
	return _reserved_pattern_type


func has_pending_pattern_events() -> bool:
	return not _active_pattern_events.is_empty() or _sweeper_spawn_pending


func first_compound_pattern_time() -> float:
	return _first_compound_pattern_time


func first_relevant_sweeper_time() -> float:
	return _first_relevant_sweeper_time


func first_compound_decision_time() -> float:
	return _first_compound_decision_time


func last_relevant_sweeper_time() -> float:
	return _last_relevant_sweeper_time


func encounter_log() -> Array[Dictionary]:
	return _encounter_log.duplicate(true)


func right_edge_dwell_time() -> float:
	return _right_edge_dwell_time


func right_pressure_is_requested() -> bool:
	return _right_pressure_requested


func right_pressure_target_x() -> float:
	return _right_pressure_target_x


func last_pattern_type() -> int:
	return _last_pattern_type


func consecutive_simple_patterns() -> int:
	return _consecutive_simple_patterns


func consecutive_compound_patterns() -> int:
	return _consecutive_compound_patterns


func teaching_patterns_presented() -> bool:
	return _teaching_can_presented and _teaching_sweeper_presented


func both_compound_templates_presented() -> bool:
	return _sweeper_then_can_presented and _can_then_sweeper_presented


func director_distribution_sample(
	time_seconds: float,
	sample_count: int
) -> PackedInt32Array:
	var counts := PackedInt32Array([0, 0, 0, 0])
	var preview_state := director_seed
	var previous_pattern := -1
	var weights := pattern_weights_at(time_seconds)
	for _sample_index in range(maxi(sample_count, 0)):
		preview_state = _next_rng_state(preview_state)
		var pattern_type := _weighted_pattern_from_roll(
			weights,
			preview_state
		)
		if (
			pattern_type == PatternType.CAN_ONLY
			and previous_pattern == PatternType.CAN_ONLY
		):
			pattern_type = PatternType.SWEEPER_ONLY
		counts[pattern_type] += 1
		previous_pattern = pattern_type
	return counts


func force_pattern_for_test(pattern_type: int) -> bool:
	if (
		pattern_type < PatternType.CAN_ONLY
		or pattern_type > PatternType.RIGHT_EDGE_PRESSURE
	):
		return false
	if pattern_type == PatternType.RIGHT_EDGE_PRESSURE:
		_right_pressure_requested = true
		_right_pressure_target_x = clampf(
			player.position.x,
			right_edge_zone_left(),
			control_band_right
		)
	_reserved_pattern_type = pattern_type
	_record_pattern_selection(pattern_type, survival_time)
	_pattern_cooldown_remaining = 0.0
	return _try_start_reserved_pattern()


func current_warning_lane() -> int:
	return _pending_lane_index


func current_warning_x() -> float:
	return _pending_drop_x


func warning_is_visible() -> bool:
	return _has_pending_drop() and _warning_column.visible


func warning_is_aligned() -> bool:
	if not _has_pending_drop():
		return false
	return is_equal_approx(
		_source_carriage.position.x,
		_pending_drop_x
	)


func chute_is_visible() -> bool:
	return _source_carriage.visible


func chute_is_aligned_with_active_drop() -> bool:
	if not is_instance_valid(_chute_product):
		return false
	return is_equal_approx(
		_source_carriage.position.x,
		_chute_product.position.x
	)


func falling_product_count() -> int:
	return _falling_products.size()


func landed_product_count() -> int:
	return _landed_products.size()


func active_product_count() -> int:
	return falling_product_count() + landed_product_count()


func active_falling_products() -> Array[ConveyorProduct]:
	return _falling_products.duplicate()


func active_landed_products() -> Array[ConveyorProduct]:
	return _landed_products.duplicate()


func is_player_inside_control_band() -> bool:
	return (
		player.position.x >= control_band_left - 0.01
		and player.position.x <= control_band_right + 0.01
	)


func calculated_jump_height() -> float:
	if player.gravity <= 0.0:
		return INF
	return player.jump_velocity * player.jump_velocity / (2.0 * player.gravity)


func landed_can_is_jump_clearable() -> bool:
	return landed_product_size.y < calculated_jump_height()


func drop_lane_is_geometrically_valid(lane_index: int) -> bool:
	if lane_index < 0 or lane_index >= drop_lane_positions.size():
		return false
	var lane_x := drop_lane_positions[lane_index]
	return (
		lane_x - product_size.x * 0.5 >= belt_left_x
		and lane_x + product_size.x * 0.5 <= belt_right_x
		and lane_x - product_size.x * 0.5 > control_band_right
	)


func force_warning_for_test(lane_index: int) -> void:
	if lane_index < 0 or lane_index >= drop_lane_positions.size():
		return
	_pending_lane_index = lane_index
	_pending_drop_x = drop_lane_positions[lane_index]
	_pending_drop_pattern_type = PatternType.CAN_ONLY
	_telegraph_remaining = telegraph_duration
	_pending_fall_duration = target_fall_duration_at(survival_time)
	_show_warning()


func force_drop_for_test(lane_index: int) -> ConveyorProduct:
	if lane_index < 0 or lane_index >= drop_lane_positions.size():
		return null
	_pending_lane_index = lane_index
	_pending_drop_x = drop_lane_positions[lane_index]
	_pending_drop_pattern_type = PatternType.CAN_ONLY
	_telegraph_remaining = 0.0
	_pending_fall_duration = target_fall_duration_at(survival_time)
	return _drop_pending_product()


func _scroll_belt_presentation(delta: float) -> void:
	var belt_width := belt_right_x - belt_left_x
	if belt_width <= 0.0:
		return
	for stripe in _belt_stripes.get_children():
		if not stripe is Node2D:
			continue
		stripe.position.x -= conveyor_speed * delta
		while stripe.position.x < belt_left_x:
			stripe.position.x += belt_width


func _apply_conveyor_support_velocity() -> void:
	if not is_node_ready():
		return
	_belt_floor.constant_linear_velocity = conveyor_support_velocity()


func _enforce_control_band() -> void:
	var last_supported_center_x := (
		conveyor_support_left_x + player_collision_size().x * 0.5
	)
	if not left_failure_enabled and player.position.x < last_supported_center_x:
		player.position.x = last_supported_center_x
		player.velocity.x = 0.0
	if player.position.x > control_band_right:
		player.position.x = control_band_right
	if player.position.x >= control_band_right and player.velocity.x > 0.0:
		player.velocity.x = 0.0


func _update_right_edge_dwell(delta: float) -> void:
	if _right_pressure_requested:
		return
	if not is_player_in_right_edge_zone():
		_right_edge_dwell_time = 0.0
		return
	_right_edge_dwell_time += delta
	if _right_edge_dwell_time + 0.0001 < right_edge_dwell_threshold:
		return
	_right_pressure_requested = true
	_right_pressure_target_x = clampf(
		player.position.x,
		right_edge_zone_left(),
		control_band_right
	)
	_right_pressure_reserved_at = survival_time
	right_pressure_reserved.emit(
		_right_pressure_target_x,
		_right_pressure_reserved_at
	)


func _update_sweeper_encounters() -> void:
	for sweeper in _active_sweepers:
		if not is_instance_valid(sweeper):
			continue
		var instance_id := sweeper.get_instance_id()
		if not _sweeper_contexts.has(instance_id):
			continue
		var context: Dictionary = _sweeper_contexts[instance_id]
		if context.reached_player_region:
			continue
		var player_left := player.position.x - player_collision_size().x * 0.5
		var sweeper_right := (
			sweeper.position.x + sweeper.hazard_size.x * 0.5
		)
		if sweeper_right < player_left:
			continue
		context.reached_player_region = true
		context.reached_at = survival_time
		context.player_region_x = player.position.x
		_sweeper_contexts[instance_id] = context
		_record_encounter({
			"event": "sweeper_player_region",
			"pattern_type": context.pattern_type,
			"time": survival_time,
			"player_x": player.position.x,
			"spawned_at": context.spawned_at,
		})
		if _first_relevant_sweeper_time < 0.0:
			_first_relevant_sweeper_time = survival_time
		_last_relevant_sweeper_time = survival_time
		sweeper_reached_player_region.emit(
			context.pattern_type,
			survival_time,
			player.position.x
		)


func _record_pattern_selection(pattern_type: int, selected_at: float) -> void:
	_record_encounter({
		"event": "pattern_selection",
		"pattern_type": pattern_type,
		"time": selected_at,
	})
	pattern_selected.emit(pattern_type, selected_at)


func _record_compound_decision(pattern_type: int) -> void:
	if not _pattern_is_compound(pattern_type):
		return
	_record_encounter({
		"event": "compound_decision",
		"pattern_type": pattern_type,
		"time": survival_time,
		"player_x": player.position.x,
	})
	if _first_compound_decision_time < 0.0:
		_first_compound_decision_time = survival_time
	compound_decision_reached.emit(pattern_type, survival_time)


func _record_encounter(record: Dictionary) -> void:
	_encounter_log.append(record)


func _try_start_reserved_pattern() -> bool:
	if _reserved_pattern_type < 0:
		_reserved_pattern_type = _select_director_pattern(survival_time)
		if _reserved_pattern_type < 0:
			_pattern_cooldown_remaining = maxf(
				teaching_phase_end - survival_time,
				pattern_retry_delay
			)
			return false
		_record_pattern_selection(_reserved_pattern_type, survival_time)

	if not _pattern_can_start(_reserved_pattern_type):
		if _reserved_pattern_type == PatternType.RIGHT_EDGE_PRESSURE:
			_pattern_cooldown_remaining = pattern_retry_delay
			return false
		if _pattern_is_compound(_reserved_pattern_type):
			var reserved_template_is_required := (
				(
					_reserved_pattern_type
					== PatternType.SWEEPER_THEN_CAN
					and not _sweeper_then_can_presented
				)
				or (
					_reserved_pattern_type
					== PatternType.CAN_THEN_SWEEPER
					and not _can_then_sweeper_presented
				)
			)
			if reserved_template_is_required:
				_pattern_cooldown_remaining = pattern_retry_delay
				return false
			var alternative := _alternate_compound_pattern(
				_reserved_pattern_type
			)
			if (
				not _would_exceed_relevant_sweeper_gap(
					alternative,
					survival_time
				)
				and _pattern_can_start(alternative)
			):
				_reserved_pattern_type = alternative
			else:
				_pattern_cooldown_remaining = pattern_retry_delay
				return false
		else:
			_pattern_cooldown_remaining = pattern_retry_delay
			return false

	var committed_pattern := _reserved_pattern_type
	_active_pattern_type = committed_pattern
	_reserved_pattern_type = -1
	_active_pattern_elapsed = 0.0
	_active_pattern_started_at = survival_time
	_active_pattern_events = _events_for_pattern(
		committed_pattern,
		_active_pattern_started_at
	)
	_record_pattern_commit(committed_pattern, _active_pattern_started_at)
	if committed_pattern == PatternType.RIGHT_EDGE_PRESSURE:
		_right_pressure_requested = false
		_right_edge_dwell_time = 0.0
		right_pressure_launched.emit(
			_right_pressure_target_x,
			survival_time
		)
	pattern_started.emit(committed_pattern, survival_time)
	_trigger_due_pattern_events()
	return true


func _select_director_pattern(time_seconds: float) -> int:
	if not _teaching_can_presented:
		return PatternType.CAN_ONLY
	if not _teaching_sweeper_presented:
		return PatternType.SWEEPER_ONLY
	if time_seconds < teaching_phase_end:
		return -1
	if _right_pressure_requested:
		return PatternType.RIGHT_EDGE_PRESSURE
	if _first_compound_pattern_time < 0.0:
		return _preferred_compound_pattern()
	if (
		time_seconds >= second_compound_template_deadline
		and not both_compound_templates_presented()
	):
		var missing_pattern := _missing_compound_pattern()
		if _would_exceed_relevant_sweeper_gap(
			missing_pattern,
			time_seconds
		):
			return PatternType.SWEEPER_THEN_CAN
		return missing_pattern
	if (
		_last_relevant_sweeper_time >= 0.0
		and (
			time_seconds
			+ sweeper_player_region_arrival_delay(
				control_band_right,
				time_seconds
			)
			- _last_relevant_sweeper_time
		) >= maximum_relevant_sweeper_gap
	):
		return PatternType.SWEEPER_THEN_CAN

	_director_rng_state = _next_rng_state(_director_rng_state)
	var candidate := _weighted_pattern_from_roll(
		pattern_weights_at(time_seconds),
		_director_rng_state
	)
	if (
		candidate == PatternType.CAN_ONLY
		and _last_pattern_type == PatternType.CAN_ONLY
	):
		candidate = PatternType.SWEEPER_ONLY
	if not pattern_is_solvable(candidate, time_seconds):
		if _pattern_is_compound(candidate):
			var alternative := _alternate_compound_pattern(candidate)
			if pattern_is_solvable(alternative, time_seconds):
				return alternative
		return _preferred_compound_pattern()
	if _would_exceed_relevant_sweeper_gap(candidate, time_seconds):
		return PatternType.SWEEPER_THEN_CAN
	return candidate


func _next_rng_state(state: int) -> int:
	return (state * 1103515245 + 12345) & 0x7fffffff


func _weighted_pattern_from_roll(
	weights: PackedInt32Array,
	roll_source: int
) -> int:
	if weights.size() < 4:
		return PatternType.SWEEPER_ONLY
	var total_weight := 0
	for weight in weights:
		total_weight += maxi(weight, 0)
	if total_weight <= 0:
		return PatternType.SWEEPER_ONLY
	var roll := posmod(roll_source, total_weight)
	var cumulative := 0
	for pattern_type in range(4):
		cumulative += maxi(weights[pattern_type], 0)
		if roll < cumulative:
			return pattern_type
	return PatternType.CAN_THEN_SWEEPER


func _preferred_compound_pattern() -> int:
	if not _sweeper_then_can_presented:
		return PatternType.SWEEPER_THEN_CAN
	if not _can_then_sweeper_presented:
		return PatternType.CAN_THEN_SWEEPER
	return _alternate_compound_pattern(_last_compound_pattern_type)


func _missing_compound_pattern() -> int:
	if not _sweeper_then_can_presented:
		return PatternType.SWEEPER_THEN_CAN
	return PatternType.CAN_THEN_SWEEPER


func _alternate_compound_pattern(pattern_type: int) -> int:
	if pattern_type == PatternType.SWEEPER_THEN_CAN:
		return PatternType.CAN_THEN_SWEEPER
	return PatternType.SWEEPER_THEN_CAN


func _pattern_is_simple(pattern_type: int) -> bool:
	return (
		pattern_type == PatternType.CAN_ONLY
		or pattern_type == PatternType.SWEEPER_ONLY
	)


func _pattern_is_compound(pattern_type: int) -> bool:
	return (
		pattern_type == PatternType.SWEEPER_THEN_CAN
		or pattern_type == PatternType.CAN_THEN_SWEEPER
		or pattern_type == PatternType.RIGHT_EDGE_PRESSURE
	)


func _pattern_has_sweeper(pattern_type: int) -> bool:
	return pattern_type != PatternType.CAN_ONLY


func _record_pattern_commit(pattern_type: int, started_at: float) -> void:
	_last_pattern_type = pattern_type
	if _pattern_is_simple(pattern_type):
		_consecutive_simple_patterns += 1
		_consecutive_compound_patterns = 0
	else:
		_consecutive_compound_patterns += 1
		_consecutive_simple_patterns = 0
		_last_compound_pattern_type = pattern_type
		if _first_compound_pattern_time < 0.0:
			_first_compound_pattern_time = started_at
	if _pattern_has_sweeper(pattern_type):
		_last_sweeper_pattern_time = started_at
	match pattern_type:
		PatternType.CAN_ONLY:
			_teaching_can_presented = true
		PatternType.SWEEPER_ONLY:
			_teaching_sweeper_presented = true
		PatternType.SWEEPER_THEN_CAN:
			_sweeper_then_can_presented = true
		PatternType.CAN_THEN_SWEEPER:
			_can_then_sweeper_presented = true


func _pattern_can_start(pattern_type: int) -> bool:
	if not pattern_is_solvable(pattern_type, survival_time):
		return false
	var includes_can := (
		pattern_type == PatternType.CAN_ONLY
		or pattern_type == PatternType.SWEEPER_THEN_CAN
		or pattern_type == PatternType.CAN_THEN_SWEEPER
		or pattern_type == PatternType.RIGHT_EDGE_PRESSURE
	)
	var includes_sweeper := _pattern_has_sweeper(pattern_type)
	var sweeper_event_is_immediate := (
		pattern_type == PatternType.SWEEPER_ONLY
		or pattern_type == PatternType.SWEEPER_THEN_CAN
		or pattern_type == PatternType.RIGHT_EDGE_PRESSURE
	)
	if (
		includes_can
		and (
			_has_pending_drop()
			or _falling_products.size() >= maximum_concurrent_falling_cans
		)
	):
		return false
	if (
		includes_sweeper
		and sweeper_event_is_immediate
		and (
			_active_sweepers.size() >= maximum_active_sweepers
			or _sweeper_spawn_pending
		)
	):
		return false
	return true


func _events_for_pattern(
	pattern_type: int,
	pattern_start_time: float
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var compound_offset := compound_offset_for_pattern(
		pattern_type,
		pattern_start_time
	)
	match pattern_type:
		PatternType.CAN_ONLY:
			events.append(_pattern_event(
				PatternEventType.CAN,
				0.0,
				pattern_start_time
			))
		PatternType.SWEEPER_ONLY:
			events.append(_pattern_event(
				PatternEventType.SWEEPER,
				0.0,
				pattern_start_time
			))
		PatternType.SWEEPER_THEN_CAN:
			events.append(_pattern_event(
				PatternEventType.SWEEPER,
				0.0,
				pattern_start_time
			))
			events.append(_pattern_event(
				PatternEventType.CAN,
				compound_offset,
				pattern_start_time,
				true
			))
		PatternType.CAN_THEN_SWEEPER:
			events.append(_pattern_event(
				PatternEventType.CAN,
				0.0,
				pattern_start_time
			))
			events.append(_pattern_event(
				PatternEventType.SWEEPER,
				compound_offset,
				pattern_start_time,
				true
			))
		PatternType.RIGHT_EDGE_PRESSURE:
			events.append(_pattern_event(
				PatternEventType.SWEEPER,
				0.0,
				pattern_start_time
			))
			events.append(_pattern_event(
				PatternEventType.CAN,
				right_pressure_can_warning_offset(
					pattern_start_time,
					_right_pressure_target_x
				),
				pattern_start_time,
				true,
				_right_pressure_target_x
			))
	return events


func _pattern_event(
	event_type: int,
	offset: float,
	pattern_start_time: float,
	decision_event: bool = false,
	target_x: float = NAN
) -> Dictionary:
	var event_time := pattern_start_time + maxf(offset, 0.0)
	return {
		"event_type": event_type,
		"offset": maxf(offset, 0.0),
		"triggered": false,
		"decision_event": decision_event,
		"target_x": target_x,
		"fall_duration": target_fall_duration_at(event_time),
		"sweeper_speed": sweeper_speed_at(event_time),
	}


func _update_active_pattern(delta: float) -> void:
	_active_pattern_elapsed += delta
	_trigger_due_pattern_events()


func _trigger_due_pattern_events() -> void:
	for event in _active_pattern_events:
		if event.triggered or event.offset > _active_pattern_elapsed:
			continue
		var triggered := false
		if event.event_type == PatternEventType.CAN:
			triggered = (
				not _has_pending_drop()
				and _falling_products.size() < maximum_concurrent_falling_cans
				and _start_next_telegraph(
					event.fall_duration,
					event.target_x,
					_active_pattern_type
				)
			)
		elif event.event_type == PatternEventType.SWEEPER:
			triggered = _start_sweeper_entry_cue(
				event.sweeper_speed,
				_active_pattern_type
			)
		if not triggered:
			continue
		event.triggered = true
		if event.decision_event:
			_record_compound_decision(_active_pattern_type)
		pattern_event_triggered.emit(
			_active_pattern_type,
			event.event_type,
			event.offset
		)

	for event in _active_pattern_events:
		if not event.triggered:
			return
	_active_pattern_events.clear()
	_active_pattern_type = -1
	_active_pattern_elapsed = 0.0
	_active_pattern_started_at = 0.0
	_pattern_cooldown_remaining = _bounded_pattern_cooldown(
		pattern_cooldown_at(survival_time)
	)


func _bounded_pattern_cooldown(requested_cooldown: float) -> float:
	if _teaching_can_presented and not _teaching_sweeper_presented:
		return minf(requested_cooldown, teaching_followup_cooldown)
	if (
		survival_time < teaching_phase_end
		or _last_relevant_sweeper_time < 0.0
	):
		return requested_cooldown
	var next_arrival_delay := sweeper_player_region_arrival_delay(
		control_band_right,
		survival_time
	)
	var latest_start_delay := (
		_last_relevant_sweeper_time
		+ maximum_relevant_sweeper_gap
		- survival_time
		- next_arrival_delay
	)
	return minf(requested_cooldown, maxf(latest_start_delay, 0.0))


func _start_sweeper_entry_cue(
	event_sweeper_speed: float = NAN,
	pattern_type: int = -1
) -> bool:
	if (
		_sweeper_spawn_pending
		or _active_sweepers.size() >= maximum_active_sweepers
	):
		return false
	_sweeper_spawn_pending = true
	_sweeper_cue_remaining = sweeper_entry_cue_duration
	_pending_sweeper_speed = (
		sweeper_speed_at(survival_time)
		if is_nan(event_sweeper_speed)
		else event_sweeper_speed
	)
	_pending_sweeper_pattern_type = pattern_type
	_sweeper_entry.position.y = sweeper_altitude
	_sweeper_entry_cue.visible = true
	sweeper_entry_cue_started.emit(
		sweeper_altitude,
		sweeper_entry_cue_duration
	)
	if _sweeper_cue_remaining <= 0.0:
		_spawn_sweeper()
	return true


func _update_sweeper_entry_cue(delta: float) -> void:
	if not _sweeper_spawn_pending:
		return
	_sweeper_cue_remaining = maxf(_sweeper_cue_remaining - delta, 0.0)
	if _sweeper_cue_remaining <= 0.0:
		_spawn_sweeper()


func _spawn_sweeper() -> AirSweeper:
	if not _sweeper_spawn_pending:
		return null
	_sweeper_spawn_pending = false
	_sweeper_cue_remaining = 0.0
	_sweeper_entry_cue.visible = false
	var sweeper := AIR_SWEEPER_SCENE.instantiate() as AirSweeper
	sweeper.position = Vector2(sweeper_spawn_x, sweeper_altitude)
	sweeper.configure(
		_pending_sweeper_speed,
		sweeper_altitude,
		sweeper_size,
		sweeper_exit_x
	)
	sweeper.player_hit.connect(_on_sweeper_hit)
	sweeper.cleared.connect(_on_sweeper_cleared)
	_hazard_container.add_child(sweeper)
	_active_sweepers.append(sweeper)
	_sweeper_contexts[sweeper.get_instance_id()] = {
		"pattern_type": _pending_sweeper_pattern_type,
		"spawned_at": survival_time,
		"reached_player_region": false,
		"reached_at": -1.0,
		"player_region_x": NAN,
	}
	_record_encounter({
		"event": "sweeper_spawn",
		"pattern_type": _pending_sweeper_pattern_type,
		"time": survival_time,
		"x": sweeper.position.x,
	})
	_pending_sweeper_pattern_type = -1
	sweeper_spawned.emit(sweeper)
	return sweeper


func _start_next_telegraph(
	event_fall_duration: float = NAN,
	target_x: float = NAN,
	pattern_type: int = -1
) -> bool:
	var selected_lane := -1
	var selected_x := target_x
	if is_nan(target_x):
		if drop_lane_positions.is_empty():
			return false
		for offset in range(
			maxi(drop_lane_sequence.size(), drop_lane_positions.size())
		):
			var sequence_value := (
				drop_lane_sequence[
					(_sequence_cursor + offset) % drop_lane_sequence.size()
				]
				if not drop_lane_sequence.is_empty()
				else _sequence_cursor + offset
			)
			var lane_index := posmod(
				sequence_value,
				drop_lane_positions.size()
			)
			if drop_lane_is_geometrically_valid(lane_index):
				selected_lane = lane_index
				selected_x = drop_lane_positions[lane_index]
				_sequence_cursor += offset + 1
				break
		if selected_lane < 0:
			return false
	elif not _targeted_drop_is_currently_valid(
		target_x,
		event_fall_duration
	):
		return false
	_pending_lane_index = selected_lane
	_pending_drop_x = selected_x
	_pending_drop_pattern_type = pattern_type
	_telegraph_remaining = telegraph_duration
	_pending_fall_duration = (
		target_fall_duration_at(survival_time)
		if is_nan(event_fall_duration)
		else event_fall_duration
	)
	_show_warning()
	telegraph_started.emit(_pending_lane_index, telegraph_duration)
	_record_encounter({
		"event": "can_warning",
		"pattern_type": pattern_type,
		"time": survival_time,
		"target_x": _pending_drop_x,
		"lane_index": _pending_lane_index,
	})
	return true


func _targeted_drop_is_currently_valid(
	target_x: float,
	event_fall_duration: float
) -> bool:
	var half_product_width := product_size.x * 0.5
	if (
		is_nan(target_x)
		or target_x - half_product_width < belt_left_x
		or target_x + half_product_width > belt_right_x
	):
		return false
	var remaining_fall_duration := (
		target_fall_duration_at(survival_time)
		if is_nan(event_fall_duration)
		else event_fall_duration
	)
	var time_until_impact := telegraph_duration + remaining_fall_duration
	if _right_pressure_landing_overlaps_existing_can(
		target_x,
		time_until_impact
	):
		return false
	var required_escape_distance := (
		product_size.x * 0.5
		+ player_collision_size().x * 0.5
		+ grounded_sweeper_clearance
	)
	var escape_x := target_x - required_escape_distance
	return not _right_pressure_escape_corridor_is_blocked(
		escape_x,
		target_x,
		0.0
	)


func _has_pending_drop() -> bool:
	return not is_nan(_pending_drop_x)


func _show_warning() -> void:
	_source_carriage.position.x = _pending_drop_x
	_source_carriage.visible = true
	_warning_column.visible = true
	_warning_text.visible = true
	_source_head.color = Color(0.92, 0.24, 0.20, 1.0)


func _drop_pending_product() -> ConveyorProduct:
	if not _has_pending_drop():
		return null
	var lane_index := _pending_lane_index
	var drop_x := _pending_drop_x
	var drop_pattern_type := _pending_drop_pattern_type
	var product := CONVEYOR_PRODUCT_SCENE.instantiate() as ConveyorProduct
	product.position = Vector2(drop_x, product_spawn_y)
	product.configure_conveyor(
		fall_distance() / _pending_fall_duration
			if _pending_fall_duration > 0.0
			else INF,
		floor_y,
		landed_lifetime,
		despawn_warning_duration,
		product_size,
		landed_product_size,
		conveyor_speed,
		offscreen_cleanup_x
	)
	product.player_hit.connect(_on_product_hit)
	product.landed.connect(_on_product_landed)
	product.cleared.connect(_on_product_cleared)
	_hazard_container.add_child(product)
	_falling_products.append(product)
	_chute_product = product
	_pending_lane_index = -1
	_pending_drop_x = NAN
	_pending_drop_pattern_type = -1
	_telegraph_remaining = 0.0
	_update_source_visuals()
	product_dropped.emit(lane_index, product.fall_speed)
	_record_encounter({
		"event": "can_spawn",
		"pattern_type": drop_pattern_type,
		"time": survival_time,
		"target_x": drop_x,
	})
	return product


func _update_source_visuals() -> void:
	var falling_visible := (
		is_instance_valid(_chute_product)
		and _chute_product.is_falling()
	)
	var warning_visible := _has_pending_drop()
	_source_carriage.visible = warning_visible or falling_visible
	_warning_column.visible = warning_visible
	_warning_text.visible = warning_visible
	_source_head.color = (
		Color(0.92, 0.24, 0.20, 1.0)
		if warning_visible
		else Color(0.36, 0.72, 0.86, 1.0)
			if falling_visible
			else Color(0.30, 0.34, 0.40, 1.0)
	)


func _on_product_hit(product: FallingProduct) -> void:
	if is_dead or not product.is_falling_lethal():
		return
	_kill_player()


func _on_product_landed(product: FallingProduct) -> void:
	if not product is ConveyorProduct:
		return
	var conveyor_product := product as ConveyorProduct
	_falling_products.erase(conveyor_product)
	if not _landed_products.has(conveyor_product):
		_landed_products.append(conveyor_product)
	if _chute_product == conveyor_product:
		_chute_product = null
	_update_source_visuals()
	conveyor_product_landed.emit(conveyor_product)


func _on_product_cleared(product: FallingProduct) -> void:
	if not product is ConveyorProduct:
		return
	var conveyor_product := product as ConveyorProduct
	_falling_products.erase(conveyor_product)
	_landed_products.erase(conveyor_product)
	if _chute_product == conveyor_product:
		_chute_product = null
	_update_source_visuals()
	conveyor_product_cleared.emit(conveyor_product)


func _on_sweeper_hit(_sweeper: AirSweeper) -> void:
	if is_dead:
		return
	_kill_player()


func _on_sweeper_cleared(sweeper: AirSweeper) -> void:
	_active_sweepers.erase(sweeper)
	_sweeper_contexts.erase(sweeper.get_instance_id())


func _on_off_belt_kill_region_body_entered(body: Node2D) -> void:
	if not left_failure_enabled or is_dead or body != player:
		return
	_kill_player()


func _kill_player() -> void:
	if is_dead or is_round_complete:
		return
	is_dead = true
	_stop_active_gameplay()
	_death_label.visible = true
	player_died.emit()


func stop_for_round_completion() -> void:
	if is_dead or is_round_complete:
		return
	is_round_complete = true
	_stop_active_gameplay()


func gameplay_is_stopped() -> bool:
	return is_dead or is_round_complete


func _stop_active_gameplay() -> void:
	player.set_physics_process(false)
	_belt_floor.constant_linear_velocity = Vector2.ZERO
	_clear_warning_state()
	for product in _falling_products:
		if is_instance_valid(product):
			product.stop()
	for product in _landed_products:
		if is_instance_valid(product):
			product.stop()
	for sweeper in _active_sweepers:
		if is_instance_valid(sweeper):
			sweeper.stop()
	_clear_pattern_state()


func _clear_warning_state() -> void:
	_pending_lane_index = -1
	_pending_drop_x = NAN
	_pending_drop_pattern_type = -1
	_telegraph_remaining = 0.0
	_pending_fall_duration = target_fall_duration_at(survival_time)
	_chute_product = null
	_update_source_visuals()


func _clear_pattern_state() -> void:
	_reserved_pattern_type = -1
	_active_pattern_type = -1
	_active_pattern_elapsed = 0.0
	_active_pattern_started_at = 0.0
	_active_pattern_events.clear()
	_pattern_cooldown_remaining = 0.0
	_sweeper_spawn_pending = false
	_sweeper_cue_remaining = 0.0
	_pending_sweeper_speed = sweeper_speed_at(survival_time)
	_pending_sweeper_pattern_type = -1
	_sweeper_contexts.clear()
	_sweeper_entry_cue.visible = false
	_right_edge_dwell_time = 0.0
	_right_pressure_requested = false
	_right_pressure_target_x = NAN
	_right_pressure_reserved_at = -1.0


func _update_timer_label() -> void:
	if external_timer_display_enabled:
		return
	_timer_label.text = "SURVIVAL  %05.2f s" % survival_time
