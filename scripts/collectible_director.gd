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

enum BallisticArchetype {
	SHALLOW,
	MEDIUM,
	HIGH,
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

const SCATTER_TEMPLATE := -2

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
const REJECTION_SCATTER_EXHAUSTED := "scatter retries exhausted"
const REJECTION_D3_PRIORITY := "D3 priority"
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

@export_category("Constrained Scatter")
@export var scatter_offer_count_weights := PackedInt32Array([0, 10, 90])
@export_range(0.0, 1.0, 0.01) var scatter_pair_mode_probability: float = 0.15
@export_range(0.5, 1.25, 0.01) var scatter_cadence_multiplier: float = 0.84
@export var minimum_scatter_separation: float = 120.0
@export var pair_mode_separation: float = 64.0
@export var maximum_scatter_layout_attempts: int = 96
@export var scatter_position_quantum: float = 4.0
@export var scatter_collinearity_area_threshold: float = 600.0

@export_category("Independent Coin Stream")
@export var independent_stream_enabled: bool = true
@export var independent_spawn_interval_range := Vector2(0.75, 1.70)
@export var maximum_active_independent_coins: int = 5
@export_range(0.0, 1.0, 0.01) var independent_bonus_probability: float = 0.10
@export var independent_bonus_delay_range := Vector2(0.10, 0.30)
@export var maximum_bonus_placement_cycles: int = 4
@export var independent_lifetime_range := Vector2(2.50, 4.00)
@export var independent_expiry_warning_duration: float = 0.70
@export var independent_minimum_separation: float = 120.0
@export var independent_bonus_minimum_separation: float = 96.0
@export var maximum_independent_placement_attempts: int = 96
@export var d3_priority_clearance_time: float = 0.20

@export_category("Variable Coin Events")
@export var variable_coin_events_enabled: bool = true
@export var coin_event_interval_range := Vector2(1.10, 2.10)
@export var coin_event_size_weights := PackedInt32Array([55, 35, 10])
@export var single_event_side_weights := PackedInt32Array([35, 20, 45])
@export var minimum_guaranteed_visible_lifetime: float = 1.65
@export var coin_event_minimum_separation: float = 110.0
@export var coin_event_sibling_minimum_separation: float = 96.0

@export_category("Ballistic Coin Prototype")
@export var ballistic_coin_events_enabled: bool = false
@export var ballistic_launch_origins := PackedVector2Array([
	Vector2(840.0, 300.0),
	Vector2(720.0, 260.0),
	Vector2(620.0, 220.0),
])
@export var ballistic_flight_durations := PackedFloat32Array([0.72, 0.90, 1.10])
@export var ballistic_gravity: float = 1250.0
@export var ballistic_bounce_restitutions := Vector2(0.38, 0.16)
@export var ballistic_post_contact_lifetime_range := Vector2(2.0, 3.0)
@export var ballistic_minimum_post_contact_visible_lifetime: float = 2.0
@export var ballistic_minimum_trajectory_separation: float = 44.0

@export_category("Ballistic Abundance Prototype")
@export var ballistic_abundance_enabled: bool = false
@export_range(0.0, 1.0, 0.01) var ballistic_double_stagger_probability: float = 0.50
@export_range(0.0, 1.0, 0.01) var ballistic_triple_stagger_probability: float = 0.75
@export var ballistic_double_stagger_delay_range := Vector2(0.10, 0.30)
@export var ballistic_triple_stagger_delay_range := Vector2(0.10, 0.25)
@export var ballistic_launch_origin_variance := Vector2(20.0, 16.0)
@export_range(0.0, 0.10, 0.005) var ballistic_flight_duration_variance_ratio: float = 0.075
@export var ballistic_maximum_landed_can_ricochets: int = 2
@export var ballistic_can_top_restitution: float = 0.34
@export var ballistic_can_side_horizontal_restitution: float = 0.35
@export var ballistic_can_side_upward_speed: float = 180.0
@export var ballistic_can_horizontal_deflection: float = 70.0

@export_category("Ballistic Integrity Prototype")
@export var ballistic_integrity_enabled: bool = false
@export var ballistic_group_candidate_pool_size: int = 4
@export var ballistic_group_member_placement_attempts: int = 12
@export var ballistic_group_combination_checks: int = 64
@export var ballistic_single_placement_attempts: int = 48

@export_category("Performance Diagnostics")
@export var performance_profiling_enabled: bool = false

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
var _last_scatter_layout_attempts: int = 0
var _scatter_exhausted_count: int = 0
var _stream_rng_state: int = 401
var _pending_bonus_spawn_time: float = INF
var _pending_bonus: bool = false
var _normal_stream_spawn_count: int = 0
var _bonus_stream_spawn_count: int = 0
var _stream_cap_skip_count: int = 0
var _stream_priority_skip_count: int = 0
var _stream_attempt_count: int = 0
var _stream_lifetime_log := PackedFloat32Array()
var _coin_event_count: int = 0
var _coin_event_size_counts := PackedInt32Array([0, 0, 0, 0])
var _coin_event_cap_truncated_event_count: int = 0
var _coin_event_cap_truncated_coin_count: int = 0
var _coin_event_placement_failure_count: int = 0
var _coin_event_log: Array[Dictionary] = []
var _last_stream_spawn_position := Vector2.ZERO
var _last_stream_effective_lifetime: float = 0.0
var _last_stream_spawn_side: int = OfferSide.CENTRED
var _last_ballistic_plan: Dictionary = {}
var _ballistic_archetype_counts := PackedInt32Array([0, 0, 0])
var _ballistic_trajectory_failure_count: int = 0
var _ballistic_first_contact_count: int = 0
var _ballistic_settled_count: int = 0
var _ballistic_flight_log := PackedFloat32Array()
var _ballistic_post_contact_lifetime_log := PackedFloat32Array()
var _ballistic_launch_side_counts := PackedInt32Array([0, 0, 0])
var _ballistic_landing_side_counts := PackedInt32Array([0, 0, 0])
var _ballistic_settle_side_counts := PackedInt32Array([0, 0, 0])
var _ballistic_player_crossing_count: int = 0
var _ballistic_simultaneous_multi_event_count: int = 0
var _ballistic_staggered_multi_event_count: int = 0
var _ballistic_collection_counts := {
	"AIRBORNE": 0,
	"BOUNCING": 0,
	"SETTLED": 0,
}
var _ballistic_expired_count: int = 0
var _ballistic_exited_left_count: int = 0
var _ballistic_total_ricochet_count: int = 0
var _ballistic_collection_time_total: float = 0.0
var _ballistic_collection_time_samples: int = 0
var _ballistic_full_double_count: int = 0
var _ballistic_full_triple_count: int = 0
var _ballistic_degraded_double_count: int = 0
var _ballistic_degraded_triple_count: int = 0
var _ballistic_group_degradation_reasons: Dictionary = {}
var _performance_event_log: Array[Dictionary] = []
var _performance_current_event_started_usec: int = 0
var _performance_current_event_placement_attempts: int = 0
var _performance_current_event_trajectory_checks: int = 0
var _performance_landed_can_query_count: int = 0
var _performance_landed_can_rect_count: int = 0
var _performance_landed_can_cache_rebuild_count: int = 0
var _landed_can_collision_cache: Array[Dictionary] = []
var _landed_can_collision_cache_frame: int = -1

@onready var _conveyor: ConveyorPrototype = get_parent() as ConveyorPrototype
@onready var _score_label: Label = _conveyor.get_node("HUD/ScoreGroup/CollectibleScore")


func _ready() -> void:
	_next_spawn_time = clampf(first_spawn_time, first_spawn_window_min, first_spawn_window_max)
	_placement_rng_state = placement_seed
	_stream_rng_state = maxi(posmod(placement_seed * 1664525 + 1013904223, 0x7fffffff), 1)
	_update_score_label()
	_conveyor.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	_update_score_hud_pulse(delta)
	if _stopped or _conveyor.gameplay_is_stopped():
		return
	_update_staggered_offers()
	_refresh_active_offers()
	_update_active_coin_speeds()
	_update_ballistic_player_crossings()
	if independent_stream_enabled and not variable_coin_events_enabled:
		_update_pending_bonus_spawn()
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


func scatter_exhausted_count() -> int:
	return _scatter_exhausted_count


func normal_stream_spawn_count() -> int:
	return _normal_stream_spawn_count


func bonus_stream_spawn_count() -> int:
	return _bonus_stream_spawn_count


func stream_cap_skip_count() -> int:
	return _stream_cap_skip_count


func stream_priority_skip_count() -> int:
	return _stream_priority_skip_count


func stream_attempt_count() -> int:
	return _stream_attempt_count


func stream_lifetime_log() -> PackedFloat32Array:
	return _stream_lifetime_log.duplicate()


func pending_bonus_spawn_time() -> float:
	return _pending_bonus_spawn_time


func coin_event_count() -> int:
	return _coin_event_count


func coin_event_size_counts() -> PackedInt32Array:
	return _coin_event_size_counts.duplicate()


func coin_event_cap_truncated_event_count() -> int:
	return _coin_event_cap_truncated_event_count


func coin_event_cap_truncated_coin_count() -> int:
	return _coin_event_cap_truncated_coin_count


func coin_event_placement_failure_count() -> int:
	return _coin_event_placement_failure_count


func coin_event_log() -> Array[Dictionary]:
	return _coin_event_log.duplicate(true)


func ballistic_archetype_counts() -> PackedInt32Array:
	return _ballistic_archetype_counts.duplicate()


func ballistic_trajectory_failure_count() -> int:
	return _ballistic_trajectory_failure_count


func ballistic_first_contact_count() -> int:
	return _ballistic_first_contact_count


func ballistic_settled_count() -> int:
	return _ballistic_settled_count


func ballistic_flight_log() -> PackedFloat32Array:
	return _ballistic_flight_log.duplicate()


func ballistic_post_contact_lifetime_log() -> PackedFloat32Array:
	return _ballistic_post_contact_lifetime_log.duplicate()


func ballistic_landing_side_counts() -> PackedInt32Array:
	return _ballistic_landing_side_counts.duplicate()


func ballistic_launch_side_counts() -> PackedInt32Array:
	return _ballistic_launch_side_counts.duplicate()


func ballistic_settle_side_counts() -> PackedInt32Array:
	return _ballistic_settle_side_counts.duplicate()


func ballistic_player_crossing_count() -> int:
	return _ballistic_player_crossing_count


func ballistic_simultaneous_multi_event_count() -> int:
	return _ballistic_simultaneous_multi_event_count


func ballistic_staggered_multi_event_count() -> int:
	return _ballistic_staggered_multi_event_count


func ballistic_collection_counts() -> Dictionary:
	return _ballistic_collection_counts.duplicate(true)


func ballistic_expired_count() -> int:
	return _ballistic_expired_count


func ballistic_exited_left_count() -> int:
	return _ballistic_exited_left_count


func ballistic_total_ricochet_count() -> int:
	return _ballistic_total_ricochet_count


func ballistic_collection_rate() -> float:
	return (
		float(_ballistic_collection_time_samples) / float(spawn_count)
		if spawn_count > 0
		else 0.0
	)


func ballistic_average_launch_to_collection_time() -> float:
	return (
		_ballistic_collection_time_total / float(_ballistic_collection_time_samples)
		if _ballistic_collection_time_samples > 0
		else 0.0
	)


func ballistic_run_summary() -> Dictionary:
	var collections := ballistic_collection_counts()
	var collected_total := (
		int(collections.get("AIRBORNE", 0))
		+ int(collections.get("BOUNCING", 0))
		+ int(collections.get("SETTLED", 0))
	)
	var result := {
		"delivered": spawn_count,
		"collected": collected_total,
		"airborne": int(collections.get("AIRBORNE", 0)),
		"bouncing": int(collections.get("BOUNCING", 0)),
		"settled": int(collections.get("SETTLED", 0)),
		"expired": _ballistic_expired_count,
		"exited_left": _ballistic_exited_left_count,
		"landed_can_ricochets": _ballistic_total_ricochet_count,
		"collection_rate": ballistic_collection_rate(),
		"average_launch_to_collection_time": ballistic_average_launch_to_collection_time(),
	}
	if ballistic_integrity_enabled:
		result.merge(ballistic_integrity_summary())
	return result


func ballistic_integrity_summary() -> Dictionary:
	var selected_doubles := int(_coin_event_size_counts[2])
	var selected_triples := int(_coin_event_size_counts[3])
	return {
		"selected_singles": int(_coin_event_size_counts[1]),
		"selected_doubles": selected_doubles,
		"selected_triples": selected_triples,
		"full_doubles": _ballistic_full_double_count,
		"full_triples": _ballistic_full_triple_count,
		"degraded_doubles": _ballistic_degraded_double_count,
		"degraded_triples": _ballistic_degraded_triple_count,
		"double_integrity_rate": (
			float(_ballistic_full_double_count) / float(selected_doubles)
			if selected_doubles > 0
			else 0.0
		),
		"triple_integrity_rate": (
			float(_ballistic_full_triple_count) / float(selected_triples)
			if selected_triples > 0
			else 0.0
		),
		"degradation_reasons": _ballistic_group_degradation_reasons.duplicate(true),
	}


func performance_event_log() -> Array[Dictionary]:
	return _performance_event_log.duplicate(true)


func performance_landed_can_query_count() -> int:
	return _performance_landed_can_query_count


func performance_landed_can_rect_count() -> int:
	return _performance_landed_can_rect_count


func performance_profile_summary() -> Dictionary:
	var durations := PackedFloat32Array()
	var placement_attempts := 0
	var trajectory_checks := 0
	for event in _performance_event_log:
		durations.append(float(event.get("planning_ms", 0.0)))
		placement_attempts += int(event.get("placement_attempts", 0))
		trajectory_checks += int(event.get("trajectory_checks", 0))
	var duration_total := 0.0
	var duration_maximum := 0.0
	for duration in durations:
		duration_total += duration
		duration_maximum = maxf(duration_maximum, duration)
	return {
		"event_count": durations.size(),
		"average_planning_ms": (
			duration_total / float(durations.size())
			if not durations.is_empty()
			else 0.0
		),
		"maximum_planning_ms": duration_maximum,
		"placement_attempts": placement_attempts,
		"trajectory_checks": trajectory_checks,
		"landed_can_queries": _performance_landed_can_query_count,
		"landed_can_rects_returned": _performance_landed_can_rect_count,
		"landed_can_cache_rebuilds": _performance_landed_can_cache_rebuild_count,
	}


func last_scatter_layout_attempts() -> int:
	return _last_scatter_layout_attempts


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


func try_spawn_scatter_for_test(intended_count: int, pair_mode: bool = false) -> bool:
	return _try_spawn_template(
		SCATTER_TEMPLATE,
		intended_count,
		false,
		-1,
		false,
		pair_mode
	)


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
	if _stopped:
		return
	_stopped = true
	if ballistic_coin_events_enabled and ballistic_integrity_enabled:
		print("VM069_COIN_SUMMARY ", JSON.stringify(ballistic_run_summary()))
	elif ballistic_coin_events_enabled and ballistic_abundance_enabled:
		print("VM068_COIN_SUMMARY ", JSON.stringify(ballistic_run_summary()))
	set_process(false)
	_pending_bonus = false
	_pending_bonus_spawn_time = INF
	_reset_score_hud_pulse()
	for offer in _active_offers:
		offer.pending_candidates = []
	for child in get_children():
		if child is ConveyorCollectible:
			child.stop()


func _try_spawn_natural_offer() -> bool:
	if independent_stream_enabled:
		if variable_coin_events_enabled:
			return _try_spawn_variable_coin_event()
		return _try_spawn_natural_stream_coin()
	var anti_streak_requested := _should_request_centred_ahead_offer()
	var intended_count := 1 if _natural_offer_count == 0 else _select_scatter_count()
	if anti_streak_requested:
		intended_count = mini(intended_count, 2)
	var pair_mode := intended_count >= 2 and _select_scatter_pair_mode()
	var side_preferences: Array[int] = [-1]
	if anti_streak_requested:
		side_preferences = _scatter_correction_side_preferences()
	for side_preference in side_preferences:
		if _try_spawn_template(
			SCATTER_TEMPLATE,
			intended_count,
			true,
			int(side_preference),
			anti_streak_requested,
			pair_mode
		):
			_pending_teaching_template = -1
			_rotation_offset = 0
			_natural_offer_count += 1
			return true
	_next_spawn_time = _conveyor.survival_time + failed_spawn_retry_delay
	return false


func _try_spawn_variable_coin_event() -> bool:
	_begin_performance_event_profile()
	var teaching := _natural_offer_count == 0
	if teaching:
		var teaching_accepted := _try_spawn_independent_coin(
			"teaching",
			collectible_lifetime,
			true,
			-1,
			[],
			-1,
			1,
			0,
			[],
			BallisticArchetype.MEDIUM if ballistic_coin_events_enabled else -1,
			[]
		)
		var teaching_interval := _schedule_next_coin_event_attempt()
		if teaching_accepted:
			_natural_offer_count += 1
			if not _offer_log.is_empty():
				_offer_log[-1].next_stream_interval = teaching_interval
		_end_performance_event_profile(1, 1 if teaching_accepted else 0)
		return teaching_accepted

