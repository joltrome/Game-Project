class_name MotionBackgroundDropDirector
extends Node2D

signal reservation_created(schedule_index: int, scheduled_at: float)
signal warning_started(schedule_index: int, lane_index: int, lane_x: float, started_at: float)
signal product_released(schedule_index: int, lane_index: int, product: ConveyorProduct, released_at: float)
signal product_landed(schedule_index: int, lane_index: int, product: ConveyorProduct, landed_at: float)
signal visual_cycle_reset(schedule_index: int, reset_at: float)
signal replacement_rejected(schedule_index: int, reason: String, rejected_at: float)
signal product_player_collision(
	schedule_index: int,
	lane_index: int,
	death_resulted: bool,
	collided_at: float
)
signal sequence_stopped(outcome: String, stopped_at: float)

enum VisualState {
	STORED,
	SELECTED,
	RELEASED,
	STOPPED,
}

@export_category("Schedule Hypothesis")
@export var first_reservation_time: float = 8.5
@export var minimum_repeat_interval: float = 7.0
@export var maximum_repeat_interval: float = 9.0
@export var minimum_successful_warning_gap: float = 7.0
@export var maximum_events_per_round: int = 6
@export var schedule_seed: int = 5002
@export var retry_delay: float = 0.12

@export_category("Warning and Fall")
@export var warning_duration: float = 1.10
@export var target_fall_duration: float = 0.85
@export var background_product_y: float = 192.0
@export var release_y: float = 232.0
@export var candidate_lane_x := PackedFloat32Array([406.0, 526.0, 646.0])
@export var first_event_preferred_lane_index: int = 1

@export_category("Fairness")
@export var horizontal_clearance: float = 8.0
@export var reachability_reserve: float = 0.18

var state: VisualState = VisualState.STORED
var reservation_pending: bool = false
var next_reservation_time: float = 16.0
var selected_lane_index: int = -1
var selected_lane_x: float = NAN
var warning_time_remaining: float = 0.0
var _replacement_retry_remaining: float = 0.0
var _events_released: int = 0
var _active_schedule_index: int = -1
var _lane_cursor: int = 0
var _pulse_elapsed: float = 0.0
var _event_log: Array[Dictionary] = []
var _conveyor: ConveyorPrototype
var _nominal_reservation_times := PackedFloat32Array()
var _last_successful_warning_time: float = -INF
var _last_selected_lane_index: int = -1
var _suppressed_ordinary_products: int = 0
var _background_player_collisions: int = 0
var _summary_recorded: bool = false
var _latest_candidate_rejection_details: Dictionary = {}

const CREAM := Color("f2e7c9")
const NAVY := Color("17243a")
const RED := Color("c93c45")
const GOLD := Color("f2ba45")
const TEAL := Color("2ca6a4")
const MUTED := Color("5f7185")


func _ready() -> void:
	_conveyor = get_parent() as ConveyorPrototype
	if _conveyor == null:
		push_error("MotionBackgroundDropDirector requires ConveyorPrototype parent")
		set_process(false)
		return
	z_index = 6
	_build_nominal_schedule()
	_conveyor.player_died.connect(_on_gameplay_stopped)
	_conveyor.ordinary_product_event_replaced.connect(
		_on_ordinary_product_event_suppressed
	)
	queue_redraw()


func _process(delta: float) -> void:
	if _conveyor == null or state == VisualState.STOPPED:
		return
	if _conveyor.gameplay_is_stopped():
		_on_gameplay_stopped()
		return
	_replacement_retry_remaining = maxf(
		_replacement_retry_remaining - delta,
		0.0
	)
	if (
		state == VisualState.STORED
		and not reservation_pending
		and _events_released < maximum_events_per_round
		and _conveyor.survival_time + 0.0001 >= next_reservation_time
	):
		reservation_pending = true
		_active_schedule_index = _events_released
		_record("reservation", {
			"schedule_index": _active_schedule_index,
			"scheduled_at": next_reservation_time,
			"next_scheduled_drop_time": next_reservation_time,
		})
		reservation_created.emit(_active_schedule_index, next_reservation_time)
	if (
		state == VisualState.STORED
		and reservation_pending
		and _replacement_retry_remaining <= 0.0
	):
		if _sequence_can_finish_before_round_end():
			_try_start_reserved_sequence()
		else:
			_cancel_unfinishable_reservation()
	if state == VisualState.SELECTED:
		_pulse_elapsed += delta
		warning_time_remaining = maxf(warning_time_remaining - delta, 0.0)
		queue_redraw()
		if warning_time_remaining <= 0.0:
			_release_selected_product()


