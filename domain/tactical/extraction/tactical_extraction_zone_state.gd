class_name TacticalExtractionZoneState
extends RefCounted

var zone_id: StringName = &""
var enabled: bool = true
var contested: bool = false


func _init(
		zone_id_value: StringName = &"",
		enabled_value: bool = true,
		contested_value: bool = false
) -> void:
	zone_id = zone_id_value
	enabled = enabled_value
	contested = contested_value


func is_usable() -> bool:
	return enabled and not contested


func to_dictionary() -> Dictionary:
	return {
		"zone_id": String(zone_id),
		"enabled": enabled,
		"contested": contested,
	}


static func from_dictionary(data: Dictionary) -> TacticalExtractionZoneState:
	return TacticalExtractionZoneState.new(
		StringName(data.get("zone_id", "")),
		bool(data.get("enabled", true)),
		bool(data.get("contested", false))
	)
