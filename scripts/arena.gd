class_name CompactArena
extends Node2D

signal telegraph_started(lane_index: int, duration: float)
signal product_dropped(lane_index: int, fall_speed: float)
signal pattern_committed(lane_indices: PackedInt32Array, duration: float)
signal pattern_dropped(lane_indices: PackedInt32Array)
signal pattern_retry_scheduled
signal paired_pattern_reserved(reserved_at_time: float)
signal platform_eviction_started(product: FallingProduct)
signal falling_product_landed(product: FallingProduct)
signal player_died

const BUILD_ID := "VM-0.2.3-A"
const FALLING_PRODUCT_SCENE := preload("res://scenes/hazards/falling_product.tscn")
const PLAYER_COLLISION_WIDTH := 32.0
const PLAYER_COLLISION_HEIGHT := 48.0
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

@export_category("Rolling Landed Terrain")
@export var landed_product_size: Vector2 = Vector2(72.0, 48.0)
@export var landed_lifetime: float = 2.0
@export var despawn_warning_duration: float = 0.35
@export var rolling_eviction_warning_duration: float = 0.35
@export_range(1, 3, 1) var maximum_landed_cans: int = 3
@export var minimum_landed_spacing: float = 256.0
@export var jump_clearance_margin: float = 12.0

@export_category("Pacing Thresholds")
@export var single_ramp_midpoint_seconds: float = 5.0
@export var paired_pattern_start_seconds: float = 12.0
@export var late_phase_start_seconds: float = 20.0
@export var final_ramp_seconds: float = 30.0

@export_category("Telegraph Duration")
@export var telegraph_at_zero_seconds: float = 0.70
@export var telegraph_at_five_seconds: float = 0.55
@export var telegraph_at_twelve_seconds: float = 0.40
@export var telegraph_at_twenty_seconds: float = 0.32
@export var minimum_telegraph_duration: float = 0.28

@export_category("Target Fall Duration")
@export var fall_duration_at_zero_seconds: float = 0.75
@export var fall_duration_at_five_seconds: float = 0.60
@export var fall_duration_at_twelve_seconds: float = 0.40
@export var fall_duration_at_twenty_seconds: float = 0.30
@export var minimum_fall_duration: float = 0.25

@export_category("Post-Drop Delay")
@export var initial_drop_delay: float = 0.35
@export var post_drop_delay_before_five_seconds: float = 0.40
@export var post_drop_delay_at_five_seconds: float = 0.30
@export var post_drop_delay_at_twelve_seconds: float = 0.20
@export var post_drop_delay_at_twenty_seconds: float = 0.20
@export var minimum_post_drop_delay: float = 0.15

@export_category("Pattern Scheduling")
@export_range(1, 2, 1) var maximum_concurrent_falling_cans: int = 2
@export var pattern_retry_delay: float = 0.10
@export var pattern_random_seed: int = 2203

@export_category("Fairness Validation")
@export var clearance_margin: float = 12.0
@export var minimum_safe_region_width: float = 64.0
@export var player_support_tolerance: float = 4.0

var survival_time: float = 0.0
var is_dead: bool = false

var _falling_products: Array[FallingProduct] = []
var _landed_products: Array[FallingProduct] = []
var _eviction_pending_products: Array[FallingProduct] = []
var _pending_pattern_lanes := PackedInt32Array()
var _pending_chute_slots := PackedInt32Array()
var _reserved_pattern_size: int = 0
var _pair_reservation_started_at: float = -1.0
var _cooldown_remaining: float = 0.0
var _telegraph_remaining: float = 0.0
var _telegraph_duration: float = 0.0
var _sequence_cursor: int = 0
var _rng := RandomNumberGenerator.new()
var _chute_products: Array[FallingProduct] = []
var _chute_lane_indices := PackedInt32Array([-1, -1])

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
	_chute_products.resize(_source_carriages.size())
	for slot in range(_chute_products.size()):
		_chute_products[slot] = null
	_build_label.text = "BUILD %s" % BUILD_ID
	_update_timer_label()
	_clear_pattern_warnings()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	survival_time += delta
	_update_timer_label()

	if not _pending_pattern_lanes.is_empty():
		_telegraph_remaining -= delta
		if _telegraph_remaining <= 0.0:
			_drop_pending_pattern()

	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if not _pending_pattern_lanes.is_empty() or _cooldown_remaining > 0.0:
		return

	_start_pattern_telegraph()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func telegraph_duration_at(time_seconds: float) -> float:
	if time_seconds < single_ramp_midpoint_seconds:
		return _ramp_between(
			time_seconds,
			0.0,
			single_ramp_midpoint_seconds,
			telegraph_at_zero_seconds,
			telegraph_at_five_seconds
		)
	if time_seconds < paired_pattern_start_seconds:
		return _ramp_between(
			time_seconds,
			single_ramp_midpoint_seconds,
			paired_pattern_start_seconds,
			telegraph_at_five_seconds,
			telegraph_at_twelve_seconds
		)
	if time_seconds < late_phase_start_seconds:
		return _ramp_between(
			time_seconds,
			paired_pattern_start_seconds,
			late_phase_start_seconds,
			telegraph_at_twelve_seconds,
			telegraph_at_twenty_seconds
		)
	return _ramp_between(
		time_seconds,
		late_phase_start_seconds,
		final_ramp_seconds,
		telegraph_at_twenty_seconds,
		minimum_telegraph_duration
	)


