class_name ConveyorPrototype
extends Node2D

signal telegraph_started(lane_index: int, duration: float)
signal product_dropped(lane_index: int, fall_speed: float)
signal conveyor_product_landed(product: ConveyorProduct)
signal conveyor_product_cleared(product: ConveyorProduct)
signal pattern_started(pattern_type: int, started_at: float)
signal pattern_event_triggered(pattern_type: int, event_type: int, offset: float)
signal sweeper_entry_cue_started(altitude: float, duration: float)
signal sweeper_spawned(sweeper: AirSweeper)
signal player_died

enum PatternType {
	CAN_ONLY,
	SWEEPER_ONLY,
	SWEEPER_THEN_CAN,
	CAN_THEN_SWEEPER,
}

enum PatternEventType {
	CAN,
	SWEEPER,
}

const BUILD_ID := "VM-0.3.2-B"
const CONVEYOR_PRODUCT_SCENE := preload(
	"res://scenes/hazards/conveyor_product.tscn"
)
const AIR_SWEEPER_SCENE := preload("res://scenes/hazards/air_sweeper.tscn")
const PLAYER_COLLISION_SIZE := Vector2(32.0, 48.0)

@export_category("Conveyor")
@export var conveyor_speed: float = 140.0
@export var belt_left_x: float = 160.0
@export var belt_right_x: float = 1056.0
@export var offscreen_cleanup_x: float = 96.0
@export var conveyor_support_left_x: float = 160.0

@export_category("Player Control Band")
@export var control_band_left: float = 280.0
@export var control_band_right: float = 760.0
@export var left_failure_enabled: bool = true

@export_category("Single Drop Layout")
@export var drop_lane_positions := PackedFloat32Array([880.0, 952.0, 1020.0])
@export var drop_lane_sequence := PackedInt32Array([0, 1, 2, 1])
@export var maximum_concurrent_falling_cans: int = 1
@export var product_spawn_y: float = 176.0
@export var floor_y: float = 584.0
@export var product_size: Vector2 = Vector2(72.0, 72.0)
@export var landed_product_size: Vector2 = Vector2(72.0, 48.0)

@export_category("Timing")
@export var initial_warning_delay: float = 0.85
@export var telegraph_duration: float = 0.45
@export var target_fall_duration: float = 0.55
@export var pattern_cadence: float = 1.80
@export var landed_lifetime: float = 30.0
@export var despawn_warning_duration: float = 0.35

@export_category("Air Sweeper")
@export var sweeper_spawn_x: float = -48.0
@export var sweeper_exit_x: float = 1200.0
@export var sweeper_altitude: float = 460.0
@export var sweeper_speed: float = 520.0
@export var sweeper_size: Vector2 = Vector2(96.0, 28.0)
@export var sweeper_entry_cue_duration: float = 0.20
@export var maximum_active_sweepers: int = 1

@export_category("Controlled Patterns")
@export var pattern_sequence := PackedInt32Array([
	PatternType.CAN_ONLY,
	PatternType.SWEEPER_ONLY,
	PatternType.SWEEPER_THEN_CAN,
	PatternType.CAN_THEN_SWEEPER,
])
@export var sweeper_then_can_offset: float = 1.35
@export var can_then_sweeper_offset: float = 1.60
@export var pattern_retry_delay: float = 0.10
@export var compound_response_margin: float = 0.30

var survival_time: float = 0.0
var is_dead: bool = false

var _pattern_cooldown_remaining: float = 0.0
var _telegraph_remaining: float = 0.0
var _pending_lane_index: int = -1
var _sequence_cursor: int = 0
var _falling_products: Array[ConveyorProduct] = []
var _landed_products: Array[ConveyorProduct] = []
var _chute_product: ConveyorProduct = null
var _active_sweepers: Array[AirSweeper] = []
var _reserved_pattern_type: int = -1
var _active_pattern_type: int = -1
var _active_pattern_elapsed: float = 0.0
var _active_pattern_events: Array[Dictionary] = []
var _pattern_sequence_cursor: int = 0
var _sweeper_spawn_pending: bool = false
var _sweeper_cue_remaining: float = 0.0

