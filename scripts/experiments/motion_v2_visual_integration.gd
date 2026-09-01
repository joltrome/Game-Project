class_name MotionV2VisualIntegration
extends Node

enum ProductVariant {
	RED_SODA,
	BLUE_COFFEE,
	GREEN_SPORTS,
}

const ASSET_ROOT := "res://assets/vm050_d3_v2/"
const TECHNICIAN_TEXTURE := preload(
	ASSET_ROOT + "VM050_D3_V2_technician_runtime_sheet.png"
)
const FALLING_TEXTURES: Array[Texture2D] = [
	preload(ASSET_ROOT + "VM050_D3_V2_falling_red_soda_runtime_sheet.png"),
	preload(ASSET_ROOT + "VM050_D3_V2_falling_blue_coffee_runtime_sheet.png"),
	preload(ASSET_ROOT + "VM050_D3_V2_falling_green_sports_runtime_sheet.png"),
]
const LANDED_TEXTURES: Array[Texture2D] = [
	preload(ASSET_ROOT + "VM050_D3_V2_landed_red_soda_runtime_sheet.png"),
	preload(ASSET_ROOT + "VM050_D3_V2_landed_blue_coffee_runtime_sheet.png"),
	preload(ASSET_ROOT + "VM050_D3_V2_landed_green_sports_runtime_sheet.png"),
]
const CARRIAGE_TEXTURE := preload(
	ASSET_ROOT + "VM050_D3_V2_retrieval_carriage_runtime_sheet.png"
)
const COIN_TEXTURE := preload(
	ASSET_ROOT + "VM050_D3_V2_refund_coin_runtime_sheet.png"
)
const BELT_TEXTURE := preload(
	ASSET_ROOT + "VM050_D3_V2_conveyor_tile_sheet.png"
)
const RACK_TEXTURE := preload(
	ASSET_ROOT + "VM050_D3_V2_rack_product_lifecycle_sheet.png"
)
const WARNING_TEXTURE := preload(
	ASSET_ROOT + "VM050_D3_V2_warning_column_sheet.png"
)

const TECHNICIAN_FRAME_SIZE := Vector2i(32, 48)
const FALLING_FRAME_SIZE := Vector2i(36, 36)
const LANDED_FRAME_SIZE := Vector2i(36, 24)
const CARRIAGE_FRAME_SIZE := Vector2i(48, 14)
const COIN_FRAME_SIZE := Vector2i(12, 12)
const BELT_FRAME_SIZE := Vector2i(32, 16)
const RACK_FRAME_SIZE := Vector2i(72, 44)
const WARNING_FRAME_SIZE := Vector2i(24, 96)

const PRODUCT_VARIANT_NAMES := ["red_soda", "blue_coffee", "green_sports"]
const RACK_SELECTED_FRAMES := [3, 1, 2]
const RACK_ALIGNMENT_OFFSETS := [23.0, 9.0, -7.0]
const BELT_TILE_COUNT := 14

var conveyor: ConveyorPrototype
var background_drop_director: MotionBackgroundDropDirector
var debug_overlay_enabled: bool = false

var _technician_anchor: Node2D
var _technician_sprite: AnimatedSprite2D
var _debug_overlay: MotionV2DebugOverlay
var _rack_sprites: Array[AnimatedSprite2D] = []
var _d3_warning_sprite: AnimatedSprite2D
var _ordinary_warning_sprite: AnimatedSprite2D
var _belt_sprites: Array[AnimatedSprite2D] = []
var _falling_frames: Array[SpriteFrames] = []
var _landed_frames: Array[SpriteFrames] = []
var _carriage_frames: SpriteFrames
var _coin_frames: SpriteFrames
var _rack_frames: SpriteFrames
var _warning_frames: SpriteFrames
var _belt_frames: SpriteFrames
var _ordinary_variant_cursor: int = 0
var _previous_grounded: bool = false
var _land_visual_remaining: float = 0.0
var _ordinary_warning_was_visible: bool = false


