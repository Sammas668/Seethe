class_name RegionRoadType
extends RefCounted

const PRIMARY_ROAD: StringName = &"primary_road"
const LOCAL_ROAD: StringName = &"local_road"
const FOREST_TRACK: StringName = &"forest_track"

const ALL: Array[StringName] = [
	PRIMARY_ROAD,
	LOCAL_ROAD,
	FOREST_TRACK,
]


static func normalize(value: StringName) -> StringName:
	match value:
		PRIMARY_ROAD, LOCAL_ROAD, FOREST_TRACK:
			return value
		&"public_road", &"road", &"":
			return LOCAL_ROAD
		_:
			return LOCAL_ROAD


static func display_name(value: StringName) -> String:
	match normalize(value):
		PRIMARY_ROAD:
			return "Primary Road"
		FOREST_TRACK:
			return "Forest Track"
		_:
			return "Local Road"
