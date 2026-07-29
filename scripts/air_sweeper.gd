class_name AirSweeper
extends Area2D

signal player_hit(sweeper: AirSweeper)
signal cleared(sweeper: AirSweeper)

@export var travel_speed: float = 520.0
@export var fixed_altitude: float = 518.0
@export var hazard_size: Vector2 = Vector2(96.0, 28.0)
@export var exit_x: float = 800.0

var _hit_emitted: bool = false
var _stopped: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _arm_visual: Polygon2D = $Arm
@onready var _housing_visual: Polygon2D = $Housing


func _ready() -> void:
	_collision_shape.shape = _collision_shape.shape.duplicate()
	_apply_dimensions()


func _physics_process(delta: float) -> void:
	if _stopped:
		return
	position.x += travel_speed * delta
	if position.x - hazard_size.x * 0.5 > exit_x:
		_clear()


func configure(
	speed: float,
	altitude: float,
	size: Vector2,
	right_exit_x: float
) -> void:
	travel_speed = maxf(speed, 0.0)
	fixed_altitude = altitude
	hazard_size = size
	exit_x = right_exit_x
	position.y = fixed_altitude
	_hit_emitted = false
	_stopped = false
	if is_node_ready():
		_apply_dimensions()
		monitoring = true
		_collision_shape.disabled = false
		set_physics_process(true)


func stop() -> void:
	_stopped = true
	set_deferred("monitoring", false)
	_collision_shape.set_deferred("disabled", true)
	set_physics_process(false)


func collision_band() -> Vector2:
	return Vector2(
		fixed_altitude - hazard_size.y * 0.5,
		fixed_altitude + hazard_size.y * 0.5
	)


func _apply_dimensions() -> void:
	var rectangle := _collision_shape.shape as RectangleShape2D
	rectangle.size = hazard_size
	var half_size := hazard_size * 0.5
	_arm_visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y * 0.45),
		Vector2(half_size.x, -half_size.y * 0.45),
		Vector2(half_size.x, half_size.y * 0.45),
		Vector2(-half_size.x, half_size.y * 0.45),
	])
	_housing_visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(-half_size.x + 24.0, -half_size.y),
		Vector2(-half_size.x + 24.0, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])


func _clear() -> void:
	if _stopped:
		return
	_stopped = true
	set_deferred("monitoring", false)
	_collision_shape.set_deferred("disabled", true)
	cleared.emit(self)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _stopped or _hit_emitted or not body is SharedPlayerController:
		return
	_hit_emitted = true
	player_hit.emit(self)
