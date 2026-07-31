class_name TacticalStructureAttackHandler
extends RefCounted

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue
var _event_journal: RefCounted
var _dice_roller: TacticalDiceRoller


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		event_journal: RefCounted,
		dice_roller: TacticalDiceRoller
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_event_journal = event_journal
	_dice_roller = dice_roller


func preview(
		attacker_id: StringName,
		source_id: StringName,
		action_id: StringName
) -> Dictionary:
	var result: Dictionary = {"success": false, "reason": "", "attacker_id": attacker_id, "source_id": source_id, "action_id": action_id}
	if _state_store == null or _state_store.state == null or _catalogue == null:
		result.reason = "Structure-attack services are unavailable."
		return result
	var attacker: TacticalUnitState = _state_store.state.get_unit(attacker_id)
	var attack: AttackDefinition = _catalogue.attack_definition(action_id)
	var source: Dictionary = _source_definition(source_id)
	if attacker == null or attack == null or source.is_empty():
		result.reason = "The attacker, attack, or structure is missing."
		return result
	if _source_is_destroyed(source_id):
		result.reason = "That structure has already been destroyed or cleared."
		return result
	if not _state_store.state.can_unit_act(attacker_id) or attacker.is_incapacitated():
		result.reason = "This unit cannot attack now."
		return result
	if not _state_store.state.granted_action_ids_for_unit(attacker_id).has(action_id):
		result.reason = "The selected weapon does not grant this attack."
		return result
	var unavailable: String = ActionEconomyRules.attack_unavailable_reason(attacker, attack)
	if not unavailable.is_empty():
		result.reason = unavailable
		return result
	var target_tile: Vector2i = _source_target_tile(source_id, attacker.grid_position)
	var distance_feet: int = TacticalGridDistance.steps_between(attacker.grid_position, target_tile) * 5
	var range_penalty: int = 0
	if attack.attack_kind == AttackDefinition.ATTACK_MELEE:
		var reach_feet: int = maxi(5, attack.range_profile.reach_feet)
		if distance_feet > reach_feet:
			result.reason = "%s is beyond melee reach." % String(source.get("display_name", "Structure"))
			return result
	else:
		var increment_feet: int = maxi(5, attack.range_profile.range_increment_feet)
		var maximum_range: int = increment_feet * maxi(1, attack.range_profile.maximum_increments)
		if distance_feet > maximum_range:
			result.reason = "%s is beyond weapon range." % String(source.get("display_name", "Structure"))
			return result
		if not TacticalCombatGeometryQuery.cheap_has_line_of_sight(_state_store.state, _map_definition, attacker.grid_position, target_tile):
			result.reason = "No line of sight to the structure."
			return result
		var increment_index: int = maxi(0, int(ceil(
			float(distance_feet) / float(increment_feet)
		)) - 1)
		range_penalty = -2 * increment_index
	var definition_ac: int = int(source.get("armour_class", 5))
	var snapshot: ResolvedCharacterSnapshot = attacker.resolved_character
	var attack_bonus: int = snapshot.attack_bonus_for(attack) + range_penalty
	var cost_feet: int = attack.resolved_cost().resolved_normal_capacity_feet(attacker.action_budget.maximum_turn_capacity_feet)
	result.merge({
		"success": true,
		"reason": "",
		"display_name": String(source.get("display_name", "Structure")),
		"target_ac": definition_ac,
		"attack_bonus": attack_bonus,
		"range_penalty": range_penalty,
		"range_feet": distance_feet,
		"damage_dice_count": attack.damage_profile.dice_count,
		"damage_die_size": attack.damage_profile.die_size,
		"damage_bonus": snapshot.damage_bonus_for(attack) + attack.damage_profile.flat_bonus,
		"action_cost_feet": cost_feet,
		"expected_state_revision": _state_store.state.revision,
		"expected_geometry_revision": _state_store.state.geometry_revision(),
	})
	return result


