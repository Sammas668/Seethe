class_name StrongholdFacilityPresentationDefinition
extends RefCounted


var id: StringName = &""
var display_name: String = ""
var description: String = ""
var art_path: String = ""
var fallback_symbol: String = ""
var accent_color: String = "c5a35b"
var expected_footprint: Vector2i = Vector2i.ONE


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Stronghold facility presentation has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Stronghold facility presentation %s has no display name." % id)
	if expected_footprint.x <= 0 or expected_footprint.y <= 0:
		errors.append("Stronghold facility presentation %s has an invalid footprint hint." % id)
	return errors
