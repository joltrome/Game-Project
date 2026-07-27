class_name CompactArena
extends Node2D

signal telegraph_started(lane_index: int, duration: float)
signal product_dropped(lane_index: int, fall_speed: float)
signal pattern_committed(lane_indices: PackedInt32Array, duration: float)
signal pattern_dropped(lane_indices: PackedInt32Array)
signal pattern_retry_scheduled
signal player_died

const BUILD_ID := "VM-0.2.2-A"
const FALLING_PRODUCT_SCENE := preload("res://scenes/hazards/falling_product.tscn")
const PLAYER_COLLISION_WIDTH := 32.0
const ARENA_LEFT := 96.0
const ARENA_RIGHT := 1056.0

@export_category("Drop Layout")
@export var drop_lane_positions: PackedFloat32Array = PackedFloat32Array([
	192.0, 320.0, 448.0, 576.0, 704.0, 832.0, 960.0
])
@export var drop_lane_sequence: PackedInt32Array = PackedInt32Array([
	3, 1, 5, 2, 4, 0, 6, 4, 2, 5, 1, 3
])
@export var product_spawn_y: float = 176.0
@export var floor_y: float = 584.0
@export var product_size: Vector2 = Vector2(72.0, 72.0)

@export_category("Landed Can Experiment")
@export var landed_product_size: Vector2 = Vector2(72.0, 48.0)
@export var landed_lifetime: float = 6.0
@export var despawn_warning_duration: float = 1.0
@export_range(1, 2, 1) var maximum_landed_cans: int = 2
@export var minimum_landed_spacing: float = 256.0
@export var jump_clearance_margin: float = 12.0

@export_category("Drop Timing")
@export var initial_drop_delay: float = 1.0
@export var initial_telegraph_duration: float = 0.85
@export var minimum_telegraph_duration: float = 0.50
@export var initial_drop_cooldown: float = 0.80
@export var minimum_drop_cooldown: float = 0.35

@export_category("Difficulty")
@export var initial_fall_speed: float = 360.0
@export var maximum_fall_speed: float = 620.0
@export var difficulty_ramp_seconds: float = 60.0

@export_category("Pattern Ramp")
@export var early_phase_end_seconds: float = 15.0
@export var middle_phase_end_seconds: float = 35.0
@export_range(0.0, 1.0, 0.05) var middle_two_can_probability: float = 0.35
@export_range(0.0, 1.0, 0.05) var late_two_can_probability: float = 0.70
@export_range(1, 2, 1) var maximum_concurrent_falling_cans: int = 2
@export var pattern_retry_delay: float = 0.25
@export var pattern_random_seed: int = 2202

@export_category("Fairness Validation")
@export var clearance_margin: float = 12.0
@export var minimum_safe_region_width: float = 64.0

var survival_time: float = 0.0
var is_dead: bool = false

var _falling_products: Array[FallingProduct] = []
var _landed_products: Array[FallingProduct] = []
var _pending_pattern_lanes := PackedInt32Array()
var _cooldown_remaining: float = 0.0
var _telegraph_remaining: float = 0.0
var _telegraph_duration: float = 0.0
var _sequence_cursor: int = 0
var _rng := RandomNumberGenerator.new()

@onready var player: SharedPlayerController = $Player
@onready var _hazard_container: Node2D = $Hazards
@onready var _source_carriages: Array[Node2D] = [
	$SourceRack/SourceCarriage,
	$SourceRack/SourceCarriage2,
]
@onready var _source_heads: Array[Polygon2D] = [
	$SourceRack/SourceCarriage/Head,
	$SourceRack/SourceCarriage2/Head,
]
@onready var _warning_columns: Array[Polygon2D] = [
	$SourceRack/SourceCarriage/WarningColumn,
	$SourceRack/SourceCarriage2/WarningColumn,
]
@onready var _warning_texts: Array[Label] = [
	$SourceRack/SourceCarriage/WarningText,
	$SourceRack/SourceCarriage2/WarningText,
]
@onready var _timer_label: Label = $HUD/Timer
@onready var _death_label: Label = $HUD/DeathMessage
@onready var _build_label: Label = $HUD/BuildId


