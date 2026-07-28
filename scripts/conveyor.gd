class_name ConveyorPrototype
extends Node2D

signal telegraph_started(lane_index: int, duration: float)
signal product_dropped(lane_index: int, fall_speed: float)
signal conveyor_product_landed(product: ConveyorProduct)
signal conveyor_product_cleared(product: ConveyorProduct)
signal player_died

const BUILD_ID := "VM-0.3.0-B"
const CONVEYOR_PRODUCT_SCENE := preload(
	"res://scenes/hazards/conveyor_product.tscn"
)
const PLAYER_COLLISION_WIDTH := 32.0

@export_category("Conveyor")
@export var conveyor_speed: float = 140.0
@export var belt_left_x: float = 96.0
@export var belt_right_x: float = 1056.0
@export var offscreen_cleanup_x: float = 96.0

@export_category("Player Control Band")
@export var control_band_left: float = 280.0
@export var control_band_right: float = 760.0
@export var left_failure_enabled: bool = true
@export var left_failure_x: float = 232.0

@export_category("Single Drop Layout")
@export var drop_lane_positions := PackedFloat32Array([880.0, 952.0, 1020.0])
@export var drop_lane_sequence := PackedInt32Array([0, 1, 2, 1])
@export var maximum_concurrent_falling_cans: int = 1
@export var product_spawn_y: float = 176.0
@export var floor_y: float = 584.0
@export var product_size: Vector2 = Vector2(72.0, 72.0)
@export var landed_product_size: Vector2 = Vector2(72.0, 48.0)

@export_category("Timing")
@export var initial_drop_delay: float = 6.5
@export var telegraph_duration: float = 0.65
@export var target_fall_duration: float = 0.65
@export var spawn_interval: float = 1.80
@export var landed_lifetime: float = 30.0
@export var despawn_warning_duration: float = 0.35

var survival_time: float = 0.0
var is_dead: bool = false

var _cooldown_remaining: float = 0.0
var _telegraph_remaining: float = 0.0
var _pending_lane_index: int = -1
var _sequence_cursor: int = 0
var _falling_products: Array[ConveyorProduct] = []
var _landed_products: Array[ConveyorProduct] = []
var _chute_product: ConveyorProduct = null

@onready var player: SharedPlayerController = $Player
@onready var _hazard_container: Node2D = $Hazards
@onready var _belt_stripes: Node2D = $ConveyorBelt/Stripes
@onready var _source_carriage: Node2D = $SourceRack/SourceCarriage
@onready var _source_head: Polygon2D = $SourceRack/SourceCarriage/Head
@onready var _warning_column: Polygon2D = (
	$SourceRack/SourceCarriage/WarningColumn
)
@onready var _warning_text: Label = $SourceRack/SourceCarriage/WarningText
@onready var _timer_label: Label = $HUD/Timer
@onready var _death_label: Label = $HUD/DeathMessage
@onready var _build_label: Label = $HUD/BuildId


func _ready() -> void:
	_cooldown_remaining = initial_drop_delay
	_build_label.text = "BUILD %s" % BUILD_ID
	_update_timer_label()
	_update_source_visuals()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	survival_time += delta
	_update_timer_label()
	_scroll_belt_presentation(delta)
	_enforce_control_band()
	if is_dead:
		return

	if _pending_lane_index >= 0:
		_telegraph_remaining = maxf(_telegraph_remaining - delta, 0.0)
		if _telegraph_remaining <= 0.0:
			_drop_pending_product()

	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if (
		_pending_lane_index < 0
		and _cooldown_remaining <= 0.0
		and _falling_products.size() < maximum_concurrent_falling_cans
	):
		_start_next_telegraph()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func fall_distance() -> float:
	return maxf(
		floor_y - product_size.y * 0.5 - product_spawn_y,
		0.0
	)


func fall_speed() -> float:
	if target_fall_duration <= 0.0:
		return INF
	return fall_distance() / target_fall_duration


func current_warning_lane() -> int:
	return _pending_lane_index


func warning_is_visible() -> bool:
	return _pending_lane_index >= 0 and _warning_column.visible


