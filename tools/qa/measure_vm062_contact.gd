extends SceneTree
const SESSION := preload("res://scenes/presentation/standard_session.tscn")
var session: StandardSession
var measurements: Array[Dictionary] = []
var tag := "before"

class ContactOverlay extends Node2D:
	var rectangles: Array[Rect2] = []
	func _draw() -> void:
		var colors := [Color.CYAN,Color.RED,Color.YELLOW,Color.GREEN]
		for i in rectangles.size():
			draw_rect(rectangles[i],colors[i],false,1)

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty(): tag=OS.get_cmdline_user_args()[0]
	call_deferred("run")

func ink_rect(sprite: AnimatedSprite2D) -> Rect2:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	var used := Rect2(texture.get_image().get_used_rect())
	var origin := sprite.offset - (Vector2(texture.get_size())/2 if sprite.centered else Vector2.ZERO)
	return sprite.global_transform * Rect2(origin+used.position,used.size)

func shape_rect(shape: CollisionShape2D) -> Rect2:
	var dimensions := (shape.shape as RectangleShape2D).size
	return shape.global_transform * Rect2(-dimensions/2,dimensions)

func capture(label: String, product: ConveyorProduct = null) -> void:
	var c := session.game.conveyor
	var visual := session.game.v2_visual_integration
	var boots := ink_rect(visual.technician_sprite())
	var body := shape_rect(c.player.get_node("CollisionShape2D"))
	var row := {"case":label,"grounded":c.player.is_on_floor(),"boot_bottom_y":boots.end.y,"player_collider_bottom_y":body.end.y,"visual_anchor_y":visual.technician_anchor().global_position.y,"floor_contact_y":c.floor_y,"player_collider_size":body.size,"last_floor_normal":c.player.get_floor_normal()}
	var overlay := ContactOverlay.new()
	overlay.z_index=100
	overlay.rectangles=[boots,body]
	if product != null:
		var art := ink_rect(visual.product_landed_sprite(product))
		var collision := shape_rect(product.get_node("LandedBody/CollisionShape2D"))
		row.merge({"can_visible_top_y":art.position.y,"can_visible_bottom_y":art.end.y,"can_collider_top_y":collision.position.y,"can_collider_bottom_y":collision.end.y,"can_collider_size":collision.size,"can_sprite_offset":visual.product_landed_sprite(product).position,"can_body_y":product.get_node("LandedBody").global_position.y,"gap":art.position.y-boots.end.y})
		overlay.rectangles.append(art);overlay.rectangles.append(collision)
	else:
		row["gap"]=c.floor_y-boots.end.y
	measurements.append(row)
	print(JSON.stringify(row))
	c.add_child(overlay)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/validation-vm062/contact/%s-%s.png" % [tag,label])
	overlay.queue_free()

func run() -> void:
	auto_accept_quit=false
	root.size=Vector2i(1152,648)
	DirAccess.make_dir_recursive_absolute("res://builds/validation-vm062/contact")
	session=SESSION.instantiate()
	session.score_storage_path="/tmp/vms-vm062-contact.cfg"
	session.auto_focus_pause_enabled=false
	root.add_child(session)
	session.audio.music.volume_db=-80
	session.start_game()
	if tag=="before": session.game.v2_visual_integration.landed_contact_offset_y=0.0
	var c := session.game.conveyor
	c.set_process(false)
	c.left_failure_enabled=false
	session.game.background_drop_director.set_process(false)
	c.get_node("RoundController").set_process(false)
	c.get_node("CollectibleDirector").set_process(false)
	for i in 45: await physics_frame
	await capture("conveyor")
	for source in ["ordinary","d3"]:
		session.start_game()
		if tag=="before": session.game.v2_visual_integration.landed_contact_offset_y=0.0
		c=session.game.conveyor
		c.set_process(false)
		c.left_failure_enabled=false
		session.game.background_drop_director.set_process(false)
		c.get_node("RoundController").set_process(false)
		c.get_node("CollectibleDirector").set_process(false)
		c.player.set_physics_process(false)
		c.player.position=Vector2(1000,300)
		var product: ConveyorProduct
		if source == "ordinary":
			product=c.force_drop_for_test(0)
		else: product=c.spawn_external_conveyor_product(640,c.product_spawn_y,0.85,"RC2-contact")
		product.landed_lifetime=8.0
		product.position.y=product.floor_y-product.falling_size.y/2-1
		product.fall_speed=120
		for i in 12: await physics_frame
		# The ordinary source starts beyond the frozen control-band right edge.
		# Let the real belt carry it into reachable space before placing the fixture.
		while product.conveyor_center_x()>640: await physics_frame
		var platform := shape_rect(product.get_node("LandedBody/CollisionShape2D"))
		c.player.position=Vector2(platform.get_center().x,platform.position.y-26)
		c.player.velocity=Vector2.ZERO
		c.player.set_physics_process(true)
		for i in 25: await physics_frame
		await capture(source,product)
		product.queue_free()
		await process_frame
	var file := FileAccess.open("res://builds/validation-vm062/contact/%s.json" % tag,FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"  ")+"\n")
	file.close()
	session.queue_free()
	await process_frame
	quit()
