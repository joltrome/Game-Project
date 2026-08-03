class_name FixedRoundController
extends Node

signal round_completed(score: int)
signal round_ended_by_death(score: int, time_remaining: float)

enum RoundState {
	RUNNING,
	DEAD,
	COMPLETE,
}

@export var fixed_round_enabled: bool = true
@export var round_duration: float = 60.0

var round_time_remaining: float = 60.0
var round_state: RoundState = RoundState.RUNNING
var completion_count: int = 0

@onready var _conveyor: ConveyorPrototype = get_parent() as ConveyorPrototype
@onready var _collectibles: CollectibleDirector = (
	_conveyor.get_node("CollectibleDirector") as CollectibleDirector
)
@onready var _timer_label: Label = _conveyor.get_node("HUD/Timer")
@onready var _result_label: Label = _conveyor.get_node("HUD/DeathMessage")


func _ready() -> void:
	round_time_remaining = maxf(round_duration, 0.0)
	_conveyor.external_timer_display_enabled = fixed_round_enabled
	_conveyor.player_died.connect(_on_player_died)
	if fixed_round_enabled:
		_update_timer_label()
	else:
		set_process(false)


func _process(delta: float) -> void:
	if not fixed_round_enabled or round_state != RoundState.RUNNING:
		return
	round_time_remaining = maxf(round_time_remaining - delta, 0.0)
	_update_timer_label()
	if round_time_remaining <= 0.0:
		_complete_round()


func is_running() -> bool:
	return round_state == RoundState.RUNNING


func is_complete() -> bool:
	return round_state == RoundState.COMPLETE


func ended_by_death() -> bool:
	return round_state == RoundState.DEAD


func force_time_remaining_for_test(value: float) -> void:
	round_time_remaining = clampf(value, 0.0, maxf(round_duration, 0.0))
	_update_timer_label()


func _complete_round() -> void:
	if round_state != RoundState.RUNNING:
		return
	round_state = RoundState.COMPLETE
	round_time_remaining = 0.0
	completion_count += 1
	_conveyor.stop_for_round_completion()
	_collectibles.stop_for_round_end()
	_update_timer_label()
	_result_label.text = (
		"MACHINE SHUTDOWN\nCOINS COLLECTED: %d\nPRESS R TO RESTART"
		% _collectibles.score
	)
	_result_label.visible = true
	round_completed.emit(_collectibles.score)


func _on_player_died() -> void:
	if round_state != RoundState.RUNNING:
		return
	round_state = RoundState.DEAD
	_update_timer_label()
	_result_label.text = (
		"MACHINE FAILURE\nCOINS COLLECTED: %d\nSHUTDOWN: %.1f\nPRESS R TO RESTART"
		% [_collectibles.score, round_time_remaining]
	)
	_result_label.visible = true
	round_ended_by_death.emit(
		_collectibles.score,
		round_time_remaining
	)


func _update_timer_label() -> void:
	if not fixed_round_enabled:
		return
	_timer_label.text = "SHUTDOWN: %02d" % ceili(round_time_remaining)
