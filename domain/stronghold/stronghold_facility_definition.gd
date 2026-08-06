class_name StrongholdFacilityDefinition
extends RefCounted

var id: StringName = &""
var display_name: String = ""
var description: String = ""
var presentation_id: StringName = &""
var footprint: Vector2i = Vector2i.ONE
var buildable: bool = true
var unique: bool = false
var max_level: int = 3
var demolishable: bool = true
var starting_facility: bool = false
var category: StringName = &"support"
var construction_duration_minutes: int = 720
var upgrade_duration_minutes: Array[int] = []
# Total Storage Capacity contributed by each completed level. Empty or missing
# entries contribute zero. Upgrading facilities retain their current level.
var storage_capacity_by_level: Array[int] = []
# Additional lethal HP recovered per strategic day at each completed level.
# Nonlethal recovery is derived as twice the final lethal rate.
var recovery_rate_bonus_by_level: Array[int] = []
# Stable Space supplied by each completed level. This controls how many
# persistent transport assets can be supported, not which types are unlocked.
var stable_space_by_level: Array[int] = []
# Captive cells contributed by each completed Prison level.
var prison_capacity_by_level: Array[int] = []
# Stage 5.4B aggregate personnel and Workshop Production capability.
var personnel_capacity_by_level: Array[int] = []
var production_project_slots_by_level: Array[int] = []
var production_worker_positions_by_level: Array[int] = []
var production_max_workers_per_project_by_level: Array[int] = []
# Stage 5.4C Research capacity. Facilities provide project slots and worker
# positions without creating or owning Research knowledge.
var research_project_slots_by_level: Array[int] = []
var research_worker_positions_by_level: Array[int] = []
var research_max_workers_per_project_by_level: Array[int] = []
var benefit_lines: Array[String] = []


func validate_definition() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("Stronghold facility definition has no ID.")
	if display_name.strip_edges().is_empty():
		errors.append("Stronghold facility %s has no display name." % id)
	if presentation_id.is_empty():
		errors.append("Stronghold facility %s has no presentation ID." % id)
	if footprint.x <= 0 or footprint.y <= 0:
		errors.append("Stronghold facility %s has an invalid footprint." % id)
	if max_level <= 0:
		errors.append("Stronghold facility %s has an invalid maximum level." % id)
	if buildable and construction_duration_minutes <= 0:
		errors.append("Stronghold facility %s has an invalid construction duration." % id)
	for duration: int in upgrade_duration_minutes:
		if duration <= 0:
			errors.append("Stronghold facility %s has an invalid upgrade duration." % id)
	var previous_capacity: int = -1
	for capacity: int in storage_capacity_by_level:
		if capacity < 0:
			errors.append("Stronghold facility %s has negative storage capacity." % id)
		if previous_capacity >= 0 and capacity < previous_capacity:
			errors.append("Stronghold facility %s storage capacity decreases across normal levels." % id)
		previous_capacity = capacity
	if storage_capacity_by_level.size() > max_level:
		errors.append("Stronghold facility %s defines storage capacity beyond its maximum level." % id)
	var previous_recovery_bonus: int = -1
	for recovery_bonus: int in recovery_rate_bonus_by_level:
		if recovery_bonus < 0:
			errors.append("Stronghold facility %s has a negative recovery-rate bonus." % id)
		if previous_recovery_bonus >= 0 and recovery_bonus < previous_recovery_bonus:
			errors.append("Stronghold facility %s recovery-rate bonus decreases across normal levels." % id)
		previous_recovery_bonus = recovery_bonus
	if recovery_rate_bonus_by_level.size() > max_level:
		errors.append("Stronghold facility %s defines recovery bonuses beyond its maximum level." % id)
	var previous_stable_space: int = -1
	for stable_space: int in stable_space_by_level:
		if stable_space < 0:
			errors.append("Stronghold facility %s has negative Stable Space." % id)
		if previous_stable_space >= 0 and stable_space < previous_stable_space:
			errors.append("Stronghold facility %s Stable Space decreases across normal levels." % id)
		previous_stable_space = stable_space
	if stable_space_by_level.size() > max_level:
		errors.append("Stronghold facility %s defines Stable Space beyond its maximum level." % id)
	var previous_prison_capacity: int = -1
	for prison_capacity: int in prison_capacity_by_level:
		if prison_capacity < 0:
			errors.append("Stronghold facility %s has negative Prison capacity." % id)
		if previous_prison_capacity >= 0 and prison_capacity < previous_prison_capacity:
			errors.append("Stronghold facility %s Prison capacity decreases across normal levels." % id)
		previous_prison_capacity = prison_capacity
	if prison_capacity_by_level.size() > max_level:
		errors.append("Stronghold facility %s defines Prison capacity beyond its maximum level." % id)

	var previous_personnel_capacity: int = -1
	for personnel_capacity: int in personnel_capacity_by_level:
		if personnel_capacity < 0:
			errors.append("Stronghold facility %s has negative personnel capacity." % id)
		if previous_personnel_capacity >= 0 and personnel_capacity < previous_personnel_capacity:
			errors.append("Stronghold facility %s personnel capacity decreases across normal levels." % id)
		previous_personnel_capacity = personnel_capacity
	if personnel_capacity_by_level.size() > max_level:
		errors.append("Stronghold facility %s defines personnel capacity beyond its maximum level." % id)
	for raw_capability_values: Variant in [
		production_project_slots_by_level,
		production_worker_positions_by_level,
		production_max_workers_per_project_by_level,
		research_project_slots_by_level,
		research_worker_positions_by_level,
		research_max_workers_per_project_by_level,
	]:
		var capability_values: Array = raw_capability_values as Array
		for raw_value: Variant in capability_values:
			if int(raw_value) < 0:
				errors.append("Stronghold facility %s has negative Production or Research capacity." % id)
		if capability_values.size() > max_level:
			errors.append("Stronghold facility %s defines Production capacity beyond its maximum level." % id)
	return errors


