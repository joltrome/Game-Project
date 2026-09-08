class_name SessionAudio
extends Node

signal sfx_requested(event: StringName)

# Replace this resource in standard_session.tscn when the seamless master arrives.
@export var music_stream: AudioStream
@export var sfx_streams: Dictionary[StringName, AudioStream] = {}

var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var music_started: bool = false
var music_start_count: int = 0


func _ready() -> void:
	for bus_name in [&"Music", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")
	music = AudioStreamPlayer.new()
	music.name = "MusicPlayer"
	music.bus = &"Music"
	music.stream = music_stream
	add_child(music)
	sfx = AudioStreamPlayer.new()
	sfx.name = "SFXPlayer"
	sfx.bus = &"SFX"
	sfx.max_polyphony = 8
	add_child(sfx)
	if not OS.has_feature("web"):
		start_music_once()


func start_music_once() -> void:
	if music_started or music.stream == null:
		return
	music_started = true
	music_start_count += 1
	music.play()
	# No finished callback: the temporary demo plays through once, quiet tail included.


func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	if is_instance_valid(sfx):
		sfx.stop()
		sfx.stream = null


func request_sfx(event: StringName) -> void:
	sfx_requested.emit(event)
	var stream := sfx_streams.get(event) as AudioStream
	if stream != null:
		sfx.stream = stream
		sfx.play()


func set_muted(bus_name: StringName, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0 and bus_name in [&"Music", &"SFX"]:
		AudioServer.set_bus_mute(index, muted)


func is_muted(bus_name: StringName) -> bool:
	var index := AudioServer.get_bus_index(bus_name)
	return index >= 0 and AudioServer.is_bus_mute(index)
