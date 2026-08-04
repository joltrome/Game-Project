extends SceneTree

const FLOW_SCENE_PATH := "res://scenes/playtest/playtest_flow.tscn"
const GAME_A_SCENE_PATH := "res://scenes/prototypes/arena.tscn"
const GAME_B_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const PROHIBITED_TERMS := [
	"arena",
	"conveyor",
	"prototype a",
	"prototype b",
]

var _failures: int = 0
var _session: PlaytestSessionController


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _run() -> void:
	_session = root.get_node("PlaytestSession") as PlaytestSessionController
	_check(_session != null, "Persistent playtest session controller is available")
	_test_configuration()
	await _test_order(
		"AB",
		PackedStringArray([GAME_A_SCENE_PATH, GAME_B_SCENE_PATH])
	)
	await _test_order(
		"BA",
		PackedStringArray([GAME_B_SCENE_PATH, GAME_A_SCENE_PATH])
	)
	print("PLAYTEST_DISTRIBUTION_TEST_FAILURES=%d" % _failures)
	quit(_failures)


func _test_configuration() -> void:
	_check(
		is_equal_approx(
			float(ProjectSettings.get_setting("playtest/game_duration_seconds")),
			60.0
		),
		"Both playtest orders use the same 60-second game duration"
	)
	_check(
		InputMap.has_action("begin_playtest")
		and not InputMap.action_get_events("begin_playtest").is_empty(),
		"Enter-to-begin action is configured"
	)
	_check(
		str(ProjectSettings.get_setting("application/run/main_scene"))
			== GAME_B_SCENE_PATH,
		"Normal editor F5 launch remains the current conveyor game"
	)
	_check(
		str(
			ProjectSettings.get_setting(
				"application/run/main_scene.playtest_ab"
			)
		) == FLOW_SCENE_PATH,
		"AB export feature overrides the main scene with the neutral flow"
	)
	_check(
		str(
			ProjectSettings.get_setting(
				"application/run/main_scene.playtest_ba"
			)
		) == FLOW_SCENE_PATH,
		"BA export feature overrides the main scene with the neutral flow"
	)

	var presets := ConfigFile.new()
	var load_error := presets.load("res://export_presets.cfg")
	_check(load_error == OK, "Web export presets parse successfully")
	if load_error != OK:
		return
	_check(
		presets.get_value("preset.0", "name") == "Web AB"
		and presets.get_value("preset.1", "name") == "Web BA"
		and presets.get_value("preset.2", "name") == "Web Current",
		"Archived AB and BA presets and standalone current preset exist"
	)
	_check(
		presets.get_value("preset.0", "custom_features") == "playtest_ab"
		and presets.get_value("preset.1", "custom_features") == "playtest_ba",
		"Each preset selects exactly one fixed order"
	)
	_check(
		not bool(
			presets.get_value("preset.0.options", "variant/thread_support")
		)
		and not bool(
			presets.get_value("preset.1.options", "variant/thread_support")
		)
		and not bool(
			presets.get_value("preset.2.options", "variant/thread_support")
		),
		"All Web presets explicitly disable thread support"
	)
	_check(
		presets.get_value("preset.0", "export_path")
			== "builds/web-ab/index.html"
		and presets.get_value("preset.1", "export_path")
			== "builds/web-ba/index.html",
		"Each preset exports index.html into its own directory"
	)
	_check(
		str(presets.get_value("preset.0", "exclude_filter"))
			.contains("builds/")
		and str(presets.get_value("preset.1", "exclude_filter"))
			.contains("builds/")
		and str(presets.get_value("preset.2", "exclude_filter"))
			.contains("builds/"),
		"Generated Web output is excluded from subsequent exports"
	)
	_check(
		str(presets.get_value("preset.2", "custom_features")).is_empty(),
		"Standalone preset does not select either comparison order"
	)
	_check(
		presets.get_value("preset.2", "export_path")
			== "builds/web-current/index.html",
		"Standalone preset exports index.html into its own directory"
	)
	_check(
		int(presets.get_value("preset.2.options", "html/canvas_resize_policy"))
			== 2,
		"Standalone Web canvas adapts to the available browser viewport"
	)


