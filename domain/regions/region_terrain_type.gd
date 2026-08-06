class_name RegionTerrainType
extends RefCounted

const GRASSLAND: StringName = &"grassland"
const FARMLAND: StringName = &"farmland"
const LAKE: StringName = &"lake"
const MARSH: StringName = &"marsh"
const FOREST: StringName = &"forest"
const DEEP_FOREST: StringName = &"deep_forest"

const ALL: Array[StringName] = [
	GRASSLAND,
	FARMLAND,
	LAKE,
	MARSH,
	FOREST,
	DEEP_FOREST,
]


static func is_valid(terrain_type: StringName) -> bool:
	return terrain_type in ALL
