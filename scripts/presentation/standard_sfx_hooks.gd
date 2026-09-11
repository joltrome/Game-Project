class_name StandardSFXHooks
extends Node

var audio: SessionAudio
var conveyor: ConveyorPrototype
var round_controller: FixedRoundController
var _last_urgent_second: int = -1


func bind(shell: MotionExperimentShell, session_audio: SessionAudio) -> void:
	audio = session_audio
	conveyor = shell.conveyor
	round_controller = conveyor.get_node("RoundController")
	(conveyor.get_node("CollectibleDirector") as CollectibleDirector).score_changed.connect(
		func(_score: int) -> void: audio.request_sfx(&"coin_pickup"))
	conveyor.conveyor_product_landed.connect(
		func(_product: ConveyorProduct) -> void: audio.request_sfx(&"product_impact"))
	conveyor.telegraph_started.connect(
		func(_lane: int, _duration: float) -> void: audio.request_sfx(&"rack_warning"))
	conveyor.product_dropped.connect(
		func(_lane: int, _speed: float) -> void: audio.request_sfx(&"rack_release"))
	conveyor.sweeper_spawned.connect(
		func(_sweeper: AirSweeper) -> void: audio.request_sfx(&"carriage_sweep"))
	shell.background_drop_director.warning_started.connect(
		func(_index: int, _lane: int, _x: float, _time: float) -> void:
			audio.request_sfx(&"rack_warning"))
	shell.background_drop_director.product_released.connect(
		func(_index: int, _lane: int, _product: ConveyorProduct, _time: float) -> void:
			audio.request_sfx(&"rack_release"))
	conveyor.player.jump_accepted.connect(func() -> void: audio.request_sfx(&"jump"))
	conveyor.player.landed.connect(func() -> void: audio.request_sfx(&"landing"))


func _physics_process(_delta: float) -> void:
	if conveyor == null or conveyor.gameplay_is_stopped():
		return
	var seconds := ceili(round_controller.round_time_remaining)
	if seconds >= 1 and seconds <= 5 and seconds != _last_urgent_second:
		_last_urgent_second = seconds
		audio.request_sfx(&"final_seconds")