func _ready() -> void:
	process_priority = 100
	if conveyor == null:
		push_error("MotionV2VisualIntegration requires a ConveyorPrototype")
		set_process(false)
		return
	if not runtime_contract_matches():
		push_error("V2 runtime art contract does not match frozen gameplay geometry")
		set_process(false)
		return
	_build_frame_resources()
	_install_technician()
	_install_conveyor_tiles()
	_install_warning_visuals()
	_install_rack_visuals()
	_connect_runtime_signals()
	_install_debug_overlay()
	_scan_runtime_objects()
	_previous_grounded = conveyor.player.is_on_floor()
	set_process(true)


func _process(delta: float) -> void:
	_update_technician(delta)
	_scan_runtime_objects()
	_update_product_visual_states()
	_update_carriage_visual_states()
	_update_coin_visual_states()
	_update_belt_animation_speed()
	_update_ordinary_warning()
	if _debug_overlay != null and _debug_overlay.visible:
		_debug_overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if (
		OS.is_debug_build()
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_F8
	):
		set_debug_overlay_enabled(not debug_overlay_is_enabled())


func runtime_contract_matches() -> bool:
	if conveyor == null:
		return false
	var collectibles := conveyor.get_node_or_null("CollectibleDirector") as CollectibleDirector
	return (
		conveyor.player_collision_size() == Vector2(32.0, 48.0)
		and conveyor.product_size == Vector2(72.0, 72.0)
		and conveyor.landed_product_size == Vector2(72.0, 48.0)
		and conveyor.sweeper_size == Vector2(96.0, 28.0)
		and collectibles != null
		and collectibles.collectible_size == Vector2(24.0, 24.0)
	)


func set_debug_overlay_enabled(enabled: bool) -> void:
	debug_overlay_enabled = enabled
	if _debug_overlay != null:
		_debug_overlay.visible = enabled
		_debug_overlay.queue_redraw()


func debug_overlay_is_enabled() -> bool:
	return _debug_overlay != null and _debug_overlay.visible


func technician_sprite() -> AnimatedSprite2D:
	return _technician_sprite


func technician_anchor() -> Node2D:
	return _technician_anchor


func rack_sprite_for_lane(lane_index: int) -> AnimatedSprite2D:
	if lane_index < 0 or lane_index >= _rack_sprites.size():
		return null
	return _rack_sprites[lane_index]


func d3_warning_sprite() -> AnimatedSprite2D:
	return _d3_warning_sprite


func debug_overlay() -> MotionV2DebugOverlay:
	return _debug_overlay


func product_variant(product: ConveyorProduct) -> int:
	return int(product.get_meta("v2_product_variant", -1))


func product_variant_name(product: ConveyorProduct) -> String:
	var variant := product_variant(product)
	if variant < 0 or variant >= PRODUCT_VARIANT_NAMES.size():
		return "unassigned"
	return PRODUCT_VARIANT_NAMES[variant]


func product_falling_sprite(product: ConveyorProduct) -> AnimatedSprite2D:
	return product.get_node_or_null("V2FallingVisual") as AnimatedSprite2D


func product_landed_sprite(product: ConveyorProduct) -> AnimatedSprite2D:
	return product.get_node_or_null("LandedBody/V2LandedVisual") as AnimatedSprite2D


func carriage_sprite(sweeper: AirSweeper) -> AnimatedSprite2D:
	return sweeper.get_node_or_null("V2CarriageVisual") as AnimatedSprite2D


func coin_sprite(coin: ConveyorCollectible) -> AnimatedSprite2D:
	return coin.get_node_or_null("V2CoinVisual") as AnimatedSprite2D


static func technician_animation_for_state(
	is_dead: bool,
	is_grounded: bool,
	vertical_velocity: float,
	input_axis: float,
	land_visual_active: bool
) -> StringName:
	if is_dead:
		return &"death"
	if not is_grounded:
		return &"jump" if vertical_velocity < 0.0 else &"fall"
	if not is_zero_approx(input_axis):
		return &"run"
	if land_visual_active:
		return &"land"
	return &"idle"