func execute(preview_value: Dictionary) -> OperationResult:
	if not bool(preview_value.get("success", false)):
		return OperationResult.fail(&"structure_attack_preview_invalid", String(preview_value.get("reason", "Invalid structure attack.")))
	if _state_store.state.revision != int(preview_value.get("expected_state_revision", -1)) or _state_store.state.geometry_revision() != int(preview_value.get("expected_geometry_revision", -1)):
		return OperationResult.fail(&"structure_attack_preview_stale", "The battlefield changed; preview the structure attack again.")
	var refreshed: Dictionary = preview(StringName(preview_value.get("attacker_id")), StringName(preview_value.get("source_id")), StringName(preview_value.get("action_id")))
	if not bool(refreshed.get("success", false)):
		return OperationResult.fail(&"structure_attack_no_longer_legal", String(refreshed.get("reason", "The structure attack is no longer legal.")))
	var attacker: TacticalUnitState = _state_store.state.get_unit(StringName(refreshed.get("attacker_id")))
	var attack: AttackDefinition = _catalogue.attack_definition(StringName(refreshed.get("action_id")))
	var source_id: StringName = StringName(refreshed.get("source_id"))
	var dice_checkpoint: Dictionary = _dice_roller.snapshot_state()
	var attack_roll: int = _dice_roller.roll_die(20)
	var attack_total: int = attack_roll + int(refreshed.get("attack_bonus"))
	var hit: bool = attack_roll == 20 or (attack_roll != 1 and attack_total >= int(refreshed.get("target_ac")))
	var damage_results: Array[int] = []
	var damage: int = 0
	if hit:
		damage_results = _dice_roller.roll_dice(int(refreshed.get("damage_dice_count")), int(refreshed.get("damage_die_size")))
		for value: int in damage_results:
			damage += value
		damage = maxi(0, damage + int(refreshed.get("damage_bonus")))
	var budget_before: Dictionary = _budget_snapshot(attacker)
	var attacker_was_disabled: bool = attacker.is_disabled()
	var target_tile: Vector2i = _source_target_tile(
		source_id,
		attacker.grid_position
	)
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	var source_snapshot: Dictionary = environment.snapshot_source(source_id)
	var damage_result: Dictionary = {}
	var salvage_item_id: StringName = StringName("instance.salvage.%s" % source_id)
	var salvage_existed: bool = _state_store.state.get_item(salvage_item_id) != null
	var changes := TacticalChangeSet.new(&"structure_attacked", _state_store.state.revision)
	changes.stage(
		func() -> bool:
			if ActionEconomyRules.spend_attack(attacker, attack) < 0:
				return false
			attacker.set_facing(
				TacticalPerceptionRules.normalized_facing(
					target_tile - attacker.grid_position
				)
			)
			if hit:
				damage_result = environment.apply_damage_to_source(
					_map_definition,
					source_id,
					damage
				)
				if not bool(damage_result.get("success", false)):
					return false
				if not _create_salvage_if_needed(
					source_id,
					damage_result,
					salvage_item_id
				):
					return false
			if attacker_was_disabled:
				attacker.apply_disabled_strain()
			return true,
		func() -> void:
			_restore_budget(attacker, budget_before)
			environment.restore_source(source_id, source_snapshot)
			if not salvage_existed and _state_store.state.get_item(salvage_item_id) != null:
				_state_store.state.remove_item(salvage_item_id, false),
		"The structure attack could not be committed.",
		&"structure_attack_commit_failed"
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		_dice_roller.restore_state(dice_checkpoint)
		return committed
	_record_event(attacker, refreshed, attack_roll, attack_total, hit, damage_results, damage, damage_result)
	return OperationResult.ok({"hit": hit, "attack_total": attack_total, "damage": damage, "structure_damage": damage_result}, "%s %s %s." % [attacker.display_name, "damaged" if hit else "missed", String(refreshed.get("display_name"))])


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_snapshot(),
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
		"facing": unit.facing_direction,
		"life_state": unit.life_state_snapshot(),
	}


func _restore_budget(unit: TacticalUnitState, snapshot: Dictionary) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
	unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
	unit.action_budget.quick_action_available = bool(snapshot["quick"])
	unit.action_budget.restore_reaction_snapshot(snapshot.get("reaction", {}))
	unit.action_budget.ordinary_attack_available = bool(
		snapshot["ordinary_attack"]
	)
	unit.action_budget.ended_activation = bool(snapshot["ended"])
	var facing_value: Variant = snapshot.get("facing", unit.facing_direction)
	if facing_value is Vector2i:
		unit.facing_direction = Vector2i(facing_value)
	var life_value: Variant = snapshot.get("life_state", {})
	if life_value is Dictionary:
		unit.restore_life_state(life_value)


