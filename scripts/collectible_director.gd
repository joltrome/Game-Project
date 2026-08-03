class_name CollectibleDirector
extends Node2D

signal collectible_spawned(collectible: ConveyorCollectible)
signal score_changed(score: int)

enum PlacementBand {
	GROUND,
	LOW_AIR,
}

const COLLECTIBLE_SCENE := preload(
	"res://scenes/collectibles/conveyor_collectible.tscn"
)

@export_category("Timing")
@export var first_spawn_window_min: float = 5.0
@export var first_spawn_window_max: float = 8.0
@export var first_spawn_time: float = 6.5
@export var recurring_spawn_interval: float = 7.0
@export var failed_spawn_retry_delay: float = 0.10
@export var collectible_lifetime: float = 3.0

@export_category("Band Distribution")
@export_range(0.0, 1.0, 0.01) var ground_probability_after_first := 0.50
@export var placement_seed: int = 401
@export var ground_band_center_y_range := Vector2(548.0, 552.0)
@export var low_air_band_center_y_range := Vector2(488.0, 500.0)
@export var minimum_normal_jump_margin: float = 48.0

@export_category("Horizontal Placement")
@export var candidate_x_positions := PackedFloat32Array([600.0, 560.0, 640.0])
@export var collectible_size: Vector2 = Vector2(24.0, 24.0)
@export var safe_edge_exclusion: float = 48.0
@export var reachability_reserve: float = 0.35

var score: int = 0
var first_actual_spawn_time: float = -1.0
var last_spawn_band: int = -1
var spawn_count: int = 0
var _next_spawn_time: float = 6.5
var _active_collectible: ConveyorCollectible = null
var _pending_band: int = -1
var _placement_rng_state: int = 401

@onready var _conveyor: ConveyorPrototype = get_parent() as ConveyorPrototype
@onready var _score_label: Label = _conveyor.get_node("HUD/CollectibleScore")


func _ready() -> void:
	_next_spawn_time = clampf(
		first_spawn_time,
		first_spawn_window_min,
		first_spawn_window_max
	)
	_placement_rng_state = placement_seed
	_update_score_label()
	_conveyor.player_died.connect(_on_player_died)


func _process(_delta: float) -> void:
	if _conveyor.gameplay_is_stopped() or is_instance_valid(_active_collectible):
		return
	if _conveyor.survival_time + 0.0001 < _next_spawn_time:
		return
	if not _try_spawn_collectible():
		_next_spawn_time = _conveyor.survival_time + failed_spawn_retry_delay


func active_collectible_count() -> int:
	return 1 if is_instance_valid(_active_collectible) else 0


func active_collectible() -> ConveyorCollectible:
	return _active_collectible if is_instance_valid(_active_collectible) else null


func next_spawn_time() -> float:
	return _next_spawn_time


func pending_band() -> int:
	return _pending_band


func try_spawn_for_test() -> bool:
	return _try_spawn_collectible()


func try_spawn_band_for_test(band: int) -> bool:
	_pending_band = band
	return _try_spawn_collectible()