func footprint_label() -> String:
	return "%d×%d" % [footprint.x, footprint.y]


func storage_capacity_for_level(level_value: int) -> int:
	if level_value <= 0 or storage_capacity_by_level.is_empty():
		return 0
	var index: int = mini(level_value, storage_capacity_by_level.size()) - 1
	return maxi(0, storage_capacity_by_level[index])


func recovery_rate_bonus_for_level(level_value: int) -> int:
	if level_value <= 0 or recovery_rate_bonus_by_level.is_empty():
		return 0
	var index: int = mini(level_value, recovery_rate_bonus_by_level.size()) - 1
	return maxi(0, recovery_rate_bonus_by_level[index])


func stable_space_for_level(level_value: int) -> int:
	if level_value <= 0 or stable_space_by_level.is_empty():
		return 0
	var index: int = mini(level_value, stable_space_by_level.size()) - 1
	return maxi(0, stable_space_by_level[index])


func prison_capacity_for_level(level_value: int) -> int:
	if level_value <= 0 or prison_capacity_by_level.is_empty():
		return 0
	var index: int = mini(level_value, prison_capacity_by_level.size()) - 1
	return maxi(0, prison_capacity_by_level[index])


func personnel_capacity_for_level(level_value: int) -> int:
	return _value_for_level(personnel_capacity_by_level, level_value)


func production_project_slots_for_level(level_value: int) -> int:
	return _value_for_level(production_project_slots_by_level, level_value)


func production_worker_positions_for_level(level_value: int) -> int:
	return _value_for_level(production_worker_positions_by_level, level_value)


func production_max_workers_for_level(level_value: int) -> int:
	return _value_for_level(production_max_workers_per_project_by_level, level_value)


func research_project_slots_for_level(level_value: int) -> int:
	return _value_for_level(research_project_slots_by_level, level_value)


func research_worker_positions_for_level(level_value: int) -> int:
	return _value_for_level(research_worker_positions_by_level, level_value)


func research_max_workers_for_level(level_value: int) -> int:
	return _value_for_level(research_max_workers_per_project_by_level, level_value)


func _value_for_level(values: Array[int], level_value: int) -> int:
	if level_value <= 0 or values.is_empty():
		return 0
	var index: int = mini(level_value, values.size()) - 1
	return maxi(0, values[index])


func upgrade_duration_for_target_level(target_level: int) -> int:
	if target_level <= 1:
		return maxi(1, construction_duration_minutes)
	var index: int = target_level - 2
	if index >= 0 and index < upgrade_duration_minutes.size():
		return maxi(1, upgrade_duration_minutes[index])
	return maxi(1, construction_duration_minutes * maxi(1, target_level - 1))
