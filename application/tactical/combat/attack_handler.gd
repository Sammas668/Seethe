class_name AttackHandler
extends RefCounted

signal damage_committed(event: Dictionary)

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
var _detection_service: TacticalDetectionService


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		event_journal: RefCounted,
		preview_query: RefCounted,
		dice_roller: RefCounted,
		detection_service: TacticalDetectionService = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_event_journal = event_journal
	_preview_query = preview_query
	_dice_roller = dice_roller
	_detection_service = detection_service


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
	if state.geometry_revision() != int(preview.get("expected_geometry_revision")):
		return OperationResult.fail(
			&"attack_geometry_stale",
			"The battlefield geometry changed. Preview the attack again."
		)

	var refreshed = _preview_query.call(
		"execute",
		StringName(preview.get("attacker_id")),
		StringName(preview.get("target_id")),
		StringName(preview.get("action_id")),
		int(preview.get("power_attack_value")),
		StringName(preview.get("damage_channel")),
		preview.get("attack_origin_override"),
		preview.get("target_position_override"),
		preview.get("reaction_context")
	)
	if refreshed == null or not bool(refreshed.get("success")):
		return OperationResult.fail(
			&"attack_no_longer_legal",
			str(refreshed.get("reason")) if refreshed != null else "The attack is no longer legal."
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
	var is_reaction: bool = StringName(refreshed.get("action_source")) == &"reaction"
	if attacker == null or target == null or attack == null:
		return OperationResult.fail(
			&"attack_state_missing",
			"The attacker, target, or attack definition is missing."
		)

	var budget_snapshot: Dictionary = _budget_snapshot(attacker)
	var attacker_was_disabled: bool = attacker.is_disabled()
	var target_hp_before: int = target.current_hp
	var target_nonlethal_before: int = target.nonlethal_damage
	var target_combat_state_before: StringName = target.combat_state
	var target_life_before: Dictionary = target.life_state_snapshot()
	var dice_checkpoint: Dictionary = _dice_roller.call("snapshot_state")

	# Randomness is resolved before the TacticalChangeSet begins. The staged
	# mutations below are deterministic and only apply the already-resolved
	# outcome. If commit fails, the dice checkpoint is restored.
	var resolution = _resolve_roll_outcome(
		refreshed,
		attack,
		target,
		target_hp_before,
		target_nonlethal_before,
		target_combat_state_before
	)
	if resolution == null:
		_dice_roller.call("restore_state", dice_checkpoint)
		return OperationResult.fail(
			&"attack_roll_resolution_failed",
			"The attack dice could not be resolved."
		)

	var cover_source_id: StringName = StringName(
		refreshed.get("primary_cover_source_id")
	)
	var cover_source_snapshot: Dictionary = (
		state.environment_state.snapshot_source(cover_source_id)
		if (
			state.environment_state != null
			and not cover_source_id.is_empty()
			and bool(resolution.get("missed_due_to_cover"))
		)
		else {}
	)
	var cover_salvage_item_id := StringName("instance.salvage.%s" % cover_source_id)
	var cover_salvage_existed_before: bool = state.get_item(cover_salvage_item_id) != null

	var alert_resolution: TacticalDetectionResolution = null
	var alert_snapshot: Dictionary = {}
	if _detection_service != null:
		alert_resolution = _detection_service.prepare_hostile_action_resolution(
			attacker.unit_id,
			target.unit_id
		)
		alert_snapshot = _detection_service.snapshot_for_resolution(alert_resolution)

	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"attack_resolved",
		state.revision
	)
	if is_reaction:
		changes.stage(
			Callable(self, "_spend_reaction_and_face").bind(
				attacker,
				Vector2i(refreshed.get("target_position_override"))
				if refreshed.get("target_position_override") is Vector2i
				else target.grid_position
			),
			Callable(self, "_restore_budget").bind(attacker, budget_snapshot),
			"The Reaction could not be spent.",
			&"reaction_cost_failed"
		)
	else:
		changes.stage(
			Callable(self, "_spend_attack_cost_and_face").bind(
				attacker,
				attack,
				target.grid_position
			),
			Callable(self, "_restore_budget").bind(attacker, budget_snapshot),
			"The attack action cost could not be paid.",
			&"attack_cost_failed"
		)
	changes.stage(
		Callable(self, "_apply_resolved_attack").bind(
			target,
			resolution
		),
		Callable(self, "_restore_attack_resolution").bind(
			target,
			target_life_before,
			resolution
		),
		"The resolved attack damage could not be applied.",
		&"attack_resolution_failed"
	)
	if (
		bool(resolution.get("missed_due_to_cover"))
		and StringName(refreshed.get("primary_cover_source_kind")) in [
			&"opening", &"structure"
		]
	):
		changes.stage(
			Callable(self, "_apply_cover_source_damage_and_salvage").bind(
				resolution,
				target.grid_position,
				cover_salvage_item_id
			),
			Callable(self, "_restore_cover_source_damage_and_salvage").bind(
				cover_source_id,
				cover_source_snapshot,
				cover_salvage_item_id,
				cover_salvage_existed_before
			),
			"The protecting structure could not receive the cover hit.",
			&"cover_source_damage_failed"
		)
	if attacker_was_disabled:
		changes.stage(
			Callable(self, "_apply_disabled_attack_strain").bind(attacker),
			Callable(attacker, "restore_life_state").bind(
				budget_snapshot.get("life_state", {})
			),
			"Disabled attack strain could not be applied.",
			&"disabled_attack_strain_failed"
		)
	if _detection_service != null and alert_resolution != null:
		changes.stage(
			Callable(_detection_service, "apply_resolution").bind(alert_resolution),
			Callable(_detection_service, "restore_resolution_snapshot").bind(alert_snapshot),
			"The attack alert transition could not be committed.",
			&"attack_alert_failed"
		)
	changes.require(
		Callable(self, "_validate_attack_result").bind(
			attacker,
			target,
			resolution,
			target_hp_before,
			target_nonlethal_before,
			is_reaction
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
	if _detection_service != null and alert_resolution != null:
		changes.after_commit(
			Callable(_detection_service, "record_resolution").bind(alert_resolution)
		)

	var committed: OperationResult = _state_store.commit(
		changes,
		_map_definition
	)
	if not committed.success:
		_dice_roller.call("restore_state", dice_checkpoint)
		return committed

	resolution.capacity_after = attacker.action_budget.remaining_turn_capacity_feet
	resolution.target_hp_after = target.current_hp
	resolution.target_nonlethal_after = target.nonlethal_damage
	_emit_damage_committed(attacker, target, resolution)
	if _detection_service != null and not attacker.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(
			attacker.squad_id
		)
	return OperationResult.committed(
		resolution,
		_result_message(attacker, target, attack, resolution),
		_state_store.state.revision
	)


func _apply_disabled_attack_strain(attacker: TacticalUnitState) -> bool:
	attacker.apply_disabled_strain()
	return attacker.is_dying() or attacker.is_dead()


func _emit_damage_committed(
	attacker: TacticalUnitState,
	target: TacticalUnitState,
	resolution
) -> void:
	var applied_damage: int = int(resolution.get("applied_damage"))
	if applied_damage <= 0:
		return
	# This signal is emitted only after the complete TacticalChangeSet has
	# committed, post-commit log callbacks have run and state_changed has fired.
	# Presentation may react immediately, but no gameplay system waits for it.
	damage_committed.emit({
		"attacker_id": attacker.unit_id,
		"target_id": target.unit_id,
		"amount": applied_damage,
		"damage_channel": StringName(resolution.get("damage_channel")),
		"life_state": target.life_state_id(),
		"hp_after": target.current_hp,
		"nonlethal_after": target.nonlethal_damage,
	})


func _resolve_roll_outcome(
		preview,
		attack: AttackDefinition,
		target: TacticalUnitState,
		target_hp_before: int,
		target_nonlethal_before: int,
		target_combat_state_before: StringName
):
	var resolution = ATTACK_RESOLUTION_SCRIPT.new()
	resolution.preview = preview
	resolution.capacity_before = int(preview.get("capacity_before"))
	resolution.target_hp_before = target_hp_before
	resolution.target_hp_after = target_hp_before
	resolution.target_nonlethal_before = target_nonlethal_before
	resolution.target_nonlethal_after = target_nonlethal_before
	resolution.target_combat_state_before = target_combat_state_before
	resolution.target_combat_state_after = target_combat_state_before
	resolution.damage_channel = StringName(preview.get("damage_channel"))

	resolution.attack_roll = int(_dice_roller.call("roll_die", 20))
	resolution.natural_one = resolution.attack_roll == 1
	resolution.natural_twenty = resolution.attack_roll == 20
	resolution.attack_total = (
		resolution.attack_roll + int(preview.get("attack_bonus"))
	)
	var base_ac: int = int(preview.get("base_target_armour_class"))
	var effective_ac: int = int(preview.get("effective_target_armour_class"))
	resolution.hit_without_cover = (
		resolution.natural_twenty
		or (
			not resolution.natural_one
			and resolution.attack_total >= base_ac
		)
	)
	resolution.hit = (
		resolution.natural_twenty
		or (
			not resolution.natural_one
			and resolution.attack_total >= effective_ac
		)
	)
	resolution.missed_due_to_cover = (
		not resolution.hit
		and resolution.hit_without_cover
		and int(preview.get("cover_ac_bonus")) > 0
	)
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
				and resolution.confirmation_total >= int(
					preview.get("effective_target_armour_class")
				)
			)
		)

	if resolution.hit or resolution.missed_due_to_cover:
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

	return resolution


