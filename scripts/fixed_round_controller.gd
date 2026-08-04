class_name FixedRoundController
extends Node

signal round_completed(score: int)
signal round_ended_by_death(score: int, time_remaining: float)

enum RoundState {
	RUNNING,
	DEAD,
	COMPLETE,
}

enum CountdownUrgency {
	NORMAL,
	MILD,
	URGENT,
	FINAL,
}

@export var fixed_round_enabled: bool = true
@export var round_duration: float = 60.0

@export_category("Countdown Readability")
@export var mild_urgency_threshold: float = 30.0
@export var urgent_urgency_threshold: float = 15.0
@export var final_urgency_threshold: float = 5.0
@export var final_second_pulse_start: int = 10
@export var pulse_duration: float = 0.24
@export var threshold_pulse_scale: float = 1.10
@export var final_pulse_scale: float = 1.16
@export var normal_color := Color(0.95, 0.97, 1.0, 1.0)
@export var mild_color := Color(1.0, 0.84, 0.30, 1.0)
@export var urgent_color := Color(1.0, 0.52, 0.16, 1.0)
@export var final_color := Color(1.0, 0.25, 0.20, 1.0)

var round_time_remaining: float = 60.0
var round_state: RoundState = RoundState.RUNNING
var completion_count: int = 0
var _countdown_urgency: CountdownUrgency = CountdownUrgency.NORMAL
var _urgency_entry_counts := PackedInt32Array([0, 0, 0, 0])
var _threshold_pulse_count: int = 0
var _mild_threshold_pulsed: bool = false
var _urgent_threshold_pulsed: bool = false
var _final_second_pulse_count: int = 0
var _last_final_pulse_second: int = -1
var _pulse_time_remaining: float = 0.0
var _pulse_target_scale: float = 1.0

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
		_reset_countdown_visuals()
		_update_timer_label(false, round_time_remaining)
	else:
		set_process(false)


func _process(delta: float) -> void:
	if not fixed_round_enabled or round_state != RoundState.RUNNING:
		return
	var previous_time := round_time_remaining
	round_time_remaining = maxf(round_time_remaining - delta, 0.0)
	_update_timer_label(true, previous_time)
	if round_time_remaining <= 0.0:
		_complete_round()
		return
	_update_pulse(delta)


func is_running() -> bool:
	return round_state == RoundState.RUNNING


func is_complete() -> bool:
	return round_state == RoundState.COMPLETE


func ended_by_death() -> bool:
	return round_state == RoundState.DEAD


func force_time_remaining_for_test(value: float) -> void:
	var previous_time := round_time_remaining
	round_time_remaining = clampf(value, 0.0, maxf(round_duration, 0.0))
	_update_timer_label(true, previous_time)


func countdown_urgency_state() -> CountdownUrgency:
	return _countdown_urgency


func urgency_entry_count(state: CountdownUrgency) -> int:
	if state < 0 or state >= _urgency_entry_counts.size():
		return 0
	return _urgency_entry_counts[state]


func threshold_pulse_count() -> int:
	return _threshold_pulse_count


func final_second_pulse_count() -> int:
	return _final_second_pulse_count


func countdown_pulse_is_active() -> bool:
	return _pulse_time_remaining > 0.0


func countdown_pulse_target_scale() -> float:
	return _pulse_target_scale


func _complete_round() -> void:
	if round_state != RoundState.RUNNING:
		return
	round_state = RoundState.COMPLETE
	round_time_remaining = 0.0
	completion_count += 1
	_conveyor.stop_for_round_completion()
	_collectibles.stop_for_round_end()
	_update_timer_label(false, round_time_remaining)
	_cancel_pulse()
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
	_update_timer_label(false, round_time_remaining)
	_cancel_pulse()
	_result_label.text = (
		"MACHINE FAILURE\nCOINS COLLECTED: %d\nSHUTDOWN: %.1f\nPRESS R TO RESTART"
		% [_collectibles.score, round_time_remaining]
	)
	_result_label.visible = true
	round_ended_by_death.emit(
		_collectibles.score,
		round_time_remaining
	)


