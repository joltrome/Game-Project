class_name FallingProduct
extends Area2D

signal player_hit(product: FallingProduct)
signal cleared(product: FallingProduct)

@export var fall_speed: float = 360.0
@export var despawn_y: float = 700.0
@export var product_size: Vector2 = Vector2(72.0, 72.0)

var _is_active: bool = true

@onready var _body_visual: Polygon2D = $Body
@onready var _band_visual: Polygon2D = $Band
@onready var _label: Label = $Label
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_apply_product_size()


func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	position.y += fall_speed * delta
	if position.y <= despawn_y:
		return

	_is_active = false
	cleared.emit(self)
	queue_free()


func configure(speed: float, bottom_limit: float, size: Vector2) -> void:
	fall_speed = speed
	despawn_y = bottom_limit
	product_size = size
	if is_node_ready():
		_apply_product_size()


func stop() -> void:
	_is_active = false
	set_physics_process(false)


func _apply_product_size() -> void:
	var half_size := product_size * 0.5
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
	_label.size = Vector2(product_size.x, 20.0)

	var rectangle := _collision_shape.shape as RectangleShape2D
	rectangle.size = product_size


func _on_body_entered(body: Node2D) -> void:
	if not _is_active or not body is SharedPlayerController:
		return

	_is_active = false
	player_hit.emit(self)