@onready var player: SharedPlayerController = $Player
@onready var _hazard_container: Node2D = $Hazards
@onready var _belt_floor: AnimatableBody2D = $ConveyorBelt/Floor
@onready var _belt_stripes: Node2D = $ConveyorBelt/Stripes
@onready var _source_carriage: Node2D = $SourceRack/SourceCarriage
@onready var _source_head: Polygon2D = $SourceRack/SourceCarriage/Head
@onready var _warning_column: Polygon2D = (
	$SourceRack/SourceCarriage/WarningColumn
)
@onready var _warning_text: Label = $SourceRack/SourceCarriage/WarningText
@onready var _sweeper_entry: Node2D = $SweeperEntry
@onready var _sweeper_entry_cue: Polygon2D = $SweeperEntry/ActivationCue
@onready var _timer_label: Label = $HUD/Timer
@onready var _death_label: Label = $HUD/DeathMessage
@onready var _build_label: Label = $HUD/BuildId


func _ready() -> void:
	_pattern_cooldown_remaining = initial_warning_delay
	_apply_conveyor_support_velocity()
	_build_label.text = "BUILD %s" % BUILD_ID
	_update_timer_label()
	_update_source_visuals()
	_sweeper_entry_cue.visible = false


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	survival_time += delta
	_update_timer_label()
	_scroll_belt_presentation(delta)
	_enforce_control_band()
	if is_dead:
		return

	_update_sweeper_entry_cue(delta)
	if _pending_lane_index >= 0:
		_telegraph_remaining = maxf(_telegraph_remaining - delta, 0.0)
		if _telegraph_remaining <= 0.0:
			_drop_pending_product()

	if _active_pattern_type >= 0:
		_update_active_pattern(delta)

	_pattern_cooldown_remaining = maxf(
		_pattern_cooldown_remaining - delta,
		0.0
	)
	if (
		_active_pattern_type < 0
		and _pattern_cooldown_remaining <= 0.0
	):
		_try_start_reserved_pattern()


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


func conveyor_support_velocity() -> Vector2:
	return Vector2(-conveyor_speed, 0.0)


func belt_support_velocity() -> Vector2:
	return _belt_floor.constant_linear_velocity


func maximum_relative_player_speed() -> float:
	return player.maximum_speed


func net_no_input_world_speed() -> float:
	return -conveyor_speed


func net_left_input_world_speed() -> float:
	return -conveyor_speed - player.maximum_speed


func net_right_input_world_speed() -> float:
	return -conveyor_speed + player.maximum_speed


func can_recover_rightward() -> bool:
	return net_right_input_world_speed() > 0.0


func first_warning_time_estimate() -> float:
	return initial_warning_delay


func first_impact_time_estimate() -> float:
	return initial_warning_delay + telegraph_duration + target_fall_duration


func passive_failure_time_estimate(start_x: float = NAN) -> float:
	if conveyor_speed <= 0.0:
		return INF
	var player_start_x := player.position.x if is_nan(start_x) else start_x
	var last_supported_center_x := (
		conveyor_support_left_x + PLAYER_COLLISION_SIZE.x * 0.5
	)
	return (
		maxf(player_start_x - last_supported_center_x, 0.0)
		/ conveyor_speed
	)


func sweeper_collision_band() -> Vector2:
	return Vector2(
		sweeper_altitude - sweeper_size.y * 0.5,
		sweeper_altitude + sweeper_size.y * 0.5
	)


func grounded_player_band_on_belt() -> Vector2:
	return Vector2(
		floor_y - PLAYER_COLLISION_SIZE.y,
		floor_y
	)


func grounded_player_band_on_can() -> Vector2:
	var can_top := floor_y - landed_product_size.y
	return Vector2(
		can_top - PLAYER_COLLISION_SIZE.y,
		can_top
	)


