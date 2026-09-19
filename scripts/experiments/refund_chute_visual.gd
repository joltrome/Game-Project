class_name RefundChuteVisual
extends Node2D

enum State {
	IDLE,
	PRE_EJECT,
	OPEN,
}

const IDLE_TEXTURE := preload(
	"res://assets/vm0610_refund_chute/refund_chute_idle.png"
)
const PRE_TEXTURE := preload(
	"res://assets/vm0610_refund_chute/refund_chute_pre.png"
)
const OPEN_TEXTURE := preload(
	"res://assets/vm0610_refund_chute/refund_chute_open.png"
)
const LIP_TEXTURE := preload(
	"res://assets/vm0610_refund_chute/refund_chute_lip.png"
)

const APPROVED_TOP_LEFT := Vector2(692.0, 338.0)
const APPROVED_SIZE := Vector2(84.0, 66.0)

@export var pre_eject_duration: float = 0.15
@export var open_after_final_launch_duration: float = 0.15

var director: CollectibleDirector
var state: State = State.IDLE
var _elapsed: float = 0.0
var _open_at: float = INF
var _close_at: float = INF
var _body: Sprite2D
var _lip: Sprite2D


func _ready() -> void:
	position = APPROVED_TOP_LEFT
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.centered = false
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.z_index = 2
	add_child(_body)
	_lip = Sprite2D.new()
	_lip.name = "FrontLip"
	_lip.centered = false
	_lip.texture = LIP_TEXTURE
	_lip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lip.z_index = 13
	add_child(_lip)
	_set_state(State.IDLE)
	if director != null:
		director.refund_chute_sequence_cued.connect(_on_sequence_cued)
		director.refund_chute_sequence_reset.connect(reset)


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	_elapsed += maxf(delta, 0.0)
	if state == State.PRE_EJECT and _elapsed + 0.000001 >= _open_at:
		_set_state(State.OPEN)
	if state == State.OPEN and _elapsed + 0.000001 >= _close_at:
		reset()


func reset() -> void:
	_elapsed = 0.0
	_open_at = INF
	_close_at = INF
	_set_state(State.IDLE)


func current_state_name() -> String:
	match state:
		State.PRE_EJECT:
			return "PRE_EJECT"
		State.OPEN:
			return "OPEN"
	return "IDLE"


func runtime_size() -> Vector2:
	return Vector2(_body.texture.get_size()) if _body != null else Vector2.ZERO


func _on_sequence_cued(
	configured_pre_duration: float,
	last_launch_delay: float
) -> void:
	pre_eject_duration = maxf(configured_pre_duration, 0.0)
	_elapsed = 0.0
	_open_at = pre_eject_duration
	_close_at = maxf(last_launch_delay, _open_at) + maxf(
		open_after_final_launch_duration,
		0.0
	)
	_set_state(State.PRE_EJECT if _open_at > 0.0 else State.OPEN)


func _set_state(next_state: State) -> void:
	state = next_state
	if _body == null:
		return
	match state:
		State.PRE_EJECT:
			_body.texture = PRE_TEXTURE
		State.OPEN:
			_body.texture = OPEN_TEXTURE
		_:
			_body.texture = IDLE_TEXTURE