func _build_frame_resources() -> void:
	_falling_frames = [
		_make_frames(FALLING_TEXTURES[0], FALLING_FRAME_SIZE, [
			_animation(&"fall_tumble", 0, 3, 1.0 / 0.085, true),
		]),
		_make_frames(FALLING_TEXTURES[1], FALLING_FRAME_SIZE, [
			_animation(&"fall_tumble", 0, 3, 1.0 / 0.085, true),
		]),
		_make_frames(FALLING_TEXTURES[2], FALLING_FRAME_SIZE, [
			_animation(&"fall_tumble", 0, 3, 1.0 / 0.085, true),
		]),
	]
	_landed_frames = [
		_make_landed_frames(LANDED_TEXTURES[0]),
		_make_landed_frames(LANDED_TEXTURES[1]),
		_make_landed_frames(LANDED_TEXTURES[2]),
	]
	_carriage_frames = _make_frames(CARRIAGE_TEXTURE, CARRIAGE_FRAME_SIZE, [
		_animation(&"telegraph", 0, 2, 1.0 / 0.11, true),
		_animation(&"active_sweep", 3, 6, 1.0 / 0.07, true),
		_animation(&"return", 7, 8, 1.0 / 0.12, false),
	])
	_coin_frames = _make_frames(COIN_TEXTURE, COIN_FRAME_SIZE, [
		_animation(&"spin", 0, 5, 1.0 / 0.09, true),
	])
	_belt_frames = _make_frames(BELT_TEXTURE, BELT_FRAME_SIZE, [
		_animation(&"belt_loop", 0, 3, 10.0, true),
	])
	_rack_frames = _make_frames(RACK_TEXTURE, RACK_FRAME_SIZE, [
		_animation(&"stored", 0, 0, 1.0, false),
		_animation(&"selected_red", RACK_SELECTED_FRAMES[0], RACK_SELECTED_FRAMES[0], 1.0, false),
		_animation(&"selected_blue", RACK_SELECTED_FRAMES[1], RACK_SELECTED_FRAMES[1], 1.0, false),
		_animation(&"selected_green", RACK_SELECTED_FRAMES[2], RACK_SELECTED_FRAMES[2], 1.0, false),
		_animation(&"release", 4, 5, 10.0, false),
	])
	_warning_frames = _make_frames(WARNING_TEXTURE, WARNING_FRAME_SIZE, [
		_animation(&"warning", 0, 3, 10.0, true),
		_animation(&"release", 4, 5, 10.0, false),
	])


func _make_landed_frames(texture: Texture2D) -> SpriteFrames:
	return _make_frames(texture, LANDED_FRAME_SIZE, [
		_animation(&"impact", 0, 1, 1.0 / 0.075, false),
		_animation(&"settled", 2, 3, 1.0 / 0.16, true),
	])


func _animation(
	name: StringName,
	first_frame: int,
	last_frame: int,
	fps: float,
	looping: bool
) -> Dictionary:
	return {
		"name": name,
		"first": first_frame,
		"last": last_frame,
		"fps": fps,
		"loop": looping,
	}


func _make_frames(
	texture: Texture2D,
	frame_size: Vector2i,
	animations: Array
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for definition in animations:
		var animation_name: StringName = definition.name
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(definition.fps))
		frames.set_animation_loop(animation_name, bool(definition.loop))
		for frame_index in range(int(definition.first), int(definition.last) + 1):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(
				frame_index * frame_size.x,
				0,
				frame_size.x,
				frame_size.y
			)
			frames.add_frame(animation_name, atlas)
	return frames


func _new_sprite(frames: SpriteFrames, runtime_scale: float = 1.0) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * runtime_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	return sprite


func _install_technician() -> void:
	var player := conveyor.player
	(player.get_node("Body") as CanvasItem).visible = false
	_technician_anchor = Node2D.new()
	_technician_anchor.name = "V2TechnicianBottomCenter"
	_technician_anchor.position = Vector2(0.0, 24.0)
	_technician_anchor.z_index = 20
	player.add_child(_technician_anchor)
	var frames := _make_frames(TECHNICIAN_TEXTURE, TECHNICIAN_FRAME_SIZE, [
		_animation(&"idle", 0, 2, 1.0 / 0.16, true),
		_animation(&"run", 3, 8, 1.0 / 0.08, true),
		_animation(&"jump", 9, 10, 1.0 / 0.12, true),
		_animation(&"fall", 11, 12, 1.0 / 0.12, true),
		_animation(&"land", 13, 15, 1.0 / 0.087, false),
		_animation(&"death", 16, 18, 1.0 / 0.14, false),
	])
	_technician_sprite = _new_sprite(frames)
	_technician_sprite.name = "V2Technician"
	_technician_sprite.centered = false
	_technician_sprite.position = Vector2(-16.0, -48.0)
	_technician_anchor.add_child(_technician_sprite)
	_technician_sprite.play(&"idle")


