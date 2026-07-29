class_name AttackHandler
extends RefCounted

const ATTACK_RESOLUTION_SCRIPT: Script = preload(
	"res://application/tactical/combat/tactical_attack_resolution.gd"
)
const ROLL_RECORD_SCRIPT: Script = preload(
	"res://domain/tactical/events/tactical_roll_record.gd"
)
const MODIFIER_RECORD_SCRIPT: Script = preload(
	"res://domain/tactical/events/tactical_modifier_record.gd"
)
const EFFECT_RECORD_SCRIPT: Script = preload(
	"res://domain/tactical/events/tactical_effect_record.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue
var _event_journal: RefCounted
var _preview_query: RefCounted
var _dice_roller: RefCounted


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		event_journal: RefCounted,
		preview_query: RefCounted,
		dice_roller: RefCounted
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_event_journal = event_journal
	_preview_query = preview_query
	_dice_roller = dice_roller


func execute_preview(preview) -> OperationResult:
	if preview == null or not bool(preview.get("success")):
		return OperationResult.fail(
			&"attack_preview_invalid",
			"A valid attack preview is required."
		)
	if _state_store == null or _preview_query == null or _dice_roller == null:
		return OperationResult.fail(
			&"attack_service_missing",
			"Combat resolution services are unavailable."
		)
	var state: TacticalState = _state_store.state
	if state.revision != int(preview.get("expected_state_revision")):
		return OperationResult.fail(
			&"attack_preview_stale",
			"The tactical state changed. Preview the attack again."
		)

	var refreshed = _preview_query.call(
		"execute",
		StringName(preview.get("attacker_id")),
		StringName(preview.get("target_id")),
		StringName(preview.get("action_id")),
		int(preview.get("power_attack_value")),
		StringName(preview.get("damage_channel"))
	)
	if refreshed == null or not bool(refreshed.get("success")):
		return OperationResult.fail(
			&"attack_no_longer_legal",
			String(refreshed.get("reason")) if refreshed != null else "The attack is no longer legal."
		)

	var attacker: TacticalUnitState = state.get_unit(
		StringName(refreshed.get("attacker_id"))
	)
	var target: TacticalUnitState = state.get_unit(
		StringName(refreshed.get("target_id"))
	)
	var attack: AttackDefinition = _catalogue.attack_definition(
		StringName(refreshed.get("action_id"))
	)
	if attacker == null or target == null or attack == null:
		return OperationResult.fail(
			&"attack_state_missing",
			"The attacker, target, or attack definition is missing."
		)

	var resolution = ATTACK_RESOLUTION_SCRIPT.new()
	resolution.preview = refreshed
	var budget_snapshot: Dictionary = _budget_snapshot(attacker)
	var target_hp_before: int = target.current_hp
	var target_nonlethal_before: int = target.nonlethal_damage
	var target_combat_state_before: StringName = target.combat_state
	resolution.capacity_before = attacker.action_budget.remaining_turn_capacity_feet
	resolution.target_hp_before = target_hp_before
	resolution.target_hp_after = target_hp_before
	resolution.target_nonlethal_before = target_nonlethal_before
	resolution.target_nonlethal_after = target_nonlethal_before
	resolution.target_combat_state_before = target_combat_state_before
	resolution.target_combat_state_after = target_combat_state_before

	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"attack_resolved",
		state.revision
	)
	changes.stage(
		Callable(self, "_spend_attack_cost").bind(attacker, attack),
		Callable(self, "_restore_budget").bind(attacker, budget_snapshot),
		"The attack action cost could not be paid.",
		&"attack_cost_failed"
	)
	changes.stage(
		Callable(self, "_roll_and_apply_attack").bind(
			refreshed,
			attack,
			target,
			resolution
		),
		Callable(self, "_restore_attack_resolution").bind(
			target,
			target_hp_before,
			target_nonlethal_before,
			resolution
		),
		"The attack roll or damage could not be resolved.",
		&"attack_resolution_failed"
	)
	changes.require(
		Callable(self, "_validate_attack_result").bind(
			attacker,
			target,
			resolution,
			target_hp_before,
			target_nonlethal_before
		),
		"The committed attack state is inconsistent.",
		&"attack_invariant_failed"
	)
	changes.after_commit(
		Callable(self, "_record_attack_event").bind(
			attacker,
			target,
			attack,
			resolution,
			budget_snapshot
		)
	)

	var committed: OperationResult = _state_store.commit(
		changes,
		_map_definition
	)
	if not committed.success:
		return committed

	resolution.capacity_after = attacker.action_budget.remaining_turn_capacity_feet
	resolution.target_hp_after = target.current_hp
	resolution.target_nonlethal_after = target.nonlethal_damage
	return OperationResult.ok(
		resolution,
		_result_message(attacker, target, attack, resolution)
	)


