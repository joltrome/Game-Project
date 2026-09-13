extends SceneTree

const PA_CA_SCENE := "res://scenes/experiments/motion_vis04_pa_ca.tscn"
const PB_CA_SCENE := "res://scenes/experiments/motion_vis04_pb_ca.tscn"
const PB_CB_SCENE := "res://scenes/experiments/motion_vis04_pb_cb.tscn"
const PROVISIONAL_SCENE := "res://scenes/experiments/motion_vis04_provisional.tscn"
const VIS03_SCENE := "res://scenes/experiments/motion_vis03_debug.tscn"
const D2_SCENE := "res://scenes/experiments/motion_d2.tscn"
const ARENA_SCENE := "res://scenes/prototypes/arena.tscn"
const S1_RUN_IMAGE := "res://assets/vm050_vis04/VM050_VIS04_S1_50x60_run_sheet.png"
const C1_COIN_IMAGE := "res://assets/vm050_vis04/VM050_VIS04_C1_16x16_coin_sheet.png"
const FLOAT_TOLERANCE := 0.001

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	await _test_profiles_and_frozen_values()
	await _test_s1_run_mapping_and_collision()
	await _test_carriage_height_pair()
	await _test_coin_collider_pair_and_scoring()
	await _test_natural_d3_cadence()
	await _test_restart_and_completion_cleanup()
	print("VM050_VIS04_RUNTIME_VALIDATION_FAILURES=%d" % _failures)
	quit(_failures)


func _test_profiles_and_frozen_values() -> void:
	var pa := await _make_shell(PA_CA_SCENE)
	var pb := await _make_shell(PB_CA_SCENE)
	var cb := await _make_shell(PB_CB_SCENE)
	var vis03 := await _make_shell(VIS03_SCENE)
	var d2 := await _make_shell(D2_SCENE)
	_check(
		pa.v2_visual_integration.runtime_profile_name() == "VIS-04"
		and pb.v2_visual_integration.runtime_profile_name() == "VIS-04"
		and cb.v2_visual_integration.runtime_profile_name() == "VIS-04"
		and pa.falling_collision_variant_id() == "VIS04-FALL-60",
		"All VIS-04 configurations use the isolated VIS-04/Fall60 profile"
	)
	var baseline := _frozen_snapshot(vis03)
	_check(
		_frozen_snapshot(pa) == baseline
		and _frozen_snapshot(pb) == baseline
		and _frozen_snapshot(cb) == baseline,
		"Player, conveyor, product, D3, round, score, and route values match VIS-03"
	)
	_check(
		pa.conveyor.effective_product_falling_collision_size() == Vector2(60.0, 60.0)
		and pa.conveyor.landed_product_size == Vector2(72.0, 48.0)
		and load(ARENA_SCENE) != null
		and d2.v2_visual_integration == null,
		"Fall60, landed72x48, Prototype A, and D2 remain preserved"
	)
	_free_shells([pa, pb, cb, vis03, d2])
	await process_frame


func _test_s1_run_mapping_and_collision() -> void:
	var shell := await _make_shell(PA_CA_SCENE)
	var visual := shell.v2_visual_integration
	var sprite := visual.technician_sprite()
	var collision := shell.conveyor.player.get_node("CollisionShape2D") as CollisionShape2D
	var run_valid := sprite.sprite_frames.get_frame_count(&"run") == 6
	for frame_index in range(6):
		var atlas := sprite.sprite_frames.get_frame_texture(&"run", frame_index) as AtlasTexture
		run_valid = (
			run_valid
			and atlas.atlas.resource_path == S1_RUN_IMAGE
			and atlas.region == Rect2(frame_index * 50.0, 0.0, 50.0, 60.0)
			and is_equal_approx(
				sprite.sprite_frames.get_frame_duration(&"run", frame_index),
				0.06
			)
		)
	_check(
		run_valid
		and sprite.sprite_frames.get_animation_loop(&"run")
		and sprite.position == Vector2(-25.0, -60.0)
		and visual.technician_anchor().position == Vector2(0.0, 24.0),
		"S1 uses six authored 50x60 frames at 60ms with a stable bottom-centre anchor"
	)
	_check(
		(collision.shape as RectangleShape2D).size == Vector2(32.0, 48.0)
		and visual.technician_visual_rect().size == Vector2(50.0, 60.0),
		"S1 visual bounds do not enlarge or move the frozen 32x48 hurtbox"
	)
	var controller_before := _player_snapshot(shell)
	for _frame in range(120):
		if shell.conveyor.player.is_on_floor():
			break
		await physics_frame
	Input.action_press("move_right")
	await physics_frame
	var right_run := sprite.animation == &"run" and sprite.scale == Vector2.ONE
	var right_facing := visual.technician_anchor().scale.x
	Input.action_release("move_right")
	Input.action_press("move_left")
	await physics_frame
	var left_run := sprite.animation == &"run" and sprite.scale == Vector2.ONE
	var left_facing := visual.technician_anchor().scale.x
	Input.action_release("move_left")
	_check(
		right_run and left_run and right_facing == 1.0 and left_facing == -1.0,
		"S1 RUN responds to immediate left/right reversal without changing control"
	)
	_check(
		_player_snapshot(shell) == controller_before,
		"VIS-04 animation does not change controller speed, acceleration, jump, or gravity"
	)
	shell.queue_free()
	await process_frame


