class_name StandardSession
extends Control

enum State { MENU, MODE_SELECT, GAME, RESULTS, CREDITS, DEATH_BEAT, PAUSED }
enum RunMode { STANDARD, OVERLOAD }

const DEATH_BEAT_SECONDS := 0.75

const STANDARD_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const DESIGN_SIZE := Vector2(1152, 648)
const CREAM := Color("f2e7c9")
const INK := Color("172b3d")
const RED := Color("b93743")
const TEAL := Color("2ca6a4")
const GOLD := Color("f2ba45")
const VOLUME_SLIDER := preload("res://scripts/presentation/c2_volume_slider.gd")
const FRAME_PACING := preload("res://scripts/presentation/frame_pacing_telemetry.gd")
const OVERLOAD_RECORD_STORE := preload("res://scripts/presentation/overload_record_store.gd")
const OVERLOAD_SCORE := preload("res://scripts/presentation/overload_score.gd")

@export var score_storage_path: String = "user://standard_best.cfg"
@export var audio_settings_path: String = "user://standard_audio.cfg"
@export var ballistic_coins_enabled: bool = false
@export var ballistic_abundance_enabled: bool = false
@export var ballistic_integrity_enabled: bool = false
@export var refund_chute_enabled: bool = false
@export var refund_system_enabled: bool = false
@export var mobile_playability_enabled: bool = false
@export var mobile_arcade_deck_enabled: bool = false
@export var coin_pressure_enabled: bool = false
@export var responsive_mobile_cabinet_enabled: bool = false
@export var overload_mode_available: bool = false
@export var overload_storage_path: String = "user://overload_best.cfg"
@export var overload_survival_points_per_second: int = 100
@export var overload_refund_points: int = 250

var state: State = State.MENU
var game: MotionExperimentShell
var scores := StandardScoreStore.new()
var overload_records := OVERLOAD_RECORD_STORE.new()
var current_mode: RunMode = RunMode.STANDARD
var last_score: int = 0
var last_survived: bool = false
var last_survival_seconds: float = 0.0
var last_overload_telemetry: Dictionary = {}
var _overload_max_active_coins: int = 0
var last_overload_score: int = 0
var last_overload_new_best: bool = false
var _ui: Control
var _music_slider: C2VolumeSlider
var _sfx_slider: C2VolumeSlider
var result_headline: String = ""
var last_death_cause: ConveyorPrototype.DeathCause = ConveyorPrototype.DeathCause.UNKNOWN
var result_transition_count: int = 0
var _run_serial: int = 0
var _death_ready_at_msec: int = 0
var _death_timer: Timer
var auto_focus_pause_enabled: bool = true
var hud: CohesionHUD
var pause_count: int = 0
var death_reaction: StandardDeathReaction
var _c2: C2Screen
var touch: StandardTouchControls
var result_score: C2PixelText
var best_label: C2PixelText
var result_survival: C2PixelText
var best_survival: C2PixelText
var _frame_pacing = FRAME_PACING.new()

@onready var audio: SessionAudio = $Audio


func _enter_tree() -> void:
	($Audio as SessionAudio).settings_storage_path = audio_settings_path


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	get_window().title = "GET CANNED!"
	scores.storage_path = score_storage_path
	scores.load_best()
	overload_records.storage_path = overload_storage_path
	overload_records.load_bests()
	_ui = Control.new()
	_ui.name = "Presentation"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.size = DESIGN_SIZE
	add_child(_ui)
	_death_timer = Timer.new()
	_death_timer.one_shot = true
	_death_timer.ignore_time_scale = true
	_death_timer.wait_time = DEATH_BEAT_SECONDS
	_death_timer.timeout.connect(_finish_death_beat)
	add_child(_death_timer)
	touch = StandardTouchControls.new()
	add_child(touch)
	touch.pause_requested.connect(_toggle_pause_with_confirm)
	resized.connect(_layout)
	get_window().size_changed.connect(_layout)
	show_menu()
	_layout()


