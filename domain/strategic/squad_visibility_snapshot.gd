class_name SquadVisibilitySnapshot
extends RefCounted

const CATEGORY_LOW: StringName = &"low"
const CATEGORY_STANDARD: StringName = &"standard"
const CATEGORY_HIGH: StringName = &"high"
const CATEGORY_SEVERE: StringName = &"severe"

var snapshot_id: StringName = &""
var character_snapshots: Array[CharacterVisibilitySnapshot] = []
var total_visibility: int = 0
var category: StringName = CATEGORY_LOW
var travel_multiplier: float = 0.75
var created_tick: int = 0


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	if snapshot_id.is_empty():
		errors.append("Squad visibility snapshot has no ID.")
	var calculated: int = 0
	for character_snapshot: CharacterVisibilitySnapshot in character_snapshots:
		if character_snapshot == null:
			errors.append("Squad visibility snapshot %s contains a null character." % snapshot_id)
			continue
		errors.append_array(character_snapshot.validate_state())
		calculated += character_snapshot.final_visibility
	if calculated != total_visibility:
		errors.append("Squad visibility snapshot %s total does not match its characters." % snapshot_id)
	if category not in [CATEGORY_LOW, CATEGORY_STANDARD, CATEGORY_HIGH, CATEGORY_SEVERE]:
		errors.append("Squad visibility snapshot %s has invalid category %s." % [snapshot_id, category])
	if travel_multiplier <= 0.0:
		errors.append("Squad visibility snapshot %s has a non-positive multiplier." % snapshot_id)
	return errors


func character_snapshot(character_id: StringName) -> CharacterVisibilitySnapshot:
	for snapshot: CharacterVisibilitySnapshot in character_snapshots:
		if snapshot != null and snapshot.character_id == character_id:
			return snapshot
	return null


func category_display_name() -> String:
	return String(category).to_upper()


func to_dictionary() -> Dictionary:
	var serialized: Array[Dictionary] = []
	for snapshot: CharacterVisibilitySnapshot in character_snapshots:
		if snapshot != null:
			serialized.append(snapshot.to_dictionary())
	return {
		"snapshot_id": String(snapshot_id),
		"character_snapshots": serialized,
		"total_visibility": total_visibility,
		"category": String(category),
		"travel_multiplier": travel_multiplier,
		"created_tick": created_tick,
	}


static func from_dictionary(data: Dictionary) -> SquadVisibilitySnapshot:
	var result := SquadVisibilitySnapshot.new()
	result.snapshot_id = StringName(data.get("snapshot_id", ""))
	var raw_characters: Variant = data.get("character_snapshots", [])
	if raw_characters is Array:
		for raw_snapshot: Variant in raw_characters as Array:
			if raw_snapshot is Dictionary:
				result.character_snapshots.append(
					CharacterVisibilitySnapshot.from_dictionary(raw_snapshot as Dictionary)
				)
	result.total_visibility = maxi(0, int(data.get("total_visibility", 0)))
	result.category = StringName(data.get("category", CATEGORY_LOW))
	result.travel_multiplier = maxf(0.01, float(data.get("travel_multiplier", 0.75)))
	result.created_tick = maxi(0, int(data.get("created_tick", 0)))
	return result