func _test_carriage_height_pair() -> void:
	var pa := await _make_shell(PA_CA_SCENE)
	var pb := await _make_shell(PB_CA_SCENE)
	var a := pa.conveyor
	var b := pb.conveyor
	_check(
		is_equal_approx(a.sweeper_altitude, 518.0)
		and is_equal_approx(b.sweeper_altitude, 506.0)
		and is_equal_approx(b.sweeper_altitude - a.sweeper_altitude, -12.0),
		"P-A uses baseline Y=518 and P-B raises the physical carriage centre to Y=506"
	)
	_check(
		a.sweeper_size == b.sweeper_size
		and is_equal_approx(a.sweeper_speed, b.sweeper_speed)
		and is_equal_approx(a.sweeper_spawn_x, b.sweeper_spawn_x)
		and is_equal_approx(a.sweeper_exit_x, b.sweeper_exit_x)
		and is_equal_approx(a.sweeper_entry_cue_duration, b.sweeper_entry_cue_duration)
		and a.sweeper_collision_band() == Vector2(504.0, 532.0)
		and b.sweeper_collision_band() == Vector2(492.0, 520.0),
		"Only carriage Y differs; size, X path, speed, and cue timing remain frozen"
	)
	_check(
		a.sweeper_clears_grounded_player()
		and b.sweeper_clears_grounded_player()
		and a.sweeper_overlaps_player_on_can()
		and b.sweeper_overlaps_player_on_can()
		and a.sweeper_intersects_jump_arc()
		and b.sweeper_intersects_jump_arc(),
		"Both carriage heights preserve standing safety and deterministic can/jump pressure"
	)
	var a_intervals := a.normal_jump_sweeper_overlap_intervals()
	var b_intervals := b.normal_jump_sweeper_overlap_intervals()
	_check(
		not a_intervals.is_empty()
		and not b_intervals.is_empty()
		and a_intervals == a.normal_jump_sweeper_overlap_intervals()
		and b_intervals == b.normal_jump_sweeper_overlap_intervals(),
		"Normal-jump overlap remains present and deterministic at both heights"
	)
	print("VM050_VIS04_CARRIAGE %s" % JSON.stringify({
		"baseline_y": a.sweeper_altitude,
		"raised_y": b.sweeper_altitude,
		"baseline_jump_intervals": a_intervals,
		"raised_jump_intervals": b_intervals,
	}))
	_free_shells([pa, pb])
	await process_frame