func _process(delta: float) -> void:
	if state == State.GAME and is_instance_valid(game) and not get_tree().paused:
		_frame_pacing.record_frame(delta, game)
		if current_mode == RunMode.OVERLOAD:
			var director := game.conveyor.get_node("CollectibleDirector") as CollectibleDirector
			_overload_max_active_coins = maxi(
				_overload_max_active_coins,
				director.active_collectible_count()
			)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if state == State.GAME:
			_toggle_pause_with_confirm()
		elif state == State.PAUSED:
			_toggle_pause_with_confirm()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and state in [State.MODE_SELECT,State.RESULTS,State.CREDITS]:
		_activate_ui(show_menu)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and state in [State.GAME, State.RESULTS, State.PAUSED]:
		start_game()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and auto_focus_pause_enabled and state == State.GAME:
		call_deferred("pause_game")


func pause_game() -> void:
	if state != State.GAME or not is_instance_valid(game) or game.conveyor.gameplay_is_stopped():
		return
	state=State.PAUSED
	audio.pause_run_music()
	pause_count+=1
	touch.set_game_active(false)
	_release_gameplay_actions()
	get_tree().paused=true
	_c2=CohesionScreen.new()
	(_c2 as CohesionScreen).kind="pause"
	_ui.add_child(_c2)
	var panel := _c2 as CohesionScreen
	var resume := panel.add_action("resume",_confirmed(resume_game))
	panel.add_action("pause-retry",start_game)
	panel.add_action("pause-menu",_confirmed(show_menu))
	_add_volume_sliders(panel, Vector2(694.0, 494.0))
	panel.wire_focus()
	resume.grab_focus()
	_layout()


func resume_game() -> void:
	if state != State.PAUSED:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()
	_ui.remove_child(_c2)
	_c2.queue_free()
	_c2=null
	_music_slider=null
	_sfx_slider=null
	_release_gameplay_actions()
	state=State.GAME
	audio.resume_run_music()
	get_tree().paused=false
	touch.set_game_active(true)
	_layout()


func _release_gameplay_actions() -> void:
	for action in [&"move_left",&"move_right",&"jump"]:
		Input.action_release(action)


