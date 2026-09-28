class_name OverloadRecordStore
extends RefCounted

var storage_path: String = "user://overload_best.cfg"
var best_survival_seconds: float = 0.0
var best_refunds: int = 0
var last_storage_error: Error = OK


func load_bests() -> void:
	best_survival_seconds = 0.0
	best_refunds = 0
	var config := ConfigFile.new()
	last_storage_error = config.load(storage_path)
	if last_storage_error != OK:
		return
	var stored_time: Variant = config.get_value("overload", "best_survival_seconds", 0.0)
	var stored_refunds: Variant = config.get_value("overload", "best_refunds", 0)
	if (stored_time is float or stored_time is int) and float(stored_time) >= 0.0:
		best_survival_seconds = float(stored_time)
	if stored_refunds is int and stored_refunds >= 0:
		best_refunds = stored_refunds


func record_run(survival_seconds: float, refunds: int) -> bool:
	var improved := false
	if survival_seconds > best_survival_seconds:
		best_survival_seconds = survival_seconds
		improved = true
	if refunds > best_refunds:
		best_refunds = refunds
		improved = true
	if not improved:
		return false
	var config := ConfigFile.new()
	config.set_value("overload", "best_survival_seconds", best_survival_seconds)
	config.set_value("overload", "best_refunds", best_refunds)
	last_storage_error = config.save(storage_path)
	return true


static func format_survival_time(survival_seconds: float) -> String:
	var total_centiseconds := maxi(floori(maxf(survival_seconds, 0.0) * 100.0), 0)
	var minutes := floori(float(total_centiseconds) / 6000.0)
	var seconds := floori(float(total_centiseconds) / 100.0) % 60
	var centiseconds := total_centiseconds % 100
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]