func event_log() -> Array[Dictionary]:
	return _event_log.duplicate(true)


func released_event_count() -> int:
	return _events_released


func active_replacement_id() -> String:
	if _active_schedule_index < 0:
		return ""
	return "D3-BAY-%02d" % (_active_schedule_index + 1)


func visual_state_name() -> String:
	return VisualState.keys()[state].to_lower()


func configured_event_times() -> PackedFloat32Array:
	return _nominal_reservation_times.duplicate()


func configure_schedule_seed(new_seed: int) -> void:
	if _events_released > 0 or state != VisualState.STORED or reservation_pending:
		push_error("Cannot reseed an active background-drop schedule")
		return
	schedule_seed = new_seed
	_build_nominal_schedule()


func active_sequence_count() -> int:
	return 1 if state in [VisualState.SELECTED, VisualState.RELEASED] else 0


func suppressed_ordinary_product_count() -> int:
	return _suppressed_ordinary_products


func background_player_collision_count() -> int:
	return _background_player_collisions


func successful_warning_times() -> PackedFloat32Array:
	var times := PackedFloat32Array()
	for entry in _event_log:
		if String(entry.get("event", "")) == "warning":
			times.append(float(entry.get("time", 0.0)))
	return times


func selected_lane_indices() -> PackedInt32Array:
	var lanes := PackedInt32Array()
	for entry in _event_log:
		if String(entry.get("event", "")) == "warning":
			lanes.append(int(entry.get("lane_index", -1)))
	return lanes


func longest_successful_warning_gap() -> float:
	var times := successful_warning_times()
	var longest := 0.0
	for index in range(1, times.size()):
		longest = maxf(longest, times[index] - times[index - 1])
	return longest


func rejection_counts_by_reason() -> Dictionary:
	var counts := {}
	for entry in _event_log:
		if String(entry.get("event", "")) != "rejection":
			continue
		var reason := String(entry.get("reason", "unknown"))
		counts[reason] = int(counts.get(reason, 0)) + 1
	return counts


func candidate_rejection_counts_by_reason() -> Dictionary:
	var counts := {}
	for entry in _event_log:
		if String(entry.get("event", "")) != "rejection":
			continue
		var details: Dictionary = entry.get("candidate_rejection_details", {})
		for lane in details:
			var reason := String(details[lane])
			counts[reason] = int(counts.get(reason, 0)) + 1
	return counts


func _build_nominal_schedule() -> void:
	_nominal_reservation_times.clear()
	var event_count := maxi(maximum_events_per_round, 0)
	if event_count == 0:
		next_reservation_time = INF
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = schedule_seed
	var scheduled_time := maxf(first_reservation_time, 0.0)
	_nominal_reservation_times.append(scheduled_time)
	for _index in range(1, event_count):
		var minimum_interval := maxf(minimum_repeat_interval, 0.0)
		var maximum_interval := maxf(maximum_repeat_interval, minimum_interval)
		scheduled_time += rng.randf_range(minimum_interval, maximum_interval)
		_nominal_reservation_times.append(scheduled_time)
	next_reservation_time = _nominal_reservation_times[0]


func safe_response_exists(candidate_x: float, response_time: float = -1.0) -> bool:
	if _conveyor == null:
		return false
	var available_time := (
		warning_duration + target_fall_duration
		if response_time < 0.0
		else response_time
	)
	available_time = maxf(available_time - reachability_reserve, 0.0)
	var player_half := _conveyor.player_collision_size().x * 0.5
	var hazard_half := _conveyor.product_size.x * 0.5
	var required_distance := player_half + hazard_half + horizontal_clearance
	var left_safe_x := candidate_x - required_distance
	var right_safe_x := candidate_x + required_distance
	var player_x := _conveyor.player.position.x
	if absf(player_x - candidate_x) >= required_distance:
		return true
	var left_distance := INF
	if left_safe_x >= _conveyor.belt_left_x + player_half:
		left_distance = absf(player_x - left_safe_x)
	var right_distance := INF
	if right_safe_x <= _conveyor.control_band_right:
		right_distance = absf(player_x - right_safe_x)
	var left_reach := absf(_conveyor.net_left_input_world_speed()) * available_time
	var right_reach := maxf(_conveyor.net_right_input_world_speed(), 0.0) * available_time
	return left_distance <= left_reach or right_distance <= right_reach


