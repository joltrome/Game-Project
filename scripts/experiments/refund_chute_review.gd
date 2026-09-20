class_name RefundChuteReview
extends Control

const MOTION_SCENE := preload(
	"res://scenes/experiments/motion_vis04_pa_ca.tscn"
)
const PRODUCT_SCENE := preload("res://scenes/hazards/conveyor_product.tscn")

const CASE_NAMES := [
	"SHALLOW SINGLE",
	"MEDIUM SINGLE",
	"HIGH SINGLE",
	"SIMULTANEOUS DOUBLE",
	"STAGGERED DOUBLE",
	"STAGGERED TRIPLE",
	"SHORT-STAGGER DOUBLE",
	"CAN BOUNCE THEN SUPPORT",
	"SUPPORT LOSS TO BELT",
]

var shell: MotionExperimentShell
var director: CollectibleDirector
var _case_label: Label
var _event_cursor: int = 6100
var _review_can: ConveyorProduct


func _ready() -> void:
	shell = MOTION_SCENE.instantiate() as MotionExperimentShell
	shell.refund_chute_enabled = true
	shell.clean_tester_presentation = true
	shell.local_instrumentation_enabled = false
	shell.build_id_override = "VM-0.7.0-REFUND-SYSTEM-REVIEW"
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	director = shell.conveyor.get_node("CollectibleDirector") as CollectibleDirector
	director.ballistic_coin_events_enabled = true
	director.ballistic_abundance_enabled = true
	director.ballistic_integrity_enabled = true
	director.refund_chute_enabled = true
	director.refund_system_enabled = true
	director.static_teaching_coin_enabled = true
	director.set_process(false)
	shell.background_drop_director.set_process(false)
	shell.conveyor.set_process(false)
	shell.conveyor.set_physics_process(false)
	(shell.conveyor.get_node("RoundController") as FixedRoundController).set_process(false)
	shell.conveyor.player.set_physics_process(false)
	shell.conveyor.initial_warning_delay = 999.0
	shell.conveyor.left_failure_enabled = false
	_install_instructions()
	_launch_case(0)
	if "--autoplay" in OS.get_cmdline_user_args():
		call_deferred("_autoplay_cases")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		_launch_case(key_event.keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_R:
		_launch_case(0)
		get_viewport().set_input_as_handled()


func _install_instructions() -> void:
	var panel := ColorRect.new()
	panel.position = Vector2(18.0, 72.0)
	panel.size = Vector2(344.0, 58.0)
	panel.color = Color(0.02, 0.03, 0.06, 0.82)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 100
	add_child(panel)
	_case_label = Label.new()
	_case_label.position = Vector2(12.0, 7.0)
	_case_label.size = Vector2(320.0, 44.0)
	_case_label.text = "1–9: SELECT REVIEW CASE"
	_case_label.add_theme_font_size_override("font_size", 14)
	_case_label.add_theme_color_override("font_color", Color("f2e7c9"))
	panel.add_child(_case_label)


func _launch_case(case_index: int) -> void:
	if director == null:
		return
	case_index = clampi(case_index, 0, CASE_NAMES.size() - 1)
	_clear_coins()
	_clear_review_can()
	_event_cursor += 1
	var archetypes: Array[int] = []
	var relative_delays := PackedFloat32Array()
	match case_index:
		0:
			archetypes = [CollectibleDirector.BallisticArchetype.SHALLOW]
			relative_delays = PackedFloat32Array([0.0])
		1:
			archetypes = [CollectibleDirector.BallisticArchetype.MEDIUM]
			relative_delays = PackedFloat32Array([0.0])
		2:
			archetypes = [CollectibleDirector.BallisticArchetype.HIGH]
			relative_delays = PackedFloat32Array([0.0])
		3:
			archetypes = [
				CollectibleDirector.BallisticArchetype.SHALLOW,
				CollectibleDirector.BallisticArchetype.HIGH,
			]
			relative_delays = PackedFloat32Array([0.0, 0.0])
		4:
			archetypes = [
				CollectibleDirector.BallisticArchetype.SHALLOW,
				CollectibleDirector.BallisticArchetype.HIGH,
			]
			relative_delays = PackedFloat32Array([0.0, 0.18])
		5:
			archetypes = [
				CollectibleDirector.BallisticArchetype.SHALLOW,
				CollectibleDirector.BallisticArchetype.MEDIUM,
				CollectibleDirector.BallisticArchetype.HIGH,
			]
			relative_delays = PackedFloat32Array([0.0, 0.14, 0.28])
		6:
			archetypes = [
				CollectibleDirector.BallisticArchetype.SHALLOW,
				CollectibleDirector.BallisticArchetype.HIGH,
			]
			relative_delays = PackedFloat32Array([0.0, 0.09])
		_:
			archetypes = [CollectibleDirector.BallisticArchetype.MEDIUM]
			relative_delays = PackedFloat32Array([0.0])
			_review_can = _install_review_can(575.0)
	var physical_delays := PackedFloat32Array()
	for relative_delay in relative_delays:
		physical_delays.append(
			director.refund_chute_pre_eject_duration + relative_delay
		)
	var plans: Array[Dictionary] = []
	for member_index in range(archetypes.size()):
		var landing_x := (
			575.0
			if case_index >= 7
			else 430.0 + member_index * 145.0
		)
		var landing := Vector2(landing_x, director._ballistic_contact_y())
		var origin := director._refund_chute_origin_for_member(
			archetypes.size(),
			member_index,
			physical_delays
		)
		var plan := director._build_ballistic_plan(
			landing,
			archetypes[member_index],
			2.5,
			physical_delays[member_index],
			false,
			origin
		)
		plans.append(plan)
		var candidate := {
			"position": landing,
			"band": CollectibleDirector.PlacementBand.GROUND,
		}
		var sample := {
			"candidate": candidate,
			"effective_lifetime": 2.5,
			"ballistic_plan": plan,
			"reason": "",
			"attempts": 1,
		}
		director._try_spawn_independent_coin(
			"event",
			2.5,
			false,
			-1,
			[],
			_event_cursor,
			archetypes.size(),
			member_index,
			[],
			archetypes[member_index],
			[],
			physical_delays[member_index],
			sample
		)
	director._cue_refund_chute_from_plans(plans)
	_case_label.text = "%d — %s\nR: REPLAY / 1–9: SELECT" % [
		case_index + 1,
		CASE_NAMES[case_index],
	]
	if case_index == 8:
		_remove_review_can_after_delay(_event_cursor, 1.75)


func _clear_coins() -> void:
	for coin in director.active_collectibles():
		coin.free()
	director._refresh_active_offers()


func _install_review_can(x: float) -> ConveyorProduct:
	var product := PRODUCT_SCENE.instantiate() as ConveyorProduct
	product.position = Vector2(
		x,
		shell.conveyor.floor_y - shell.conveyor.landed_product_size.y * 0.5
	)
	product.configure_conveyor(
		0.0,
		shell.conveyor.floor_y,
		30.0,
		shell.conveyor.despawn_warning_duration,
		shell.conveyor.product_size,
		shell.conveyor.landed_product_size,
		shell.conveyor.conveyor_speed,
		shell.conveyor.offscreen_cleanup_x,
		shell.conveyor.effective_product_falling_collision_size()
	)
	product.landed.connect(shell.conveyor._on_product_landed)
	product.cleared.connect(shell.conveyor._on_product_cleared)
	shell.conveyor.get_node("Hazards").add_child(product)
	product._land()
	return product


func _clear_review_can() -> void:
	if not is_instance_valid(_review_can):
		_review_can = null
		return
	shell.conveyor._on_product_cleared(_review_can)
	_review_can.queue_free()
	_review_can = null
	director.invalidate_landed_can_collision_cache_for_test()


func _remove_review_can_after_delay(serial: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if serial != _event_cursor:
		return
	_clear_review_can()


func _autoplay_cases() -> void:
	for case_index in range(CASE_NAMES.size()):
		_launch_case(case_index)
		await get_tree().create_timer(2.0).timeout
	get_tree().quit()