func _ready() -> void:
	_rng.seed = pattern_random_seed
	_cooldown_remaining = initial_drop_delay
	_build_label.text = "BUILD %s" % BUILD_ID
	_update_timer_label()
	_clear_pattern_warnings()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	survival_time += delta
	_update_timer_label()

	if not _falling_products.is_empty():
		return

	if not _pending_pattern_lanes.is_empty():
		_telegraph_remaining -= delta
		if _telegraph_remaining <= 0.0:
			_drop_pending_pattern()
		return

	_cooldown_remaining -= delta
	if _cooldown_remaining > 0.0:
		return

	if _landed_products.size() >= maximum_landed_cans:
		return

	_start_pattern_telegraph()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func telegraph_duration_at(time_seconds: float) -> float:
	return lerpf(
		initial_telegraph_duration,
		minimum_telegraph_duration,
		_difficulty_ratio_at(time_seconds)
	)


func drop_cooldown_at(time_seconds: float) -> float:
	return lerpf(
		initial_drop_cooldown,
		minimum_drop_cooldown,
		_difficulty_ratio_at(time_seconds)
	)


func fall_speed_at(time_seconds: float) -> float:
	return lerpf(
		initial_fall_speed,
		maximum_fall_speed,
		_difficulty_ratio_at(time_seconds)
	)


func two_can_probability_at(time_seconds: float) -> float:
	if time_seconds < early_phase_end_seconds:
		return 0.0
	if time_seconds < middle_phase_end_seconds:
		return middle_two_can_probability
	return late_two_can_probability


func minimum_reaction_distance() -> float:
	return player.maximum_speed * minimum_telegraph_duration


func required_clearance_distance() -> float:
	return (product_size.x + PLAYER_COLLISION_WIDTH) * 0.5 + clearance_margin


func has_reachable_ground_response() -> bool:
	return minimum_reaction_distance() >= required_clearance_distance()


func active_product_count() -> int:
	return falling_product_count() + landed_product_count()


func falling_product_count() -> int:
	return _falling_products.size()


func landed_product_count() -> int:
	return _landed_products.size()


func pending_pattern_lanes() -> PackedInt32Array:
	return _pending_pattern_lanes.duplicate()


func has_pending_pattern() -> bool:
	return not _pending_pattern_lanes.is_empty()


func landed_positions() -> PackedFloat32Array:
	var positions := PackedFloat32Array()
	for product in _landed_products:
		positions.append(product.position.x)
	return positions


func calculated_jump_height() -> float:
	if player.gravity <= 0.0:
		return INF
	return player.jump_velocity * player.jump_velocity / (2.0 * player.gravity)


func is_landed_can_jump_clearable() -> bool:
	return landed_product_size.y + jump_clearance_margin <= calculated_jump_height()


func has_safe_landed_spacing() -> bool:
	var clear_gap := minimum_landed_spacing - landed_product_size.x
	var required_gap := PLAYER_COLLISION_WIDTH + clearance_margin * 2.0
	return clear_gap >= required_gap


func lane_footprint_overlaps_landed(lane_index: int) -> bool:
	if lane_index < 0 or lane_index >= drop_lane_positions.size():
		return true

	var lane_x := drop_lane_positions[lane_index]
	var overlap_distance := (product_size.x + landed_product_size.x) * 0.5
	for product in _landed_products:
		if absf(lane_x - product.position.x) < overlap_distance:
			return true
	return false


func is_lane_available(lane_index: int) -> bool:
	if lane_index < 0 or lane_index >= drop_lane_positions.size():
		return false

	var lane_x := drop_lane_positions[lane_index]
	if lane_x - product_size.x * 0.5 < ARENA_LEFT:
		return false
	if lane_x + product_size.x * 0.5 > ARENA_RIGHT:
		return false
	if lane_footprint_overlaps_landed(lane_index):
		return false

	for product in _landed_products:
		if absf(lane_x - product.position.x) < minimum_landed_spacing:
			return false
	return true