func candidate_rejection_reason(
	candidate_x: float,
	time_to_impact: float = -1.0,
	include_collectibles: bool = true
) -> String:
	if _conveyor == null:
		return "missing_conveyor"
	var impact_time := (
		warning_duration + target_fall_duration
		if time_to_impact < 0.0
		else time_to_impact
	)
	var half_width := _conveyor.product_size.x * 0.5
	if (
		candidate_x - half_width < _conveyor.belt_left_x
		or candidate_x + half_width > _conveyor.control_band_right
	):
		return "outside_player_band"
	if not safe_response_exists(candidate_x, impact_time):
		return "unreachable_escape"
	var overlap_distance := (
		_conveyor.product_size.x + _conveyor.landed_product_size.x
	) * 0.5
	for product in _conveyor.active_landed_products():
		if not is_instance_valid(product):
			continue
		var projected_x := (
			product.conveyor_center_x()
			- _conveyor.conveyor_speed_at(_conveyor.survival_time) * impact_time
		)
		if absf(projected_x - candidate_x) < overlap_distance:
			return "landed_product_overlap"
	for product in _conveyor.active_falling_products():
		if is_instance_valid(product):
			return "falling_product_active"
	if _conveyor.warning_is_visible():
		return "ordinary_warning_active"
	var collectibles := _conveyor.get_node_or_null("CollectibleDirector") as CollectibleDirector
	if include_collectibles and collectibles != null:
		for coin in collectibles.active_collectibles():
			var coin_left := (
				coin.global_position.x
				- _conveyor.conveyor_speed_at(_conveyor.survival_time) * impact_time
			)
			var coin_clearance := half_width + coin.collectible_size.x * 0.5
			if (
				candidate_x >= coin_left - coin_clearance
				and candidate_x <= coin.global_position.x + coin_clearance
			):
				return "collectible_path_overlap"
	# The frozen carriage band exactly clears a grounded belt player. Therefore
	# an active carriage preserves a grounded escape response; reject only if a
	# future baseline changes that exact vertical relationship.
	if _conveyor.active_sweeper_count() > 0 and not _conveyor.sweeper_clears_grounded_player():
		return "grounded_sweeper_conflict"
	return ""


func _try_start_reserved_sequence() -> String:
	if (
		not reservation_pending
		or state != VisualState.STORED
		or _replacement_retry_remaining > 0.0
	):
		return ""
	var lane := _select_valid_lane()
	if lane < 0:
		_reject("no_valid_background_lane")
		return ""
	var replacement_id := active_replacement_id()
	if not _conveyor.reserve_ordinary_product_suppression(replacement_id):
		_reject("ordinary_suppression_reservation_failed")
		return ""
	_conveyor.set_external_product_event_pending(true)
	selected_lane_index = lane
	selected_lane_x = candidate_lane_x[lane]
	state = VisualState.SELECTED
	reservation_pending = false
	warning_time_remaining = warning_duration
	_pulse_elapsed = 0.0
	_last_successful_warning_time = _conveyor.survival_time
	_last_selected_lane_index = lane
	_record("warning", {
		"schedule_index": _active_schedule_index,
		"lane_index": selected_lane_index,
		"lane_x": selected_lane_x,
		"warning_duration": warning_duration,
		"attempt_accepted": true,
		"ordinary_product_suppression_reserved": true,
		"replacement_id": replacement_id,
		"next_scheduled_drop_time": next_reservation_time,
	})
	warning_started.emit(
		_active_schedule_index,
		selected_lane_index,
		selected_lane_x,
		_conveyor.survival_time
	)
	queue_redraw()
	return replacement_id


func _on_ordinary_product_event_suppressed(
	pattern_type: int,
	replacement_id: String
) -> void:
	if not replacement_id.begins_with("D3-BAY-"):
		return
	_suppressed_ordinary_products += 1
	_record("ordinary_suppressed", {
		"pattern_type": pattern_type,
		"replacement_id": replacement_id,
		"total_suppressed_ordinary_products": _suppressed_ordinary_products,
		"next_scheduled_drop_time": next_reservation_time,
	})


