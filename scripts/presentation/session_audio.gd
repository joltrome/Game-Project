class_name SessionAudio
extends Node

signal sfx_requested(event: StringName)

# Original master stays byte-identical; loop settings live on its import resource.
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
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	music.stream = prepare_music_stream(music_stream)
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
	# The resource loops inside the continuous mixer; never restart on finished.


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


static func prepare_music_stream(source: AudioStream) -> AudioStream:
	if not source is AudioStreamWAV:
		return source
	var wav := source as AudioStreamWAV
	# Godot 4.7.1 reads the exclusive WAV endpoint, then resumes at frame 1.
	# Supply sample 0 as a decoder guard so audible output is exactly the full
	# original repeated. This does not add a played frame or change the loop period.
	# Scoped to the verified PCM16, full-file, forward-loop case; recheck on upgrade.
	if wav.format != AudioStreamWAV.FORMAT_16_BITS or wav.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		return source
	var bytes_per_frame := 4 if wav.stereo else 2
	if wav.loop_begin != 0 or wav.loop_end * bytes_per_frame != wav.data.size():
		return source
	var prepared := wav.duplicate() as AudioStreamWAV
	prepared.data = wav.data + wav.data.slice(0, bytes_per_frame)
	return prepared
