class_name CollectibleDirector
extends Node2D

signal collectible_spawned(collectible: ConveyorCollectible)
signal offer_spawned(offer_id: int, template: int, coin_count: int)
signal score_changed(score: int)

enum PlacementBand {
	GROUND,
	LOW_AIR,
}

enum OfferTemplate {
	GROUND_SINGLE,
	LOW_AIR_ARC,
	SAFE_VERSUS_RISK,
	HORIZONTAL_LINE,
	MIXED_ROUTE,
	COMPACT_BURST,
	STAGGERED_ROUTE,
}

enum RouteTrajectory {
	NO_FURTHER_INPUT,
	SAME_INPUT_CONTINUATION,
	PASSIVE_JUMP,
	INTENDED_AGGRESSIVE,
	SAFE_ABANDONMENT,
}

enum OfferSide {
	BEHIND,
	CENTRED,
	AHEAD,
}

enum RouteArchetype {
	LINEAR,
	STAIR_UP,
	STAIR_DOWN,
	ARC,
	STAGGER,
	RISK_TAIL,
	CLUSTER,
}

const COLLECTIBLE_SCENE := preload(
	"res://scenes/collectibles/conveyor_collectible.tscn"
)

const REJECTION_ACTIVE_LIMIT := "active-offer limit"
const REJECTION_CAN_OVERLAP := "can overlap"
const REJECTION_SWEEPER := "Sweeper conflict"
const REJECTION_UNREACHABLE := "unreachable"
const REJECTION_OFF_BELT := "off-belt"
const REJECTION_JUMP_MARGIN := "invalid jump margin"
const REJECTION_LIFETIME := "invalid lifetime"
const REJECTION_SIBLING := "sibling geometry conflict"
const REJECTION_ROUND_ENDING := "round ending"
const REJECTION_PLAYER_OVERLAP := "player overlap"
const REJECTION_PLAYER_BUFFER := "player safety buffer"
const REJECTION_UNKNOWN := "unknown"

@export_category("Offer Timing")
@export var first_spawn_window_min: float = 1.5
@export var first_spawn_window_max: float = 2.0
@export var first_spawn_time: float = 1.75
@export var recurring_spawn_interval: float = 2.75
@export var failed_spawn_retry_delay: float = 0.10
@export var maximum_offer_free_gap: float = 3.5
@export var collectible_lifetime: float = 2.25
@export var maximum_active_offers: int = 2
@export var bounded_overlap_duration: float = 0.50

@export_category("Readability Feedback")
@export var first_offer_teaching_cue_enabled: bool = true
@export var first_offer_teaching_cue_timeout: float = 2.0
@export var score_hud_pulse_duration: float = 0.22
@export var score_hud_normal_font_size: int = 28
@export var score_hud_pulse_scale: float = 1.22
@export var score_hud_normal_color := Color(1.0, 0.79, 0.11, 1.0)
@export var score_hud_pulse_color := Color(1.0, 0.96, 0.54, 1.0)

@export_category("Offer Phases")
@export var phase_one_end: float = 10.0
@export var phase_two_end: float = 30.0
@export var phase_three_end: float = 45.0
@export var phase_one_cadence := Vector2(2.5, 3.0)
@export var phase_two_cadence := Vector2(2.25, 2.75)
@export var phase_three_cadence := Vector2(1.75, 2.25)
@export var phase_four_cadence := Vector2(1.5, 2.0)
@export var phase_one_coin_range := Vector2i(1, 2)
@export var phase_two_coin_range := Vector2i(1, 3)
@export var phase_three_coin_range := Vector2i(2, 4)
@export var phase_four_coin_range := Vector2i(3, 5)
@export var phase_one_template_weights := PackedInt32Array([0, 0, 30, 20, 25, 10, 15])
@export var phase_two_template_weights := PackedInt32Array([0, 0, 30, 20, 25, 10, 15])
@export var phase_three_template_weights := PackedInt32Array([0, 0, 30, 20, 25, 10, 15])
@export var phase_four_template_weights := PackedInt32Array([0, 0, 30, 20, 25, 10, 15])

@export_category("Placement")
@export var placement_seed: int = 401
@export var ground_band_center_y_range := Vector2(548.0, 552.0)
@export var low_air_band_center_y_range := Vector2(488.0, 500.0)
@export var minimum_normal_jump_margin: float = 48.0
@export var candidate_x_positions := PackedFloat32Array([610.0, 580.0, 640.0, 550.0])
@export var collectible_size: Vector2 = Vector2(24.0, 24.0)
@export var safe_edge_exclusion: float = 48.0
@export var reachability_reserve: float = 0.20
@export_range(1.75, 2.50, 0.05) var typical_sibling_spacing_player_widths: float = 2.00
@export_range(0.35, 0.55, 0.01) var horizontal_trail_span_ratio: float = 0.45
@export_range(0.35, 0.70, 0.01) var staggered_coin_interval: float = 0.50
@export var minimum_route_response_time: float = 0.55
@export var player_spawn_safety_padding: float = 8.0
@export var maximum_delayed_coin_spawn_retries: int = 4

@export_category("Route Validation")
@export var trajectory_simulation_step: float = 1.0 / 120.0
@export var recent_route_history_size: int = 2
@export var decision_route_cadence_multiplier: float = 1.50

@export_category("Player-Relative Offer Distribution")
@export var side_distribution_correction_enabled: bool = true
@export var maximum_consecutive_behind_offers: int = 2
@export_range(0.0, 1.0, 0.01) var centred_ahead_after_behind_weight: float = 1.0
@export var offer_side_tolerance_player_widths: float = 1.0
@export var ahead_target_offset_player_widths: float = 1.5
@export_range(0.25, 1.0, 0.05) var centred_ahead_followup_cadence_multiplier: float = 0.40

# Kept as a compatibility surface for VM-0.4.1 tests and factual comparisons.
@export_range(0.0, 1.0, 0.01) var ground_probability_after_first := 0.50

var score: int = 0
var first_actual_spawn_time: float = -1.0
var last_spawn_band: int = -1
var spawn_count: int = 0
var _next_spawn_time: float = 1.75
var _placement_rng_state: int = 401
var _active_offers: Array[Dictionary] = []
var _offer_log: Array[Dictionary] = []
var _rejection_counts: Dictionary = {}
var _offer_id_cursor: int = 0
var _natural_offer_count: int = 0
var _rotation_offset: int = 0
var _pending_teaching_template: int = -1
var _last_offer_spawn_time: float = -1.0
var _longest_offer_gap: float = 0.0
var _stopped: bool = false
var _teaching_cue_shown: bool = false
var _score_pulse_remaining: float = 0.0
var _score_pulse_count: int = 0
var _recent_natural_templates: Array[int] = []
var _consecutive_behind_offers: int = 0
var _alternate_placement_count: int = 0
var _delayed_player_safety_retry_count: int = 0
var _delayed_candidate_skip_count: int = 0
var _player_safety_encounter_counts: Dictionary = {}

@onready var _conveyor: ConveyorPrototype = get_parent() as ConveyorPrototype
@onready var _score_label: Label = _conveyor.get_node("HUD/ScoreGroup/CollectibleScore")


func _ready() -> void:
	_next_spawn_time = clampf(first_spawn_time, first_spawn_window_min, first_spawn_window_max)
	_placement_rng_state = placement_seed
	_update_score_label()
	_conveyor.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	_update_score_hud_pulse(delta)
	if _stopped or _conveyor.gameplay_is_stopped():
		return
	_update_staggered_offers()
	_refresh_active_offers()
	_update_active_coin_speeds()
	if _conveyor.survival_time + 0.0001 < _next_spawn_time:
		_enforce_scheduling_invariant()
		return
	_try_spawn_natural_offer()
	_enforce_scheduling_invariant()


func active_collectible_count() -> int:
	var count := 0
	for offer in _active_offers:
		for coin in offer.coins:
			if is_instance_valid(coin) and not coin.is_resolved():
				count += 1
	return count


func active_offer_count() -> int:
	_refresh_active_offers()
	return _active_offers.size()


func active_collectible() -> ConveyorCollectible:
	for offer in _active_offers:
		for coin in offer.coins:
			if is_instance_valid(coin) and not coin.is_resolved():
				return coin
	return null


func active_collectibles() -> Array[ConveyorCollectible]:
	var result: Array[ConveyorCollectible] = []
	for offer in _active_offers:
		for coin in offer.coins:
			if is_instance_valid(coin) and not coin.is_resolved():
				result.append(coin)
	return result


func next_spawn_time() -> float:
	return _next_spawn_time


func pending_band() -> int:
	if _pending_teaching_template == OfferTemplate.GROUND_SINGLE:
		return PlacementBand.GROUND
	if _pending_teaching_template == OfferTemplate.LOW_AIR_ARC:
		return PlacementBand.LOW_AIR
	return -1


func diagnostic_log() -> Array[Dictionary]:
	return offer_log()