func _select_valid_lane() -> int:
	if candidate_lane_x.is_empty():
		return -1
	_latest_candidate_rejection_details.clear()
	if _active_schedule_index == 0:
		var preferred := clampi(
			first_event_preferred_lane_index,
			0,
			candidate_lane_x.size() - 1
		)
		var preferred_reason := candidate_rejection_reason(candidate_lane_x[preferred])
		if preferred_reason.is_empty():
			_lane_cursor = preferred + 1
			return preferred
		_latest_candidate_rejection_details[preferred] = preferred_reason
	for offset in range(candidate_lane_x.size()):
		var index := posmod(_lane_cursor + offset, candidate_lane_x.size())
		if index == _last_selected_lane_index and candidate_lane_x.size() > 1:
			continue
		var reason := candidate_rejection_reason(candidate_lane_x[index])
		if reason.is_empty():
			_lane_cursor = index + 1
			return index
		_latest_candidate_rejection_details[index] = reason
	return -1


func _release_selected_product() -> void:
	# Selection commits the lane after validating the complete warning-plus-fall
	# horizon. The conveyor then reserves the product slot until release, so the
	# warning duration remains stable and its one-to-one correspondence is not
	# changed by a late visual-only collectible crossing.
	var replacement_id := active_replacement_id()
	var product := _conveyor.spawn_external_conveyor_product(
		selected_lane_x,
		release_y,
		target_fall_duration,
		replacement_id
	)
	if product == null:
		_reject("external_spawn_rejected")
		warning_time_remaining = retry_delay
		return
	state = VisualState.RELEASED
	_events_released += 1
	product.landed.connect(
		_on_external_product_landed.bind(_active_schedule_index, selected_lane_index),
		CONNECT_ONE_SHOT
	)
	product.player_hit.connect(
		_on_external_product_player_hit.bind(_active_schedule_index, selected_lane_index),
		CONNECT_ONE_SHOT
	)
	_record("release", {
		"schedule_index": _active_schedule_index,
		"lane_index": selected_lane_index,
		"lane_x": selected_lane_x,
		"fall_duration": target_fall_duration,
		"replacement_id": replacement_id,
	})
	product_released.emit(
		_active_schedule_index,
		selected_lane_index,
		product,
		_conveyor.survival_time
	)
	queue_redraw()


func _on_external_product_landed(
	product: FallingProduct,
	schedule_index: int,
	lane_index: int
) -> void:
	if not product is ConveyorProduct or state == VisualState.STOPPED:
		return
	product_landed.emit(
		schedule_index,
		lane_index,
		product as ConveyorProduct,
		_conveyor.survival_time
	)
	_record("landing", {
		"schedule_index": schedule_index,
		"lane_index": lane_index,
		"lane_x": selected_lane_x,
	})
	var completed_schedule := _active_schedule_index
	state = VisualState.STORED
	selected_lane_index = -1
	selected_lane_x = NAN
	warning_time_remaining = 0.0
	_active_schedule_index = -1
	if _events_released < _nominal_reservation_times.size():
		next_reservation_time = maxf(
			_nominal_reservation_times[_events_released],
			_last_successful_warning_time + minimum_successful_warning_gap
		)
	else:
		next_reservation_time = INF
	_record("reset", {
		"schedule_index": completed_schedule,
		"next_reservation_time": next_reservation_time,
		"sequence_completion_time": _conveyor.survival_time,
	})
	visual_cycle_reset.emit(completed_schedule, _conveyor.survival_time)
	queue_redraw()


func _reject(reason: String) -> void:
	_replacement_retry_remaining = retry_delay
	_record("rejection", {
		"schedule_index": _active_schedule_index,
		"reason": reason,
		"attempt_accepted": false,
		"next_scheduled_drop_time": next_reservation_time,
		"candidate_rejection_details": _latest_candidate_rejection_details.duplicate(true),
	})
	replacement_rejected.emit(
		_active_schedule_index,
		reason,
		_conveyor.survival_time
	)


func _sequence_can_finish_before_round_end() -> bool:
	var round_controller := _conveyor.get_node_or_null("RoundController") as FixedRoundController
	if round_controller == null or not round_controller.fixed_round_enabled:
		return true
	return (
		round_controller.round_time_remaining
		>= warning_duration + target_fall_duration + 0.10
	)


