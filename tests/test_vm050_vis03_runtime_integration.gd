extends SceneTree

const DEBUG_SCENE := "res://scenes/experiments/motion_vis03_debug.tscn"
const TEST_SCENE := "res://scenes/experiments/motion_vis03_test.tscn"
const VIS02_SCENE := "res://scenes/experiments/motion_vis02_fall60.tscn"
const D2_SCENE := "res://scenes/experiments/motion_d2.tscn"
const ARENA_SCENE := "res://scenes/prototypes/arena.tscn"
const TECHNICIAN_IMAGE := (
	"res://assets/vm050_d3_vis03/"
	+ "VM050_VIS03_technician_rigid_block_limbs_sheet.png"
)
const FALLING_RED_IMAGE := (
	"res://assets/vm050_d3_vis02/"
	+ "VM050_D3_VIS02_falling_red_soda_runtime_sheet.png"
)
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
	await _test_rigid_block_technician()
	await _test_rack_warning_and_product_continuity()
	await _test_landed_alignment_and_selected_collision()
	await _test_clean_and_debug_presentation()
	await _test_terminal_warning_cleanup()
	await _test_natural_d3_cadence()
	await _test_restart_resets_visual_state()
	print("VM050_VIS03_RUNTIME_INTEGRATION_FAILURES=%d" % _failures)
	quit(_failures)


func _test_profiles_and_frozen_values() -> void:
	var debug := await _make_shell(DEBUG_SCENE)
	var clean := await _make_shell(TEST_SCENE)
	var vis02 := await _make_shell(VIS02_SCENE)
	var d2 := await _make_shell(D2_SCENE)
	_check(
		debug.v2_visual_integration.runtime_profile_name() == "VIS-03"
		and clean.v2_visual_integration.runtime_profile_name() == "VIS-03"
		and vis02.v2_visual_integration.runtime_profile_name() == "VIS-02",
		"VIS-03 is isolated from the preserved VIS-02 profile"
	)
	_check(
		debug.falling_collision_variant_id() == "VIS03-FALL-60"
		and clean.falling_collision_variant_id() == "VIS03-FALL-60"
		and debug.conveyor.effective_product_falling_collision_size()
			== Vector2(60.0, 60.0)
		and clean.conveyor.effective_product_falling_collision_size()
			== Vector2(60.0, 60.0),
		"Both VIS-03 candidates select the centred 60x60 falling collision"
	)
	_check(
		_controlled_gameplay_snapshot(debug) == _controlled_gameplay_snapshot(clean)
		and _controlled_gameplay_snapshot(debug) == _controlled_gameplay_snapshot(vis02),
		"VIS-03 clean/debug and VIS-02 Fall60 share frozen gameplay values"
	)
	_check(
		d2.v2_visual_integration == null
		and load(ARENA_SCENE) != null,
		"D2 and Prototype A remain preserved and independently loadable"
	)
	debug.queue_free()
	clean.queue_free()
	vis02.queue_free()
	d2.queue_free()
	await process_frame