func start_game() -> void:
	if state == State.GAME and is_instance_valid(game):
		_frame_pacing.finish_run("restart")
	audio.stop_all_sfx()
	audio.request_sfx(&"clock_in_confirm")
	_dispose_game()
	state = State.GAME
	audio.set_gameplay_sfx_enabled(true)
	audio.begin_run_music()
	_run_serial += 1
	last_death_cause = ConveyorPrototype.DeathCause.UNKNOWN
	last_survival_seconds = 0.0
	last_overload_telemetry.clear()
	_overload_max_active_coins = 0
	game = STANDARD_SCENE.instantiate() as MotionExperimentShell
	game.name = "StandardRun"
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.clean_tester_presentation = true
	game.clean_control_hint_duration = 0.0
	game.local_instrumentation_enabled = false
	game.overload_mode_enabled = current_mode == RunMode.OVERLOAD
	game.vm081_presentation_enabled = overload_mode_available
	if overload_mode_available:
		game.build_id_override = "VM-0.8.1-OVERLOAD-REWORK"
	elif responsive_mobile_cabinet_enabled:
		game.build_id_override = "VM-0.7.4-RESPONSIVE-MOBILE-CABINET"
	elif coin_pressure_enabled:
		game.build_id_override = "VM-0.7.3-COIN-PRESSURE"
	elif mobile_arcade_deck_enabled:
		game.build_id_override = "VM-0.7.2.1-MOBILE-MONITOR-HOTFIX"
	elif mobile_playability_enabled:
		game.build_id_override = "VM-0.7.1-MOBILE-PLAYABILITY"
	elif refund_system_enabled:
		game.build_id_override = "VM-0.7.0-REFUND-SYSTEM"
	elif refund_chute_enabled:
		game.build_id_override = "VM-0.6.10-REFUND-CHUTE"
	elif ballistic_integrity_enabled:
		game.build_id_override = "VM-0.6.9-BALLISTIC-INTEGRITY"
	elif ballistic_abundance_enabled:
		game.build_id_override = "VM-0.6.8-BALLISTIC-ABUNDANCE"
	elif ballistic_coins_enabled:
		game.build_id_override = "VM-0.6.7-BALLISTIC-COINS"
	# Both flags are required. A normal release can never enable the overlay.
	game.debug_overlay_toggle_allowed = OS.is_debug_build() and OS.has_feature("standard_debug")
	game.v2_debug_overlay_enabled = false
	game.refund_chute_enabled = refund_chute_enabled
	add_child(game)
	move_child(game, 0)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.conveyor.set_process_unhandled_input(false)
	game.v2_visual_integration.external_death_presentation_enabled=true
	game.v2_visual_integration.live_death_pose.connect(_capture_death_pose)
	game.v2_visual_integration.enable_c2_live_typography()
	# Settled art has a two-source-pixel transparent top (4 logical pixels).
	# Shift only the support position; retain its frozen 72x48 shape.
	game.v2_visual_integration.landed_contact_offset_y=4.0
	var collectible_director := game.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	collectible_director.ballistic_coin_events_enabled = ballistic_coins_enabled
	collectible_director.ballistic_abundance_enabled = ballistic_abundance_enabled
	collectible_director.ballistic_integrity_enabled = ballistic_integrity_enabled
	collectible_director.refund_chute_enabled = refund_chute_enabled
	collectible_director.refund_system_enabled = refund_system_enabled
	# Overload is the mastery path and starts after Standard's teaching phase.
	# Enter the accepted VM-0.7.3 event stream directly so an impossible static
	# teaching placement cannot starve all later Refund Coin events under the
	# intentionally higher opening pressure. Standard remains unchanged.
	collectible_director.static_teaching_coin_enabled = (
		refund_system_enabled and current_mode == RunMode.STANDARD
	)
	collectible_director.coin_pressure_enabled = coin_pressure_enabled
	collectible_director.performance_profiling_enabled = mobile_playability_enabled
	collectible_director.bounded_optional_planning_enabled = mobile_playability_enabled
	var round_controller := game.conveyor.get_node("RoundController") as FixedRoundController
	# Death can originate inside a physics collision callback. Finish that callback
	# before disabling the complete run and its collision objects.
	round_controller.round_ended_by_death.connect(_on_death.bind(_run_serial), CONNECT_DEFERRED)
	round_controller.round_completed.connect(_on_completion.bind(_run_serial), CONNECT_DEFERRED)
	var hooks := StandardSFXHooks.new()
	hooks.name = "SFXHooks"
	game.add_child(hooks)
	hooks.bind(game, audio)
	_apply_hud_style()
	_clear_ui()
	hud=CohesionHUD.new()
	hud.round_controller=round_controller
	hud.coins=game.conveyor.get_node("CollectibleDirector")
	hud.overload_mode_enabled = current_mode == RunMode.OVERLOAD
	hud.overload_survival_points_per_second = overload_survival_points_per_second
	hud.overload_refund_points = overload_refund_points
	_ui.add_child(hud)
	touch.overload_hud=hud
	touch.set_game_active(true)
	_frame_pacing.begin_run(mobile_playability_enabled)
	_layout()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func start_standard_game() -> void:
	current_mode = RunMode.STANDARD
	start_game()


func start_overload_game() -> void:
	if not overload_mode_available:
		return
	current_mode = RunMode.OVERLOAD
	start_game()


