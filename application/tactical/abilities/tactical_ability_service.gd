class_name TacticalAbilityService
extends RefCounted

const TacticalGridDistance: Script = preload(
	"res://domain/tactical/tactical_grid_distance.gd"
)
const TacticalTeamRelations: Script = preload(
	"res://domain/tactical/tactical_team_relations.gd"
)

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


func ability_definition(action_id: StringName) -> TacticalAbilityDefinition:
	if _catalogue == null:
		return null
	return _catalogue.action_definition(action_id) as TacticalAbilityDefinition


func unavailable_reason(
		caster_id: StringName,
		action_id: StringName,
		target_id: StringName
) -> String:
	if _state_store == null or _state_store.state == null:
		return "Tactical state is unavailable."
	var caster: TacticalUnitState = _state_store.state.get_unit(caster_id)
	var target: TacticalUnitState = _state_store.state.get_unit(target_id)
	var ability: TacticalAbilityDefinition = ability_definition(action_id)
	if caster == null:
		return "The acting character does not exist."
	if target == null:
		return "The target does not exist."
	if ability == null:
		return "The selected ability is not implemented."
	if not ability.controller_can_use(caster.is_ai_controlled()):
		return "This controller cannot use that ability."
	if caster.resolved_character == null:
		return "The caster has no resolved character sheet."
	if not _state_store.state.granted_action_ids_for_unit(caster_id).has(action_id):
		return "The character does not possess that ability."
	for feature_id: StringName in ability.required_feature_ids:
		if not caster.resolved_character.has_trait(feature_id):
			return "The character lacks required feature %s." % feature_id
	var economy_reason: String = ActionEconomyRules.unavailable_reason(
		caster,
		ability.resolved_cost()
	)
	if not economy_reason.is_empty():
		return economy_reason
	if (
		ability.resource_cost > 0
		and not caster.can_spend_ability_resource(
			ability.resource_id,
			ability.resource_cost
		)
	):
		return "%s has no remaining use." % ability.display_name
	var target_reason: String = _targeting_reason(caster, target, ability)
	if not target_reason.is_empty():
		return target_reason
	var distance_feet: int = TacticalGridDistance.feet_between(
		caster.grid_position,
		target.grid_position
	)
	if distance_feet > ability.range_feet:
		return "%s is beyond %d feet." % [target.display_name, ability.range_feet]
	return ""