func target_fall_duration_at(time_seconds: float) -> float:
	if time_seconds < single_ramp_midpoint_seconds:
		return _ramp_between(
			time_seconds,
			0.0,
			single_ramp_midpoint_seconds,
			fall_duration_at_zero_seconds,
			fall_duration_at_five_seconds
		)
	if time_seconds < paired_pattern_start_seconds:
		return _ramp_between(
			time_seconds,
			single_ramp_midpoint_seconds,
			paired_pattern_start_seconds,
			fall_duration_at_five_seconds,
			fall_duration_at_twelve_seconds
		)
	if time_seconds < late_phase_start_seconds:
		return _ramp_between(
			time_seconds,
			paired_pattern_start_seconds,
			late_phase_start_seconds,
			fall_duration_at_twelve_seconds,
			fall_duration_at_twenty_seconds
		)
	return _ramp_between(
		time_seconds,
		late_phase_start_seconds,
		final_ramp_seconds,
		fall_duration_at_twenty_seconds,
		minimum_fall_duration
	)


func drop_cooldown_at(time_seconds: float) -> float:
	if time_seconds < single_ramp_midpoint_seconds:
		return post_drop_delay_before_five_seconds
	if time_seconds < paired_pattern_start_seconds:
		return _ramp_between(
			time_seconds,
			single_ramp_midpoint_seconds,
			paired_pattern_start_seconds,
			post_drop_delay_at_five_seconds,
			post_drop_delay_at_twelve_seconds
		)
	if time_seconds < late_phase_start_seconds:
		return post_drop_delay_at_twelve_seconds
	return _ramp_between(
		time_seconds,
		late_phase_start_seconds,
		final_ramp_seconds,
		post_drop_delay_at_twenty_seconds,
		minimum_post_drop_delay
	)


func drop_distance() -> float:
	return maxf(
		floor_y - product_size.y * 0.5 - product_spawn_y,
		0.0
	)


func fall_speed_at(time_seconds: float) -> float:
	var duration := target_fall_duration_at(time_seconds)
	if duration <= 0.0:
		return INF
	return drop_distance() / duration


func two_can_probability_at(time_seconds: float) -> float:
	return 1.0 if time_seconds >= paired_pattern_start_seconds else 0.0


func minimum_reaction_distance() -> float:
	return player.maximum_speed * (
		minimum_telegraph_duration + minimum_fall_duration
	)


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


func eviction_pending_count() -> int:
	return _eviction_pending_products.size()


func pending_pattern_lanes() -> PackedInt32Array:
	return _pending_pattern_lanes.duplicate()


func has_pending_pattern() -> bool:
	return not _pending_pattern_lanes.is_empty()


func has_reserved_pair() -> bool:
	return _reserved_pattern_size == 2


func reserved_pattern_size() -> int:
	return _reserved_pattern_size


func pair_reservation_started_at() -> float:
	return _pair_reservation_started_at


func active_chute_count() -> int:
	var count := 0
	for product in _chute_products:
		if is_instance_valid(product) and product.is_falling():
			count += 1
	return count


func chute_is_visible_for_lane(lane_index: int) -> bool:
	for slot in range(_chute_lane_indices.size()):
		if (
			_chute_lane_indices[slot] == lane_index
			and is_instance_valid(_chute_products[slot])
		):
			return _source_carriages[slot].visible
	return false


