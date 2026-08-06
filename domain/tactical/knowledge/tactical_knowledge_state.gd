class_name TacticalKnowledgeState
extends RefCounted

var grid_size: Vector2i = Vector2i.ZERO
var revision: int = 0
var _explored_by_team: Dictionary = {}


func configure(grid_size_value: Vector2i) -> void:
	var resolved_size := Vector2i(
		maxi(0, grid_size_value.x),
		maxi(0, grid_size_value.y)
	)
	if resolved_size == grid_size:
		return
	grid_size = resolved_size
	_explored_by_team.clear()
	revision += 1


func mark_explored(team_id: StringName, tile: Vector2i) -> bool:
	if team_id.is_empty() or not _is_inside(tile):
		return false
	var explored: PackedByteArray = _ensure_explored(team_id)
	var index: int = _tile_index(tile)
	if explored[index] != 0:
		return false
	explored[index] = 1
	_explored_by_team[team_id] = explored
	revision += 1
	return true


func mark_many_explored(
		team_id: StringName,
		tiles: Array[Vector2i]
) -> int:
	if team_id.is_empty() or tiles.is_empty():
		return 0
	var explored: PackedByteArray = _ensure_explored(team_id)
	var changed: int = 0
	for tile: Vector2i in tiles:
		if not _is_inside(tile):
			continue
		var index: int = _tile_index(tile)
		if explored[index] != 0:
			continue
		explored[index] = 1
		changed += 1
	if changed > 0:
		_explored_by_team[team_id] = explored
		revision += 1
	return changed


func is_explored(team_id: StringName, tile: Vector2i) -> bool:
	if not _is_inside(tile):
		return false
	var explored: PackedByteArray = _explored_by_team.get(
		team_id,
		PackedByteArray()
	)
	return (
		explored.size() == _tile_count()
		and explored[_tile_index(tile)] != 0
	)


func explored_tile_count(team_id: StringName) -> int:
	var result: int = 0
	var explored: PackedByteArray = _explored_by_team.get(
		team_id,
		PackedByteArray()
	)
	for value: int in explored:
		if value != 0:
			result += 1
	return result


func team_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in _explored_by_team.keys():
		result.append(StringName(value))
	result.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	return result


func snapshot() -> Dictionary:
	var explored_copy: Dictionary = {}
	for team_value: Variant in _explored_by_team.keys():
		var team_id := StringName(team_value)
		var values: PackedByteArray = _explored_by_team.get(
			team_id,
			PackedByteArray()
		)
		explored_copy[team_id] = values.duplicate()
	return {
		"grid_size": grid_size,
		"revision": revision,
		"explored_by_team": explored_copy,
	}


func restore(snapshot_value: Dictionary) -> void:
	grid_size = Vector2i(snapshot_value.get("grid_size", Vector2i.ZERO))
	revision = int(snapshot_value.get("revision", 0))
	_explored_by_team.clear()
	var explored_value: Variant = snapshot_value.get("explored_by_team", {})
	if not (explored_value is Dictionary):
		return
	var explored_dictionary: Dictionary = explored_value
	for team_value: Variant in explored_dictionary.keys():
		var packed_value: Variant = explored_dictionary[team_value]
		if packed_value is PackedByteArray:
			var packed: PackedByteArray = packed_value
			_explored_by_team[StringName(team_value)] = packed.duplicate()


func validate_state(expected_grid_size: Vector2i = Vector2i.ZERO) -> Array[String]:
	var errors: Array[String] = []
	if grid_size.x < 0 or grid_size.y < 0:
		errors.append("Tactical knowledge has an invalid grid size.")
	if expected_grid_size != Vector2i.ZERO and grid_size != expected_grid_size:
		errors.append(
			"Tactical knowledge grid %s does not match map grid %s."
			% [grid_size, expected_grid_size]
		)
	for team_id: StringName in team_ids():
		var explored: PackedByteArray = _explored_by_team.get(
			team_id,
			PackedByteArray()
		)
		if explored.size() != _tile_count():
			errors.append(
				"Explored knowledge for %s has %d entries; expected %d."
				% [team_id, explored.size(), _tile_count()]
			)
	return errors


func _ensure_explored(team_id: StringName) -> PackedByteArray:
	var explored: PackedByteArray = _explored_by_team.get(
		team_id,
		PackedByteArray()
	)
	if explored.size() != _tile_count():
		explored.resize(_tile_count())
		explored.fill(0)
	_explored_by_team[team_id] = explored
	return explored


func _tile_count() -> int:
	return maxi(0, grid_size.x * grid_size.y)


func _tile_index(tile: Vector2i) -> int:
	return tile.y * grid_size.x + tile.x


func _is_inside(tile: Vector2i) -> bool:
	return (
		tile.x >= 0
		and tile.y >= 0
		and tile.x < grid_size.x
		and tile.y < grid_size.y
	)
