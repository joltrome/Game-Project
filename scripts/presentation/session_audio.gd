class_name SessionAudio
extends Node

signal sfx_requested(event: StringName)
signal sfx_played(event: StringName, voice_index: int)
signal music_state_changed(state: int, target_db: float)

enum MusicState { MENU, GAMEPLAY, CREDITS, PAUSE, RESULTS, OUTCOME_DUCK }

# Original master stays byte-identical; loop settings live on its import resource.
@export var music_stream: AudioStream
@export var sfx_streams: Dictionary[StringName, AudioStream] = {}

@export_category("SFX Mix")
@export var sfx_voice_count: int = 12
@export var sfx_volume_db: Dictionary[StringName, float] = {
	&"coin_pickup": -8.0,
	&"jump": 6.0,
	&"landing": 2.0,
	&"product_impact": -3.0,
	&"carriage_warning": 12.0,
	&"clock_in_confirm": 0.0,
	&"player_death": -6.0,
	&"round_complete": 2.0,
}

@export_category("Reactive Music")
@export var menu_music_db: float = -6.0
@export var gameplay_music_db: float = 0.0
@export var credits_music_db: float = -8.0
@export var pause_music_db: float = -12.0
@export var results_music_db: float = -7.0
@export var outcome_duck_db: float = -15.0
@export var normal_transition_seconds: float = 0.25
@export var pause_transition_seconds: float = 0.18
@export var outcome_duck_seconds: float = 0.10
@export var outcome_duck_hold_seconds: float = 0.35
@export var outcome_settle_seconds: float = 0.25

var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var sfx_voices: Array[AudioStreamPlayer] = []
var music_started: bool = false
var music_start_count: int = 0
var current_music_state: MusicState = MusicState.MENU
var gameplay_sfx_enabled: bool = false
var _voice_cursor: int = 0
var _music_tween: Tween
var _played_counts: Dictionary[StringName, int] = {}

const GAMEPLAY_SFX_EVENTS: Array[StringName] = [
	&"coin_pickup",
	&"jump",
	&"landing",
	&"product_impact",
	&"carriage_warning",
]


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
	for index in maxi(sfx_voice_count, 1):
		var voice := AudioStreamPlayer.new()
		voice.name = "SFXVoice%02d" % index
		voice.bus = &"SFX"
		add_child(voice)
		sfx_voices.append(voice)
	sfx = sfx_voices[0]
	set_music_state(MusicState.MENU, false, 0.0)
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
	for voice in sfx_voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null


func request_sfx(event: StringName) -> void:
	sfx_requested.emit(event)
	if event in GAMEPLAY_SFX_EVENTS and not gameplay_sfx_enabled:
		return
	var stream := sfx_streams.get(event) as AudioStream
	if stream == null or sfx_voices.is_empty():
		return
	var voice_index := _next_voice_index()
	var voice := sfx_voices[voice_index]
	voice.stop()
	voice.stream = stream
	voice.volume_db = float(sfx_volume_db.get(event, 0.0))
	voice.play()
	_played_counts[event] = int(_played_counts.get(event, 0)) + 1
	sfx_played.emit(event, voice_index)


func set_gameplay_sfx_enabled(enabled: bool) -> void:
	gameplay_sfx_enabled = enabled


func stop_all_sfx() -> void:
	for voice in sfx_voices:
		voice.stop()
		voice.stream = null


func played_count(event: StringName) -> int:
	return int(_played_counts.get(event, 0))


func sfx_player_count() -> int:
	return sfx_voices.size()


func set_music_state(
	state: MusicState,
	with_outcome_duck: bool = false,
	duration_override: float = -1.0
) -> void:
	var previous_state := current_music_state
	current_music_state = state
	var target_db := music_target_db(state)
	music_state_changed.emit(state, target_db)
	_kill_music_tween()
	if with_outcome_duck:
		_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_music_tween.tween_property(
			music,
			"volume_db",
			outcome_duck_db,
			outcome_duck_seconds
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_music_tween.tween_interval(outcome_duck_hold_seconds)
		_music_tween.tween_property(
			music,
			"volume_db",
			target_db,
			outcome_settle_seconds
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	var transition_seconds := (
		duration_override
		if duration_override >= 0.0
		else pause_transition_seconds
		if state == MusicState.PAUSE or previous_state == MusicState.PAUSE
		else normal_transition_seconds
	)
	if transition_seconds <= 0.0:
		music.volume_db = target_db
		return
	_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(
		music,
		"volume_db",
		target_db,
		transition_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func duck_music_for_death() -> void:
	current_music_state = MusicState.OUTCOME_DUCK
	music_state_changed.emit(current_music_state, outcome_duck_db)
	_tween_music_to(outcome_duck_db, outcome_duck_seconds)


func music_target_db(state: MusicState = current_music_state) -> float:
	match state:
		MusicState.GAMEPLAY:
			return gameplay_music_db
		MusicState.CREDITS:
			return credits_music_db
		MusicState.PAUSE:
			return pause_music_db
		MusicState.RESULTS:
			return results_music_db
		MusicState.OUTCOME_DUCK:
			return outcome_duck_db
		_:
			return menu_music_db


func _next_voice_index() -> int:
	for offset in sfx_voices.size():
		var candidate := (_voice_cursor + offset) % sfx_voices.size()
		if not sfx_voices[candidate].playing:
			_voice_cursor = (candidate + 1) % sfx_voices.size()
			return candidate
	var fallback := _voice_cursor
	_voice_cursor = (_voice_cursor + 1) % sfx_voices.size()
	return fallback


func _tween_music_to(target_db: float, duration: float) -> void:
	_kill_music_tween()
	if duration <= 0.0:
		music.volume_db = target_db
		return
	_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(
		music,
		"volume_db",
		target_db,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


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
