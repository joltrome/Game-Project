class_name OverloadRecordStore
extends RefCounted

const SCORE := preload("res://scripts/presentation/overload_score.gd")

var storage_path: String = "user://overload_best.cfg"
var best_survival_seconds: float = 0.0
var best_refunds: int = 0
var best_score: int = 0
var has_best_score: bool = false
var last_storage_error: Error = OK


func load_bests() -> void:
	best_survival_seconds = 0.0
	best_refunds = 0
	best_score = 0
	has_best_score = false
	var config := ConfigFile.new()
	last_storage_error = config.load(storage_path)
	if last_storage_error != OK:
		return
	var stored_time: Variant = config.get_value("overload", "best_survival_seconds", 0.0)
	var stored_refunds: Variant = config.get_value("overload", "best_refunds", 0)
	var stored_formula: String = str(config.get_value("overload", "score_formula_id", ""))
	var stored_score: Variant = config.get_value("overload", "best_score", 0)
	if (stored_time is float or stored_time is int) and float(stored_time) >= 0.0:
		best_survival_seconds = float(stored_time)
	if stored_refunds is int and stored_refunds >= 0:
		best_refunds = stored_refunds
	# VM-0.8.0's independent raw records can originate from different runs. They
	# are deliberately retained but never combined into a fictional score.
	if stored_formula == SCORE.FORMULA_ID and stored_score is int and stored_score >= 0:
		best_score = stored_score
		has_best_score = true


func record_run(survival_seconds: float, refunds: int, score: int = -1) -> bool:
	var storage_changed := false
	var score_improved := false
	if survival_seconds > best_survival_seconds:
		best_survival_seconds = survival_seconds
		storage_changed = true
	if refunds > best_refunds:
		best_refunds = refunds
		storage_changed = true
	if score >= 0 and (not has_best_score or score > best_score):
		best_score = score
		has_best_score = true
		score_improved = true
		storage_changed = true
	if not storage_changed:
		return false
	var config := ConfigFile.new()
	config.set_value("overload", "best_survival_seconds", best_survival_seconds)
	config.set_value("overload", "best_refunds", best_refunds)
	if has_best_score:
		config.set_value("overload", "best_score", best_score)
		config.set_value("overload", "score_formula_id", SCORE.FORMULA_ID)
	last_storage_error = config.save(storage_path)
	return score_improved


static func format_survival_time(survival_seconds: float) -> String:
	var total_centiseconds := maxi(floori(maxf(survival_seconds, 0.0) * 100.0), 0)
	var minutes := floori(float(total_centiseconds) / 6000.0)
	var seconds := floori(float(total_centiseconds) / 100.0) % 60
	var centiseconds := total_centiseconds % 100
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]
