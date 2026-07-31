class_name TacticalVisibilityState
extends RefCounted

const TILE_UNSEEN: int = 0
const TILE_EXPLORED: int = 1
const TILE_VISIBLE: int = 2

var grid_size: Vector2i = Vector2i.ZERO
var revision: int = 0

# Visibility is maintained as per-team reference counts plus one compact list of
# tile indices contributed by each observing unit. Replacing one moved unit's
# contribution is therefore O(old visible tiles + new visible tiles), instead of
# clearing and rebuilding every team's visibility after every movement.
var _visible_counts_by_team: Dictionary = {}
var _visible_indices_by_unit: Dictionary = {}
var _team_by_unit: Dictionary = {}


func configure(grid_size_value: Vector2i) -> void:
	grid_size = Vector2i(maxi(0, grid_size_value.x), maxi(0, grid_size_value.y))
	_visible_counts_by_team.clear()
	_visible_indices_by_unit.clear()
	_team_by_unit.clear()
	revision = 0


func begin_recalculation(team_ids: Array[StringName]) -> void:
	_visible_counts_by_team.clear()
	_visible_indices_by_unit.clear()
	_team_by_unit.clear()
	for team_id: StringName in team_ids:
		_ensure_team_counts(team_id)


func replace_unit_visibility(
		unit_id: StringName,
		team_id: StringName,
		visible_tiles: Array[Vector2i]
) -> void:
	if unit_id.is_empty() or team_id.is_empty():
		return
	remove_unit_visibility(unit_id)
	var counts: PackedInt32Array = _ensure_team_counts(team_id)
	var indices := PackedInt32Array()
	var seen_indices: Dictionary = {}
	for tile: Vector2i in visible_tiles:
		if not _is_inside(tile):
			continue
		var index: int = _tile_index(tile)
		if seen_indices.has(index):
			continue
		seen_indices[index] = true
		counts[index] += 1
		indices.append(index)
	_visible_counts_by_team[team_id] = counts
	_visible_indices_by_unit[unit_id] = indices
	_team_by_unit[unit_id] = team_id


func remove_unit_visibility(unit_id: StringName) -> void:
	if unit_id.is_empty() or not _visible_indices_by_unit.has(unit_id):
		return
	var team_id := StringName(_team_by_unit.get(unit_id, &""))
	var counts: PackedInt32Array = _visible_counts_by_team.get(
		team_id,
		PackedInt32Array()
	)
	var indices: PackedInt32Array = _visible_indices_by_unit.get(
		unit_id,
		PackedInt32Array()
	)
	if counts.size() == _tile_count():
		for index: int in indices:
			if index >= 0 and index < counts.size():
				counts[index] = maxi(0, counts[index] - 1)
		_visible_counts_by_team[team_id] = counts
	_visible_indices_by_unit.erase(unit_id)
	_team_by_unit.erase(unit_id)


# Compatibility helper for older callers. New gameplay code should replace a
# unit contribution rather than revealing anonymous tiles.
func reveal_tile(team_id: StringName, tile: Vector2i) -> void:
	if not _is_inside(tile) or team_id.is_empty():
		return
	var counts: PackedInt32Array = _ensure_team_counts(team_id)
	counts[_tile_index(tile)] = maxi(1, counts[_tile_index(tile)])
	_visible_counts_by_team[team_id] = counts


func complete_recalculation() -> void:
	revision += 1


func is_visible(team_id: StringName, tile: Vector2i) -> bool:
	if not _is_inside(tile):
		return false
	var counts: PackedInt32Array = _visible_counts_by_team.get(
		team_id,
		PackedInt32Array()
	)
	return (
		counts.size() == _tile_count()
		and counts[_tile_index(tile)] > 0
	)


func visible_tile_count(team_id: StringName) -> int:
	var result: int = 0
	var counts: PackedInt32Array = _visible_counts_by_team.get(
		team_id,
		PackedInt32Array()
	)
	for value: int in counts:
		if value > 0:
			result += 1
	return result


func contribution_tile_count(unit_id: StringName) -> int:
	var indices: PackedInt32Array = _visible_indices_by_unit.get(
		unit_id,
		PackedInt32Array()
	)
	return indices.size()


func _ensure_team_counts(team_id: StringName) -> PackedInt32Array:
	var counts: PackedInt32Array = _visible_counts_by_team.get(
		team_id,
		PackedInt32Array()
	)
	if counts.size() != _tile_count():
		counts.resize(_tile_count())
		counts.fill(0)
		_visible_counts_by_team[team_id] = counts
	return counts


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