func chute_position_for_lane(lane_index: int) -> float:
	for slot in range(_chute_lane_indices.size()):
		if (
			_chute_lane_indices[slot] == lane_index
			and is_instance_valid(_chute_products[slot])
		):
			return _source_carriages[slot].position.x
	return NAN


func landed_positions() -> PackedFloat32Array:
	var positions := PackedFloat32Array()
	for product in _landed_products:
		if is_instance_valid(product):
			positions.append(product.position.x)
	return positions


func planned_eviction_positions(incoming_count: int) -> PackedFloat32Array:
	var positions := PackedFloat32Array()
	for product in _select_platform_evictions(incoming_count):
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
		if is_instance_valid(product) and absf(lane_x - product.position.x) < overlap_distance:
			return true
	return false


func is_lane_available(lane_index: int) -> bool:
	return _is_lane_available_for_future(lane_index, [])


func is_pattern_valid(lane_indices: PackedInt32Array) -> bool:
	if lane_indices.is_empty() or lane_indices.size() > maximum_concurrent_falling_cans:
		return false
	if _falling_products.size() + lane_indices.size() > maximum_concurrent_falling_cans:
		return false
	if _free_chute_slots().size() < lane_indices.size():
		return false
	if not is_landed_can_jump_clearable() or not has_safe_landed_spacing():
		return false

	var planned_evictions := _select_platform_evictions(lane_indices.size())
	if (
		not planned_evictions.is_empty()
		and rolling_eviction_warning_duration
			> telegraph_duration_at(survival_time)
				+ target_fall_duration_at(survival_time)
	):
		return false
	var ignored_products := _combined_eviction_products(planned_evictions)
	var retained_products := _retained_landed_products(ignored_products)
	if (
		retained_products.size()
		+ _falling_products.size()
		+ lane_indices.size()
		> maximum_landed_cans
	):
		return false

	var unique_lanes := {}
	for lane_index in lane_indices:
		if (
			unique_lanes.has(lane_index)
			or not _is_lane_available_for_future(lane_index, ignored_products)
		):
			return false
		unique_lanes[lane_index] = true

	if not _future_landed_spacing_is_valid(lane_indices, retained_products):
		return false
	return pattern_has_reachable_safe_region(lane_indices)


func pattern_has_reachable_safe_region(lane_indices: PackedInt32Array) -> bool:
	var centers: Array[float] = []
	for product in _falling_products:
		if is_instance_valid(product) and not centers.has(product.position.x):
			centers.append(product.position.x)
	for lane_index in lane_indices:
		if lane_index < 0 or lane_index >= drop_lane_positions.size():
			return false
		var lane_x := drop_lane_positions[lane_index]
		if not centers.has(lane_x):
			centers.append(lane_x)
	centers.sort()

	var reaction_duration := (
		telegraph_duration_at(survival_time)
		+ target_fall_duration_at(survival_time)
	)
	var reaction_distance := player.maximum_speed * reaction_duration
	var danger_half_width := product_size.x * 0.5
	var safe_interval_start := ARENA_LEFT
	for center in centers:
		var danger_left := center - danger_half_width
		if _safe_interval_is_reachable(safe_interval_start, danger_left, reaction_distance):
			return true
		safe_interval_start = maxf(safe_interval_start, center + danger_half_width)
	return _safe_interval_is_reachable(safe_interval_start, ARENA_RIGHT, reaction_distance)


func warning_is_visible_for_lane(lane_index: int) -> bool:
	var pattern_index := _pending_pattern_lanes.find(lane_index)
	if pattern_index < 0 or pattern_index >= _pending_chute_slots.size():
		return false
	var slot := _pending_chute_slots[pattern_index]
	return slot >= 0 and slot < _warning_columns.size() and _warning_columns[slot].visible


func warning_position_for_lane(lane_index: int) -> float:
	var pattern_index := _pending_pattern_lanes.find(lane_index)
	if pattern_index < 0 or pattern_index >= _pending_chute_slots.size():
		return NAN
	var slot := _pending_chute_slots[pattern_index]
	if slot < 0 or slot >= _source_carriages.size():
		return NAN
	return _source_carriages[slot].position.x