func _apply_resolved_attack(
		target: TacticalUnitState,
		resolution
) -> bool:
	resolution.applied_damage = 0
	if bool(resolution.get("hit")):
		resolution.applied_damage = target.apply_damage(
			int(resolution.get("final_damage")),
			StringName(resolution.get("damage_channel"))
		)
	resolution.target_hp_after = target.current_hp
	resolution.target_nonlethal_after = target.nonlethal_damage
	resolution.target_combat_state_after = target.combat_state
	resolution.target_became_defeated = (
		StringName(resolution.get("target_combat_state_before"))
		!= TacticalUnitState.COMBAT_STATE_DEFEATED
		and target.is_defeated()
	)
	return true


func _restore_attack_resolution(
		target: TacticalUnitState,
		life_before: Dictionary,
		resolution
) -> void:
	target.restore_life_state(life_before)
	var hp_before: int = int(life_before.get("current_hp", target.current_hp))
	var nonlethal_before: int = int(
		life_before.get("nonlethal_damage", target.nonlethal_damage)
	)
	# The dice outcome remains unchanged. Only the tactical application fields
	# are reset while the dice source itself is restored by execute_preview().
	resolution.applied_damage = 0
	resolution.target_hp_after = hp_before
	resolution.target_nonlethal_after = nonlethal_before
	resolution.target_combat_state_after = target.combat_state
	resolution.target_became_defeated = false


