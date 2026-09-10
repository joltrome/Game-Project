class_name CohesionHUD
extends Control

const COIN := preload("res://assets/ui/get_canned_rc2/hud/refund-coin.png")
const COLORS := [Color("f2e7c9"),Color("f2ba45"),Color("ff8529"),Color("ff4033")]
var round_controller: FixedRoundController
var coins: CollectibleDirector
var timer_text: C2PixelText
var score_text: C2PixelText
var coin_position := Vector2.ZERO
var _old_timer: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	size = Vector2(1152,648)
	_old_timer = round_controller.get_parent().get_node("HUD/Timer")
	timer_text = C2PixelText.new()
	timer_text.glyph_scale=3
	add_child(timer_text)
	score_text = C2PixelText.new()
	add_child(score_text)
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	timer_text.text="00:%02d" % ceili(round_controller.round_time_remaining)
	timer_text.color=COLORS[round_controller.countdown_urgency_state()]
	var width := timer_text.ink_width(timer_text.text,3)
	timer_text.position=Vector2(576-width/2,12)
	timer_text.pivot_offset=Vector2(width/2,13.5)
	timer_text.scale=_old_timer.scale
	timer_text.queue_redraw()
	score_text.text="%02d" % maxi(coins.score,0)
	var glyph_size := 3
	while score_text.ink_width(score_text.text,glyph_size)>168 and glyph_size>1:
		glyph_size-=1
	score_text.glyph_scale=glyph_size
	score_text.position=Vector2(1120-score_text.ink_width(score_text.text,glyph_size),12)
	coin_position=Vector2(score_text.position.x-44,10)
	score_text.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_texture(COIN,coin_position)
