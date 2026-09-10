extends SceneTree
const SESSION:=preload("res://scenes/presentation/standard_session.tscn")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1;push_error(message)
	else: print("PASS: ",message)
func run() -> void:
	var s:=SESSION.instantiate() as StandardSession
	s.auto_focus_pause_enabled=false
	s.score_storage_path="/tmp/vms-rc2-contact-test.cfg"
	root.add_child(s)
	for source in ["ordinary","d3"]:
		s.start_game()
		var c:=s.game.conveyor
		c.set_physics_process(false)
		c.left_failure_enabled=false
		s.game.background_drop_director.set_process(false)
		s.hud.round_controller.set_process(false)
		s.hud.coins.set_process(false)
		c.player.set_physics_process(false)
		c.player.position=Vector2(100,250)
		var p: ConveyorProduct=c.force_drop_for_test(0) if source=="ordinary" else c.spawn_external_conveyor_product(640,c.product_spawn_y,0.85,"contact-test")
		p.landed_lifetime=20
		p.position.y=p.floor_y-p.falling_size.y/2-1
		p.fall_speed=120
		for i in 12: await physics_frame
		while p.conveyor_center_x()>640: await physics_frame
		var shape:=p.get_node("LandedBody/CollisionShape2D") as CollisionShape2D
		var art:=s.game.v2_visual_integration.product_landed_sprite(p)
		check((shape.shape as RectangleShape2D).size==Vector2(72,48),source+" frozen support size")
		check(shape.global_position.y-24==540 and art.global_position.y==560 and shape.position.y==4,source+" support top matches settled ink top")
		var player_shape:=c.player.get_node("CollisionShape2D") as CollisionShape2D
		check((player_shape.shape as RectangleShape2D).size==Vector2(32,48),"Player hurtbox unchanged")
		c.player.position=Vector2(p.conveyor_center_x(),514)
		c.player.velocity=Vector2.ZERO
		c.player.set_physics_process(true)
		for i in 25: await physics_frame
		check(c.player.is_on_floor() and absf(c.player.position.y+24-540)<0.1,source+" boots stand on visible surface")
		var before_x:=c.player.position.x
		for i in 10: await physics_frame
		check(c.player.position.x<before_x and absf(c.player.position.y+24-540)<0.1,source+" moving conveyor support retains contact")
		Input.action_press("jump")
		await physics_frame
		await physics_frame
		Input.action_release("jump")
		check(c.player.velocity.y<0,source+" can remains jumpable")
		# Follow the moving platform horizontally in the fixture during a real
		# unchanged jump arc, then verify downward landing on its solid surface.
		for i in 60:
			c.player.position.x=p.conveyor_center_x()
			await physics_frame
			if c.player.is_on_floor() and i>5: break
		check(c.player.is_on_floor() and absf(c.player.position.y+24-540)<0.1,source+" downward jump lands on can")
		Input.action_press("move_right")
		for i in 22: await physics_frame
		Input.action_release("move_right")
		for i in 24: await physics_frame
		print("WALK STATE ",c.player.position," dead=",c.is_dead," cause=",c.death_cause," velocity=",c.player.velocity)
		check(c.player.is_on_floor() and absf(c.player.position.y+24-c.floor_y)<0.1,source+" walks off to unchanged conveyor contact")
		var second:=c.spawn_external_conveyor_product(620,c.product_spawn_y,0.85,"second-contact")
		if second==null: continue
		second.position.y=second.floor_y-second.falling_size.y/2-1
		second.fall_speed=120
		for i in 12: await physics_frame
		check(c.active_landed_products().size()>=2 and (second.get_node("LandedBody/CollisionShape2D") as CollisionShape2D).global_position.y-24==540,"Multiple landed sources share physical top")
	s.show_menu();s.queue_free()
	await process_frame
	print("VM062_CONTACT_FAILURES=",failures)
	quit(failures)
