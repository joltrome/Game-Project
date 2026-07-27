class_name FallingProduct
extends Area2D

signal player_hit(product: FallingProduct)
signal landed(product: FallingProduct)
signal despawn_warning_started(product: FallingProduct)
signal cleared(product: FallingProduct)

enum ProductState {
	FALLING,
	LANDED,
	DESPAWN_WARNING,
	STOPPED,
}

@export var fall_speed: float = 360.0
@export var floor_y: float = 584.0
@export var landed_lifetime: float = 6.0
@export var despawn_warning_duration: float = 1.0
@export var falling_size: Vector2 = Vector2(72.0, 72.0)
@export var landed_size: Vector2 = Vector2(72.0, 48.0)

var state: ProductState = ProductState.FALLING
var landed_time_remaining: float = 0.0

@onready var _body_visual: Polygon2D = $Body
@onready var _band_visual: Polygon2D = $Band
@onready var _label: Label = $Label
@onready var _falling_collision: CollisionShape2D = $CollisionShape2D
@onready var _landed_collision: CollisionShape2D = $LandedBody/CollisionShape2D


func _ready() -> void:
	_falling_collision.shape = _falling_collision.shape.duplicate()
	_landed_collision.shape = _landed_collision.shape.duplicate()
	_update_collision_shapes()
	_set_collision_mode(true, false)
	_apply_product_size(falling_size)
	_apply_falling_visual()


func _physics_process(delta: float) -> void:
	match state:
		ProductState.FALLING:
			var previous_bottom := position.y + falling_size.y * 0.5
			position.y += fall_speed * delta
			var current_bottom := position.y + falling_size.y * 0.5
			if _is_valid_floor_contact(previous_bottom, current_bottom):
				_land()
		ProductState.LANDED:
			landed_time_remaining = maxf(landed_time_remaining - delta, 0.0)
			if landed_time_remaining <= minf(despawn_warning_duration, landed_lifetime):
				_start_despawn_warning()
			if landed_time_remaining <= 0.0:
				_clear()
		ProductState.DESPAWN_WARNING:
			landed_time_remaining = maxf(landed_time_remaining - delta, 0.0)
			if landed_time_remaining <= 0.0:
				_clear()
		ProductState.STOPPED:
			return


func configure(
	speed: float,
	floor_level: float,
	lifetime: float,
	warning_duration: float,
	drop_size: Vector2,
	obstacle_size: Vector2
) -> void:
	fall_speed = speed
	floor_y = floor_level
	landed_lifetime = lifetime
	despawn_warning_duration = warning_duration
	falling_size = drop_size
	landed_size = obstacle_size
	if is_node_ready():
		state = ProductState.FALLING
		landed_time_remaining = 0.0
		set_physics_process(true)
		_update_collision_shapes()
		_set_collision_mode(true, false)
		_apply_product_size(falling_size)
		_apply_falling_visual()


func stop() -> void:
	state = ProductState.STOPPED
	set_physics_process(false)


func is_falling() -> bool:
	return state == ProductState.FALLING


func is_landed() -> bool:
	return state == ProductState.LANDED or state == ProductState.DESPAWN_WARNING


func is_in_despawn_warning() -> bool:
	return state == ProductState.DESPAWN_WARNING


func is_falling_lethal() -> bool:
	return state == ProductState.FALLING and monitoring and not _falling_collision.disabled


func is_landed_solid() -> bool:
	return is_landed() and not _landed_collision.disabled


func _is_valid_floor_contact(previous_bottom: float, current_bottom: float) -> bool:
	return fall_speed > 0.0 and previous_bottom < floor_y and current_bottom >= floor_y


func _land() -> void:
	state = ProductState.LANDED
	landed_time_remaining = landed_lifetime
	position.y = floor_y - landed_size.y * 0.5
	_set_collision_mode(false, true)
	_apply_product_size(landed_size)
	_apply_landed_visual()
	landed.emit(self)


func _start_despawn_warning() -> void:
	if state != ProductState.LANDED:
		return

	state = ProductState.DESPAWN_WARNING
	_apply_warning_visual()
	despawn_warning_started.emit(self)


func _clear() -> void:
	state = ProductState.STOPPED
	_set_collision_mode(false, false)
	cleared.emit(self)
	queue_free()


func _set_collision_mode(falling_lethal: bool, landed_solid: bool) -> void:
	monitoring = falling_lethal
	monitorable = falling_lethal
	collision_layer = 2 if falling_lethal else 0
	collision_mask = 1 if falling_lethal else 0
	_falling_collision.disabled = not falling_lethal
	_landed_collision.disabled = not landed_solid


func _update_collision_shapes() -> void:
	var falling_rectangle := _falling_collision.shape as RectangleShape2D
	falling_rectangle.size = falling_size
	var landed_rectangle := _landed_collision.shape as RectangleShape2D
	landed_rectangle.size = landed_size


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


func _apply_falling_visual() -> void:
	_body_visual.color = Color(0.36, 0.72, 0.86, 1.0)
	_band_visual.color = Color(0.13, 0.27, 0.34, 1.0)
	_label.text = "PRODUCT"


func _apply_landed_visual() -> void:
	_body_visual.color = Color(0.38, 0.62, 0.43, 1.0)
	_band_visual.color = Color(0.14, 0.30, 0.18, 1.0)
	_label.text = "PLATFORM"


func _apply_warning_visual() -> void:
	_body_visual.color = Color(0.92, 0.62, 0.20, 1.0)
	_band_visual.color = Color(0.42, 0.24, 0.08, 1.0)
	_label.text = "DESPAWN"


func _on_body_entered(body: Node2D) -> void:
	if not is_falling_lethal() or not body is SharedPlayerController:
		return

	player_hit.emit(self)