func _install_conveyor_tiles() -> void:
	(conveyor.get_node("ConveyorBelt/Floor/Visual") as CanvasItem).visible = false
	(conveyor.get_node("ConveyorBelt/Floor/TopSurface") as CanvasItem).visible = false
	(conveyor.get_node("ConveyorBelt/Stripes") as CanvasItem).visible = false
	var belt_layer := Node2D.new()
	belt_layer.name = "V2ConveyorVisual"
	belt_layer.z_index = 41
	conveyor.add_child(belt_layer)
	for index in range(BELT_TILE_COUNT):
		var tile := _new_sprite(_belt_frames, 2.0)
		tile.name = "Tile%02d" % index
		tile.centered = false
		tile.position = Vector2(conveyor.belt_left_x + index * 64.0, conveyor.floor_y)
		tile.play(&"belt_loop")
		belt_layer.add_child(tile)
		_belt_sprites.append(tile)


func _install_warning_visuals() -> void:
	var source_carriage := conveyor.get_node("SourceRack/SourceCarriage") as Node2D
	(conveyor.get_node("SourceRack/SourceCarriage/WarningColumn") as CanvasItem).visible = false
	(conveyor.get_node("SourceRack/SourceCarriage/WarningText") as CanvasItem).visible = false
	_ordinary_warning_sprite = _new_sprite(_warning_frames, 4.0)
	_ordinary_warning_sprite.name = "V2OrdinaryWarning"
	_ordinary_warning_sprite.position = Vector2(0.0, 266.0)
	_ordinary_warning_sprite.z_index = 3
	_ordinary_warning_sprite.visible = false
	source_carriage.add_child(_ordinary_warning_sprite)

	_d3_warning_sprite = _new_sprite(_warning_frames, 4.0)
	_d3_warning_sprite.name = "V2BackgroundWarning"
	_d3_warning_sprite.position.y = 392.0
	_d3_warning_sprite.z_index = 3
	_d3_warning_sprite.visible = false
	_d3_warning_sprite.animation_finished.connect(_on_d3_warning_animation_finished)
	conveyor.add_child(_d3_warning_sprite)


func _install_rack_visuals() -> void:
	if background_drop_director == null:
		return
	# The original director keeps processing and emitting its frozen schedule;
	# only its code-drawn presentation is hidden.
	background_drop_director.visible = false
	for lane_index in range(background_drop_director.candidate_lane_x.size()):
		var variant := posmod(lane_index, ProductVariant.size())
		var rack := _new_sprite(_rack_frames)
		rack.name = "V2RackLane%d" % lane_index
		rack.position = Vector2(
			background_drop_director.candidate_lane_x[lane_index]
				+ RACK_ALIGNMENT_OFFSETS[variant],
			background_drop_director.background_product_y
		)
		rack.z_index = -8
		rack.play(&"stored")
		conveyor.add_child(rack)
		_rack_sprites.append(rack)


func _connect_runtime_signals() -> void:
	conveyor.product_dropped.connect(_on_product_dropped)
	conveyor.conveyor_product_landed.connect(_on_product_landed)
	conveyor.sweeper_entry_cue_started.connect(_on_sweeper_entry_cue_started)
	conveyor.sweeper_spawned.connect(_on_sweeper_spawned)
	conveyor.player_died.connect(_on_player_died_visual)
	var collectibles := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	collectibles.collectible_spawned.connect(_on_collectible_spawned)
	if background_drop_director != null:
		background_drop_director.warning_started.connect(_on_d3_warning_started)
		background_drop_director.product_released.connect(_on_d3_product_released)
		background_drop_director.visual_cycle_reset.connect(_on_d3_visual_cycle_reset)
		background_drop_director.sequence_stopped.connect(_on_d3_sequence_stopped)