func show_menu() -> void:
	_dispose_game()
	state = State.MENU
	audio.set_gameplay_sfx_enabled(false)
	audio.stop_run_music_immediately()
	_clear_ui()
	_c2 = C2Screen.new()
	_ui.add_child(_c2)
	var play_callback := show_mode_select if overload_mode_available else start_standard_game
	var play := _c2.add_button("clock-in", "CLOCK IN", Rect2(416,472,320,70), play_callback, true)
	_c2.add_button("credits", "CREDITS", Rect2(660,557,112,44), _confirmed(show_credits))
	_add_volume_sliders(_c2, Vector2(790.0, 538.0))
	_c2.wire_focus()
	play.grab_focus()
	_layout()


func show_mode_select() -> void:
	if not overload_mode_available:
		start_standard_game()
		return
	state = State.MODE_SELECT
	audio.set_gameplay_sfx_enabled(false)
	audio.stop_run_music_immediately()
	_clear_ui()
	_c2 = C2Screen.new()
	_c2.show_menu_static_lettering = false
	_ui.add_child(_c2)
	_add_pixel_label(_c2, "SELECT MODE", Vector2(80, 68), "small", 2, CREAM)
	_add_centered_label(_c2, "60 SECOND SHIFT", 396.0, 562.0, "small", 2, INK)
	_add_centered_label(_c2, "ENDLESS / ESCALATING", 804.0, 562.0, "small", 2, INK)
	_add_pixel_label(_c2, "ESC: BACK", Vector2(80, 580), "small", 2, INK)
	var standard := _c2.add_overload_button(
		"standard", "standard", Rect2(236,472,320,70), Vector2(224,460), start_standard_game
	)
	var overload := _c2.add_overload_button(
		"overload", "overload", Rect2(644,472,320,70), Vector2(632,460), start_overload_game
	)
	_c2.add_overload_button(
		"back", "back", Rect2(64,478,144,64), Vector2(64,478), _confirmed(show_menu)
	)
	standard.focus_entered.connect(_update_mode_record.bind(RunMode.STANDARD))
	standard.mouse_entered.connect(_update_mode_record.bind(RunMode.STANDARD))
	overload.focus_entered.connect(_update_mode_record.bind(RunMode.OVERLOAD))
	overload.mouse_entered.connect(_update_mode_record.bind(RunMode.OVERLOAD))
	_c2.wire_focus()
	_update_mode_record(RunMode.STANDARD)
	standard.grab_focus()
	_layout()


func _update_mode_record(mode: RunMode) -> void:
	if state != State.MODE_SELECT or not is_instance_valid(_c2):
		return
	for child_name in ["ModeRecordLabel", "ModeRecordValue"]:
		var old := _c2.get_node_or_null(child_name)
		if old != null:
			old.queue_free()
	var label_text := "STANDARD BEST" if mode == RunMode.STANDARD else "OVERLOAD BEST"
	var value := str(scores.best_score)
	if mode == RunMode.OVERLOAD:
		value = OVERLOAD_SCORE.format_score(overload_records.best_score) if overload_records.has_best_score else "--"
	var label := _add_right_label(_c2, label_text, 1048.0, 350.0, "small", 2, CREAM)
	label.name = "ModeRecordLabel"
	var record := _add_right_label(_c2, value, 1048.0, 378.0, "display", 3, CREAM)
	record.name = "ModeRecordValue"


func show_credits() -> void:
	state = State.CREDITS
	audio.set_gameplay_sfx_enabled(false)
	audio.stop_run_music_immediately()
	_clear_ui()
	var panel := CohesionScreen.new()
	panel.kind="credits"
	_c2=panel
	_ui.add_child(panel)
	var back := panel.add_action("back",_confirmed(show_menu))
	_add_volume_sliders(panel, Vector2(790.0, 538.0))
	panel.wire_focus()
	back.grab_focus()


func _capture_death_pose(snapshot: Dictionary) -> void:
	if state != State.GAME or is_instance_valid(death_reaction):
		return
	death_reaction=StandardDeathReaction.new()
	game.conveyor.add_child(death_reaction)
	death_reaction.setup(snapshot,game.conveyor.death_cause)


