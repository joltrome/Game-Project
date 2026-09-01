class_name MotionV2DebugOverlay
extends Node2D

const PLAYER_COLOR := Color("4ee6a8")
const FALLING_COLOR := Color("ff5d67")
const LANDED_COLOR := Color("56b8ff")
const CARRIAGE_COLOR := Color("ffb84a")
const COIN_COLOR := Color("ffe66d")
const PIVOT_COLOR := Color("ffffff")

var integration: MotionV2VisualIntegration


func _ready() -> void:
	z_index = 100
	visible = false
	set_process(true)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if integration == null or integration.conveyor == null:
		return
	var conveyor := integration.conveyor
	var player := conveyor.player
	_draw_centered_box(
		player.position,
		conveyor.player_collision_size(),
		PLAYER_COLOR
	)
	_draw_cross(
		player.position + Vector2(0.0, conveyor.player_collision_size().y * 0.5),
		PIVOT_COLOR
	)

	for product in conveyor.active_falling_products():
		if is_instance_valid(product):
			_draw_centered_box(product.position, product.falling_size, FALLING_COLOR)
			_draw_cross(product.position, PIVOT_COLOR)
	for product in conveyor.active_landed_products():
		if not is_instance_valid(product):
			continue
		var landed_body := product.get_node("LandedBody") as AnimatableBody2D
		var center := landed_body.global_position
		_draw_centered_box(center, product.landed_size, LANDED_COLOR)
		_draw_cross(center, PIVOT_COLOR)
	for sweeper in conveyor.active_sweepers():
		if is_instance_valid(sweeper):
			_draw_centered_box(sweeper.position, sweeper.hazard_size, CARRIAGE_COLOR)
			_draw_cross(sweeper.position, PIVOT_COLOR)

	var collectibles := conveyor.get_node_or_null("CollectibleDirector") as CollectibleDirector
	if collectibles != null:
		for coin in collectibles.active_collectibles():
			if is_instance_valid(coin):
				_draw_centered_box(coin.position, coin.collectible_size, COIN_COLOR)
				_draw_cross(coin.position, PIVOT_COLOR)

	var state_text := "D3 state: unavailable"
	if integration.background_drop_director != null:
		var director := integration.background_drop_director
		state_text = "D3 state: %s  selected lane: %d" % [
			director.visual_state_name(),
			director.selected_lane_index,
		]
		if director.selected_lane_index >= 0 and not is_nan(director.selected_lane_x):
			draw_line(
				Vector2(director.selected_lane_x, 132.0),
				Vector2(director.selected_lane_x, conveyor.floor_y),
				Color(FALLING_COLOR.r, FALLING_COLOR.g, FALLING_COLOR.b, 0.72),
				2.0
			)
	draw_rect(Rect2(16.0, 92.0, 340.0, 28.0), Color(0.02, 0.03, 0.05, 0.86))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(24.0, 111.0),
		state_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color.WHITE
	)


func _draw_centered_box(center: Vector2, size: Vector2, color: Color) -> void:
	draw_rect(Rect2(center - size * 0.5, size), color, false, 2.0)


func _draw_cross(center: Vector2, color: Color) -> void:
	draw_line(center - Vector2(4.0, 0.0), center + Vector2(4.0, 0.0), color, 1.0)
	draw_line(center - Vector2(0.0, 4.0), center + Vector2(0.0, 4.0), color, 1.0)