func execute(
		caster_id: StringName,
		action_id: StringName,
		target_id: StringName
) -> OperationResult:
	var reason: String = unavailable_reason(caster_id, action_id, target_id)
	if not reason.is_empty():
		return OperationResult.fail(&"ability_unavailable", reason)
	var state: TacticalState = _state_store.state
	var caster: TacticalUnitState = state.get_unit(caster_id)
	var target: TacticalUnitState = state.get_unit(target_id)
	var ability: TacticalAbilityDefinition = ability_definition(action_id)
	var dice_checkpoint: Dictionary = _dice_roller.snapshot_state()
	var resolved: Dictionary = _resolve_ability(target, ability)
	if resolved.is_empty():
		_dice_roller.restore_state(dice_checkpoint)
		return OperationResult.fail(
			&"ability_resolution_failed",
			"The ability could not be resolved."
		)

	var caster_budget_before: Dictionary = _budget_snapshot(caster)
	var caster_life_before: Dictionary = caster.life_state_snapshot()
	var target_life_before: Dictionary = target.life_state_snapshot()
	var caster_resources_before: Dictionary = caster.ability_uses_remaining.duplicate(true)
	var target_effects_before: Dictionary = _effect_snapshot(target)
	var caster_effects_before: Dictionary = _effect_snapshot(caster)
	var contract := TacticalInvalidationContract.attack(caster_id, target_id)
	contract.combat_events_changed = true
	var changes := TacticalChangeSet.new(
		&"tactical_ability_resolved",
		state.revision,
		contract
	)
	changes.stage(
		Callable(self, "_apply_cost_and_resource").bind(caster, ability),
		Callable(self, "_restore_caster_state").bind(
			caster,
			caster_budget_before,
			caster_life_before,
			caster_resources_before,
			caster_effects_before
		),
		"The ability cost could not be paid.",
		&"ability_cost_failed"
	)
	changes.stage(
		Callable(self, "_apply_resolved_effect").bind(
			caster,
			target,
			ability,
			resolved
		),
		Callable(self, "_restore_target_state").bind(
			target,
			target_life_before,
			target_effects_before
		),
		"The resolved ability effect could not be applied.",
		&"ability_effect_failed"
	)
	changes.after_commit(
		Callable(self, "_record_ability_event").bind(
			caster,
			target,
			ability,
			resolved
		)
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		_dice_roller.restore_state(dice_checkpoint)
		return committed
	return OperationResult.committed(
		resolved,
		_ability_result_message(caster, target, ability, resolved),
		_state_store.state.revision
	)


func has_ai_usable_special_abilities(unit_id: StringName) -> bool:
	if _state_store == null:
		return false
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	return (
		unit != null
		and unit.resolved_character != null
		and unit.resolved_character.has_trait(&"feature.mercy_bearer_spellcasting")
	)


func has_start_of_activation_work(unit_id: StringName) -> bool:
	if _state_store == null:
		return false
	var unit: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if unit == null:
		return false
	if unit.has_timed_effect(&"condition.hold_person"):
		return true
	# Only a Mercy-Bearer can be the source whose Sanctuary expires here. This
	# avoids scanning every tactical unit for ordinary guards.
	if (
		unit.resolved_character == null
		or not unit.resolved_character.has_trait(
			&"feature.mercy_bearer_spellcasting"
		)
	):
		return false
	for other: TacticalUnitState in _state_store.state.get_units():
		if (
			other != null
			and other.has_timed_effect(&"effect.sanctuary")
			and StringName(other.timed_effect_source_ids.get(
				&"effect.sanctuary", &""
			)) == unit_id
		):
			return true
	return false


func execute_best_ai_ability(unit_id: StringName) -> OperationResult:
	if _state_store == null or _catalogue == null:
		return null
	var caster: TacticalUnitState = _state_store.state.get_unit(unit_id)
	if caster == null or caster.resolved_character == null:
		return null
	if not caster.resolved_character.has_trait(&"feature.mercy_bearer_spellcasting"):
		return null

	var injured: Array[TacticalUnitState] = []
	for candidate: TacticalUnitState in _state_store.state.get_units():
		if (
			candidate != null
			and candidate.team_id == caster.team_id
			and not candidate.is_dead()
			and candidate.current_hp < candidate.maximum_hp
		):
			injured.append(candidate)
	injured.sort_custom(func(a: TacticalUnitState, b: TacticalUnitState) -> bool:
		return a.current_hp < b.current_hp
	)
	for ally: TacticalUnitState in injured:
		for healing_id: StringName in [
			&"action.mercy.cure_moderate_wounds",
			&"action.mercy.cure_light_wounds",
		]:
			if unavailable_reason(unit_id, healing_id, ally.unit_id).is_empty():
				return execute(unit_id, healing_id, ally.unit_id)

	var hostile: TacticalUnitState = _nearest_hostile(caster)
	if hostile != null:
		for action_id: StringName in [
			&"action.mercy.hold_person",
			&"action.mercy.command_kneel",
			&"action.mercy.mercys_rebuke",
		]:
			if unavailable_reason(unit_id, action_id, hostile.unit_id).is_empty():
				return execute(unit_id, action_id, hostile.unit_id)
	return null


func resolve_start_of_activation(unit_id: StringName) -> OperationResult:
	if _state_store == null or _dice_roller == null:
		return OperationResult.no_change(null, "No start-of-activation effects.")
	var state: TacticalState = _state_store.state
	var unit: TacticalUnitState = state.get_unit(unit_id)
	if unit == null:
		return OperationResult.fail(&"ability_unit_missing", "The unit is missing.")

	var sanctuary_targets: Array[TacticalUnitState] = []
	for other: TacticalUnitState in state.get_units():
		if (
			other != null
			and other.has_timed_effect(&"effect.sanctuary")
			and StringName(other.timed_effect_source_ids.get(
				&"effect.sanctuary", &""
			)) == unit_id
		):
			sanctuary_targets.append(other)

	var hold_save: Dictionary = {}
	var dice_checkpoint: Dictionary = _dice_roller.snapshot_state()
	if unit.has_timed_effect(&"condition.hold_person"):
		var dc: int = unit.timed_effect_value(&"condition.hold_person")
		var roll: int = _dice_roller.roll_die(20)
		var bonus: int = _save_bonus(unit, &"will")
		hold_save = {
			"roll": roll,
			"bonus": bonus,
			"total": roll + bonus,
			"dc": dc,
			"succeeded": roll + bonus >= dc,
			"source_id": StringName(unit.timed_effect_source_ids.get(
				&"condition.hold_person", &""
			)),
		}

	if sanctuary_targets.is_empty() and hold_save.is_empty():
		return OperationResult.no_change(null, "No start-of-activation effects.")

	var affected_units: Array[TacticalUnitState] = []
	affected_units.append_array(sanctuary_targets)
	if not hold_save.is_empty() and not affected_units.has(unit):
		affected_units.append(unit)
	var affected_ids: Array[StringName] = []
	var snapshots: Dictionary = {}
	for affected: TacticalUnitState in affected_units:
		affected_ids.append(affected.unit_id)
		snapshots[affected.unit_id] = {
			"effects": _effect_snapshot(affected),
			"budget": _budget_snapshot(affected),
		}

	var contract := TacticalInvalidationContract.token_status(affected_ids)
	contract.action_budget_changed = not hold_save.is_empty()
	contract.combat_events_changed = true
	var changes := TacticalChangeSet.new(
		&"ability_start_of_activation_resolved",
		state.revision,
		contract
	)
	changes.stage(
		Callable(self, "_apply_start_of_activation_effects").bind(
			unit,
			sanctuary_targets,
			hold_save
		),
		Callable(self, "_restore_start_of_activation_effects").bind(
			affected_units,
			snapshots
		),
		"Start-of-activation spell effects could not be resolved.",
		&"ability_start_effect_failed"
	)
	changes.after_commit(
		Callable(self, "_record_start_of_activation_event").bind(
			unit,
			sanctuary_targets.size(),
			hold_save
		)
	)
	var committed: OperationResult = _state_store.commit(changes, _map_definition)
	if not committed.success:
		_dice_roller.restore_state(dice_checkpoint)
		return committed
	if not hold_save.is_empty():
		return OperationResult.committed(
			hold_save,
			(
				"%s broke free of Hold Person." % unit.display_name
				if bool(hold_save.get("succeeded", false))
				else "%s remains held." % unit.display_name
			),
			state.revision
		)
	return OperationResult.committed(
		{"sanctuary_effects_expired": sanctuary_targets.size()},
		"Sanctuary expired at the beginning of %s's activation." % unit.display_name,
		state.revision
	)


func _apply_start_of_activation_effects(
		unit: TacticalUnitState,
		sanctuary_targets: Array[TacticalUnitState],
		hold_save: Dictionary
) -> bool:
	for target: TacticalUnitState in sanctuary_targets:
		target.clear_timed_effect(&"effect.sanctuary")
	if hold_save.is_empty():
		return true
	if unit.has_timed_effect(&"effect.resistance"):
		unit.clear_timed_effect(&"effect.resistance")
	if bool(hold_save.get("succeeded", false)):
		unit.clear_timed_effect(&"condition.hold_person")
		unit.action_budget.ended_activation = false
		unit.action_budget.ordinary_attack_available = true
	return true


func _restore_start_of_activation_effects(
		affected_units: Array[TacticalUnitState],
		snapshots: Dictionary
) -> void:
	for unit: TacticalUnitState in affected_units:
		var snapshot: Dictionary = snapshots.get(unit.unit_id, {}) as Dictionary
		if snapshot.is_empty():
			continue
		_restore_effect_snapshot(unit, snapshot.get("effects", {}) as Dictionary)
		_restore_budget(unit, snapshot.get("budget", {}) as Dictionary)


func _record_start_of_activation_event(
		unit: TacticalUnitState,
		sanctuary_expired_count: int,
		hold_save: Dictionary
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var details: Array[String] = []
	if sanctuary_expired_count > 0:
		details.append("Sanctuary effects expired: %d" % sanctuary_expired_count)
	if not hold_save.is_empty():
		details.append(
			"Hold Person Will save: d20 %d %+d = %d vs DC %d — %s"
			% [
				int(hold_save.get("roll", 0)),
				int(hold_save.get("bonus", 0)),
				int(hold_save.get("total", 0)),
				int(hold_save.get("dc", 0)),
				"Success" if bool(hold_save.get("succeeded", false)) else "Failure",
			]
		)
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"ability_start_of_activation_resolved",
		phase.round_number,
		phase.current_phase,
		"Start-of-activation effects resolved for %s." % unit.display_name,
		{
			"category": &"events",
			"source_actor_id": unit.unit_id,
			"details": details,
		}
	)


func _resolve_ability(
		target: TacticalUnitState,
		ability: TacticalAbilityDefinition
) -> Dictionary:
	var result: Dictionary = {
		"action_id": ability.id,
		"profile": ability.implementation_profile_id,
		"save_required": false,
		"save_roll": 0,
		"save_bonus": 0,
		"save_total": 0,
		"save_dc": ability.save_dc,
		"save_succeeded": false,
		"rolls": [],
		"amount": 0,
		"condition_applied": false,
	}
	if ability.implementation_profile_id in [
		TacticalAbilityDefinition.PROFILE_SAVE_CONDITION,
		TacticalAbilityDefinition.PROFILE_NONLETHAL_SAVE_DAMAGE,
	]:
		var save_roll: int = _dice_roller.roll_die(20)
		var save_bonus: int = _save_bonus(target, ability.save_type)
		result["save_required"] = true
		result["save_roll"] = save_roll
		result["save_bonus"] = save_bonus
		result["save_total"] = save_roll + save_bonus
		result["save_succeeded"] = save_roll + save_bonus >= ability.save_dc
	if ability.implementation_profile_id in [
		TacticalAbilityDefinition.PROFILE_HEAL,
		TacticalAbilityDefinition.PROFILE_NONLETHAL_SAVE_DAMAGE,
	]:
		var rolls: Array[int] = _dice_roller.roll_dice(
			ability.dice_count,
			ability.die_size
		)
		var amount: int = ability.flat_bonus
		for value: int in rolls:
			amount += value
		if (
			ability.implementation_profile_id
			== TacticalAbilityDefinition.PROFILE_NONLETHAL_SAVE_DAMAGE
			and bool(result["save_succeeded"])
			and ability.half_on_save
		):
			amount = int(floor(float(amount) * 0.5))
		result["rolls"] = rolls
		result["amount"] = maxi(0, amount)
	return result


func _apply_cost_and_resource(
		caster: TacticalUnitState,
		ability: TacticalAbilityDefinition
) -> bool:
	if ActionEconomyRules.spend(caster, ability.resolved_cost()) < 0:
		return false
	return caster.spend_ability_resource(
		ability.resource_id,
		ability.resource_cost
	)


func _apply_resolved_effect(
		caster: TacticalUnitState,
		target: TacticalUnitState,
		ability: TacticalAbilityDefinition,
		resolved: Dictionary
) -> bool:
	if target.has_timed_effect(&"effect.resistance") and bool(resolved.get(
		"save_required", false
	)):
		target.clear_timed_effect(&"effect.resistance")
	match ability.implementation_profile_id:
		TacticalAbilityDefinition.PROFILE_HEAL:
			resolved["applied_amount"] = target.apply_healing(int(resolved["amount"]))
		TacticalAbilityDefinition.PROFILE_SAVE_CONDITION:
			if not bool(resolved["save_succeeded"]):
				if ability.concentration:
					_break_existing_concentration(caster)
					caster.concentration_action_id = ability.id
				target.apply_timed_effect(
					ability.condition_id,
					maxi(1, ability.duration_rounds),
					caster.unit_id,
					ability.save_dc
				)
				resolved["condition_applied"] = true
		TacticalAbilityDefinition.PROFILE_NONLETHAL_SAVE_DAMAGE:
			resolved["applied_amount"] = target.apply_damage(
				int(resolved["amount"]),
				TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
			)
		TacticalAbilityDefinition.PROFILE_APPLY_BONUS:
			target.apply_timed_effect(
				ability.condition_id,
				maxi(1, ability.duration_rounds),
				caster.unit_id,
				ability.bonus_value
			)
		TacticalAbilityDefinition.PROFILE_LIGHT:
			for other: TacticalUnitState in _state_store.state.get_units():
				if StringName(other.timed_effect_source_ids.get(
					&"effect.light", &""
				)) == caster.unit_id:
					other.clear_timed_effect(&"effect.light")
			target.apply_timed_effect(
				&"effect.light",
				maxi(1, ability.duration_rounds),
				caster.unit_id,
				20
			)
		TacticalAbilityDefinition.PROFILE_DETECT_POISON:
			resolved["poison_detected"] = false
		_:
			return false
	return true


func _break_existing_concentration(caster: TacticalUnitState) -> void:
	if caster.concentration_action_id.is_empty():
		return
	for unit: TacticalUnitState in _state_store.state.get_units():
		var effect_ids: Array[StringName] = []
		for raw_effect_id: Variant in unit.timed_effect_source_ids.keys():
			if StringName(unit.timed_effect_source_ids.get(raw_effect_id, &"")) == caster.unit_id:
				effect_ids.append(StringName(raw_effect_id))
		for effect_id: StringName in effect_ids:
			if effect_id == &"condition.hold_person":
				unit.clear_timed_effect(effect_id)
	caster.concentration_action_id = &""


func _targeting_reason(
		caster: TacticalUnitState,
		target: TacticalUnitState,
		ability: TacticalAbilityDefinition
) -> String:
	if ability.targeting_rule_id == TacticalAbilityDefinition.TARGET_SELF:
		return "" if caster.unit_id == target.unit_id else "This ability targets the caster."
	if target.is_dead() and ability.implementation_profile_id != TacticalAbilityDefinition.PROFILE_DETECT_POISON:
		return "Dead targets are not eligible."
	if ability.implementation_profile_id == TacticalAbilityDefinition.PROFILE_HEAL:
		if not TacticalTeamRelations.are_allied(caster.team_id, target.team_id):
			return "Healing requires an allied living target."
	if ability.targeting_rule_id == TacticalAbilityDefinition.TARGET_SINGLE_HOSTILE_LIVING:
		if not TacticalTeamRelations.are_hostile(caster.team_id, target.team_id):
			return "This ability requires a hostile living target."
	if ability.targeting_rule_id in [
		TacticalAbilityDefinition.TARGET_SINGLE_HUMANOID,
		TacticalAbilityDefinition.TARGET_SINGLE_HOSTILE_HUMANOID,
	]:
		if (
			target.resolved_character == null
			or target.resolved_character.species_name != "Human"
		):
			return "Hold Person requires a living humanoid."
	if ability.targeting_rule_id == TacticalAbilityDefinition.TARGET_SINGLE_HOSTILE_HUMANOID:
		if not TacticalTeamRelations.are_hostile(caster.team_id, target.team_id):
			return "Hold Person requires a hostile humanoid."
	if ability.effect_tags.has(&"biological_only") and not target.has_role_tag(&"biological"):
		return "This ability affects only biological living creatures."
	return ""


func _save_bonus(unit: TacticalUnitState, save_type: StringName) -> int:
	return unit.saving_throw_bonus(save_type) if unit != null else 0


func _nearest_hostile(caster: TacticalUnitState) -> TacticalUnitState:
	var best: TacticalUnitState = null
	var best_distance: int = 1_000_000
	for candidate: TacticalUnitState in _state_store.state.get_units():
		if (
			candidate == null
			or candidate.is_defeated()
			or not TacticalTeamRelations.are_hostile(
				caster.team_id,
				candidate.team_id
			)
		):
			continue
		var distance: int = TacticalGridDistance.feet_between(
			caster.grid_position,
			candidate.grid_position
		)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_snapshot(),
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
	}