func preview_band_sequence_for_test(count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var preview_state := placement_seed
	for index in range(maxi(count, 0)):
		if index == 0:
			result.append(PlacementBand.GROUND)
			continue
		preview_state = _next_rng_state(preview_state)
		result.append(_band_from_roll(preview_state))
	return result


func band_center_y(band: int) -> float:
	var configured_range := (
		ground_band_center_y_range
		if band == PlacementBand.GROUND
		else low_air_band_center_y_range
	)
	return (configured_range.x + configured_range.y) * 0.5


func candidate_is_reachable(candidate: Vector2, band: int = -1) -> bool:
	var evaluated_band := _resolve_band(candidate, band)
	var relative_control_speed := _conveyor.player.maximum_speed
	var available_time := maxf(
		collectible_lifetime - reachability_reserve,
		0.0
	)
	var horizontal_time := (
		absf(candidate.x - _conveyor.player.global_position.x)
		/ relative_control_speed
		if relative_control_speed > 0.0
		else INF
	)
	if relative_control_speed <= _conveyor.conveyor_speed:
		return false
	if evaluated_band == PlacementBand.GROUND:
		return (
			_grounded_player_overlaps_y(candidate.y)
			and horizontal_time <= available_time + 0.0001
		)
	var intervals := normal_jump_collection_intervals(candidate.y)
	if intervals.is_empty() or _grounded_player_overlaps_y(candidate.y):
		return false
	return (
		normal_jump_collection_margin(candidate.y)
			>= minimum_normal_jump_margin
		and maxf(horizontal_time, intervals[0].x)
			<= available_time + 0.0001
	)


func candidate_is_valid(candidate: Vector2, band: int = -1) -> bool:
	var evaluated_band := _resolve_band(candidate, band)
	var half_size := collectible_size * 0.5
	var risky_right_limit := (
		_conveyor.right_edge_zone_left() - safe_edge_exclusion
	)
	if (
		candidate.x - half_size.x < _conveyor.belt_left_x
		or candidate.x + half_size.x > _conveyor.control_band_right
		or candidate.x > risky_right_limit
		or candidate.y - half_size.y <= 0.0
		or candidate.y + half_size.y > _conveyor.floor_y
	):
		return false
	var expiry_left := (
		candidate.x
		- _conveyor.conveyor_speed * collectible_lifetime
		- half_size.x
	)
	if expiry_left < _conveyor.conveyor_support_left_x:
		return false
	if not candidate_is_reachable(candidate, evaluated_band):
		return false
	if _overlaps_or_intercepts_current_hazard(candidate, evaluated_band):
		return false
	if _warning_or_reserved_can_conflicts(candidate.x):
		return false
	if (
		evaluated_band == PlacementBand.LOW_AIR
		and _sweeper_plan_conflicts(candidate)
	):
		return false
	return true


func normal_jump_collection_margin(coin_center_y: float) -> float:
	var start_center_y := (
		_conveyor.floor_y - _conveyor.player_collision_size().y * 0.5
	)
	var combined_half_height := (
		_conveyor.player_collision_size().y + collectible_size.y
	) * 0.5
	var required_rise := maxf(
		start_center_y - (coin_center_y + combined_half_height),
		0.0
	)
	return _conveyor.calculated_jump_height() - required_rise


func normal_jump_collection_intervals(coin_center_y: float) -> Array[Vector2]:
	var intervals: Array[Vector2] = []
	var player_size := _conveyor.player_collision_size()
	var start_center_y := _conveyor.floor_y - player_size.y * 0.5
	var combined_half_height := (player_size.y + collectible_size.y) * 0.5
	var upper_center_y := coin_center_y + combined_half_height
	var lower_center_y := coin_center_y - combined_half_height
	if upper_center_y >= start_center_y:
		return intervals
	var apex_time := absf(_conveyor.player.jump_velocity) / _conveyor.player.gravity
	var total_duration := apex_time * 2.0
	var ascent_start := _jump_ascent_time_at_center_y(upper_center_y)
	var ascent_end := _jump_ascent_time_at_center_y(lower_center_y)
	if ascent_start < 0.0:
		return intervals
	if ascent_end < 0.0:
		ascent_end = apex_time
	if ascent_end > ascent_start:
		intervals.append(Vector2(ascent_start, ascent_end))
		intervals.append(Vector2(
			total_duration - ascent_end,
			total_duration - ascent_start
		))
	return intervals


func stop_for_round_end() -> void:
	set_process(false)
	if is_instance_valid(_active_collectible):
		_active_collectible.stop()


func _try_spawn_collectible() -> bool:
	if is_instance_valid(_active_collectible) or _conveyor.gameplay_is_stopped():
		return false
	if _pending_band < 0:
		_pending_band = _select_next_band()
	var spawn_y := band_center_y(_pending_band)
	for candidate_x in candidate_x_positions:
		var candidate := Vector2(candidate_x, spawn_y)
		if not candidate_is_valid(candidate, _pending_band):
			continue
		var collectible := COLLECTIBLE_SCENE.instantiate() as ConveyorCollectible
		add_child(collectible)
		collectible.global_position = candidate
		collectible.configure(
			collectible_lifetime,
			_conveyor.conveyor_speed,
			collectible_size,
			_pending_band
		)
		collectible.collected.connect(_on_collectible_collected)
		collectible.expired.connect(_on_collectible_expired)
		_active_collectible = collectible
		last_spawn_band = _pending_band
		_pending_band = -1
		spawn_count += 1
		if first_actual_spawn_time < 0.0:
			first_actual_spawn_time = _conveyor.survival_time
		collectible_spawned.emit(collectible)
		return true
	return false


func _select_next_band() -> int:
	if spawn_count == 0:
		return PlacementBand.GROUND
	_placement_rng_state = _next_rng_state(_placement_rng_state)
	return _band_from_roll(_placement_rng_state)


func _band_from_roll(roll_source: int) -> int:
	var ground_threshold := roundi(
		clampf(ground_probability_after_first, 0.0, 1.0) * 10000.0
	)
	return (
		PlacementBand.GROUND
		if posmod(roll_source, 10000) < ground_threshold
		else PlacementBand.LOW_AIR
	)


func _next_rng_state(state: int) -> int:
	return (state * 1103515245 + 12345) & 0x7fffffff


func _resolve_band(candidate: Vector2, requested_band: int) -> int:
	if requested_band in [PlacementBand.GROUND, PlacementBand.LOW_AIR]:
		return requested_band
	return (
		PlacementBand.GROUND
		if _grounded_player_overlaps_y(candidate.y)
		else PlacementBand.LOW_AIR
	)


func _grounded_player_overlaps_y(coin_center_y: float) -> bool:
	var player_center_y := (
		_conveyor.floor_y - _conveyor.player_collision_size().y * 0.5
	)
	return absf(coin_center_y - player_center_y) <= (
		(_conveyor.player_collision_size().y + collectible_size.y) * 0.5
	)


func _jump_ascent_time_at_center_y(target_center_y: float) -> float:
	var start_center_y := (
		_conveyor.floor_y - _conveyor.player_collision_size().y * 0.5
	)
	var displacement_up := start_center_y - target_center_y
	var launch_speed := absf(_conveyor.player.jump_velocity)
	var discriminant := (
		launch_speed * launch_speed
		- 2.0 * _conveyor.player.gravity * displacement_up
	)
	if displacement_up < 0.0 or discriminant < 0.0:
		return -1.0
	return (launch_speed - sqrt(discriminant)) / _conveyor.player.gravity


func _overlaps_or_intercepts_current_hazard(
	candidate: Vector2,
	band: int
) -> bool:
	for product in _conveyor.active_falling_products():
		if _falling_can_path_conflicts(candidate, product):
			return true
	for product in _conveyor.active_landed_products():
		var landed_center := Vector2(
			product.conveyor_center_x(),
			product.global_position.y
		)
		if _rectangles_overlap(
			candidate,
			collectible_size,
			landed_center,
			product.landed_size
		):
			return true
	if band == PlacementBand.LOW_AIR:
		for sweeper in _conveyor.active_sweepers():
			if _active_sweeper_crosses_coin(candidate, sweeper):
				return true
	return false


func _falling_can_path_conflicts(
	candidate: Vector2,
	product: ConveyorProduct
) -> bool:
	var coin_left_at_expiry := (
		candidate.x - _conveyor.conveyor_speed * collectible_lifetime
	)
	var half_width_sum := (collectible_size.x + product.falling_size.x) * 0.5
	return (
		product.global_position.x >= coin_left_at_expiry - half_width_sum
		and product.global_position.x <= candidate.x + half_width_sum
	)


func _warning_or_reserved_can_conflicts(candidate_x: float) -> bool:
	var possible_x_positions := PackedFloat32Array()
	var warning_x := _conveyor.current_warning_x()
	if not is_nan(warning_x):
		possible_x_positions.append(warning_x)
	var active_pattern := _conveyor.active_pattern_type()
	var reserved_pattern := _conveyor.reserved_pattern_type()
	if _pattern_includes_can(active_pattern) or _pattern_includes_can(reserved_pattern):
		for lane_x in _conveyor.drop_lane_positions:
			possible_x_positions.append(lane_x)
	if (
		active_pattern == ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE
		or reserved_pattern == ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE
		or _conveyor.right_pressure_is_requested()
	):
		var target_x := _conveyor.right_pressure_target_x()
		if not is_nan(target_x):
			possible_x_positions.append(target_x)
	var coin_left_at_expiry := (
		candidate_x - _conveyor.conveyor_speed * collectible_lifetime
	)
	var half_width_sum := (
		collectible_size.x + _conveyor.product_size.x
	) * 0.5
	for possible_x in possible_x_positions:
		if (
			possible_x >= coin_left_at_expiry - half_width_sum
			and possible_x <= candidate_x + half_width_sum
		):
			return true
	return false


func _sweeper_plan_conflicts(candidate: Vector2) -> bool:
	if _conveyor.sweeper_cue_is_visible():
		return true
	if _pattern_includes_sweeper(_conveyor.active_pattern_type()):
		return true
	if _pattern_includes_sweeper(_conveyor.reserved_pattern_type()):
		return true
	for sweeper in _conveyor.active_sweepers():
		if _active_sweeper_crosses_coin(candidate, sweeper):
			return true
	return false


func _active_sweeper_crosses_coin(
	candidate: Vector2,
	sweeper: AirSweeper
) -> bool:
	var closing_speed := sweeper.travel_speed + _conveyor.conveyor_speed
	if closing_speed <= 0.0 or sweeper.global_position.x > candidate.x:
		return false
	var crossing_time := (
		(candidate.x - sweeper.global_position.x) / closing_speed
	)
	return crossing_time <= collectible_lifetime + 0.0001


func _pattern_includes_can(pattern_type: int) -> bool:
	return pattern_type in [
		ConveyorPrototype.PatternType.CAN_ONLY,
		ConveyorPrototype.PatternType.SWEEPER_THEN_CAN,
		ConveyorPrototype.PatternType.CAN_THEN_SWEEPER,
		ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE,
	]


func _pattern_includes_sweeper(pattern_type: int) -> bool:
	return pattern_type in [
		ConveyorPrototype.PatternType.SWEEPER_ONLY,
		ConveyorPrototype.PatternType.SWEEPER_THEN_CAN,
		ConveyorPrototype.PatternType.CAN_THEN_SWEEPER,
		ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE,
	]


func _rectangles_overlap(
	first_center: Vector2,
	first_size: Vector2,
	second_center: Vector2,
	second_size: Vector2
) -> bool:
	return (
		absf(first_center.x - second_center.x)
			< (first_size.x + second_size.x) * 0.5
		and absf(first_center.y - second_center.y)
			< (first_size.y + second_size.y) * 0.5
	)


func _on_collectible_collected(collectible: ConveyorCollectible) -> void:
	if collectible != _active_collectible:
		return
	score += 1
	_active_collectible = null
	_next_spawn_time = _conveyor.survival_time + recurring_spawn_interval
	_update_score_label()
	score_changed.emit(score)


func _on_collectible_expired(collectible: ConveyorCollectible) -> void:
	if collectible != _active_collectible:
		return
	_active_collectible = null
	_next_spawn_time = _conveyor.survival_time + recurring_spawn_interval


func _on_player_died() -> void:
	stop_for_round_end()


func _update_score_label() -> void:
	_score_label.text = "COINS: %d" % score
