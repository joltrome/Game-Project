extends SceneTree

const FALL72_SCENE := "res://scenes/experiments/motion_vis02_fall72.tscn"
const FALL60_SCENE := "res://scenes/experiments/motion_vis02_fall60.tscn"
const VIS01_SCENE := "res://scenes/experiments/motion_d3.tscn"
const D2_SCENE := "res://scenes/experiments/motion_d2.tscn"
const ARENA_SCENE := "res://scenes/prototypes/arena.tscn"
const FALLING_RED_IMAGE := "res://assets/vm050_d3_vis02/VM050_D3_VIS02_falling_red_soda_runtime_sheet.png"
const TECHNICIAN_IMAGE := "res://assets/vm050_d3_vis02/VM050_D3_VIS02_technician_chunky_runtime_sheet.png"
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
	await _test_controlled_profiles_and_unchanged_baselines()
	await _test_technician_rack_and_warning_mapping()
	await _test_source_independent_landed_alignment()
	await _test_falling_collision_variants_and_runtime_margins()
	await _test_natural_d3_cadence_for_both_variants()
	print("VM050_VIS02_RUNTIME_RETEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_controlled_profiles_and_unchanged_baselines() -> void:
	var fall72 := await _make_shell(FALL72_SCENE)
	var fall60 := await _make_shell(FALL60_SCENE)
	var vis01 := await _make_shell(VIS01_SCENE)
	var d2 := await _make_shell(D2_SCENE)
	_check(
		fall72.falling_collision_variant_id() == "VIS02-FALL-72"
		and fall60.falling_collision_variant_id() == "VIS02-FALL-60",
		"The two developer-only VIS-02 collision IDs are explicit"
	)
	_check(
		(fall72.conveyor.get_node("HUD/BuildId") as Label).text
			== "BUILD VM-0.5.0-VIS-02-D3-FALL72"
		and (fall60.conveyor.get_node("HUD/BuildId") as Label).text
			== "BUILD VM-0.5.0-VIS-02-D3-FALL60",
		"Each internal build exposes its subordinate A/B build ID"
	)
	_check(
		fall72.v2_visual_integration.runtime_profile_name() == "VIS-02"
		and fall60.v2_visual_integration.runtime_profile_name() == "VIS-02"
		and vis01.v2_visual_integration.runtime_profile_name() == "V2",
		"VIS-02 is isolated while the preserved VIS-01 scene still uses V2"
	)
	_check(
		fall72.conveyor.product_size == Vector2(72.0, 72.0)
		and fall60.conveyor.product_size == Vector2(72.0, 72.0)
		and fall72.conveyor.effective_product_falling_collision_size()
			== Vector2(72.0, 72.0)
		and fall60.conveyor.effective_product_falling_collision_size()
			== Vector2(60.0, 60.0),
		"Only the effective falling collision differs between A and B"
	)
	_check(
		_controlled_gameplay_snapshot(fall72) == _controlled_gameplay_snapshot(fall60),
		"A and B share player, scheduler, warning, physics, hazard, coin, and round values"
	)
	_check(
		d2.v2_visual_integration == null
		and load(ARENA_SCENE) != null,
		"D2 remains without runtime art integration and Prototype A remains loadable"
	)
	fall72.queue_free()
	fall60.queue_free()
	vis01.queue_free()
	d2.queue_free()
	await process_frame


func _test_technician_rack_and_warning_mapping() -> void:
	var shell := await _make_shell(FALL60_SCENE)
	var visual := shell.v2_visual_integration
	var technician := visual.technician_sprite()
	var technician_collision := (
		shell.conveyor.player.get_node("CollisionShape2D") as CollisionShape2D
	)
	_check(
		visual.technician_anchor().position == Vector2(0.0, 24.0)
		and technician.position == Vector2(-16.0, -48.0)
		and technician.scale == Vector2.ONE
		and (technician_collision.shape as RectangleShape2D).size
			== Vector2(32.0, 48.0),
		"Chunky technician keeps the exact 32x48 bottom-centre contract"
	)
	_check(
		technician.sprite_frames.get_frame_count(&"idle") == 3
		and technician.sprite_frames.get_frame_count(&"run") == 6
		and technician.sprite_frames.get_frame_count(&"jump") == 2
		and technician.sprite_frames.get_frame_count(&"fall") == 2
		and technician.sprite_frames.get_frame_count(&"land") == 3
		and technician.sprite_frames.get_frame_count(&"death") == 3
		and is_equal_approx(
			technician.sprite_frames.get_frame_duration(&"land", 2),
			0.12
		),
		"Technician maps every supplied VIS-02 tag and exact LAND timing"
	)
	_check(
		_technician_live_frames_fill_canvas(),
		"All sixteen live technician frames fill the documented 32x48 envelope"
	)
	var racks := visual.all_rack_sprites()
	var baseline_only := racks.size() == 10
	for rack in racks:
		baseline_only = baseline_only and rack.animation == &"normal"
		baseline_only = baseline_only and rack.get_child_count() == 0
	_check(
		baseline_only and visual.rack_sprite_for_lane(0) != null
		and visual.rack_sprite_for_lane(1) != null
		and visual.rack_sprite_for_lane(2) != null,
		"All ten safe rack positions share the common non-colliding NORMAL module"
	)

	var director := shell.background_drop_director
	shell.conveyor.left_failure_enabled = false
	shell.conveyor.player.set_physics_process(false)
	shell.conveyor.player.collision_layer = 0
	shell.conveyor.player.position = Vector2(640.0, 420.0)
	director.set_process(false)
	director.reservation_pending = true
	director._active_schedule_index = 0
	var warning_duration_before := director.warning_duration
	var replacement_id := director._try_start_reserved_sequence()
	var divergent_count := 0
	for rack in racks:
		if rack.animation != &"normal":
			divergent_count += 1
	_check(
		not replacement_id.is_empty()
		and divergent_count == 1
		and visual.rack_sprite_for_lane(1).animation == &"selected"
		and visual.d3_warning_sprite().visible
		and visual.d3_warning_sprite().animation == &"machine_warning",
		"Only the reserved slot diverges and starts the machine-integrated warning"
	)
	_check(
		is_equal_approx(director.warning_duration, warning_duration_before)
		and is_equal_approx(director.warning_time_remaining, warning_duration_before),
		"VIS-02 warning presentation leaves the existing 1.10-second schedule untouched"
	)
	director._process(warning_duration_before + 0.01)
	await process_frame
	var released := shell.conveyor.active_falling_products()
	_check(
		released.size() == 1
		and not visual.d3_warning_sprite().visible
		and visual.rack_sprite_for_lane(1).animation == &"release",
		"Release hides the guide warning and empties only the selected rack slot"
	)
	if not released.is_empty():
		released[0]._land()
		await process_frame
		_check(
			visual.rack_sprite_for_lane(1).animation in [&"reset", &"normal"],
			"Landing enters the supplied rack RESET path"
		)
	shell.queue_free()
	await process_frame


func _test_source_independent_landed_alignment() -> void:
	var shell := await _make_shell(FALL60_SCENE)
	var conveyor := shell.conveyor
	var visual := shell.v2_visual_integration
	conveyor.set_process(false)
	conveyor.left_failure_enabled = false
	conveyor.player.set_physics_process(false)
	conveyor.player.collision_layer = 0
	var normal := conveyor.force_drop_for_test(0)
	await _land_through_valid_floor_contact(normal)
	var background := conveyor.spawn_external_conveyor_product(
		600.0,
		conveyor.product_spawn_y,
		0.85,
		"VIS02-LANDED-ALIGNMENT"
	)
	if background != null:
		await _land_through_valid_floor_contact(background)
	_check(
		normal != null and background != null,
		"Both normal and D3 source paths create a landed product for comparison"
	)
	if normal != null and background != null:
		var normal_collision := normal.get_node("LandedBody/CollisionShape2D") as CollisionShape2D
		var background_collision := background.get_node("LandedBody/CollisionShape2D") as CollisionShape2D
		var normal_body := normal.get_node("LandedBody") as AnimatableBody2D
		var background_body := background.get_node("LandedBody") as AnimatableBody2D
		var normal_sprite := visual.product_landed_sprite(normal)
		var background_sprite := visual.product_landed_sprite(background)
		print("VM050_VIS02_LANDED_ALIGNMENT %s" % JSON.stringify({
			"floor_y": conveyor.floor_y,
			"normal_bottom": visual.landed_collision_bottom_y(normal),
			"background_bottom": visual.landed_collision_bottom_y(background),
			"normal_parent_y": normal.global_position.y,
			"background_parent_y": background.global_position.y,
			"normal_body_y": normal_body.global_position.y,
			"background_body_y": background_body.global_position.y,
			"normal_sprite_y": normal_sprite.global_position.y if normal_sprite != null else -999.0,
			"background_sprite_y": background_sprite.global_position.y if background_sprite != null else -999.0,
		}))
		_check(
			(normal_collision.shape as RectangleShape2D).size == Vector2(72.0, 48.0)
			and (background_collision.shape as RectangleShape2D).size == Vector2(72.0, 48.0),
			"Both sources retain the frozen 72x48 landed collision"
		)
		_check(
			is_equal_approx(visual.landed_collision_bottom_y(normal), conveyor.floor_y)
			and is_equal_approx(visual.landed_collision_bottom_y(background), conveyor.floor_y)
			and is_equal_approx(
				visual.landed_collision_bottom_y(normal),
				visual.landed_collision_bottom_y(background)
			),
			"Both landed collision bottoms equal the common conveyor surface exactly"
		)
		_check(
			is_equal_approx(normal.global_position.y, background.global_position.y)
			and is_equal_approx(normal_body.global_position.y, background_body.global_position.y)
			and normal_sprite != null and background_sprite != null
			and is_equal_approx(normal_sprite.global_position.y, background_sprite.global_position.y)
			and is_equal_approx(normal_sprite.position.y, 0.0)
			and is_equal_approx(background_sprite.position.y, 0.0),
			"Source provenance cannot change settled body or sprite Y/origin"
		)
		_check(
			normal.intended_platform_velocity() == background.intended_platform_velocity()
			and normal.is_landed_solid() and background.is_landed_solid(),
			"Both sources retain identical solid support and conveyor velocity"
		)
	shell.queue_free()
	await process_frame


func _test_falling_collision_variants_and_runtime_margins() -> void:
	var fall72 := await _make_shell(FALL72_SCENE)
	var fall60 := await _make_shell(FALL60_SCENE)
	fall72.conveyor.set_process(false)
	fall60.conveyor.set_process(false)
	var product72 := fall72.conveyor.force_drop_for_test(0)
	var product60 := fall60.conveyor.force_drop_for_test(0)
	await process_frame
	await process_frame
	var shape72 := product72.get_node("CollisionShape2D") as CollisionShape2D
	var shape60 := product60.get_node("CollisionShape2D") as CollisionShape2D
	var sprite72 := fall72.v2_visual_integration.product_falling_sprite(product72)
	var sprite60 := fall60.v2_visual_integration.product_falling_sprite(product60)
	_check(
		(shape72.shape as RectangleShape2D).size == Vector2(72.0, 72.0)
		and (shape60.shape as RectangleShape2D).size == Vector2(60.0, 60.0),
		"Variant A uses 72x72 and Variant B uses the centred 60x60 lethal collision"
	)
	_check(
		product72.falling_size == Vector2(72.0, 72.0)
		and product60.falling_size == Vector2(72.0, 72.0)
		and sprite72.sprite_frames.get_frame_count(&"fall_tumble") == 8
		and sprite60.sprite_frames.get_frame_count(&"fall_tumble") == 8
		and is_equal_approx(
			sprite72.sprite_frames.get_animation_speed(&"fall_tumble"),
			1.0 / 0.075
		)
		and is_equal_approx(
			sprite60.sprite_frames.get_animation_speed(&"fall_tumble"),
			1.0 / 0.075
		),
		"Both variants use the same eight-frame 75ms VIS-02 rotation artwork"
	)
	var atlas72 := sprite72.sprite_frames.get_frame_texture(&"fall_tumble", 0) as AtlasTexture
	var atlas60 := sprite60.sprite_frames.get_frame_texture(&"fall_tumble", 0) as AtlasTexture
	_check(
		atlas72.atlas.resource_path == atlas60.atlas.resource_path
		and atlas72.region == atlas60.region
		and is_equal_approx(product72.fall_speed, product60.fall_speed)
		and product72.position == product60.position,
		"A and B use the exact same art, spawn, trajectory, and falling speed"
	)
	var margin_report := _measure_falling_margins()
	_check(
		int(margin_report.max_hidden_72) == 10,
		"Actual runtime art reproduces the 72x72 baseline's 10px invisible margin"
	)
	_check(
		int(margin_report.max_hidden_60) <= 4,
		"The centred 60x60 collision keeps every invisible lethal margin at 4px or less"
	)
	_check(
		int(margin_report.max_visible_overhang_60) <= 6,
		"Variant B uses only forgiving visible overhang, with a measured 6px raster maximum"
	)
	print("VM050_VIS02_MARGIN_REPORT %s" % JSON.stringify(margin_report))
	await _land_through_valid_floor_contact(product60)
	var landed60 := product60.get_node("LandedBody/CollisionShape2D") as CollisionShape2D
	_check(
		product60.is_landed_solid()
		and (landed60.shape as RectangleShape2D).size == Vector2(72.0, 48.0)
		and is_equal_approx(
			fall60.v2_visual_integration.landed_collision_bottom_y(product60),
			fall60.conveyor.floor_y
		),
		"Variant B transitions stably from 60x60 lethal falling to 72x48 solid landed"
	)
	fall72.queue_free()
	fall60.queue_free()
	await process_frame


func _land_through_valid_floor_contact(product: ConveyorProduct) -> void:
	# AnimatableBody2D support transforms synchronize on the physics tick. Drive
	# the product through the public floor-contact path instead of teleporting it
	# by calling its private landing method from an idle-frame test.
	product.position.y = product.floor_y - product.falling_size.y * 0.5 - 1.0
	product.fall_speed = 120.0
	await physics_frame
	await physics_frame
	await process_frame


func _test_natural_d3_cadence_for_both_variants() -> void:
	var report72 := await _run_schedule(FALL72_SCENE, 5002)
	var report60 := await _run_schedule(FALL60_SCENE, 5002)
	_check(
		int(report72.drop_count) == 6 and int(report60.drop_count) == 6,
		"Both collision variants retain the natural six-event D3 schedule"
	)
	var timing_matches: bool = true
	var times72: PackedFloat32Array = report72.warning_times
	var times60: PackedFloat32Array = report60.warning_times
	if times72.size() != times60.size():
		timing_matches = false
	else:
		# The natural-lifecycle test runs at 12x speed and deliberately retains
		# live fairness retries, so absolute timestamps quantize differently by a
		# few accelerated ticks. Exact scheduler/timing configuration equality is
		# asserted above; here both outcomes must remain inside the frozen D3 range.
		timing_matches = (
			timing_matches
			and not times72.is_empty() and not times60.is_empty()
			and times72[0] >= 8.5 and times72[0] <= 10.1
			and times60[0] >= 8.5 and times60[0] <= 10.1
			# A valid lane may wait through the configured 9.0 s repeat ceiling,
			# one 1.10 s warning lifecycle, and accelerated-frame quantization.
			and float(report72.longest_gap) <= 10.5
			and float(report60.longest_gap) <= 10.5
			and _has_no_consecutive_duplicate_lanes(report72.lanes)
			and _has_no_consecutive_duplicate_lanes(report60.lanes)
		)
	_check(
		timing_matches,
		"Both collision retests remain inside frozen D3 scheduling and lane-fairness bounds"
	)
	_check(
		int(report72.maximum_sequences) <= 1
		and int(report60.maximum_sequences) <= 1
		and int(report72.maximum_falling) <= 1
		and int(report60.maximum_falling) <= 1,
		"Both variants preserve maximum one background sequence and one falling product"
	)
	print("VM050_VIS02_CADENCE_FALL72 %s" % JSON.stringify(report72))
	print("VM050_VIS02_CADENCE_FALL60 %s" % JSON.stringify(report60))


func _measure_falling_margins() -> Dictionary:
	var image := Image.load_from_file(ProjectSettings.globalize_path(FALLING_RED_IMAGE))
	var max_hidden_72 := 0
	var max_hidden_60 := 0
	var max_visible_overhang_60 := 0
	var frames: Array[Dictionary] = []
	for frame_index in range(8):
		var frame := image.get_region(Rect2i(frame_index * 36, 0, 36, 36))
		var used := frame.get_used_rect()
		var alpha_left := used.position.x * 2
		var alpha_top := used.position.y * 2
		var alpha_right := used.end.x * 2
		var alpha_bottom := used.end.y * 2
		var hidden72 := _side_margins(alpha_left, alpha_top, alpha_right, alpha_bottom, 0, 72, true)
		var hidden60 := _side_margins(alpha_left, alpha_top, alpha_right, alpha_bottom, 6, 66, true)
		var overhang60 := _side_margins(alpha_left, alpha_top, alpha_right, alpha_bottom, 6, 66, false)
		max_hidden_72 = maxi(max_hidden_72, _max_margin(hidden72))
		max_hidden_60 = maxi(max_hidden_60, _max_margin(hidden60))
		max_visible_overhang_60 = maxi(max_visible_overhang_60, _max_margin(overhang60))
		frames.append({
			"frame": frame_index + 1,
			"alpha": Vector2i(used.size.x * 2, used.size.y * 2),
			"hidden_60": hidden60,
			"overhang_60": overhang60,
		})
	return {
		"max_hidden_72": max_hidden_72,
		"max_hidden_60": max_hidden_60,
		"max_visible_overhang_60": max_visible_overhang_60,
		"frames": frames,
	}


func _side_margins(
	alpha_left: int,
	alpha_top: int,
	alpha_right: int,
	alpha_bottom: int,
	collision_start: int,
	collision_end: int,
	hidden: bool
) -> PackedInt32Array:
	if hidden:
		return PackedInt32Array([
			maxi(alpha_left - collision_start, 0),
			maxi(collision_end - alpha_right, 0),
			maxi(alpha_top - collision_start, 0),
			maxi(collision_end - alpha_bottom, 0),
		])
	return PackedInt32Array([
		maxi(collision_start - alpha_left, 0),
		maxi(alpha_right - collision_end, 0),
		maxi(collision_start - alpha_top, 0),
		maxi(alpha_bottom - collision_end, 0),
	])


func _max_margin(margins: PackedInt32Array) -> int:
	var maximum := 0
	for margin in margins:
		maximum = maxi(maximum, margin)
	return maximum


func _technician_live_frames_fill_canvas() -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(TECHNICIAN_IMAGE))
	for frame_index in range(16):
		var frame := image.get_region(Rect2i(frame_index * 32, 0, 32, 48))
		if frame.get_used_rect() != Rect2i(0, 0, 32, 48):
			return false
	return true


func _run_schedule(scene_path: String, seed: int) -> Dictionary:
	var shell := await _make_shell(scene_path)
	var conveyor := shell.conveyor
	var director := shell.background_drop_director
	director.configure_schedule_seed(seed)
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
	var report := {
		"drop_count": director.released_event_count(),
		"warning_times": director.successful_warning_times(),
		"lanes": director.selected_lane_indices(),
		"longest_gap": director.longest_successful_warning_gap(),
		"maximum_sequences": maximum_sequences,
		"maximum_falling": maximum_falling,
	}
	shell.queue_free()
	await process_frame
	return report


func _has_no_consecutive_duplicate_lanes(lanes: PackedInt32Array) -> bool:
	for index in range(1, lanes.size()):
		if lanes[index] == lanes[index - 1]:
			return false
	return true


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
		"product_visual_footprint": conveyor.product_size,
		"landed_collision": conveyor.landed_product_size,
		"product_spawn_y": conveyor.product_spawn_y,
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