func _test_rigid_block_technician() -> void:
	var shell := await _make_shell(DEBUG_SCENE)
	var visual := shell.v2_visual_integration
	var sprite := visual.technician_sprite()
	var collision := shell.conveyor.player.get_node("CollisionShape2D") as CollisionShape2D
	var run_atlas := sprite.sprite_frames.get_frame_texture(&"run", 0) as AtlasTexture
	_check(
		sprite.position == Vector2(-20.0, -48.0)
		and visual.technician_anchor().position == Vector2(0.0, 24.0)
		and sprite.scale == Vector2.ONE
		and run_atlas.region.size == Vector2(40.0, 48.0),
		"Rigid-block technician uses the 40x48 cell and stable bottom-centre anchor"
	)
	_check(
		(collision.shape as RectangleShape2D).size == Vector2(32.0, 48.0),
		"Technician visual overhang does not enlarge the 32x48 player collision"
	)
	var run_mapping_valid := sprite.sprite_frames.get_frame_count(&"run") == 4
	for frame_index in range(4):
		var atlas := sprite.sprite_frames.get_frame_texture(&"run", frame_index) as AtlasTexture
		run_mapping_valid = (
			run_mapping_valid
			and atlas.region.position.x == float((frame_index + 3) * 40)
			and is_equal_approx(
				sprite.sprite_frames.get_frame_duration(&"run", frame_index),
				0.08
			)
		)
	_check(
		run_mapping_valid
		and is_equal_approx(sprite.sprite_frames.get_animation_speed(&"run"), 1.0),
		"RUN maps only atlas indices 3-6 at 80ms each for a 320ms loop"
	)
	_check(
		sprite.sprite_frames.get_frame_count(&"idle") == 3
		and sprite.sprite_frames.get_frame_count(&"jump") == 2
		and sprite.sprite_frames.get_frame_count(&"fall") == 2
		and sprite.sprite_frames.get_frame_count(&"land") == 3
		and sprite.sprite_frames.get_frame_count(&"death") == 3,
		"Approved continuity states retain their established frame counts"
	)
	_check(
		MotionV2VisualIntegration.technician_animation_for_state(
			false, true, 0.0, 0.0, false
		) == &"idle"
		and MotionV2VisualIntegration.technician_animation_for_state(
			false, true, 0.0, 1.0, true
		) == &"run"
		and MotionV2VisualIntegration.technician_animation_for_state(
			false, false, -1.0, 0.0, false
		) == &"jump"
		and MotionV2VisualIntegration.technician_animation_for_state(
			false, false, 1.0, 0.0, false
		) == &"fall"
		and MotionV2VisualIntegration.technician_animation_for_state(
			false, true, 0.0, 0.0, true
		) == &"land",
		"Runtime state mapping remains IDLE, RUN, JUMP, FALL, and visual-only LAND"
	)
	var image := Image.load_from_file(ProjectSettings.globalize_path(TECHNICIAN_IMAGE))
	_check(
		image.get_size() == Vector2i(760, 48),
		"Runtime technician sheet preserves nineteen stable 40x48 cells"
	)
	for _frame in range(120):
		if shell.conveyor.player.is_on_floor():
			break
		await physics_frame
	Input.action_press("move_right")
	await physics_frame
	var right_animation := sprite.animation
	var right_facing := visual.technician_anchor().scale.x
	Input.action_release("move_right")
	Input.action_press("move_left")
	await physics_frame
	var left_animation := sprite.animation
	var left_facing := visual.technician_anchor().scale.x
	Input.action_release("move_left")
	_check(
		right_animation == &"run"
		and left_animation == &"run"
		and right_facing == 1.0
		and left_facing == -1.0,
		"Rapid grounded reversal uses current input and never retains stale facing"
	)
	var score_before := (
		shell.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	).score
	shell.conveyor._kill_player()
	await process_frame
	_check(
		shell.conveyor.is_dead
		and not shell.conveyor.player.is_physics_processing()
		and sprite.animation == &"death"
		and (shell.conveyor.get_node("CollectibleDirector") as CollectibleDirector).score
			== score_before,
		"DEATH remains presentation-only after gameplay interaction is disabled"
	)
	shell.queue_free()
	await process_frame


