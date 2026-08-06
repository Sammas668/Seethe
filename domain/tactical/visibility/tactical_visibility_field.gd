class_name TacticalVisibilityField
extends RefCounted

const BIT_COUNTS: Array[int] = [
	0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8,
]

var grid_size: Vector2i = Vector2i.ZERO
var bits: PackedByteArray = PackedByteArray()
var _indices: PackedInt32Array = PackedInt32Array()
var _indices_ready: bool = false
var visible_count: int = 0


func configure(grid_size_value: Vector2i) -> void:
	grid_size = Vector2i(
		maxi(0, grid_size_value.x),
		maxi(0, grid_size_value.y)
	)
	bits = PackedByteArray()
	bits.resize(int(ceil(float(_tile_count()) / 8.0)))
	bits.fill(0)
	_indices = PackedInt32Array()
	_indices_ready = false
	visible_count = 0


func configure_from_bits(
		grid_size_value: Vector2i,
		source_bits: PackedByteArray
) -> void:
	configure(grid_size_value)
	var copy_count: int = mini(bits.size(), source_bits.size())
	for index: int in range(copy_count):
		bits[index] = source_bits[index]
	_indices_ready = false
	visible_count = _count_set_bits()


func set_tile(tile: Vector2i) -> void:
	if not _is_inside(tile):
		return
	set_index(_tile_index(tile))


func set_index(index: int) -> void:
	if index < 0 or index >= _tile_count():
		return
	var byte_index: int = index >> 3
	var bit_mask: int = 1 << (index & 7)
	var current: int = int(bits[byte_index])
	if (current & bit_mask) != 0:
		return
	bits[byte_index] = current | bit_mask
	visible_count += 1
	_indices_ready = false


func has_tile(tile: Vector2i) -> bool:
	return _is_inside(tile) and has_index(_tile_index(tile))


func has_index(index: int) -> bool:
	if index < 0 or index >= _tile_count():
		return false
	var byte_index: int = index >> 3
	var bit_mask: int = 1 << (index & 7)
	return (int(bits[byte_index]) & bit_mask) != 0


func merge_from(other: TacticalVisibilityField) -> void:
	if other == null or other.grid_size != grid_size:
		return
	var changed: bool = false
	var byte_count: int = mini(bits.size(), other.bits.size())
	for index: int in range(byte_count):
		var before: int = int(bits[index])
		var after: int = before | int(other.bits[index])
		if before == after:
			continue
		bits[index] = after
		visible_count += int(BIT_COUNTS[after]) - int(BIT_COUNTS[before])
		changed = true
	if changed:
		_indices_ready = false


func visible_indices() -> PackedInt32Array:
	if not _indices_ready:
		_rebuild_indices()
	return _indices


func duplicate_bits() -> PackedByteArray:
	return bits.duplicate()


func duplicate_field() -> TacticalVisibilityField:
	var result := TacticalVisibilityField.new()
	result.grid_size = grid_size
	result.bits = bits.duplicate()
	result._indices = PackedInt32Array()
	result._indices_ready = false
	result.visible_count = visible_count
	return result


func memory_bytes() -> int:
	return bits.size() + (_indices.size() * 4 if _indices_ready else 0)


func _rebuild_indices() -> void:
	_indices = PackedInt32Array()
	for index: int in range(_tile_count()):
		if has_index(index):
			_indices.append(index)
	visible_count = _indices.size()
	_indices_ready = true


func _count_set_bits() -> int:
	var result: int = 0
	for value: int in bits:
		result += int(BIT_COUNTS[value])
	return result


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