func _update_timer_label(
	trigger_events: bool = true,
	previous_time: float = INF
) -> void:
	if not fixed_round_enabled:
		return
	var displayed_seconds := ceili(round_time_remaining)
	_timer_label.text = "00:%02d" % displayed_seconds
	_update_urgency_state()
	if trigger_events and round_time_remaining < previous_time:
		_update_pulse_events(previous_time, displayed_seconds)


func _reset_countdown_visuals() -> void:
	_countdown_urgency = CountdownUrgency.NORMAL
	_urgency_entry_counts = PackedInt32Array([1, 0, 0, 0])
	_threshold_pulse_count = 0
	_mild_threshold_pulsed = false
	_urgent_threshold_pulsed = false
	_final_second_pulse_count = 0
	_last_final_pulse_second = -1
	_timer_label.pivot_offset = _timer_label.size * 0.5
	_apply_urgency_color()
	_cancel_pulse()


func _update_urgency_state() -> void:
	var next_state := CountdownUrgency.NORMAL
	if round_time_remaining <= final_urgency_threshold:
		next_state = CountdownUrgency.FINAL
	elif round_time_remaining <= urgent_urgency_threshold:
		next_state = CountdownUrgency.URGENT
	elif round_time_remaining <= mild_urgency_threshold:
		next_state = CountdownUrgency.MILD
	if next_state == _countdown_urgency:
		return
	_countdown_urgency = next_state
	if _urgency_entry_counts[next_state] == 0:
		_urgency_entry_counts[next_state] = 1
	_apply_urgency_color()


func _apply_urgency_color() -> void:
	match _countdown_urgency:
		CountdownUrgency.MILD:
			_timer_label.add_theme_color_override("font_color", mild_color)
		CountdownUrgency.URGENT:
			_timer_label.add_theme_color_override("font_color", urgent_color)
		CountdownUrgency.FINAL:
			_timer_label.add_theme_color_override("font_color", final_color)
		_:
			_timer_label.add_theme_color_override("font_color", normal_color)


func _update_pulse_events(
	previous_time: float,
	displayed_seconds: int
) -> void:
	if (
		not _mild_threshold_pulsed
		and previous_time > mild_urgency_threshold
		and round_time_remaining <= mild_urgency_threshold
	):
		_mild_threshold_pulsed = true
		_threshold_pulse_count += 1
		_start_pulse(threshold_pulse_scale)
	if (
		not _urgent_threshold_pulsed
		and previous_time > urgent_urgency_threshold
		and round_time_remaining <= urgent_urgency_threshold
	):
		_urgent_threshold_pulsed = true
		_threshold_pulse_count += 1
		_start_pulse(threshold_pulse_scale)
	if (
		displayed_seconds >= 1
		and displayed_seconds <= final_second_pulse_start
		and displayed_seconds != _last_final_pulse_second
	):
		_last_final_pulse_second = displayed_seconds
		_final_second_pulse_count += 1
		_start_pulse(
			final_pulse_scale
			if displayed_seconds <= ceili(final_urgency_threshold)
			else threshold_pulse_scale
		)


func _start_pulse(target_scale: float) -> void:
	_pulse_time_remaining = maxf(pulse_duration, 0.0)
	_pulse_target_scale = maxf(target_scale, 1.0)
	_timer_label.pivot_offset = _timer_label.size * 0.5


func _update_pulse(delta: float) -> void:
	if _pulse_time_remaining <= 0.0 or pulse_duration <= 0.0:
		_cancel_pulse()
		return
	_pulse_time_remaining = maxf(_pulse_time_remaining - delta, 0.0)
	var progress := 1.0 - (_pulse_time_remaining / pulse_duration)
	var pulse_wave := sin(clampf(progress, 0.0, 1.0) * PI)
	var visual_scale := lerpf(1.0, _pulse_target_scale, pulse_wave)
	_timer_label.scale = Vector2.ONE * visual_scale
	if _pulse_time_remaining <= 0.0:
		_cancel_pulse()


func _cancel_pulse() -> void:
	_pulse_time_remaining = 0.0
	_pulse_target_scale = 1.0
	_timer_label.scale = Vector2.ONE
	_timer_label.modulate = Color.WHITE