	_coin_event_count += 1
	var event_id := _coin_event_count
	var requested_count := _select_coin_event_size()
	_coin_event_size_counts[requested_count] += 1
	var active_before := active_collectible_count()
	var available_capacity := maxi(
		maxi(maximum_active_independent_coins, 1) - active_before,
		0
	)
	var target_count := mini(requested_count, available_capacity)
	var cap_truncated_count := requested_count - target_count
	if cap_truncated_count > 0:
		_coin_event_cap_truncated_event_count += 1
		_coin_event_cap_truncated_coin_count += cap_truncated_count

	var side_plan := _coin_event_side_plan(requested_count)
	_shuffle_side_plan(side_plan)
	if side_plan.size() > target_count:
		side_plan.resize(target_count)
	var accepted_positions: Array[Vector2] = []
	var requested_lifetimes := PackedFloat32Array()
	var effective_lifetimes := PackedFloat32Array()
	var accepted_sides: Array[int] = []
	var archetype_plan: Array[int] = []
	if ballistic_coin_events_enabled:
		archetype_plan = _ballistic_archetype_plan(requested_count)
	var launch_delay_plan := PackedFloat32Array()
	var launch_rhythm := "SIMULTANEOUS"
	if ballistic_coin_events_enabled:
		launch_delay_plan = _ballistic_launch_delay_plan(requested_count)
		launch_rhythm = (
			"STAGGERED"
			if launch_delay_plan.size() > 1 and launch_delay_plan[-1] > 0.0
			else "SIMULTANEOUS"
		)
		if requested_count > 1 and ballistic_abundance_enabled:
			if launch_rhythm == "STAGGERED":
				_ballistic_staggered_multi_event_count += 1
			else:
				_ballistic_simultaneous_multi_event_count += 1
	var accepted_trajectories: Array[Dictionary] = []
	var accepted_archetypes := PackedInt32Array()
	var flight_durations := PackedFloat32Array()
	var placement_failures := 0
	var priority_skips_before := _stream_priority_skip_count
	var integrity_plan: Dictionary = {}
	var preplanned_samples: Array[Dictionary] = []
	if ballistic_coin_events_enabled and ballistic_integrity_enabled:
		for _coin_index in range(target_count):
			requested_lifetimes.append(_stream_random_range(
				ballistic_post_contact_lifetime_range
			))
		integrity_plan = _plan_ballistic_event_group(
			target_count,
			side_plan,
			archetype_plan,
			launch_delay_plan,
			requested_lifetimes
		)
		preplanned_samples.assign(integrity_plan.get("samples", []))
		target_count = preplanned_samples.size()
	for coin_index in range(target_count):
		var requested_lifetime := (
			float(requested_lifetimes[coin_index])
			if ballistic_coin_events_enabled and ballistic_integrity_enabled
			else _stream_random_range(
				ballistic_post_contact_lifetime_range
				if ballistic_coin_events_enabled
				else independent_lifetime_range
			)
		)
		if not (ballistic_coin_events_enabled and ballistic_integrity_enabled):
			requested_lifetimes.append(requested_lifetime)
		var preplanned_sample: Dictionary = (
			preplanned_samples[coin_index]
			if coin_index < preplanned_samples.size()
			else {}
		)
		var planned_ballistic: Dictionary = preplanned_sample.get(
			"ballistic_plan",
			{}
		)
		var accepted := _try_spawn_independent_coin(
			"event",
			requested_lifetime,
			false,
			int(preplanned_sample.get("preferred_side", side_plan[coin_index])),
			accepted_positions,
			event_id,
			requested_count,
			coin_index,
			accepted_sides,
			int(planned_ballistic.get("archetype", archetype_plan[coin_index])) if ballistic_coin_events_enabled else -1,
			accepted_trajectories,
			float(planned_ballistic.get("launch_delay", launch_delay_plan[coin_index])) if not launch_delay_plan.is_empty() else 0.0,
			preplanned_sample
		)
		if not accepted:
			placement_failures += 1
			_coin_event_placement_failure_count += 1
			continue
		accepted_positions.append(_last_stream_spawn_position)
		effective_lifetimes.append(_last_stream_effective_lifetime)
		accepted_sides.append(_last_stream_spawn_side)
		if ballistic_coin_events_enabled and not _last_ballistic_plan.is_empty():
			accepted_trajectories.append(_last_ballistic_plan.duplicate(true))
			accepted_archetypes.append(int(_last_ballistic_plan.archetype))
			flight_durations.append(float(_last_ballistic_plan.flight_duration))
		_normal_stream_spawn_count += 1
	if ballistic_coin_events_enabled and ballistic_integrity_enabled:
		placement_failures = maxi(requested_count - accepted_positions.size(), 0)
		_coin_event_placement_failure_count += placement_failures
		_record_ballistic_integrity_result(
			requested_count,
			accepted_positions.size(),
			String(integrity_plan.get("degradation_reason", ""))
			if cap_truncated_count == 0
			else REJECTION_ACTIVE_LIMIT
		)

	var next_interval := _schedule_next_coin_event_attempt()
	_natural_offer_count += 1
	_coin_event_log.append({
		"event_id": event_id,
		"time": _conveyor.survival_time,
		"requested_count": requested_count,
		"capacity_at_event": available_capacity,
		"cap_truncated_count": cap_truncated_count,
		"planned_sides": side_plan.duplicate(),
		"spawned_count": accepted_positions.size(),
		"spawned_positions": accepted_positions.duplicate(),
		"spawned_sides": accepted_sides,
		"requested_lifetimes": requested_lifetimes,
		"effective_lifetimes": effective_lifetimes,
		"ballistic": ballistic_coin_events_enabled,
		"trajectory_archetypes": accepted_archetypes,
		"flight_durations": flight_durations,
		"launch_rhythm": launch_rhythm,
		"launch_delays": launch_delay_plan,
		"full_group_success": (
			ballistic_integrity_enabled
			and accepted_positions.size() == requested_count
		),
		"degraded_fallback": (
			ballistic_integrity_enabled
			and accepted_positions.size() < requested_count
		),
		"degradation_reason": (
			String(integrity_plan.get("degradation_reason", ""))
			if cap_truncated_count == 0
			else REJECTION_ACTIVE_LIMIT
		),
		"group_planning_attempts": int(integrity_plan.get("group_attempts", 0)),
		"placement_failures": placement_failures,
		"d3_priority_skips": _stream_priority_skip_count - priority_skips_before,
		"next_event_interval": next_interval,
	})
	_end_performance_event_profile(requested_count, accepted_positions.size())
	return not accepted_positions.is_empty()


func _plan_ballistic_event_group(
	target_count: int,
	side_plan: Array[int],
	archetype_plan: Array[int],
	launch_delay_plan: PackedFloat32Array,
	requested_lifetimes: PackedFloat32Array
) -> Dictionary:
	if target_count <= 0:
		return {
			"samples": [],
			"group_attempts": 0,
			"degradation_reason": REJECTION_ACTIVE_LIMIT,
		}
	if target_count == 1:
		var sampled_single := _sample_independent_candidate(
			float(requested_lifetimes[0]),
			false,
			"event",
			int(side_plan[0]),
			[],
			[],
			int(archetype_plan[0]),
			[],
			float(launch_delay_plan[0]) if not launch_delay_plan.is_empty() else 0.0,
			maxi(ballistic_single_placement_attempts, 1)
		)
		if performance_profiling_enabled:
			_performance_current_event_placement_attempts += int(
				sampled_single.get("attempts", 0)
			)
		var single_candidate: Dictionary = sampled_single.get("candidate", {})
		var single_plan: Dictionary = sampled_single.get("ballistic_plan", {})
		if single_candidate.is_empty() or single_plan.is_empty():
			return {
				"samples": [],
				"group_attempts": 1,
				"degradation_reason": String(sampled_single.get(
					"reason",
					REJECTION_SCATTER_EXHAUSTED
				)),
			}
		var committed_single := sampled_single.duplicate(true)
		committed_single.preferred_side = int(side_plan[0])
		committed_single.requested_lifetime = float(requested_lifetimes[0])
		return {
			"samples": [committed_single],
			"group_attempts": 1,
			"degradation_reason": "",
		}
	var total_group_attempts := 0
	var last_reason := REJECTION_SCATTER_EXHAUSTED
	# Generate several individually valid options for each requested sibling,
	# then search combinations. VM-0.6.8 and the first VM-0.6.9 draft locked
	# sibling A before planning B/C, so an unlucky first choice frequently made a
	# valid complete event look impossible. Pools keep that search bounded while
	# allowing the complete event to be judged before anything is spawned.
	var candidate_pools: Array = []
	for coin_index in range(target_count):
		var pool: Array[Dictionary] = []
		var pool_calls := 0
		var maximum_pool_calls := maxi(ballistic_group_candidate_pool_size, 1) * 2
		while (
			pool.size() < maxi(ballistic_group_candidate_pool_size, 1)
			and pool_calls < maximum_pool_calls
		):
			pool_calls += 1
			var requested_lifetime := float(requested_lifetimes[coin_index])
			var preferred_side := int(side_plan[coin_index])
			var archetype := int(archetype_plan[coin_index])
			var launch_delay := (
				float(launch_delay_plan[coin_index])
				if coin_index < launch_delay_plan.size()
				else 0.0
			)
			var sampled := _sample_independent_candidate(
				requested_lifetime,
				false,
				"event",
				preferred_side,
				[],
				[],
				archetype,
				[],
				launch_delay,
				maxi(ballistic_group_member_placement_attempts, 1)
			)
			if performance_profiling_enabled:
				_performance_current_event_placement_attempts += int(
					sampled.get("attempts", 0)
				)
			var candidate: Dictionary = sampled.get("candidate", {})
			var plan: Dictionary = sampled.get("ballistic_plan", {})
			if candidate.is_empty() or plan.is_empty():
				last_reason = String(sampled.get(
					"reason",
					REJECTION_SCATTER_EXHAUSTED
				))
				continue
			var duplicate_option := false
			for existing_sample in pool:
				var existing_candidate: Dictionary = existing_sample.candidate
				if (
					candidate.position.distance_to(existing_candidate.position)
					< collectible_size.x * 0.5
				):
					duplicate_option = true
					break
			if duplicate_option:
				continue
			var committed_sample := sampled.duplicate(true)
			committed_sample.preferred_side = preferred_side
			committed_sample.requested_lifetime = requested_lifetime
			pool.append(committed_sample)
		candidate_pools.append(pool)

