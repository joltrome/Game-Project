class_name CompactArena
extends Node2D

signal telegraph_started(lane_index: int, duration: float)
signal product_dropped(lane_index: int, fall_speed: float)
signal player_died

const BUILD_ID := "VM-0.2.0-A"
const FALLING_PRODUCT_SCENE := preload("res://scenes/hazards/falling_product.tscn")
const PLAYER_COLLISION_WIDTH := 32.0

@export_category("Drop Layout")
@export var drop_lane_positions: PackedFloat32Array = PackedFloat32Array([
	192.0, 320.0, 448.0, 576.0, 704.0, 832.0, 960.0
])
@export var drop_lane_sequence: PackedInt32Array = PackedInt32Array([
	3, 1, 5, 2, 4, 0, 6, 4, 2, 5, 1, 3
])
@export var product_spawn_y: float = 176.0
@export var product_despawn_y: float = 700.0
@export var product_size: Vector2 = Vector2(72.0, 72.0)

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

@export_category("Fairness Validation")
@export var clearance_margin: float = 12.0

var survival_time: float = 0.0
var is_dead: bool = false

var _active_product: FallingProduct
var _cooldown_remaining: float = 0.0
var _telegraph_remaining: float = 0.0
var _telegraph_duration: float = 0.0
var _telegraphed_lane_index: int = -1
var _sequence_cursor: int = 0

@onready var player: SharedPlayerController = $Player
@onready var _hazard_container: Node2D = $Hazards
@onready var _source_carriage: Node2D = $SourceRack/SourceCarriage
@onready var _source_head: Polygon2D = $SourceRack/SourceCarriage/Head
@onready var _warning_column: Polygon2D = $SourceRack/SourceCarriage/WarningColumn
@onready var _warning_text: Label = $SourceRack/SourceCarriage/WarningText
@onready var _timer_label: Label = $HUD/Timer
@onready var _death_label: Label = $HUD/DeathMessage
@onready var _build_label: Label = $HUD/BuildId


func _ready() -> void:
	_cooldown_remaining = initial_drop_delay
	_build_label.text = "BUILD %s" % BUILD_ID
	_update_timer_label()
	_set_telegraph_visible(false)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	survival_time += delta
	_update_timer_label()

	if _active_product != null:
		return

	if _telegraphed_lane_index >= 0:
		_telegraph_remaining -= delta
		if _telegraph_remaining <= 0.0:
			_drop_telegraphed_product()
		return

	_cooldown_remaining -= delta
	if _cooldown_remaining <= 0.0:
		_start_telegraph()


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


func minimum_reaction_distance() -> float:
	return player.maximum_speed * minimum_telegraph_duration


func required_clearance_distance() -> float:
	return (product_size.x + PLAYER_COLLISION_WIDTH) * 0.5 + clearance_margin


func has_reachable_ground_response() -> bool:
	return minimum_reaction_distance() >= required_clearance_distance()


func active_product_count() -> int:
	return 1 if _active_product != null else 0


func _difficulty_ratio_at(time_seconds: float) -> float:
	if difficulty_ramp_seconds <= 0.0:
		return 1.0
	return clampf(time_seconds / difficulty_ramp_seconds, 0.0, 1.0)


func _start_telegraph() -> void:
	if drop_lane_positions.is_empty() or drop_lane_sequence.is_empty():
		push_error("Compact arena requires at least one drop lane and one sequence entry.")
		return

	var sequence_value := drop_lane_sequence[_sequence_cursor % drop_lane_sequence.size()]
	_telegraphed_lane_index = posmod(sequence_value, drop_lane_positions.size())
	_sequence_cursor += 1

	_telegraph_duration = telegraph_duration_at(survival_time)
	_telegraph_remaining = _telegraph_duration
	_source_carriage.position.x = drop_lane_positions[_telegraphed_lane_index]
	_set_telegraph_visible(true)
	telegraph_started.emit(_telegraphed_lane_index, _telegraph_duration)


func _drop_telegraphed_product() -> void:
	var lane_index := _telegraphed_lane_index
	var speed := fall_speed_at(survival_time)
	var product := FALLING_PRODUCT_SCENE.instantiate() as FallingProduct
	product.position = Vector2(drop_lane_positions[lane_index], product_spawn_y)
	product.configure(speed, product_despawn_y, product_size)
	product.player_hit.connect(_on_product_hit)
	product.cleared.connect(_on_product_cleared)
	_hazard_container.add_child(product)
	_active_product = product

	_telegraphed_lane_index = -1
	_telegraph_remaining = 0.0
	_set_telegraph_visible(false)
	product_dropped.emit(lane_index, speed)


func _on_product_hit(product: FallingProduct) -> void:
	if is_dead:
		return

	is_dead = true
	player.set_physics_process(false)
	product.stop()
	_set_telegraph_visible(false)
	_death_label.visible = true
	player_died.emit()


func _on_product_cleared(product: FallingProduct) -> void:
	if product != _active_product:
		return

	_active_product = null
	_cooldown_remaining = drop_cooldown_at(survival_time)


func _set_telegraph_visible(is_visible: bool) -> void:
	_warning_column.visible = is_visible
	_warning_text.visible = is_visible
	_source_head.color = (
		Color(0.92, 0.24, 0.20, 1.0)
		if is_visible
		else Color(0.30, 0.34, 0.40, 1.0)
	)


func _update_timer_label() -> void:
	_timer_label.text = "SURVIVAL  %05.2f s" % survival_time
