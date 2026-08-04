extends SceneTree

const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const REPRESENTATIVE_WIDTHS := [1152, 960, 800, 720]

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	var conveyor := await _make_conveyor()
	var timer := conveyor.get_node("HUD/Timer") as Label
	var score_group := conveyor.get_node("HUD/ScoreGroup") as Control
	var score := conveyor.get_node("HUD/ScoreGroup/CollectibleScore") as Label
	var controller := (
		conveyor.get_node("RoundController") as FixedRoundController
	)

	_test_hierarchy_and_layout(timer, score_group, score)
	_test_responsive_layout(timer, score_group)
	_test_format_and_urgency(controller, timer)
	_test_death_freeze(conveyor, controller, timer)

	conveyor.queue_free()
	await process_frame
	await _test_restart_reset()

	print("VM044_COUNTDOWN_VISIBILITY_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_hierarchy_and_layout(timer: Label, score_group: Control, score: Label) -> void:
	_check(
		is_equal_approx(timer.anchor_left, 0.5)
		and is_equal_approx(timer.anchor_right, 0.5)
		and timer.offset_top >= 20.0,
		"Countdown is anchored to the viewport top centre with safe margin"
	)
	_check(
		timer.get_theme_font_size("font_size") == 44
		and score.get_theme_font_size("font_size") == 28
		and float(score.get_theme_font_size("font_size"))
			/ float(timer.get_theme_font_size("font_size")) >= 0.55
		and float(score.get_theme_font_size("font_size"))
			/ float(timer.get_theme_font_size("font_size")) <= 0.70,
		"Countdown typography is visually dominant over the coin score"
	)
	_check(
		timer.get_theme_constant("outline_size") == 6
		and timer.get_theme_stylebox("normal") is StyleBoxFlat,
		"Countdown has a dark outline and high-contrast backing plate"
	)
	_check(
		timer.position.y >= 20.0
		and timer.position.y + timer.size.y <= 100.0,
		"Countdown remains inside the top safe HUD band"
	)
	_check(
		score_group.position.y > timer.position.y + timer.size.y
		and is_equal_approx(score_group.anchor_left, 0.5)
		and is_equal_approx(score_group.anchor_right, 0.5),
		"Refund Coin score is attached directly beneath the centred timer"
	)


func _test_responsive_layout(timer: Label, score_group: Control) -> void:
	for width in REPRESENTATIVE_WIDTHS:
		var timer_rect := _anchored_rect(timer, Vector2(width, 648))
		var score_rect := _anchored_rect(score_group, Vector2(width, 648))
		_check(
			absf(timer_rect.get_center().x - width * 0.5) <= 0.5,
			"Countdown remains centred at %d-pixel viewport width" % width
		)
		_check(
			timer_rect.position.x >= 16.0
			and timer_rect.end.x <= width - 16.0,
			"Countdown remains inside safe bounds at %d pixels" % width
		)
		_check(
			not timer_rect.intersects(score_rect),
			"Countdown does not overlap coin score at %d pixels" % width
		)


func _test_format_and_urgency(
	controller: FixedRoundController,
	timer: Label
) -> void:
	_check(timer.text == "00:60", "Countdown begins at 00:60")
	controller.force_time_remaining_for_test(47.0)
	_check(timer.text == "00:47", "Countdown displays 00:47 exactly")
	controller.force_time_remaining_for_test(9.0)
	_check(timer.text == "00:09", "Countdown preserves two digits at 9 seconds")

	controller.force_time_remaining_for_test(60.0)
	controller.force_time_remaining_for_test(30.0)
	_check(
		controller.countdown_urgency_state()
			== FixedRoundController.CountdownUrgency.MILD
		and controller.urgency_entry_count(
			FixedRoundController.CountdownUrgency.MILD
		) == 1,
		"Mild urgency enters exactly once at 30 seconds"
	)
	controller.force_time_remaining_for_test(29.0)
	_check(
		controller.urgency_entry_count(
			FixedRoundController.CountdownUrgency.MILD
		) == 1,
		"Mild urgency does not retrigger below its threshold"
	)
	controller.force_time_remaining_for_test(15.0)
	_check(
		controller.countdown_urgency_state()
			== FixedRoundController.CountdownUrgency.URGENT
		and controller.urgency_entry_count(
			FixedRoundController.CountdownUrgency.URGENT
		) == 1,
		"Urgent state enters exactly once at 15 seconds"
	)
	controller.force_time_remaining_for_test(14.0)
	_check(
		controller.urgency_entry_count(
			FixedRoundController.CountdownUrgency.URGENT
		) == 1,
		"Urgent state does not retrigger below its threshold"
	)
	var pulse_count_before_final_ten := controller.final_second_pulse_count()
	controller.force_time_remaining_for_test(10.0)
	controller.force_time_remaining_for_test(9.8)
	controller.force_time_remaining_for_test(9.0)
	_check(
		controller.final_second_pulse_count()
			== pulse_count_before_final_ten + 2,
		"Final-ten pulse triggers once for each newly displayed second"
	)
	controller.force_time_remaining_for_test(5.0)
	_check(
		controller.countdown_urgency_state()
			== FixedRoundController.CountdownUrgency.FINAL
		and controller.urgency_entry_count(
			FixedRoundController.CountdownUrgency.FINAL
		) == 1
		and controller.countdown_pulse_is_active()
		and is_equal_approx(
			controller.countdown_pulse_target_scale(),
			controller.final_pulse_scale
		),
		"Final state enters once and uses the stronger readable pulse"
	)
	_check(
		controller.threshold_pulse_count() == 2,
		"Thirty- and fifteen-second threshold pulses each trigger once"
	)


func _test_death_freeze(
	conveyor: ConveyorPrototype,
	controller: FixedRoundController,
	timer: Label
) -> void:
	controller.force_time_remaining_for_test(12.4)
	var frozen_text := timer.text
	conveyor._kill_player()
	controller._process(1.0)
	_check(
		controller.ended_by_death()
		and timer.text == frozen_text
		and not controller.countdown_pulse_is_active()
		and timer.scale == Vector2.ONE,
		"Death freezes the displayed time and stops countdown animation"
	)


func _test_restart_reset() -> void:
	var change_error := change_scene_to_file(CONVEYOR_SCENE_PATH)
	_check(change_error == OK, "Restart fixture loads the conveyor scene")
	await scene_changed
	await process_frame
	var conveyor := current_scene as ConveyorPrototype
	var controller := (
		conveyor.get_node("RoundController") as FixedRoundController
	)
	controller.set_process(false)
	_check(
		conveyor.get_node("HUD/Timer").text == "00:60"
		and controller.countdown_urgency_state()
			== FixedRoundController.CountdownUrgency.NORMAL
		and controller.threshold_pulse_count() == 0
		and controller.final_second_pulse_count() == 0
		and not controller.countdown_pulse_is_active(),
		"Fresh scene restart resets countdown text, state, and pulses"
	)
	conveyor.queue_free()
	await process_frame


func _make_conveyor() -> ConveyorPrototype:
	var scene := load(CONVEYOR_SCENE_PATH) as PackedScene
	var conveyor := scene.instantiate() as ConveyorPrototype
	conveyor.initial_warning_delay = 999.0
	conveyor.left_failure_enabled = false
	root.add_child(conveyor)
	await process_frame
	var controller := (
		conveyor.get_node("RoundController") as FixedRoundController
	)
	controller.set_process(false)
	return conveyor


func _anchored_rect(control: Control, viewport_size: Vector2) -> Rect2:
	var left := viewport_size.x * control.anchor_left + control.offset_left
	var top := viewport_size.y * control.anchor_top + control.offset_top
	var right := viewport_size.x * control.anchor_right + control.offset_right
	var bottom := viewport_size.y * control.anchor_bottom + control.offset_bottom
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
