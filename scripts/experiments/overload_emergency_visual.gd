class_name OverloadEmergencyVisual
extends Node2D

enum Stage { UNSTABLE, WARNING, CRITICAL, SEVERE, CATASTROPHIC, MAX }

const ROOT := "res://assets/visuals/vm081_overload/emergency/"
const STAGE_NAMES := ["UNSTABLE", "WARNING", "CRITICAL", "SEVERE", "CATASTROPHIC", "MAX"]
const RED_LIGHT := Color("d53f4f")

@export var warning_threshold_seconds: float = 15.0
@export var critical_threshold_seconds: float = 30.0
@export var severe_threshold_seconds: float = 45.0
@export var catastrophic_threshold_seconds: float = 60.0
@export var maximum_threshold_seconds: float = 90.0
@export var reduced_motion: bool = false
@export var debug_stage_keys_enabled: bool = false
@export var transition_jolt_duration: float = 0.18
@export var transition_jolt_amplitude_pixels: int = 2
@export var maximum_vibration_amplitude_pixels: int = 1
@export var maximum_vibration_frequency_hz: float = 8.0

var conveyor: ConveyorPrototype
var background_drop_director: MotionBackgroundDropDirector
var current_stage: int = Stage.UNSTABLE
var maximum_stage_reached: int = Stage.UNSTABLE
var _forced_stage: int = -1
var _elapsed: float = 0.0
var _warning_hold_remaining: float = 0.0
var _transition_twitch_remaining: float = 0.0
var _beacons: Array[Sprite2D] = []
var _lenses: Array[Sprite2D] = []
var _top_cover: Sprite2D
var _loose_hatch: Sprite2D
var _right_cover: Sprite2D
var _left_cover: Sprite2D
var _texture_cache: Dictionary = {}


func _ready() -> void:
	z_index = 42
	_build_visuals()
	if conveyor != null:
		conveyor.sweeper_entry_cue_started.connect(_on_sweeper_warning)
		conveyor.telegraph_started.connect(_on_product_warning)
	if background_drop_director != null:
		background_drop_director.warning_started.connect(_on_d3_warning)
	_apply_stage(true)


func _process(delta: float) -> void:
	if conveyor == null:
		return
	_elapsed += delta
	_warning_hold_remaining = maxf(_warning_hold_remaining - delta, 0.0)
	_transition_twitch_remaining = maxf(_transition_twitch_remaining - delta, 0.0)
	var next_stage := _forced_stage if _forced_stage >= 0 else stage_at(conveyor.survival_time)
	if next_stage != current_stage:
		current_stage = next_stage
		maximum_stage_reached = maxi(maximum_stage_reached, current_stage)
		_transition_twitch_remaining = transition_jolt_duration
		_apply_stage(false)
	_update_motion()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not debug_stage_keys_enabled or not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_forced_stage = posmod((_forced_stage if _forced_stage >= 0 else int(current_stage)) + 1, STAGE_NAMES.size())


func stage_at(time_seconds: float) -> int:
	if time_seconds >= maximum_threshold_seconds:
		return Stage.MAX
	if time_seconds >= catastrophic_threshold_seconds:
		return Stage.CATASTROPHIC
	if time_seconds >= severe_threshold_seconds:
		return Stage.SEVERE
	if time_seconds >= critical_threshold_seconds:
		return Stage.CRITICAL
	if time_seconds >= warning_threshold_seconds:
		return Stage.WARNING
	return Stage.UNSTABLE


func stage_name() -> String:
	return STAGE_NAMES[int(current_stage)]


func maximum_stage_name() -> String:
	return STAGE_NAMES[int(maximum_stage_reached)]


func set_review_stage(stage_value: int) -> void:
	_forced_stage = clampi(stage_value, 0, STAGE_NAMES.size() - 1)
	current_stage = _forced_stage
	maximum_stage_reached = maxi(maximum_stage_reached, current_stage)
	_apply_stage(false)


func clear_review_stage() -> void:
	_forced_stage = -1