	for group_size in range(target_count, 0, -1):
		var combination_result := _find_ballistic_group_combination(
			candidate_pools,
			group_size
		)
		total_group_attempts += int(combination_result.get("checks", 0))
		var samples: Array[Dictionary] = []
		samples.assign(combination_result.get("samples", []))
		if not samples.is_empty():
			return {
				"samples": samples,
				"group_attempts": total_group_attempts,
				"degradation_reason": (
					"" if group_size == target_count else last_reason
				),
			}
		var combination_reason := String(combination_result.get("reason", ""))
		if not combination_reason.is_empty():
			last_reason = combination_reason
	# A full target pool can be empty under transient constraints. Give the final
	# single fallback its own bounded search so a failed multi-event does not turn
	# into an avoidable zero-coin gap.
	var single_sample := _sample_independent_candidate(
		float(requested_lifetimes[0]),
		false,
		"event",
		int(side_plan[0]),
		[],
		[],
		int(archetype_plan[0]),
		[],
		float(launch_delay_plan[0]) if not launch_delay_plan.is_empty() else 0.0,
		maxi(ballistic_single_placement_attempts, 1)
	)
	if performance_profiling_enabled:
		_performance_current_event_placement_attempts += int(
			single_sample.get("attempts", 0)
		)
	if (
		not Dictionary(single_sample.get("candidate", {})).is_empty()
		and not Dictionary(single_sample.get("ballistic_plan", {})).is_empty()
	):
		var committed_single := single_sample.duplicate(true)
		committed_single.preferred_side = int(side_plan[0])
		committed_single.requested_lifetime = float(requested_lifetimes[0])
		return {
			"samples": [committed_single],
			"group_attempts": total_group_attempts + 1,
			"degradation_reason": last_reason,
		}
	return {
		"samples": [],
		"group_attempts": total_group_attempts,
		"degradation_reason": last_reason,
	}


func _find_ballistic_group_combination(
	candidate_pools: Array,
	group_size: int
) -> Dictionary:
	if group_size <= 0 or candidate_pools.size() < group_size:
		return {"samples": [], "checks": 0, "reason": REJECTION_SCATTER_EXHAUSTED}
	for index in range(group_size):
		if Array(candidate_pools[index]).is_empty():
			return {"samples": [], "checks": 0, "reason": REJECTION_SCATTER_EXHAUSTED}
	var checks := 0
	var last_reason := REJECTION_SIBLING
	var check_limit := maxi(ballistic_group_combination_checks, 1)
	if group_size == 1:
		for first in Array(candidate_pools[0]):
			checks += 1
			var samples: Array[Dictionary] = [first]
			var reason := _ballistic_group_combination_rejection_reason(samples)
			if reason.is_empty():
				return {"samples": samples, "checks": checks, "reason": ""}
			last_reason = reason
			if checks >= check_limit:
				break
	elif group_size == 2:
		for first in Array(candidate_pools[0]):
			for second in Array(candidate_pools[1]):
				checks += 1
				var samples: Array[Dictionary] = [first, second]
				var reason := _ballistic_group_combination_rejection_reason(samples)
				if reason.is_empty():
					return {"samples": samples, "checks": checks, "reason": ""}
				last_reason = reason
				if checks >= check_limit:
					return {"samples": [], "checks": checks, "reason": last_reason}
	else:
		for first in Array(candidate_pools[0]):
			for second in Array(candidate_pools[1]):
				for third in Array(candidate_pools[2]):
					checks += 1
					var samples: Array[Dictionary] = [first, second, third]
					var reason := _ballistic_group_combination_rejection_reason(samples)
					if reason.is_empty():
						return {"samples": samples, "checks": checks, "reason": ""}
					last_reason = reason
					if checks >= check_limit:
						return {"samples": [], "checks": checks, "reason": last_reason}
	return {"samples": [], "checks": checks, "reason": last_reason}


func _ballistic_group_combination_rejection_reason(
	samples: Array[Dictionary]
) -> String:
	var sibling_trajectories: Array[Dictionary] = []
	for sample in samples:
		var candidate: Dictionary = sample.get("candidate", {})
		var plan: Dictionary = sample.get("ballistic_plan", {})
		if candidate.is_empty() or plan.is_empty():
			return REJECTION_SCATTER_EXHAUSTED
		if not _ballistic_trajectory_separation_is_valid(
			plan,
			sibling_trajectories
		):
			return REJECTION_SIBLING
		if not _ballistic_post_contact_separation_is_valid(
			plan,
			sibling_trajectories
		):
			return REJECTION_SIBLING
		sibling_trajectories.append(plan)
	if not _ballistic_group_preserves_d3_priority(sibling_trajectories):
		return REJECTION_D3_PRIORITY
	return ""


func _ballistic_group_preserves_d3_priority(
	candidate_plans: Array[Dictionary]
) -> bool:
	var d3 := _conveyor.get_node_or_null(
		"BackgroundDropDirector"
	) as MotionBackgroundDropDirector
	if (
		d3 == null
		or d3.released_event_count() >= d3.maximum_events_per_round
		or d3.state in [
			MotionBackgroundDropDirector.VisualState.RELEASED,
			MotionBackgroundDropDirector.VisualState.STOPPED,
		]
	):
		return true
	var until_reservation := 0.0
	var impact_horizon := d3.warning_duration + d3.target_fall_duration
	if d3.state == MotionBackgroundDropDirector.VisualState.SELECTED:
		impact_horizon = d3.warning_time_remaining + d3.target_fall_duration
	elif is_finite(d3.next_reservation_time):
		until_reservation = (
			0.0
			if d3.reservation_pending
			else maxf(
				d3.next_reservation_time - _conveyor.survival_time,
				0.0
			)
		)
	else:
		return true
	var clearance := (
		_conveyor.product_size.x + collectible_size.x
	) * 0.5
	for lane_x in d3.candidate_lane_x:
		var lane_is_clear := true
		for active_coin in active_collectibles():
			var remaining := active_coin.total_collectible_time_remaining()
			if remaining <= until_reservation + 0.0001:
				continue
			var active_interval := active_coin.projected_horizontal_interval(
				until_reservation,
				minf(impact_horizon, remaining - until_reservation)
			)
			if (
				float(lane_x) >= active_interval.x - clearance
				and float(lane_x) <= active_interval.y + clearance
			):
				lane_is_clear = false
				break
		if not lane_is_clear:
			continue
		for plan in candidate_plans:
			var total_lifetime := (
				float(plan.get("launch_delay", 0.0))
				+ float(plan.flight_duration)
				+ float(plan.effective_post_contact_lifetime)
			)
			if total_lifetime <= until_reservation + 0.0001:
				continue
			var interval := _ballistic_plan_horizontal_interval(
				plan,
				until_reservation,
				minf(impact_horizon, total_lifetime - until_reservation)
			)
			if (
				float(lane_x) >= interval.x - clearance
				and float(lane_x) <= interval.y + clearance
			):
				lane_is_clear = false
				break
		if lane_is_clear:
			return true
	return false


func _record_ballistic_integrity_result(
	requested_count: int,
	delivered_count: int,
	degradation_reason: String
) -> void:
	if requested_count == 2:
		if delivered_count == 2:
			_ballistic_full_double_count += 1
		else:
			_ballistic_degraded_double_count += 1
	elif requested_count == 3:
		if delivered_count == 3:
			_ballistic_full_triple_count += 1
		else:
			_ballistic_degraded_triple_count += 1
	if requested_count <= 1 or delivered_count == requested_count:
		return
	var reason := (
		degradation_reason
		if not degradation_reason.is_empty()
		else REJECTION_SCATTER_EXHAUSTED
	)
	_ballistic_group_degradation_reasons[reason] = int(
		_ballistic_group_degradation_reasons.get(reason, 0)
	) + 1


func _select_coin_event_size() -> int:
	return _select_stream_weighted_index(coin_event_size_weights, 0) + 1


func _select_single_event_side() -> int:
	return _select_stream_weighted_index(single_event_side_weights, OfferSide.AHEAD)


func _select_stream_weighted_index(weights: PackedInt32Array, fallback: int) -> int:
	var total := 0
	for weight in weights:
		total += maxi(weight, 0)
	if total <= 0:
		return fallback
	_stream_rng_state = _next_rng_state(_stream_rng_state)
	var roll := posmod(_stream_rng_state, total)
	for index in range(weights.size()):
		roll -= maxi(weights[index], 0)
		if roll < 0:
			return index
	return clampi(fallback, 0, maxi(weights.size() - 1, 0))


func _coin_event_side_plan(requested_count: int) -> Array[int]:
	if requested_count <= 1:
		return [_select_single_event_side()]
	if requested_count == 2:
		var pair_plans := [
			[OfferSide.BEHIND, OfferSide.AHEAD],
			[OfferSide.BEHIND, OfferSide.AHEAD],
			[OfferSide.CENTRED, OfferSide.AHEAD],
			[OfferSide.BEHIND, OfferSide.CENTRED],
		]
		return _copy_side_plan(pair_plans[_stream_random_index(pair_plans.size())])
	var triple_plans := [
		[OfferSide.BEHIND, OfferSide.CENTRED, OfferSide.AHEAD],
		[OfferSide.BEHIND, OfferSide.CENTRED, OfferSide.AHEAD],
		[OfferSide.BEHIND, OfferSide.AHEAD, OfferSide.AHEAD],
		[OfferSide.BEHIND, OfferSide.BEHIND, OfferSide.AHEAD],
	]
	return _copy_side_plan(triple_plans[_stream_random_index(triple_plans.size())])


func _copy_side_plan(source: Array) -> Array[int]:
	var result: Array[int] = []
	for side in source:
		result.append(int(side))
	return result


func _ballistic_archetype_plan(requested_count: int) -> Array[int]:
	if requested_count <= 1:
		return [_stream_random_index(3)]
	if requested_count == 2:
		var pair_plans := [
			[BallisticArchetype.SHALLOW, BallisticArchetype.HIGH],
			[BallisticArchetype.SHALLOW, BallisticArchetype.MEDIUM],
			[BallisticArchetype.MEDIUM, BallisticArchetype.HIGH],
		]
		return _copy_side_plan(pair_plans[_stream_random_index(pair_plans.size())])
	return [
		BallisticArchetype.SHALLOW,
		BallisticArchetype.MEDIUM,
		BallisticArchetype.HIGH,
	]


func _ballistic_launch_delay_plan(requested_count: int) -> PackedFloat32Array:
	var delays := PackedFloat32Array()
	for _index in range(maxi(requested_count, 0)):
		delays.append(0.0)
	if not ballistic_abundance_enabled or requested_count <= 1:
		return delays
	if requested_count == 2:
		if _stream_probability_roll(ballistic_double_stagger_probability):
			delays[1] = _stream_random_range(ballistic_double_stagger_delay_range)
		return delays
	if _stream_probability_roll(ballistic_triple_stagger_probability):
		delays[1] = _stream_random_range(ballistic_triple_stagger_delay_range)
		delays[2] = delays[1] + _stream_random_range(
			ballistic_triple_stagger_delay_range
		)
	return delays


func ballistic_archetype_name(archetype: int) -> String:
	match archetype:
		BallisticArchetype.SHALLOW:
			return "SHALLOW"
		BallisticArchetype.HIGH:
			return "HIGH"
	return "MEDIUM"


func _event_side_fallback_preferences(
	preferred_side: int,
	already_used_sides: Array[int]
) -> Array[int]:
	var result: Array[int] = [preferred_side]
	# A multi-coin event first tries an unused direction so fallback placement
	# cannot quietly collapse a competing choice into one same-side cluster.
	for side in [OfferSide.BEHIND, OfferSide.CENTRED, OfferSide.AHEAD]:
		if side not in result and side not in already_used_sides:
			result.append(side)
	for side in [OfferSide.BEHIND, OfferSide.CENTRED, OfferSide.AHEAD]:
		if side not in result:
			result.append(side)
	return result


func _shuffle_side_plan(plan: Array[int]) -> void:
	for index in range(plan.size() - 1, 0, -1):
		var swap_index := _stream_random_index(index + 1)
		var held := plan[index]
		plan[index] = plan[swap_index]
		plan[swap_index] = held


func _stream_random_index(count: int) -> int:
	if count <= 1:
		return 0
	_stream_rng_state = _next_rng_state(_stream_rng_state)
	return posmod(_stream_rng_state, count)


func _schedule_next_coin_event_attempt() -> float:
	var interval := _stream_random_range(coin_event_interval_range)
	_next_spawn_time = _conveyor.survival_time + interval
	return interval


func _try_spawn_natural_stream_coin() -> bool:
	var teaching := _natural_offer_count == 0
	var lifetime := (
		collectible_lifetime
		if teaching
		else _stream_random_range(independent_lifetime_range)
	)
	var accepted := _try_spawn_independent_coin(
		"teaching" if teaching else "normal",
		lifetime,
		teaching
	)
	_schedule_next_stream_attempt()
	if not accepted:
		return false
	_natural_offer_count += 1
	if teaching:
		return true
	_normal_stream_spawn_count += 1
	if (
		active_collectible_count() < maxi(maximum_active_independent_coins, 1)
		and _stream_probability_roll(independent_bonus_probability)
	):
		_pending_bonus = true
		_pending_bonus_spawn_time = (
			_conveyor.survival_time
			+ _stream_random_range(independent_bonus_delay_range)
		)
	return true


func _update_pending_bonus_spawn() -> void:
	if (
		not _pending_bonus
		or _conveyor.survival_time + 0.0001 < _pending_bonus_spawn_time
	):
		return
	_pending_bonus = false
	_pending_bonus_spawn_time = INF
	if active_collectible_count() >= maxi(maximum_active_independent_coins, 1):
		_stream_cap_skip_count += 1
		_record_stream_rejection("bonus", REJECTION_ACTIVE_LIMIT, 0.0, 0)
		return
	for _cycle in range(maxi(maximum_bonus_placement_cycles, 1)):
		var lifetime := _stream_random_range(independent_lifetime_range)
		if _try_spawn_independent_coin("bonus", lifetime, false):
			_bonus_stream_spawn_count += 1
			return


func _schedule_next_stream_attempt() -> void:
	var interval := _stream_random_range(independent_spawn_interval_range)
	_next_spawn_time = (
		_conveyor.survival_time
		+ interval
	)
	if not _offer_log.is_empty():
		var last: Dictionary = _offer_log[-1]
		if String(last.get("event", "")) == "attempt":
			last.next_scheduled_time = _next_spawn_time
			last.next_stream_interval = interval
			_offer_log[-1] = last


func _try_spawn_independent_coin(
	spawn_kind: String,
	lifetime: float,
	force_ground: bool,
	preferred_side: int = -1,
	event_sibling_positions: Array[Vector2] = [],
	event_id: int = -1,
	event_requested_count: int = 1,
	event_coin_index: int = 0,
	event_sibling_sides: Array[int] = [],
	ballistic_archetype: int = -1,
	event_sibling_trajectories: Array[Dictionary] = [],
	ballistic_launch_delay: float = 0.0,
	preplanned_sample: Dictionary = {}
) -> bool:
	_last_stream_spawn_position = Vector2.ZERO
	_last_stream_effective_lifetime = 0.0
	_last_stream_spawn_side = OfferSide.CENTRED
	_last_ballistic_plan = {}
	_stream_attempt_count += 1
	_refresh_active_offers()
	if _conveyor.gameplay_is_stopped() or _stopped:
		_record_stream_rejection(spawn_kind, REJECTION_ROUND_ENDING, lifetime, 0)
		return false
	if active_collectible_count() >= maxi(maximum_active_independent_coins, 1):
		_stream_cap_skip_count += 1
		_record_stream_rejection(spawn_kind, REJECTION_ACTIVE_LIMIT, lifetime, 0)
		return false
	var sampled := (
		preplanned_sample
		if not preplanned_sample.is_empty()
		else _sample_independent_candidate(
			lifetime,
			force_ground,
			spawn_kind,
			preferred_side,
			event_sibling_positions,
			event_sibling_sides,
			ballistic_archetype,
			event_sibling_trajectories,
			ballistic_launch_delay
		)
	)
	var candidate_data: Dictionary = sampled.get("candidate", {})
	var rejection_reason := String(sampled.get("reason", REJECTION_SCATTER_EXHAUSTED))
	var placement_attempts := int(sampled.get("attempts", 0))
	if performance_profiling_enabled and preplanned_sample.is_empty():
		_performance_current_event_placement_attempts += placement_attempts
	if candidate_data.is_empty():
		if rejection_reason == REJECTION_D3_PRIORITY:
			_stream_priority_skip_count += 1
		_record_stream_rejection(
			spawn_kind,
			rejection_reason,
			lifetime,
			placement_attempts
		)
		return false
	var effective_lifetime := float(sampled.get("effective_lifetime", lifetime))
	var ballistic_plan: Dictionary = sampled.get("ballistic_plan", {})
	_offer_id_cursor += 1
	var offer_id := _offer_id_cursor
	var coin := _spawn_offer_coin(
		candidate_data,
		offer_id,
		0,
		lifetime,
		independent_expiry_warning_duration,
		effective_lifetime,
		ballistic_plan
	)
	coin.set_meta("stream_spawn_kind", spawn_kind)
	coin.set_meta("stream_spawn_time", _conveyor.survival_time)
	coin.set_meta("stream_lifetime", lifetime)
	coin.set_meta("stream_effective_lifetime", effective_lifetime)
	coin.set_meta("coin_event_id", event_id)
	coin.set_meta("coin_event_index", event_coin_index)
	if not ballistic_plan.is_empty():
		coin.set_meta("ballistic_archetype", int(ballistic_plan.archetype))
		coin.set_meta("ballistic_archetype_name", ballistic_archetype_name(int(ballistic_plan.archetype)))
		coin.set_meta("ballistic_flight_duration", float(ballistic_plan.flight_duration))
		coin.set_meta("ballistic_launch_delay", float(ballistic_plan.get("launch_delay", 0.0)))
		var launch_side := classify_offer_side_for_test(
			[{"position": ballistic_plan.launch_position}],
			_conveyor.player.global_position.x
		)
		coin.set_meta("ballistic_launch_side", launch_side)
		coin.set_meta(
			"ballistic_previous_player_delta_x",
			(ballistic_plan.launch_position as Vector2).x
			- _conveyor.player.global_position.x
		)
		coin.set_meta("ballistic_crossed_player", false)
		_ballistic_launch_side_counts[launch_side] += 1
		_last_ballistic_plan = ballistic_plan.duplicate(true)
		_ballistic_archetype_counts[int(ballistic_plan.archetype)] += 1
		_ballistic_flight_log.append(float(ballistic_plan.flight_duration))
		_ballistic_post_contact_lifetime_log.append(effective_lifetime)
		coin.first_conveyor_contact.connect(_on_ballistic_first_contact)
		coin.settled.connect(_on_ballistic_settled)
	var offer := {
		"id": offer_id,
		"template": SCATTER_TEMPLATE,
		"phase": phase_at(_conveyor.survival_time),
		"coins": [coin],
		"pending_candidates": [],
		"next_subspawn_time": INF,
		"pending_retry_count": 0,
		"total_count": 1,
		"spawn_time": _conveyor.survival_time,
		"collected": 0,
		"expired": 0,
		"log_index": _offer_log.size(),
	}
	_active_offers.append(offer)
	if spawn_kind == "teaching" and first_offer_teaching_cue_enabled:
		coin.show_teaching_cue(first_offer_teaching_cue_timeout)
		_teaching_cue_shown = true
	last_spawn_band = int(candidate_data.band)
	spawn_count += 1
	_stream_lifetime_log.append(lifetime)
	if first_actual_spawn_time < 0.0:
		first_actual_spawn_time = _conveyor.survival_time
	if _last_offer_spawn_time >= 0.0:
		_longest_offer_gap = maxf(
			_longest_offer_gap,
			_conveyor.survival_time - _last_offer_spawn_time
		)
	_last_offer_spawn_time = _conveyor.survival_time
	var candidates: Array[Dictionary] = [candidate_data]
	var side := classify_offer_side_for_test(
		candidates,
		_conveyor.player.global_position.x
	)
	_last_stream_spawn_position = candidate_data.position
	_last_stream_effective_lifetime = effective_lifetime
	_last_stream_spawn_side = side
	_update_offer_side_history(side)
	_offer_log.append({
		"event": "attempt",
		"time": _conveyor.survival_time,
		"phase": phase_at(_conveyor.survival_time),
		"template": SCATTER_TEMPLATE,
		"template_name": "variable coin event" if spawn_kind == "event" else "independent coin",
		"intended_count": 1,
		"ground_count": 1 if int(candidate_data.band) == PlacementBand.GROUND else 0,
		"air_count": 1 if int(candidate_data.band) == PlacementBand.LOW_AIR else 0,
		"intended_ground_count": 1 if int(candidate_data.band) == PlacementBand.GROUND else 0,
		"intended_low_air_count": 1 if int(candidate_data.band) == PlacementBand.LOW_AIR else 0,
		"accepted": true,
		"rejection_reason": "",
		"spawn_timestamp": _conveyor.survival_time,
		"resolve_timestamp": -1.0,
		"spawned_offer_id": offer_id,
		"resolved_offer_id": -1,
		"collected": 0,
		"expired": 0,
		"next_scheduled_time": _next_spawn_time,
		"active_offer_count": _active_offers.size(),
		"active_coin_count": active_collectible_count(),
		"active_offer_state": _active_offer_state(),
		"natural": true,
		"player_x": _conveyor.player.global_position.x,
		"offer_primary_x": candidate_data.position.x,
		"offer_side": side,
		"offer_side_name": offer_side_name(side),
		"behind_streak_before": maxi(_consecutive_behind_offers - (1 if side == OfferSide.BEHIND else 0), 0),
		"behind_streak_after": _consecutive_behind_offers,
		"anti_streak_requested": false,
		"route_archetype": "INDEPENDENT",
		"topology": "VARIABLE_EVENT" if spawn_kind == "event" else "INDEPENDENT_STREAM",
		"pair_mode": false,
		"minimum_pairwise_separation": INF,
		"candidate_positions": [candidate_data.position],
		"scatter_layout_attempts": placement_attempts,
		"placement_attempts": placement_attempts,
		"alternate_placement_selected": false,
		"placement_shift_x": 0.0,
		"player_safety_rejections": 0,
		"player_overlap_rejections": 0,
		"player_buffer_rejections": 0,
		"spawn_kind": spawn_kind,
		"coin_lifetime": lifetime,
		"requested_lifetime": lifetime,
		"effective_lifetime": effective_lifetime,
		"expiry_warning_duration": independent_expiry_warning_duration,
		"coin_event_id": event_id,
		"coin_event_requested_count": event_requested_count,
		"coin_event_index": event_coin_index,
		"preferred_side": preferred_side,
		"preferred_side_name": offer_side_name(preferred_side),
		"ballistic": not ballistic_plan.is_empty(),
		"ballistic_archetype": int(ballistic_plan.get("archetype", -1)),
		"ballistic_archetype_name": ballistic_archetype_name(int(ballistic_plan.get("archetype", BallisticArchetype.MEDIUM))) if not ballistic_plan.is_empty() else "",
		"flight_duration": float(ballistic_plan.get("flight_duration", 0.0)),
		"launch_delay": float(ballistic_plan.get("launch_delay", 0.0)),
		"launch_position": ballistic_plan.get("launch_position", Vector2.ZERO),
		"landing_position": ballistic_plan.get("landing_position", candidate_data.position),
	})
	offer_spawned.emit(offer_id, SCATTER_TEMPLATE, 1)
	return true


func _sample_independent_candidate(
	lifetime: float,
	force_ground: bool,
	spawn_kind: String,
	preferred_side: int = -1,
	event_sibling_positions: Array[Vector2] = [],
	event_sibling_sides: Array[int] = [],
	ballistic_archetype: int = -1,
	event_sibling_trajectories: Array[Dictionary] = [],
	ballistic_launch_delay: float = 0.0,
	maximum_attempts_override: int = -1
) -> Dictionary:
	var variable_event := variable_coin_events_enabled and spawn_kind == "event"
	var ballistic_event := (
		ballistic_coin_events_enabled
		and ballistic_archetype in [
			BallisticArchetype.SHALLOW,
			BallisticArchetype.MEDIUM,
			BallisticArchetype.HIGH,
		]
		and spawn_kind in ["event", "teaching"]
	)
	var anti_streak_requested := (
		not force_ground and _should_request_centred_ahead_offer()
	)
	var side_preferences: Array[int] = []
	if variable_event and preferred_side in [OfferSide.BEHIND, OfferSide.CENTRED, OfferSide.AHEAD]:
		side_preferences.assign(
			_event_side_fallback_preferences(preferred_side, event_sibling_sides)
		)
	elif anti_streak_requested:
		side_preferences.assign(_scatter_correction_side_preferences())
	else:
		side_preferences.append(-1)
	var last_reason := REJECTION_SCATTER_EXHAUSTED
	var total_attempts := 0
	for side_preference in side_preferences:
		var bounds := _scatter_x_bounds(int(side_preference), 1)
		bounds.y = _conveyor.control_band_right - collectible_size.x * 0.5
		if ballistic_event:
			bounds.x = maxf(
				bounds.x,
				_minimum_ballistic_landing_x(
					_ballistic_flight_duration(ballistic_archetype)
				)
			)
			bounds = _restrict_event_bounds_to_side(bounds, int(side_preference))
		elif variable_event:
			bounds.x = maxf(bounds.x, _minimum_event_spawn_x())
			bounds = _restrict_event_bounds_to_side(bounds, int(side_preference))
		else:
			# VM-0.6.5 compatibility path: the complete requested lifetime had to
			# fit before the left edge. VM-0.6.6 intentionally replaces this rule.
			bounds.x = maxf(
				bounds.x,
				_conveyor.conveyor_support_left_x
				+ collectible_size.x * 0.5
				+ _conveyor.conveyor_speed * maxf(lifetime, 0.0)
			)
		if bounds.y <= bounds.x:
			continue
		var attempt_limit := (
			maxi(maximum_independent_placement_attempts, 1)
			if maximum_attempts_override < 0
			else maxi(maximum_attempts_override, 1)
		)
		for _attempt in range(attempt_limit):
			total_attempts += 1
			var candidate := _sample_scatter_candidate(
				bounds,
				PlacementBand.GROUND if force_ground or ballistic_event else -1
			)
			if ballistic_event:
				candidate.position.y = _ballistic_contact_y()
			candidate.route_branch = "independent"
			candidate.lifetime = lifetime
			candidate.allow_right_edge = true
			if not variable_event and int(side_preference) in [OfferSide.BEHIND, OfferSide.CENTRED, OfferSide.AHEAD]:
				candidate = _translate_candidates_for_side([candidate], int(side_preference))[0]
			if not _scatter_side_matches([candidate], int(side_preference)):
				continue
			var player_reason := _player_spawn_rejection_reason(candidate.position)
			if not player_reason.is_empty():
				last_reason = player_reason
				continue
			var ballistic_plan := (
				_build_ballistic_plan(
					candidate.position,
					ballistic_archetype,
					lifetime,
					ballistic_launch_delay,
					ballistic_abundance_enabled
				)
				if ballistic_event
				else {}
			)
			var effective_lifetime := (
				float(ballistic_plan.effective_post_contact_lifetime)
				if ballistic_event
				else (
					_event_effective_visible_lifetime(candidate.position.x, lifetime)
					if variable_event
					else _visible_lifetime_for(candidate.position.x, lifetime)
				)
			)
			if (
				(variable_event or ballistic_event)
				and effective_lifetime + 0.0001
				< maxf(
					ballistic_minimum_post_contact_visible_lifetime
					if ballistic_event
					else minimum_guaranteed_visible_lifetime,
					0.0
				)
			):
				last_reason = REJECTION_LIFETIME
				continue
			var reason := _candidate_rejection_reason(
				candidate.position,
				candidate.band,
				[],
					not variable_event and not ballistic_event,
				bool(candidate.allow_right_edge),
				effective_lifetime,
				ballistic_event and ballistic_abundance_enabled
			)
			if not reason.is_empty():
				last_reason = reason
				continue
			if (
				(variable_event or ballistic_event)
				and not _candidate_is_reachable_with_lifetime(
					candidate.position,
					candidate.band,
					effective_lifetime
				)
			):
				last_reason = REJECTION_UNREACHABLE
				continue
			var separation_is_valid := (
				_ballistic_active_opportunity_separation_is_valid(ballistic_plan)
				if ballistic_event and ballistic_integrity_enabled
				else _independent_separation_is_valid(
					candidate.position,
					spawn_kind,
					event_sibling_positions
				)
			)
			if not separation_is_valid:
				last_reason = REJECTION_SIBLING
				continue
			if (
				ballistic_event
				and not _ballistic_trajectory_separation_is_valid(
					ballistic_plan,
					event_sibling_trajectories
				)
			):
				_ballistic_trajectory_failure_count += 1
				last_reason = REJECTION_SIBLING
				continue
			if not _candidate_preserves_d3_priority(
				candidate.position,
				effective_lifetime,
				ballistic_plan
			):
				last_reason = REJECTION_D3_PRIORITY
				continue
			return {
				"candidate": candidate,
				"effective_lifetime": effective_lifetime,
				"ballistic_plan": ballistic_plan,
				"reason": "",
				"attempts": total_attempts,
			}
	return {"candidate": {}, "reason": last_reason, "attempts": total_attempts}


func _independent_separation_is_valid(
	candidate: Vector2,
	spawn_kind: String,
	event_sibling_positions: Array[Vector2] = []
) -> bool:
	var configured_separation := (
		coin_event_minimum_separation
		if spawn_kind == "event"
		else (
			independent_bonus_minimum_separation
			if spawn_kind == "bonus"
			else independent_minimum_separation
		)
	)
	for existing in active_collectibles():
		var existing_position := (
			existing.landing_position()
			if existing.is_ballistic() and not existing.first_contact_occurred()
			else existing.global_position
		)
		if (
			candidate.distance_to(existing_position) + 0.001
			< maxf(configured_separation, collectible_size.x + 1.0)
		):
			return false
	for sibling_position in event_sibling_positions:
		var sibling_separation := (
			coin_event_sibling_minimum_separation
			if spawn_kind == "event"
			else configured_separation
		)
		if (
			candidate.distance_to(sibling_position) + 0.001
			< maxf(sibling_separation, collectible_size.x + 1.0)
		):
			return false
	return true


func _candidate_preserves_d3_priority(
	candidate: Vector2,
	lifetime: float,
	ballistic_plan: Dictionary = {}
) -> bool:
	var d3 := _conveyor.get_node_or_null("BackgroundDropDirector") as MotionBackgroundDropDirector
	if d3 == null or d3.released_event_count() >= d3.maximum_events_per_round:
		return true
	# Once D3 has selected a lane, optional coins may continue only when their
	# complete moving lifetime remains clear of that committed lane. During the
	# released state the existing falling-product check has already validated the
	# candidate. This avoids suppressing the coin stream for an entire D3 cycle
	# without ever allowing a coin to displace the authored hazard event.
	if d3.state == MotionBackgroundDropDirector.VisualState.SELECTED:
		var selected_coin_data := _projected_candidate_coin_data(
			candidate,
			lifetime,
			ballistic_plan,
			0.0,
			d3.warning_time_remaining + d3.target_fall_duration
		)
		return not _projected_coin_blocks_d3_lane(
			selected_coin_data,
			d3.selected_lane_x,
			0.0,
			d3.warning_time_remaining + d3.target_fall_duration
		)
	if d3.state == MotionBackgroundDropDirector.VisualState.RELEASED:
		return true
	if d3.state == MotionBackgroundDropDirector.VisualState.STOPPED:
		return true
	if not is_finite(d3.next_reservation_time):
		return true
	var until_reservation := (
		0.0
		if d3.reservation_pending
		else maxf(d3.next_reservation_time - _conveyor.survival_time, 0.0)
	)
	if ballistic_plan.is_empty():
		return _nonballistic_candidate_preserves_d3_priority(
			candidate,
			lifetime,
			d3,
			until_reservation
		)
	if ballistic_abundance_enabled:
		return _ballistic_opportunities_leave_d3_lane(
			d3,
			ballistic_plan,
			until_reservation
		)
	# A ballistic path can cross several logical lanes. To guarantee optional
	# reward motion never alters a frozen D3 reservation, admit it only when its
	# complete flight and post-contact opportunity clear before that reservation.
	var candidate_total_lifetime := (
		float(ballistic_plan.get("launch_delay", 0.0))
		+ float(ballistic_plan.flight_duration)
		+ float(ballistic_plan.effective_post_contact_lifetime)
	)
	if (
		candidate_total_lifetime
		> maxf(until_reservation - d3_priority_clearance_time, 0.0) + 0.0001
	):
		return false
	for active_coin in active_collectibles():
		if (
			active_coin.total_collectible_time_remaining()
			> maxf(until_reservation - d3_priority_clearance_time, 0.0) + 0.0001
		):
			return false
	return true


func _ballistic_opportunities_leave_d3_lane(
	d3: MotionBackgroundDropDirector,
	candidate_plan: Dictionary,
	until_reservation: float
) -> bool:
	# VM-0.6.7 rejected every reward whose complete lifetime crossed the next
	# reservation timestamp. VM-0.6.8 instead proves that at least one authored
	# D3 lane remains clear for the complete warning + fall horizon. This relaxes
	# unnecessary reward starvation without allowing an optional coin to delay
	# the frozen hazard schedule.
	var impact_horizon := d3.warning_duration + d3.target_fall_duration
	var candidate_total := (
		float(candidate_plan.get("launch_delay", 0.0))
		+ float(candidate_plan.flight_duration)
		+ float(candidate_plan.effective_post_contact_lifetime)
	)
	for lane_x in d3.candidate_lane_x:
		var lane_is_clear := true
		var clearance := (
			_conveyor.product_size.x + collectible_size.x
		) * 0.5
		if candidate_total > until_reservation + 0.0001:
			var candidate_duration := minf(
				impact_horizon,
				candidate_total - until_reservation
			)
			var candidate_interval := _ballistic_plan_horizontal_interval(
				candidate_plan,
				until_reservation,
				candidate_duration
			)
			if (
				float(lane_x) >= candidate_interval.x - clearance
				and float(lane_x) <= candidate_interval.y + clearance
			):
				lane_is_clear = false
		if not lane_is_clear:
			continue
		for active_coin in active_collectibles():
			var remaining := active_coin.total_collectible_time_remaining()
			if remaining <= until_reservation + 0.0001:
				continue
			var interval := active_coin.projected_horizontal_interval(
				until_reservation,
				minf(impact_horizon, remaining - until_reservation)
			)
			if (
				float(lane_x) >= interval.x - clearance
				and float(lane_x) <= interval.y + clearance
			):
				lane_is_clear = false
				break
		if lane_is_clear:
			return true
	return false


func _nonballistic_candidate_preserves_d3_priority(
	candidate: Vector2,
	lifetime: float,
	d3: MotionBackgroundDropDirector,
	until_reservation: float
) -> bool:
	# This is the accepted VM-0.6.6 path verbatim. Keeping it separate prevents
	# the isolated ballistic prototype from changing control-build scheduling.
	var projected_coins: Array[Dictionary] = []
	for coin in active_collectibles():
		if (
			coin.time_remaining
			<= maxf(until_reservation - d3_priority_clearance_time, 0.0) + 0.0001
		):
			continue
		projected_coins.append({
			"x": coin.global_position.x,
			"remaining": coin.time_remaining,
			"size": coin.collectible_size,
		})
	var visible_lifetime := _visible_lifetime_for(candidate.x, lifetime)
	if (
		visible_lifetime
		> maxf(until_reservation - d3_priority_clearance_time, 0.0) + 0.0001
	):
		projected_coins.append({
			"x": candidate.x,
			"remaining": visible_lifetime,
			"size": collectible_size,
		})
	if projected_coins.is_empty():
		return true
	var excluded_lane := -1
	var prior_lanes := d3.selected_lane_indices()
	if d3.candidate_lane_x.size() > 1 and not prior_lanes.is_empty():
		excluded_lane = int(prior_lanes[-1])
	for lane_index in range(d3.candidate_lane_x.size()):
		if lane_index == excluded_lane:
			continue
		var blocked := false
		for coin_data in projected_coins:
			if _projected_coin_blocks_d3_lane(
				coin_data,
				float(d3.candidate_lane_x[lane_index]),
				until_reservation,
				d3.warning_duration + d3.target_fall_duration
			):
				blocked = true
				break
		if not blocked:
			return true
	return false


func _projected_coin_blocks_d3_lane(
	coin_data: Dictionary,
	lane_x: float,
	until_reservation: float,
	impact_horizon: float
) -> bool:
	if (
		float(coin_data.remaining)
		<= maxf(until_reservation - d3_priority_clearance_time, 0.0) + 0.0001
	):
		return false
	var clearance := (
		_conveyor.product_size.x + (coin_data.size as Vector2).x
	) * 0.5
	if coin_data.has("horizontal_interval"):
		var interval := coin_data.horizontal_interval as Vector2
		return (
			lane_x >= interval.x - clearance
			and lane_x <= interval.y + clearance
		)
	var speed := _conveyor.conveyor_speed_at(_conveyor.survival_time)
	var x_at_reservation := float(coin_data.x) - speed * until_reservation
	var left_at_impact := x_at_reservation - speed * maxf(impact_horizon, 0.0)
	return (
		lane_x >= left_at_impact - clearance
		and lane_x <= x_at_reservation + clearance
	)


func _projected_candidate_coin_data(
	candidate: Vector2,
	lifetime: float,
	ballistic_plan: Dictionary,
	seconds_from_now: float = 0.0,
	duration: float = 0.0
) -> Dictionary:
	if ballistic_plan.is_empty():
		return {
			"x": candidate.x,
			"remaining": _visible_lifetime_for(candidate.x, lifetime),
			"size": collectible_size,
		}
	return {
		"x": float((ballistic_plan.launch_position as Vector2).x),
		"remaining": (
			float(ballistic_plan.get("launch_delay", 0.0))
			+ float(ballistic_plan.flight_duration)
			+ float(ballistic_plan.effective_post_contact_lifetime)
		),
		"size": collectible_size,
		"horizontal_interval": _ballistic_plan_horizontal_interval(
			ballistic_plan,
			seconds_from_now,
			duration
		),
	}


func _visible_lifetime_for(candidate_x: float, requested_lifetime: float) -> float:
	if _conveyor.conveyor_speed <= 0.0:
		return maxf(requested_lifetime, 0.0)
	var time_to_left_edge := (
		candidate_x
		- collectible_size.x * 0.5
		- _conveyor.conveyor_support_left_x
	) / _conveyor.conveyor_speed
	return minf(maxf(requested_lifetime, 0.0), maxf(time_to_left_edge, 0.0))


func _minimum_event_spawn_x() -> float:
	return (
		_conveyor.conveyor_support_left_x
		+ collectible_size.x * 0.5
		+ _conveyor_distance_over_duration(
			maxf(minimum_guaranteed_visible_lifetime, 0.0)
		)
	)


func _restrict_event_bounds_to_side(bounds: Vector2, side: int) -> Vector2:
	if side not in [OfferSide.BEHIND, OfferSide.CENTRED, OfferSide.AHEAD]:
		return bounds
	var player_x := _conveyor.player.global_position.x
	var tolerance := (
		_conveyor.player_collision_size().x
		* maxf(offer_side_tolerance_player_widths, 0.0)
	)
	var strict_margin := maxf(scatter_position_quantum, 0.01)
	match side:
		OfferSide.BEHIND:
			bounds.y = minf(bounds.y, player_x - tolerance - strict_margin)
		OfferSide.CENTRED:
			bounds.x = maxf(bounds.x, player_x - tolerance)
			bounds.y = minf(bounds.y, player_x + tolerance)
		OfferSide.AHEAD:
			bounds.x = maxf(bounds.x, player_x + tolerance + strict_margin)
	return bounds


func _event_effective_visible_lifetime(
	candidate_x: float,
	requested_lifetime: float
) -> float:
	var requested := maxf(requested_lifetime, 0.0)
	if requested <= 0.0:
		return 0.0
	var available_distance := (
		candidate_x
		- collectible_size.x * 0.5
		- _conveyor.conveyor_support_left_x
	)
	if available_distance <= 0.0:
		return 0.0
	var elapsed := 0.0
	var travelled := 0.0
	var step := 1.0 / 120.0
	while elapsed + 0.000001 < requested:
		var delta := minf(step, requested - elapsed)
		var start_speed := _conveyor.conveyor_speed_at(
			_conveyor.survival_time + elapsed
		)
		var end_speed := _conveyor.conveyor_speed_at(
			_conveyor.survival_time + elapsed + delta
		)
		var distance := maxf((start_speed + end_speed) * 0.5 * delta, 0.0)
		if travelled + distance + 0.000001 >= available_distance:
			if distance <= 0.0:
				return requested
			return elapsed + delta * clampf(
				(available_distance - travelled) / distance,
				0.0,
				1.0
			)
		travelled += distance
		elapsed += delta
	return requested


func _conveyor_distance_over_duration(duration: float) -> float:
	var bounded_duration := maxf(duration, 0.0)
	var elapsed := 0.0
	var distance := 0.0
	var step := 1.0 / 120.0
	while elapsed + 0.000001 < bounded_duration:
		var delta := minf(step, bounded_duration - elapsed)
		var start_speed := _conveyor.conveyor_speed_at(
			_conveyor.survival_time + elapsed
		)
		var end_speed := _conveyor.conveyor_speed_at(
			_conveyor.survival_time + elapsed + delta
		)
		distance += maxf((start_speed + end_speed) * 0.5 * delta, 0.0)
		elapsed += delta
	return distance


func _ballistic_flight_duration(archetype: int) -> float:
	if ballistic_flight_durations.is_empty():
		return 0.9
	var index := clampi(archetype, 0, ballistic_flight_durations.size() - 1)
	return maxf(float(ballistic_flight_durations[index]), 0.01)


func _ballistic_launch_origin(archetype: int) -> Vector2:
	if ballistic_launch_origins.is_empty():
		return Vector2(760.0, 260.0)
	var index := clampi(archetype, 0, ballistic_launch_origins.size() - 1)
	return ballistic_launch_origins[index]


func _ballistic_contact_y() -> float:
	return _conveyor.floor_y - collectible_size.y * 0.5


func _build_ballistic_plan(
	landing_position: Vector2,
	archetype: int,
	requested_post_contact_lifetime: float,
	launch_delay: float = 0.0,
	apply_variation: bool = false
) -> Dictionary:
	var flight_duration := _ballistic_flight_duration(archetype)
	var launch_position := _ballistic_launch_origin(archetype)
	if apply_variation:
		launch_position += Vector2(
			_stream_random_range(Vector2(
				-ballistic_launch_origin_variance.x,
				ballistic_launch_origin_variance.x
			)),
			_stream_random_range(Vector2(
				-ballistic_launch_origin_variance.y,
				ballistic_launch_origin_variance.y
			))
		)
		var duration_variance := _stream_random_range(Vector2(
			-ballistic_flight_duration_variance_ratio,
			ballistic_flight_duration_variance_ratio
		))
		flight_duration *= 1.0 + duration_variance
	flight_duration = maxf(flight_duration, 0.01)
	var launch_velocity := Vector2(
		(landing_position.x - launch_position.x) / flight_duration,
		(
			landing_position.y
			- launch_position.y
			- 0.5 * ballistic_gravity * flight_duration * flight_duration
		) / flight_duration
	)
	var effective_lifetime := _ballistic_post_contact_effective_lifetime(
		landing_position.x,
		requested_post_contact_lifetime,
		flight_duration,
		launch_delay
	)
	return {
		"archetype": archetype,
		"launch_position": launch_position,
		"landing_position": landing_position,
		"launch_velocity": launch_velocity,
		"flight_duration": flight_duration,
		"launch_delay": maxf(launch_delay, 0.0),
		"gravity": ballistic_gravity,
		"requested_post_contact_lifetime": requested_post_contact_lifetime,
		"effective_post_contact_lifetime": effective_lifetime,
	}


func _minimum_ballistic_landing_x(flight_duration: float) -> float:
	return (
		_conveyor.conveyor_support_left_x
		+ collectible_size.x * 0.5
		+ _conveyor_distance_between(
			maxf(flight_duration, 0.0),
			maxf(ballistic_minimum_post_contact_visible_lifetime, 0.0)
		)
	)


func _ballistic_post_contact_effective_lifetime(
	landing_x: float,
	requested_lifetime: float,
	flight_duration: float,
	launch_delay: float = 0.0
) -> float:
	var requested := maxf(requested_lifetime, 0.0)
	var available_distance := (
		landing_x
		- collectible_size.x * 0.5
		- _conveyor.conveyor_support_left_x
	)
	if requested <= 0.0 or available_distance <= 0.0:
		return 0.0
	if ballistic_integrity_enabled:
		return _time_until_conveyor_distance(
			launch_delay + flight_duration,
			requested,
			available_distance
		)
	var elapsed := 0.0
	var travelled := 0.0
	var step := 1.0 / 120.0
	while elapsed + 0.000001 < requested:
		var delta := minf(step, requested - elapsed)
		var start_speed := _conveyor.conveyor_speed_at(
			_conveyor.survival_time + launch_delay + flight_duration + elapsed
		)
		var end_speed := _conveyor.conveyor_speed_at(
			_conveyor.survival_time + launch_delay + flight_duration + elapsed + delta
		)
		var distance := maxf((start_speed + end_speed) * 0.5 * delta, 0.0)
		if travelled + distance + 0.000001 >= available_distance:
			if distance <= 0.0:
				return requested
			return elapsed + delta * clampf(
				(available_distance - travelled) / distance,
				0.0,
				1.0
			)
		travelled += distance
		elapsed += delta
	return requested


func _conveyor_distance_between(start_delay: float, duration: float) -> float:
	var bounded_duration := maxf(duration, 0.0)
	if ballistic_integrity_enabled:
		return _integrated_conveyor_distance(
			maxf(start_delay, 0.0),
			bounded_duration
		)
	var elapsed := 0.0
	var distance := 0.0
	var step := 1.0 / 120.0
	while elapsed + 0.000001 < bounded_duration:
		var delta := minf(step, bounded_duration - elapsed)
		var start_speed := _conveyor.conveyor_speed_at(
			_conveyor.survival_time + maxf(start_delay, 0.0) + elapsed
		)
		var end_speed := _conveyor.conveyor_speed_at(
			_conveyor.survival_time + maxf(start_delay, 0.0) + elapsed + delta
		)
		distance += maxf((start_speed + end_speed) * 0.5 * delta, 0.0)
		elapsed += delta
	return distance


func _integrated_conveyor_distance(start_delay: float, duration: float) -> float:
	if duration <= 0.0:
		return 0.0
	# Composite Simpson integration is exact for the current cubic smoothstep
	# speed ramp when it is not clamped, and remains tightly bounded if exported
	# values introduce a clamp boundary. It replaces hundreds of 120 Hz samples
	# in candidate planning without changing runtime conveyor physics.
	var intervals := 8
	var step := duration / float(intervals)
	var weighted_speed := 0.0
	for index in range(intervals + 1):
		var sample_time := (
			_conveyor.survival_time
			+ maxf(start_delay, 0.0)
			+ step * float(index)
		)
		var weight := 1.0
		if index > 0 and index < intervals:
			weight = 4.0 if index % 2 == 1 else 2.0
		weighted_speed += weight * maxf(
			_conveyor.conveyor_speed_at(sample_time),
			0.0
		)
	return weighted_speed * step / 3.0


func _time_until_conveyor_distance(
	start_delay: float,
	maximum_duration: float,
	target_distance: float
) -> float:
	var bounded_duration := maxf(maximum_duration, 0.0)
	if target_distance <= 0.0 or bounded_duration <= 0.0:
		return 0.0
	if (
		_integrated_conveyor_distance(start_delay, bounded_duration)
		<= target_distance + 0.0001
	):
		return bounded_duration
	var lower := 0.0
	var upper := bounded_duration
	for _iteration in range(14):
		var midpoint := (lower + upper) * 0.5
		if (
			_integrated_conveyor_distance(start_delay, midpoint)
			< target_distance
		):
			lower = midpoint
		else:
			upper = midpoint
	return upper


func _ballistic_plan_position_at(plan: Dictionary, elapsed: float) -> Vector2:
	var launch := plan.launch_position as Vector2
	var landing := plan.landing_position as Vector2
	var velocity := plan.launch_velocity as Vector2
	var flight_duration := float(plan.flight_duration)
	var bounded_elapsed := maxf(elapsed, 0.0)
	var launch_delay := float(plan.get("launch_delay", 0.0))
	if bounded_elapsed <= launch_delay:
		return launch
	bounded_elapsed -= launch_delay
	if bounded_elapsed <= flight_duration:
		return Vector2(
			launch.x + velocity.x * bounded_elapsed,
			launch.y
			+ velocity.y * bounded_elapsed
			+ 0.5 * float(plan.gravity) * bounded_elapsed * bounded_elapsed
		)
	return Vector2(
		landing.x - _conveyor_distance_between(
			launch_delay + flight_duration,
			bounded_elapsed - flight_duration
		),
		landing.y
	)


func _ballistic_plan_horizontal_interval(
	plan: Dictionary,
	seconds_from_now: float,
	duration: float
) -> Vector2:
	var start := maxf(seconds_from_now, 0.0)
	var end := start + maxf(duration, 0.0)
	var samples := PackedFloat32Array([start, end])
	var launch_delay := float(plan.get("launch_delay", 0.0))
	var flight_end := launch_delay + float(plan.flight_duration)
	if launch_delay > start and launch_delay < end:
		samples.append(launch_delay)
	if flight_end > start and flight_end < end:
		samples.append(flight_end)
	var minimum_x := INF
	var maximum_x := -INF
	for sample_time in samples:
		var sample_x := _ballistic_plan_position_at(plan, float(sample_time)).x
		minimum_x = minf(minimum_x, sample_x)
		maximum_x = maxf(maximum_x, sample_x)
	return Vector2(minimum_x, maximum_x)


func _ballistic_trajectory_separation_is_valid(
	candidate_plan: Dictionary,
	sibling_plans: Array[Dictionary]
) -> bool:
	var minimum_separation := maxf(
		ballistic_minimum_trajectory_separation,
		collectible_size.x + 1.0
	)
	for sibling_plan in sibling_plans:
		if performance_profiling_enabled:
			_performance_current_event_trajectory_checks += 1
		var candidate_start := float(candidate_plan.get("launch_delay", 0.0))
		var sibling_start := float(sibling_plan.get("launch_delay", 0.0))
		var overlap_start := maxf(candidate_start, sibling_start)
		var overlap_end := minf(
			candidate_start + float(candidate_plan.flight_duration),
			sibling_start + float(sibling_plan.flight_duration)
		)
		if overlap_end < overlap_start:
			continue
		var elapsed := overlap_start
		while elapsed <= overlap_end + 0.000001:
			var candidate_position := _ballistic_plan_position_at(
				candidate_plan,
				elapsed
			)
			var sibling_position := _ballistic_plan_position_at(
				sibling_plan,
				elapsed
			)
			if candidate_position.distance_to(sibling_position) < minimum_separation:
				return false
			elapsed += 1.0 / 60.0
	return true


func _ballistic_post_contact_separation_is_valid(
	candidate_plan: Dictionary,
	sibling_plans: Array[Dictionary]
) -> bool:
	var minimum_separation := maxf(
		coin_event_sibling_minimum_separation,
		collectible_size.x + 1.0
	)
	var candidate_contact := (
		float(candidate_plan.get("launch_delay", 0.0))
		+ float(candidate_plan.flight_duration)
	)
	var candidate_end := (
		candidate_contact
		+ float(candidate_plan.effective_post_contact_lifetime)
	)
	for sibling_plan in sibling_plans:
		var sibling_contact := (
			float(sibling_plan.get("launch_delay", 0.0))
			+ float(sibling_plan.flight_duration)
		)
		var sibling_end := (
			sibling_contact
			+ float(sibling_plan.effective_post_contact_lifetime)
		)
		var shared_ground_start := maxf(candidate_contact, sibling_contact)
		if minf(candidate_end, sibling_end) <= shared_ground_start + 0.0001:
			continue
		var candidate_position := _ballistic_plan_position_at(
			candidate_plan,
			shared_ground_start
		)
		var sibling_position := _ballistic_plan_position_at(
			sibling_plan,
			shared_ground_start
		)
		if (
			absf(candidate_position.x - sibling_position.x) + 0.001
			< minimum_separation
		):
			return false
	return true


func _ballistic_active_opportunity_separation_is_valid(
	candidate_plan: Dictionary
) -> bool:
	var candidate_contact := (
		float(candidate_plan.get("launch_delay", 0.0))
		+ float(candidate_plan.flight_duration)
	)
	var candidate_x := Vector2(candidate_plan.landing_position).x
	var minimum_separation := maxf(
		coin_event_minimum_separation,
		collectible_size.x + 1.0
	)
	for existing in active_collectibles():
		if existing.total_collectible_time_remaining() <= candidate_contact + 0.0001:
			continue
		var projected := existing.projected_horizontal_interval(
			candidate_contact,
			0.0
		)
		var existing_x := (projected.x + projected.y) * 0.5
		if absf(candidate_x - existing_x) + 0.001 < minimum_separation:
			return false
	return true


func _candidate_is_reachable_with_lifetime(
	candidate: Vector2,
	band: int,
	visible_lifetime: float
) -> bool:
	var relative_control_speed := _conveyor.player.maximum_speed
	if relative_control_speed <= _conveyor.conveyor_speed:
		return false
	var available_time := maxf(visible_lifetime - reachability_reserve, 0.0)
	var horizontal_time := (
		absf(candidate.x - _conveyor.player.global_position.x) / relative_control_speed
		if relative_control_speed > 0.0
		else INF
	)
	if band == PlacementBand.GROUND:
		return (
			_grounded_player_overlaps_y(candidate.y)
			and horizontal_time <= available_time + 0.0001
		)
	var intervals := normal_jump_collection_intervals(candidate.y)
	if intervals.is_empty() or _grounded_player_overlaps_y(candidate.y):
		return false
	return (
		normal_jump_collection_margin(candidate.y) >= minimum_normal_jump_margin
		and maxf(horizontal_time, intervals[0].x) <= available_time + 0.0001
	)


func _stream_random_range(configured: Vector2) -> float:
	var minimum := minf(configured.x, configured.y)
	var maximum := maxf(configured.x, configured.y)
	_stream_rng_state = _next_rng_state(_stream_rng_state)
	var unit := float(_stream_rng_state) / float(0x7fffffff)
	return lerpf(minimum, maximum, unit)


func _stream_probability_roll(probability: float) -> bool:
	var clamped := clampf(probability, 0.0, 1.0)
	if clamped <= 0.0:
		return false
	if clamped >= 1.0:
		return true
	_stream_rng_state = _next_rng_state(_stream_rng_state)
	return (
		float(_stream_rng_state) / float(0x7fffffff)
		< clamped
	)


func _record_stream_rejection(
	spawn_kind: String,
	reason: String,
	lifetime: float,
	placement_attempts: int
) -> void:
	var known_reason := reason if reason in known_rejection_reasons() else REJECTION_UNKNOWN
	_offer_log.append({
		"event": "attempt",
		"time": _conveyor.survival_time,
		"phase": phase_at(_conveyor.survival_time),
		"template": SCATTER_TEMPLATE,
		"template_name": "variable coin event" if spawn_kind == "event" else "independent coin",
		"intended_count": 1,
		"accepted": false,
		"rejection_reason": known_reason,
		"spawn_timestamp": -1.0,
		"resolve_timestamp": -1.0,
		"spawned_offer_id": -1,
		"resolved_offer_id": -1,
		"collected": 0,
		"expired": 0,
		"next_scheduled_time": _next_spawn_time,
		"active_offer_count": _active_offers.size(),
		"active_coin_count": active_collectible_count(),
		"natural": true,
		"topology": "VARIABLE_EVENT" if spawn_kind == "event" else "INDEPENDENT_STREAM",
		"pair_mode": false,
		"candidate_positions": [],
		"placement_attempts": placement_attempts,
		"spawn_kind": spawn_kind,
		"coin_lifetime": lifetime,
	})
	_rejection_counts[known_reason] = int(_rejection_counts.get(known_reason, 0)) + 1


func _try_spawn_template(
	template: int,
	intended_count: int,
	natural: bool,
	side_preference: int = -1,
	anti_streak_requested: bool = false,
	pair_mode: bool = false
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
		"topology": "CONSTRAINED_SCATTER" if template == SCATTER_TEMPLATE else "AUTHORED_ROUTE",
		"pair_mode": pair_mode,
		"minimum_pairwise_separation": INF,
		"candidate_positions": [],
		"scatter_layout_attempts": 0,
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
	var original_candidates := (
		_scatter_candidates(
			intended_count,
			pair_mode,
			side_preference,
			natural and _natural_offer_count == 0
		)
		if template == SCATTER_TEMPLATE
		else _template_candidates(template, intended_count, side_preference)
	)
	log_entry.scatter_layout_attempts = _last_scatter_layout_attempts if template == SCATTER_TEMPLATE else 0
	if original_candidates.is_empty():
		if template == SCATTER_TEMPLATE:
			_scatter_exhausted_count += 1
		return _reject_attempt(
			log_entry,
			REJECTION_SCATTER_EXHAUSTED if template == SCATTER_TEMPLATE else REJECTION_UNKNOWN
		)
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
	log_entry.candidate_positions = candidates.map(
		func(candidate: Dictionary) -> Vector2: return candidate.position
	)
	log_entry.minimum_pairwise_separation = _minimum_pairwise_separation(candidates)
	var accepted_candidates: Array[Dictionary] = candidates
	if not _offer_has_reachable_response(accepted_candidates):
		return _reject_attempt(log_entry, REJECTION_UNREACHABLE)
	if template != SCATTER_TEMPLATE and _is_post_teaching_route(template):
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
	if template == SCATTER_TEMPLATE:
		cadence *= scatter_cadence_multiplier
	elif anti_streak_requested:
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
	coin_index: int,
	lifetime_override: float = -1.0,
	expiry_warning_override: float = -1.0,
	effective_lifetime_override: float = -1.0,
	ballistic_plan: Dictionary = {}
) -> ConveyorCollectible:
	var coin := COLLECTIBLE_SCENE.instantiate() as ConveyorCollectible
	add_child(coin)
	coin.global_position = candidate_data.position
	var requested_lifetime := (
		collectible_lifetime
		if lifetime_override < 0.0
		else lifetime_override
	)
	var effective_lifetime := (
		_visible_lifetime_for(candidate_data.position.x, requested_lifetime)
		if effective_lifetime_override < 0.0
		else effective_lifetime_override
	)
	coin.configure(
		effective_lifetime,
		_conveyor.conveyor_speed,
		collectible_size,
		candidate_data.band,
		offer_id * 101 + coin_index * 37 + placement_seed,
		expiry_warning_override
	)
	if not ballistic_plan.is_empty():
		coin.configure_ballistic(
			ballistic_plan.launch_position,
			ballistic_plan.landing_position,
			ballistic_plan.launch_velocity,
			float(ballistic_plan.flight_duration),
			float(ballistic_plan.gravity),
			effective_lifetime,
			_conveyor.conveyor_speed,
			ballistic_bounce_restitutions,
			float(ballistic_plan.get("launch_delay", 0.0)),
			_conveyor.conveyor_support_left_x
		)
		if ballistic_abundance_enabled:
			coin.configure_landed_can_collision(
				Callable(self, "_landed_can_collision_rects"),
				Vector2(
					_conveyor.conveyor_support_left_x + collectible_size.x * 0.5,
					_conveyor.control_band_right - collectible_size.x * 0.5
				),
				ballistic_maximum_landed_can_ricochets,
				ballistic_can_top_restitution,
				ballistic_can_side_horizontal_restitution,
				ballistic_can_side_upward_speed,
				ballistic_can_horizontal_deflection
			)
			coin.landed_can_ricochet.connect(_on_ballistic_landed_can_ricochet)
	coin.set_meta("offer_id", offer_id)
	coin.collected.connect(_on_collectible_collected.bind(offer_id))
	coin.expired.connect(_on_collectible_expired.bind(offer_id))
	collectible_spawned.emit(coin)
	return coin


func _candidate_visible_lifetime(candidate_x: float) -> float:
	return _visible_lifetime_for(candidate_x, collectible_lifetime)


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
		REJECTION_SCATTER_EXHAUSTED,
		REJECTION_D3_PRIORITY,
		REJECTION_UNKNOWN,
	])