func _on_death(score: int, _remaining: float, serial: int) -> void:
	if serial != _run_serial or state != State.GAME:
		return
	state = State.DEATH_BEAT
	var frame_summary := _frame_pacing.finish_run("death")
	last_score = score
	last_survived = false
	last_death_cause = game.conveyor.death_cause
	last_survival_seconds = game.conveyor.survival_time
	if current_mode == RunMode.OVERLOAD:
		_capture_overload_telemetry(frame_summary)
	touch.set_game_active(false)
	_layout()
	game.conveyor.get_node("HUD/DeathMessage").hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	audio.set_gameplay_sfx_enabled(false)
	audio.end_run_music()
	if death_uses_impact_sound(last_death_cause):
		audio.request_sfx(&"player_death")
	_death_ready_at_msec = (death_reaction.started_at_msec if is_instance_valid(death_reaction) else Time.get_ticks_msec()) + roundi(DEATH_BEAT_SECONDS * 1000)
	_death_timer.start(DEATH_BEAT_SECONDS)


func _finish_death_beat() -> void:
	if state == State.DEATH_BEAT and is_instance_valid(game):
		# A Timer can consume the current frame delta immediately after start.
		# Keep the visible hold at least 0.75 real seconds, including a slow frame.
		var remaining := _death_ready_at_msec - Time.get_ticks_msec()
		if remaining > 0:
			_death_timer.start(remaining / 1000.0)
			return
		_show_results(last_score, false)


func _on_completion(score: int, serial: int) -> void:
	if serial == _run_serial and state == State.GAME:
		_frame_pacing.finish_run("completion")
		_show_results(score, true)


static func headline_for(cause: ConveyorPrototype.DeathCause, survived: bool) -> String:
	if survived:
		return "CLOCKED OUT."
	match cause:
		ConveyorPrototype.DeathCause.FALLING_PRODUCT, ConveyorPrototype.DeathCause.BACKGROUND_PRODUCT:
			return "CANNED."
		ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE:
			return "FRIED."
		ConveyorPrototype.DeathCause.LEFT_OUT:
			return "VENDED."
		_:
			return "GAME OVER."