func jump_apex_player_band() -> Vector2:
	var apex_center_y := (
		floor_y
		- PLAYER_COLLISION_SIZE.y * 0.5
		- calculated_jump_height()
	)
	return Vector2(
		apex_center_y - PLAYER_COLLISION_SIZE.y * 0.5,
		apex_center_y + PLAYER_COLLISION_SIZE.y * 0.5
	)


func sweeper_clears_grounded_player() -> bool:
	return (
		sweeper_collision_band().y < grounded_player_band_on_belt().x
		and sweeper_collision_band().y < grounded_player_band_on_can().x
	)


func sweeper_intersects_jump_arc() -> bool:
	var jump_band := Vector2(
		jump_apex_player_band().x,
		grounded_player_band_on_belt().x
	)
	return (
		sweeper_collision_band().y >= jump_band.x
		and sweeper_collision_band().x <= jump_band.y
	)


func sweeper_center_arrival_time() -> float:
	if sweeper_speed <= 0.0:
		return INF
	return (576.0 - sweeper_spawn_x) / sweeper_speed


func normal_jump_duration() -> float:
	if player.gravity <= 0.0:
		return INF
	return 2.0 * absf(player.jump_velocity) / player.gravity


func earliest_can_contact_delay_from_event() -> float:
	if drop_lane_positions.is_empty() or conveyor_speed <= 0.0:
		return INF
	var earliest_lane_x := drop_lane_positions[0]
	for lane_x in drop_lane_positions:
		earliest_lane_x = minf(earliest_lane_x, lane_x)
	var contact_center_x := (
		control_band_right
		+ PLAYER_COLLISION_SIZE.x * 0.5
		+ landed_product_size.x * 0.5
	)
	var conveyor_travel_time := (
		maxf(earliest_lane_x - contact_center_x, 0.0)
		/ conveyor_speed
	)
	return (
		telegraph_duration
		+ target_fall_duration
		+ conveyor_travel_time
	)


func pattern_is_solvable(pattern_type: int) -> bool:
	if pattern_type == PatternType.CAN_ONLY:
		return landed_can_is_jump_clearable()
	if not sweeper_clears_grounded_player() or not sweeper_intersects_jump_arc():
		return false
	match pattern_type:
		PatternType.SWEEPER_ONLY:
			var visible_arrival_time := sweeper_center_arrival_time()
			return (
				visible_arrival_time >= 0.8
				and visible_arrival_time <= 1.2
			)
		PatternType.SWEEPER_THEN_CAN:
			var sweeper_center_time := (
				sweeper_entry_cue_duration + sweeper_center_arrival_time()
			)
			var can_contact_time := (
				sweeper_then_can_offset
				+ earliest_can_contact_delay_from_event()
			)
			return (
				can_contact_time
				>= sweeper_center_time + compound_response_margin
			)
		PatternType.CAN_THEN_SWEEPER:
			var can_contact_time := earliest_can_contact_delay_from_event()
			var sweeper_center_time := (
				can_then_sweeper_offset
				+ sweeper_entry_cue_duration
				+ sweeper_center_arrival_time()
			)
			return (
				sweeper_center_time
				>= can_contact_time
					+ normal_jump_duration()
					+ compound_response_margin
			)
	return false


func active_sweeper_count() -> int:
	return _active_sweepers.size()


func active_sweepers() -> Array[AirSweeper]:
	return _active_sweepers.duplicate()


func sweeper_cue_is_visible() -> bool:
	return _sweeper_entry_cue.visible


func sweeper_cue_altitude() -> float:
	return _sweeper_entry.position.y


func active_pattern_type() -> int:
	return _active_pattern_type


func reserved_pattern_type() -> int:
	return _reserved_pattern_type


func has_pending_pattern_events() -> bool:
	return not _active_pattern_events.is_empty() or _sweeper_spawn_pending


func force_pattern_for_test(pattern_type: int) -> bool:
	if pattern_type < PatternType.CAN_ONLY or pattern_type > PatternType.CAN_THEN_SWEEPER:
		return false
	_reserved_pattern_type = pattern_type
	_pattern_cooldown_remaining = 0.0
	return _try_start_reserved_pattern()


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