func _restore_budget(unit: TacticalUnitState, snapshot: Dictionary) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
	unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
	unit.action_budget.quick_action_available = bool(snapshot["quick"])
	unit.action_budget.restore_reaction_snapshot(snapshot["reaction"])
	unit.action_budget.ordinary_attack_available = bool(snapshot["ordinary_attack"])
	unit.action_budget.ended_activation = bool(snapshot["ended"])


func _effect_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"rounds": unit.timed_effect_rounds.duplicate(true),
		"sources": unit.timed_effect_source_ids.duplicate(true),
		"values": unit.timed_effect_values.duplicate(true),
		"concentration": unit.concentration_action_id,
		"kneeling": unit.kneeling,
		"incapacitated": unit.action_incapacitated,
	}


func _restore_effect_snapshot(unit: TacticalUnitState, snapshot: Dictionary) -> void:
	unit.timed_effect_rounds = (snapshot["rounds"] as Dictionary).duplicate(true)
	unit.timed_effect_source_ids = (snapshot["sources"] as Dictionary).duplicate(true)
	unit.timed_effect_values = (snapshot["values"] as Dictionary).duplicate(true)
	unit.concentration_action_id = StringName(snapshot["concentration"])
	unit.kneeling = bool(snapshot["kneeling"])
	unit.action_incapacitated = bool(snapshot["incapacitated"])