func _show_results(score: int, survived: bool) -> void:
	if state not in [State.GAME, State.DEATH_BEAT]:
		return
	state = State.RESULTS
	result_transition_count += 1
	last_score = score
	last_survived = survived
	if current_mode == RunMode.OVERLOAD:
		last_overload_score = OVERLOAD_SCORE.calculate(
			last_survival_seconds,
			score,
			overload_survival_points_per_second,
			overload_refund_points
		)
		last_overload_new_best = overload_records.record_run(
			last_survival_seconds,
			score,
			last_overload_score
		)
	else:
		scores.record_score(score)
	touch.set_game_active(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.hide()
	audio.set_gameplay_sfx_enabled(false)
	if survived:
		audio.end_run_music()
		audio.request_sfx(&"round_complete")
	_clear_ui()
	result_headline = headline_for(last_death_cause, survived)
	_c2 = C2Screen.new()
	_c2.is_result = true
	_c2.show_result_static_lettering = current_mode != RunMode.OVERLOAD
	_c2.headline = result_headline.trim_suffix(".").to_lower().replace(" ", "-")
	_ui.add_child(_c2)
	var displayed_score := last_overload_score if current_mode == RunMode.OVERLOAD else score
	result_score = _score_text(displayed_score, current_mode == RunMode.OVERLOAD)
	best_label = _score_text(
		overload_records.best_score if current_mode == RunMode.OVERLOAD else scores.best_score,
		current_mode == RunMode.OVERLOAD
	)
	var scale_value := 5
	while maxf(result_score.ink_width(result_score.text,scale_value), best_label.ink_width(best_label.text,scale_value)) > 232 and scale_value > 1:
		scale_value -= 1
	if current_mode == RunMode.OVERLOAD:
		_add_overload_result_details()
	else:
		for item: Array in [[result_score,450],[best_label,714]]:
			var label := item[0] as C2PixelText
			label.glyph_scale = scale_value
			label.position = Vector2(item[1]-floorf(label.ink_width(label.text,scale_value)/2),291)
	var retry := _c2.add_button("retry", "RETRY", Rect2(336,472,280,70), start_game, true)
	_c2.add_button("menu", "MENU", Rect2(644,478,144,64), _confirmed(show_menu))
	_add_volume_sliders(_c2, Vector2(790.0, 538.0))
	_c2.wire_focus()
	retry.grab_focus()
	_layout()


static func death_uses_impact_sound(cause: ConveyorPrototype.DeathCause) -> bool:
	return cause in [
		ConveyorPrototype.DeathCause.FALLING_PRODUCT,
		ConveyorPrototype.DeathCause.BACKGROUND_PRODUCT,
		ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE,
	]


func _score_text(value: int, grouped: bool = false) -> C2PixelText:
	var label := C2PixelText.new()
	label.text = OVERLOAD_SCORE.format_score(value) if grouped else "%02d" % value
	_c2.add_child(label)
	return label


func _add_overload_result_details() -> void:
	_add_pixel_label(_c2, "OVERLOAD", Vector2(80,68), "small", 2, GOLD)
	_add_pixel_label(_c2, "R: RETRY", Vector2(76,577), "small", 2, INK)
	_add_pixel_label(_c2, "ESC: MENU", Vector2(240,577), "small", 2, INK)
	_add_centered_label(_c2, "SCORE", 576.0, 244.0, "small", 2, CREAM)
	var score_scale := 5
	while result_score.ink_width(result_score.text, score_scale) > 512.0 and score_scale > 1:
		score_scale -= 1
	result_score.glyph_scale = score_scale
	result_score.position = Vector2(576.0 - result_score.ink_width(result_score.text,score_scale) * 0.5,272)
	result_survival = _add_centered_label(
		_c2,
		"SURVIVAL %s   REFUNDS %d" % [OVERLOAD_RECORD_STORE.format_survival_time(last_survival_seconds), last_score],
		576.0,
		330.0,
		"small",
		2,
		CREAM
	)
	var record_color := GOLD if last_overload_new_best else CREAM
	_add_right_label(_c2, "NEW BEST" if last_overload_new_best else "BEST SCORE", 1048.0,350.0,"small",2,record_color)
	var best_scale := 3
	while best_label.ink_width(best_label.text,best_scale) > 232.0 and best_scale > 1:
		best_scale -= 1
	best_label.glyph_scale = best_scale
	best_label.color = record_color
	best_label.position = Vector2(1048.0-best_label.ink_width(best_label.text,best_scale),378)


func _capture_overload_telemetry(frame_summary: Dictionary) -> void:
	var conveyor := game.conveyor
	var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var intensity := conveyor.overload_intensity_snapshot(last_survival_seconds)
	last_overload_telemetry = {
		"combined_score": OVERLOAD_SCORE.calculate(last_survival_seconds, last_score, overload_survival_points_per_second, overload_refund_points),
		"score_formula_id": OVERLOAD_SCORE.FORMULA_ID,
		"survival_seconds": last_survival_seconds,
		"refunds": last_score,
		"death_cause": ConveyorPrototype.DeathCause.keys()[last_death_cause],
		"maximum_intensity_reached": intensity.intensity_progress,
		"final_conveyor_multiplier": intensity.conveyor_multiplier,
		"final_sweeper_multiplier": intensity.sweeper_multiplier,
		"final_hazard_multiplier": intensity.hazard_multiplier,
		"final_pattern_cooldown": intensity.pattern_cooldown,
		"compound_pattern_weights": intensity.pattern_weights,
		"consecutive_compound_patterns": conveyor.consecutive_compound_patterns(),
		"max_active_coins": _overload_max_active_coins,
		"coin_planning": director.performance_profile_summary(),
		"frame_pacing": frame_summary.duplicate(true),
		"visual_stage": game.overload_visual_stage_name() if game.has_method("overload_visual_stage_name") else "UNAVAILABLE",
		"maximum_visual_stage": game.maximum_overload_visual_stage_name() if game.has_method("maximum_overload_visual_stage_name") else "UNAVAILABLE",
	}
	print("VM081_OVERLOAD_RUN ", JSON.stringify(last_overload_telemetry))


func _add_pixel_label(parent: Node, value: String, position_value: Vector2, family_value: String, scale_value: int, color_value: Color) -> C2PixelText:
	var label := C2PixelText.new()
	label.text = value
	label.family = family_value
	label.glyph_scale = scale_value
	label.color = color_value
	label.position = position_value
	parent.add_child(label)
	return label


func _add_centered_label(parent: Node, value: String, center_x: float, y: float, family_value: String, scale_value: int, color_value: Color) -> C2PixelText:
	var label := _add_pixel_label(parent,value,Vector2.ZERO,family_value,scale_value,color_value)
	label.position = Vector2(center_x-label.ink_width(value,scale_value)*0.5,y)
	return label


func _add_right_label(parent: Node, value: String, right_x: float, y: float, family_value: String, scale_value: int, color_value: Color) -> C2PixelText:
	var label := _add_pixel_label(parent,value,Vector2.ZERO,family_value,scale_value,color_value)
	label.position = Vector2(right_x-label.ink_width(value,scale_value),y)
	return label


func _dispose_game() -> void:
	get_tree().paused=false
	if _death_timer != null:
		_death_timer.stop()
	if touch != null:
		touch.set_game_active(false)
	if is_instance_valid(game):
		game.process_mode = Node.PROCESS_MODE_DISABLED
		remove_child(game)
		game.queue_free()
	game = null
	death_reaction=null


func _apply_hud_style() -> void:
	var hud := game.conveyor.get_node("HUD")
	for node_name in ["BuildId", "ExperimentId", "Hypothesis", "Controls", "CollectibleLegend"]:
		var item := hud.get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.hide()
	var timer := hud.get_node("Timer") as Label
	timer.hide()
	# Retain the existing central timer, score hierarchy and urgency timings.
	var score := hud.get_node("ScoreGroup/CollectibleScore") as Label
	score.get_parent().hide()


func _layout() -> void:
	var fitted := MotionExperimentShell.contained_rect(size, DESIGN_SIZE)
	if touch != null:
		touch.responsive_side_wings_enabled = responsive_mobile_cabinet_enabled
		var layout_reference := _mobile_layout_reference_size()
		touch.configure_viewport(size, fitted, layout_reference, _mobile_device_pixel_ratio())

	var use_mobile_monitor := (
		mobile_arcade_deck_enabled
		and touch != null
		and touch.arcade_layout_supported()
		and state in [State.GAME, State.PAUSED, State.DEATH_BEAT]
	)
	var ui_rect := (
		touch.gameplay_bounds
		if use_mobile_monitor and state in [State.GAME, State.DEATH_BEAT]
		else fitted
	)
	_ui.position = ui_rect.position
	_ui.scale = ui_rect.size / DESIGN_SIZE

	if is_instance_valid(game):
		if use_mobile_monitor:
			game.set_anchors_preset(Control.PRESET_TOP_LEFT)
			game.position = touch.gameplay_bounds.position
			game.size = touch.gameplay_bounds.size
			game.reflow_display()
		else:
			game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			game.reflow_display()
	if is_instance_valid(hud):
		hud.visible = not (
			current_mode == RunMode.OVERLOAD
			and use_mobile_monitor
			and touch.arcade_layout_supported()
		)


func _mobile_layout_reference_size() -> Vector2:
	# Godot keeps the game at its fixed 1152x648 internal resolution on Web.
	# Cabinet geometry, however, must follow the actual browser viewport so
	# ultrawide phones can use their side space without changing game pixels.
	if OS.has_feature("web"):
		var json: Variant = JavaScriptBridge.eval(
			"JSON.stringify([window.innerWidth, window.innerHeight])",
			true
		)
		var parsed: Variant = JSON.parse_string(String(json))
		if parsed is Array and parsed.size() >= 2:
			var css_size := Vector2(float(parsed[0]), float(parsed[1]))
			if css_size.x > 1.0 and css_size.y > 1.0:
				return css_size
	return StandardTouchControls.layout_reference_size(size)


func _mobile_device_pixel_ratio() -> float:
	if OS.has_feature("web"):
		return maxf(float(JavaScriptBridge.eval("window.devicePixelRatio || 1", true)), 1.0)
	return 1.0


func _clear_ui() -> void:
	if touch != null:
		touch.overload_hud=null
	hud=null
	_c2 = null
	for child in _ui.get_children():
		_ui.remove_child(child)
		child.queue_free()
	result_headline = ""
	result_score = null
	best_label = null
	result_survival = null
	best_survival = null
	_music_slider = null
	_sfx_slider = null


func _frame(heading: String) -> void:
	_rect(Rect2(0, 0, 1152, 648), INK)
	_rect(Rect2(32, 28, 1088, 592), RED)
	_rect(Rect2(48, 82, 1056, 524), INK)
	_rect(Rect2(48, 82, 1056, 6), GOLD)
	_label(heading, Rect2(66, 39, 970, 30), 20, CREAM)
	for x in [52, 1090]:
		for y in [46, 590]:
			_rect(Rect2(x, y, 10, 10), GOLD)


func _add_volume_sliders(host: Control, at: Vector2) -> void:
	_music_slider = VOLUME_SLIDER.new() as C2VolumeSlider
	_music_slider.name = "MusicVolume"
	_music_slider.position = at
	host.add_child(_music_slider)
	_music_slider.configure("MUSIC", audio.user_volume_percent(&"Music"))
	_music_slider.percent_changed.connect(
		func(percent: float) -> void:
			audio.set_user_volume_percent(&"Music", percent)
	)
	_sfx_slider = VOLUME_SLIDER.new() as C2VolumeSlider
	_sfx_slider.name = "SFXVolume"
	_sfx_slider.position = at + Vector2(0.0, 48.0)
	host.add_child(_sfx_slider)
	_sfx_slider.configure("SFX", audio.user_volume_percent(&"SFX"))
	_sfx_slider.percent_changed.connect(
		func(percent: float) -> void:
			audio.set_user_volume_percent(&"SFX", percent)
	)
	_sfx_slider.adjustment_finished.connect(_preview_sfx_volume)


func _preview_sfx_volume(_percent: float) -> void:
	audio.request_sfx(&"clock_in_confirm")


func _confirmed(action: Callable) -> Callable:
	return func() -> void: _activate_ui(action)


func _activate_ui(action: Callable) -> void:
	audio.request_sfx(&"clock_in_confirm")
	action.call()


func _toggle_pause_with_confirm() -> void:
	if state not in [State.GAME, State.PAUSED]:
		return
	audio.request_sfx(&"clock_in_confirm")
	if state == State.GAME:
		pause_game()
	else:
		resume_game()


func _rect(rect: Rect2, color: Color) -> void:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(node)


func _label(value: String, rect: Rect2, font_size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(label)
	return label


func _button(value: String, rect: Rect2, action: Callable, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 28 if rect.size.y >= 60 else 17)
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.darkened(0.16) if style_name == "pressed" else color
		style.border_color = CREAM if style_name == "focus" else INK
		style.set_border_width_all(3 if style_name == "focus" else 2)
		if style_name == "focus":
			style.draw_center = false
			style.set_expand_margin_all(4)
		button.add_theme_stylebox_override(style_name, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, INK)
	button.pressed.connect(action)
	_ui.add_child(button)
	return button
