class_name PlaytestSessionController
extends Node

signal session_state_changed(state: int)
signal game_started(order_code: String, game_number: int, scene_path: String)
signal game_finished(order_code: String, game_number: int)

enum SessionState {
	INTRO,
	GAME,
	TRANSITION,
	COMPLETE,
}

const FLOW_SCENE_PATH := "res://scenes/playtest/playtest_flow.tscn"
const GAME_A_SCENE_PATH := "res://scenes/prototypes/arena.tscn"
const GAME_B_SCENE_PATH := "res://scenes/prototypes/conveyor.tscn"
const PROHIBITED_TESTER_TERMS := [
	"arena",
	"conveyor",
	"prototype a",
	"prototype b",
]

var _order_code: String = "AB"
var _ordered_scene_paths := PackedStringArray([
	GAME_A_SCENE_PATH,
	GAME_B_SCENE_PATH,
])
var _state: SessionState = SessionState.INTRO
var _current_game_index: int = -1
var _game_duration_seconds: float = 60.0
var _game_time_remaining: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game_duration_seconds = float(
		ProjectSettings.get_setting(
			"playtest/game_duration_seconds",
			60.0
		)
	)
	_set_order(_detect_export_order())
	get_tree().scene_changed.connect(_on_scene_changed)


func _process(delta: float) -> void:
	if _state != SessionState.GAME:
		return
	if not _current_scene_matches_game():
		return
	_game_time_remaining = maxf(_game_time_remaining - delta, 0.0)
	if _game_time_remaining <= 0.0:
		_finish_current_game()


func advance_from_screen() -> bool:
	match _state:
		SessionState.INTRO:
			_current_game_index = 0
			return _start_current_game()
		SessionState.TRANSITION:
			_current_game_index = 1
			return _start_current_game()
	return false


func order_code() -> String:
	return _order_code


func session_state() -> SessionState:
	return _state


func session_state_name() -> String:
	match _state:
		SessionState.INTRO:
			return "INTRO"
		SessionState.GAME:
			return "GAME"
		SessionState.TRANSITION:
			return "TRANSITION"
		SessionState.COMPLETE:
			return "COMPLETE"
	return "UNKNOWN"


func current_game_number() -> int:
	return _current_game_index + 1 if _current_game_index >= 0 else 0


func current_game_scene_path() -> String:
	if (
		_current_game_index < 0
		or _current_game_index >= _ordered_scene_paths.size()
	):
		return ""
	return _ordered_scene_paths[_current_game_index]


func ordered_scene_paths() -> PackedStringArray:
	return _ordered_scene_paths.duplicate()


func game_duration_seconds() -> float:
	return _game_duration_seconds


func game_time_remaining() -> float:
	return _game_time_remaining


func neutral_build_id() -> String:
	if _state == SessionState.GAME:
		return "BUILD VM-EXT-%s · GAME %d" % [
			_order_code,
			current_game_number(),
		]
	return "BUILD VM-EXT-%s" % _order_code


func configure_for_test(
	requested_order: String,
	duration_seconds: float = 60.0
) -> void:
	_set_order(requested_order)
	_game_duration_seconds = maxf(duration_seconds, 0.05)
	_state = SessionState.INTRO
	_current_game_index = -1
	_game_time_remaining = 0.0
	session_state_changed.emit(_state)


func force_finish_current_game_for_test() -> bool:
	if _state != SessionState.GAME:
		return false
	_finish_current_game()
	return true


func visible_text_contains_prohibited_term(scene: Node) -> bool:
	for text in visible_texts(scene):
		var normalized := text.to_lower()
		for term in PROHIBITED_TESTER_TERMS:
			if normalized.contains(term):
				return true
	return false


func visible_texts(scene: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	if scene == null:
		return texts
	_collect_visible_text(scene, texts)
	return texts


func _collect_visible_text(node: Node, texts: PackedStringArray) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		texts.append((node as Label).text)
	elif node is Button:
		texts.append((node as Button).text)
	for child in node.get_children():
		_collect_visible_text(child, texts)


func _detect_export_order() -> String:
	if OS.has_feature("playtest_ba"):
		return "BA"
	if OS.has_feature("playtest_ab"):
		return "AB"
	for argument in OS.get_cmdline_user_args():
		var normalized := argument.strip_edges().to_upper()
		if normalized in ["BA", "--PLAYTEST-ORDER=BA"]:
			return "BA"
		if normalized in ["AB", "--PLAYTEST-ORDER=AB"]:
			return "AB"
	return "AB"


func _set_order(requested_order: String) -> void:
	_order_code = "BA" if requested_order.to_upper() == "BA" else "AB"
	_ordered_scene_paths = (
		PackedStringArray([GAME_B_SCENE_PATH, GAME_A_SCENE_PATH])
		if _order_code == "BA"
		else PackedStringArray([GAME_A_SCENE_PATH, GAME_B_SCENE_PATH])
	)


func _start_current_game() -> bool:
	var scene_path := current_game_scene_path()
	if scene_path.is_empty():
		return false
	_state = SessionState.GAME
	_game_time_remaining = _game_duration_seconds
	session_state_changed.emit(_state)
	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error(
			"Could not start playtest game %d (error %s)."
			% [current_game_number(), change_error]
		)
		return false
	return true


func _finish_current_game() -> void:
	var finished_game_number := current_game_number()
	game_finished.emit(_order_code, finished_game_number)
	_state = (
		SessionState.TRANSITION
		if _current_game_index == 0
		else SessionState.COMPLETE
	)
	_game_time_remaining = 0.0
	session_state_changed.emit(_state)
	var change_error := get_tree().change_scene_to_file(FLOW_SCENE_PATH)
	if change_error != OK:
		push_error(
			"Could not open the playtest interstitial (error %s)."
			% change_error
		)


func _current_scene_matches_game() -> bool:
	var scene := get_tree().current_scene
	return (
		scene != null
		and scene.scene_file_path == current_game_scene_path()
	)


func _on_scene_changed() -> void:
	if _state != SessionState.GAME:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != current_game_scene_path():
		return
	_apply_neutral_game_labels(scene)
	game_started.emit(
		_order_code,
		current_game_number(),
		scene.scene_file_path
	)


func _apply_neutral_game_labels(scene: Node) -> void:
	var build_label := scene.get_node_or_null("HUD/BuildId") as Label
	if build_label != null:
		build_label.text = neutral_build_id()

	var controls_label := scene.get_node_or_null("HUD/Controls") as Label
	if controls_label != null:
		controls_label.text = (
			"MOVE: ←/→    JUMP: SPACE    RESTART: R"
		)

	var structural_hint := scene.get_node_or_null("HUD/Hypothesis") as Label
	if structural_hint != null:
		structural_hint.visible = false

	var machine_label := (
		scene.get_node_or_null("SourceRack/MachineLabel") as Label
	)
	if machine_label != null:
		machine_label.text = "VENDING DROP RACK"