func _ramp_between(
	time_seconds: float,
	start_time: float,
	end_time: float,
	start_value: float,
	end_value: float
) -> float:
	if end_time <= start_time:
		return end_value
	return lerpf(
		start_value,
		end_value,
		clampf((time_seconds - start_time) / (end_time - start_time), 0.0, 1.0)
	)


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
	var requested_pattern_size := 1
	if has_reserved_pair():
		requested_pattern_size = 2
	elif survival_time >= paired_pattern_start_seconds:
		_reserve_paired_pattern()
		requested_pattern_size = 2

	var selected_pattern := _select_valid_pattern(requested_pattern_size)
	if selected_pattern.is_empty():
		_cooldown_remaining = pattern_retry_delay
		pattern_retry_scheduled.emit()
		return

	var free_slots := _free_chute_slots()
	_pending_chute_slots = PackedInt32Array(free_slots.slice(0, requested_pattern_size))
	_begin_rolling_evictions(_select_platform_evictions(requested_pattern_size))
	if requested_pattern_size == 2:
		_clear_pair_reservation()
	_pending_pattern_lanes = selected_pattern
	_telegraph_duration = telegraph_duration_at(survival_time)
	_telegraph_remaining = _telegraph_duration
	_show_pattern_warnings()
	pattern_committed.emit(_pending_pattern_lanes.duplicate(), _telegraph_duration)


func _reserve_paired_pattern() -> void:
	_reserved_pattern_size = 2
	_pair_reservation_started_at = survival_time
	paired_pattern_reserved.emit(_pair_reservation_started_at)


func _clear_pair_reservation() -> void:
	_reserved_pattern_size = 0
	_pair_reservation_started_at = -1.0


func _select_valid_pattern(pattern_size: int) -> PackedInt32Array:
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


func _free_chute_slots() -> Array[int]:
	var slots: Array[int] = []
	for slot in range(_source_carriages.size()):
		if not is_instance_valid(_chute_products[slot]):
			slots.append(slot)
	return slots


func _show_pattern_warnings() -> void:
	_clear_pattern_warnings()
	for pattern_index in range(_pending_pattern_lanes.size()):
		var slot := _pending_chute_slots[pattern_index]
		var lane_index := _pending_pattern_lanes[pattern_index]
		_source_carriages[slot].visible = true
		_source_carriages[slot].position.x = drop_lane_positions[lane_index]
		_warning_columns[slot].visible = true
		_warning_texts[slot].visible = true
		_source_heads[slot].color = Color(0.92, 0.24, 0.20, 1.0)
		telegraph_started.emit(lane_index, _telegraph_duration)


func _clear_pattern_warnings() -> void:
	for slot in range(_source_carriages.size()):
		_warning_columns[slot].visible = false
		_warning_texts[slot].visible = false
		var has_falling_product := (
			slot < _chute_products.size()
			and is_instance_valid(_chute_products[slot])
			and _chute_products[slot].is_falling()
		)
		_source_heads[slot].color = (
			Color(0.36, 0.72, 0.86, 1.0)
			if has_falling_product
			else Color(0.30, 0.34, 0.40, 1.0)
		)
		_source_carriages[slot].visible = has_falling_product or slot == 0


func _drop_pending_pattern() -> void:
	var dropped_lanes := _pending_pattern_lanes.duplicate()
	var dropped_slots := _pending_chute_slots.duplicate()
	var speed := fall_speed_at(survival_time)
	for pattern_index in range(dropped_lanes.size()):
		var lane_index := dropped_lanes[pattern_index]
		var slot := dropped_slots[pattern_index]
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
		_chute_products[slot] = product
		_chute_lane_indices[slot] = lane_index
		product_dropped.emit(lane_index, speed)

	_pending_pattern_lanes = PackedInt32Array()
	_pending_chute_slots = PackedInt32Array()
	_telegraph_remaining = 0.0
	_cooldown_remaining = drop_cooldown_at(survival_time)
	_clear_pattern_warnings()
	pattern_dropped.emit(dropped_lanes)