func _install_debug_overlay() -> void:
	_debug_overlay = MotionV2DebugOverlay.new()
	_debug_overlay.name = "V2CollisionDebugOverlay"
	_debug_overlay.integration = self
	conveyor.add_child(_debug_overlay)
	set_debug_overlay_enabled(debug_overlay_enabled)


func _scan_runtime_objects() -> void:
	for product in conveyor.active_falling_products():
		if is_instance_valid(product) and not product.has_meta("v2_visual_installed"):
			_ensure_product_visual(product, _fallback_variant_for_product(product))
	for product in conveyor.active_landed_products():
		if not is_instance_valid(product):
			continue
		if not product.has_meta("v2_visual_installed"):
			_ensure_product_visual(product, _fallback_variant_for_product(product))
		_ensure_product_landed_visual(product)
	for sweeper in conveyor.active_sweepers():
		if is_instance_valid(sweeper):
			_ensure_carriage_visual(sweeper)
	var collectibles := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	for coin in collectibles.active_collectibles():
		if is_instance_valid(coin):
			_ensure_coin_visual(coin)


func _fallback_variant_for_product(product: ConveyorProduct) -> int:
	var existing := int(product.get_meta("v2_product_variant", -1))
	if existing >= 0:
		return existing
	var nearest_lane := -1
	var nearest_distance := INF
	for lane_index in range(conveyor.drop_lane_positions.size()):
		var distance := absf(product.position.x - conveyor.drop_lane_positions[lane_index])
		if distance < nearest_distance:
			nearest_lane = lane_index
			nearest_distance = distance
	if nearest_lane >= 0 and nearest_distance <= 2.0:
		return posmod(nearest_lane, ProductVariant.size())
	var variant := posmod(_ordinary_variant_cursor, ProductVariant.size())
	_ordinary_variant_cursor += 1
	return variant


func _ensure_product_visual(product: ConveyorProduct, requested_variant: int) -> void:
	var variant := clampi(requested_variant, 0, ProductVariant.size() - 1)
	product.set_meta("v2_product_variant", variant)
	product.set_meta("v2_visual_installed", true)
	(product.get_node("Body") as CanvasItem).visible = false
	(product.get_node("Band") as CanvasItem).visible = false
	(product.get_node("Label") as CanvasItem).visible = false
	var falling_sprite := _new_sprite(_falling_frames[variant], 2.0)
	falling_sprite.name = "V2FallingVisual"
	falling_sprite.z_index = 10
	falling_sprite.play(&"fall_tumble")
	product.add_child(falling_sprite)
	var landed_sprite := _new_sprite(_landed_frames[variant], 2.0)
	landed_sprite.name = "V2LandedVisual"
	landed_sprite.z_index = 10
	landed_sprite.visible = false
	landed_sprite.animation_finished.connect(
		_on_landed_animation_finished.bind(landed_sprite)
	)
	product.get_node("LandedBody").add_child(landed_sprite)
	var warning_outline := Line2D.new()
	warning_outline.name = "V2DespawnWarning"
	warning_outline.points = PackedVector2Array([
		Vector2(-38.0, -26.0),
		Vector2(38.0, -26.0),
		Vector2(38.0, 26.0),
		Vector2(-38.0, 26.0),
		Vector2(-38.0, -26.0),
	])
	warning_outline.width = 3.0
	warning_outline.default_color = Color("ffd66b")
	warning_outline.z_index = 11
	warning_outline.visible = false
	product.get_node("LandedBody").add_child(warning_outline)
	if product.is_landed():
		_ensure_product_landed_visual(product)


func _ensure_product_landed_visual(product: ConveyorProduct) -> void:
	var falling_sprite := product_falling_sprite(product)
	var landed_sprite := product_landed_sprite(product)
	if falling_sprite == null or landed_sprite == null:
		return
	falling_sprite.visible = false
	if not landed_sprite.visible:
		landed_sprite.visible = true
		landed_sprite.play(&"impact")