func _roll_and_apply_attack(
		preview,
		attack: AttackDefinition,
		target: TacticalUnitState,
		resolution
) -> bool:
	resolution.attack_roll = int(_dice_roller.call("roll_die", 20))
	resolution.natural_one = resolution.attack_roll == 1
	resolution.natural_twenty = resolution.attack_roll == 20
	resolution.attack_total = (
		resolution.attack_roll + int(preview.get("attack_bonus"))
	)
	resolution.hit = (
		resolution.natural_twenty
		or (
			not resolution.natural_one
			and resolution.attack_total >= target.armour_class
		)
	)
	resolution.damage_channel = StringName(preview.get("damage_channel"))
	resolution.critical_threat = (
		resolution.hit
		and resolution.attack_roll >= attack.critical_threat_minimum
	)

	if resolution.critical_threat:
		resolution.confirmation_roll = int(_dice_roller.call("roll_die", 20))
		resolution.confirmation_total = (
			resolution.confirmation_roll
			+ int(preview.get("attack_bonus"))
		)
		resolution.critical_confirmed = (
			resolution.confirmation_roll == 20
			or (
				resolution.confirmation_roll != 1
				and resolution.confirmation_total >= target.armour_class
			)
		)

	if resolution.hit:
		var raw_results: Variant = _dice_roller.call(
			"roll_dice",
			int(preview.get("damage_dice_count")),
			int(preview.get("damage_die_size"))
		)
		if raw_results is Array:
			for value: Variant in raw_results:
				resolution.damage_die_results.append(int(value))
		var rolled_damage: int = 0
		for die_result: int in resolution.damage_die_results:
			rolled_damage += die_result
		resolution.base_damage = maxi(
			0,
			rolled_damage + int(preview.get("damage_bonus"))
		)
		resolution.final_damage = resolution.base_damage
		if resolution.critical_confirmed:
			resolution.final_damage *= attack.critical_multiplier

	resolution.applied_damage = target.apply_damage(
		resolution.final_damage,
		resolution.damage_channel
	)
	resolution.target_hp_after = target.current_hp
	resolution.target_nonlethal_after = target.nonlethal_damage
	resolution.target_combat_state_after = target.combat_state
	resolution.target_became_defeated = (
		resolution.target_combat_state_before
		!= TacticalUnitState.COMBAT_STATE_DEFEATED
		and target.is_defeated()
	)
	return true


func _restore_attack_resolution(
		target: TacticalUnitState,
		hp_before: int,
		nonlethal_before: int,
		resolution
) -> void:
	target.restore_damage_state(hp_before, nonlethal_before)
	resolution.attack_roll = 0
	resolution.attack_total = 0
	resolution.natural_one = false
	resolution.natural_twenty = false
	resolution.hit = false
	resolution.critical_threat = false
	resolution.confirmation_roll = 0
	resolution.confirmation_total = 0
	resolution.critical_confirmed = false
	resolution.damage_die_results.clear()
	resolution.base_damage = 0
	resolution.final_damage = 0
	resolution.applied_damage = 0
	resolution.damage_channel = TacticalUnitState.DAMAGE_CHANNEL_LETHAL
	resolution.target_hp_after = hp_before
	resolution.target_nonlethal_before = nonlethal_before
	resolution.target_nonlethal_after = nonlethal_before
	resolution.target_combat_state_after = target.combat_state
	resolution.target_became_defeated = false


func _spend_attack_cost(
		attacker: TacticalUnitState,
		attack: AttackDefinition
) -> bool:
	return ActionEconomyRules.spend_attack(attacker, attack) >= 0


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_available,
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
	}