func _spend_reaction_and_face(
		attacker: TacticalUnitState,
		target_position: Vector2i
) -> bool:
	if attacker == null or not attacker.can_use_reaction():
		return false
	if not attacker.action_budget.spend_reaction():
		return false
	attacker.set_facing(
		TacticalPerceptionRules.normalized_facing(
			target_position - attacker.grid_position
		)
	)
	return true


func _spend_attack_cost_and_face(
		attacker: TacticalUnitState,
		attack: AttackDefinition,
		target_position: Vector2i
) -> bool:
	if ActionEconomyRules.spend_attack(attacker, attack) < 0:
		return false
	attacker.set_facing(
		TacticalPerceptionRules.normalized_facing(
			target_position - attacker.grid_position
		)
	)
	return true


func _budget_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"remaining": unit.action_budget.remaining_turn_capacity_feet,
		"spent": unit.action_budget.normal_capacity_spent_feet,
		"quick": unit.action_budget.quick_action_available,
		"reaction": unit.action_budget.reaction_snapshot(),
		"reaction_snapshot": unit.action_budget.reaction_snapshot(),
		"ordinary_attack": unit.action_budget.ordinary_attack_available,
		"ended": unit.action_budget.ended_activation,
		"facing": unit.facing_direction,
		"life_state": unit.life_state_snapshot(),
	}