func _test_rack_warning_and_product_continuity() -> void:
	var shell := await _make_shell(DEBUG_SCENE)
	var visual := shell.v2_visual_integration
	var director := shell.background_drop_director
	var baseline := visual.rack_baseline_sprite()
	var overlays := visual.all_rack_sprites()
	_check(
		baseline != null
		and baseline.visible
		and baseline.position == Vector2(126.0, 96.0)
		and baseline.scale == Vector2(2.0, 2.0)
		and baseline.texture.get_size() == Vector2(312.0, 108.0)
		and not _contains_collision_object(baseline),
		"VIS-03 uses one always-safe 312x108 full-rack baseline at exact 2x scale"
	)
	var safe_state := overlays.size() == 3
	for lane_index in range(overlays.size()):
		var overlay := overlays[lane_index]
		var visual_center_x := overlay.position.x + _vis03_overlay_half_width()
		safe_state = (
			safe_state
			and not overlay.visible
			and overlay.animation == &"normal"
			and is_equal_approx(
				visual_center_x,
				director.candidate_lane_x[lane_index]
			)
			and not _contains_collision_object(overlay)
		)
	_check(
		safe_state
		and director.candidate_lane_x == PackedFloat32Array([406.0, 526.0, 646.0]),
		"Hidden lane overlays align to the frozen 406/526/646 centres without revealing active lanes"
	)
	shell.conveyor.left_failure_enabled = false
	shell.conveyor.player.set_physics_process(false)
	shell.conveyor.player.collision_layer = 0
	shell.conveyor.player.position = Vector2(640.0, 420.0)
	director.set_process(false)
	director.reservation_pending = true
	director._active_schedule_index = 0
	var warning_duration_before := director.warning_duration
	var replacement_id := director._try_start_reserved_sequence()
	var visible_count := 0
	for overlay in overlays:
		if overlay.visible:
			visible_count += 1
	_check(
		not replacement_id.is_empty()
		and director.selected_lane_index == 1
		and visible_count == 1
		and overlays[1].animation == &"selected"
		and visual.d3_warning_sprite().visible
		and visual.d3_warning_sprite().animation == &"machine_warning"
		and not _contains_collision_object(visual.d3_warning_sprite()),
		"Only the selected lane diverges and the lighter warning remains non-colliding"
	)
	_check(
		is_equal_approx(director.warning_duration, warning_duration_before)
		and is_equal_approx(director.warning_time_remaining, warning_duration_before),
		"VIS-03 warning playback leaves the frozen gameplay duration unchanged"
	)
	director._process(warning_duration_before + 0.01)
	await process_frame
	var products := shell.conveyor.active_falling_products()
	var continuity_valid := products.size() == 1
	if not products.is_empty():
		continuity_valid = (
			visual.product_variant(products[0]) == director.selected_lane_index
			and visual.product_variant_name(products[0]) == "blue_coffee"
			and overlays[1].animation == &"release"
			and not visual.d3_warning_sprite().visible
		)
	_check(
		continuity_valid,
		"Released foreground product preserves selected rack-lane identity"
	)
	if not products.is_empty():
		await _land_through_valid_floor_contact(products[0])
		await create_timer(0.20).timeout
	_check(
		not overlays[1].visible and overlays[1].animation == &"normal",
		"RESET returns the active lane to the indistinguishable safe baseline"
	)
	shell.queue_free()
	await process_frame


func _test_landed_alignment_and_selected_collision() -> void:
	var shell := await _make_shell(DEBUG_SCENE)
	var conveyor := shell.conveyor
	var visual := shell.v2_visual_integration
	conveyor.set_process(false)
	conveyor.left_failure_enabled = false
	conveyor.player.set_physics_process(false)
	conveyor.player.collision_layer = 0
	var ordinary := conveyor.force_drop_for_test(0)
	await process_frame
	var falling_collision := ordinary.get_node("CollisionShape2D") as CollisionShape2D
	var falling_sprite := visual.product_falling_sprite(ordinary)
	var atlas := falling_sprite.sprite_frames.get_frame_texture(
		&"fall_tumble", 0
	) as AtlasTexture
	_check(
		(falling_collision.shape as RectangleShape2D).size == Vector2(60.0, 60.0)
		and falling_collision.position == Vector2.ZERO
		and atlas.atlas.resource_path == FALLING_RED_IMAGE
		and falling_sprite.sprite_frames.get_frame_count(&"fall_tumble") == 8,
		"Selected build uses centred 60x60 collision with unchanged VIS-02 rotation art"
	)
	var ordinary_speed := ordinary.fall_speed
	await _land_through_valid_floor_contact(ordinary)
	var background := conveyor.spawn_external_conveyor_product(
		600.0,
		conveyor.product_spawn_y,
		0.85,
		"VIS03-LANDED-ALIGNMENT"
	)
	if background != null:
		await _land_through_valid_floor_contact(background)
	var alignment_valid := ordinary != null and background != null
	if alignment_valid:
		var ordinary_landed := (
			ordinary.get_node("LandedBody/CollisionShape2D") as CollisionShape2D
		)
		var background_landed := (
			background.get_node("LandedBody/CollisionShape2D") as CollisionShape2D
		)
		alignment_valid = (
			(ordinary_landed.shape as RectangleShape2D).size == Vector2(72.0, 48.0)
			and (background_landed.shape as RectangleShape2D).size == Vector2(72.0, 48.0)
			and is_equal_approx(visual.landed_collision_bottom_y(ordinary), conveyor.floor_y)
			and is_equal_approx(visual.landed_collision_bottom_y(background), conveyor.floor_y)
			and is_equal_approx(ordinary.global_position.y, background.global_position.y)
			and ordinary.intended_platform_velocity()
				== background.intended_platform_velocity()
			and ordinary.is_landed_solid()
			and background.is_landed_solid()
		)
	_check(
		alignment_valid,
		"Normal and D3 products retain exact 72x48 landed-Y and support invariants"
	)
	_check(
		is_equal_approx(ordinary_speed, conveyor.fall_speed_at(0.0)),
		"VIS-03 collision selection does not compensate through fall-speed changes"
	)
	shell.queue_free()
	await process_frame