func _restore_budget(unit: TacticalUnitState, snapshot: Dictionary) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
	unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
	unit.action_budget.quick_action_available = bool(snapshot["quick"])
	unit.action_budget.reaction_available = bool(snapshot["reaction"])
	unit.action_budget.ordinary_attack_available = bool(
		snapshot["ordinary_attack"]
	)
	unit.action_budget.ended_activation = bool(snapshot["ended"])


func _validate_attack_result(
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		resolution,
		target_hp_before: int,
		target_nonlethal_before: int
) -> String:
	if attacker.action_budget.remaining_turn_capacity_feet < 0:
		return "Attack expenditure produced negative capacity."
	if attacker.action_budget.ordinary_attack_available:
		return "A committed normal attack did not consume its attack allowance."

	var damage_channel: StringName = StringName(
		resolution.get("damage_channel")
	)
	var final_damage: int = int(resolution.get("final_damage"))
	var expected_hp: int = target_hp_before
	var expected_nonlethal: int = target_nonlethal_before
	if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL:
		expected_nonlethal += final_damage
	else:
		expected_hp = maxi(0, target_hp_before - final_damage)

	if target.current_hp != expected_hp:
		return "Attack damage did not produce the expected target HP."
	if target.nonlethal_damage != expected_nonlethal:
		return "Attack damage did not produce the expected nonlethal total."
	if target.current_hp <= 0 and not target.is_defeated():
		return "A target at 0 HP was not marked Defeated."
	if target.current_hp > 0 and target.is_defeated():
		return "A target with remaining HP was incorrectly marked Defeated."
	return ""