func _select_platform_evictions(incoming_count: int) -> Array[FallingProduct]:
	var retained_count := _retained_landed_products(_eviction_pending_products).size()
	var required_removals := maxi(
		retained_count + _falling_products.size() + incoming_count - maximum_landed_cans,
		0
	)
	if required_removals == 0:
		return []

	var unsupported: Array[FallingProduct] = []
	var supporting: Array[FallingProduct] = []
	for product in _landed_products:
		if (
			not is_instance_valid(product)
			or _eviction_pending_products.has(product)
			or product.is_rolling_eviction_pending()
		):
			continue
		if _is_player_supported_by(product):
			supporting.append(product)
		else:
			unsupported.append(product)

	var ordered_candidates: Array[FallingProduct] = []
	ordered_candidates.append_array(unsupported)
	ordered_candidates.append_array(supporting)
	if ordered_candidates.size() < required_removals:
		return []
	return ordered_candidates.slice(0, required_removals)


func _begin_rolling_evictions(products: Array[FallingProduct]) -> void:
	for product in products:
		if (
			is_instance_valid(product)
			and product.request_rolling_eviction(rolling_eviction_warning_duration)
		):
			_eviction_pending_products.append(product)
			platform_eviction_started.emit(product)


func _combined_eviction_products(
	additional_products: Array[FallingProduct]
) -> Array[FallingProduct]:
	var combined := _eviction_pending_products.duplicate()
	for product in additional_products:
		if not combined.has(product):
			combined.append(product)
	return combined


func _retained_landed_products(
	ignored_products: Array[FallingProduct]
) -> Array[FallingProduct]:
	var retained: Array[FallingProduct] = []
	for product in _landed_products:
		if is_instance_valid(product) and not ignored_products.has(product):
			retained.append(product)
	return retained


func _is_player_supported_by(product: FallingProduct) -> bool:
	if not is_instance_valid(product) or not product.is_landed_solid():
		return false
	var player_bottom := player.position.y + PLAYER_COLLISION_HEIGHT * 0.5
	var platform_top := product.position.y - landed_product_size.y * 0.5
	var horizontal_limit := (
		PLAYER_COLLISION_WIDTH + landed_product_size.x
	) * 0.5
	return (
		absf(player_bottom - platform_top) <= player_support_tolerance
		and absf(player.position.x - product.position.x) < horizontal_limit
	)


func _is_lane_available_for_future(
	lane_index: int,
	ignored_products: Array[FallingProduct]
) -> bool:
	if lane_index < 0 or lane_index >= drop_lane_positions.size():
		return false
	var lane_x := drop_lane_positions[lane_index]
	if lane_x - product_size.x * 0.5 < ARENA_LEFT:
		return false
	if lane_x + product_size.x * 0.5 > ARENA_RIGHT:
		return false

	for product in _landed_products:
		if not is_instance_valid(product) or ignored_products.has(product):
			continue
		if absf(lane_x - product.position.x) < minimum_landed_spacing:
			return false
	for product in _falling_products:
		if is_instance_valid(product) and absf(lane_x - product.position.x) < minimum_landed_spacing:
			return false
	return true


func _future_landed_spacing_is_valid(
	lane_indices: PackedInt32Array,
	retained_products: Array[FallingProduct]
) -> bool:
	var centers: Array[float] = []
	for product in retained_products:
		centers.append(product.position.x)
	for product in _falling_products:
		if is_instance_valid(product):
			centers.append(product.position.x)
	for lane_index in lane_indices:
		centers.append(drop_lane_positions[lane_index])
	centers.sort()
	for index in range(1, centers.size()):
		if centers[index] - centers[index - 1] < minimum_landed_spacing:
			return false
	return true


func _resolve_chute_for_product(product: FallingProduct) -> void:
	for slot in range(_chute_products.size()):
		if _chute_products[slot] != product:
			continue
		_chute_products[slot] = null
		_chute_lane_indices[slot] = -1
	_clear_pattern_warnings()


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
	_pending_chute_slots = PackedInt32Array()
	_clear_pair_reservation()
	for slot in range(_chute_products.size()):
		_chute_products[slot] = null
		_chute_lane_indices[slot] = -1
	_clear_pattern_warnings()
	_death_label.visible = true
	player_died.emit()


func _on_product_landed(product: FallingProduct) -> void:
	if not _falling_products.has(product):
		return
	_falling_products.erase(product)
	_landed_products.append(product)
	_resolve_chute_for_product(product)
	falling_product_landed.emit(product)


func _on_product_cleared(product: FallingProduct) -> void:
	_falling_products.erase(product)
	_landed_products.erase(product)
	_eviction_pending_products.erase(product)
	_resolve_chute_for_product(product)


func _update_timer_label() -> void:
	_timer_label.text = "SURVIVAL  %05.2f s" % survival_time