func warning_is_aligned() -> bool:
	if _pending_lane_index < 0:
		return false
	return is_equal_approx(
		_source_carriage.position.x,
		drop_lane_positions[_pending_lane_index]
	)


func chute_is_visible() -> bool:
	return _source_carriage.visible


func chute_is_aligned_with_active_drop() -> bool:
	if not is_instance_valid(_chute_product):
		return false
	return is_equal_approx(
		_source_carriage.position.x,
		_chute_product.position.x
	)


func falling_product_count() -> int:
	return _falling_products.size()


func landed_product_count() -> int:
	return _landed_products.size()


func active_product_count() -> int:
	return falling_product_count() + landed_product_count()


func active_falling_products() -> Array[ConveyorProduct]:
	return _falling_products.duplicate()


func active_landed_products() -> Array[ConveyorProduct]:
	return _landed_products.duplicate()


func is_player_inside_control_band() -> bool:
	return (
		player.position.x >= control_band_left - 0.01
		and player.position.x <= control_band_right + 0.01
	)


func calculated_jump_height() -> float:
	if player.gravity <= 0.0:
		return INF
	return player.jump_velocity * player.jump_velocity / (2.0 * player.gravity)


func landed_can_is_jump_clearable() -> bool:
	return landed_product_size.y < calculated_jump_height()


func drop_lane_is_geometrically_valid(lane_index: int) -> bool:
	if lane_index < 0 or lane_index >= drop_lane_positions.size():
		return false
	var lane_x := drop_lane_positions[lane_index]
	return (
		lane_x - product_size.x * 0.5 >= belt_left_x
		and lane_x + product_size.x * 0.5 <= belt_right_x
		and lane_x - product_size.x * 0.5 > control_band_right
	)


func stationary_first_contact_estimate() -> float:
	if drop_lane_positions.is_empty() or conveyor_speed <= 0.0:
		return INF
	var first_sequence_value := (
		drop_lane_sequence[0] if not drop_lane_sequence.is_empty() else 0
	)
	var lane_index := posmod(first_sequence_value, drop_lane_positions.size())
	var collision_distance := (
		product_size.x + PLAYER_COLLISION_WIDTH
	) * 0.5
	var travel_distance := maxf(
		drop_lane_positions[lane_index] - player.position.x - collision_distance,
		0.0
	)
	return (
		initial_drop_delay
		+ telegraph_duration
		+ target_fall_duration
		+ travel_distance / conveyor_speed
	)


func force_warning_for_test(lane_index: int) -> void:
	if lane_index < 0 or lane_index >= drop_lane_positions.size():
		return
	_pending_lane_index = lane_index
	_telegraph_remaining = telegraph_duration
	_show_warning()


func force_drop_for_test(lane_index: int) -> ConveyorProduct:
	if lane_index < 0 or lane_index >= drop_lane_positions.size():
		return null
	_pending_lane_index = lane_index
	_telegraph_remaining = 0.0
	return _drop_pending_product()


func _scroll_belt_presentation(delta: float) -> void:
	var belt_width := belt_right_x - belt_left_x
	if belt_width <= 0.0:
		return
	for stripe in _belt_stripes.get_children():
		if not stripe is Node2D:
			continue
		stripe.position.x -= conveyor_speed * delta
		while stripe.position.x < belt_left_x:
			stripe.position.x += belt_width


func _enforce_control_band() -> void:
	if left_failure_enabled and player.position.x < left_failure_x:
		_kill_player()
		return
	player.position.x = clampf(
		player.position.x,
		control_band_left,
		control_band_right
	)
	if (
		player.position.x <= control_band_left
		and player.velocity.x < 0.0
	):
		player.velocity.x = 0.0
	elif (
		player.position.x >= control_band_right
		and player.velocity.x > 0.0
	):
		player.velocity.x = 0.0