func offer_log() -> Array[Dictionary]:
	return _offer_log.duplicate(true)


func rejection_counts() -> Dictionary:
	return _rejection_counts.duplicate(true)


func alternate_placement_count() -> int:
	return _alternate_placement_count


func delayed_player_safety_retry_count() -> int:
	return _delayed_player_safety_retry_count


func delayed_candidate_skip_count() -> int:
	return _delayed_candidate_skip_count


func player_safety_encounter_counts() -> Dictionary:
	return _player_safety_encounter_counts.duplicate(true)


func longest_offer_gap() -> float:
	return _longest_offer_gap


func teaching_cue_was_shown() -> bool:
	return _teaching_cue_shown


func active_teaching_cue_count() -> int:
	var count := 0
	for child in get_children():
		if child is ConveyorCollectible and child.teaching_cue_is_visible():
			count += 1
	return count


func score_hud_is_pulsing() -> bool:
	return _score_pulse_remaining > 0.0


func score_hud_pulse_count() -> int:
	return _score_pulse_count


func pending_staggered_coin_count() -> int:
	var count := 0
	for offer in _active_offers:
		count += offer.get("pending_candidates", []).size()
	return count


func try_spawn_for_test() -> bool:
	return _try_spawn_template(OfferTemplate.GROUND_SINGLE, 1, false)


func try_spawn_band_for_test(band: int) -> bool:
	var template := (
		OfferTemplate.GROUND_SINGLE
		if band == PlacementBand.GROUND
		else OfferTemplate.LOW_AIR_ARC
	)
	var accepted := _try_spawn_template(template, 1, false)
	_pending_teaching_template = -1 if accepted else template
	return accepted


func try_spawn_template_for_test(template: int, intended_count: int) -> bool:
	return _try_spawn_template(template, intended_count, false)