func _record_attack_event(
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		attack: AttackDefinition,
		resolution,
		budget_snapshot: Dictionary
) -> void:
	if _event_journal == null or not _event_journal.has_method("record_event"):
		return
	var preview = resolution.get("preview")
	var damage_channel: StringName = StringName(
		resolution.get("damage_channel")
	)
	var damage_channel_label: String = _damage_channel_label(damage_channel)
	var attack_modifiers: Array = _attack_modifier_records(
		attacker,
		attack,
		int(preview.get("power_attack_value")),
		int(preview.get("nonlethal_attack_penalty"))
	)
	var roll_records: Array = [
		ROLL_RECORD_SCRIPT.create(
			&"attack_roll",
			"d20",
			[resolution.get("attack_roll")],
			int(resolution.get("attack_total")),
			target.armour_class,
			&"hit" if bool(resolution.get("hit")) else &"miss",
			attack_modifiers
		),
	]
	if bool(resolution.get("critical_threat")):
		roll_records.append(
			ROLL_RECORD_SCRIPT.create(
				&"critical_confirmation",
				"d20",
				[resolution.get("confirmation_roll")],
				int(resolution.get("confirmation_total")),
				target.armour_class,
				(
					&"confirmed"
					if bool(resolution.get("critical_confirmed"))
					else &"not_confirmed"
				),
				attack_modifiers
			)
		)
	if bool(resolution.get("hit")):
		roll_records.append(
			ROLL_RECORD_SCRIPT.create(
				&"damage_roll",
				"%dd%d" % [
					int(preview.get("damage_dice_count")),
					int(preview.get("damage_die_size")),
				],
				resolution.get("damage_die_results"),
				int(resolution.get("base_damage")),
				-1,
				(
					&"critical_nonlethal_damage"
					if (
						damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
						and bool(resolution.get("critical_confirmed"))
					)
					else &"nonlethal_damage"
					if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
					else &"critical_damage"
					if bool(resolution.get("critical_confirmed"))
					else &"damage"
				),
				_damage_modifier_records(
					attacker,
					attack,
					int(preview.get("power_attack_value"))
				)
			)
		)

	var details: Array[String] = [
		"Attack: %s" % attack.display_name,
		"Damage channel: %s" % damage_channel_label,
		"Target Armour Class: %d" % target.armour_class,
		"Power Attack: %d" % int(preview.get("power_attack_value")),
		"Range: %d ft" % int(preview.get("range_feet")),
		"Action cost: %d ft" % int(preview.get("action_cost_feet")),
		"Capacity: %d → %d ft" % [
			int(budget_snapshot.get("remaining", 0)),
			attacker.action_budget.remaining_turn_capacity_feet,
		],
	]
	if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL:
		if bool(preview.get("nonlethal_penalty_ignored")):
			details.append(
				"Take Them Alive: no −4 nonlethal penalty with this blunt weapon."
			)
		else:
			details.append("Nonlethal attack penalty: −4.")
	if bool(resolution.get("natural_one")):
		details.append("Natural 1: automatic miss.")
	elif bool(resolution.get("natural_twenty")):
		details.append("Natural 20: automatic hit and critical threat.")
	if bool(resolution.get("hit")):
		if bool(resolution.get("critical_confirmed")):
			details.append(
				"Critical damage: %d × %d = %d %s."
				% [
					int(resolution.get("base_damage")),
					attack.critical_multiplier,
					int(resolution.get("final_damage")),
					String(preview.get("damage_type")).replace("_", "/"),
				]
			)
		else:
			details.append(
				"Damage: %d %s."
				% [
					int(resolution.get("final_damage")),
					String(preview.get("damage_type")).replace("_", "/"),
				]
			)

	if bool(resolution.get("target_became_defeated")):
		details.append(
			"%s reached 0 HP and became Defeated." % target.display_name
		)

	var effect_records: Array = []
	if bool(resolution.get("hit")):
		if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL:
			effect_records.append(
				EFFECT_RECORD_SCRIPT.create(
					"%s Nonlethal Damage" % target.display_name,
					&"nonlethal_damage",
					int(resolution.get("target_nonlethal_before")),
					target.nonlethal_damage,
					attack.id
				)
			)
		else:
			effect_records.append(
				EFFECT_RECORD_SCRIPT.create(
					"%s HP" % target.display_name,
					&"hit_points",
					int(resolution.get("target_hp_before")),
					target.current_hp,
					attack.id
				)
			)

	if bool(resolution.get("target_became_defeated")):
		effect_records.append(
			EFFECT_RECORD_SCRIPT.create(
				"%s Combat State" % target.display_name,
				&"combat_state",
				StringName(str(resolution.get("target_combat_state_before"))),
				target.combat_state,
				attack.id
			)
		)

	var damage_resource_change: Dictionary = {
		"resource": &"hit_points",
		"before": int(resolution.get("target_hp_before")),
		"after": target.current_hp,
	}
	if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL:
		damage_resource_change = {
			"resource": &"nonlethal_damage",
			"before": int(resolution.get("target_nonlethal_before")),
			"after": target.nonlethal_damage,
		}

	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"attack_resolved",
		phase.round_number,
		phase.current_phase,
		"%s attacks %s with %s — %s."
		% [
			attacker.display_name,
			target.display_name,
			attack.display_name,
			String(resolution.call("outcome_label")),
		],
		{
			"category": &"combat",
			"source_actor_id": attacker.unit_id,
			"target_actor_ids": [target.unit_id],
			"action_id": attack.id,
			"item_id": StringName(preview.get("source_item_id")),
			"details": details,
			"roll_records": roll_records,
			"effect_records": effect_records,
			"resource_changes": [
				{
					"resource": &"normal_capacity",
					"before": int(budget_snapshot.get("remaining", 0)),
					"after": attacker.action_budget.remaining_turn_capacity_feet,
				},
				{
					"resource": &"ordinary_attack",
					"before": bool(
						budget_snapshot.get("ordinary_attack", true)
					),
					"after": (
						attacker.action_budget.ordinary_attack_available
					),
				},
				damage_resource_change,
			],
			"metadata": {
				"power_attack": int(preview.get("power_attack_value")),
				"hit": bool(resolution.get("hit")),
				"critical_threat": bool(resolution.get("critical_threat")),
				"critical_confirmed": bool(resolution.get("critical_confirmed")),
				"critical_multiplier": attack.critical_multiplier,
				"damage_type": preview.get("damage_type"),
				"damage_channel": damage_channel,
				"nonlethal_attack_penalty": int(
					preview.get("nonlethal_attack_penalty")
				),
				"nonlethal_penalty_ignored": bool(
					preview.get("nonlethal_penalty_ignored")
				),
				"ordinary_attack_available_after": (
					attacker.action_budget.ordinary_attack_available
				),
				"final_damage": int(resolution.get("final_damage")),
				"applied_damage": int(resolution.get("applied_damage")),
				"target_combat_state": target.combat_state,
				"target_became_defeated": bool(
					resolution.get("target_became_defeated")
				),
			},
		}
	)