func _test_coin_collider_pair_and_scoring() -> void:
	var ca := await _make_shell(PB_CA_SCENE)
	var cb := await _make_shell(PB_CB_SCENE)
	var ca_director := ca.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var cb_director := cb.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var ca_coin := _spawn_controlled_coin(ca, 1)
	var cb_coin := _spawn_controlled_coin(cb, 2)
	await process_frame
	var ca_sprite := ca.v2_visual_integration.coin_sprite(ca_coin)
	var cb_sprite := cb.v2_visual_integration.coin_sprite(cb_coin)
	var ca_atlas := ca_sprite.sprite_frames.get_frame_texture(&"spin", 0) as AtlasTexture
	var cb_atlas := cb_sprite.sprite_frames.get_frame_texture(&"spin", 0) as AtlasTexture
	_check(
		ca_atlas.atlas.resource_path == C1_COIN_IMAGE
		and cb_atlas.atlas.resource_path == C1_COIN_IMAGE
		and ca_atlas.region.size == Vector2(16.0, 16.0)
		and ca_sprite.scale == Vector2(2.0, 2.0)
		and cb_sprite.scale == Vector2(2.0, 2.0)
		and ca.v2_visual_integration.coin_visual_size() == Vector2(32.0, 32.0),
		"C1 renders the authored 16x16 six-frame source at exact 2x as 32x32"
	)
	_check(
		ca.v2_visual_integration.coin_collision_size(ca_coin) == Vector2(24.0, 24.0)
		and cb.v2_visual_integration.coin_collision_size(cb_coin) == Vector2(32.0, 32.0)
		and ca_director.collectible_size == Vector2(24.0, 24.0)
		and cb_director.collectible_size == Vector2(24.0, 24.0),
		"C-A keeps 24x24; C-B uses centred 32x32 without changing route geometry"
	)
	_check(
		_route_snapshot(ca_director) == _route_snapshot(cb_director),
		"C-A and C-B preserve identical offer routes, timing, and director configuration"
	)
	var score_before := cb_director.score
	cb_coin._on_body_entered(cb.conveyor.player)
	cb_coin._on_body_entered(cb.conveyor.player)
	await process_frame
	_check(
		cb_director.score == score_before + 1 and cb_coin.is_resolved(),
		"C-B collection increments score exactly once"
	)
	_free_shells([ca, cb])
	await process_frame


func _test_natural_d3_cadence() -> void:
	var shell := await _make_shell(PB_CB_SCENE)
	var conveyor := shell.conveyor
	var director := shell.background_drop_director
	director.configure_schedule_seed(5002)
	conveyor.left_failure_enabled = false
	conveyor.player.position = Vector2(640.0, 420.0)
	conveyor.player.collision_layer = 0
	conveyor.player.set_physics_process(false)
	shell.instrumentation.print_events = false
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 12.0
	var maximum_sequences := 0
	var maximum_falling := 0
	while not conveyor.gameplay_is_stopped():
		await physics_frame
		maximum_sequences = maxi(maximum_sequences, director.active_sequence_count())
		maximum_falling = maxi(maximum_falling, conveyor.falling_product_count())
	Engine.time_scale = previous_time_scale
	var warning_times := director.successful_warning_times()
	var candidate_rejections := director.candidate_rejection_counts_by_reason()
	var longest_gap := director.longest_successful_warning_gap()
	_check(
		director.released_event_count() == 6
		and warning_times.size() == 6
		and warning_times[0] >= 8.5
		and warning_times[0] <= 10.1
		and longest_gap <= 12.0
		and (
			longest_gap <= 10.5
			or int(candidate_rejections.get("collectible_path_overlap", 0)) > 0
		)
		and maximum_sequences <= 1
		and maximum_falling <= 1,
		"VIS-04 preserves the natural six-event D3 cadence and concurrency cap"
	)
	print("VM050_VIS04_CADENCE %s" % JSON.stringify({
		"warnings": warning_times,
		"lanes": director.selected_lane_indices(),
		"longest_gap": longest_gap,
		"candidate_rejections": candidate_rejections,
		"maximum_sequences": maximum_sequences,
		"maximum_falling": maximum_falling,
	}))
	shell.queue_free()
	await process_frame


