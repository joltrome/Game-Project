class_name FallingProduct
extends Area2D

signal player_hit(product: FallingProduct)
signal landed(product: FallingProduct)
signal cleared(product: FallingProduct)

enum ProductState {
	FALLING,
	LANDED,
	STOPPED,
}

@export var fall_speed: float = 360.0
@export var floor_y: float = 584.0
@export var landed_lifetime: float = 6.0
@export var falling_size: Vector2 = Vector2(72.0, 72.0)
@export var landed_size: Vector2 = Vector2(72.0, 48.0)

var state: ProductState = ProductState.FALLING
var landed_time_remaining: float = 0.0

@onready var _body_visual: Polygon2D = $Body
@onready var _band_visual: Polygon2D = $Band
@onready var _label: Label = $Label
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_collision_shape.shape = _collision_shape.shape.duplicate()
	_apply_product_size(falling_size)


func _physics_process(delta: float) -> void:
	match state:
		ProductState.FALLING:
			position.y += fall_speed * delta
			if position.y + falling_size.y * 0.5 >= floor_y:
				_land()
		ProductState.LANDED:
			landed_time_remaining = maxf(landed_time_remaining - delta, 0.0)
			if landed_time_remaining <= 0.0:
				_clear()
		ProductState.STOPPED:
			return


func configure(
	speed: float,
	floor_level: float,
	lifetime: float,
	drop_size: Vector2,
	obstacle_size: Vector2
) -> void:
	fall_speed = speed
	floor_y = floor_level
	landed_lifetime = lifetime
	falling_size = drop_size
	landed_size = obstacle_size
	if is_node_ready():
		_apply_product_size(falling_size)


func stop() -> void:
	state = ProductState.STOPPED
	set_physics_process(false)


func is_landed() -> bool:
	return state == ProductState.LANDED


func _land() -> void:
	state = ProductState.LANDED
	landed_time_remaining = landed_lifetime
	position.y = floor_y - landed_size.y * 0.5
	_apply_product_size(landed_size)
	_label.text = "LANDED"
	landed.emit(self)


func _clear() -> void:
	state = ProductState.STOPPED
	cleared.emit(self)
	queue_free()


func _apply_product_size(size: Vector2) -> void:
	var half_size := size * 0.5
	_body_visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	_band_visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -8.0),
		Vector2(half_size.x, -8.0),
		Vector2(half_size.x, 8.0),
		Vector2(-half_size.x, 8.0),
	])
	_label.position = Vector2(-half_size.x, -10.0)
	_label.size = Vector2(size.x, 20.0)

	var rectangle := _collision_shape.shape as RectangleShape2D
	rectangle.size = size


func _on_body_entered(body: Node2D) -> void:
	if state == ProductState.STOPPED or not body is SharedPlayerController:
		return

	player_hit.emit(self)