func _attack_modifier_records(
		attacker: TacticalUnitState,
		attack: AttackDefinition,
		power_attack_value: int,
		nonlethal_attack_penalty: int
) -> Array:
	var snapshot: ResolvedCharacterSnapshot = attacker.resolved_character
	var ability_abbreviation: String = _ability_abbreviation(attack.attack_ability)
	var result: Array = [
		MODIFIER_RECORD_SCRIPT.create(
			"Base Attack Bonus",
			snapshot.stat_value(&"base_attack_bonus"),
			&"base_attack_bonus",
			&"character"
		),
		MODIFIER_RECORD_SCRIPT.create(
			_ability_label(ability_abbreviation),
			snapshot.ability_modifier(ability_abbreviation),
			StringName("ability.%s" % ability_abbreviation.to_lower()),
			&"ability"
		),
	]
	if attack.attack_bonus_modifier != 0:
		result.append(
			MODIFIER_RECORD_SCRIPT.create(
				attack.display_name,
				attack.attack_bonus_modifier,
				attack.id,
				&"weapon"
			)
		)
	if nonlethal_attack_penalty != 0:
		result.append(
			MODIFIER_RECORD_SCRIPT.create(
				"Nonlethal attack",
				nonlethal_attack_penalty,
				&"rule.nonlethal_attack",
				&"option"
			)
		)
	if power_attack_value > 0:
		result.append(
			MODIFIER_RECORD_SCRIPT.create(
				"Power Attack",
				-power_attack_value,
				&"rule.power_attack",
				&"option"
			)
		)
	return result


func _damage_modifier_records(
		attacker: TacticalUnitState,
		attack: AttackDefinition,
		power_attack_value: int
) -> Array:
	var snapshot: ResolvedCharacterSnapshot = attacker.resolved_character
	var damage_ability: StringName = attack.damage_ability
	if damage_ability.is_empty():
		damage_ability = attack.attack_ability
	var ability_abbreviation: String = _ability_abbreviation(damage_ability)
	var result: Array = [
		MODIFIER_RECORD_SCRIPT.create(
			_ability_label(ability_abbreviation),
			snapshot.ability_modifier(ability_abbreviation),
			StringName("ability.%s" % ability_abbreviation.to_lower()),
			&"ability"
		),
	]
	if attack.damage_bonus_modifier != 0:
		result.append(
			MODIFIER_RECORD_SCRIPT.create(
				attack.display_name,
				attack.damage_bonus_modifier,
				attack.id,
				&"weapon"
			)
		)
	if attack.damage_profile != null and attack.damage_profile.flat_bonus != 0:
		result.append(
			MODIFIER_RECORD_SCRIPT.create(
				"Weapon profile",
				attack.damage_profile.flat_bonus,
				attack.id,
				&"weapon"
			)
		)
	if power_attack_value > 0:
		result.append(
			MODIFIER_RECORD_SCRIPT.create(
				"Power Attack",
				power_attack_value,
				&"rule.power_attack",
				&"option"
			)
		)
	return result


func _ability_abbreviation(ability_id: StringName) -> String:
	match ability_id:
		&"strength":
			return "STR"
		&"dexterity":
			return "DEX"
		&"constitution":
			return "CON"
		&"intelligence":
			return "INT"
		&"wisdom":
			return "WIS"
		&"charisma":
			return "CHA"
		_:
			return String(ability_id).left(3).to_upper()


func _ability_label(abbreviation: String) -> String:
	match abbreviation:
		"STR":
			return "Strength"
		"DEX":
			return "Dexterity"
		"CON":
			return "Constitution"
		"INT":
			return "Intelligence"
		"WIS":
			return "Wisdom"
		"CHA":
			return "Charisma"
		_:
			return abbreviation


func _damage_channel_label(damage_channel: StringName) -> String:
	return (
		"Nonlethal"
		if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
		else "Lethal"
	)


func _result_message(
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		attack: AttackDefinition,
		resolution
) -> String:
	var result: String = "%s used %s against %s: %s"
	result = result % [
		attacker.display_name,
		attack.display_name,
		target.display_name,
		String(resolution.call("outcome_label")),
	]
	if bool(resolution.get("hit")):
		result += " for %d %s damage" % [
			int(resolution.get("final_damage")),
			_damage_channel_label(
				StringName(resolution.get("damage_channel"))
			).to_lower(),
		]
	return result + "."
