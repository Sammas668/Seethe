class_name CampaignItemLocationState
extends RefCounted

const LOCATION_CHARACTER_EQUIPMENT: StringName = &"character_equipment"
const LOCATION_CHARACTER_INVENTORY: StringName = &"character_inventory"
const LOCATION_STRONGHOLD_STORAGE: StringName = &"stronghold_storage"
const LOCATION_MISSION_GROUND: StringName = &"mission_ground"
const LOCATION_RETURN_TRANSIT: StringName = &"return_transit"
const LOCATION_UNASSIGNED: StringName = &"unassigned"
const LOCATION_LOST: StringName = &"lost"

const DEFAULT_STRONGHOLD_STORAGE_ID: StringName = &"stronghold.main.storage"

const CONTAINER_PRIMARY_HAND: StringName = &"main_hand"
const CONTAINER_SECONDARY_HAND: StringName = &"off_hand"
const CONTAINER_BELT: StringName = &"belt"
const CONTAINER_BACKPACK: StringName = &"backpack"
const CONTAINER_ARMOUR: StringName = &"armour"
# Legacy save-only container. New strategic loadouts migrate it to Belt, Backpack or Storage.
const CONTAINER_WORN_UTILITY: StringName = &"worn_utility"

var location_type: StringName = LOCATION_UNASSIGNED
var owner_id: StringName = &""
var container_id: StringName = &""
var grid_position: Vector2i = Vector2i.ZERO
var map_position: Vector2i = Vector2i.ZERO
var source_label: String = ""
var is_rotated: bool = false


func _init(
		location_type_value: StringName = LOCATION_UNASSIGNED,
		owner_id_value: StringName = &"",
		container_id_value: StringName = &"",
		grid_position_value: Vector2i = Vector2i.ZERO,
		map_position_value: Vector2i = Vector2i.ZERO,
		source_label_value: String = "",
		is_rotated_value: bool = false
) -> void:
	location_type = location_type_value
	owner_id = owner_id_value
	container_id = container_id_value
	grid_position = grid_position_value
	map_position = map_position_value
	source_label = source_label_value
	is_rotated = is_rotated_value


static func character_slot(
		character_id: StringName,
		container_kind: StringName,
		position: Vector2i = Vector2i.ZERO,
		is_rotated_value: bool = false
) -> CampaignItemLocationState:
	if container_kind == CONTAINER_WORN_UTILITY:
		container_kind = CONTAINER_BACKPACK
	var location_type_value: StringName = LOCATION_CHARACTER_EQUIPMENT
	if container_kind in [
		CONTAINER_BELT,
		CONTAINER_BACKPACK,
	]:
		location_type_value = LOCATION_CHARACTER_INVENTORY
	return CampaignItemLocationState.new(
		location_type_value,
		character_id,
		container_kind,
		position,
		Vector2i.ZERO,
		"",
		is_rotated_value
	)


static func stronghold_storage(
		storage_id: StringName = DEFAULT_STRONGHOLD_STORAGE_ID,
		position: Vector2i = Vector2i.ZERO
) -> CampaignItemLocationState:
	return CampaignItemLocationState.new(
		LOCATION_STRONGHOLD_STORAGE,
		storage_id,
		&"storage",
		position
	)


static func return_transit(operation_id: StringName) -> CampaignItemLocationState:
	return CampaignItemLocationState.new(
		LOCATION_RETURN_TRANSIT,
		operation_id,
		&"return_cargo",
		Vector2i.ZERO,
		Vector2i.ZERO,
		"Returning mission cargo"
	)


static func mission_ground(
		position: Vector2i,
		source_label_value: String = "Ground"
) -> CampaignItemLocationState:
	return CampaignItemLocationState.new(
		LOCATION_MISSION_GROUND,
		&"",
		&"ground",
		Vector2i.ZERO,
		position,
		source_label_value
	)