func synchronize_to_time(time_seconds: float) -> void:
	_forced_stage = -1
	var next_stage := stage_at(time_seconds)
	current_stage = next_stage
	maximum_stage_reached = maxi(maximum_stage_reached, current_stage)
	_transition_twitch_remaining = transition_jolt_duration
	_apply_stage(false)


func _build_visuals() -> void:
	_beacons = [
		_add_sprite("RightBeacon", Vector2(954,52), "beacon-dim.png"),
		_add_sprite("LeftBeacon", Vector2(210,52), "beacon-dim.png"),
	]
	for position_value in [Vector2(66,184),Vector2(1062,184),Vector2(66,310),Vector2(1062,310),Vector2(1062,458)]:
		_lenses.append(_add_sprite("Lens%d" % _lenses.size(),position_value,"lens-dim.png"))
	_top_cover = _add_sprite("TopCover",Vector2(382,54),"top-cover-1-p0.png")
	_loose_hatch = _add_sprite("LooseHatch",Vector2(820,54),"loose-hatch-1-p0.png")
	_right_cover = _add_sprite("RightSideCover",Vector2(1092,378),"side-cover-1-p0.png")
	_left_cover = _add_sprite("LeftSideCover",Vector2(36,178),"side-cover-1-p0.png")


func _add_sprite(node_name: String, position_value: Vector2, file_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.centered = false
	sprite.position = position_value
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = _texture(file_name)
	add_child(sprite)
	return sprite


func _texture(file_name: String) -> Texture2D:
	if not _texture_cache.has(file_name):
		_texture_cache[file_name] = load(ROOT + file_name)
	return _texture_cache[file_name] as Texture2D


func _cover_state_number() -> int:
	match current_stage:
		Stage.UNSTABLE:
			return 1
		Stage.WARNING:
			return 2
		Stage.CRITICAL, Stage.SEVERE:
			return 3
		_:
			return 4


func _apply_stage(initial: bool) -> void:
	var state_number := _cover_state_number()
	_top_cover.texture = _texture("top-cover-%d-p0.png" % state_number)
	_loose_hatch.texture = _texture("loose-hatch-%d-p0.png" % state_number)
	_right_cover.texture = _texture("side-cover-%d-p0.png" % (state_number if state_number >= 3 else 1))
	_left_cover.texture = _texture("side-cover-%d-p0.png" % (4 if current_stage >= Stage.CATASTROPHIC else 1))
	if not initial:
		_transition_twitch_remaining = transition_jolt_duration
	queue_redraw()


func _update_motion() -> void:
	var warning_active := _warning_hold_remaining > 0.0 or conveyor.warning_is_visible()
	var animate := not reduced_motion and not warning_active and not conveyor.gameplay_is_stopped()
	position = _cabinet_visual_offset() if animate else Vector2.ZERO
	for index in _beacons.size():
		var active := index == 0 or current_stage >= Stage.WARNING
		var frame := posmod(floori(_elapsed / 0.15) + index * 2, 4)
		_beacons[index].texture = _texture("beacon-%d.png" % frame if active and animate else "beacon-0.png" if active else "beacon-dim.png")
	for index in _lenses.size():
		var active := (index < 2 and current_stage >= Stage.WARNING) or (index < 4 and current_stage >= Stage.CRITICAL) or current_stage >= Stage.CATASTROPHIC
		var lit_name := "lens-lit-a.png" if posmod(floori(_elapsed / 0.6) + index,2) == 0 else "lens-lit-b.png"
		_lenses[index].texture = _texture(lit_name if active and animate else "lens-lit-a.png" if active else "lens-dim.png")
	if _transition_twitch_remaining > 0.0 and not warning_active:
		var state_number := _cover_state_number()
		var top_twitch := "top-cover-%d-p2.png" % state_number
		var hatch_twitch := "loose-hatch-%d-p2.png" % state_number
		if ResourceLoader.exists(ROOT + top_twitch): _top_cover.texture = _texture(top_twitch)
		if ResourceLoader.exists(ROOT + hatch_twitch): _loose_hatch.texture = _texture(hatch_twitch)
	else:
		var state_number := _cover_state_number()
		_top_cover.texture = _texture("top-cover-%d-p0.png" % state_number)
		_loose_hatch.texture = _texture("loose-hatch-%d-p0.png" % state_number)


func _cabinet_visual_offset() -> Vector2:
	if reduced_motion:
		return Vector2.ZERO
	if _transition_twitch_remaining > 0.0:
		var tick := floori(_elapsed / 0.035)
		var amplitude := maxi(transition_jolt_amplitude_pixels, 0)
		return Vector2(amplitude if tick % 2 == 0 else -amplitude, 0.0)
	if current_stage == Stage.MAX and maximum_vibration_amplitude_pixels > 0:
		var tick := floori(_elapsed * maxf(maximum_vibration_frequency_hz, 0.0))
		return Vector2(maximum_vibration_amplitude_pixels if tick % 2 == 0 else -maximum_vibration_amplitude_pixels, 0.0)
	return Vector2.ZERO


func _draw() -> void:
	var light_alpha: float = PackedFloat32Array([0.03, 0.07, 0.11, 0.16, 0.22, 0.28])[current_stage]
	var edge_width: float = PackedFloat32Array([2.0, 3.0, 4.0, 6.0, 8.0, 10.0])[current_stage]
	var flicker_multiplier := 1.0
	if current_stage >= Stage.SEVERE and posmod(floori(_elapsed / 0.12), 7) == 0:
		flicker_multiplier = 0.55
	var light := Color(RED_LIGHT.r, RED_LIGHT.g, RED_LIGHT.b, light_alpha * flicker_multiplier)
	# Localized cabinet illumination leaves the player/hazard field untinted.
	draw_rect(Rect2(48, 82, 1056, edge_width), light)
	draw_rect(Rect2(48, 82, edge_width, 524), light)
	draw_rect(Rect2(1104 - edge_width, 82, edge_width, 524), light)
	draw_rect(Rect2(48, 606 - edge_width, 1056, edge_width), light)
	if current_stage >= Stage.CRITICAL:
		draw_rect(Rect2(188, 44, 104, 5), Color(RED_LIGHT.r, RED_LIGHT.g, RED_LIGHT.b, light_alpha + 0.08))
		draw_rect(Rect2(862, 44, 104, 5), Color(RED_LIGHT.r, RED_LIGHT.g, RED_LIGHT.b, light_alpha + 0.08))
	if current_stage >= Stage.SEVERE:
		draw_rect(Rect2(840, 102, 190, 4), Color(RED_LIGHT.r, RED_LIGHT.g, RED_LIGHT.b, light_alpha + 0.06))
		draw_rect(Rect2(122, 102, 164, 4), Color(RED_LIGHT.r, RED_LIGHT.g, RED_LIGHT.b, light_alpha + 0.06))
	if current_stage >= Stage.CATASTROPHIC:
		draw_rect(Rect2(64, 458, 6, 100), Color(RED_LIGHT.r, RED_LIGHT.g, RED_LIGHT.b, light_alpha + 0.08))
		draw_rect(Rect2(1082, 458, 6, 100), Color(RED_LIGHT.r, RED_LIGHT.g, RED_LIGHT.b, light_alpha + 0.08))
	if current_stage == Stage.MAX:
		draw_rect(Rect2(808,596,196,4),Color("172b3d"))
		draw_rect(Rect2(826,598,52,2),Color("86969b"))
		draw_rect(Rect2(948,598,28,2),Color("f2ba45"))


func _on_sweeper_warning(_altitude: float, duration: float) -> void:
	_warning_hold_remaining = maxf(_warning_hold_remaining,duration)


func _on_product_warning(_lane: int, duration: float) -> void:
	_warning_hold_remaining = maxf(_warning_hold_remaining,duration)


func _on_d3_warning(_index: int, _lane: int, _x: float, _started_at: float) -> void:
	if background_drop_director != null:
		_warning_hold_remaining = maxf(_warning_hold_remaining,background_drop_director.warning_duration)
