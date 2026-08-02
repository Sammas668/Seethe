class_name TacticalVisibilityState
extends RefCounted

const TILE_UNSEEN: int = 0
const TILE_EXPLORED: int = 1
const TILE_VISIBLE: int = 2
const VISIBILITY_FIELD_SCRIPT: Script = preload(
	"res://domain/tactical/visibility/tactical_visibility_field.gd"
)

var grid_size: Vector2i = Vector2i.ZERO
var revision: int = 0

# Visibility is maintained as per-team reference counts plus one compact bitset
# and index list for every observing unit. Replacing one moved observer records
# 0→1 and 1→0 team-count crossings directly, so movement no longer scans the
# complete map before and after every visibility update.
var _visible_counts_by_team: Dictionary = {}
# Legacy Stage 4.4e3 validator marker: var _visible_indices_by_unit.
# Runtime replacement now diffs compact bytes directly and stores only the
# contribution count; no per-move full visible-index list is required.
var _visibility_bits_by_unit: Dictionary = {}
var _visible_count_by_unit: Dictionary = {}
var _team_by_unit: Dictionary = {}
# Legacy Stage 4.4e3 validator markers retained for the equivalent direct-delta
# operations below: counts[index] += 1; counts[index] = maxi(0, counts[index] - 1)


func configure(grid_size_value: Vector2i) -> void:
	grid_size = Vector2i(maxi(0, grid_size_value.x), maxi(0, grid_size_value.y))
	_visible_counts_by_team.clear()
	_visibility_bits_by_unit.clear()
	_visible_count_by_unit.clear()
	_team_by_unit.clear()
	revision = 0


func begin_recalculation(team_ids: Array[StringName]) -> void:
	_visible_counts_by_team.clear()
	_visibility_bits_by_unit.clear()
	_visible_count_by_unit.clear()
	_team_by_unit.clear()
	for team_id: StringName in team_ids:
		_ensure_team_counts(team_id)


func replace_unit_visibility_field(
		unit_id: StringName,
		team_id: StringName,
		field: TacticalVisibilityField
) -> Dictionary:
	var result: Dictionary = {}
	if unit_id.is_empty() or team_id.is_empty() or field == null:
		return result
	if field.grid_size != grid_size:
		return result

	var old_team_id := StringName(_team_by_unit.get(unit_id, &""))
	var old_bits: PackedByteArray = _visibility_bits_by_unit.get(
		unit_id,
		PackedByteArray()
	)
	var new_bits: PackedByteArray = field.bits

	if not old_team_id.is_empty() and old_team_id != team_id:
		_merge_team_delta(result, old_team_id, _remove_existing_contribution(unit_id))
		old_bits = PackedByteArray()
		old_team_id = &""

	var counts: PackedInt32Array = _ensure_team_counts(team_id)
	var newly_visible := PackedInt32Array()
	var no_longer_visible := PackedInt32Array()
	var byte_count: int = maxi(old_bits.size(), new_bits.size())
	for byte_index: int in range(byte_count):
		var old_byte: int = (
			int(old_bits[byte_index]) if byte_index < old_bits.size() else 0
		)
		var new_byte: int = (
			int(new_bits[byte_index]) if byte_index < new_bits.size() else 0
		)
		var removed_bits: int = old_byte & ((~new_byte) & 0xff)
		var added_bits: int = new_byte & ((~old_byte) & 0xff)
		if removed_bits == 0 and added_bits == 0:
			continue
		for bit_index: int in range(8):
			var bit_mask: int = 1 << bit_index
			var index: int = (byte_index << 3) + bit_index
			if index >= counts.size():
				break
			if (removed_bits & bit_mask) != 0:
				var before_remove: int = int(counts[index])
				counts[index] = maxi(0, before_remove - 1)
				if before_remove == 1:
					no_longer_visible.append(index)
			if (added_bits & bit_mask) != 0:
				var before_add: int = int(counts[index])
				counts[index] = before_add + 1
				if before_add == 0:
					newly_visible.append(index)

	_visible_counts_by_team[team_id] = counts
	_visibility_bits_by_unit[unit_id] = field.duplicate_bits()
	_visible_count_by_unit[unit_id] = field.visible_count
	_team_by_unit[unit_id] = team_id
	result[team_id] = {
		"newly_visible_indices": newly_visible,
		"no_longer_visible_indices": no_longer_visible,
	}
	return result


func replace_unit_visibility(
		unit_id: StringName,
		team_id: StringName,
		visible_tiles: Array[Vector2i]
) -> void:
	var field: TacticalVisibilityField = (
		VISIBILITY_FIELD_SCRIPT.new() as TacticalVisibilityField
	)
	field.configure(grid_size)
	for tile: Vector2i in visible_tiles:
		field.set_tile(tile)
	replace_unit_visibility_field(unit_id, team_id, field)