static func lost() -> CampaignItemLocationState:
	return CampaignItemLocationState.new(LOCATION_LOST)


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	var known_types: Array[StringName] = [
		LOCATION_CHARACTER_EQUIPMENT,
		LOCATION_CHARACTER_INVENTORY,
		LOCATION_STRONGHOLD_STORAGE,
		LOCATION_MISSION_GROUND,
		LOCATION_RETURN_TRANSIT,
		LOCATION_UNASSIGNED,
		LOCATION_LOST,
	]
	if location_type not in known_types:
		errors.append("Unknown campaign item location type %s." % location_type)
		return errors

	match location_type:
		LOCATION_CHARACTER_EQUIPMENT:
			if owner_id.is_empty():
				errors.append("Character equipment location has no character owner.")
			if container_id == CONTAINER_WORN_UTILITY:
				errors.append("Worn Utility is a legacy strategic container and must be migrated.")
			elif container_id not in [
				CONTAINER_PRIMARY_HAND,
				CONTAINER_SECONDARY_HAND,
				CONTAINER_ARMOUR,
			]:
				errors.append("Character equipment uses illegal container %s." % container_id)
		LOCATION_CHARACTER_INVENTORY:
			if owner_id.is_empty():
				errors.append("Character inventory location has no character owner.")
			if container_id not in [CONTAINER_BELT, CONTAINER_BACKPACK]:
				errors.append("Character inventory uses illegal container %s." % container_id)
			if grid_position.x < 0 or grid_position.y < 0:
				errors.append("Character inventory location has a negative grid position.")
		LOCATION_STRONGHOLD_STORAGE:
			if owner_id.is_empty():
				errors.append("Stronghold storage location has no storage owner.")
			if container_id != &"storage":
				errors.append("Stronghold storage location uses an illegal container.")
		LOCATION_MISSION_GROUND:
			if not owner_id.is_empty():
				errors.append("Mission-ground item must not have a character owner.")
			if container_id != &"ground":
				errors.append("Mission-ground item uses an illegal container.")
		LOCATION_RETURN_TRANSIT:
			if owner_id.is_empty():
				errors.append("Returning cargo has no travel-operation owner.")
			if container_id != &"return_cargo":
				errors.append("Returning cargo uses an illegal container.")
		LOCATION_UNASSIGNED, LOCATION_LOST:
			if not owner_id.is_empty() or not container_id.is_empty():
				errors.append("Unassigned or lost item must not retain owner/container data.")

	return errors


func belongs_to_character(character_id: StringName) -> bool:
	return (
		owner_id == character_id
		and location_type in [
			LOCATION_CHARACTER_EQUIPMENT,
			LOCATION_CHARACTER_INVENTORY,
		]
	)


func is_stronghold_storage() -> bool:
	return location_type == LOCATION_STRONGHOLD_STORAGE


func clone() -> CampaignItemLocationState:
	return CampaignItemLocationState.new(
		location_type,
		owner_id,
		container_id,
		grid_position,
		map_position,
		source_label,
		is_rotated
	)


func to_dictionary() -> Dictionary:
	return {
		"location_type": String(location_type),
		"owner_id": String(owner_id),
		"container_id": String(container_id),
		"grid_position": [grid_position.x, grid_position.y],
		"map_position": [map_position.x, map_position.y],
		"source_label": source_label,
		"is_rotated": is_rotated,
	}


static func from_dictionary(data: Dictionary) -> CampaignItemLocationState:
	return CampaignItemLocationState.new(
		StringName(data.get("location_type", "unassigned")),
		StringName(data.get("owner_id", "")),
		StringName(data.get("container_id", data.get("container_kind", ""))),
		_vector_from_value(data.get("grid_position", [0, 0])),
		_vector_from_value(data.get("map_position", [0, 0])),
		String(data.get("source_label", "")),
		bool(data.get("is_rotated", false))
	)


static func _vector_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array:
		var values: Array = value as Array
		if values.size() >= 2:
			return Vector2i(int(values[0]), int(values[1]))
	return Vector2i.ZERO