func _apply_conveyor_support_velocity() -> void:
	if not is_node_ready():
		return
	_belt_floor.constant_linear_velocity = conveyor_support_velocity()


func _enforce_control_band() -> void:
	var last_supported_center_x := (
		conveyor_support_left_x + PLAYER_COLLISION_SIZE.x * 0.5
	)
	if not left_failure_enabled and player.position.x < last_supported_center_x:
		player.position.x = last_supported_center_x
		player.velocity.x = 0.0
	if player.position.x > control_band_right:
		player.position.x = control_band_right
	if player.position.x >= control_band_right and player.velocity.x > 0.0:
		player.velocity.x = 0.0


func _try_start_reserved_pattern() -> bool:
	if _reserved_pattern_type < 0:
		if pattern_sequence.is_empty():
			return false
		_reserved_pattern_type = pattern_sequence[
			_pattern_sequence_cursor % pattern_sequence.size()
		]

	if not _pattern_can_start(_reserved_pattern_type):
		_pattern_cooldown_remaining = pattern_retry_delay
		return false

	_active_pattern_type = _reserved_pattern_type
	_reserved_pattern_type = -1
	_active_pattern_elapsed = 0.0
	_active_pattern_events = _events_for_pattern(_active_pattern_type)
	_pattern_sequence_cursor = (
		(_pattern_sequence_cursor + 1)
		% maxi(pattern_sequence.size(), 1)
	)
	_pattern_cooldown_remaining = pattern_cadence
	pattern_started.emit(_active_pattern_type, survival_time)
	_trigger_due_pattern_events()
	return true


func _pattern_can_start(pattern_type: int) -> bool:
	if not pattern_is_solvable(pattern_type):
		return false
	var includes_can := (
		pattern_type == PatternType.CAN_ONLY
		or pattern_type == PatternType.SWEEPER_THEN_CAN
		or pattern_type == PatternType.CAN_THEN_SWEEPER
	)
	var includes_sweeper := pattern_type != PatternType.CAN_ONLY
	if (
		includes_can
		and (
			_pending_lane_index >= 0
			or _falling_products.size() >= maximum_concurrent_falling_cans
		)
	):
		return false
	if (
		includes_sweeper
		and (
			_active_sweepers.size() >= maximum_active_sweepers
			or _sweeper_spawn_pending
		)
	):
		return false
	return true


