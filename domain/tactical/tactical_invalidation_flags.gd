class_name TacticalInvalidationFlags
extends RefCounted

## Compatibility projection consumed by presentation and visibility listeners.
## Production transactions must supply TacticalInvalidationContract explicitly.

var occupancy_changed: bool = false
var visibility_changed: bool = false
var exploration_changed: bool = false
var geometry_changed: bool = false
var environment_visuals_changed: bool = false
var inventory_changed: bool = false
var initiative_changed: bool = false
var token_status_changed: bool = false
var action_budget_changed: bool = false


static func full_refresh() -> TacticalInvalidationFlags:
	var flags := TacticalInvalidationFlags.new()
	flags.occupancy_changed = true
	flags.visibility_changed = true
	flags.exploration_changed = true
	flags.geometry_changed = true
	flags.environment_visuals_changed = true
	flags.inventory_changed = true
	flags.initiative_changed = true
	flags.token_status_changed = true
	flags.action_budget_changed = true
	return flags


static func reaction_decision() -> TacticalInvalidationFlags:
	var flags := TacticalInvalidationFlags.new()
	flags.token_status_changed = true
	return flags


static func for_reason(reason: StringName) -> TacticalInvalidationFlags:
	# Legacy-only compatibility for old tests and migration diagnostics. Runtime
	# production code must not call this function after Stage 4.5g.
	push_error(
		"Reason-derived invalidation is retired. Supply an explicit contract for %s."
		% reason
	)
	return TacticalInvalidationFlags.full_refresh()


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
	result.action_budget_changed = action_budget_changed
	return result
