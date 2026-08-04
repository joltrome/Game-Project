extends Node

const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const ROUTES := [
	CollectibleDirector.OfferTemplate.SAFE_VERSUS_RISK,
	CollectibleDirector.OfferTemplate.MIXED_ROUTE,
	CollectibleDirector.OfferTemplate.HORIZONTAL_LINE,
	CollectibleDirector.OfferTemplate.STAGGERED_ROUTE,
	CollectibleDirector.OfferTemplate.COMPACT_BURST,
]
const ROUTE_COUNTS := [4, 4, 3, 4, 3]

@onready var route_label: Label = $Guide/Panel/RouteLabel
@onready var instruction_label: Label = $Guide/Panel/InstructionLabel

var _conveyor: ConveyorPrototype
var _director: CollectibleDirector
var _route_index := 0


func _ready() -> void:
	call_deferred("_load_route", 0)


func _process(delta: float) -> void:
	if not is_instance_valid(_conveyor) or not is_instance_valid(_director):
		return
	if _director.pending_staggered_coin_count() > 0:
		_conveyor.survival_time += delta
		_director._process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode >= KEY_1 and key.keycode <= KEY_5:
		_load_route(int(key.keycode - KEY_1))
	elif key.keycode == KEY_R:
		_load_route(_route_index)


func _load_route(index: int) -> void:
	_route_index = clampi(index, 0, ROUTES.size() - 1)
	if is_instance_valid(_conveyor):
		_conveyor.queue_free()
		await get_tree().process_frame

	_conveyor = CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	_conveyor.initial_warning_delay = 999.0
	_conveyor.left_failure_enabled = false
	add_child(_conveyor)
	await get_tree().physics_frame

	(_conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	_conveyor.set_process(false)
	_director = _conveyor.get_node("CollectibleDirector") as CollectibleDirector
	_director.set_process(false)
	var template: int = ROUTES[_route_index]
	var intended_count: int = ROUTE_COUNTS[_route_index]
	var candidates := _director.template_candidates_for_test(template, intended_count)
	if candidates.is_empty():
		route_label.text = "ROUTE FIXTURE FAILED"
		return

	_conveyor.player.position = Vector2(
		candidates[0].position.x,
		_conveyor.floor_y - _conveyor.player_collision_size().y * 0.5
	)
	_conveyor.player.velocity = Vector2.ZERO
	var spawned := _director.try_spawn_template_for_test(template, intended_count)
	route_label.text = "%d — %s" % [_route_index + 1, _director.template_name(template).to_upper()]
	instruction_label.text = (
		"1–5: choose route    R: reset route    Arrow keys: move    Space: jump\n"
		+ ("Route ready. Start at the first coin and choose whether to commit." if spawned else "Route rejected by the live safety validator.")
	)