func _restore_budget(unit: TacticalUnitState, snapshot: Dictionary) -> void:
	unit.action_budget.remaining_turn_capacity_feet = int(snapshot["remaining"])
	unit.action_budget.normal_capacity_spent_feet = int(snapshot["spent"])
	unit.action_budget.quick_action_available = bool(snapshot["quick"])
	var reaction_snapshot_value: Variant = snapshot.get("reaction_snapshot")
	if reaction_snapshot_value is Dictionary:
		unit.action_budget.restore_reaction_snapshot(reaction_snapshot_value)
	else:
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


func _validate_attack_result(
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		resolution,
		target_hp_before: int,
		target_nonlethal_before: int,
		is_reaction: bool = false
) -> String:
	if attacker.action_budget.remaining_turn_capacity_feet < 0:
		return "Attack expenditure produced negative capacity."
	if is_reaction:
		if attacker.action_budget.reaction_state != ReactionResourceState.SPENT:
			return "A committed Reaction attack did not spend its Reaction."
	elif attacker.action_budget.ordinary_attack_available:
		return "A committed normal attack did not consume its attack allowance."

	var damage_channel: StringName = StringName(
		resolution.get("damage_channel")
	)
	var final_damage: int = int(resolution.get("final_damage"))
	var expected_hp: int = target_hp_before
	var expected_nonlethal: int = target_nonlethal_before
	if bool(resolution.get("hit")):
		if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL:
			expected_nonlethal += final_damage
		else:
			expected_hp = target_hp_before - final_damage

	if target.current_hp != expected_hp:
		return "Attack damage did not produce the expected target HP."
	if target.nonlethal_damage != expected_nonlethal:
		return "Attack damage did not produce the expected nonlethal total."
	if target.current_hp < 0 and not (target.is_dying() or target.is_stable_unconscious() or target.is_dead()):
		return "Negative HP did not produce Dying, Stable, or Dead state."
	if target.current_hp == 0 and not target.is_disabled():
		return "A target at 0 HP was not marked Disabled."
	if target.current_hp > 0 and target.is_defeated() and not target.is_nonlethal_unconscious():
		return "A target with positive HP was incorrectly defeated."
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
		int(preview.get("nonlethal_attack_penalty")),
		int(preview.get("range_penalty"))
	)
	var roll_records: Array = [
		ROLL_RECORD_SCRIPT.create(
			&"attack_roll",
			"d20",
			[resolution.get("attack_roll")],
			int(resolution.get("attack_total")),
			int(preview.get("effective_target_armour_class")),
			(
				&"cover_hit"
				if bool(resolution.get("missed_due_to_cover"))
				else &"hit" if bool(resolution.get("hit")) else &"miss"
			),
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
				int(preview.get("effective_target_armour_class")),
				(
					&"confirmed"
					if bool(resolution.get("critical_confirmed"))
					else &"not_confirmed"
				),
				attack_modifiers
			)
		)
	if bool(resolution.get("hit")) or bool(resolution.get("missed_due_to_cover")):
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
		"Target base Armour Class: %d" % int(preview.get("base_target_armour_class")),
		"Cover: %s (%+d AC; %d/%d exposure samples clear)" % [
			_cover_label(StringName(preview.get("cover_category"))),
			int(preview.get("cover_ac_bonus")),
			int(preview.get("clear_exposure_samples")),
			int(preview.get("total_exposure_samples")),
		],
		"Effective Armour Class: %d" % int(preview.get("effective_target_armour_class")),
		"Power Attack: %d" % int(preview.get("power_attack_value")),
		"Range: %d ft" % int(preview.get("range_feet")),
		(
			"Reaction attack: %s"
			% String(preview.get("reaction_kind")).replace("_", " ").capitalize()
			if StringName(preview.get("action_source")) == &"reaction"
			else "Action cost: %d ft" % int(preview.get("action_cost_feet"))
		),
		"Capacity: %d → %d ft" % [
			int(budget_snapshot.get("remaining", 0)),
			attacker.action_budget.remaining_turn_capacity_feet,
		],
	]
	if int(preview.get("range_penalty")) != 0:
		details.append(
			"Range increment penalty: %+d."
			% int(preview.get("range_penalty"))
		)
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
	if bool(resolution.get("missed_due_to_cover")):
		details.append(
			"The attack would have hit base AC but struck %s instead."
			% _cover_source_label(StringName(preview.get("primary_cover_source_id")))
		)
		var source_damage: Dictionary = resolution.get("cover_source_damage")
		if not source_damage.is_empty():
			details.append(
				"Cover damage: %d - Hardness %d = %d; HP %d → %d."
				% [
					int(source_damage.get("raw_damage", 0)),
					int(source_damage.get("hardness", 0)),
					int(source_damage.get("applied_damage", 0)),
					int(source_damage.get("before_hp", 0)),
					int(source_damage.get("after_hp", 0)),
				]
			)
	if bool(resolution.get("hit")):
		if bool(resolution.get("critical_confirmed")):
			details.append(
				"Critical damage: %d × %d = %d %s."
				% [
					int(resolution.get("base_damage")),
					attack.critical_multiplier,
					int(resolution.get("final_damage")),
					str(preview.get("damage_type")).replace("_", "/"),
				]
			)
		else:
			details.append(
				"Damage: %d %s."
				% [
					int(resolution.get("final_damage")),
					str(preview.get("damage_type")).replace("_", "/"),
				]
			)

	if bool(resolution.get("target_became_defeated")):
		details.append(
			"%s became %s."
			% [
				target.display_name,
				String(target.life_state_id()).replace("_", " ").capitalize(),
			]
		)
	elif target.is_disabled():
		details.append(
			"%s reached exactly 0 HP and became Disabled."
			% target.display_name
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
			str(resolution.call("outcome_label")),
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
			"resource_changes": (
				[
					{
						"resource": &"reaction",
						"before": StringName(
							(budget_snapshot.get("reaction_snapshot", {}) as Dictionary).get(
								"state", ReactionResourceState.AVAILABLE
							)
						),
						"after": attacker.action_budget.reaction_state,
					},
					damage_resource_change,
				]
				if StringName(preview.get("action_source")) == &"reaction"
				else [
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
						"after": attacker.action_budget.ordinary_attack_available,
					},
					damage_resource_change,
				]
			),
			"metadata": {
				"action_source": StringName(preview.get("action_source")),
				"reaction_kind": StringName(preview.get("reaction_kind")),
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
				"base_target_armour_class": int(preview.get("base_target_armour_class")),
				"effective_target_armour_class": int(preview.get("effective_target_armour_class")),
				"cover_category": preview.get("cover_category"),
				"cover_ac_bonus": int(preview.get("cover_ac_bonus")),
				"primary_cover_source_id": preview.get("primary_cover_source_id"),
				"hit_without_cover": bool(resolution.get("hit_without_cover")),
				"missed_due_to_cover": bool(resolution.get("missed_due_to_cover")),
				"cover_source_damage": resolution.get("cover_source_damage"),
				"final_damage": int(resolution.get("final_damage")),
				"applied_damage": int(resolution.get("applied_damage")),
				"target_combat_state": target.combat_state,
				"target_life_state": target.life_state_id(),
				"dying_successes": target.dying_successes,
				"dying_failures": target.dying_failures,
				"target_became_defeated": bool(
					resolution.get("target_became_defeated")
				),
			},
		}
	)