func _test_clean_and_debug_presentation() -> void:
	var debug := await _make_shell(DEBUG_SCENE)
	var clean := await _make_shell(TEST_SCENE)
	var debug_build := debug.conveyor.get_node("HUD/BuildId") as Label
	var debug_experiment := debug.conveyor.get_node("HUD/ExperimentId") as Label
	var clean_build := clean.conveyor.get_node("HUD/BuildId") as Label
	var clean_experiment := clean.conveyor.get_node("HUD/ExperimentId") as Label
	var clean_controls := clean.conveyor.get_node("HUD/Controls") as Label
	_check(
		debug_build.visible
		and debug_experiment.visible
		and debug_experiment.text.contains("INTERNAL VIS-03")
		and debug.instrumentation != null
		and debug.debug_overlay_toggle_allowed,
		"Debug candidate retains developer identity, instrumentation, and F8 toggle"
	)
	_check(
		not clean_build.visible
		and not clean_experiment.visible
		and not (clean.conveyor.get_node("HUD/Hypothesis") as Label).visible
		and clean.instrumentation == null
		and not clean.debug_overlay_toggle_allowed
		and not clean.v2_visual_integration.debug_overlay_is_enabled(),
		"Clean candidate hides internal labels, diagnostics, instrumentation, and overlay access"
	)
	_check(
		clean_controls.visible
		and clean_controls.text.contains("MOVE: A/D OR LEFT/RIGHT")
		and clean_controls.text.contains("JUMP: SPACE")
		and clean_controls.text.contains("RESTART: R")
		and not clean_controls.text.contains("D3")
		and not clean_controls.text.contains("INTERNAL"),
		"Clean candidate shows only concise fresh-player controls at run start"
	)
	clean._process(clean.clean_control_hint_duration + 0.01)
	_check(
		not clean.clean_control_hint_is_visible(),
		"Clean control hint leaves gameplay after its four-second display"
	)
	debug.queue_free()
	clean.queue_free()
	await process_frame


func _test_terminal_warning_cleanup() -> void:
	var death_shell := await _make_shell(DEBUG_SCENE)
	var death_visual := death_shell.v2_visual_integration
	var death_started := _start_controlled_warning(death_shell)
	death_shell.conveyor._kill_player()
	await process_frame
	_check(
		death_started
		and not death_visual.d3_warning_sprite().visible
		and _all_rack_overlays_hidden(death_visual),
		"Death clears the VIS-03 warning and selected rack overlay"
	)
	death_shell.queue_free()
	await process_frame

	var completion_shell := await _make_shell(DEBUG_SCENE)
	var completion_visual := completion_shell.v2_visual_integration
	var completion_started := _start_controlled_warning(completion_shell)
	var round_controller := (
		completion_shell.conveyor.get_node("RoundController")
		as FixedRoundController
	)
	round_controller.force_time_remaining_for_test(0.0)
	round_controller._process(0.01)
	completion_shell.background_drop_director._process(0.01)
	await process_frame
	_check(
		completion_started
		and round_controller.is_complete()
		and not completion_visual.d3_warning_sprite().visible
		and _all_rack_overlays_hidden(completion_visual),
		"Completion clears the VIS-03 warning and selected rack overlay"
	)
	completion_shell.queue_free()
	await process_frame


func _test_natural_d3_cadence() -> void:
	var shell := await _make_shell(DEBUG_SCENE)
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
	_check(
		director.released_event_count() == 6
		and warning_times.size() == 6
		and warning_times[0] >= 8.5
		and warning_times[0] <= 10.1
		and director.longest_successful_warning_gap() <= 10.5
		and maximum_sequences <= 1
		and maximum_falling <= 1,
		"VIS-03 preserves the natural six-event D3 cadence and concurrency cap"
	)
	print("VM050_VIS03_CADENCE %s" % JSON.stringify({
		"warnings": warning_times,
		"lanes": director.selected_lane_indices(),
		"longest_gap": director.longest_successful_warning_gap(),
		"maximum_sequences": maximum_sequences,
		"maximum_falling": maximum_falling,
	}))
	shell.queue_free()
	await process_frame