func template_name(template: int) -> String:
	if template == SCATTER_TEMPLATE:
		return "constrained scatter"
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
	if template == SCATTER_TEMPLATE:
		return "SCATTER"
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


func _select_scatter_count() -> int:
	var weights := scatter_offer_count_weights
	if weights.size() != 3:
		return 2
	var total := 0
	for weight in weights:
		total += maxi(weight, 0)
	if total <= 0:
		return 2
	_placement_rng_state = _next_rng_state(_placement_rng_state)
	var roll := posmod(_placement_rng_state, total)
	for index in range(3):
		roll -= maxi(weights[index], 0)
		if roll < 0:
			return index + 1
	return 3


func _select_scatter_pair_mode() -> bool:
	var probability := clampf(scatter_pair_mode_probability, 0.0, 1.0)
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	_placement_rng_state = _next_rng_state(_placement_rng_state)
	return posmod(_placement_rng_state, 10000) < roundi(probability * 10000.0)


func _scatter_correction_side_preferences() -> Array[int]:
	var right_limit := _conveyor.control_band_right - collectible_size.x * 0.5
	var ahead_threshold := (
		_conveyor.player.global_position.x
		+ _conveyor.player_collision_size().x * maxf(offer_side_tolerance_player_widths, 0.0)
	)
	if right_limit <= ahead_threshold:
		return [OfferSide.CENTRED]
	return [OfferSide.AHEAD, OfferSide.CENTRED]


