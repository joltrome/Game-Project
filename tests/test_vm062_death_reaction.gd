extends SceneTree
const SESSION := preload("res://scenes/presentation/standard_session.tscn")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1;push_error(message)
	else: print("PASS: ",message)
func run() -> void:
	var s:=SESSION.instantiate() as StandardSession
	s.auto_focus_pause_enabled=false
	s.score_storage_path="/tmp/vms-rc2-death.cfg"
	root.add_child(s)
	for cause in [ConveyorPrototype.DeathCause.FALLING_PRODUCT,ConveyorPrototype.DeathCause.BACKGROUND_PRODUCT,ConveyorPrototype.DeathCause.RETRIEVAL_CARRIAGE,ConveyorPrototype.DeathCause.LEFT_OUT,ConveyorPrototype.DeathCause.UNKNOWN]:
		s.start_game()
		var c:=s.game.conveyor
		var v:=s.game.v2_visual_integration
		var sprite:=v.technician_sprite()
		# Deliberately non-death, mirrored, airborne pose before the lethal signal.
		c.player.position=Vector2(440,310)
		v.technician_anchor().scale.x=-1
		sprite.play("jump")
		var texture:=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
		var pose:=sprite.global_transform
		c._kill_player(cause)
		var reaction:=s.death_reaction
		check(reaction!=null and reaction.captured.texture==texture and reaction.captured.global_transform==pose,"Captures live pose before old collapse selection")
		check(not sprite.visible and reaction.ko.scale==Vector2.ONE and reaction.ko.position==Vector2(-40,-88),"Exact native-size KO anchor; no duplicate player")
		var id:=reaction.get_instance_id()
		c._kill_player(ConveyorPrototype.DeathCause.UNKNOWN)
		check(s.death_reaction.get_instance_id()==id and reaction.cause==cause,"One reaction; first cause wins")
		await process_frame
		await process_frame
		var frozen:=[c.player.position,c.player.velocity,s.hud.round_controller.round_time_remaining,s.hud.coins.score]
		if cause in [ConveyorPrototype.DeathCause.LEFT_OUT,ConveyorPrototype.DeathCause.UNKNOWN]:
			reaction.update_at(500)
			check(not reaction.ko.visible,"OUT/unknown do not invent impact death")
		else:
			reaction.update_at(69)
			check(reaction.captured.visible and not reaction.ko.visible,"70ms captured-pose hit stop")
			for row in [[70,0],[129,0],[130,1],[199,1],[200,2],[279,2],[280,3],[359,3],[360,4],[489,4],[749,4]]:
				reaction.update_at(row[0])
				check(reaction.frame_index==row[1],"Authored frame boundary %d -> %d"%row)
		await create_timer(0.52).timeout
		check(s.state==StandardSession.State.DEATH_BEAT and reaction.can_process(),"KO processes independently of frozen run")
		check([c.player.position,c.player.velocity,s.hud.round_controller.round_time_remaining,s.hud.coins.score]==frozen,"Death presentation never mutates physics/time/score")
		while s.state==StandardSession.State.DEATH_BEAT: await process_frame
		var duration:=Time.get_ticks_msec()-reaction.started_at_msec
		check(duration>=750 and duration<900,"750ms result deadline: %dms"%duration)
		check(s.result_headline==StandardSession.headline_for(cause,false),"Cause headline preserved")
	s.show_menu();s.queue_free()
	await process_frame
	DirAccess.remove_absolute("/tmp/vms-rc2-death.cfg")
	print("VM062_DEATH_FAILURES=",failures)
	quit(failures)
