extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const MOTION_SCENE := preload("res://scenes/experiments/motion_vis04_pa_ca.tscn")
const FRAME_PACING := preload("res://scripts/presentation/frame_pacing_telemetry.gd")
const FIXED_STEP := 1.0 / 120.0
const TEST_SEEDS := [401, 1701, 4202, 7007, 9011]

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func finger(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func run() -> void:
	root.size = Vector2i(1152, 648)
	await _test_release_and_touch_layouts()
	await _test_multitouch_lifecycle()
	_test_frame_summary_contract()
	await _test_bounded_planning_and_frozen_d3()
	print("VM071_MOBILE_PLAYABILITY_FAILURES=", failures)
	quit(failures)


func _test_release_and_touch_layouts() -> void:
	var session := SESSION.instantiate() as StandardSession
	session.auto_focus_pause_enabled = false
	session.score_storage_path = "/tmp/vm071-score.cfg"
	root.add_child(session)
	await process_frame
	check(session.mobile_playability_enabled, "Release scene preserves VM-0.7.1 frame-planning behavior")
	session.start_game()
	await process_frame
	var director := session.game.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	check(
		session.game.build_id_override == "VM-0.7.3-COIN-PRESSURE"
		and director.bounded_optional_planning_enabled
		and director.performance_profiling_enabled
		and director.coin_pressure_enabled,
		"Forward release preserves bounded optional planning and frame correlation without changing gameplay flags"
	)
	session.show_menu()
	session.queue_free()
	await process_frame


func _test_multitouch_lifecycle() -> void:
	var touch := StandardTouchControls.new()
	root.add_child(touch)
	await process_frame
	touch.touch_available = true
	touch.configure_viewport(
		Vector2(1152.0, 648.0),
		Rect2(Vector2.ZERO, Vector2(1152.0, 648.0)),
		Vector2(844.0, 390.0),
		3.0
	)
	touch.set_game_active(true)
	var left := touch.rectangles[0].get_center()
	var right := touch.rectangles[1].get_center()
	var jump := touch.rectangles[2].get_center()
	finger(0, right, true)
	for index in range(1, 6):
		finger(index, jump, true)
		check(
			Input.is_action_pressed("move_right") and Input.is_action_pressed("jump"),
			"RIGHT remains held during repeated JUMP touch %d" % index
		)
		finger(index, jump, false)
		check(
			Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"),
			"Releasing JUMP %d leaves RIGHT held" % index
		)
	drag(0, left)
	check(
		Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"),
		"Sliding one movement finger switches cleanly between RIGHT and LEFT zones"
	)
	drag(0, Vector2(500.0, 250.0))
	check(
		not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"),
		"Sliding outside movement zones releases movement"
	)
	finger(0, Vector2(500.0, 250.0), false)
	finger(0, right, true)
	finger(1, jump, true)
	touch.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(
		not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"),
		"Focus loss releases simultaneous movement and jump"
	)
	finger(0, right, false)
	finger(1, jump, false)
	touch.set_game_active(false)
	check(
		touch.buttons.all(func(button: TouchScreenButton) -> bool: return not button.visible),
		"Death/results/pause state hides every gameplay touch target"
	)
	touch.set_game_active(true)
	check(
		touch.buttons.all(func(button: TouchScreenButton) -> bool: return button.visible and not button.is_pressed()),
		"Retry/resume restores controls without a stuck action"
	)
	touch.queue_free()
	await process_frame


func _test_frame_summary_contract() -> void:
	var telemetry = FRAME_PACING.new()
	telemetry.begin_run(true)
	telemetry._samples_ms = PackedFloat32Array([8.0, 16.0, 17.0, 26.0, 34.0, 51.0])
	telemetry._process_samples_ms = PackedFloat32Array([1.0, 2.0])
	telemetry._physics_samples_ms = PackedFloat32Array([0.5, 1.5])
	telemetry._planning_events.assign([
		{"planning_ms": 7.0},
		{"planning_ms": 34.0},
		{"planning_ms": 51.0},
	])
	var summary := telemetry.summary()
	check(
		int(summary.frames_over_16_67_ms) == 4
		and int(summary.frames_over_25_ms) == 3
		and int(summary.frames_over_33_33_ms) == 2
		and int(summary.frames_over_50_ms) == 1,
		"Frame telemetry reports every required tail threshold"
	)
	check(
		is_equal_approx(float(summary.median_ms), 26.0)
		and is_equal_approx(float(summary.p95_ms), 51.0)
		and is_equal_approx(float(summary.p99_ms), 51.0)
		and is_equal_approx(float(summary.worst_ms), 51.0),
		"Frame telemetry reports median, p95, p99, and worst frame"
	)
	check(
		int(summary.planning_over_33_33_ms) == 2
		and int(summary.planning_over_50_ms) == 1,
		"Planning telemetry preserves separate tail counts for correlation"
	)


func _test_bounded_planning_and_frozen_d3() -> void:
	var selected_doubles := 0
	var full_doubles := 0
	var selected_triples := 0
	var full_triples := 0
	var requested := 0
	var delivered := 0
	var maximum_planning_ms := 0.0
	var planning_over_33 := 0
	var planning_over_50 := 0
	var maximum_attempts := 0
	var d3_ok := true
	for seed in TEST_SEEDS:
		var shell := MOTION_SCENE.instantiate() as MotionExperimentShell
		shell.local_instrumentation_enabled = false
		root.add_child(shell)
		await process_frame
		var conveyor := shell.conveyor
		var director := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		var d3 := shell.background_drop_director
		director.ballistic_coin_events_enabled = true
		director.ballistic_abundance_enabled = true
		director.ballistic_integrity_enabled = true
		director.refund_chute_enabled = true
		director.refund_system_enabled = true
		director.static_teaching_coin_enabled = true
		director.performance_profiling_enabled = true
		director.bounded_optional_planning_enabled = true
		director.placement_seed = seed
		director._placement_rng_state = seed
		director._stream_rng_state = maxi(posmod(seed * 1664525 + 1013904223, 0x7fffffff), 1)
		conveyor.initial_warning_delay = 999.0
		conveyor.left_failure_enabled = false
		conveyor.set_physics_process(false)
		(conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
		director.set_process(false)
		d3.set_process(false)
		conveyor.player.global_position = Vector2(640.0, 420.0)
		conveyor.player.collision_layer = 0
		conveyor.player.set_physics_process(false)
		while conveyor.survival_time < 59.95:
			conveyor.survival_time += FIXED_STEP
			conveyor._update_continuous_speed_ramps()
			director.invalidate_landed_can_collision_cache_for_test()
			for coin in director.active_collectibles():
				coin._physics_process(FIXED_STEP)
				coin._process(FIXED_STEP)
			director._process(FIXED_STEP)
			d3._process(FIXED_STEP)
			for product in conveyor.active_falling_products():
				product._physics_process(FIXED_STEP)
			for product in conveyor.active_landed_products():
				product._physics_process(FIXED_STEP)
		var integrity := director.ballistic_integrity_summary()
		var run_summary := director.ballistic_run_summary()
		selected_doubles += int(integrity.selected_doubles)
		full_doubles += int(integrity.full_doubles)
		selected_triples += int(integrity.selected_triples)
		full_triples += int(integrity.full_triples)
		requested += (
			int(integrity.selected_singles)
			+ int(integrity.selected_doubles) * 2
			+ int(integrity.selected_triples) * 3
		)
		delivered += int(run_summary.delivered)
		for event in director.performance_event_log():
			var duration := float(event.planning_ms)
			maximum_planning_ms = maxf(maximum_planning_ms, duration)
			maximum_attempts = maxi(maximum_attempts, int(event.placement_attempts))
			if duration > 33.33:
				planning_over_33 += 1
			if duration > 50.0:
				planning_over_50 += 1
		d3_ok = d3_ok and d3.released_event_count() == 6 and d3.longest_successful_warning_gap() <= 8.80
		shell.queue_free()
		await process_frame
	var double_rate := float(full_doubles) / float(maxi(selected_doubles, 1))
	check(
		double_rate >= 0.50 and full_triples > 0,
		"Bounded planner preserves at least 50% complete doubles and a nonzero complete triple"
	)
	check(
		maximum_planning_ms < 16.67 and planning_over_33 == 0 and planning_over_50 == 0,
		"Five-run planning tail stays below one 60 fps frame with zero >33 ms or >50 ms events"
	)
	check(
		maximum_attempts <= 216 and delivered >= roundi(float(requested) * 0.60),
		"Deterministic operation cap prevents combinatorial work without reward starvation"
	)
	check(d3_ok, "All five runs preserve the frozen six-warning D3 schedule")
	print(
		"VM071_AGGREGATE requested=%d delivered=%d selected_2=%d full_2=%d selected_3=%d full_3=%d max_planning_ms=%.3f over_33=%d over_50=%d max_attempts=%d"
		% [requested, delivered, selected_doubles, full_doubles, selected_triples, full_triples, maximum_planning_ms, planning_over_33, planning_over_50, maximum_attempts]
	)
