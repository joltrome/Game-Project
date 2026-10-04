extends SceneTree

const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const SESSION_SCENE := preload("res://scenes/presentation/standard_session.tscn")
const RECORD_STORE := preload("res://scripts/presentation/overload_record_store.gd")
const OVERLOAD_SCORE := preload("res://scripts/presentation/overload_score.gd")
const SCORE_PATH := "/tmp/vms-vm080-standard-score.cfg"
const AUDIO_PATH := "/tmp/vms-vm080-audio.cfg"
const OVERLOAD_PATH := "/tmp/vms-vm080-overload-record.cfg"

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func run() -> void:
	root.size = Vector2i(1152, 648)
	_cleanup_storage()
	await _test_bounded_intensity_and_standard_contract()
	_test_independent_records()
	await _test_menu_modes_retry_and_results()
	_cleanup_storage()
	print("VM080_OVERLOAD_FAILURES=", failures)
	quit(failures)


func _test_bounded_intensity_and_standard_contract() -> void:
	var standard := await _make_conveyor(false)
	var overload := await _make_conveyor(true)
	var checkpoints := PackedFloat32Array([0.0, 15.0, 30.0, 45.0, 60.0, 90.0, 120.0, 180.0])
	var expected_conveyor := PackedFloat32Array([1.25, 1.35, 1.425, 1.47, 1.50, 1.50, 1.50, 1.50])
	var expected_cooldown := PackedFloat32Array([0.50, 0.42, 0.35, 0.30, 0.27, 0.25, 0.25, 0.25])
	var previous_conveyor := -INF
	var previous_cooldown := INF
	for index in checkpoints.size():
		var time := checkpoints[index]
		var snapshot := overload.overload_intensity_snapshot(time)
		check(
			is_equal_approx(float(snapshot.conveyor_multiplier), expected_conveyor[index])
			and is_equal_approx(float(snapshot.pattern_cooldown), expected_cooldown[index]),
			"Overload checkpoint %.0fs matches its authored conveyor and cadence values" % time
		)
		check(
			float(snapshot.conveyor_multiplier) >= previous_conveyor
			and float(snapshot.pattern_cooldown) <= previous_cooldown,
			"Overload intensity is monotonic through %.0fs" % time
		)
		previous_conveyor = float(snapshot.conveyor_multiplier)
		previous_cooldown = float(snapshot.pattern_cooldown)
		print("VM080_INTENSITY ", JSON.stringify(snapshot))

	var equivalent := overload.overload_starting_equivalent_seconds
	check(
		absf(overload.conveyor_speed_at(0.0) - standard.conveyor_speed_at(equivalent)) <= 2.0
		and absf(overload.sweeper_speed_at(0.0) - standard.sweeper_speed_at(equivalent)) <= 3.0
		and absf(overload.hazard_speed_multiplier_at(0.0) - standard.hazard_speed_multiplier_at(equivalent)) <= 0.02,
		"Overload begins at declared late-Standard intensity without replaying teaching"
	)
	check(
		is_equal_approx(standard.conveyor_speed_at(0.0), 140.0)
		and is_equal_approx(standard.conveyor_speed_at(60.0), 175.0)
		and is_equal_approx(standard.sweeper_speed_at(0.0), 520.0)
		and is_equal_approx(standard.sweeper_speed_at(60.0), 598.0)
		and standard.director_phase_at(0.0) == 0
		and standard.director_phase_at(60.0) == 3,
		"Standard retains its existing 60-second speed and director curves"
	)
	check(
		overload.director_phase_at(0.0) == 3
		and overload.pattern_weights_at(0.0) == PackedInt32Array([0, 0, 50, 50])
		and overload.conveyor_speed_at(999.0) <= overload.player.maximum_speed * overload.maximum_conveyor_player_speed_ratio
		and overload.player_rightward_recovery_speed_at(999.0) > 0.0
		and overload.target_fall_duration_at(999.0) > 0.0,
		"Maximum Overload preserves compound-only selection, positive reaction time, and rightward recovery"
	)
	standard.queue_free()
	overload.queue_free()
	await process_frame


func _test_independent_records() -> void:
	var store := RECORD_STORE.new()
	store.storage_path = OVERLOAD_PATH
	store.load_bests()
	check(
		is_zero_approx(store.best_survival_seconds) and store.best_refunds == 0,
		"Overload records begin independently from the Standard score file"
	)
	store.record_run(97.42, 4)
	store.record_run(80.0, 9)
	var loaded := RECORD_STORE.new()
	loaded.storage_path = OVERLOAD_PATH
	loaded.load_bests()
	check(
		is_equal_approx(loaded.best_survival_seconds, 97.42)
		and loaded.best_refunds == 9
		and not loaded.has_best_score
		and RECORD_STORE.format_survival_time(97.42) == "01:37.42",
		"Historical raw records remain separate and do not fabricate a combined Best Score"
	)
	var actual_score := OVERLOAD_SCORE.calculate(61.25,7)
	check(actual_score == 7875 and OVERLOAD_SCORE.format_score(16892) == "16,892", "Combined Score uses stable configurable integer arithmetic and comma grouping")
	check(loaded.record_run(61.25,7,actual_score), "First actual VM-0.8.1 run establishes Best Score")
	loaded.load_bests()
	check(loaded.has_best_score and loaded.best_score == 7875, "Best Score persists with formula scope")


