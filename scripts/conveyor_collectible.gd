class_name ConveyorCollectible
extends Area2D

signal collected(collectible: ConveyorCollectible)
signal expired(collectible: ConveyorCollectible)

@export var lifetime: float = 3.0
@export var scroll_speed: float = 140.0
@export var collectible_size: Vector2 = Vector2(24.0, 24.0)

var time_remaining: float = 0.0
var _resolved: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _body_visual: Polygon2D = $Body
@onready var _center_visual: Polygon2D = $Center


func _ready() -> void:
	_collision_shape.shape = _collision_shape.shape.duplicate()
	_apply_dimensions()
	time_remaining = maxf(lifetime, 0.0)


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
	size: Vector2
) -> void:
	lifetime = maxf(duration, 0.0)
	scroll_speed = maxf(conveyor_scroll_speed, 0.0)
	collectible_size = size
	time_remaining = lifetime
	_resolved = false
	monitoring = true
	set_physics_process(true)
	if is_node_ready():
		_apply_dimensions()


func stop() -> void:
	monitoring = false
	set_physics_process(false)


func is_resolved() -> bool:
	return _resolved


func is_non_solid() -> bool:
	return collision_layer == 0 and not monitorable


func _apply_dimensions() -> void:
	var rectangle := _collision_shape.shape as RectangleShape2D
	rectangle.size = collectible_size
	var half_size := collectible_size * 0.5
	_body_visual.polygon = PackedVector2Array([
		Vector2(0.0, -half_size.y),
		Vector2(half_size.x, 0.0),
		Vector2(0.0, half_size.y),
		Vector2(-half_size.x, 0.0),
	])
	_center_visual.polygon = PackedVector2Array([
		Vector2(0.0, -half_size.y * 0.45),
		Vector2(half_size.x * 0.45, 0.0),
		Vector2(0.0, half_size.y * 0.45),
		Vector2(-half_size.x * 0.45, 0.0),
	])


func _resolve(was_collected: bool) -> void:
	if _resolved:
		return
	_resolved = true
	set_deferred("monitoring", false)
	set_physics_process(false)
	if was_collected:
		collected.emit(self)
	else:
		expired.emit(self)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _resolved or not body is SharedPlayerController:
		return
	_resolve(true)