func _events_for_pattern(pattern_type: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	match pattern_type:
		PatternType.CAN_ONLY:
			events.append(_pattern_event(PatternEventType.CAN, 0.0))
		PatternType.SWEEPER_ONLY:
			events.append(_pattern_event(PatternEventType.SWEEPER, 0.0))
		PatternType.SWEEPER_THEN_CAN:
			events.append(_pattern_event(PatternEventType.SWEEPER, 0.0))
			events.append(_pattern_event(
				PatternEventType.CAN,
				sweeper_then_can_offset
			))
		PatternType.CAN_THEN_SWEEPER:
			events.append(_pattern_event(PatternEventType.CAN, 0.0))
			events.append(_pattern_event(
				PatternEventType.SWEEPER,
				can_then_sweeper_offset
			))
	return events


func _pattern_event(event_type: int, offset: float) -> Dictionary:
	return {
		"event_type": event_type,
		"offset": maxf(offset, 0.0),
		"triggered": false,
	}


func _update_active_pattern(delta: float) -> void:
	_active_pattern_elapsed += delta
	_trigger_due_pattern_events()


func _trigger_due_pattern_events() -> void:
	for event in _active_pattern_events:
		if event.triggered or event.offset > _active_pattern_elapsed:
			continue
		var triggered := false
		if event.event_type == PatternEventType.CAN:
			triggered = (
				_pending_lane_index < 0
				and _falling_products.size() < maximum_concurrent_falling_cans
				and _start_next_telegraph()
			)
		elif event.event_type == PatternEventType.SWEEPER:
			triggered = _start_sweeper_entry_cue()
		if not triggered:
			continue
		event.triggered = true
		pattern_event_triggered.emit(
			_active_pattern_type,
			event.event_type,
			event.offset
		)

	for event in _active_pattern_events:
		if not event.triggered:
			return
	_active_pattern_events.clear()
	_active_pattern_type = -1
	_active_pattern_elapsed = 0.0


func _start_sweeper_entry_cue() -> bool:
	if (
		_sweeper_spawn_pending
		or _active_sweepers.size() >= maximum_active_sweepers
	):
		return false
	_sweeper_spawn_pending = true
	_sweeper_cue_remaining = sweeper_entry_cue_duration
	_sweeper_entry.position.y = sweeper_altitude
	_sweeper_entry_cue.visible = true
	sweeper_entry_cue_started.emit(
		sweeper_altitude,
		sweeper_entry_cue_duration
	)
	if _sweeper_cue_remaining <= 0.0:
		_spawn_sweeper()
	return true


func _update_sweeper_entry_cue(delta: float) -> void:
	if not _sweeper_spawn_pending:
		return
	_sweeper_cue_remaining = maxf(_sweeper_cue_remaining - delta, 0.0)
	if _sweeper_cue_remaining <= 0.0:
		_spawn_sweeper()


func _spawn_sweeper() -> AirSweeper:
	if not _sweeper_spawn_pending:
		return null
	_sweeper_spawn_pending = false
	_sweeper_cue_remaining = 0.0
	_sweeper_entry_cue.visible = false
	var sweeper := AIR_SWEEPER_SCENE.instantiate() as AirSweeper
	sweeper.position = Vector2(sweeper_spawn_x, sweeper_altitude)
	sweeper.configure(
		sweeper_speed,
		sweeper_altitude,
		sweeper_size,
		sweeper_exit_x
	)
	sweeper.player_hit.connect(_on_sweeper_hit)
	sweeper.cleared.connect(_on_sweeper_cleared)
	_hazard_container.add_child(sweeper)
	_active_sweepers.append(sweeper)
	sweeper_spawned.emit(sweeper)
	return sweeper


func _start_next_telegraph() -> bool:
	if drop_lane_positions.is_empty():
		return false
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
		return false
	_pending_lane_index = selected_lane
	_telegraph_remaining = telegraph_duration
	_show_warning()
	telegraph_started.emit(_pending_lane_index, telegraph_duration)
	return true


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


func _on_sweeper_hit(_sweeper: AirSweeper) -> void:
	if is_dead:
		return
	_kill_player()


func _on_sweeper_cleared(sweeper: AirSweeper) -> void:
	_active_sweepers.erase(sweeper)


func _on_off_belt_kill_region_body_entered(body: Node2D) -> void:
	if not left_failure_enabled or is_dead or body != player:
		return
	_kill_player()


func _kill_player() -> void:
	if is_dead:
		return
	is_dead = true
	player.set_physics_process(false)
	_belt_floor.constant_linear_velocity = Vector2.ZERO
	_clear_warning_state()
	for product in _falling_products:
		if is_instance_valid(product):
			product.stop()
	for product in _landed_products:
		if is_instance_valid(product):
			product.stop()
	for sweeper in _active_sweepers:
		if is_instance_valid(sweeper):
			sweeper.stop()
	_clear_pattern_state()
	_death_label.visible = true
	player_died.emit()


func _clear_warning_state() -> void:
	_pending_lane_index = -1
	_telegraph_remaining = 0.0
	_chute_product = null
	_update_source_visuals()


func _clear_pattern_state() -> void:
	_reserved_pattern_type = -1
	_active_pattern_type = -1
	_active_pattern_elapsed = 0.0
	_active_pattern_events.clear()
	_pattern_cooldown_remaining = 0.0
	_sweeper_spawn_pending = false
	_sweeper_cue_remaining = 0.0
	_sweeper_entry_cue.visible = false


func _update_timer_label() -> void:
	_timer_label.text = "SURVIVAL  %05.2f s" % survival_time