func _scatter_candidates(
	intended_count: int,
	pair_mode: bool,
	side_preference: int = -1,
	force_ground_single: bool = false
) -> Array[Dictionary]:
	_last_scatter_layout_attempts = 0
	var count := clampi(intended_count, 1, 3)
	var bounds := _scatter_x_bounds(side_preference, count)
	if bounds.y <= bounds.x:
		return []
	for layout_attempt in range(1, maxi(maximum_scatter_layout_attempts, 1) + 1):
		_last_scatter_layout_attempts = layout_attempt
		var candidates: Array[Dictionary] = []
		if pair_mode and count >= 2:
			candidates = _sample_pair_layout(count, bounds)
		else:
			for candidate_index in range(count):
				var candidate := _sample_scatter_candidate(
					bounds,
					PlacementBand.GROUND if force_ground_single and count == 1 else -1
				)
				candidate.route_branch = "scatter_%d" % candidate_index
				candidates.append(candidate)
		if candidates.size() != count:
			continue
		if side_preference in [OfferSide.BEHIND, OfferSide.CENTRED, OfferSide.AHEAD]:
			for index in range(candidates.size()):
				candidates[index].allow_right_edge = side_preference in [OfferSide.CENTRED, OfferSide.AHEAD]
			candidates = _translate_candidates_for_side(candidates, side_preference)
		if not _scatter_separation_is_valid(candidates, pair_mode):
			continue
		if count == 3 and not pair_mode and _scatter_is_trivially_collinear(candidates):
			continue
		if not _scatter_side_matches(candidates, side_preference):
			continue
		if not String(_offer_candidate_rejection(candidates).reason).is_empty():
			continue
		if not _offer_has_reachable_response(candidates):
			continue
		return candidates
	return []