func _test_restart_and_completion_cleanup() -> void:
	var change_error := change_scene_to_file(PROVISIONAL_SCENE)
	_check(change_error == OK, "VIS04-PROVISIONAL loads as an independent clean scene")
	await physics_frame
	await physics_frame
	var shell := current_scene as MotionExperimentShell
	var old_id := shell.get_instance_id()
	var director := shell.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	_spawn_controlled_coin(shell, 3)
	await process_frame
	var restart_event := InputEventAction.new()
	restart_event.action = "restart"
	restart_event.pressed = true
	shell.conveyor._unhandled_input(restart_event)
	for _frame in range(30):
		await physics_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			break
	await physics_frame
	var restarted := current_scene as MotionExperimentShell
	var restarted_director := (
		restarted.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	)
	_check(
		restarted != null
		and restarted.get_instance_id() != old_id
		and restarted_director.score == 0
		and restarted_director.active_collectibles().is_empty()
		and restarted.conveyor.survival_time < 0.1,
		"Restart clears C1 pickups, score, hazards, and timer state"
	)
	var round_controller := restarted.conveyor.get_node("RoundController") as FixedRoundController
	round_controller.force_time_remaining_for_test(0.0)
	round_controller._process(0.01)
	_check(
		round_controller.is_complete()
		and restarted.conveyor.gameplay_is_stopped(),
		"Provisional completion still reaches the frozen machine-shutdown state"
	)
	if restarted != null:
		restarted.queue_free()
	await process_frame


func _spawn_controlled_coin(shell: MotionExperimentShell, seed: int) -> ConveyorCollectible:
	var director := shell.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.placement_seed = 900 + seed
	director.candidate_x_positions = PackedFloat32Array([600.0])
	shell.conveyor.left_failure_enabled = false
	shell.conveyor.player.position = Vector2(900.0, 552.0)
	shell.conveyor.player.collision_layer = 0
	director.try_spawn_band_for_test(CollectibleDirector.PlacementBand.GROUND)
	return director.active_collectible()


func _player_snapshot(shell: MotionExperimentShell) -> Dictionary:
	var player := shell.conveyor.player
	return {
		"maximum_speed": player.maximum_speed,
		"air_acceleration": player.air_acceleration,
		"gravity": player.gravity,
		"jump_velocity": player.jump_velocity,
		"coyote_time": player.coyote_time,
		"jump_buffering": player.jump_buffering,
	}


func _frozen_snapshot(shell: MotionExperimentShell) -> Dictionary:
	var conveyor := shell.conveyor
	var director := shell.background_drop_director
	var coins := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	var round_controller := conveyor.get_node("RoundController") as FixedRoundController
	return {
		"player": _player_snapshot(shell),
		"player_collision": conveyor.player_collision_size(),
		"conveyor_speed_start": conveyor.conveyor_speed_at(0.0),
		"conveyor_speed_end": conveyor.conveyor_speed_at(60.0),
		"falling_collision": conveyor.effective_product_falling_collision_size(),
		"landed_collision": conveyor.landed_product_size,
		"ordinary_warning": conveyor.telegraph_duration,
		"ordinary_fall": conveyor.target_fall_duration,
		"d3_warning": director.warning_duration,
		"d3_fall": director.target_fall_duration,
		"d3_schedule": director.configured_event_times(),
		"sweeper_size": conveyor.sweeper_size,
		"sweeper_speed": conveyor.sweeper_speed,
		"sweeper_cue": conveyor.sweeper_entry_cue_duration,
		"coin_route_size": coins.collectible_size,
		"coin_value": 1,
		"round_duration": round_controller.round_duration,
		"route": _route_snapshot(coins),
	}


func _route_snapshot(director: CollectibleDirector) -> Dictionary:
	return {
		"candidate_x": director.candidate_x_positions,
		"first_window": Vector2(
			director.first_spawn_window_min,
			director.first_spawn_window_max
		),
		"lifetime": director.collectible_lifetime,
		"cadence": director.recurring_spawn_interval,
		"phase_one_weights": director.phase_one_template_weights,
		"phase_two_weights": director.phase_two_template_weights,
		"phase_three_weights": director.phase_three_template_weights,
		"phase_four_weights": director.phase_four_template_weights,
		"ground_y": director.ground_band_center_y_range,
		"low_air_y": director.low_air_band_center_y_range,
	}


func _free_shells(shells: Array) -> void:
	for shell in shells:
		if is_instance_valid(shell):
			shell.queue_free()


func _make_shell(scene_path: String) -> MotionExperimentShell:
	var shell := (load(scene_path) as PackedScene).instantiate() as MotionExperimentShell
	root.add_child(shell)
	await physics_frame
	return shell
