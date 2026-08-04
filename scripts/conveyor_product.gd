class_name ConveyorProduct
extends FallingProduct

signal exited_conveyor(product: ConveyorProduct)

@export var conveyor_speed: float = 140.0
@export var cleanup_left_x: float = 96.0

@onready var _moving_landed_body: AnimatableBody2D = $LandedBody


func _ready() -> void:
	super._ready()
	_update_platform_velocity()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_landed():
		_update_platform_velocity()
		return

	_move_landed_components(-conveyor_speed * delta)
	_update_platform_velocity()
	if conveyor_center_x() + landed_size.x * 0.5 < cleanup_left_x:
		exited_conveyor.emit(self)
		_clear()


func configure_conveyor(
	speed: float,
	floor_level: float,
	lifetime: float,
	warning_duration: float,
	drop_size: Vector2,
	obstacle_size: Vector2,
	scroll_speed: float,
	left_cleanup_boundary: float
) -> void:
	conveyor_speed = maxf(scroll_speed, 0.0)
	cleanup_left_x = left_cleanup_boundary
	configure(
		speed,
		floor_level,
		lifetime,
		warning_duration,
		drop_size,
		obstacle_size
	)
	if is_node_ready():
		_update_platform_velocity()


func stop() -> void:
	if is_node_ready():
		_moving_landed_body.constant_linear_velocity = Vector2.ZERO
	super.stop()


func set_conveyor_speed(speed: float) -> void:
	conveyor_speed = maxf(speed, 0.0)
	_update_platform_velocity()


func intended_platform_velocity() -> Vector2:
	return Vector2(-conveyor_speed, 0.0) if is_landed() else Vector2.ZERO


func conveyor_center_x() -> float:
	if not is_node_ready() or not is_landed():
		return global_position.x
	return _moving_landed_body.global_position.x


func _update_platform_velocity() -> void:
	if not is_node_ready():
		return
	_moving_landed_body.constant_linear_velocity = intended_platform_velocity()


func _move_landed_components(horizontal_delta: float) -> void:
	_moving_landed_body.position.x += horizontal_delta
	_body_visual.position.x += horizontal_delta
	_band_visual.position.x += horizontal_delta
	_label.position.x += horizontal_delta