func _test_menu_modes_retry_and_results() -> void:
	var session := SESSION_SCENE.instantiate() as StandardSession
	session.score_storage_path = SCORE_PATH
	session.audio_settings_path = AUDIO_PATH
	session.overload_storage_path = OVERLOAD_PATH
	root.add_child(session)
	await process_frame
	await process_frame
	var clock_in := session._c2.get_node("clock_in") as Button
	var credits := session._c2.get_node("credits") as Button
	check(
		clock_in != null and credits != null and clock_in.has_focus()
		and session._c2.get_node_or_null("overload") == null,
		"Main Menu preserves one primary CLOCK IN action without direct mode clutter"
	)
	clock_in.pressed.emit()
	await process_frame
	var standard_button := session._c2.get_node("standard") as Button
	var overload_button := session._c2.get_node("overload") as Button
	var back_button := session._c2.get_node("back") as Button
	check(
		session.state == StandardSession.State.MODE_SELECT
		and standard_button.has_focus()
		and overload_button.get_node("Artwork") is TextureRect
		and back_button.get_node("Artwork") is TextureRect
		and not overload_button.focus_neighbor_left.is_empty(),
		"CLOCK IN opens authored sibling mode controls with Standard focused and Back wired"
	)
	overload_button.pressed.emit()
	await process_frame
	await physics_frame
	var overload_round := session.game.conveyor.get_node("RoundController") as FixedRoundController
	var overload_coins := session.game.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		session.current_mode == StandardSession.RunMode.OVERLOAD
		and session.state == StandardSession.State.GAME
		and session.game.overload_mode_enabled
		and session.game.conveyor.overload_mode_enabled
		and not overload_round.fixed_round_enabled
		and not overload_round.is_processing()
		and session.game.background_drop_director.endless_schedule_enabled
		and is_equal_approx(
			session.game.background_drop_director.endless_pre_reservation_lead_time,
			3.5
		),
		"Overload starts endless play and extends the authoritative D3 schedule without a second gameplay scene"
	)
	check(
		overload_coins.coin_pressure_enabled
		and overload_coins.refund_system_enabled
		and overload_coins.ballistic_integrity_enabled
		and not overload_coins.static_teaching_coin_enabled
		and session.game.build_id_override == "VM-0.8.1.1-OVERLOAD-QA-TUNING"
		and session.game.vm081_presentation_enabled
		and session.game.overload_emergency_visual != null,
		"Overload enters the accepted VM-0.7.3 coin stream after teaching and identifies its build"
	)
	session.game.conveyor.survival_time = 61.25
	overload_round._process(5.0)
	session.hud.refresh()
	check(
		not session.game.conveyor.is_round_complete
		and overload_round.is_running()
		and session.hud.timer_text.text == "01:01.25",
		"Overload continues beyond 60 seconds and HUD shows elapsed survival time"
	)

	session.last_survival_seconds = 61.25
	session._show_results(7, false)
	check(
		session.state == StandardSession.State.RESULTS
		and session.result_survival.text.contains("01:01.25")
		and session.result_survival.text.contains("REFUNDS 7")
		and session.result_score.text == "7,875"
		and session.overload_records.best_score == 7875,
		"Overload Results prioritize combined Score and preserve raw run explanation"
	)
	var retry := session._c2.get_node("retry") as Button
	retry.pressed.emit()
	await process_frame
	await physics_frame
	check(
		session.state == StandardSession.State.GAME
		and session.current_mode == StandardSession.RunMode.OVERLOAD
		and session.game.overload_mode_enabled,
		"Retry restarts the current Overload mode rather than changing modes"
	)

	session.show_menu()
	await process_frame
	(session._c2.get_node("clock_in") as Button).pressed.emit()
	await process_frame
	(session._c2.get_node("standard") as Button).pressed.emit()
	await process_frame
	await physics_frame
	var standard_round := session.game.conveyor.get_node("RoundController") as FixedRoundController
	check(
		session.current_mode == StandardSession.RunMode.STANDARD
		and not session.game.overload_mode_enabled
		and not session.game.conveyor.overload_mode_enabled
		and standard_round.fixed_round_enabled
		and standard_round.round_time_remaining > 59.9
		and not session.game.background_drop_director.endless_schedule_enabled,
		"Returning to Standard restores the frozen countdown and finite D3 schedule without mode-state leakage"
	)
	session.queue_free()
	await process_frame


func _make_conveyor(overload_enabled: bool) -> ConveyorPrototype:
	var conveyor := CONVEYOR_SCENE.instantiate() as ConveyorPrototype
	conveyor.overload_mode_enabled = overload_enabled
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	root.add_child(conveyor)
	await physics_frame
	conveyor.set_physics_process(false)
	(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	return conveyor


func _cleanup_storage() -> void:
	for path in [SCORE_PATH, AUDIO_PATH, OVERLOAD_PATH]:
		DirAccess.remove_absolute(path)
