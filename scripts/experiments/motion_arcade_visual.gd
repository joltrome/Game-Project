class_name MotionArcadeVisual
extends Node2D

@export var foreground: bool = false
@export var compact_crop: bool = false
@export var vis02_consistent_rack: bool = false
@export var vis03_full_rack: bool = false

const NAVY := Color("17243a")
const DEEP_NAVY := Color("0d1424")
const CREAM := Color("f2e7c9")
const RED := Color("c93c45")
const DARK_RED := Color("7f2634")
const TEAL := Color("2ca6a4")
const BLUE := Color("3978c5")
const GREEN := Color("5ba85a")
const GOLD := Color("f2ba45")
const CORAL := Color("e66b4f")
const MUTED_BLUE := Color("64788f")


func _ready() -> void:
	z_index = 40 if foreground else -40
	queue_redraw()


func _draw() -> void:
	if foreground:
		_draw_foreground()
	else:
		_draw_background()


func _draw_background() -> void:
	draw_rect(Rect2(-32.0, -32.0, 1216.0, 736.0), DEEP_NAVY)
	draw_rect(Rect2(18.0, 42.0, 1116.0, 584.0), DARK_RED)
	draw_rect(Rect2(34.0, 58.0, 1084.0, 552.0), RED)
	draw_rect(Rect2(62.0, 84.0, 1028.0, 500.0), CREAM)
	draw_rect(Rect2(92.0, 116.0, 964.0, 468.0), NAVY)

	# Safe background inventory. It is intentionally muted and sits behind play.
	draw_rect(Rect2(122.0, 146.0, 642.0, 246.0), Color("263b54"))
	draw_rect(Rect2(134.0, 158.0, 618.0, 222.0), Color("1b2a40"))
	if not vis03_full_rack:
		for row in range(3):
			for column in range(10):
				var center := Vector2(166.0 + column * 60.0, 192.0 + row * 64.0)
				# D3's first-row columns 4, 6, and 8 are owned by the
				# stored/selected/released lifecycle director. Leaving the slots
				# empty here prevents translucent duplicate products.
				if (
					not compact_crop
					and row == 0
					and (vis02_consistent_rack or column in [4, 6, 8])
				):
					draw_rect(
						Rect2(center - Vector2(19.0, 27.0), Vector2(38.0, 54.0)),
						Color("142238")
					)
					continue
				var colors := [MUTED_BLUE, Color("58736f"), Color("716879")]
				_draw_product(center, colors[(row + column) % colors.size()], true)
			draw_line(
				Vector2(142.0, 222.0 + row * 64.0),
				Vector2(744.0, 222.0 + row * 64.0),
				Color("496077"),
				4.0
			)

	# Left retrieval chute and right product elevator establish source/destination.
	draw_rect(Rect2(96.0, 414.0, 72.0, 170.0), Color("1a2c40"))
	draw_rect(Rect2(108.0, 446.0, 48.0, 116.0), DEEP_NAVY)
	draw_rect(Rect2(800.0, 116.0, 256.0, 468.0), Color("263b54"))
	draw_rect(Rect2(824.0, 144.0, 208.0, 416.0), Color("152238"))
	for row in range(5):
		for column in range(3):
			var center := Vector2(866.0 + column * 62.0, 184.0 + row * 68.0)
			var colors := [TEAL, BLUE, GREEN, GOLD, CORAL]
			_draw_product(center, colors[(row + column) % colors.size()], false)

	# The rail itself is safe and visually recessive. Only the moving carriage is lethal.
	draw_rect(Rect2(96.0, 510.0, 704.0, 16.0), Color("26364b"))
	draw_rect(Rect2(96.0, 514.0, 704.0, 4.0), MUTED_BLUE)
	draw_rect(Rect2(96.0, 574.0, 960.0, 10.0), Color("dbcda8"))


func _draw_foreground() -> void:
	# Chunky frame pieces remain outside the gameplay collision geometry.
	draw_rect(Rect2(34.0, 58.0, 28.0, 552.0), RED)
	draw_rect(Rect2(1090.0, 58.0, 28.0, 552.0), RED)
	draw_rect(Rect2(34.0, 58.0, 1084.0, 26.0), RED)
	draw_rect(Rect2(34.0, 584.0, 1084.0, 26.0), RED)
	draw_rect(Rect2(92.0, 116.0, 8.0, 468.0), GOLD)
	draw_rect(Rect2(1048.0, 116.0, 8.0, 468.0), GOLD)

	# Non-colliding labels are deliberately short so the HUD remains dominant.
	_draw_block_label(Vector2(110.0, 126.0), Vector2(168.0, 22.0), "PRODUCT BAY")
	_draw_block_label(Vector2(826.0, 126.0), Vector2(204.0, 22.0), "VEND ELEVATOR")
	_draw_block_label(Vector2(104.0, 418.0), Vector2(56.0, 22.0), "OUT")


func _draw_product(center: Vector2, color: Color, muted: bool) -> void:
	var alpha := 0.52 if muted else 0.90
	var body_color := Color(color.r, color.g, color.b, alpha)
	draw_rect(Rect2(center - Vector2(17.0, 25.0), Vector2(34.0, 50.0)), body_color)
	draw_rect(
		Rect2(center + Vector2(-17.0, -7.0), Vector2(34.0, 9.0)),
		Color(NAVY.r, NAVY.g, NAVY.b, alpha)
	)
	draw_rect(
		Rect2(center + Vector2(-10.0, -20.0), Vector2(20.0, 6.0)),
		Color(CREAM.r, CREAM.g, CREAM.b, alpha)
	)


func _draw_block_label(origin: Vector2, label_size: Vector2, text: String) -> void:
	draw_rect(Rect2(origin, label_size), DARK_RED)
	draw_string(
		ThemeDB.fallback_font,
		origin + Vector2(8.0, 16.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		CREAM
	)
