class_name StandardScoreStore
extends RefCounted

var storage_path: String = "user://standard_best.cfg"
var best_score: int = 0
var last_storage_error: Error = OK


func load_best() -> int:
	best_score = 0
	var config := ConfigFile.new()
	last_storage_error = config.load(storage_path)
	if last_storage_error == OK:
		var value: Variant = config.get_value("standard", "best_score", 0)
		if value is int and value >= 0:
			best_score = value
	return best_score


func record_score(score: int) -> bool:
	if score <= best_score:
		return false
	best_score = score
	var config := ConfigFile.new()
	config.set_value("standard", "best_score", best_score)
	last_storage_error = config.save(storage_path)
	# A failed write still retains the best for this arcade session.
	return true
