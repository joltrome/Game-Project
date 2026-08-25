class_name MotionLocalInstrumentation
extends Node

@export var variant_id: String = "UNSET"
@export var print_events: bool = true

var _conveyor: ConveyorPrototype
var _d3_director: MotionBackgroundDropDirector
var _entries: Array[Dictionary] = []
var _pending_death_cause: String = "unknown"
var _run_ended: bool = false


func _ready() -> void:
	_conveyor = get_parent() as ConveyorPrototype
	if _conveyor == null:
		push_error("MotionLocalInstrumentation requires ConveyorPrototype parent")
		return
	_d3_director = _conveyor.get_node_or_null("BackgroundDropDirector") as MotionBackgroundDropDirector
	_conveyor.telegraph_started.connect(_on_telegraph_started)
	_conveyor.product_dropped.connect(_on_product_dropped)
	_conveyor.conveyor_product_landed.connect(_on_product_landed)
	_conveyor.conveyor_product_cleared.connect(_on_product_cleared)
	_conveyor.sweeper_spawned.connect(_on_sweeper_spawned)
	_conveyor.player_died.connect(_on_player_died)
	var round_controller := _conveyor.get_node_or_null("RoundController") as FixedRoundController
	if round_controller != null:
		round_controller.round_completed.connect(_on_round_completed)
	if _d3_director != null:
		_d3_director.reservation_created.connect(_on_d3_reservation)
		_d3_director.warning_started.connect(_on_d3_warning)
		_d3_director.product_released.connect(_on_d3_release)
		_d3_director.product_landed.connect(_on_d3_landing)
		_d3_director.visual_cycle_reset.connect(_on_d3_reset)
		_d3_director.replacement_rejected.connect(_on_d3_rejection)
	_record("run_start", {
		"player_x": _conveyor.player.position.x,
		"score": _score(),
	})


func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func count_event(event_name: String) -> int:
	var count := 0
	for entry in _entries:
		if entry.event == event_name:
			count += 1
	return count


func _on_telegraph_started(lane_index: int, duration: float) -> void:
	_record("ordinary_warning", {
		"lane_index": lane_index,
		"duration": duration,
		"warning_x": _conveyor.current_warning_x(),
	})


func _on_product_dropped(lane_index: int, fall_speed: float) -> void:
	_record("product_drop", {
		"lane_index": lane_index,
		"fall_speed": fall_speed,
		"falling_product_count": _conveyor.falling_product_count(),
	})
	for product in _conveyor.active_falling_products():
		if not product.player_hit.is_connected(_on_product_player_hit):
			product.player_hit.connect(_on_product_player_hit)


func _on_product_player_hit(_product: FallingProduct) -> void:
	_pending_death_cause = "falling_product"


func _on_product_landed(product: ConveyorProduct) -> void:
	_record("product_landed", {
		"product_x": product.conveyor_center_x(),
		"landed_product_count": _conveyor.landed_product_count(),
	})


func _on_product_cleared(_product: ConveyorProduct) -> void:
	_record("product_cleared", {
		"product_count": _conveyor.active_product_count(),
	})


func _on_sweeper_spawned(sweeper: AirSweeper) -> void:
	if not sweeper.player_hit.is_connected(_on_sweeper_player_hit):
		sweeper.player_hit.connect(_on_sweeper_player_hit)
	_record("carriage_spawn", {
		"carriage_count": _conveyor.active_sweeper_count(),
		"speed": sweeper.travel_speed,
		"altitude": sweeper.fixed_altitude,
	})


func _on_sweeper_player_hit(_sweeper: AirSweeper) -> void:
	_pending_death_cause = "retrieval_carriage"


func _on_player_died() -> void:
	if _run_ended:
		return
	if (
		_pending_death_cause == "unknown"
		and _conveyor.player.position.x < _conveyor.conveyor_support_left_x
	):
		_pending_death_cause = "left_failure"
	_record("run_end", {
		"outcome": "death",
		"death_cause": _pending_death_cause,
		"player_x": _conveyor.player.position.x,
		"remaining_time": _remaining_time(),
		"score": _score(),
		"carriage_count": _conveyor.active_sweeper_count(),
		"product_count": _conveyor.active_product_count(),
	})
	_run_ended = true


func _on_round_completed(score: int) -> void:
	if _run_ended:
		return
	_record("run_end", {
		"outcome": "complete",
		"player_x": _conveyor.player.position.x,
		"remaining_time": 0.0,
		"score": score,
		"carriage_count": _conveyor.active_sweeper_count(),
		"product_count": _conveyor.active_product_count(),
	})
	_run_ended = true


func _on_d3_reservation(schedule_index: int, scheduled_at: float) -> void:
	_record("d3_reservation", {
		"schedule_index": schedule_index,
		"scheduled_at": scheduled_at,
	})


func _on_d3_warning(
	schedule_index: int,
	lane_index: int,
	lane_x: float,
	_started_at: float
) -> void:
	_record("d3_warning", {
		"schedule_index": schedule_index,
		"lane_index": lane_index,
		"lane_x": lane_x,
	})


func _on_d3_release(
	schedule_index: int,
	lane_index: int,
	_product: ConveyorProduct,
	_released_at: float
) -> void:
	_record("d3_release", {
		"schedule_index": schedule_index,
		"lane_index": lane_index,
	})


func _on_d3_landing(
	schedule_index: int,
	lane_index: int,
	_product: ConveyorProduct,
	_landed_at: float
) -> void:
	_record("d3_landing", {
		"schedule_index": schedule_index,
		"lane_index": lane_index,
	})


func _on_d3_reset(schedule_index: int, _reset_at: float) -> void:
	_record("d3_reset", {"schedule_index": schedule_index})


func _on_d3_rejection(schedule_index: int, reason: String, _rejected_at: float) -> void:
	_record("d3_rejection", {
		"schedule_index": schedule_index,
		"reason": reason,
	})


func _remaining_time() -> float:
	var round_controller := _conveyor.get_node_or_null("RoundController") as FixedRoundController
	return round_controller.round_time_remaining if round_controller != null else 0.0


func _score() -> int:
	var director := _conveyor.get_node_or_null("CollectibleDirector") as CollectibleDirector
	return director.score if director != null else 0


func _record(event_name: String, values: Dictionary) -> void:
	var entry := {
		"event": event_name,
		"variant": variant_id,
		"run_time": _conveyor.survival_time if _conveyor != null else 0.0,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	entry.merge(values, true)
	_entries.append(entry)
	if print_events:
		print("MOTION_LOCAL %s" % JSON.stringify(entry))