func _test_restart_resets_visual_state() -> void:
	var change_error := change_scene_to_file(TEST_SCENE)
	_check(change_error == OK, "VIS-03 restart fixture loads the clean candidate")
	await physics_frame
	await physics_frame
	var shell := current_scene as MotionExperimentShell
	var old_id := shell.get_instance_id()
	var visual := shell.v2_visual_integration
	visual.technician_sprite().play(&"death")
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
	_check(
		restarted != null
		and restarted.get_instance_id() != old_id
		and restarted.v2_visual_integration.technician_sprite().animation != &"death"
		and restarted.v2_visual_integration.rack_baseline_sprite().visible
		and not restarted.v2_visual_integration.rack_sprite_for_lane(0).visible
		and not restarted.v2_visual_integration.d3_warning_sprite().visible
		and restarted.conveyor.survival_time < 0.1,
		"Restart clears death presentation, rack warning, hazards, and timer state"
	)
	if restarted != null:
		restarted.queue_free()
	await process_frame


func _vis03_overlay_half_width() -> float:
	return 24.0


func _start_controlled_warning(shell: MotionExperimentShell) -> bool:
	var director := shell.background_drop_director
	shell.conveyor.left_failure_enabled = false
	shell.conveyor.player.set_physics_process(false)
	shell.conveyor.player.collision_layer = 0
	shell.conveyor.player.position = Vector2(900.0, 420.0)
	director.set_process(false)
	director.reservation_pending = true
	director._active_schedule_index = 0
	return not director._try_start_reserved_sequence().is_empty()


func _all_rack_overlays_hidden(visual: MotionV2VisualIntegration) -> bool:
	for overlay in visual.all_rack_sprites():
		if overlay.visible:
			return false
	return true


func _contains_collision_object(node: Node) -> bool:
	if node is CollisionObject2D:
		return true
	for child in node.get_children():
		if _contains_collision_object(child):
			return true
	return false


func _land_through_valid_floor_contact(product: ConveyorProduct) -> void:
	product.position.y = product.floor_y - product.falling_size.y * 0.5 - 1.0
	product.fall_speed = 120.0
	await physics_frame
	await physics_frame
	await process_frame


func _controlled_gameplay_snapshot(shell: MotionExperimentShell) -> Dictionary:
	var conveyor := shell.conveyor
	var director := shell.background_drop_director
	var round_controller := conveyor.get_node("RoundController") as FixedRoundController
	var coins := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	return {
		"player_collision": conveyor.player_collision_size(),
		"maximum_speed": conveyor.player.maximum_speed,
		"air_acceleration": conveyor.player.air_acceleration,
		"gravity": conveyor.player.gravity,
		"jump_velocity": conveyor.player.jump_velocity,
		"coyote_time": conveyor.player.coyote_time,
		"jump_buffer": conveyor.player.jump_buffering,
		"product_visual_footprint": conveyor.product_size,
		"falling_collision": conveyor.effective_product_falling_collision_size(),
		"landed_collision": conveyor.landed_product_size,
		"ordinary_warning": conveyor.telegraph_duration,
		"ordinary_fall_duration": conveyor.target_fall_duration,
		"d3_warning": director.warning_duration,
		"d3_fall_duration": director.target_fall_duration,
		"d3_schedule": director.configured_event_times(),
		"sweeper_size": conveyor.sweeper_size,
		"sweeper_speed": conveyor.sweeper_speed,
		"conveyor_start": conveyor.conveyor_speed_at(0.0),
		"conveyor_end": conveyor.conveyor_speed_at(60.0),
		"round_duration": round_controller.round_duration,
		"coin_size": coins.collectible_size,
		"coin_value": 1,
	}


func _make_shell(scene_path: String) -> MotionExperimentShell:
	var shell := (load(scene_path) as PackedScene).instantiate() as MotionExperimentShell
	root.add_child(shell)
	await physics_frame
	return shell
