extends SceneTree

const D2_SCENE_PATH := "res://scenes/experiments/motion_d2.tscn"
const D3_SCENE_PATH := "res://scenes/experiments/motion_d3.tscn"
const CONVEYOR_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const ARENA_SCENE_PATH := "res://scenes/prototypes/arena.tscn"
const COIN_SCENE_PATH := "res://scenes/collectibles/conveyor_collectible.tscn"

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
	await _test_isolated_install_and_frozen_values()
	await _test_technician_state_mapping_and_death_gate()
	await _test_d3_rack_product_variant_continuity()
	await _test_carriage_coin_belt_and_debug_mapping()
	print("VM050_VIS01_INTEGRATION_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_isolated_install_and_frozen_values() -> void:
	var base := (load(CONVEYOR_SCENE_PATH) as PackedScene).instantiate() as ConveyorPrototype
	root.add_child(base)
	await physics_frame
	var frozen_values := _gameplay_snapshot(base)
	var d2 := await _make_shell(D2_SCENE_PATH)
	var d3 := await _make_shell(D3_SCENE_PATH)
	_check(
		d2.v2_visual_integration == null
		and d2.conveyor.get_node_or_null("V2VisualIntegration") == null,
		"D2 does not instantiate the VIS-01 adapter"
	)
	_check(
		d3.v2_visual_integration != null
		and d3.conveyor.get_node_or_null("V2VisualIntegration")
			== d3.v2_visual_integration,
		"D3 instantiates one isolated V2 visual adapter"
	)
	_check(
		d3.v2_visual_integration.runtime_contract_matches(),
		"V2 documented geometry matches every frozen runtime envelope"
	)
	_check(
		_gameplay_snapshot(d2.conveyor) == frozen_values
		and _gameplay_snapshot(d3.conveyor) == frozen_values,
		"D2 and D3 gameplay values remain identical to the frozen conveyor"
	)
	_check(
		load(ARENA_SCENE_PATH) != null,
		"Prototype A remains independently loadable"
	)
	_check(
		d3.background_drop_director != null
		and not d3.background_drop_director.visible
		and d3.background_drop_director.is_processing(),
		"Only D3's old drawing is hidden while its scheduler keeps processing"
	)
	_check(
		(d3.conveyor.get_node("HUD/BuildId") as Label).text
			== "BUILD VM-0.5.0-VIS-01-D3-V2",
		"The manual QA build exposes the VIS-01 D3 V2 build ID"
	)
	base.queue_free()
	d2.queue_free()
	d3.queue_free()
	await process_frame


func _test_technician_state_mapping_and_death_gate() -> void:
	var d3 := await _make_shell(D3_SCENE_PATH)
	var visual := d3.v2_visual_integration
	var sprite := visual.technician_sprite()
	var anchor := visual.technician_anchor()
	var collision_shape := d3.conveyor.player.get_node("CollisionShape2D") as CollisionShape2D
	var collision_before := (collision_shape.shape as RectangleShape2D).size
	_check(
		anchor.position == Vector2(0.0, 24.0)
		and sprite.position == Vector2(-16.0, -48.0)
		and sprite.scale == Vector2.ONE,
		"Technician uses exact 1x scale and a bottom-centre (16,48) anchor"
	)
	_check(
		sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and sprite.sprite_frames.get_frame_count(&"idle") == 3
		and sprite.sprite_frames.get_frame_count(&"run") == 6
		and sprite.sprite_frames.get_frame_count(&"death") == 3,
		"Technician frames import nearest-neighbour with the approved tag ranges"
	)
	_check(
		MotionV2VisualIntegration.technician_animation_for_state(false, true, 0.0, 0.0, false) == &"idle"
		and MotionV2VisualIntegration.technician_animation_for_state(false, true, 0.0, 1.0, true) == &"run"
		and MotionV2VisualIntegration.technician_animation_for_state(false, false, -1.0, 0.0, false) == &"jump"
		and MotionV2VisualIntegration.technician_animation_for_state(false, false, 1.0, 0.0, false) == &"fall"
		and MotionV2VisualIntegration.technician_animation_for_state(false, true, 0.0, 0.0, true) == &"land",
		"Representative live states map to IDLE, RUN, JUMP, FALL, and visual-only LAND"
	)
	var score_before := (d3.conveyor.get_node("CollectibleDirector") as CollectibleDirector).score
	d3.conveyor._kill_player()
	await process_frame
	_check(
		d3.conveyor.is_dead
		and not d3.conveyor.player.is_physics_processing()
		and sprite.animation == &"death",
		"DEATH begins only after the existing flow disables player physics"
	)
	_check(
		(d3.conveyor.get_node("CollectibleDirector") as CollectibleDirector).score == score_before
		and (collision_shape.shape as RectangleShape2D).size == collision_before,
		"Death art changes neither score interaction nor the frozen player collision"
	)
	d3.queue_free()
	await process_frame


func _test_d3_rack_product_variant_continuity() -> void:
	var d3 := await _make_shell(D3_SCENE_PATH)
	var director := d3.background_drop_director
	var visual := d3.v2_visual_integration
	d3.conveyor.left_failure_enabled = false
	d3.conveyor.player.set_physics_process(false)
	d3.conveyor.player.collision_layer = 0
	d3.conveyor.player.position = Vector2(640.0, 420.0)
	director.set_process(false)
	director.reservation_pending = true
	director._active_schedule_index = 0
	var replacement_id := director._try_start_reserved_sequence()
	_check(
		not replacement_id.is_empty()
		and director.selected_lane_index == 1
		and visual.rack_sprite_for_lane(1).animation == &"selected_blue"
		and visual.d3_warning_sprite().visible
		and is_equal_approx(
			visual.d3_warning_sprite().position.x,
			director.selected_lane_x
		),
		"The first D3 source selects the blue rack identity and aligns its warning lane"
	)
	director._process(director.warning_duration + 0.01)
	await process_frame
	var products := d3.conveyor.active_falling_products()
	var product: ConveyorProduct = products[0] if not products.is_empty() else null
	_check(
		product != null
		and visual.product_variant_name(product) == "blue_coffee"
		and visual.product_falling_sprite(product) != null,
		"The selected blue source identity follows the released foreground product"
	)
	if product != null:
		var falling_shape := product.get_node("CollisionShape2D") as CollisionShape2D
		var falling_sprite := visual.product_falling_sprite(product)
		_check(
			falling_sprite.scale == Vector2(2.0, 2.0)
			and falling_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and (falling_shape.shape as RectangleShape2D).size == Vector2(72.0, 72.0),
			"Falling V2 art renders 72x72 over the unchanged 72x72 lethal collision"
		)
		product._land()
		await process_frame
		var landed_shape := product.get_node("LandedBody/CollisionShape2D") as CollisionShape2D
		var landed_sprite := visual.product_landed_sprite(product)
		_check(
			landed_sprite != null
			and landed_sprite.visible
			and landed_sprite.scale == Vector2(2.0, 2.0)
			and not falling_sprite.visible
			and product.is_landed_solid()
			and (landed_shape.shape as RectangleShape2D).size == Vector2(72.0, 48.0),
			"The same variant settles sideways over the unchanged 72x48 solid collision"
		)
		_check(
			visual.product_variant_name(product) == "blue_coffee"
			and visual.rack_sprite_for_lane(1).animation == &"stored",
			"Landing preserves product identity and resets the rack lifecycle"
		)
	d3.queue_free()
	await process_frame


func _test_carriage_coin_belt_and_debug_mapping() -> void:
	var d3 := await _make_shell(D3_SCENE_PATH)
	var visual := d3.v2_visual_integration
	var belt_velocity_before := d3.conveyor.belt_support_velocity()
	var belt_layer := d3.conveyor.get_node("V2ConveyorVisual") as Node2D
	_check(
		belt_layer.get_child_count() == 14
		and (belt_layer.get_child(0) as AnimatedSprite2D).scale == Vector2(2.0, 2.0)
		and (belt_layer.get_child(0) as AnimatedSprite2D).get_playing_speed() < 0.0
		and d3.conveyor.belt_support_velocity() == belt_velocity_before,
		"Four-frame 2x belt tiles play leftward without changing support physics"
	)
	var cue_started := d3.conveyor._start_sweeper_entry_cue(
		d3.conveyor.sweeper_speed,
		ConveyorPrototype.PatternType.SWEEPER_ONLY
	)
	var cue := d3.conveyor.get_node_or_null("SweeperEntry/V2CarriageTelegraph") as AnimatedSprite2D
	_check(
		cue_started and cue != null and cue.visible and cue.animation == &"telegraph",
		"Existing Sweeper warning timing maps to the V2 TELEGRAPH frames"
	)
	var sweeper := d3.conveyor._spawn_sweeper()
	var carriage := visual.carriage_sprite(sweeper)
	var sweeper_shape := sweeper.get_node("CollisionShape2D") as CollisionShape2D
	_check(
		carriage != null
		and carriage.scale == Vector2(2.0, 2.0)
		and carriage.animation == &"active_sweep"
		and (sweeper_shape.shape as RectangleShape2D).size == Vector2(96.0, 28.0),
		"V2 carriage renders exactly 96x28 over the unchanged 96x28 lethal hitbox"
	)
	_check(
		(d3.conveyor.get_node("MotionArcadeBackground") as MotionArcadeVisual) != null
		and d3.conveyor.get_node("SweeperEntry") is Node2D,
		"The fixed safe rail and entry housing remain separate from carriage collision"
	)

	var coin := (load(COIN_SCENE_PATH) as PackedScene).instantiate() as ConveyorCollectible
	coin.configure(3.0, d3.conveyor.conveyor_speed, Vector2(24.0, 24.0), 0, 17)
	(d3.conveyor.get_node("CollectibleDirector") as CollectibleDirector).add_child(coin)
	visual._ensure_coin_visual(coin)
	var coin_shape := coin.get_node("CollisionShape2D") as CollisionShape2D
	_check(
		visual.coin_sprite(coin) != null
		and visual.coin_sprite(coin).scale == Vector2(2.0, 2.0)
		and visual.coin_sprite(coin).animation == &"spin"
		and (coin_shape.shape as RectangleShape2D).size == Vector2(24.0, 24.0),
		"Refund Coin uses the six-frame 2x spin over its unchanged 24x24 pickup area"
	)
	_check(
		not visual.debug_overlay_is_enabled(),
		"Developer collision overlay is off by default"
	)
	visual.set_debug_overlay_enabled(true)
	_check(
		visual.debug_overlay_is_enabled()
		and visual.debug_overlay().z_index == 100,
		"Developer overlay can be enabled explicitly without entering tester UI"
	)
	d3.queue_free()
	await process_frame


func _make_shell(scene_path: String) -> MotionExperimentShell:
	var shell := (load(scene_path) as PackedScene).instantiate() as MotionExperimentShell
	root.add_child(shell)
	await physics_frame
	return shell


func _gameplay_snapshot(conveyor: ConveyorPrototype) -> Dictionary:
	var round_controller := conveyor.get_node("RoundController") as FixedRoundController
	var coins := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	return {
		"player_collision": conveyor.player_collision_size(),
		"player_maximum_speed": conveyor.player.maximum_speed,
		"player_air_acceleration": conveyor.player.air_acceleration,
		"player_gravity": conveyor.player.gravity,
		"player_jump_velocity": conveyor.player.jump_velocity,
		"player_coyote_time": conveyor.player.coyote_time,
		"player_jump_buffering": conveyor.player.jump_buffering,
		"conveyor_speed_start": conveyor.conveyor_speed_at(0.0),
		"conveyor_speed_end": conveyor.conveyor_speed_at(60.0),
		"product_size": conveyor.product_size,
		"landed_product_size": conveyor.landed_product_size,
		"sweeper_size": conveyor.sweeper_size,
		"telegraph_duration": conveyor.telegraph_duration,
		"target_fall_duration": conveyor.target_fall_duration,
		"round_duration": round_controller.round_duration,
		"coin_size": coins.collectible_size,
		"coin_first_spawn": coins.first_spawn_time,
		"coin_lifetime": coins.collectible_lifetime,
	}