func is_pattern_valid(lane_indices: PackedInt32Array) -> bool:
	if lane_indices.is_empty() or lane_indices.size() > maximum_concurrent_falling_cans:
		return false
	if _falling_products.size() + lane_indices.size() > maximum_concurrent_falling_cans:
		return false
	if _landed_products.size() + lane_indices.size() > maximum_landed_cans:
		return false
	if not is_landed_can_jump_clearable() or not has_safe_landed_spacing():
		return false

	var unique_lanes := {}
	for lane_index in lane_indices:
		if unique_lanes.has(lane_index) or not is_lane_available(lane_index):
			return false
		unique_lanes[lane_index] = true

	for first_index in range(lane_indices.size()):
		for second_index in range(first_index + 1, lane_indices.size()):
			var first_x := drop_lane_positions[lane_indices[first_index]]
			var second_x := drop_lane_positions[lane_indices[second_index]]
			if absf(first_x - second_x) < minimum_landed_spacing:
				return false

	return pattern_has_reachable_safe_region(lane_indices)


func pattern_has_reachable_safe_region(lane_indices: PackedInt32Array) -> bool:
	var centers: Array[float] = []
	for lane_index in lane_indices:
		if lane_index < 0 or lane_index >= drop_lane_positions.size():
			return false
		centers.append(drop_lane_positions[lane_index])
	centers.sort()

	var reaction_distance := player.maximum_speed * telegraph_duration_at(survival_time)
	var danger_half_width := product_size.x * 0.5
	var safe_interval_start := ARENA_LEFT
	for center in centers:
		var danger_left := center - danger_half_width
		if _safe_interval_is_reachable(safe_interval_start, danger_left, reaction_distance):
			return true
		safe_interval_start = maxf(safe_interval_start, center + danger_half_width)

	return _safe_interval_is_reachable(safe_interval_start, ARENA_RIGHT, reaction_distance)


func warning_is_visible_for_lane(lane_index: int) -> bool:
	var slot := _pending_pattern_lanes.find(lane_index)
	return slot >= 0 and slot < _warning_columns.size() and _warning_columns[slot].visible


func warning_position_for_lane(lane_index: int) -> float:
	var slot := _pending_pattern_lanes.find(lane_index)
	if slot < 0 or slot >= _source_carriages.size():
		return NAN
	return _source_carriages[slot].position.x


func _difficulty_ratio_at(time_seconds: float) -> float:
	if difficulty_ramp_seconds <= 0.0:
		return 1.0
	return clampf(time_seconds / difficulty_ramp_seconds, 0.0, 1.0)


func _safe_interval_is_reachable(
	interval_left: float,
	interval_right: float,
	reaction_distance: float
) -> bool:
	if interval_right - interval_left < minimum_safe_region_width:
		return false

	var center_margin := PLAYER_COLLISION_WIDTH * 0.5 + clearance_margin
	var target_left := interval_left + center_margin
	var target_right := interval_right - center_margin
	if target_left > target_right:
		return false

	var nearest_safe_x := clampf(player.position.x, target_left, target_right)
	return absf(nearest_safe_x - player.position.x) <= reaction_distance


func _start_pattern_telegraph() -> void:
	var selected_pattern := _select_valid_pattern()
	if selected_pattern.is_empty():
		_cooldown_remaining = pattern_retry_delay
		pattern_retry_scheduled.emit()
		return

	_pending_pattern_lanes = selected_pattern
	_telegraph_duration = telegraph_duration_at(survival_time)
	_telegraph_remaining = _telegraph_duration
	_show_pattern_warnings()
	pattern_committed.emit(_pending_pattern_lanes.duplicate(), _telegraph_duration)


func _select_valid_pattern() -> PackedInt32Array:
	var remaining_landed_capacity := maximum_landed_cans - _landed_products.size()
	var maximum_pattern_size := mini(maximum_concurrent_falling_cans, remaining_landed_capacity)
	var wants_two := (
		maximum_pattern_size >= 2
		and _rng.randf() < two_can_probability_at(survival_time)
	)

	var requested_sizes: Array[int] = []
	if wants_two:
		requested_sizes.append(2)
	requested_sizes.append(1)
	for pattern_size in requested_sizes:
		if pattern_size > maximum_pattern_size:
			continue
		var valid_patterns := _collect_valid_patterns(pattern_size)
		if not valid_patterns.is_empty():
			return valid_patterns[_rng.randi_range(0, valid_patterns.size() - 1)]

	return PackedInt32Array()