func _test_order(
	order_code: String,
	expected_paths: PackedStringArray
) -> void:
	_session.configure_for_test(order_code, 5.0)
	await _change_scene(FLOW_SCENE_PATH)
	var intro := current_scene
	_check(
		_session.ordered_scene_paths() == expected_paths,
		"%s order is fixed before tester input" % order_code
	)
	_check(
		_visible_text(intro).contains("CLICK TO FOCUS")
		and _visible_text(intro).contains("ARROW KEYS: MOVE")
		and _visible_text(intro).contains("SPACE: JUMP")
		and _visible_text(intro).contains("PRESS ENTER TO BEGIN"),
		"%s introduction shows the shared focus and input instructions"
		% order_code
	)
	_check(
		not _visible_text_has_prohibited_term(intro),
		"%s introduction does not reveal internal prototype names"
		% order_code
	)

	_check(_session.advance_from_screen(), "%s begins Game 1" % order_code)
	await scene_changed
	await process_frame
	await _check_game_scene(order_code, 1, expected_paths[0])
	await _check_restart_preserves_session(order_code, 1)

	_check(
		_session.force_finish_current_game_for_test(),
		"%s Game 1 can reach the neutral transition" % order_code
	)
	await scene_changed
	await process_frame
	var transition := current_scene
	_check(
		_visible_text(transition).contains("GAME 1 COMPLETE")
		and _visible_text(transition).contains(
			"PRESS ENTER WHEN READY FOR GAME 2"
		),
		"%s transition appears between the two games" % order_code
	)
	_check(
		not _visible_text_has_prohibited_term(transition),
		"%s transition remains structurally neutral" % order_code
	)

	_check(_session.advance_from_screen(), "%s begins Game 2" % order_code)
	await scene_changed
	await process_frame
	await _check_game_scene(order_code, 2, expected_paths[1])
	await _check_restart_preserves_session(order_code, 2)

	_check(
		_session.force_finish_current_game_for_test(),
		"%s Game 2 can reach completion" % order_code
	)
	await scene_changed
	await process_frame
	var completion := current_scene
	_check(
		_visible_text(completion).contains("SESSION COMPLETE")
		and _visible_text(completion).contains(
			"PLEASE NOTIFY THE MODERATOR."
		),
		"%s completion tells the tester to notify the moderator"
		% order_code
	)
	_check(
		not _visible_text_has_prohibited_term(completion),
		"%s completion remains structurally neutral" % order_code
	)


func _check_game_scene(
	order_code: String,
	game_number: int,
	expected_path: String
) -> void:
	_check(
		current_scene.scene_file_path == expected_path,
		"%s Game %d launches the expected frozen scene"
		% [order_code, game_number]
	)
	_check(
		_session.current_game_number() == game_number,
		"%s session identifies Game %d" % [order_code, game_number]
	)
	var build_label := current_scene.get_node_or_null("HUD/BuildId") as Label
	_check(
		build_label != null
		and build_label.text
			== "BUILD VM-EXT-%s · GAME %d" % [order_code, game_number],
		"%s Game %d has its neutral order-aware build ID"
		% [order_code, game_number]
	)
	_check(
		not _visible_text_has_prohibited_term(current_scene),
		"%s Game %d tester-facing text hides internal prototype names"
		% [order_code, game_number]
	)
	if "survival_time" in current_scene:
		_check(
			float(current_scene.survival_time) < 0.2,
			"%s Game %d starts with a reset gameplay timer"
			% [order_code, game_number]
		)
	if "is_dead" in current_scene:
		_check(
			not bool(current_scene.is_dead),
			"%s Game %d starts alive" % [order_code, game_number]
		)


func _check_restart_preserves_session(
	order_code: String,
	game_number: int
) -> void:
	await process_frame
	await process_frame
	var old_instance_id := current_scene.get_instance_id()
	var remaining_before := _session.game_time_remaining()
	var reload_error := reload_current_scene()
	_check(
		reload_error == OK,
		"%s Game %d accepts the same-scene restart path"
		% [order_code, game_number]
	)
	await scene_changed
	await process_frame
	_check(
		current_scene.get_instance_id() != old_instance_id
		and _session.session_state()
			== PlaytestSessionController.SessionState.GAME
		and _session.current_game_number() == game_number,
		"%s Game %d restart reloads gameplay without changing session order"
		% [order_code, game_number]
	)
	_check(
		_session.game_time_remaining() <= remaining_before
		and _session.game_time_remaining()
			< _session.game_duration_seconds(),
		"%s Game %d restart does not reset the distribution timer"
		% [order_code, game_number]
	)


func _change_scene(scene_path: String) -> void:
	var error := change_scene_to_file(scene_path)
	_check(error == OK, "Scene change request succeeds for %s" % scene_path)
	if error == OK:
		await scene_changed
		await process_frame


func _visible_text(scene: Node) -> String:
	return "\n".join(_session.visible_texts(scene))


func _visible_text_has_prohibited_term(scene: Node) -> bool:
	var normalized := _visible_text(scene).to_lower()
	for term in PROHIBITED_TERMS:
		if normalized.contains(term):
			return true
	return false
