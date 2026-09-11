class_name SharedPlayerController
extends CharacterBody2D

signal jump_accepted
signal landed

@export_category("Horizontal Movement")
@export var maximum_speed: float = 300.0
@export var air_acceleration: float = 1400.0

@export_category("Vertical Movement")
@export var gravity: float = 2400.0
@export var jump_velocity: float = -700.0
@export var coyote_time: float = 0.10
@export var jump_buffering: float = 0.12

var _coyote_time_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _ground_state_initialized: bool = false
var _previous_grounded: bool = false


func _physics_process(delta: float) -> void:
	_update_jump_windows(delta)
	_apply_horizontal_movement(delta)
	_apply_gravity(delta)
	var accepted_jump := _try_to_jump()
	move_and_slide()
	var grounded := is_on_floor()
	if accepted_jump:
		jump_accepted.emit()
	if _ground_state_initialized and grounded and not _previous_grounded:
		landed.emit()
	_previous_grounded = grounded
	_ground_state_initialized = true


func _update_jump_windows(delta: float) -> void:
	if is_on_floor():
		_coyote_time_remaining = coyote_time
	else:
		_coyote_time_remaining = maxf(_coyote_time_remaining - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_remaining = jump_buffering
	else:
		_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)


func _apply_horizontal_movement(delta: float) -> void:
	var input_direction := Input.get_axis("move_left", "move_right")
	var target_velocity := input_direction * maximum_speed

	if is_on_floor():
		velocity.x = target_velocity
	elif not is_zero_approx(input_direction):
		velocity.x = move_toward(velocity.x, target_velocity, air_acceleration * delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func _try_to_jump() -> bool:
	var jump_is_available := is_on_floor() or _coyote_time_remaining > 0.0
	if _jump_buffer_remaining <= 0.0 or not jump_is_available:
		return false

	velocity.y = jump_velocity
	_coyote_time_remaining = 0.0
	_jump_buffer_remaining = 0.0
	return true
