class_name SessionAudio
extends Node

signal sfx_requested(event: StringName)
signal sfx_played(event: StringName, voice_index: int)
signal music_state_changed(state: int, target_db: float)
signal run_music_started(run_index: int)

enum MusicState { SILENT, START_PENDING, GAMEPLAY, PAUSE, FADING_OUT }

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
	&"clock_in_confirm": 0.0,
	&"player_death": -6.0,
	&"round_complete": 2.0,
}

@export_category("Run-Owned Music")
@export var gameplay_music_db: float = 0.0
@export var pause_music_db: float = -12.0
@export var clock_in_to_music_delay_seconds: float = 0.20
@export var pause_transition_seconds: float = 0.18
@export var run_end_fade_seconds: float = 0.10
@export var silent_music_db: float = -80.0

var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var sfx_voices: Array[AudioStreamPlayer] = []
var music_start_count: int = 0
var current_music_state: MusicState = MusicState.SILENT
var gameplay_sfx_enabled: bool = false
var _voice_cursor: int = 0
var _music_tween: Tween
var _music_start_timer: Timer
var _music_ready_at_msec: int = 0
var _run_music_active: bool = false
var _run_music_paused: bool = false
var _played_counts: Dictionary[StringName, int] = {}

const GAMEPLAY_SFX_EVENTS: Array[StringName] = [
	&"coin_pickup",
	&"jump",
	&"landing",
	&"product_impact",
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
	music.volume_db = gameplay_music_db
	add_child(music)
	_music_start_timer = Timer.new()
	_music_start_timer.name = "RunMusicStartDelay"
	_music_start_timer.one_shot = true
	_music_start_timer.ignore_time_scale = true
	_music_start_timer.timeout.connect(_start_pending_run_music)
	add_child(_music_start_timer)
	for index in maxi(sfx_voice_count, 1):
		var voice := AudioStreamPlayer.new()
		voice.name = "SFXVoice%02d" % index
		voice.bus = &"SFX"
		add_child(voice)
		sfx_voices.append(voice)
	sfx = sfx_voices[0]
	_set_music_state(MusicState.SILENT, silent_music_db)


func begin_run_music() -> void:
	_kill_music_tween()
	_music_start_timer.stop()
	music.stop()
	music.volume_db = gameplay_music_db
	_run_music_active = music.stream != null
	_run_music_paused = false
	if not _run_music_active:
		_set_music_state(MusicState.SILENT, silent_music_db)
		return
	_set_music_state(MusicState.START_PENDING, gameplay_music_db)
	if clock_in_to_music_delay_seconds <= 0.0:
		_music_ready_at_msec = 0
		_start_pending_run_music()
	else:
		_music_ready_at_msec = Time.get_ticks_msec() + roundi(clock_in_to_music_delay_seconds * 1000.0)
		_music_start_timer.start(clock_in_to_music_delay_seconds)


func pause_run_music() -> void:
	if not _run_music_active:
		return
	_run_music_paused = true
	_set_music_state(MusicState.PAUSE, pause_music_db)
	if music.playing:
		_tween_music_to(pause_music_db, pause_transition_seconds)


func resume_run_music() -> void:
	if not _run_music_active:
		return
	_run_music_paused = false
	if not _music_start_timer.is_stopped():
		_set_music_state(MusicState.START_PENDING, gameplay_music_db)
		return
	_set_music_state(MusicState.GAMEPLAY, gameplay_music_db)
	if music.playing:
		_tween_music_to(gameplay_music_db, pause_transition_seconds)


func end_run_music() -> void:
	_run_music_active = false
	_run_music_paused = false
	_music_ready_at_msec = 0
	_music_start_timer.stop()
	_kill_music_tween()
	if not music.playing:
		_finish_run_music_stop()
		return
	_set_music_state(MusicState.FADING_OUT, silent_music_db)
	if run_end_fade_seconds <= 0.0:
		_finish_run_music_stop()
		return
	_music_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(
		music,
		"volume_db",
		silent_music_db,
		run_end_fade_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tween.tween_callback(_finish_run_music_stop)


func stop_run_music_immediately() -> void:
	_run_music_active = false
	_run_music_paused = false
	_music_ready_at_msec = 0
	_music_start_timer.stop()
	_kill_music_tween()
	_finish_run_music_stop()


func run_music_active() -> bool:
	return _run_music_active


func run_music_start_pending() -> bool:
	return _run_music_active and not _music_start_timer.is_stopped()


func _start_pending_run_music() -> void:
	if not _run_music_active or music.stream == null:
		return
	var remaining_msec := _music_ready_at_msec - Time.get_ticks_msec()
	if remaining_msec > 0:
		_music_start_timer.start(remaining_msec / 1000.0)
		return
	_music_ready_at_msec = 0
	music.stop()
	music.volume_db = pause_music_db if _run_music_paused else gameplay_music_db
	music.play(0.0)
	music_start_count += 1
	_set_music_state(
		MusicState.PAUSE if _run_music_paused else MusicState.GAMEPLAY,
		music.volume_db
	)
	run_music_started.emit(music_start_count)


func _finish_run_music_stop() -> void:
	if is_instance_valid(music):
		music.stop()
		music.volume_db = gameplay_music_db
	_set_music_state(MusicState.SILENT, silent_music_db)
	_music_tween = null


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


func _set_music_state(state: MusicState, target_db: float) -> void:
	current_music_state = state
	music_state_changed.emit(state, target_db)


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