func _sample_pair_layout(count: int, bounds: Vector2) -> Array[Dictionary]:
	var separation := clampf(
		pair_mode_separation,
		collectible_size.x + 1.0,
		maxf(minimum_scatter_separation - 1.0, collectible_size.x + 1.0)
	)
	if bounds.y - bounds.x < separation:
		return []
	var pair_band := _random_band()
	var pair_y := _sample_band_y(pair_band)
	var pair_center := _sample_quantized(
		bounds.x + separation * 0.5,
		bounds.y - separation * 0.5
	)
	var candidates: Array[Dictionary] = [
		{
			"position": Vector2(pair_center - separation * 0.5, pair_y),
			"band": pair_band,
			"route_branch": "pair_a",
		},
		{
			"position": Vector2(pair_center + separation * 0.5, pair_y),
			"band": pair_band,
			"route_branch": "pair_b",
		},
	]
	if count == 3:
		var third := _sample_scatter_candidate(
			bounds,
			PlacementBand.LOW_AIR if pair_band == PlacementBand.GROUND else PlacementBand.GROUND
		)
		third.route_branch = "distant_choice"
		candidates.append(third)
	return candidates


func _sample_scatter_candidate(bounds: Vector2, forced_band: int = -1) -> Dictionary:
	var band := forced_band if forced_band in [PlacementBand.GROUND, PlacementBand.LOW_AIR] else _random_band()
	return {
		"position": Vector2(_sample_quantized(bounds.x, bounds.y), _sample_band_y(band)),
		"band": band,
		"route_branch": "scatter",
	}