func _source_is_destroyed(source_id: StringName) -> bool:
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	if environment == null:
		return false
	var opening: TacticalOpeningState = environment.opening_state(source_id)
	if opening != null:
		return opening.state_id in [
			TacticalOpeningDefinition.STATE_BROKEN,
			TacticalOpeningDefinition.STATE_DESTROYED,
		]
	var structure: TacticalStructureState = environment.structure_state(source_id)
	return structure != null and structure.integrity_state_id in [
		TacticalStructureDefinition.STATE_DESTROYED,
		TacticalStructureDefinition.STATE_CLEARED,
	]


func _source_definition(source_id: StringName) -> Dictionary:
	var opening: TacticalOpeningDefinition = _map_definition.opening_definition(source_id)
	if opening != null:
		return {"display_name": opening.display_name, "armour_class": opening.armour_class}
	var structure: TacticalStructureDefinition = _map_definition.structure_definition(source_id)
	if structure != null:
		return {"display_name": structure.display_name, "armour_class": structure.armour_class}
	return {}


func _source_target_tile(source_id: StringName, attacker_tile: Vector2i) -> Vector2i:
	var opening: TacticalOpeningDefinition = _map_definition.opening_definition(source_id)
	if opening != null:
		return opening.first_tile if TacticalGridDistance.steps_between(attacker_tile, opening.first_tile) <= TacticalGridDistance.steps_between(attacker_tile, opening.second_tile) else opening.second_tile
	var structure: TacticalStructureDefinition = _map_definition.structure_definition(source_id)
	if structure != null:
		if structure.geometry_kind == TacticalStructureDefinition.GEOMETRY_EDGE:
			return structure.first_tile if TacticalGridDistance.steps_between(attacker_tile, structure.first_tile) <= TacticalGridDistance.steps_between(attacker_tile, structure.second_tile) else structure.second_tile
		if not structure.tile_coordinates.is_empty():
			return structure.tile_coordinates[0]
	return attacker_tile


func _create_salvage_if_needed(source_id: StringName, damage_result: Dictionary, salvage_item_id: StringName) -> bool:
	if not bool(damage_result.get("destroyed", false)):
		return true
	var runtime_opening: TacticalOpeningState = _state_store.state.environment_state.opening_state(source_id)
	var runtime_structure: TacticalStructureState = _state_store.state.environment_state.structure_state(source_id)
	if (runtime_opening != null and runtime_opening.salvage_generated) or (runtime_structure != null and runtime_structure.salvage_generated):
		return true
	var definition_id: StringName = StringName(damage_result.get("salvage_item_definition_id", &""))
	var quantity: int = maxi(0, int(damage_result.get("salvage_quantity", 0)))
	if definition_id.is_empty() or quantity <= 0:
		return true
	var item_definition: ItemDefinition = _catalogue.item_definition(definition_id)
	if item_definition == null:
		return true
	var location_tile: Vector2i = _source_target_tile(source_id, Vector2i.ZERO)
	var salvage := TacticalItemInstanceState.new(salvage_item_id, item_definition, quantity, 1.0, TacticalItemLocationState.ground(location_tile, "Structural salvage"))
	if _state_store.state.get_item(salvage_item_id) == null and not _state_store.state.add_item(salvage, _map_definition, false):
		return false
	if runtime_opening != null:
		runtime_opening.salvage_generated = true
	if runtime_structure != null:
		runtime_structure.salvage_generated = true
	return true


func _record_event(attacker: TacticalUnitState, preview_value: Dictionary, attack_roll: int, attack_total: int, hit: bool, damage_results: Array[int], damage: int, damage_result: Dictionary) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var phase: TacticalPhaseState = _state_store.state.phase_state
	var details: Array[String] = ["Attack: d20 %d + %d = %d vs AC %d" % [attack_roll, int(preview_value.get("attack_bonus")), attack_total, int(preview_value.get("target_ac"))]]
	if hit:
		details.append("Damage dice: %s; raw damage %d." % [str(damage_results), damage])
		details.append("Hardness %d; applied %d; HP %d → %d." % [int(damage_result.get("hardness", 0)), int(damage_result.get("applied_damage", 0)), int(damage_result.get("before_hp", 0)), int(damage_result.get("after_hp", 0))])
	_event_journal.call("record_event", &"structure_attacked", phase.round_number, phase.current_phase, "%s attacks %s — %s." % [attacker.display_name, String(preview_value.get("display_name")), "Hit" if hit else "Miss"], {"category": &"combat", "source_actor_id": attacker.unit_id, "action_id": StringName(preview_value.get("action_id")), "details": details})
