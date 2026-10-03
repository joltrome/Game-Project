class_name CohesionHUD
extends Control

const COIN := preload("res://assets/ui/get_canned_rc2/hud/refund-coin.png")
const COLORS := [Color("f2e7c9"),Color("f2ba45"),Color("ff8529"),Color("ff4033")]
const OVERLOAD_RECORD_STORE := preload("res://scripts/presentation/overload_record_store.gd")
const OVERLOAD_SCORE := preload("res://scripts/presentation/overload_score.gd")
var round_controller: FixedRoundController
var coins: CollectibleDirector
var timer_text: C2PixelText
var score_text: C2PixelText
var refund_text: C2PixelText
var score_label: C2PixelText
var survival_label: C2PixelText
var refund_label: C2PixelText
var overload_marking: C2PixelText
var coin_position := Vector2.ZERO
var _old_timer: Label
var overload_mode_enabled: bool = false
var overload_survival_points_per_second: int = 100
var overload_refund_points: int = 250

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
	refund_text = C2PixelText.new()
	add_child(refund_text)
	if overload_mode_enabled:
		score_label = _small_label("SCORE", Vector2(68,15))
		survival_label = _small_label("SURVIVAL", Vector2(408,15))
		refund_label = _small_label("REFUNDS", Vector2(866,15))
		overload_marking = _small_label("OVERLOAD", Vector2(64,63))
		overload_marking.color = Color("f2ba45")
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if overload_mode_enabled:
		var conveyor := round_controller.get_parent() as ConveyorPrototype
		timer_text.text = OVERLOAD_RECORD_STORE.format_survival_time(conveyor.survival_time)
		timer_text.color = COLORS[0]
		timer_text.glyph_scale = 3
		timer_text.position = Vector2(530,8)
		score_text.text = OVERLOAD_SCORE.format_score(OVERLOAD_SCORE.calculate(
			conveyor.survival_time,
			coins.score,
			overload_survival_points_per_second,
			overload_refund_points
		))
		var score_scale := 3
		while score_text.ink_width(score_text.text,score_scale)>240 and score_scale>1:
			score_scale-=1
		score_text.glyph_scale=score_scale
		score_text.position=Vector2(144,8)
		refund_text.text=str(maxi(coins.score,0))
		refund_text.glyph_scale=3
		refund_text.position=Vector2(1118-refund_text.ink_width(refund_text.text,3),8)
		coin_position=Vector2(992,6)
	else:
		timer_text.text="00:%02d" % ceili(round_controller.round_time_remaining)
		timer_text.color=COLORS[round_controller.countdown_urgency_state()]
	var width := timer_text.ink_width(timer_text.text,3)
	if not overload_mode_enabled:
		timer_text.position=Vector2(576-width/2,12)
	timer_text.pivot_offset=Vector2(width/2,13.5)
	timer_text.scale=_old_timer.scale
	timer_text.queue_redraw()
	if not overload_mode_enabled:
		score_text.text="%02d" % maxi(coins.score,0)
		var glyph_size := 3
		while score_text.ink_width(score_text.text,glyph_size)>168 and glyph_size>1:
			glyph_size-=1
		score_text.glyph_scale=glyph_size
		score_text.position=Vector2(1120-score_text.ink_width(score_text.text,glyph_size),12)
		coin_position=Vector2(score_text.position.x-44,10)
		refund_text.visible=false
	score_text.queue_redraw()
	queue_redraw()


func _small_label(value: String, position_value: Vector2) -> C2PixelText:
	var label := C2PixelText.new()
	label.family="small"
	label.text=value
	label.glyph_scale=2
	label.color=Color("f2e7c9")
	label.position=position_value
	add_child(label)
	return label

func _draw() -> void:
	if overload_mode_enabled:
		draw_rect(Rect2(0,0,1152,42),Color("172b3d"))
	draw_texture(COIN,coin_position)