func _apply_cover_source_damage_and_salvage(
		resolution,
		target_tile: Vector2i,
		salvage_item_id: StringName
) -> bool:
	var preview = resolution.get("preview")
	var source_id: StringName = StringName(preview.get("primary_cover_source_id"))
	var environment: TacticalEnvironmentState = _state_store.state.environment_state
	if environment == null or source_id.is_empty():
		return false
	var damage_result: Dictionary = environment.apply_damage_to_source(
		_map_definition,
		source_id,
		int(resolution.get("final_damage"))
	)
	if not bool(damage_result.get("success", false)):
		return false
	resolution.cover_source_damage = damage_result
	if not bool(damage_result.get("destroyed", false)):
		return true
	var definition_id: StringName = StringName(
		damage_result.get("salvage_item_definition_id", &"")
	)
	var quantity: int = maxi(0, int(damage_result.get("salvage_quantity", 0)))
	if definition_id.is_empty() or quantity <= 0:
		return true
	if _state_store.state.get_item(salvage_item_id) != null:
		return true
	var item_definition: ItemDefinition = _catalogue.item_definition(definition_id)
	if item_definition == null:
		return true
	var source_tile: Vector2i = _cover_source_ground_tile(source_id, target_tile)
	var salvage := TacticalItemInstanceState.new(
		salvage_item_id,
		item_definition,
		quantity,
		1.0,
		TacticalItemLocationState.ground(source_tile, "Structural salvage")
	)
	if not _state_store.state.add_item(salvage, _map_definition, false):
		return false
	resolution.cover_salvage_item_id = salvage_item_id
	var opening_runtime: TacticalOpeningState = environment.opening_state(source_id)
	if opening_runtime != null:
		opening_runtime.salvage_generated = true
	var structure_runtime: TacticalStructureState = environment.structure_state(source_id)
	if structure_runtime != null:
		structure_runtime.salvage_generated = true
	return true


