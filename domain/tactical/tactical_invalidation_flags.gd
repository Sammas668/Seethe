class_name TacticalInvalidationFlags
extends RefCounted

var occupancy_changed: bool = false
var visibility_changed: bool = false
var exploration_changed: bool = false
var geometry_changed: bool = false
var environment_visuals_changed: bool = false
var inventory_changed: bool = false
var initiative_changed: bool = false
var token_status_changed: bool = false


static func for_reason(reason: StringName) -> TacticalInvalidationFlags:
	var flags := TacticalInvalidationFlags.new()
	match reason:
		&"unit_moved", &"unit_sprinted", &"enemy_unit_moved", &"runtime_spawn", &"unit_removed":
			flags.occupancy_changed = true
			flags.visibility_changed = true
			flags.token_status_changed = true
		&"unit_faced_direction", &"current_perception_resolved":
			flags.visibility_changed = true
		&"attack_resolved", &"character_resolved":
			flags.occupancy_changed = true
			flags.visibility_changed = true
			flags.token_status_changed = true
		&"opening_state_changed", &"environment_geometry_changed", &"vision_blocker_changed":
			flags.geometry_changed = true
			flags.environment_visuals_changed = true
			flags.visibility_changed = true
		&"structure_state_changed", &"structure_attacked":
			flags.geometry_changed = true
			flags.environment_visuals_changed = true
			flags.visibility_changed = true
			flags.inventory_changed = true
		&"exploration_updated":
			flags.exploration_changed = true
		&"inventory_transferred", &"body_action_resolved", &"item_location_changed":
			flags.inventory_changed = true
			flags.token_status_changed = true
		&"initiative_started", &"initiative_advanced", &"initiative_ended":
			flags.initiative_changed = true
		_:
			flags.token_status_changed = true
	return flags


func duplicate_flags() -> TacticalInvalidationFlags:
	var result := TacticalInvalidationFlags.new()
	result.occupancy_changed = occupancy_changed
	result.visibility_changed = visibility_changed
	result.exploration_changed = exploration_changed
	result.geometry_changed = geometry_changed
	result.environment_visuals_changed = environment_visuals_changed
	result.inventory_changed = inventory_changed
	result.initiative_changed = initiative_changed
	result.token_status_changed = token_status_changed
	return result
