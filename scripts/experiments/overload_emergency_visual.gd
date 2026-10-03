class_name OverloadEmergencyVisual
extends Node2D

enum Stage { UNSTABLE, WARNING, CRITICAL, MAX }

const ROOT := "res://assets/visuals/vm081_overload/emergency/"
const STAGE_NAMES := ["UNSTABLE", "WARNING", "CRITICAL", "MAX"]

@export var warning_threshold_seconds: float = 15.0
@export var critical_threshold_seconds: float = 30.0
@export var maximum_threshold_seconds: float = 90.0
@export var reduced_motion: bool = false
@export var debug_stage_keys_enabled: bool = false

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
		_transition_twitch_remaining = 0.06
		_apply_stage(false)
	_update_motion()


func _unhandled_input(event: InputEvent) -> void:
	if not debug_stage_keys_enabled or not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_forced_stage = posmod((_forced_stage if _forced_stage >= 0 else int(current_stage)) + 1, 4)


func stage_at(time_seconds: float) -> int:
	if time_seconds >= maximum_threshold_seconds:
		return Stage.MAX
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
	_forced_stage = clampi(stage_value, 0, 3)
	current_stage = _forced_stage
	maximum_stage_reached = maxi(maximum_stage_reached, current_stage)
	_apply_stage(false)


func clear_review_stage() -> void:
	_forced_stage = -1


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
	sprite.texture = load(ROOT + file_name)
	add_child(sprite)
	return sprite


func _apply_stage(initial: bool) -> void:
	var state_number := int(current_stage) + 1
	_top_cover.texture = load(ROOT + "top-cover-%d-p0.png" % state_number)
	_loose_hatch.texture = load(ROOT + "loose-hatch-%d-p0.png" % state_number)
	_right_cover.texture = load(ROOT + "side-cover-%d-p0.png" % (state_number if state_number >= 3 else 1))
	_left_cover.texture = load(ROOT + "side-cover-%d-p0.png" % (4 if current_stage == Stage.MAX else 1))
	if not initial:
		_transition_twitch_remaining = 0.06
	queue_redraw()


func _update_motion() -> void:
	var warning_active := _warning_hold_remaining > 0.0 or conveyor.warning_is_visible()
	var animate := not reduced_motion and not warning_active and not conveyor.gameplay_is_stopped()
	for index in _beacons.size():
		var active := index == 0 or current_stage >= Stage.WARNING
		var frame := posmod(floori(_elapsed / 0.15) + index * 2, 4)
		_beacons[index].texture = load(ROOT + ("beacon-%d.png" % frame if active and animate else "beacon-0.png" if active else "beacon-dim.png"))
	for index in _lenses.size():
		var active := (index < 2 and current_stage >= Stage.WARNING) or (index < 4 and current_stage >= Stage.CRITICAL) or current_stage == Stage.MAX
		var lit_name := "lens-lit-a.png" if posmod(floori(_elapsed / 0.6) + index,2) == 0 else "lens-lit-b.png"
		_lenses[index].texture = load(ROOT + (lit_name if active and animate else "lens-lit-a.png" if active else "lens-dim.png"))
	if _transition_twitch_remaining > 0.0 and not warning_active:
		var state_number := int(current_stage) + 1
		var top_twitch := ROOT + "top-cover-%d-p2.png" % state_number
		var hatch_twitch := ROOT + "loose-hatch-%d-p2.png" % state_number
		if ResourceLoader.exists(top_twitch): _top_cover.texture = load(top_twitch)
		if ResourceLoader.exists(hatch_twitch): _loose_hatch.texture = load(hatch_twitch)
	else:
		var state_number := int(current_stage) + 1
		_top_cover.texture = load(ROOT + "top-cover-%d-p0.png" % state_number)
		_loose_hatch.texture = load(ROOT + "loose-hatch-%d-p0.png" % state_number)


func _draw() -> void:
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
