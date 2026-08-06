class_name TacticalDiceRoller
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _scripted_results: Array[int] = []
var _scripted_index: int = 0


func _init() -> void:
	_rng.randomize()


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	_scripted_results.clear()
	_scripted_index = 0


func set_scripted_results(results: Array[int]) -> void:
	_scripted_results = results.duplicate()
	_scripted_index = 0


func clear_scripted_results() -> void:
	_scripted_results.clear()
	_scripted_index = 0


func snapshot_state() -> Dictionary:
	return {
		"rng_state": _rng.state,
		"scripted_results": _scripted_results.duplicate(),
		"scripted_index": _scripted_index,
	}


func restore_state(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	_rng.state = int(snapshot.get("rng_state", _rng.state))
	var scripted_value: Variant = snapshot.get("scripted_results", [])
	_scripted_results.clear()
	if scripted_value is Array:
		for value: Variant in scripted_value:
			_scripted_results.append(int(value))
	_scripted_index = clampi(
		int(snapshot.get("scripted_index", 0)),
		0,
		_scripted_results.size()
	)


func roll_die(sides: int) -> int:
	var resolved_sides: int = maxi(2, sides)
	if _scripted_index < _scripted_results.size():
		var scripted: int = _scripted_results[_scripted_index]
		_scripted_index += 1
		return clampi(scripted, 1, resolved_sides)
	return _rng.randi_range(1, resolved_sides)


func roll_dice(count: int, sides: int) -> Array[int]:
	var result: Array[int] = []
	for _index: int in range(maxi(0, count)):
		result.append(roll_die(sides))
	return result