func _restore_caster_state(
		caster: TacticalUnitState,
		budget_snapshot: Dictionary,
		life_snapshot: Dictionary,
		resource_snapshot: Dictionary,
		effect_snapshot: Dictionary
) -> void:
	_restore_budget(caster, budget_snapshot)
	caster.restore_life_state(life_snapshot)
	caster.restore_ability_resources(resource_snapshot)
	_restore_effect_snapshot(caster, effect_snapshot)


func _restore_target_state(
		target: TacticalUnitState,
		life_snapshot: Dictionary,
		effect_snapshot: Dictionary
) -> void:
	target.restore_life_state(life_snapshot)
	_restore_effect_snapshot(target, effect_snapshot)


func _record_ability_event(
		caster: TacticalUnitState,
		target: TacticalUnitState,
		ability: TacticalAbilityDefinition,
		resolved: Dictionary
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var details: Array[String] = [
		"Action: %s" % ability.display_name,
		"Cost: %s" % ability.cost_label(),
	]
	if bool(resolved.get("save_required", false)):
		details.append(
			"%s save: d20 %d %+d = %d vs DC %d — %s"
			% [
				String(ability.save_type).capitalize(),
				int(resolved["save_roll"]),
				int(resolved["save_bonus"]),
				int(resolved["save_total"]),
				int(resolved["save_dc"]),
				"Success" if bool(resolved["save_succeeded"]) else "Failure",
			]
		)
	if int(resolved.get("amount", 0)) > 0:
		details.append(
			"Roll: %s %+d = %d"
			% [
				str(resolved.get("rolls", [])),
				ability.flat_bonus,
				int(resolved["amount"]),
			]
		)
	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"tactical_ability_resolved",
		phase.round_number,
		phase.current_phase,
		_ability_result_message(caster, target, ability, resolved),
		{
			"category": &"rolls",
			"source_actor_id": caster.unit_id,
			"target_actor_id": target.unit_id,
			"details": details,
		}
	)


func _ability_result_message(
		caster: TacticalUnitState,
		target: TacticalUnitState,
		ability: TacticalAbilityDefinition,
		resolved: Dictionary
) -> String:
	if ability.implementation_profile_id == TacticalAbilityDefinition.PROFILE_HEAL:
		return "%s used %s on %s, restoring %d HP." % [
			caster.display_name,
			ability.display_name,
			target.display_name,
			int(resolved.get("applied_amount", 0)),
		]
	if bool(resolved.get("save_required", false)):
		return "%s used %s on %s: %s." % [
			caster.display_name,
			ability.display_name,
			target.display_name,
			"saved" if bool(resolved["save_succeeded"]) else "failed save",
		]
	return "%s used %s on %s." % [
		caster.display_name,
		ability.display_name,
		target.display_name,
	]
