extends SceneTree

const SESSION_SCENE := preload("res://scenes/presentation/standard_session.tscn")
const SCORE := preload("res://scripts/presentation/overload_score.gd")
const EMERGENCY := preload("res://scripts/experiments/overload_emergency_visual.gd")
const SCORE_PATH := "/tmp/vms-vm081-standard-score.cfg"
const AUDIO_PATH := "/tmp/vms-vm081-audio.cfg"
const OVERLOAD_PATH := "/tmp/vms-vm081-overload-record.cfg"

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func run() -> void:
	root.size = Vector2i(1152,648)
	for path in [SCORE_PATH,AUDIO_PATH,OVERLOAD_PATH]: DirAccess.remove_absolute(path)
	await _test_mode_score_visuals_and_electric_contract()
	_test_score_and_stage_boundaries()
	for path in [SCORE_PATH,AUDIO_PATH,OVERLOAD_PATH]: DirAccess.remove_absolute(path)
	print("VM081_OVERLOAD_REWORK_FAILURES=",failures)
	quit(failures)


func _test_mode_score_visuals_and_electric_contract() -> void:
	var session := SESSION_SCENE.instantiate() as StandardSession
	session.score_storage_path=SCORE_PATH
	session.audio_settings_path=AUDIO_PATH
	session.overload_storage_path=OVERLOAD_PATH
	root.add_child(session)
	await process_frame
	(session._c2.get_node("clock_in") as Button).pressed.emit()
	await process_frame
	check(not session._c2.show_menu_static_lettering, "Mode Select suppresses stale Main Menu control and record lettering")
	for key in ["standard","overload","back"]:
		var button := session._c2.get_node(key) as Button
		check(button != null and button.get_node("Artwork").texture != null, "%s uses authored state artwork rather than a generic control" % key)
	(session._c2.get_node("overload") as Button).pressed.emit()
	await process_frame
	await physics_frame
	check(session.hud.score_label.text=="SCORE" and session.hud.survival_label.text=="SURVIVAL" and session.hud.refund_label.text=="REFUNDS", "Active Overload HUD exposes only current Score, Survival and Refund metrics")
	check(session.game.overload_emergency_visual != null and session.game.overload_visual_stage_name()=="UNSTABLE", "Overload begins in reset UNSTABLE visual state")
	var conveyor := session.game.conveyor
	var visual := session.game.v2_visual_integration
	check(conveyor.sweeper_size==Vector2(96,28) and is_equal_approx(conveyor.sweeper_altitude,518.0) and is_equal_approx(conveyor.sweeper_entry_cue_duration,0.20), "Electrical replacement preserves frozen 96x28, y518 and 200ms mechanics")
	conveyor._start_sweeper_entry_cue()
	var cue := conveyor.get_node("SweeperEntry/V2CarriageTelegraph") as AnimatedSprite2D
	check(cue.animation==&"charge" and cue.scale==Vector2.ONE and cue.sprite_frames.get_frame_texture(&"charge",0).get_size()==Vector2(96,28), "Electrical warning maps to approved full-resolution charge art without collision")
	var sweeper := conveyor._spawn_sweeper()
	await process_frame
	check(sweeper != null, "Electrical fixture creates one existing Sweeper actor")
	var electric := visual.carriage_sprite(sweeper)
	var shape := sweeper.get_node("CollisionShape2D") as CollisionShape2D
	check(electric.animation==&"standard" and electric.scale==Vector2.ONE and (shape.shape as RectangleShape2D).size==Vector2(96,28), "Moving electrical art aligns one-to-one with unchanged lethal collider")
	sweeper.position.x=sweeper.exit_x-sweeper.hazard_size.x
	visual._update_carriage_visual_states()
	check(electric.animation==&"live_exit" and electric.sprite_frames.get_frame_texture(&"live_exit",0).get_size()==Vector2(96,28), "Lethal exit retains the complete 96x28 danger envelope until actual clearance")
	check(StandardSession.headline_for(ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE,false)=="FRIED.", "Electrical contact maps to FRIED. and no longer reports GRABBED.")
	session._show_results(0,false)
	await process_frame
	check(not session._c2.show_result_static_lettering, "Overload Results suppress stale Standard metric lettering")
	session.show_menu()
	await process_frame
	(session._c2.get_node("clock_in") as Button).pressed.emit()
	await process_frame
	(session._c2.get_node("standard") as Button).pressed.emit()
	await process_frame
	await physics_frame
	check(not session.game.overload_mode_enabled and session.game.overload_emergency_visual==null and session.game.v2_visual_integration.vm081_electrical_enabled, "Standard receives only the presentation replacement and no Overload emergency state")
	session.queue_free()
	await process_frame


func _test_score_and_stage_boundaries() -> void:
	check(SCORE.calculate(76.42,37)==16892 and SCORE.calculate(-1.0,-2)==0, "Combined Score is deterministic, integer-stable and clamps invalid negative inputs")
	var visual := EMERGENCY.new() as OverloadEmergencyVisual
	check(visual.stage_at(0.0)==OverloadEmergencyVisual.Stage.UNSTABLE and visual.stage_at(14.999)==OverloadEmergencyVisual.Stage.UNSTABLE, "UNSTABLE covers 0 through under 15 seconds")
	check(visual.stage_at(15.0)==OverloadEmergencyVisual.Stage.WARNING and visual.stage_at(29.999)==OverloadEmergencyVisual.Stage.WARNING, "WARNING activates exactly at 15 seconds")
	check(visual.stage_at(30.0)==OverloadEmergencyVisual.Stage.CRITICAL and visual.stage_at(89.999)==OverloadEmergencyVisual.Stage.CRITICAL, "CRITICAL activates exactly at 30 seconds and spans the severe 60-90 rhythm")
	check(visual.stage_at(90.0)==OverloadEmergencyVisual.Stage.MAX and visual.stage_at(9999.0)==OverloadEmergencyVisual.Stage.MAX, "MAX activates at 90 seconds and remains bounded")
	visual.free()