func _restore_cover_source_damage_and_salvage(
		source_id: StringName,
		source_snapshot: Dictionary,
		salvage_item_id: StringName,
		salvage_existed_before: bool
) -> void:
	if _state_store.state.environment_state != null and not source_snapshot.is_empty():
		_state_store.state.environment_state.restore_source(source_id, source_snapshot)
	if not salvage_existed_before and _state_store.state.get_item(salvage_item_id) != null:
		_state_store.state.remove_item(salvage_item_id, false)


func _cover_source_ground_tile(
		source_id: StringName,
		fallback: Vector2i
) -> Vector2i:
	var opening: TacticalOpeningDefinition = _map_definition.opening_definition(source_id)
	if opening != null:
		return (
			opening.first_tile
			if TacticalGridDistance.steps_between(opening.first_tile, fallback)
			<= TacticalGridDistance.steps_between(opening.second_tile, fallback)
			else opening.second_tile
		)
	var structure: TacticalStructureDefinition = _map_definition.structure_definition(source_id)
	if structure != null:
		if structure.geometry_kind == TacticalStructureDefinition.GEOMETRY_EDGE:
			return (
				structure.first_tile
				if TacticalGridDistance.steps_between(structure.first_tile, fallback)
				<= TacticalGridDistance.steps_between(structure.second_tile, fallback)
				else structure.second_tile
			)
		if not structure.tile_coordinates.is_empty():
			return structure.tile_coordinates[0]
	return fallback


func _cover_label(category: StringName) -> String:
	match category:
		TacticalCombatGeometryResult.COVER_LIGHT:
			return "Light Cover"
		TacticalCombatGeometryResult.COVER_HEAVY:
			return "Heavy Cover"
		TacticalCombatGeometryResult.COVER_TOTAL:
			return "Total Cover"
		_:
			return "Exposed"


func _cover_source_label(source_id: StringName) -> String:
	if source_id.is_empty():
		return "cover"
	var opening: TacticalOpeningDefinition = _map_definition.opening_definition(source_id)
	if opening != null:
		return opening.display_name
	var structure: TacticalStructureDefinition = _map_definition.structure_definition(source_id)
	if structure != null:
		return structure.display_name
	var barrier: TacticalBarrierSegmentDefinition = _map_definition.barrier_definition(source_id)
	if barrier != null:
		return barrier.display_name
	var creature: TacticalUnitState = _state_store.state.get_unit(source_id)
	return creature.display_name if creature != null else String(source_id)


func _attack_modifier_records(
		attacker: TacticalUnitState,
		attack: AttackDefinition,
		power_attack_value: int,
		nonlethal_attack_penalty: int,
		range_penalty: int
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
	if range_penalty != 0:
		result.append(
			MODIFIER_RECORD_SCRIPT.create(
				"Range increment",
				range_penalty,
				&"rule.range_increment",
				&"range"
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
		str(resolution.call("outcome_label")),
	]
	if bool(resolution.get("hit")):
		result += " for %d %s damage" % [
			int(resolution.get("final_damage")),
			_damage_channel_label(
				StringName(resolution.get("damage_channel"))
			).to_lower(),
		]
	return result + "."