func preview_band_sequence_for_test(count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var preview_state := placement_seed
	for index in range(maxi(count, 0)):
		if index == 0:
			result.append(PlacementBand.GROUND)
			continue
		preview_state = _next_rng_state(preview_state)
		result.append(_band_from_roll(preview_state))
	return result


func phase_at(time_seconds: float) -> int:
	if time_seconds < phase_one_end:
		return 0
	if time_seconds < phase_two_end:
		return 1
	if time_seconds < phase_three_end:
		return 2
	return 3


func cadence_range_at(time_seconds: float) -> Vector2:
	match phase_at(time_seconds):
		0:
			return phase_one_cadence
		1:
			return phase_two_cadence
		2:
			return phase_three_cadence
	return phase_four_cadence


func coin_range_at(time_seconds: float) -> Vector2i:
	match phase_at(time_seconds):
		0:
			return phase_one_coin_range
		1:
			return phase_two_coin_range
		2:
			return phase_three_coin_range
	return phase_four_coin_range


func band_center_y(band: int) -> float:
	var configured_range := ground_band_center_y_range if band == PlacementBand.GROUND else low_air_band_center_y_range
	return (configured_range.x + configured_range.y) * 0.5


func candidate_is_reachable(candidate: Vector2, band: int = -1) -> bool:
	var evaluated_band := _resolve_band(candidate, band)
	var relative_control_speed := _conveyor.player.maximum_speed
	var available_time := maxf(_candidate_available_time(candidate.x), 0.0)
	var horizontal_time := absf(candidate.x - _conveyor.player.global_position.x) / relative_control_speed if relative_control_speed > 0.0 else INF
	if relative_control_speed <= _conveyor.conveyor_speed:
		return false
	if evaluated_band == PlacementBand.GROUND:
		return _grounded_player_overlaps_y(candidate.y) and horizontal_time <= available_time + 0.0001
	var intervals := normal_jump_collection_intervals(candidate.y)
	if intervals.is_empty() or _grounded_player_overlaps_y(candidate.y):
		return false
	return normal_jump_collection_margin(candidate.y) >= minimum_normal_jump_margin and maxf(horizontal_time, intervals[0].x) <= available_time + 0.0001


func candidate_is_valid(candidate: Vector2, band: int = -1) -> bool:
	return candidate_rejection_reason(candidate, band).is_empty()


func candidate_rejection_reason(candidate: Vector2, band: int = -1) -> String:
	return _candidate_rejection_reason(candidate, _resolve_band(candidate, band), [])


func normal_jump_collection_margin(coin_center_y: float) -> float:
	var start_center_y := _conveyor.floor_y - _conveyor.player_collision_size().y * 0.5
	var combined_half_height := (_conveyor.player_collision_size().y + collectible_size.y) * 0.5
	var required_rise := maxf(start_center_y - (coin_center_y + combined_half_height), 0.0)
	return _conveyor.calculated_jump_height() - required_rise


func normal_jump_collection_intervals(coin_center_y: float) -> Array[Vector2]:
	var intervals: Array[Vector2] = []
	var player_size := _conveyor.player_collision_size()
	var start_center_y := _conveyor.floor_y - player_size.y * 0.5
	var combined_half_height := (player_size.y + collectible_size.y) * 0.5
	var upper_center_y := coin_center_y + combined_half_height
	var lower_center_y := coin_center_y - combined_half_height
	if upper_center_y >= start_center_y:
		return intervals
	var apex_time := absf(_conveyor.player.jump_velocity) / _conveyor.player.gravity
	var total_duration := apex_time * 2.0
	var ascent_start := _jump_ascent_time_at_center_y(upper_center_y)
	var ascent_end := _jump_ascent_time_at_center_y(lower_center_y)
	if ascent_start < 0.0:
		return intervals
	if ascent_end < 0.0:
		ascent_end = apex_time
	if ascent_end > ascent_start:
		intervals.append(Vector2(ascent_start, ascent_end))
		intervals.append(Vector2(total_duration - ascent_end, total_duration - ascent_start))
	return intervals


func stop_for_round_end() -> void:
	_stopped = true
	set_process(false)
	_reset_score_hud_pulse()
	for offer in _active_offers:
		offer.pending_candidates = []
	for child in get_children():
		if child is ConveyorCollectible:
			child.stop()


func _try_spawn_natural_offer() -> bool:
	var anti_streak_requested := _should_request_centred_ahead_offer()
	var selected_template := (
		OfferTemplate.GROUND_SINGLE
		if anti_streak_requested
		else _select_natural_template()
	)
	var intended_count := _select_intended_count(selected_template)
	var attempted: Array[int] = []
	for rotation in range(OfferTemplate.size()):
		if anti_streak_requested and rotation > 0:
			break
		var template := selected_template if rotation == 0 else posmod(selected_template + rotation + _rotation_offset, OfferTemplate.size())
		if template == OfferTemplate.COMPACT_BURST and selected_template != OfferTemplate.COMPACT_BURST:
			continue
		if _natural_offer_count >= 2 and _recent_natural_templates.has(template):
			continue
		if attempted.has(template):
			continue
		attempted.append(template)
		var side_preferences := (
			[OfferSide.AHEAD, OfferSide.CENTRED]
			if anti_streak_requested
			else [-1]
		)
		var accepted := false
		for side_preference in side_preferences:
			if _try_spawn_template(
				template,
				intended_count,
				true,
				int(side_preference),
				anti_streak_requested
			):
				accepted = true
				break
		if accepted:
			_pending_teaching_template = -1
			_rotation_offset = 0
			if not anti_streak_requested:
				_natural_offer_count += 1
				_remember_natural_template(template)
			return true
		if _natural_offer_count < 2:
			break
	_rotation_offset = posmod(_rotation_offset + 1, OfferTemplate.size())
	_next_spawn_time = _conveyor.survival_time + failed_spawn_retry_delay
	return false


func _try_spawn_template(
	template: int,
	intended_count: int,
	natural: bool,
	side_preference: int = -1,
	anti_streak_requested: bool = false
) -> bool:
	_refresh_active_offers()
	var phase := phase_at(_conveyor.survival_time)
	var player_x_at_commit := _conveyor.player.global_position.x
	var behind_streak_before := _consecutive_behind_offers
	var log_entry := {
		"event": "attempt",
		"time": _conveyor.survival_time,
		"phase": phase,
		"template": template,
		"template_name": template_name(template),
		"intended_count": intended_count,
		"ground_count": 0,
		"air_count": 0,
		"intended_ground_count": 0,
		"intended_low_air_count": 0,
		"accepted": false,
		"rejection_reason": "",
		"spawn_timestamp": -1.0,
		"resolve_timestamp": -1.0,
		"spawned_offer_id": -1,
		"resolved_offer_id": -1,
		"collected": 0,
		"expired": 0,
		"next_scheduled_time": _next_spawn_time,
		"active_offer_count": _active_offers.size(),
		"active_coin_count": active_collectible_count(),
		"active_offer_state": _active_offer_state(),
		"natural": natural,
		"player_x": player_x_at_commit,
		"offer_primary_x": NAN,
		"offer_side": -1,
		"offer_side_name": "unclassified",
		"behind_streak_before": behind_streak_before,
		"behind_streak_after": behind_streak_before,
		"anti_streak_requested": anti_streak_requested,
		"route_archetype": route_archetype_name(template),
		"placement_attempts": 1,
		"alternate_placement_selected": false,
		"placement_shift_x": 0.0,
		"player_safety_rejections": 0,
		"player_overlap_rejections": 0,
		"player_buffer_rejections": 0,
	}
	if _conveyor.gameplay_is_stopped() or _stopped:
		return _reject_attempt(log_entry, REJECTION_ROUND_ENDING)
	if not _can_open_another_offer():
		return _reject_attempt(log_entry, REJECTION_ACTIVE_LIMIT)
	var original_candidates := _template_candidates(
		template,
		intended_count,
		side_preference
	)
	if original_candidates.is_empty():
		return _reject_attempt(log_entry, REJECTION_UNKNOWN)
	var candidates := original_candidates
	var validation := _offer_candidate_rejection(candidates)
	if _is_player_safety_rejection(String(validation.reason)):
		_record_player_safety_encounter(String(validation.reason), log_entry)
		var alternatives := _whole_offer_relocation_candidates(original_candidates)
		for alternative in alternatives:
			log_entry.placement_attempts = int(log_entry.placement_attempts) + 1
			var alternative_validation := _offer_candidate_rejection(alternative)
			if _is_player_safety_rejection(String(alternative_validation.reason)):
				_record_player_safety_encounter(String(alternative_validation.reason), log_entry)
			if String(alternative_validation.reason).is_empty():
				candidates = alternative
				validation = alternative_validation
				log_entry.alternate_placement_selected = true
				log_entry.placement_shift_x = (
					float(candidates[0].position.x)
					- float(original_candidates[0].position.x)
				)
				_alternate_placement_count += 1
				break
	if not String(validation.reason).is_empty():
		return _reject_attempt(log_entry, String(validation.reason))
	for candidate_data in candidates:
		if candidate_data.band == PlacementBand.GROUND:
			log_entry.intended_ground_count = int(log_entry.intended_ground_count) + 1
		else:
			log_entry.intended_low_air_count = int(log_entry.intended_low_air_count) + 1
	log_entry.intended_count = candidates.size()
	var accepted_candidates: Array[Dictionary] = candidates
	if not _offer_has_reachable_response(accepted_candidates):
		return _reject_attempt(log_entry, REJECTION_UNREACHABLE)
	if _is_post_teaching_route(template):
		var action_validation := route_action_validation_for_test(template, candidates.size())
		if not bool(action_validation.valid):
			return _reject_attempt(log_entry, REJECTION_UNREACHABLE)
	_offer_id_cursor += 1
	var offer_id := _offer_id_cursor
	var coins: Array[ConveyorCollectible] = []
	var ground_count := int(log_entry.intended_ground_count)
	var air_count := int(log_entry.intended_low_air_count)
	var pending_candidates: Array[Dictionary] = []
	if template == OfferTemplate.STAGGERED_ROUTE and accepted_candidates.size() > 1:
		pending_candidates.assign(accepted_candidates.slice(1))
	var initial_count := 1 if not pending_candidates.is_empty() else accepted_candidates.size()
	for candidate_index in range(initial_count):
		coins.append(_spawn_offer_coin(accepted_candidates[candidate_index], offer_id, candidate_index))
	if (
		natural
		and _natural_offer_count == 0
		and first_offer_teaching_cue_enabled
		and not coins.is_empty()
	):
		coins[0].show_teaching_cue(first_offer_teaching_cue_timeout)
		_teaching_cue_shown = true
	var offer := {
		"id": offer_id,
		"template": template,
		"phase": phase,
		"coins": coins,
		"pending_candidates": pending_candidates,
		"next_subspawn_time": _conveyor.survival_time + staggered_coin_interval,
		"pending_retry_count": 0,
		"total_count": accepted_candidates.size(),
		"spawn_time": _conveyor.survival_time,
		"collected": 0,
		"expired": 0,
		"log_index": _offer_log.size(),
	}
	_active_offers.append(offer)
	last_spawn_band = PlacementBand.GROUND if ground_count > 0 and air_count == 0 else PlacementBand.LOW_AIR
	spawn_count += coins.size()
	if first_actual_spawn_time < 0.0:
		first_actual_spawn_time = _conveyor.survival_time
	if _last_offer_spawn_time >= 0.0:
		_longest_offer_gap = maxf(_longest_offer_gap, _conveyor.survival_time - _last_offer_spawn_time)
	_last_offer_spawn_time = _conveyor.survival_time
	var cadence := _select_cadence()
	if anti_streak_requested:
		cadence *= centred_ahead_followup_cadence_multiplier
	_next_spawn_time = _conveyor.survival_time + cadence
	log_entry.accepted = true
	log_entry.ground_count = ground_count
	log_entry.air_count = air_count
	log_entry.spawned_offer_id = offer_id
	log_entry.spawn_timestamp = _conveyor.survival_time
	log_entry.next_scheduled_time = _next_spawn_time
	log_entry.active_offer_count = _active_offers.size()
	log_entry.active_coin_count = active_collectible_count()
	log_entry.active_offer_state = _active_offer_state()
	var offer_side := classify_offer_side_for_test(
		accepted_candidates,
		player_x_at_commit
	)
	_update_offer_side_history(offer_side)
	log_entry.offer_primary_x = offer_primary_x_for_test(accepted_candidates)
	log_entry.offer_side = offer_side
	log_entry.offer_side_name = offer_side_name(offer_side)
	log_entry.behind_streak_after = _consecutive_behind_offers
	_offer_log.append(log_entry)
	offer_spawned.emit(offer_id, template, accepted_candidates.size())
	return true


func _spawn_offer_coin(
	candidate_data: Dictionary,
	offer_id: int,
	coin_index: int
) -> ConveyorCollectible:
	var coin := COLLECTIBLE_SCENE.instantiate() as ConveyorCollectible
	add_child(coin)
	coin.global_position = candidate_data.position
	coin.configure(
		_candidate_visible_lifetime(candidate_data.position.x),
		_conveyor.conveyor_speed,
		collectible_size,
		candidate_data.band,
		offer_id * 101 + coin_index * 37 + placement_seed
	)
	coin.set_meta("offer_id", offer_id)
	coin.collected.connect(_on_collectible_collected.bind(offer_id))
	coin.expired.connect(_on_collectible_expired.bind(offer_id))
	collectible_spawned.emit(coin)
	return coin


func _candidate_visible_lifetime(candidate_x: float) -> float:
	if _conveyor.conveyor_speed <= 0.0:
		return collectible_lifetime
	var time_to_left_edge := (
		candidate_x
		- collectible_size.x * 0.5
		- _conveyor.conveyor_support_left_x
	) / _conveyor.conveyor_speed
	return minf(collectible_lifetime, maxf(time_to_left_edge, 0.0))


func _candidate_available_time(candidate_x: float) -> float:
	return maxf(_candidate_visible_lifetime(candidate_x) - reachability_reserve, 0.0)


func _update_staggered_offers() -> void:
	for offer_index in range(_active_offers.size()):
		var offer: Dictionary = _active_offers[offer_index]
		var pending: Array = offer.get("pending_candidates", [])
		if pending.is_empty() or _conveyor.survival_time + 0.0001 < float(offer.next_subspawn_time):
			continue
		var candidate_data: Dictionary = pending[0]
		var reason := _player_spawn_rejection_reason(candidate_data.position)
		if reason.is_empty():
			reason = _candidate_rejection_reason(
				candidate_data.position,
				candidate_data.band,
				[],
				false
			)
		if not reason.is_empty():
			var retry_count := int(offer.get("pending_retry_count", 0)) + 1
			offer.pending_retry_count = retry_count
			if _is_player_safety_rejection(reason):
				_delayed_player_safety_retry_count += 1
				_record_player_safety_encounter(reason)
			_record_subspawn_event("subspawn_rejected", offer, candidate_data, reason, retry_count)
			if retry_count > maxi(maximum_delayed_coin_spawn_retries, 0):
				pending.pop_front()
				offer.pending_candidates = pending
				offer.pending_retry_count = 0
				offer.expired = int(offer.expired) + 1
				_delayed_candidate_skip_count += 1
				_record_skipped_candidate_resolution(offer)
				_record_subspawn_event("subspawn_skipped", offer, candidate_data, reason, retry_count)
			offer.next_subspawn_time = _conveyor.survival_time + minf(failed_spawn_retry_delay, staggered_coin_interval)
			_active_offers[offer_index] = offer
			continue
		pending.pop_front()
		var coin_index := int(offer.total_count) - pending.size() - 1
		var coin := _spawn_offer_coin(candidate_data, int(offer.id), coin_index)
		offer.coins.append(coin)
		offer.pending_candidates = pending
		offer.pending_retry_count = 0
		offer.next_subspawn_time = _conveyor.survival_time + staggered_coin_interval
		_active_offers[offer_index] = offer
		spawn_count += 1


func _offer_candidate_rejection(candidates: Array[Dictionary]) -> Dictionary:
	var accepted_siblings: Array[Dictionary] = []
	for candidate_index in range(candidates.size()):
		var candidate_data: Dictionary = candidates[candidate_index]
		var player_reason := _player_spawn_rejection_reason(candidate_data.position)
		if not player_reason.is_empty():
			return {"reason": player_reason, "candidate_index": candidate_index}
		var reason := _candidate_rejection_reason(
			candidate_data.position,
			candidate_data.band,
			accepted_siblings,
			candidate_index == 0,
			bool(candidate_data.get("allow_right_edge", false))
		)
		if not reason.is_empty():
			return {"reason": reason, "candidate_index": candidate_index}
		accepted_siblings.append(candidate_data)
	return {"reason": "", "candidate_index": -1}


func _player_spawn_rejection_reason(candidate: Vector2) -> String:
	if not is_instance_valid(_conveyor.player):
		return ""
	var player_size := _conveyor.player_collision_size()
	var coin_size := collectible_size
	var player_center := _conveyor.player.global_position
	var actual_overlap := _rectangles_overlap(
		candidate,
		coin_size,
		player_center,
		player_size
	)
	if actual_overlap:
		return REJECTION_PLAYER_OVERLAP
	var padding := maxf(player_spawn_safety_padding, 0.0)
	if padding <= 0.0:
		return ""
	var padded_player_size := player_size + Vector2.ONE * padding * 2.0
	if _rectangles_overlap(candidate, coin_size, player_center, padded_player_size):
		return REJECTION_PLAYER_BUFFER
	return ""


func player_spawn_rejection_reason_for_test(candidate: Vector2) -> String:
	return _player_spawn_rejection_reason(candidate)


func _is_player_safety_rejection(reason: String) -> bool:
	return reason in [REJECTION_PLAYER_OVERLAP, REJECTION_PLAYER_BUFFER]


func _record_player_safety_encounter(reason: String, log_entry: Dictionary = {}) -> void:
	if not _is_player_safety_rejection(reason):
		return
	_player_safety_encounter_counts[reason] = int(
		_player_safety_encounter_counts.get(reason, 0)
	) + 1
	if log_entry.is_empty():
		return
	log_entry.player_safety_rejections = int(log_entry.player_safety_rejections) + 1
	var field := (
		"player_overlap_rejections"
		if reason == REJECTION_PLAYER_OVERLAP
		else "player_buffer_rejections"
	)
	log_entry[field] = int(log_entry.get(field, 0)) + 1


func _whole_offer_relocation_candidates(
	original: Array[Dictionary]
) -> Array[Array]:
	var alternatives: Array[Array] = []
	var original_primary := offer_primary_x_for_test(original)
	if is_nan(original_primary):
		return alternatives
	var used_shifts := PackedFloat32Array([0.0])
	var target_primaries := PackedFloat32Array()
	for configured_x in candidate_x_positions:
		target_primaries.append(configured_x)
	var minimum_x := INF
	var maximum_x := -INF
	for candidate in original:
		minimum_x = minf(minimum_x, float(candidate.position.x))
		maximum_x = maxf(maximum_x, float(candidate.position.x))
	var horizontal_clearance := (
		(_conveyor.player_collision_size().x + collectible_size.x) * 0.5
		+ maxf(player_spawn_safety_padding, 0.0)
		+ 0.01
	)
	var player_x := _conveyor.player.global_position.x
	target_primaries.append(
		original_primary + player_x - horizontal_clearance - maximum_x
	)
	target_primaries.append(
		original_primary + player_x + horizontal_clearance - minimum_x
	)
	for target_primary in target_primaries:
		var alternative := _shift_whole_offer_to_primary_x(original, target_primary)
		if alternative.is_empty():
			continue
		var shift := float(alternative[0].position.x) - float(original[0].position.x)
		var duplicate := false
		for used_shift in used_shifts:
			if is_equal_approx(shift, used_shift):
				duplicate = true
				break
		if duplicate:
			continue
		used_shifts.append(shift)
		alternatives.append(alternative)
	return alternatives


func _shift_whole_offer_to_primary_x(
	original: Array[Dictionary],
	target_primary_x: float
) -> Array[Dictionary]:
	if original.is_empty():
		return []
	var minimum_x := INF
	var maximum_x := -INF
	var allow_right_edge := true
	for candidate in original:
		minimum_x = minf(minimum_x, float(candidate.position.x))
		maximum_x = maxf(maximum_x, float(candidate.position.x))
		allow_right_edge = allow_right_edge and bool(candidate.get("allow_right_edge", false))
	var bounds := _route_bounds()
	if allow_right_edge:
		bounds.y = _conveyor.control_band_right - collectible_size.x * 0.5
	var desired_shift := target_primary_x - offer_primary_x_for_test(original)
	var applied_shift := clampf(
		desired_shift,
		bounds.x - minimum_x,
		bounds.y - maximum_x
	)
	var shifted_candidates: Array[Dictionary] = []
	for candidate in original:
		var shifted: Dictionary = candidate.duplicate(true)
		shifted.position = Vector2(
			float(candidate.position.x) + applied_shift,
			float(candidate.position.y)
		)
		shifted_candidates.append(shifted)
	return shifted_candidates


func _record_subspawn_event(
	event_name: String,
	offer: Dictionary,
	candidate_data: Dictionary,
	reason: String,
	retry_count: int
) -> void:
	_offer_log.append({
		"event": event_name,
		"time": _conveyor.survival_time,
		"phase": phase_at(_conveyor.survival_time),
		"template": int(offer.template),
		"template_name": template_name(int(offer.template)),
		"route_archetype": route_archetype_name(int(offer.template)),
		"candidate_position": candidate_data.position,
		"rejection_reason": reason,
		"retry_count": retry_count,
		"offer_id": int(offer.id),
	})


func _record_skipped_candidate_resolution(offer: Dictionary) -> void:
	var log_index := int(offer.get("log_index", -1))
	if log_index < 0 or log_index >= _offer_log.size():
		return
	_offer_log[log_index].expired = int(offer.expired)
	if (
		int(offer.collected) + int(offer.expired)
		>= int(offer.get("total_count", offer.coins.size()))
	):
		_offer_log[log_index].resolve_timestamp = _conveyor.survival_time


func _reject_attempt(log_entry: Dictionary, reason: String) -> bool:
	var known_reason := reason if reason in known_rejection_reasons() else REJECTION_UNKNOWN
	log_entry.rejection_reason = known_reason
	log_entry.next_scheduled_time = _conveyor.survival_time + failed_spawn_retry_delay
	_offer_log.append(log_entry)
	_rejection_counts[known_reason] = int(_rejection_counts.get(known_reason, 0)) + 1
	return false


func known_rejection_reasons() -> PackedStringArray:
	return PackedStringArray([
		REJECTION_ACTIVE_LIMIT,
		REJECTION_CAN_OVERLAP,
		REJECTION_SWEEPER,
		REJECTION_UNREACHABLE,
		REJECTION_OFF_BELT,
		REJECTION_JUMP_MARGIN,
		REJECTION_LIFETIME,
		REJECTION_SIBLING,
		REJECTION_ROUND_ENDING,
		REJECTION_PLAYER_OVERLAP,
		REJECTION_PLAYER_BUFFER,
		REJECTION_UNKNOWN,
	])


func template_name(template: int) -> String:
	match template:
		OfferTemplate.GROUND_SINGLE:
			return "ground single"
		OfferTemplate.LOW_AIR_ARC:
			return "aerial arc"
		OfferTemplate.SAFE_VERSUS_RISK:
			return "safe coin + risky extension"
		OfferTemplate.HORIZONTAL_LINE:
			return "long commitment trail"
		OfferTemplate.MIXED_ROUTE:
			return "ground-versus-air fork"
		OfferTemplate.COMPACT_BURST:
			return "compact jackpot"
		OfferTemplate.STAGGERED_ROUTE:
			return "staggered aerial route"
	return "unknown"


func route_archetype_name(template: int) -> String:
	match template:
		OfferTemplate.LOW_AIR_ARC:
			return "ARC"
		OfferTemplate.SAFE_VERSUS_RISK:
			return "RISK_TAIL"
		OfferTemplate.HORIZONTAL_LINE:
			return "LINEAR"
		OfferTemplate.MIXED_ROUTE:
			return "STAIR_DOWN"
		OfferTemplate.COMPACT_BURST:
			return "CLUSTER"
		OfferTemplate.STAGGERED_ROUTE:
			return "STAGGER"
	return "LINEAR"


func _template_candidates(
	template: int,
	intended_count: int,
	side_preference: int = -1
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var ground_y := band_center_y(PlacementBand.GROUND)
	var low_y := band_center_y(PlacementBand.LOW_AIR)
	var count := clampi(intended_count, 1, 5)
	var spacing := route_spacing_pixels()
	match template:
		OfferTemplate.GROUND_SINGLE:
			candidates.append({
				"position": Vector2(_candidate_x(0), ground_y),
				"band": PlacementBand.GROUND,
				"allow_right_edge": side_preference in [OfferSide.CENTRED, OfferSide.AHEAD],
				"route_branch": "low_risk",
			})
		OfferTemplate.LOW_AIR_ARC:
			count = clampi(count, 1, 4)
			var arc_span := spacing * float(count - 1)
			var arc_anchor := _candidate_x(2) if count == 1 else _route_anchor_x(arc_span)
			for index in range(count):
				var progress := float(index) / float(maxi(count - 1, 1))
				var rise := sin(progress * PI) * 18.0
				candidates.append({
					"position": Vector2(arc_anchor - spacing * index, low_y + 6.0 - rise),
					"band": PlacementBand.LOW_AIR,
				})
		OfferTemplate.SAFE_VERSUS_RISK:
			count = clampi(count, 3, 4)
			var risk_anchor := _route_anchor_x(spacing * float(count - 1))
			candidates.append({
				"position": Vector2(risk_anchor, ground_y),
				"band": PlacementBand.GROUND,
				"route_branch": "safe_start",
			})
			candidates.append({
				"position": Vector2(risk_anchor - spacing, ground_y),
				"band": PlacementBand.GROUND,
				"route_branch": "safe_continuation",
			})
			candidates.append({
				"position": Vector2(risk_anchor - spacing * 2.0, low_y + 6.0),
				"band": PlacementBand.LOW_AIR,
				"route_branch": "risk_tail_left",
			})
			if count >= 4:
				candidates.append({
					"position": Vector2(risk_anchor - spacing * 0.5, low_y - 20.0),
					"band": PlacementBand.LOW_AIR,
					"route_branch": "risk_tail_reverse",
				})
		OfferTemplate.HORIZONTAL_LINE:
			count = clampi(count, 3, 3)
			var line_span := trail_span_pixels()
			var line_spacing := line_span / float(count - 1)
			var line_anchor := _route_anchor_x(line_span)
			for index in range(count):
				candidates.append({
					"position": Vector2(line_anchor - line_spacing * index, ground_y),
					"band": PlacementBand.GROUND,
					"route_branch": "commitment",
				})
		OfferTemplate.MIXED_ROUTE:
			count = clampi(count, 3, 4)
			var route_bounds := _route_bounds()
			var fork_origin := clampf(
				(route_bounds.x + route_bounds.y) * 0.5,
				route_bounds.x + spacing,
				route_bounds.y - spacing * float(count - 2)
			)
			candidates.append({
				"position": Vector2(fork_origin, ground_y),
				"band": PlacementBand.GROUND,
				"route_branch": "shared",
			})
			candidates.append({
				"position": Vector2(fork_origin - spacing, ground_y),
				"band": PlacementBand.GROUND,
				"route_branch": "ground",
			})
			for index in range(count - 2):
				candidates.append({
					"position": Vector2(fork_origin + spacing * float(index + 1), low_y - float(index) * 12.0),
					"band": PlacementBand.LOW_AIR,
					"route_branch": "air",
				})
		OfferTemplate.COMPACT_BURST:
			count = clampi(count, 3, 3)
			var compact_spacing := collectible_size.x
			var compact_radius := compact_spacing * float(ceili(float(count - 1) * 0.5))
			var compact_bounds := _route_bounds()
			var compact_anchor := clampf(
				_candidate_x(0),
				compact_bounds.x + compact_radius,
				compact_bounds.y - compact_radius
			)
			for index in range(count):
				var signed_offset := 0.0
				if index > 0:
					var magnitude := float((index + 1) / 2) * compact_spacing
					signed_offset = -magnitude if index % 2 == 1 else magnitude
				candidates.append({
					"position": Vector2(compact_anchor + signed_offset, ground_y),
					"band": PlacementBand.GROUND,
					"route_branch": "jackpot",
				})
		OfferTemplate.STAGGERED_ROUTE:
			count = clampi(count, 3, 4)
			var stagger_anchor := _route_anchor_x(spacing * float(count - 1))
			for index in range(count):
				candidates.append({
					"position": Vector2(
						stagger_anchor - spacing * index,
						low_y + 6.0 - float(index % 2) * 20.0
					),
					"band": PlacementBand.LOW_AIR,
					"subspawn_time": staggered_coin_interval * float(index),
					"route_branch": "staggered_air",
				})
	return _translate_candidates_for_side(candidates, side_preference)


func offer_primary_x_for_test(candidates: Array[Dictionary]) -> float:
	if candidates.is_empty():
		return NAN
	var positions: Array[float] = []
	for candidate in candidates:
		positions.append(float(candidate.position.x))
	positions.sort()
	var middle := positions.size() / 2
	if positions.size() % 2 == 1:
		return positions[middle]
	return (positions[middle - 1] + positions[middle]) * 0.5


func classify_offer_side_for_test(
	candidates: Array[Dictionary],
	player_x: float
) -> int:
	var primary_x := offer_primary_x_for_test(candidates)
	if is_nan(primary_x):
		return OfferSide.CENTRED
	var tolerance := (
		_conveyor.player_collision_size().x
		* maxf(offer_side_tolerance_player_widths, 0.0)
	)
	if primary_x < player_x - tolerance:
		return OfferSide.BEHIND
	if primary_x > player_x + tolerance:
		return OfferSide.AHEAD
	return OfferSide.CENTRED


func offer_side_name(side: int) -> String:
	match side:
		OfferSide.BEHIND:
			return "behind"
		OfferSide.AHEAD:
			return "ahead"
	return "centred"


func consecutive_behind_offer_count_for_test() -> int:
	return _consecutive_behind_offers


func _translate_candidates_for_side(
	candidates: Array[Dictionary],
	side_preference: int
) -> Array[Dictionary]:
	if candidates.is_empty() or side_preference not in [
		OfferSide.BEHIND,
		OfferSide.CENTRED,
		OfferSide.AHEAD,
	]:
		return candidates
	var player_width := _conveyor.player_collision_size().x
	var target_x := _conveyor.player.global_position.x
	if side_preference == OfferSide.AHEAD:
		target_x += player_width * ahead_target_offset_player_widths
	elif side_preference == OfferSide.BEHIND:
		target_x -= player_width * ahead_target_offset_player_widths
	var minimum_x := INF
	var maximum_x := -INF
	var allow_right_edge := true
	for candidate in candidates:
		minimum_x = minf(minimum_x, float(candidate.position.x))
		maximum_x = maxf(maximum_x, float(candidate.position.x))
		allow_right_edge = allow_right_edge and bool(candidate.get("allow_right_edge", false))
	var bounds := _route_bounds()
	if allow_right_edge:
		bounds.y = _conveyor.control_band_right - collectible_size.x * 0.5
	var desired_shift := target_x - offer_primary_x_for_test(candidates)
	var applied_shift := clampf(
		desired_shift,
		bounds.x - minimum_x,
		bounds.y - maximum_x
	)
	for index in range(candidates.size()):
		var shifted: Dictionary = candidates[index].duplicate(true)
		shifted.position = Vector2(
			float(candidates[index].position.x) + applied_shift,
			float(candidates[index].position.y)
		)
		candidates[index] = shifted
	return candidates


func route_spacing_pixels() -> float:
	return _conveyor.player_collision_size().x * typical_sibling_spacing_player_widths


func valid_route_width() -> float:
	var bounds := _route_bounds()
	return maxf(bounds.y - bounds.x, 0.0)


func trail_span_pixels() -> float:
	return valid_route_width() * horizontal_trail_span_ratio


func template_candidates_for_test(template: int, intended_count: int) -> Array[Dictionary]:
	return _template_candidates(template, intended_count)


func route_spawn_times_for_test(template: int, intended_count: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for candidate in _template_candidates(template, intended_count):
		result.append(float(candidate.get("subspawn_time", 0.0)))
	return result


func simulate_route_trajectory_for_test(
	template: int,
	trajectory: int,
	intended_count: int = 4
) -> Dictionary:
	var candidates := _template_candidates(template, intended_count)
	if candidates.is_empty():
		return {
			"collected_count": 0,
			"collected_indices": PackedInt32Array(),
			"final_position": Vector2.ZERO,
			"intended_target_count": 0,
		}
	var spawn_times := route_spawn_times_for_test(template, intended_count)
	var collected_flags: Array[bool] = []
	collected_flags.resize(candidates.size())
	collected_flags.fill(false)
	var player_size := _conveyor.player_collision_size()
	var player_position := Vector2(
		candidates[0].position.x,
		_conveyor.floor_y - player_size.y * 0.5
	)
	var relative_velocity_x := 0.0
	var vertical_velocity := 0.0
	var grounded := true
	var jump_times := _trajectory_jump_times(template, trajectory, candidates)
	var next_jump_index := 0
	var simulation_time := 0.0
	var last_spawn_time := float(spawn_times[-1]) if not spawn_times.is_empty() else 0.0
	var simulation_duration := last_spawn_time + collectible_lifetime + 0.35
	var step := maxf(trajectory_simulation_step, 1.0 / 240.0)
	while simulation_time <= simulation_duration + 0.0001:
		for index in range(candidates.size()):
			if collected_flags[index] or simulation_time + 0.0001 < spawn_times[index]:
				continue
			if simulation_time > spawn_times[index] + _candidate_visible_lifetime(candidates[index].position.x):
				continue
			if _trajectory_overlaps_coin(player_position, candidates[index].position, player_size):
				collected_flags[index] = true

		var input_direction := _trajectory_input_direction(template, trajectory, simulation_time)
		if grounded:
			relative_velocity_x = input_direction * _conveyor.player.maximum_speed
		elif not is_zero_approx(input_direction):
			relative_velocity_x = move_toward(
				relative_velocity_x,
				input_direction * _conveyor.player.maximum_speed,
				_conveyor.player.air_acceleration * step
			)
		if (
			next_jump_index < jump_times.size()
			and simulation_time + step * 0.5 >= jump_times[next_jump_index]
			and grounded
		):
			vertical_velocity = _conveyor.player.jump_velocity
			grounded = false
			next_jump_index += 1
		if not grounded:
			vertical_velocity += _conveyor.player.gravity * step
		player_position.x += relative_velocity_x * step
		player_position.x = clampf(
			player_position.x,
			_conveyor.conveyor_support_left_x + player_size.x * 0.5,
			_conveyor.control_band_right
		)
		player_position.y += vertical_velocity * step
		var ground_center_y := _conveyor.floor_y - player_size.y * 0.5
		if player_position.y >= ground_center_y:
			player_position.y = ground_center_y
			vertical_velocity = 0.0
			grounded = true
		simulation_time += step

	var collected_indices := PackedInt32Array()
	for index in range(collected_flags.size()):
		if collected_flags[index]:
			collected_indices.append(index)
	return {
		"collected_count": collected_indices.size(),
		"collected_indices": collected_indices,
		"final_position": player_position,
		"intended_target_count": _trajectory_aggressive_target_count(template, candidates),
	}


func route_action_validation_for_test(template: int, intended_count: int = 4) -> Dictionary:
	var candidates := _template_candidates(template, intended_count)
	var results := {}
	for trajectory in RouteTrajectory.values():
		results[trajectory] = simulate_route_trajectory_for_test(
			template,
			trajectory,
			intended_count
		)
	var total := candidates.size()
	var valid := not candidates.is_empty()
	if template not in [OfferTemplate.GROUND_SINGLE, OfferTemplate.LOW_AIR_ARC, OfferTemplate.COMPACT_BURST]:
		valid = valid and int(results[RouteTrajectory.NO_FURTHER_INPUT].collected_count) < total
	if template in [
		OfferTemplate.MIXED_ROUTE,
		OfferTemplate.STAGGERED_ROUTE,
	]:
		valid = valid and int(results[RouteTrajectory.SAME_INPUT_CONTINUATION].collected_count) < total
	if template in [OfferTemplate.SAFE_VERSUS_RISK, OfferTemplate.MIXED_ROUTE, OfferTemplate.STAGGERED_ROUTE]:
		valid = valid and int(results[RouteTrajectory.PASSIVE_JUMP].collected_count) < total
	var aggressive: Dictionary = results[RouteTrajectory.INTENDED_AGGRESSIVE]
	valid = valid and int(aggressive.collected_count) >= int(aggressive.intended_target_count)
	if template == OfferTemplate.SAFE_VERSUS_RISK:
		var abandonment: Dictionary = results[RouteTrajectory.SAFE_ABANDONMENT]
		var final_position: Vector2 = abandonment.final_position
		valid = (
			valid
			and int(abandonment.collected_count) == 1
			and final_position.x >= _conveyor.conveyor_support_left_x + _conveyor.player_collision_size().x * 0.5
			and final_position.x <= _conveyor.control_band_right
			and is_equal_approx(final_position.y, _conveyor.floor_y - _conveyor.player_collision_size().y * 0.5)
		)
	return {
		"valid": valid,
		"template": template,
		"template_name": template_name(template),
		"positions": candidates.map(func(candidate: Dictionary) -> Vector2: return candidate.position),
		"spawn_times": route_spawn_times_for_test(template, intended_count),
		"results": results,
	}


func _is_post_teaching_route(template: int) -> bool:
	return template in [
		OfferTemplate.SAFE_VERSUS_RISK,
		OfferTemplate.HORIZONTAL_LINE,
		OfferTemplate.MIXED_ROUTE,
		OfferTemplate.COMPACT_BURST,
		OfferTemplate.STAGGERED_ROUTE,
	]


func _trajectory_overlaps_coin(
	player_position: Vector2,
	coin_position: Vector2,
	player_size: Vector2
) -> bool:
	return (
		absf(player_position.x - coin_position.x) <= (player_size.x + collectible_size.x) * 0.5
		and absf(player_position.y - coin_position.y) <= (player_size.y + collectible_size.y) * 0.5
	)


func _trajectory_jump_times(
	template: int,
	trajectory: int,
	candidates: Array[Dictionary]
) -> PackedFloat32Array:
	var first_is_air: bool = int(candidates[0].band) == PlacementBand.LOW_AIR
	match trajectory:
		RouteTrajectory.NO_FURTHER_INPUT:
			return PackedFloat32Array([0.0]) if first_is_air else PackedFloat32Array()
		RouteTrajectory.SAME_INPUT_CONTINUATION:
			return PackedFloat32Array([0.0]) if first_is_air else PackedFloat32Array()
		RouteTrajectory.PASSIVE_JUMP:
			return PackedFloat32Array([0.0])
		RouteTrajectory.INTENDED_AGGRESSIVE:
			match template:
				OfferTemplate.SAFE_VERSUS_RISK:
					return PackedFloat32Array([0.10, 0.82])
				OfferTemplate.MIXED_ROUTE:
					return PackedFloat32Array([0.08])
				OfferTemplate.STAGGERED_ROUTE:
					return PackedFloat32Array([0.0, 0.78, 1.38])
				OfferTemplate.LOW_AIR_ARC:
					return PackedFloat32Array([0.08])
		RouteTrajectory.SAFE_ABANDONMENT:
			return PackedFloat32Array([0.0]) if first_is_air else PackedFloat32Array()
	return PackedFloat32Array()


func _trajectory_input_direction(template: int, trajectory: int, time_seconds: float) -> float:
	match trajectory:
		RouteTrajectory.NO_FURTHER_INPUT:
			return 0.0
		RouteTrajectory.SAME_INPUT_CONTINUATION:
			return 0.0 if template == OfferTemplate.COMPACT_BURST else -1.0
		RouteTrajectory.PASSIVE_JUMP:
			return -1.0
		RouteTrajectory.SAFE_ABANDONMENT:
			return 1.0 if time_seconds < 0.22 else 0.0
		RouteTrajectory.INTENDED_AGGRESSIVE:
			match template:
				OfferTemplate.SAFE_VERSUS_RISK:
					return -1.0 if time_seconds < 0.45 else 1.0
				OfferTemplate.MIXED_ROUTE:
					return 1.0
				OfferTemplate.COMPACT_BURST:
					return 0.0
				OfferTemplate.STAGGERED_ROUTE:
					if time_seconds >= 0.20 and time_seconds < 0.55:
						return -1.0
					if time_seconds >= 0.78 and time_seconds < 1.02:
						return -1.0
					if time_seconds >= 1.36 and time_seconds < 1.58:
						return 1.0
					return 0.0
			return -1.0
	return 0.0


func _trajectory_aggressive_target_count(
	template: int,
	candidates: Array[Dictionary]
) -> int:
	if template == OfferTemplate.MIXED_ROUTE:
		var target := 0
		for candidate in candidates:
			if candidate.get("route_branch", "") != "ground":
				target += 1
		return target
	return candidates.size()


func _route_bounds() -> Vector2:
	var half_width := collectible_size.x * 0.5
	var left := (
		_conveyor.conveyor_support_left_x
		+ half_width
		+ _conveyor.conveyor_speed * (reachability_reserve + minimum_route_response_time)
	)
	var right := minf(
		_conveyor.control_band_right - half_width,
		_conveyor.right_edge_zone_left() - safe_edge_exclusion
	)
	return Vector2(left, maxf(left, right))


func _route_anchor_x(route_span: float) -> float:
	var bounds := _route_bounds()
	var clamped_span := minf(maxf(route_span, 0.0), bounds.y - bounds.x)
	var desired := _candidate_x(0)
	return clampf(desired, bounds.x + clamped_span, bounds.y)


func _candidate_x(index: int) -> float:
	if candidate_x_positions.is_empty():
		return 600.0
	return candidate_x_positions[mini(index, candidate_x_positions.size() - 1)]


func _candidate_rejection_reason(
	candidate: Vector2,
	band: int,
	siblings: Array[Dictionary],
	enforce_current_reachability: bool = true,
	allow_right_edge: bool = false
) -> String:
	if collectible_lifetime <= reachability_reserve or collectible_lifetime <= 0.0:
		return REJECTION_LIFETIME
	var half_size := collectible_size * 0.5
	var risky_right_limit := (
		_conveyor.control_band_right - half_size.x
		if allow_right_edge
		else _conveyor.right_edge_zone_left() - safe_edge_exclusion
	)
	if candidate.x - half_size.x < _conveyor.belt_left_x or candidate.x + half_size.x > _conveyor.control_band_right or candidate.x > risky_right_limit or candidate.y - half_size.y <= 0.0 or candidate.y + half_size.y > _conveyor.floor_y:
		return REJECTION_OFF_BELT
	if _candidate_available_time(candidate.x) <= 0.0:
		return REJECTION_OFF_BELT
	if band == PlacementBand.LOW_AIR and normal_jump_collection_margin(candidate.y) < minimum_normal_jump_margin:
		return REJECTION_JUMP_MARGIN
	if enforce_current_reachability and not candidate_is_reachable(candidate, band):
		return REJECTION_UNREACHABLE
	for sibling in siblings:
		if _rectangles_overlap(candidate, collectible_size, sibling.position, collectible_size):
			return REJECTION_SIBLING
	for existing in active_collectibles():
		if _rectangles_overlap(candidate, collectible_size, existing.global_position, existing.collectible_size):
			return REJECTION_SIBLING
	if _can_hazard_conflicts(candidate):
		return REJECTION_CAN_OVERLAP
	if _sweeper_schedule_conflicts(candidate, band):
		return REJECTION_SWEEPER
	return ""


func _offer_has_reachable_response(candidates: Array[Dictionary]) -> bool:
	for candidate in candidates:
		if candidate_is_reachable(candidate.position, candidate.band):
			return true
	return false


func _can_hazard_conflicts(candidate: Vector2) -> bool:
	for product in _conveyor.active_falling_products():
		if _falling_can_path_conflicts(candidate, product):
			return true
	for product in _conveyor.active_landed_products():
		var landed_center := Vector2(product.conveyor_center_x(), product.global_position.y)
		if _rectangles_overlap(candidate, collectible_size, landed_center, product.landed_size):
			return true
	return _warning_or_reserved_can_conflicts(candidate.x)


func _falling_can_path_conflicts(candidate: Vector2, product: ConveyorProduct) -> bool:
	var coin_left_at_expiry := candidate.x - _conveyor.conveyor_speed * _candidate_visible_lifetime(candidate.x)
	var half_width_sum := (collectible_size.x + product.falling_size.x) * 0.5
	return product.global_position.x >= coin_left_at_expiry - half_width_sum and product.global_position.x <= candidate.x + half_width_sum


func _warning_or_reserved_can_conflicts(candidate_x: float) -> bool:
	var possible_x_positions := PackedFloat32Array()
	var warning_x := _conveyor.current_warning_x()
	if not is_nan(warning_x):
		possible_x_positions.append(warning_x)
	var active_pattern := _conveyor.active_pattern_type()
	var reserved_pattern := _conveyor.reserved_pattern_type()
	if _pattern_includes_can(active_pattern) or _pattern_includes_can(reserved_pattern):
		for lane_x in _conveyor.drop_lane_positions:
			possible_x_positions.append(lane_x)
	if active_pattern == ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE or reserved_pattern == ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE or _conveyor.right_pressure_is_requested():
		var target_x := _conveyor.right_pressure_target_x()
		if not is_nan(target_x):
			possible_x_positions.append(target_x)
	var coin_left_at_expiry := candidate_x - _conveyor.conveyor_speed * _candidate_visible_lifetime(candidate_x)
	var half_width_sum := (collectible_size.x + _conveyor.product_size.x) * 0.5
	for possible_x in possible_x_positions:
		if possible_x >= coin_left_at_expiry - half_width_sum and possible_x <= candidate_x + half_width_sum:
			return true
	return false


func _sweeper_schedule_conflicts(candidate: Vector2, band: int) -> bool:
	for sweeper in _conveyor.active_sweepers():
		if _rectangles_overlap(candidate, collectible_size, sweeper.global_position, sweeper.hazard_size):
			return true
	if band == PlacementBand.GROUND:
		return false
	var sweeper_planned := (
		_conveyor.sweeper_cue_is_visible()
		or _pattern_includes_sweeper(_conveyor.active_pattern_type())
		or _pattern_includes_sweeper(_conveyor.reserved_pattern_type())
		or _conveyor.active_sweeper_count() > 0
	)
	if not sweeper_planned:
		return false
	var jump_intervals := normal_jump_collection_intervals(candidate.y)
	if jump_intervals.is_empty():
		return true
	var collection_choice_window := (
		_candidate_available_time(candidate.x)
		- jump_intervals[0].x
	)
	var closing_speed := (
		_conveyor.sweeper_speed_at(_conveyor.survival_time)
		+ _conveyor.conveyor_speed
	)
	if closing_speed <= 0.0:
		return true
	var blocked_duration := (
		(_conveyor.sweeper_size.x + collectible_size.x) / closing_speed
	)
	# A planned Sweeper is a risk, but it rejects the route only if its projected
	# occupancy consumes the entire available jump-choice window.
	return blocked_duration + 0.0001 >= collection_choice_window


func _select_natural_template() -> int:
	if _natural_offer_count == 0:
		_pending_teaching_template = OfferTemplate.GROUND_SINGLE
		return OfferTemplate.GROUND_SINGLE
	if _natural_offer_count == 1:
		_pending_teaching_template = OfferTemplate.LOW_AIR_ARC
		return OfferTemplate.LOW_AIR_ARC
	# Establish each authored category once during the early run. Compact
	# jackpots remain excluded as fallback replacements, so this one guaranteed
	# appearance does not let them dominate rejected-route rotation.
	if _natural_offer_count < 7:
		return [
			OfferTemplate.HORIZONTAL_LINE,
			OfferTemplate.MIXED_ROUTE,
			OfferTemplate.SAFE_VERSUS_RISK,
			OfferTemplate.STAGGERED_ROUTE,
			OfferTemplate.COMPACT_BURST,
		][_natural_offer_count - 2]
	_placement_rng_state = _next_rng_state(_placement_rng_state)
	var weights := _template_weights_at(_conveyor.survival_time)
	var total := 0
	for weight in weights:
		total += maxi(weight, 0)
	if total <= 0:
		return OfferTemplate.GROUND_SINGLE
	var roll := posmod(_placement_rng_state, total)
	for index in range(weights.size()):
		roll -= maxi(weights[index], 0)
		if roll < 0:
			return _avoid_recent_template_repeat(index, weights)
	return OfferTemplate.MIXED_ROUTE


func _should_request_centred_ahead_offer() -> bool:
	if (
		not side_distribution_correction_enabled
		or _natural_offer_count < 2
		or _consecutive_behind_offers < maxi(maximum_consecutive_behind_offers, 1)
	):
		return false
	var configured_weight := clampf(centred_ahead_after_behind_weight, 0.0, 1.0)
	if configured_weight >= 1.0:
		return true
	if configured_weight <= 0.0:
		return false
	_placement_rng_state = _next_rng_state(_placement_rng_state)
	var threshold := roundi(configured_weight * 10000.0)
	return posmod(_placement_rng_state, 10000) < threshold


func _update_offer_side_history(side: int) -> void:
	if side == OfferSide.BEHIND:
		_consecutive_behind_offers += 1
	else:
		_consecutive_behind_offers = 0


func _avoid_recent_template_repeat(selected: int, weights: PackedInt32Array) -> int:
	if not _recent_natural_templates.has(selected):
		return selected
	for offset in range(1, weights.size()):
		var alternative := posmod(selected + offset, weights.size())
		if weights[alternative] > 0 and not _recent_natural_templates.has(alternative):
			return alternative
	return selected


func _remember_natural_template(template: int) -> void:
	_recent_natural_templates.append(template)
	while _recent_natural_templates.size() > maxi(recent_route_history_size, 0):
		_recent_natural_templates.pop_front()


func _template_weights_at(time_seconds: float) -> PackedInt32Array:
	match phase_at(time_seconds):
		0:
			return phase_one_template_weights
		1:
			return phase_two_template_weights
		2:
			return phase_three_template_weights
	return phase_four_template_weights


func _select_intended_count(template: int) -> int:
	var configured := coin_range_at(_conveyor.survival_time)
	var count := configured.x
	if template == OfferTemplate.GROUND_SINGLE:
		return 1
	if template == OfferTemplate.LOW_AIR_ARC:
		return maxi(count, 2)
	if template == OfferTemplate.SAFE_VERSUS_RISK:
		return 4
	return maxi(count, 3)


func _select_cadence() -> float:
	var configured := cadence_range_at(_conveyor.survival_time)
	# Wider decision routes contain at least three independent pickups. Spacing
	# launches out so the 60-second offered-coin economy remains comparable to
	# the pre-separation baseline without changing coin value.
	return minf(
		configured.y * maxf(decision_route_cadence_multiplier, 1.0),
		maxf(maximum_offer_free_gap - 0.05, configured.y)
	)


func _can_open_another_offer() -> bool:
	if _active_offers.size() >= maximum_active_offers:
		return false
	if _active_offers.is_empty():
		return true
	var oldest_spawn := INF
	for offer in _active_offers:
		oldest_spawn = minf(oldest_spawn, float(offer.spawn_time))
	return _conveyor.survival_time - oldest_spawn >= collectible_lifetime - bounded_overlap_duration


func _refresh_active_offers() -> void:
	for index in range(_active_offers.size() - 1, -1, -1):
		var offer: Dictionary = _active_offers[index]
		var unresolved: bool = not offer.get("pending_candidates", []).is_empty()
		for coin in offer.coins:
			if is_instance_valid(coin) and not coin.is_resolved():
				unresolved = true
				break
		if not unresolved:
			_active_offers.remove_at(index)


func _update_active_coin_speeds() -> void:
	for coin in active_collectibles():
		coin.scroll_speed = _conveyor.conveyor_speed


func _enforce_scheduling_invariant() -> void:
	if _conveyor.gameplay_is_stopped() or _stopped:
		return
	if not is_finite(_next_spawn_time):
		_record_invariant(REJECTION_UNKNOWN)
		_next_spawn_time = _conveyor.survival_time + failed_spawn_retry_delay
	if _last_offer_spawn_time >= 0.0 and active_offer_count() == 0 and _conveyor.survival_time - _last_offer_spawn_time > maximum_offer_free_gap and _next_spawn_time > _conveyor.survival_time + failed_spawn_retry_delay:
		_record_invariant("watchdog retry")
		_next_spawn_time = _conveyor.survival_time + failed_spawn_retry_delay


func _record_invariant(reason: String) -> void:
	_offer_log.append({
		"event": "invariant",
		"time": _conveyor.survival_time,
		"phase": phase_at(_conveyor.survival_time),
		"template": -1,
		"template_name": "none",
		"intended_count": 0,
		"ground_count": 0,
		"air_count": 0,
		"intended_ground_count": 0,
		"intended_low_air_count": 0,
		"accepted": false,
		"rejection_reason": reason,
		"spawn_timestamp": -1.0,
		"resolve_timestamp": -1.0,
		"spawned_offer_id": -1,
		"resolved_offer_id": -1,
		"collected": 0,
		"expired": 0,
		"next_scheduled_time": _next_spawn_time,
		"active_offer_count": active_offer_count(),
		"active_coin_count": active_collectible_count(),
		"active_offer_state": _active_offer_state(),
		"natural": true,
	})


func _resolve_coin(coin: ConveyorCollectible, offer_id: int, collected: bool) -> void:
	for index in range(_active_offers.size()):
		var offer: Dictionary = _active_offers[index]
		if int(offer.id) != offer_id:
			continue
		if collected:
			offer.collected = int(offer.collected) + 1
			score += 1
			_update_score_label()
			_pulse_score_hud()
			score_changed.emit(score)
		else:
			offer.expired = int(offer.expired) + 1
		_active_offers[index] = offer
		var log_index := int(offer.log_index)
		if log_index >= 0 and log_index < _offer_log.size():
			_offer_log[log_index].collected = int(offer.collected)
			_offer_log[log_index].expired = int(offer.expired)
			_offer_log[log_index].resolved_offer_id = offer_id
			if int(offer.collected) + int(offer.expired) >= int(offer.get("total_count", offer.coins.size())):
				_offer_log[log_index].resolve_timestamp = _conveyor.survival_time
			_offer_log[log_index].active_offer_state = _active_offer_state()
		break
	call_deferred("_refresh_active_offers")


func _on_collectible_collected(collectible: ConveyorCollectible, offer_id: int) -> void:
	_resolve_coin(collectible, offer_id, true)


func _on_collectible_expired(collectible: ConveyorCollectible, offer_id: int) -> void:
	_resolve_coin(collectible, offer_id, false)


func _on_player_died() -> void:
	stop_for_round_end()


func _resolve_band(candidate: Vector2, requested_band: int) -> int:
	if requested_band in [PlacementBand.GROUND, PlacementBand.LOW_AIR]:
		return requested_band
	return PlacementBand.GROUND if _grounded_player_overlaps_y(candidate.y) else PlacementBand.LOW_AIR


func _grounded_player_overlaps_y(coin_center_y: float) -> bool:
	var player_center_y := _conveyor.floor_y - _conveyor.player_collision_size().y * 0.5
	return absf(coin_center_y - player_center_y) <= (_conveyor.player_collision_size().y + collectible_size.y) * 0.5


func _jump_ascent_time_at_center_y(target_center_y: float) -> float:
	var start_center_y := _conveyor.floor_y - _conveyor.player_collision_size().y * 0.5
	var displacement_up := start_center_y - target_center_y
	var launch_speed := absf(_conveyor.player.jump_velocity)
	var discriminant := launch_speed * launch_speed - 2.0 * _conveyor.player.gravity * displacement_up
	if displacement_up < 0.0 or discriminant < 0.0:
		return -1.0
	return (launch_speed - sqrt(discriminant)) / _conveyor.player.gravity


func _next_rng_state(state: int) -> int:
	return (state * 1103515245 + 12345) & 0x7fffffff


func _band_from_roll(roll_source: int) -> int:
	var ground_threshold := roundi(clampf(ground_probability_after_first, 0.0, 1.0) * 10000.0)
	return PlacementBand.GROUND if posmod(roll_source, 10000) < ground_threshold else PlacementBand.LOW_AIR


func _pattern_includes_can(pattern_type: int) -> bool:
	return pattern_type in [
		ConveyorPrototype.PatternType.CAN_ONLY,
		ConveyorPrototype.PatternType.SWEEPER_THEN_CAN,
		ConveyorPrototype.PatternType.CAN_THEN_SWEEPER,
		ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE,
	]


func _pattern_includes_sweeper(pattern_type: int) -> bool:
	return pattern_type in [
		ConveyorPrototype.PatternType.SWEEPER_ONLY,
		ConveyorPrototype.PatternType.SWEEPER_THEN_CAN,
		ConveyorPrototype.PatternType.CAN_THEN_SWEEPER,
		ConveyorPrototype.PatternType.RIGHT_EDGE_PRESSURE,
	]


func _active_offer_state() -> Array[Dictionary]:
	var state: Array[Dictionary] = []
	for offer in _active_offers:
		var unresolved := 0
		for coin in offer.coins:
			if is_instance_valid(coin) and not coin.is_resolved():
				unresolved += 1
		state.append({
			"offer_id": int(offer.id),
			"template": int(offer.template),
			"unresolved": unresolved,
			"pending": offer.get("pending_candidates", []).size(),
		})
	return state


func _rectangles_overlap(first_center: Vector2, first_size: Vector2, second_center: Vector2, second_size: Vector2) -> bool:
	return absf(first_center.x - second_center.x) < (first_size.x + second_size.x) * 0.5 and absf(first_center.y - second_center.y) < (first_size.y + second_size.y) * 0.5


func _update_score_label() -> void:
	_score_label.text = str(score)


func _pulse_score_hud() -> void:
	_score_pulse_remaining = maxf(score_hud_pulse_duration, 0.0)
	_score_pulse_count += 1
	_score_label.scale = Vector2.ONE * score_hud_pulse_scale
	_score_label.add_theme_color_override("font_color", score_hud_pulse_color)


func _update_score_hud_pulse(delta: float) -> void:
	if _score_pulse_remaining <= 0.0:
		return
	_score_pulse_remaining = maxf(_score_pulse_remaining - delta, 0.0)
	var progress := 1.0 - _score_pulse_remaining / maxf(score_hud_pulse_duration, 0.0001)
	var scale_value := lerpf(score_hud_pulse_scale, 1.0, progress)
	_score_label.scale = Vector2.ONE * scale_value
	if _score_pulse_remaining <= 0.0:
		_reset_score_hud_pulse()


func _reset_score_hud_pulse() -> void:
	_score_pulse_remaining = 0.0
	if not is_instance_valid(_score_label):
		return
	_score_label.scale = Vector2.ONE
	_score_label.add_theme_font_size_override(
		"font_size",
		score_hud_normal_font_size
	)
	_score_label.add_theme_color_override("font_color", score_hud_normal_color)