func _start_next_telegraph() -> void:
	if drop_lane_positions.is_empty():
		return
	var selected_lane := -1
	for offset in range(maxi(drop_lane_sequence.size(), drop_lane_positions.size())):
		var sequence_value := (
			drop_lane_sequence[
				(_sequence_cursor + offset) % drop_lane_sequence.size()
			]
			if not drop_lane_sequence.is_empty()
			else _sequence_cursor + offset
		)
		var lane_index := posmod(sequence_value, drop_lane_positions.size())
		if drop_lane_is_geometrically_valid(lane_index):
			selected_lane = lane_index
			_sequence_cursor += offset + 1
			break
	if selected_lane < 0:
		_cooldown_remaining = 0.10
		return
	_pending_lane_index = selected_lane
	_telegraph_remaining = telegraph_duration
	_show_warning()
	telegraph_started.emit(_pending_lane_index, telegraph_duration)


func _show_warning() -> void:
	_source_carriage.position.x = drop_lane_positions[_pending_lane_index]
	_source_carriage.visible = true
	_warning_column.visible = true
	_warning_text.visible = true
	_source_head.color = Color(0.92, 0.24, 0.20, 1.0)


func _drop_pending_product() -> ConveyorProduct:
	if _pending_lane_index < 0:
		return null
	var lane_index := _pending_lane_index
	var product := CONVEYOR_PRODUCT_SCENE.instantiate() as ConveyorProduct
	product.position = Vector2(drop_lane_positions[lane_index], product_spawn_y)
	product.configure_conveyor(
		fall_speed(),
		floor_y,
		landed_lifetime,
		despawn_warning_duration,
		product_size,
		landed_product_size,
		conveyor_speed,
		offscreen_cleanup_x
	)
	product.player_hit.connect(_on_product_hit)
	product.landed.connect(_on_product_landed)
	product.cleared.connect(_on_product_cleared)
	_hazard_container.add_child(product)
	_falling_products.append(product)
	_chute_product = product
	_pending_lane_index = -1
	_telegraph_remaining = 0.0
	_cooldown_remaining = spawn_interval
	_update_source_visuals()
	product_dropped.emit(lane_index, product.fall_speed)
	return product


func _update_source_visuals() -> void:
	var falling_visible := (
		is_instance_valid(_chute_product)
		and _chute_product.is_falling()
	)
	var warning_visible := _pending_lane_index >= 0
	_source_carriage.visible = warning_visible or falling_visible
	_warning_column.visible = warning_visible
	_warning_text.visible = warning_visible
	_source_head.color = (
		Color(0.92, 0.24, 0.20, 1.0)
		if warning_visible
		else Color(0.36, 0.72, 0.86, 1.0)
			if falling_visible
			else Color(0.30, 0.34, 0.40, 1.0)
	)


func _on_product_hit(product: FallingProduct) -> void:
	if is_dead or not product.is_falling_lethal():
		return
	_kill_player()


func _on_product_landed(product: FallingProduct) -> void:
	if not product is ConveyorProduct:
		return
	var conveyor_product := product as ConveyorProduct
	_falling_products.erase(conveyor_product)
	if not _landed_products.has(conveyor_product):
		_landed_products.append(conveyor_product)
	if _chute_product == conveyor_product:
		_chute_product = null
	_update_source_visuals()
	conveyor_product_landed.emit(conveyor_product)


func _on_product_cleared(product: FallingProduct) -> void:
	if not product is ConveyorProduct:
		return
	var conveyor_product := product as ConveyorProduct
	_falling_products.erase(conveyor_product)
	_landed_products.erase(conveyor_product)
	if _chute_product == conveyor_product:
		_chute_product = null
	_update_source_visuals()
	conveyor_product_cleared.emit(conveyor_product)


func _on_left_failure_body_entered(body: Node2D) -> void:
	if left_failure_enabled and body == player:
		_kill_player()


func _kill_player() -> void:
	if is_dead:
		return
	is_dead = true
	player.set_physics_process(false)
	_clear_warning_state()
	for product in _falling_products:
		if is_instance_valid(product):
			product.stop()
	for product in _landed_products:
		if is_instance_valid(product):
			product.stop()
	_death_label.visible = true
	player_died.emit()


func _clear_warning_state() -> void:
	_pending_lane_index = -1
	_telegraph_remaining = 0.0
	_chute_product = null
	_update_source_visuals()


func _update_timer_label() -> void:
	_timer_label.text = "SURVIVAL  %05.2f s" % survival_time
