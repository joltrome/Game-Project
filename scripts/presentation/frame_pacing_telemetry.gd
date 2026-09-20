class_name FramePacingTelemetry
extends RefCounted

const SLOW_FRAME_THRESHOLD_MS := 33.33

var enabled: bool = false
var _samples_ms := PackedFloat32Array()
var _process_samples_ms := PackedFloat32Array()
var _physics_samples_ms := PackedFloat32Array()
var _planning_events: Array[Dictionary] = []
var _observed_planning_event_count: int = 0
var _frame_index: int = 0
var _planning_correlated_slow_frames: int = 0
var _d3_correlated_slow_frames: int = 0
var _support_correlated_slow_frames: int = 0
var _recent_planning_frame: int = -1000
var _recent_d3_event_count: int = 0
var _recent_support_entries: int = 0
var _finished: bool = false


func begin_run(active: bool) -> void:
	enabled = active
	_samples_ms.clear()
	_process_samples_ms.clear()
	_physics_samples_ms.clear()
	_planning_events.clear()
	_observed_planning_event_count = 0
	_frame_index = 0
	_planning_correlated_slow_frames = 0
	_d3_correlated_slow_frames = 0
	_support_correlated_slow_frames = 0
	_recent_planning_frame = -1000
	_recent_d3_event_count = 0
	_recent_support_entries = 0
	_finished = false


func record_frame(delta: float, game: MotionExperimentShell) -> void:
	if not enabled or _finished or not is_instance_valid(game):
		return
	_frame_index += 1
	var frame_ms := maxf(delta, 0.0) * 1000.0
	_samples_ms.append(frame_ms)
	_process_samples_ms.append(
		float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	)
	_physics_samples_ms.append(
		float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	)
	var director := game.conveyor.get_node_or_null("CollectibleDirector") as CollectibleDirector
	if director == null:
		return
	var event_count := director.performance_event_count()
	if event_count > _observed_planning_event_count:
		for index in range(_observed_planning_event_count, event_count):
			var event := director.performance_event_at(index)
			event.observed_frame = _frame_index
			_planning_events.append(event)
		_observed_planning_event_count = event_count
		_recent_planning_frame = _frame_index
	var d3_count := 0
	if is_instance_valid(game.background_drop_director):
		d3_count = game.background_drop_director.released_event_count()
	var support_entries := director.ballistic_support_entry_count()
	if frame_ms > SLOW_FRAME_THRESHOLD_MS:
		if _frame_index - _recent_planning_frame <= 1:
			_planning_correlated_slow_frames += 1
		if d3_count > _recent_d3_event_count:
			_d3_correlated_slow_frames += 1
		if support_entries > _recent_support_entries:
			_support_correlated_slow_frames += 1
	_recent_d3_event_count = d3_count
	_recent_support_entries = support_entries


func finish_run(reason: String) -> Dictionary:
	if not enabled or _finished:
		return {}
	_finished = true
	var result := summary()
	result.reason = reason
	print("VM071_FRAME_SUMMARY ", JSON.stringify(result))
	return result


func summary() -> Dictionary:
	var ordered := Array(_samples_ms)
	ordered.sort()
	var planning_maximum := 0.0
	var planning_average := 0.0
	var planning_total := 0.0
	var planning_over_8 := 0
	var planning_over_16 := 0
	var planning_over_33 := 0
	var planning_over_50 := 0
	for event in _planning_events:
		var duration := float(event.get("planning_ms", 0.0))
		planning_total += duration
		planning_maximum = maxf(planning_maximum, duration)
		if duration > 8.0:
			planning_over_8 += 1
		if duration > 16.67:
			planning_over_16 += 1
		if duration > 33.33:
			planning_over_33 += 1
		if duration > 50.0:
			planning_over_50 += 1
	if not _planning_events.is_empty():
		planning_average = planning_total / float(_planning_events.size())
	return {
		"frames": _samples_ms.size(),
		"median_ms": _percentile(ordered, 0.50),
		"p95_ms": _percentile(ordered, 0.95),
		"p99_ms": _percentile(ordered, 0.99),
		"worst_ms": _percentile(ordered, 1.0),
		"frames_over_16_67_ms": _count_over(_samples_ms, 16.67),
		"frames_over_25_ms": _count_over(_samples_ms, 25.0),
		"frames_over_33_33_ms": _count_over(_samples_ms, 33.33),
		"frames_over_50_ms": _count_over(_samples_ms, 50.0),
		"average_process_ms": _average(_process_samples_ms),
		"maximum_process_ms": _maximum(_process_samples_ms),
		"average_physics_ms": _average(_physics_samples_ms),
		"maximum_physics_ms": _maximum(_physics_samples_ms),
		"approximate_fps": float(Performance.get_monitor(Performance.TIME_FPS)),
		"planning_events": _planning_events.size(),
		"planning_average_ms": planning_average,
		"planning_maximum_ms": planning_maximum,
		"planning_over_8_ms": planning_over_8,
		"planning_over_16_67_ms": planning_over_16,
		"planning_over_33_33_ms": planning_over_33,
		"planning_over_50_ms": planning_over_50,
		"slow_frames_near_planning": _planning_correlated_slow_frames,
		"slow_frames_near_d3_release": _d3_correlated_slow_frames,
		"slow_frames_near_support_entry": _support_correlated_slow_frames,
	}


static func _percentile(ordered: Array, percentile: float) -> float:
	if ordered.is_empty():
		return 0.0
	var index := clampi(
		roundi((ordered.size() - 1) * clampf(percentile, 0.0, 1.0)),
		0,
		ordered.size() - 1
	)
	return float(ordered[index])


static func _count_over(samples: PackedFloat32Array, threshold: float) -> int:
	var result := 0
	for value in samples:
		if value > threshold:
			result += 1
	return result


static func _average(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for value in samples:
		total += value
	return total / float(samples.size())


static func _maximum(samples: PackedFloat32Array) -> float:
	var result := 0.0
	for value in samples:
		result = maxf(result, value)
	return result