func _cancel_unfinishable_reservation() -> void:
	var skipped_schedule := _active_schedule_index
	_record("rejection", {
		"schedule_index": skipped_schedule,
		"reason": "insufficient_round_time",
		"attempt_accepted": false,
		"rescheduled": false,
		"next_scheduled_drop_time": INF,
	})
	replacement_rejected.emit(
		skipped_schedule,
		"insufficient_round_time",
		_conveyor.survival_time
	)
	reservation_pending = false
	_active_schedule_index = -1
	next_reservation_time = INF


func _on_external_product_player_hit(
	_product: FallingProduct,
	schedule_index: int,
	lane_index: int
) -> void:
	_background_player_collisions += 1
	_record("player_collision", {
		"schedule_index": schedule_index,
		"lane_index": lane_index,
		"death_resulted": true,
	})
	product_player_collision.emit(
		schedule_index,
		lane_index,
		true,
		_conveyor.survival_time
	)


func _on_gameplay_stopped() -> void:
	if state == VisualState.STOPPED:
		return
	state = VisualState.STOPPED
	reservation_pending = false
	warning_time_remaining = 0.0
	selected_lane_index = -1
	selected_lane_x = NAN
	_active_schedule_index = -1
	next_reservation_time = INF
	if is_instance_valid(_conveyor):
		_conveyor.set_external_product_event_pending(false)
	var outcome := "death" if _conveyor.is_dead else "complete"
	_record("stopped", {
		"outcome": outcome,
		"next_scheduled_drop_time": next_reservation_time,
	})
	sequence_stopped.emit(outcome, _conveyor.survival_time)
	call_deferred("_record_run_summary", outcome)
	queue_redraw()


func _record_run_summary(outcome: String) -> void:
	if _summary_recorded:
		return
	_summary_recorded = true
	_record("summary", {
		"outcome": outcome,
		"total_background_drops": _events_released,
		"longest_successful_event_gap": longest_successful_warning_gap(),
		"suppressed_ordinary_products": _suppressed_ordinary_products,
		"background_player_collisions": _background_player_collisions,
		"rejection_counts": rejection_counts_by_reason(),
	})


func _record(event_name: String, values: Dictionary) -> void:
	var entry := {
		"event": event_name,
		"time": _conveyor.survival_time if _conveyor != null else 0.0,
	}
	entry.merge(values, true)
	_event_log.append(entry)


func _draw() -> void:
	if state == VisualState.STOPPED:
		return
	for index in range(candidate_lane_x.size()):
		var center := Vector2(candidate_lane_x[index], background_product_y)
		var selected := index == selected_lane_index and state == VisualState.SELECTED
		var released := index == selected_lane_index and state == VisualState.RELEASED
		var pulse := 1.0 + (0.10 * sin(_pulse_elapsed * TAU * 4.0) if selected else 0.0)
		var product_size := Vector2(42.0, 58.0) * pulse
		var color := GOLD if selected else Color(MUTED.r, MUTED.g, MUTED.b, 0.60)
		if released:
			color = Color(NAVY.r, NAVY.g, NAVY.b, 0.40)
		draw_rect(Rect2(center - product_size * 0.5, product_size), color)
		draw_rect(
			Rect2(center + Vector2(-product_size.x * 0.5, -5.0), Vector2(product_size.x, 10.0)),
			Color(NAVY.r, NAVY.g, NAVY.b, color.a)
		)
	if state != VisualState.SELECTED:
		return
	var warning_alpha := 0.14 + 0.05 * sin(_pulse_elapsed * TAU * 4.0)
	draw_rect(
		Rect2(
			selected_lane_x - _conveyor.product_size.x * 0.5,
			background_product_y + 34.0,
			_conveyor.product_size.x,
			_conveyor.floor_y - background_product_y - 34.0
		),
		Color(RED.r, RED.g, RED.b, warning_alpha)
	)
	draw_rect(
		Rect2(selected_lane_x - 30.0, background_product_y + 32.0, 60.0, 18.0),
		RED
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(selected_lane_x - 26.0, background_product_y + 47.0),
		"DROP",
		HORIZONTAL_ALIGNMENT_CENTER,
		52.0,
		12,
		CREAM
	)