func _collect_valid_patterns(pattern_size: int) -> Array[PackedInt32Array]:
	var valid_patterns: Array[PackedInt32Array] = []
	if pattern_size == 1:
		for sequence_offset in range(drop_lane_sequence.size()):
			var sequence_value := drop_lane_sequence[
				(_sequence_cursor + sequence_offset) % drop_lane_sequence.size()
			]
			var lane_index := posmod(sequence_value, drop_lane_positions.size())
			var pattern := PackedInt32Array([lane_index])
			if is_pattern_valid(pattern) and not valid_patterns.has(pattern):
				valid_patterns.append(pattern)
	elif pattern_size == 2:
		for first_lane in range(drop_lane_positions.size()):
			for second_lane in range(first_lane + 1, drop_lane_positions.size()):
				var pattern := PackedInt32Array([first_lane, second_lane])
				if is_pattern_valid(pattern):
					valid_patterns.append(pattern)

	_sequence_cursor = (_sequence_cursor + 1) % drop_lane_sequence.size()
	return valid_patterns


func _show_pattern_warnings() -> void:
	for slot in range(_source_carriages.size()):
		var is_active := slot < _pending_pattern_lanes.size()
		_source_carriages[slot].visible = is_active or slot == 0
		_warning_columns[slot].visible = is_active
		_warning_texts[slot].visible = is_active
		_source_heads[slot].color = (
			Color(0.92, 0.24, 0.20, 1.0)
			if is_active
			else Color(0.30, 0.34, 0.40, 1.0)
		)
		if not is_active:
			continue

		var lane_index := _pending_pattern_lanes[slot]
		_source_carriages[slot].position.x = drop_lane_positions[lane_index]
		telegraph_started.emit(lane_index, _telegraph_duration)


func _clear_pattern_warnings() -> void:
	for slot in range(_source_carriages.size()):
		_warning_columns[slot].visible = false
		_warning_texts[slot].visible = false
		_source_heads[slot].color = Color(0.30, 0.34, 0.40, 1.0)
		_source_carriages[slot].visible = slot == 0


func _drop_pending_pattern() -> void:
	var dropped_lanes := _pending_pattern_lanes.duplicate()
	var speed := fall_speed_at(survival_time)
	for lane_index in dropped_lanes:
		var product := FALLING_PRODUCT_SCENE.instantiate() as FallingProduct
		product.position = Vector2(drop_lane_positions[lane_index], product_spawn_y)
		product.configure(
			speed,
			floor_y,
			landed_lifetime,
			despawn_warning_duration,
			product_size,
			landed_product_size
		)
		product.player_hit.connect(_on_product_hit)
		product.landed.connect(_on_product_landed)
		product.cleared.connect(_on_product_cleared)
		_hazard_container.add_child(product)
		_falling_products.append(product)
		product_dropped.emit(lane_index, speed)

	_pending_pattern_lanes = PackedInt32Array()
	_telegraph_remaining = 0.0
	_clear_pattern_warnings()
	pattern_dropped.emit(dropped_lanes)


func _on_product_hit(product: FallingProduct) -> void:
	if is_dead or not product.is_falling_lethal():
		return

	is_dead = true
	player.set_physics_process(false)
	for falling_product in _falling_products:
		falling_product.stop()
	for landed_product in _landed_products:
		landed_product.stop()
	_pending_pattern_lanes = PackedInt32Array()
	_clear_pattern_warnings()
	_death_label.visible = true
	player_died.emit()


func _on_product_landed(product: FallingProduct) -> void:
	if not _falling_products.has(product):
		return

	_falling_products.erase(product)
	_landed_products.append(product)
	if _falling_products.is_empty():
		_cooldown_remaining = drop_cooldown_at(survival_time)


func _on_product_cleared(product: FallingProduct) -> void:
	_falling_products.erase(product)
	_landed_products.erase(product)


func _update_timer_label() -> void:
	_timer_label.text = "SURVIVAL  %05.2f s" % survival_time
