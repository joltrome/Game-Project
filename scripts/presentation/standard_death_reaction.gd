class_name StandardDeathReaction
extends Node2D

const SHEET := preload("res://assets/ui/get_canned_rc2/death/technician-impact-ko.png")
const HIT_STOP_MS := 70
const FRAME_DURATIONS_MS := [60,70,80,80,130]
const FINAL_HOLD_MS := 260
const TOTAL_MS := 750
var started_at_msec: int
var cause: ConveyorPrototype.DeathCause
var captured: Sprite2D
var ko: Sprite2D
var frame_index := -1
var snapshot_anchor: Transform2D
var captured_origin: Vector2
const OUT_OPENING := Rect2(108,446,48,116)

func setup(snapshot: Dictionary, death_cause: ConveyorPrototype.DeathCause) -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=20
	cause=death_cause
	started_at_msec=Time.get_ticks_msec()
	snapshot_anchor=snapshot.anchor
	global_transform=snapshot_anchor
	captured=Sprite2D.new()
	captured.texture=snapshot.texture
	captured.centered=snapshot.centered
	captured.offset=snapshot.offset
	add_child(captured)
	captured.global_transform=snapshot.transform
	captured.visible=snapshot.visible
	captured_origin=captured.global_position
	if cause==ConveyorPrototype.DeathCause.LEFT_OUT:
		var aperture:=Polygon2D.new()
		aperture.clip_children=CanvasItem.CLIP_CHILDREN_ONLY
		var r:=OUT_OPENING
		aperture.polygon=global_transform.affine_inverse()*PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
		add_child(aperture)
		captured.reparent(aperture,true)
	ko=Sprite2D.new()
	ko.texture=SHEET
	ko.centered=false
	ko.position=Vector2(-40,-88)
	ko.region_enabled=true
	ko.region_rect=Rect2(0,0,112,96)
	ko.visible=false
	add_child(ko)

func _process(_delta: float) -> void:
	update_at(Time.get_ticks_msec()-started_at_msec)

func update_at(elapsed_ms: int) -> void:
	if cause==ConveyorPrototype.DeathCause.LEFT_OUT:
		captured.global_position=captured_origin+Vector2(0,64*clampf(elapsed_ms/160.0,0,1))
		if elapsed_ms>=160: captured.hide()
		return
	# OUT uses its captured pose inside the chute; unknown stays honest. Only
	# confirmed impacts use the authored KO, with no new collision or physics.
	if cause not in [ConveyorPrototype.DeathCause.FALLING_PRODUCT,ConveyorPrototype.DeathCause.BACKGROUND_PRODUCT,ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE]:
		return
	if elapsed_ms < HIT_STOP_MS:
		return
	captured.hide()
	ko.show()
	var remaining := elapsed_ms-HIT_STOP_MS
	frame_index=0
	while frame_index<FRAME_DURATIONS_MS.size()-1 and remaining>=FRAME_DURATIONS_MS[frame_index]:
		remaining-=FRAME_DURATIONS_MS[frame_index]
		frame_index+=1
	ko.region_rect.position.x=112*frame_index