func _scatter_x_bounds(side_preference: int, count: int) -> Vector2:
	var bounds := _route_bounds()
	if side_preference in [OfferSide.CENTRED, OfferSide.AHEAD]:
		bounds.y = _conveyor.control_band_right - collectible_size.x * 0.5
	if side_preference == OfferSide.AHEAD and count == 1:
		bounds.x = maxf(
			bounds.x,
			_conveyor.player.global_position.x + _conveyor.player_collision_size().x
		)
	elif side_preference == OfferSide.CENTRED and count == 1:
		var player_x := _conveyor.player.global_position.x
		var radius := _conveyor.player_collision_size().x * 2.0
		bounds.x = maxf(bounds.x, player_x - radius)
		bounds.y = minf(bounds.y, player_x + radius)
	return bounds


func _scatter_side_matches(candidates: Array[Dictionary], side_preference: int) -> bool:
	if side_preference not in [OfferSide.BEHIND, OfferSide.CENTRED, OfferSide.AHEAD]:
		return true
	return classify_offer_side_for_test(
		candidates,
		_conveyor.player.global_position.x
	) == side_preference


func _random_band() -> int:
	_placement_rng_state = _next_rng_state(_placement_rng_state)
	return _band_from_roll(_placement_rng_state)


func _sample_band_y(band: int) -> float:
	var y_range := ground_band_center_y_range if band == PlacementBand.GROUND else low_air_band_center_y_range
	return _sample_quantized(y_range.x, y_range.y)


