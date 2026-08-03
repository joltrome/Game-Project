class_name CollectibleDirector
extends Node2D

signal collectible_spawned(collectible: ConveyorCollectible)
signal score_changed(score: int)

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

@export_category("Placement")
@export var candidate_x_positions := PackedFloat32Array([600.0, 560.0, 640.0])
@export var collectible_y: float = 552.0
@export var collectible_size: Vector2 = Vector2(24.0, 24.0)
@export var safe_edge_exclusion: float = 48.0
@export var reachability_reserve: float = 0.35

var score: int = 0
var first_actual_spawn_time: float = -1.0
var _next_spawn_time: float = 6.5
var _active_collectible: ConveyorCollectible = null

@onready var _conveyor: ConveyorPrototype = get_parent() as ConveyorPrototype
@onready var _score_label: Label = _conveyor.get_node("HUD/CollectibleScore")


func _ready() -> void:
	_next_spawn_time = clampf(
		first_spawn_time,
		first_spawn_window_min,
		first_spawn_window_max
	)
	_update_score_label()
	_conveyor.player_died.connect(_on_player_died)


func _process(_delta: float) -> void:
	if _conveyor.is_dead or is_instance_valid(_active_collectible):
		return
	if _conveyor.survival_time + 0.0001 < _next_spawn_time:
		return
	if not _try_spawn_collectible():
		_next_spawn_time = (
			_conveyor.survival_time + failed_spawn_retry_delay
		)


func active_collectible_count() -> int:
	return 1 if is_instance_valid(_active_collectible) else 0


func active_collectible() -> ConveyorCollectible:
	return _active_collectible if is_instance_valid(_active_collectible) else null


func next_spawn_time() -> float:
	return _next_spawn_time


func try_spawn_for_test() -> bool:
	return _try_spawn_collectible()


func candidate_is_reachable(candidate: Vector2) -> bool:
	var relative_control_speed := _conveyor.player.maximum_speed
	var available_time := maxf(
		collectible_lifetime - reachability_reserve,
		0.0
	)
	var horizontal_distance := absf(
		candidate.x - _conveyor.player.global_position.x
	)
	var player_size := _conveyor.player_collision_size()
	var player_ground_center_y := _conveyor.floor_y - player_size.y * 0.5
	var vertical_contact := (
		absf(candidate.y - player_ground_center_y)
		<= (collectible_size.y + player_size.y) * 0.5
	)
	return (
		vertical_contact
		and relative_control_speed > _conveyor.conveyor_speed
		and horizontal_distance
			<= relative_control_speed * available_time + 0.0001
	)


func candidate_is_valid(candidate: Vector2) -> bool:
	var half_size := collectible_size * 0.5
	var risky_right_limit := (
		_conveyor.right_edge_zone_left() - safe_edge_exclusion
	)
	if (
		candidate.x - half_size.x < _conveyor.belt_left_x
		or candidate.x + half_size.x > _conveyor.control_band_right
		or candidate.x > risky_right_limit
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
	if not candidate_is_reachable(candidate):
		return false
	if _overlaps_current_hazard(candidate):
		return false
	if _warning_footprint_overlaps(candidate.x):
		return false
	return true


func _try_spawn_collectible() -> bool:
	if is_instance_valid(_active_collectible) or _conveyor.is_dead:
		return false
	for candidate_x in candidate_x_positions:
		var candidate := Vector2(candidate_x, collectible_y)
		if not candidate_is_valid(candidate):
			continue
		var collectible := COLLECTIBLE_SCENE.instantiate() as ConveyorCollectible
		add_child(collectible)
		collectible.global_position = candidate
		collectible.configure(
			collectible_lifetime,
			_conveyor.conveyor_speed,
			collectible_size
		)
		collectible.collected.connect(_on_collectible_collected)
		collectible.expired.connect(_on_collectible_expired)
		_active_collectible = collectible
		if first_actual_spawn_time < 0.0:
			first_actual_spawn_time = _conveyor.survival_time
		collectible_spawned.emit(collectible)
		return true
	return false


func _overlaps_current_hazard(candidate: Vector2) -> bool:
	for product in _conveyor.active_falling_products():
		if absf(candidate.x - product.global_position.x) < (
			(collectible_size.x + product.falling_size.x) * 0.5
		):
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
	for sweeper in _conveyor.active_sweepers():
		if _rectangles_overlap(
			candidate,
			collectible_size,
			sweeper.global_position,
			sweeper.hazard_size
		):
			return true
	return false


func _warning_footprint_overlaps(candidate_x: float) -> bool:
	var warning_x := _conveyor.current_warning_x()
	if not is_nan(warning_x):
		if absf(candidate_x - warning_x) < (
			(collectible_size.x + _conveyor.product_size.x) * 0.5
		):
			return true
	if _conveyor.right_pressure_is_requested():
		var target_x := _conveyor.right_pressure_target_x()
		if not is_nan(target_x) and absf(candidate_x - target_x) < (
			(collectible_size.x + _conveyor.product_size.x) * 0.5
		):
			return true
	return false


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
	if is_instance_valid(_active_collectible):
		_active_collectible.stop()


func _update_score_label() -> void:
	_score_label.text = "COLLECTIBLES  %d" % score