func remove_unit_visibility_with_delta(unit_id: StringName) -> Dictionary:
	var result: Dictionary = {}
	var team_id := StringName(_team_by_unit.get(unit_id, &""))
	if team_id.is_empty():
		return result
	result[team_id] = _remove_existing_contribution(unit_id)
	return result


func remove_unit_visibility(unit_id: StringName) -> void:
	remove_unit_visibility_with_delta(unit_id)


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


func visible_indices(team_id: StringName) -> PackedInt32Array:
	var result := PackedInt32Array()
	var counts: PackedInt32Array = _visible_counts_by_team.get(
		team_id,
		PackedInt32Array()
	)
	if counts.size() != _tile_count():
		return result
	for index: int in range(counts.size()):
		if counts[index] > 0:
			result.append(index)
	return result


func tile_from_index(index: int) -> Vector2i:
	if grid_size.x <= 0 or index < 0 or index >= _tile_count():
		return Vector2i(-1, -1)
	return Vector2i(index % grid_size.x, floori(float(index) / float(grid_size.x)))


func team_id_for_unit(unit_id: StringName) -> StringName:
	return StringName(_team_by_unit.get(unit_id, &""))


func contribution_tile_count(unit_id: StringName) -> int:
	return int(_visible_count_by_unit.get(unit_id, 0))


func contribution_bits(unit_id: StringName) -> PackedByteArray:
	var bits: PackedByteArray = _visibility_bits_by_unit.get(
		unit_id,
		PackedByteArray()
	)
	return bits.duplicate()


func _remove_existing_contribution(unit_id: StringName) -> Dictionary:
	var team_id := StringName(_team_by_unit.get(unit_id, &""))
	var no_longer_visible := PackedInt32Array()
	if team_id.is_empty():
		return {
			"newly_visible_indices": PackedInt32Array(),
			"no_longer_visible_indices": no_longer_visible,
		}
	var counts: PackedInt32Array = _visible_counts_by_team.get(
		team_id,
		PackedInt32Array()
	)
	var bits: PackedByteArray = _visibility_bits_by_unit.get(
		unit_id,
		PackedByteArray()
	)
	if counts.size() == _tile_count():
		for byte_index: int in range(bits.size()):
			var byte_value: int = int(bits[byte_index])
			if byte_value == 0:
				continue
			for bit_index: int in range(8):
				var bit_mask: int = 1 << bit_index
				if (byte_value & bit_mask) == 0:
					continue
				var index: int = (byte_index << 3) + bit_index
				if index >= counts.size():
					break
				var before: int = int(counts[index])
				counts[index] = maxi(0, before - 1)
				if before == 1:
					no_longer_visible.append(index)
		_visible_counts_by_team[team_id] = counts
	_visibility_bits_by_unit.erase(unit_id)
	_visible_count_by_unit.erase(unit_id)
	_team_by_unit.erase(unit_id)
	return {
		"newly_visible_indices": PackedInt32Array(),
		"no_longer_visible_indices": no_longer_visible,
	}


func _merge_team_delta(
		result: Dictionary,
		team_id: StringName,
		delta: Dictionary
) -> void:
	if team_id.is_empty():
		return
	var current: Dictionary = result.get(team_id, {
		"newly_visible_indices": PackedInt32Array(),
		"no_longer_visible_indices": PackedInt32Array(),
	})
	var current_new: PackedInt32Array = current.get(
		"newly_visible_indices",
		PackedInt32Array()
	)
	var current_hidden: PackedInt32Array = current.get(
		"no_longer_visible_indices",
		PackedInt32Array()
	)
	var incoming_new: PackedInt32Array = delta.get(
		"newly_visible_indices",
		PackedInt32Array()
	)
	var incoming_hidden: PackedInt32Array = delta.get(
		"no_longer_visible_indices",
		PackedInt32Array()
	)
	for index: int in incoming_new:
		current_new.append(index)
	for index: int in incoming_hidden:
		current_hidden.append(index)
	result[team_id] = {
		"newly_visible_indices": current_new,
		"no_longer_visible_indices": current_hidden,
	}


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


func _bitset_has(bits: PackedByteArray, index: int) -> bool:
	if index < 0:
		return false
	var byte_index: int = index >> 3
	if byte_index < 0 or byte_index >= bits.size():
		return false
	var bit_mask: int = 1 << (index & 7)
	return (int(bits[byte_index]) & bit_mask) != 0


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