func _ensure_carriage_visual(sweeper: AirSweeper) -> void:
	if sweeper.has_meta("v2_visual_installed"):
		return
	sweeper.set_meta("v2_visual_installed", true)
	(sweeper.get_node("Arm") as CanvasItem).visible = false
	(sweeper.get_node("Housing") as CanvasItem).visible = false
	(sweeper.get_node("Label") as CanvasItem).visible = false
	var sprite := _new_sprite(_carriage_frames, 2.0)
	sprite.name = "V2CarriageVisual"
	sprite.z_index = 12
	sprite.play(&"active_sweep")
	sweeper.add_child(sprite)


func _ensure_coin_visual(coin: ConveyorCollectible) -> void:
	if coin.has_meta("v2_visual_installed"):
		return
	coin.set_meta("v2_visual_installed", true)
	for visual_path in ["Outline", "Body", "Rim", "CenterMark", "Glint"]:
		var visual := coin.get_node("VisualRoot/%s" % visual_path) as CanvasItem
		visual.modulate.a = 0.0
	var sprite := _new_sprite(_coin_frames, 2.0)
	sprite.name = "V2CoinVisual"
	sprite.z_index = 12
	sprite.play(&"spin")
	coin.add_child(sprite)


func _update_technician(delta: float) -> void:
	if _technician_sprite == null:
		return
	var player := conveyor.player
	var grounded := player.is_on_floor()
	var input_axis := Input.get_axis("move_left", "move_right")
	if grounded and not _previous_grounded and is_zero_approx(input_axis):
		_land_visual_remaining = 0.26
	if not grounded or not is_zero_approx(input_axis):
		_land_visual_remaining = 0.0
	else:
		_land_visual_remaining = maxf(_land_visual_remaining - delta, 0.0)
	var animation := technician_animation_for_state(
		conveyor.is_dead,
		grounded,
		player.velocity.y,
		input_axis,
		_land_visual_remaining > 0.0
	)
	if _technician_sprite.animation != animation:
		_technician_sprite.play(animation)
	if not is_zero_approx(input_axis):
		_technician_anchor.scale.x = 1.0 if input_axis > 0.0 else -1.0
	_previous_grounded = grounded


func _update_product_visual_states() -> void:
	for product in conveyor.active_falling_products():
		if not is_instance_valid(product):
			continue
		var falling_sprite := product_falling_sprite(product)
		if falling_sprite != null:
			falling_sprite.visible = true
			if conveyor.gameplay_is_stopped():
				falling_sprite.pause()
	for product in conveyor.active_landed_products():
		if not is_instance_valid(product):
			continue
		_ensure_product_landed_visual(product)
		var landed_sprite := product_landed_sprite(product)
		if landed_sprite != null and conveyor.gameplay_is_stopped():
			landed_sprite.pause()
		var outline := product.get_node_or_null("LandedBody/V2DespawnWarning") as Line2D
		if outline != null:
			outline.visible = product.is_in_despawn_warning()
			if outline.visible:
				outline.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.018))


func _update_carriage_visual_states() -> void:
	for sweeper in conveyor.active_sweepers():
		if not is_instance_valid(sweeper):
			continue
		var sprite := carriage_sprite(sweeper)
		if sprite == null:
			continue
		if conveyor.gameplay_is_stopped():
			sprite.pause()
			continue
		var should_return := sweeper.position.x >= sweeper.exit_x - sweeper.hazard_size.x
		var target_animation: StringName = &"return" if should_return else &"active_sweep"
		if sprite.animation != target_animation:
			sprite.play(target_animation)


func _update_coin_visual_states() -> void:
	var collectibles := conveyor.get_node("CollectibleDirector") as CollectibleDirector
	for coin in collectibles.get_children():
		if not coin is ConveyorCollectible:
			continue
		var typed_coin := coin as ConveyorCollectible
		var sprite := coin_sprite(typed_coin)
		if sprite != null:
			sprite.visible = not typed_coin.is_resolved() and not conveyor.gameplay_is_stopped()


func _update_belt_animation_speed() -> void:
	var speed_scale := conveyor.conveyor_speed / 140.0 if conveyor.conveyor_speed > 0.0 else 0.0
	if conveyor.gameplay_is_stopped():
		speed_scale = 0.0
	for tile in _belt_sprites:
		tile.speed_scale = speed_scale


