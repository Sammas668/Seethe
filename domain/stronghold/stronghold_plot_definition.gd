class_name StrongholdPlotDefinition
extends RefCounted

const FIXED_HEART: StringName = &"fixed_heart"
const FIXED_ENTRANCE: StringName = &"fixed_entrance"
const SEALED: StringName = &"sealed"
const RUINED: StringName = &"ruined"
const AVAILABLE: StringName = &"available"
const OCCUPIED: StringName = &"occupied"
const PERMANENT_BLOCK: StringName = &"permanent_block"

const ALL_STATES: Array[StringName] = [
	FIXED_HEART,
	FIXED_ENTRANCE,
	SEALED,
	RUINED,
	AVAILABLE,
	OCCUPIED,
	PERMANENT_BLOCK,
]

var coord: Vector2i = Vector2i.ZERO
var authored_state: StringName = AVAILABLE
var display_name: String = ""
var description: String = ""
var fixed_facility_id: StringName = &""
var tags: Array[StringName] = []


func key() -> StringName:
	return StringName("%d,%d" % [coord.x, coord.y])


func validate_definition(width: int, height: int) -> Array[String]:
	var errors: Array[String] = []
	if coord.x < 0 or coord.y < 0 or coord.x >= width or coord.y >= height:
		errors.append("Stronghold plot %s lies outside its authored grid." % key())
	if authored_state not in ALL_STATES:
		errors.append("Stronghold plot %s has invalid state %s." % [key(), authored_state])
	if display_name.strip_edges().is_empty():
		errors.append("Stronghold plot %s has no display name." % key())
	if authored_state in [FIXED_HEART, FIXED_ENTRANCE] and fixed_facility_id.is_empty():
		errors.append("Fixed stronghold plot %s has no facility identity." % key())
	return errors


static func state_display_name(state: StringName) -> String:
	match state:
		FIXED_HEART:
			return "Fixed Heart"
		FIXED_ENTRANCE:
			return "Fixed Entrance"
		SEALED:
			return "Sealed"
		RUINED:
			return "Ruined"
		AVAILABLE:
			return "Available"
		OCCUPIED:
			return "Occupied"
		PERMANENT_BLOCK:
			return "Permanent Block"
	return String(state).replace("_", " ").capitalize()


static func is_accessible_state(state: StringName) -> bool:
	return state in [FIXED_HEART, FIXED_ENTRANCE, RUINED, AVAILABLE, OCCUPIED]
