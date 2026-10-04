extends SceneTree

const CONVEYOR_SCENE := preload("res://scenes/prototypes/conveyor.tscn")
const SHELL_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const SESSION_SCENE := preload("res://scenes/presentation/standard_session.tscn")
const OVERLOAD_SCORE := preload("res://scripts/presentation/overload_score.gd")
const SCORE_PATH := "/tmp/vms-vm0812-standard.cfg"
const AUDIO_PATH := "/tmp/vms-vm0812-audio.cfg"
const OVERLOAD_PATH := "/tmp/vms-vm0812-overload.cfg"

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
	_cleanup()
	await _test_terminal_curve_and_electrical_solver()
	await _test_overload_only_concurrency_and_d3_coexistence()
	await _test_clean_and_saturated_review_fixtures()
	await _test_persistent_records_and_pixel_stability()
	_cleanup()
	print("VM0812_TERMINAL_OVERLOAD_FAILURES=", failures)
	quit(failures)


func _test_terminal_curve_and_electrical_solver() -> void:
	var overload := await _make_conveyor(true)
	var checkpoints := [0.0, 10.0, 20.0, 30.0, 45.0, 60.0, 75.0, 90.0]
	var expected_phases := [0, 1, 2, 3, 4, 5, 5, 5]
	for index in checkpoints.size():
		var time: float = checkpoints[index]
		var snapshot := overload.overload_intensity_snapshot(time)
		check(
			int(snapshot.phase) == expected_phases[index]
			and overload.pattern_is_solvable(ConveyorPrototype.PatternType.SWEEPER_ONLY, time),
			"Checkpoint %.0f has the expected phase and a schedulable electrical response" % time
		)
	var max_speed := overload.sweeper_speed_at(60.0)
	check(
		is_equal_approx(max_speed, 832.0)
		and absf(overload.sweeper_center_arrival_time(60.0) - 0.75) < 0.001,
		"MAX reproduces the verified 832 px/s and 0.75-second center travel"
	)
	check(
		overload.player_rightward_recovery_speed_at(60.0) > 0.0
		and overload.conveyor_speed_at(60.0) <= overload.player.maximum_speed * 0.85,
		"MAX conveyor remains severe while preserving positive rightward agency"
	)
	overload.queue_free()
	await process_frame


func _test_overload_only_concurrency_and_d3_coexistence() -> void:
	var overload_shell := SHELL_SCENE.instantiate() as MotionExperimentShell
	overload_shell.overload_mode_enabled = true
	root.add_child(overload_shell)
	await process_frame
	var overload := overload_shell.conveyor
	check(
		overload.maximum_active_sweepers_at(30.0) == 1
		and overload.maximum_active_sweepers_at(45.0) == 2
		and overload.maximum_active_sweepers_at(60.0) == 3
		and overload.maximum_concurrent_falling_cans_at(29.9) == 1
		and overload.maximum_concurrent_falling_cans_at(30.0) == 2
		and overload.maximum_concurrent_falling_cans_at(60.0) == 3,
		"Concurrency unlocks only in late and terminal Overload phases"
	)
	overload.apply_overload_review_checkpoint(60.0)
	overload.force_drop_for_test(2)
	var separated_reason := overload_shell.background_drop_director.candidate_rejection_reason(406.0)
	var overlapping_reason := overload_shell.background_drop_director.candidate_rejection_reason(646.0)
	check(
		separated_reason != "falling_product_active"
		and separated_reason != "falling_product_projected_overlap"
		and overlapping_reason == "falling_product_projected_overlap",
		"Overload D3 coexists with a separated ordinary fall but rejects projected overlap"
	)
	overload_shell.queue_free()
	await process_frame

	var standard_shell := SHELL_SCENE.instantiate() as MotionExperimentShell
	root.add_child(standard_shell)
	await process_frame
	var standard := standard_shell.conveyor
	standard.force_drop_for_test(2)
	check(
		standard_shell.background_drop_director.candidate_rejection_reason(406.0) == "falling_product_active"
		and standard.maximum_active_sweepers_at(999.0) == 1
		and standard.maximum_concurrent_falling_cans_at(999.0) == 1
		and is_equal_approx(standard.conveyor_speed_at(60.0), 175.0),
		"Standard retains serialized D3, one/one concurrency, and its frozen conveyor curve"
	)
	standard_shell.queue_free()
	await process_frame