func _update_ordinary_warning() -> void:
	var warning_visible := conveyor.warning_is_visible()
	if warning_visible and not _ordinary_warning_was_visible:
		_ordinary_warning_sprite.visible = true
		_ordinary_warning_sprite.play(&"warning")
	elif not warning_visible:
		_ordinary_warning_sprite.visible = false
	_ordinary_warning_was_visible = warning_visible


func _on_product_dropped(lane_index: int, _fall_speed: float) -> void:
	call_deferred("_register_latest_product", lane_index)


func _register_latest_product(lane_index: int) -> void:
	for product in conveyor.active_falling_products():
		if not is_instance_valid(product) or product.has_meta("v2_visual_installed"):
			continue
		var variant := (
			posmod(lane_index, ProductVariant.size())
			if lane_index >= 0
			else _fallback_variant_for_product(product)
		)
		_ensure_product_visual(product, variant)


func _on_product_landed(product: ConveyorProduct) -> void:
	_ensure_product_landed_visual(product)


func _on_sweeper_entry_cue_started(_altitude: float, _duration: float) -> void:
	var entry := conveyor.get_node("SweeperEntry") as Node2D
	var cue := entry.get_node_or_null("V2CarriageTelegraph") as AnimatedSprite2D
	if cue == null:
		cue = _new_sprite(_carriage_frames, 2.0)
		cue.name = "V2CarriageTelegraph"
		cue.z_index = 12
		entry.add_child(cue)
	(conveyor.get_node("SweeperEntry/ActivationCue") as CanvasItem).visible = false
	cue.visible = true
	cue.play(&"telegraph")


func _on_sweeper_spawned(sweeper: AirSweeper) -> void:
	var cue := conveyor.get_node_or_null("SweeperEntry/V2CarriageTelegraph") as AnimatedSprite2D
	if cue != null:
		cue.visible = false
	_ensure_carriage_visual(sweeper)


func _on_collectible_spawned(coin: ConveyorCollectible) -> void:
	_ensure_coin_visual(coin)


func _on_player_died_visual() -> void:
	# ConveyorPrototype disables player physics and gameplay interaction before
	# emitting player_died, so this collapsed pose is presentation-only.
	_technician_sprite.play(&"death")


func _on_d3_warning_started(
	_schedule_index: int,
	lane_index: int,
	lane_x: float,
	_started_at: float
) -> void:
	_reset_rack_visuals()
	if lane_index >= 0 and lane_index < _rack_sprites.size():
		var selected_name: StringName = [
			&"selected_red",
			&"selected_blue",
			&"selected_green",
		][posmod(lane_index, ProductVariant.size())]
		_rack_sprites[lane_index].play(selected_name)
	_d3_warning_sprite.position.x = lane_x
	_d3_warning_sprite.visible = true
	_d3_warning_sprite.play(&"warning")


func _on_d3_product_released(
	_schedule_index: int,
	lane_index: int,
	product: ConveyorProduct,
	_released_at: float
) -> void:
	var variant := posmod(lane_index, ProductVariant.size())
	product.set_meta("v2_product_variant", variant)
	if not product.has_meta("v2_visual_installed"):
		_ensure_product_visual(product, variant)
	if lane_index >= 0 and lane_index < _rack_sprites.size():
		_rack_sprites[lane_index].play(&"release")
	_d3_warning_sprite.play(&"release")


func _on_d3_visual_cycle_reset(_schedule_index: int, _reset_at: float) -> void:
	_reset_rack_visuals()
	_d3_warning_sprite.visible = false


func _on_d3_sequence_stopped(_outcome: String, _stopped_at: float) -> void:
	_reset_rack_visuals()
	_d3_warning_sprite.visible = false


func _reset_rack_visuals() -> void:
	for rack in _rack_sprites:
		rack.play(&"stored")


func _on_d3_warning_animation_finished() -> void:
	if _d3_warning_sprite.animation == &"release":
		_d3_warning_sprite.visible = false


func _on_landed_animation_finished(sprite: AnimatedSprite2D) -> void:
	if is_instance_valid(sprite) and sprite.animation == &"impact":
		sprite.play(&"settled")