func _sample_quantized(minimum: float, maximum: float) -> float:
	if maximum <= minimum:
		return minimum
	_placement_rng_state = _next_rng_state(_placement_rng_state)
	var unit := float(_placement_rng_state) / float(0x7fffffff)
	var sampled := lerpf(minimum, maximum, unit)
	var quantum := maxf(scatter_position_quantum, 0.01)
	return clampf(roundf(sampled / quantum) * quantum, minimum, maximum)


func _scatter_separation_is_valid(candidates: Array[Dictionary], pair_mode: bool) -> bool:
	for first_index in range(candidates.size()):
		for second_index in range(first_index + 1, candidates.size()):
			var required := minimum_scatter_separation
			if pair_mode and first_index == 0 and second_index == 1:
				required = pair_mode_separation
			if (
				(candidates[first_index].position as Vector2).distance_to(
					candidates[second_index].position
				) + 0.001
				< required
			):
				return false
	return true


func _scatter_is_trivially_collinear(candidates: Array[Dictionary]) -> bool:
	if candidates.size() != 3:
		return false
	var first: Vector2 = candidates[0].position
	var second: Vector2 = candidates[1].position
	var third: Vector2 = candidates[2].position
	var twice_area := absf((second - first).cross(third - first))
	return twice_area < maxf(scatter_collinearity_area_threshold, 0.0)


func _minimum_pairwise_separation(candidates: Array[Dictionary]) -> float:
	if candidates.size() < 2:
		return INF
	var minimum := INF
	for first_index in range(candidates.size()):
		for second_index in range(first_index + 1, candidates.size()):
			minimum = minf(
				minimum,
				(candidates[first_index].position as Vector2).distance_to(
					candidates[second_index].position
				)
			)
	return minimum


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
	allow_right_edge: bool = false,
	visible_lifetime_override: float = -1.0,
	allow_landed_can_ricochet: bool = false
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
	var available_time := (
		_candidate_available_time(candidate.x)
		if visible_lifetime_override < 0.0
		else maxf(visible_lifetime_override - reachability_reserve, 0.0)
	)
	if available_time <= 0.0:
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
	if _can_hazard_conflicts(
		candidate,
		visible_lifetime_override,
		allow_landed_can_ricochet
	):
		return REJECTION_CAN_OVERLAP
	if _sweeper_schedule_conflicts(candidate, band):
		return REJECTION_SWEEPER
	return ""


func _offer_has_reachable_response(candidates: Array[Dictionary]) -> bool:
	for candidate in candidates:
		if candidate_is_reachable(candidate.position, candidate.band):
			return true
	return false


func _can_hazard_conflicts(
	candidate: Vector2,
	visible_lifetime_override: float = -1.0,
	allow_landed_can_ricochet: bool = false
) -> bool:
	for product in _conveyor.active_falling_products():
		if _falling_can_path_conflicts(candidate, product, visible_lifetime_override):
			return true
	if not allow_landed_can_ricochet:
		for product in _conveyor.active_landed_products():
			var landed_center := Vector2(product.conveyor_center_x(), product.global_position.y)
			if _rectangles_overlap(candidate, collectible_size, landed_center, product.landed_size):
				return true
	return _warning_or_reserved_can_conflicts(candidate.x, visible_lifetime_override)


func _falling_can_path_conflicts(
	candidate: Vector2,
	product: ConveyorProduct,
	visible_lifetime_override: float = -1.0
) -> bool:
	var visible_lifetime := (
		_candidate_visible_lifetime(candidate.x)
		if visible_lifetime_override < 0.0
		else visible_lifetime_override
	)
	var coin_left_at_expiry := candidate.x - _conveyor.conveyor_speed * visible_lifetime
	var half_width_sum := (collectible_size.x + product.falling_size.x) * 0.5
	return product.global_position.x >= coin_left_at_expiry - half_width_sum and product.global_position.x <= candidate.x + half_width_sum


func _warning_or_reserved_can_conflicts(
	candidate_x: float,
	visible_lifetime_override: float = -1.0
) -> bool:
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
	var visible_lifetime := (
		_candidate_visible_lifetime(candidate_x)
		if visible_lifetime_override < 0.0
		else visible_lifetime_override
	)
	var coin_left_at_expiry := candidate_x - _conveyor.conveyor_speed * visible_lifetime
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


func _landed_can_collision_rects() -> Array[Dictionary]:
	if not ballistic_integrity_enabled:
		return _collect_landed_can_collision_rects()
	var physics_frame := Engine.get_physics_frames()
	if _landed_can_collision_cache_frame != physics_frame:
		_landed_can_collision_cache = _collect_landed_can_collision_rects()
		_landed_can_collision_cache_frame = physics_frame
		if performance_profiling_enabled:
			_performance_landed_can_cache_rebuild_count += 1
	if performance_profiling_enabled:
		_performance_landed_can_query_count += 1
		_performance_landed_can_rect_count += _landed_can_collision_cache.size()
	return _landed_can_collision_cache


func invalidate_landed_can_collision_cache_for_test() -> void:
	_landed_can_collision_cache_frame = -1


func _collect_landed_can_collision_rects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for product in _conveyor.active_landed_products():
		if not is_instance_valid(product):
			continue
		result.append({
			"id": product.get_instance_id(),
			"center": Vector2(
				product.conveyor_center_x(),
				product.global_position.y
			),
			"size": product.landed_size,
		})
	if performance_profiling_enabled and not ballistic_integrity_enabled:
		_performance_landed_can_query_count += 1
		_performance_landed_can_rect_count += result.size()
	return result


func _begin_performance_event_profile() -> void:
	if not performance_profiling_enabled:
		return
	_performance_current_event_started_usec = Time.get_ticks_usec()
	_performance_current_event_placement_attempts = 0
	_performance_current_event_trajectory_checks = 0


func _end_performance_event_profile(requested_count: int, delivered_count: int) -> void:
	if not performance_profiling_enabled:
		return
	var elapsed_usec := maxi(
		Time.get_ticks_usec() - _performance_current_event_started_usec,
		0
	)
	_performance_event_log.append({
		"time": _conveyor.survival_time,
		"requested_count": requested_count,
		"delivered_count": delivered_count,
		"planning_ms": float(elapsed_usec) / 1000.0,
		"placement_attempts": _performance_current_event_placement_attempts,
		"trajectory_checks": _performance_current_event_trajectory_checks,
	})


func _update_ballistic_player_crossings() -> void:
	if not is_instance_valid(_conveyor.player):
		return
	for coin in active_collectibles():
		if (
			not coin.is_ballistic()
			or coin.motion_state() != ConveyorCollectible.MotionState.AIRBORNE
			or bool(coin.get_meta("ballistic_crossed_player", false))
		):
			continue
		var current_delta := coin.global_position.x - _conveyor.player.global_position.x
		var previous_delta := float(
			coin.get_meta("ballistic_previous_player_delta_x", current_delta)
		)
		var crossing_margin := (
			coin.collectible_size.x + _conveyor.player_collision_size().x
		) * 0.5
		if (
			absf(current_delta) <= crossing_margin
			or signf(current_delta) != signf(previous_delta)
		):
			coin.set_meta("ballistic_crossed_player", true)
			coin.set_meta("ballistic_cross_time", _conveyor.survival_time)
			_ballistic_player_crossing_count += 1
		coin.set_meta("ballistic_previous_player_delta_x", current_delta)


func _enforce_scheduling_invariant() -> void:
	if _conveyor.gameplay_is_stopped() or _stopped:
		return
	if not is_finite(_next_spawn_time):
		_record_invariant(REJECTION_UNKNOWN)
		_next_spawn_time = _conveyor.survival_time + failed_spawn_retry_delay
	if ballistic_coin_events_enabled:
		# A D3-protected gap is intentional in this isolated prototype. Keep the
		# accepted 1.10–2.10 second event-attempt cadence instead of allowing the
		# generic empty-stream watchdog to convert it into 0.10 second retries.
		return
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
	# A queued collision after death/completion cannot change the final score.
	if _stopped:
		return
	if collectible.is_ballistic():
		var phase := collectible.collection_phase()
		_ballistic_collection_counts[phase] = int(
			_ballistic_collection_counts.get(phase, 0)
		) + 1
		var collection_time := collectible.collection_time_from_launch()
		if collection_time >= 0.0:
			_ballistic_collection_time_total += collection_time
			_ballistic_collection_time_samples += 1
	_resolve_coin(collectible, offer_id, true)


func _on_collectible_expired(collectible: ConveyorCollectible, offer_id: int) -> void:
	if collectible.is_ballistic():
		if collectible.resolution_reason() == "EXITED_LEFT":
			_ballistic_exited_left_count += 1
		else:
			_ballistic_expired_count += 1
	_resolve_coin(collectible, offer_id, false)


func _on_ballistic_landed_can_ricochet(
	_collectible: ConveyorCollectible,
	_ricochet_count: int,
	_contact_kind: String
) -> void:
	_ballistic_total_ricochet_count += 1


func _on_ballistic_first_contact(collectible: ConveyorCollectible) -> void:
	_ballistic_first_contact_count += 1
	var side := classify_offer_side_for_test(
		[{"position": collectible.global_position}],
		_conveyor.player.global_position.x
	)
	collectible.set_meta("ballistic_first_landing_side", side)
	_ballistic_landing_side_counts[side] += 1


func _on_ballistic_settled(collectible: ConveyorCollectible) -> void:
	_ballistic_settled_count += 1
	var side := classify_offer_side_for_test(
		[{"position": collectible.global_position}],
		_conveyor.player.global_position.x
	)
	collectible.set_meta("ballistic_settle_side", side)
	_ballistic_settle_side_counts[side] += 1


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