func _test_clean_and_saturated_review_fixtures() -> void:
	var clean := SHELL_SCENE.instantiate() as MotionExperimentShell
	clean.overload_mode_enabled = true
	clean.vm081_presentation_enabled = true
	root.add_child(clean)
	await process_frame
	clean.apply_overload_review_checkpoint(60.0, false)
	check(
		clean.conveyor.landed_product_count() == 0
		and not clean.conveyor.sweeper_cue_is_visible()
		and clean.background_drop_director.active_sequence_count() == 0,
		"CLEAN 60 checkpoint remains an empty-board intensity comparison"
	)
	clean.queue_free()
	await process_frame

	var saturated := SHELL_SCENE.instantiate() as MotionExperimentShell
	saturated.overload_mode_enabled = true
	saturated.vm081_presentation_enabled = true
	root.add_child(saturated)
	await process_frame
	saturated.apply_overload_review_checkpoint(60.0, true)
	check(
		saturated.conveyor.landed_product_count() == 1
		and saturated.conveyor.has_pending_pattern_events()
		and saturated.background_drop_director.active_sequence_count() == 1,
		"SATURATED 60 installs validated terrain, D3 warning, and electrical warning"
	)
	saturated.queue_free()
	await process_frame


func _test_persistent_records_and_pixel_stability() -> void:
	var standard_store := StandardScoreStore.new()
	standard_store.storage_path = SCORE_PATH
	standard_store.record_score(7)
	var overload_store := OverloadRecordStore.new()
	overload_store.storage_path = OVERLOAD_PATH
	overload_store.record_run(40.0, 10, 6500)
	var session := SESSION_SCENE.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = SCORE_PATH
	session.audio_settings_path = AUDIO_PATH
	session.overload_storage_path = OVERLOAD_PATH
	root.add_child(session)
	await process_frame
	session.show_mode_select()
	await process_frame
	var screen := session._c2
	check(
		(screen.get_node("StandardRecordValue") as C2PixelText).text == "7"
		and (screen.get_node("OverloadRecordValue") as C2PixelText).text == "6,500",
		"Mode Select displays both known persisted records without hover"
	)
	var standard_button := screen.get_node("standard") as Button
	var overload_button := screen.get_node("overload") as Button
	var standard_art := standard_button.get_node("Artwork") as TextureRect
	var overload_art := overload_button.get_node("Artwork") as TextureRect
	var standard_position := standard_art.position
	var overload_position := overload_art.position
	var standard_idle := load("res://assets/ui/vm081_overload/buttons/standard-idle.png") as Texture2D
	var standard_focus := load("res://assets/ui/vm081_overload/buttons/standard-focus.png") as Texture2D
	var overload_idle := load("res://assets/ui/vm081_overload/buttons/overload-idle.png") as Texture2D
	var overload_focus := load("res://assets/ui/vm081_overload/buttons/overload-focus.png") as Texture2D
	var standard_idle_bounds := standard_idle.get_image().get_used_rect()
	var standard_focus_bounds := standard_focus.get_image().get_used_rect()
	var overload_idle_bounds := overload_idle.get_image().get_used_rect()
	var overload_focus_bounds := overload_focus.get_image().get_used_rect()
	check(
		standard_idle.get_size() == standard_focus.get_size()
		and overload_idle.get_size() == overload_focus.get_size()
		and standard_idle_bounds.get_center().x == standard_focus_bounds.get_center().x
		and overload_idle_bounds.get_center().x == overload_focus_bounds.get_center().x,
		"IDLE and FOCUS artwork keep equal canvases and the same horizontal anchor"
	)
	standard_button.mouse_entered.emit()
	overload_button.mouse_entered.emit()
	check(
		standard_art.position == standard_position
		and overload_art.position == overload_position,
		"Hover/focus swaps never translate either Artwork node"
	)

	session.start_standard_game()
	await process_frame
	session._show_results(12, false)
	await process_frame
	session.show_mode_select()
	await process_frame
	check(
		(session._c2.get_node("StandardRecordValue") as C2PixelText).text == "12",
		"A better Standard run is shown after Mode Select is recreated"
	)
	session.start_overload_game()
	await process_frame
	session.last_survival_seconds = 65.0
	session._show_results(9, false)
	await process_frame
	session.show_mode_select()
	await process_frame
	check(
		(session._c2.get_node("OverloadRecordValue") as C2PixelText).text == OVERLOAD_SCORE.format_score(8750),
		"A better combined Overload run is shown after Mode Select is recreated"
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


func _cleanup() -> void:
	for path in [SCORE_PATH, AUDIO_PATH, OVERLOAD_PATH]:
		DirAccess.remove_absolute(path)
