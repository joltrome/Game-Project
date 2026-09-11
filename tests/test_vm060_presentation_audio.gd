extends SceneTree

const SESSION := preload("res://scenes/presentation/standard_session.tscn")
const SAVE_PATH := "/tmp/vms-vm060-test-best.cfg"
var failures: int = 0
var events: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_test_storage()
	DirAccess.remove_absolute(SAVE_PATH)
	var session := SESSION.instantiate() as StandardSession
	session.score_storage_path = SAVE_PATH
	root.add_child(session)
	await process_frame
	check(session.state == StandardSession.State.MENU and session.game == null, "Launch enters menu with no gameplay instance")
	for i in 90:
		await process_frame
	check(session.game == null, "Menu never starts a hidden timer or hazard director")
	var audio_id := session.audio.music.get_instance_id()
	session.audio.sfx_requested.connect(func(event: StringName) -> void: events.append(event))
	check(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0, "Music and SFX buses exist")
	check(session.audio.music.bus == &"Music" and session.audio.sfx.bus == &"SFX", "Players route to their respective buses")
	check((session.audio.music.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "Accepted original master loops natively")
	session.audio.set_muted(&"Music", true)
	session.audio.set_muted(&"SFX", true)
	check(session.audio.is_muted(&"Music") and session.audio.is_muted(&"SFX"), "Independent mute controls reach both buses")
	var steady_node_count := 0
	for cycle in 12:
		session.start_game()
		await process_frame
		var game := session.game
		var conveyor := game.conveyor
		var round_controller := conveyor.get_node("RoundController") as FixedRoundController
		var coins := conveyor.get_node("CollectibleDirector") as CollectibleDirector
		check(session.state == StandardSession.State.GAME and round_controller.round_time_remaining > 59.9 and coins.score == 0 and not conveyor.is_dead, "Retry %d starts clean score, player and timer" % cycle)
		check(conveyor.get_node("Hazards").get_child_count() == 0 and coins.active_collectible_count() == 0 and coins.pending_staggered_coin_count() == 0 and conveyor.survival_time < 0.1, "Retry %d has no stale hazards, offers or director time" % cycle)
		check(not game.debug_overlay_toggle_allowed and game.instrumentation == null and not conveyor.get_node("HUD/BuildId").visible and not conveyor.get_node("HUD/ExperimentId").visible, "Normal session suppresses internal labels and F8")
		if cycle == 0:
			steady_node_count = get_node_count()
		else:
			check(get_node_count() == steady_node_count, "Retry %d retains a constant fresh-run node count" % cycle)
		# Use a real spawned collectible and its normal exactly-once pickup callback.
		coins.try_spawn_band_for_test(CollectibleDirector.PlacementBand.GROUND)
		var coin := coins.active_collectible()
		if coin != null:
			coin._on_body_entered(conveyor.player)
		check(coins.score == 1, "A real pickup scores once")
		conveyor._kill_player()
		await create_timer(StandardSession.DEATH_BEAT_SECONDS + 0.08).timeout
		check(session.state == StandardSession.State.RESULTS and session.result_headline == "GAME OVER." and session.result_score.text == "01", "Death result shows actual run score")
		var frozen_time := round_controller.round_time_remaining
		for i in 5:
			await process_frame
		check(round_controller.round_time_remaining == frozen_time and game.process_mode == Node.PROCESS_MODE_DISABLED, "Results freeze the entire run")
		check(
			session.audio.music.get_instance_id() == audio_id
			and not session.audio.music.playing
			and session.audio.sfx_player_count() == 12
			and session.audio.get_child_count() == 14,
			"Retry lifecycle preserves one stopped music instance, one delay timer, and the fixed SFX pool"
		)
		check(session.audio.is_muted(&"Music") and session.audio.is_muted(&"SFX"), "Mute survives run/results transitions")
		if cycle % 4 == 3:
			session.show_menu()
			await process_frame
			check(session.game == null and not is_instance_valid(game), "Menu return destroys the complete previous run")
	# Exercise the original round controller for all 60 seconds in an isolated
	# completion harness. Player collision/motion are isolated only here, never production.
	session.start_game()
	var completion_game := session.game
	var completion_round := completion_game.conveyor.get_node("RoundController") as FixedRoundController
	completion_game.background_drop_director.configure_schedule_seed(5002)
	completion_game.conveyor.left_failure_enabled = false
	completion_game.conveyor.player.collision_layer = 0
	completion_game.conveyor.player.set_physics_process(false)
	completion_game.conveyor.player.position = Vector2(640, 420)
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 12.0
	while session.state == StandardSession.State.GAME:
		await physics_frame
	Engine.time_scale = previous_time_scale
	check(completion_game.background_drop_director.released_event_count() == 6, "Presentation wrapper preserves six natural D3 releases over the complete round")
	check(events.has(&"rack_warning") and events.has(&"rack_release") and events.has(&"product_impact") and not events.has(&"carriage_warning") and events.has(&"carriage_sweep") and events.has(&"final_seconds"), "Natural round retains passive hazard events while carriage warning audio stays removed")
	check(session.state == StandardSession.State.RESULTS and session.last_survived and session.result_headline == "CLOCKED OUT." and completion_round.completion_count == 1, "Original controller reaches distinct success at 60 seconds exactly once")
	check(session.scores.best_score == 1 and session.best_label.text == "01", "Lower completion score preserves earlier best")
	check(
		events.has(&"coin_pickup")
		and events.has(&"round_complete")
		and events.has(&"clock_in_confirm")
		and events.has(&"ui_back"),
		"Pickup, completion, CLOCK IN and navigation reach the SFX event seam"
	)
	session.show_menu()
	session.audio.set_muted(&"Music", false)
	session.audio.set_muted(&"SFX", false)
	check(not session.audio.is_muted(&"Music") and not session.audio.is_muted(&"SFX"), "Both buses unmute independently")
	session.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	print("VM060_PRESENTATION_AUDIO_FAILURES=%d" % failures)
	quit(failures)


func _test_storage() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	var store := StandardScoreStore.new()
	store.storage_path = SAVE_PATH
	check(store.load_best() == 0, "Missing save initializes safely")
	check(store.record_score(12) and store.last_storage_error == OK, "Higher score writes successfully")
	var reopened := StandardScoreStore.new()
	reopened.storage_path = SAVE_PATH
	check(reopened.load_best() == 12, "Best score persists across store instances")
	check(not reopened.record_score(4) and reopened.load_best() == 12, "Lower score cannot overwrite best")
	var config := ConfigFile.new()
	config.set_value("standard", "best_score", "invalid")
	config.save(SAVE_PATH)
	check(reopened.load_best() == 0, "Malformed score type falls back to zero")
	config.set_value("standard", "best_score", -17)
	config.save(SAVE_PATH)
	check(reopened.load_best() == 0, "Negative stored score falls back to zero")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("[broken")
	file.close()
	check(reopened.load_best() == 0, "Corrupt config fails safely")
	reopened.storage_path = "/tmp/vms-missing-dir-vm060/best.cfg"
	check(reopened.record_score(7) and reopened.best_score == 7 and reopened.last_storage_error != OK, "Unavailable storage retains in-session best without blocking play")
