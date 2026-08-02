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
var _visibility_service: RefCounted

# Stage 4.5e2 commit profiling. Exact target geometry is built during hover;
# commit performs only revision-aware legality validation when that preview is
# still current. Combat impact is published before broad state reconciliation.
var _commit_preview_reuses: int = 0
var _commit_preview_validation_failures: int = 0
var _combat_impact_events_emitted: int = 0
var _lightweight_attack_commits: int = 0
var _full_validation_attack_commits: int = 0
var _redundant_hostile_action_resolutions_skipped: int = 0
var _last_attack_commit_total_usec: int = 0
var _last_attack_validation_usec: int = 0
var _last_hostile_action_preparation_usec: int = 0
var _last_impact_publish_usec_from_commit_start: int = 0
var _ordinary_attacks_without_visibility_invalidation: int = 0
var _attack_visibility_invalidations: int = 0
var _attack_geometry_invalidations: int = 0


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		event_journal: RefCounted,
		preview_query: RefCounted,
		dice_roller: RefCounted,
		detection_service: TacticalDetectionService = null,
		visibility_service: RefCounted = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_event_journal = event_journal
	_preview_query = preview_query
	_dice_roller = dice_roller
	_detection_service = detection_service
	_visibility_service = visibility_service


func execute_preview(preview) -> OperationResult:
	var attack_commit_started_usec: int = Time.get_ticks_usec()
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

	var validation_started_usec: int = Time.get_ticks_usec()
	var validation_value: Variant = _preview_query.call(
		"validate_committed_preview",
		preview
	)
	_last_attack_validation_usec = Time.get_ticks_usec() - validation_started_usec
	var validation: OperationResult = validation_value as OperationResult
	if validation == null or not validation.success:
		_commit_preview_validation_failures += 1
		_last_attack_commit_total_usec = (
			Time.get_ticks_usec() - attack_commit_started_usec
		)
		return (
			validation
			if validation != null
			else OperationResult.fail(
				&"attack_no_longer_legal",
				"The attack is no longer legal."
			)
		)
	var refreshed = validation.data
	if refreshed == null or not bool(refreshed.get("success")):
		_commit_preview_validation_failures += 1
		_last_attack_commit_total_usec = (
			Time.get_ticks_usec() - attack_commit_started_usec
		)
		return OperationResult.fail(
			&"attack_no_longer_legal",
			"The accepted attack preview could not be reused."
		)
	_commit_preview_reuses += 1

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

	var ammunition_item: TacticalItemInstanceState = _ammunition_item_for(
		attacker.unit_id, attack
	)
	if attack.ammunition_per_attack > 0 and ammunition_item == null:
		return OperationResult.fail(
			&"attack_ammunition_missing",
			"This attack requires ammunition."
		)
	var ammunition_quantity_before: int = (
		ammunition_item.quantity if ammunition_item != null else 0
	)

	var budget_snapshot: Dictionary = _budget_snapshot(attacker)
	var attacker_was_disabled: bool = attacker.is_disabled()
	var target_hp_before: int = target.current_hp
	var target_nonlethal_before: int = target.nonlethal_damage
	var target_combat_state_before: StringName = target.combat_state
	var target_life_before: Dictionary = target.life_state_snapshot()
	var dice_checkpoint: Dictionary = _dice_roller.call("snapshot_state")

	# Randomness is resolved before the TacticalChangeSet begins. Sanctuary is
	# checked before the attack roll; a failed Will save spends the declared
	# attack without rolling the attack or consuming ammunition.
	var sanctuary_check: Dictionary = _resolve_sanctuary_check(attacker, target)
	var resolution = (
		_build_sanctuary_blocked_resolution(
			refreshed,
			target_hp_before,
			target_nonlethal_before,
			target_combat_state_before,
			sanctuary_check
		)
		if bool(sanctuary_check.get("blocked", false))
		else _resolve_roll_outcome(
			refreshed,
			attack,
			target,
			target_hp_before,
			target_nonlethal_before,
			target_combat_state_before
		)
	)
	if resolution != null and bool(sanctuary_check.get("checked", false)):
		_apply_sanctuary_check_to_resolution(resolution, sanctuary_check)
	var intercessor: TacticalUnitState = null
	var intercessor_budget_before: Dictionary = {}
	var intercessor_resources_before: Dictionary = {}
	if resolution != null:
		intercessor = _prepare_mercy_intercession(target, resolution)
		if intercessor != null:
			intercessor_budget_before = _budget_snapshot(intercessor)
			intercessor_resources_before = (
				intercessor.ability_uses_remaining.duplicate(true)
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
	var cover_salvage_provenance_id := _generated_item_provenance_id(
		cover_salvage_item_id
	)
	var cover_salvage_existed_before: bool = state.get_item(cover_salvage_item_id) != null
	var cover_provenance_existed_before: bool = (
		state.generated_item_provenance(cover_salvage_provenance_id) != null
	)

	var alert_resolution: TacticalDetectionResolution = null
	var alert_snapshot: Dictionary = {}
	if _detection_service != null:
		var hostile_action_started_usec: int = Time.get_ticks_usec()
		alert_resolution = _detection_service.prepare_hostile_action_resolution(
			attacker.unit_id,
			target.unit_id
		)
		_last_hostile_action_preparation_usec = (
			Time.get_ticks_usec() - hostile_action_started_usec
		)
		if alert_resolution == null or not alert_resolution.has_state_changes():
			alert_resolution = null
			_redundant_hostile_action_resolutions_skipped += 1
		else:
			alert_snapshot = _detection_service.snapshot_for_resolution(
				alert_resolution
			)

	var attack_contract := TacticalInvalidationContract.attack(
		attacker.unit_id, target.unit_id
	)
	if ammunition_item != null and not bool(resolution.get("sanctuary_blocked")):
		attack_contract.inventory_changed = true
		attack_contract.affected_item_ids.append(ammunition_item.item_id)
	var source_item_id: StringName = StringName(refreshed.get("source_item_id"))
	var thrown_item: TacticalItemInstanceState = (
		state.get_item(source_item_id)
		if attack.id == &"action.reaver_thrown_dagger_attack"
		else null
	)
	var thrown_item_location_before: TacticalItemLocationState = (
		thrown_item.location.clone() if thrown_item != null else null
	)
	if thrown_item != null:
		attack_contract.inventory_changed = true
		if not attack_contract.affected_item_ids.has(thrown_item.item_id):
			attack_contract.affected_item_ids.append(thrown_item.item_id)
	var changes: TacticalChangeSet = TacticalChangeSet.new(
		&"attack_resolved",
		state.revision,
		attack_contract
	)
	changes.set_allow_while_pending(is_reaction)
	# Staged cover damage or ammunition consumption escalates the authoritative
	# explicit contract owned by this transaction.
	var attack_flags: TacticalInvalidationContract = changes.invalidation_contract
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
	if ammunition_item != null and not bool(resolution.get("sanctuary_blocked")):
		changes.stage(
			Callable(self, "_consume_ammunition").bind(
				ammunition_item, attack.ammunition_per_attack
			),
			Callable(self, "_restore_ammunition").bind(
				ammunition_item, ammunition_quantity_before
			),
			"The attack ammunition could not be consumed.",
			&"attack_ammunition_failed"
		)
	if intercessor != null:
		if not attack_contract.affected_unit_ids.has(intercessor.unit_id):
			attack_contract.affected_unit_ids.append(intercessor.unit_id)
		changes.stage(
			Callable(self, "_spend_mercy_intercession").bind(intercessor),
			Callable(self, "_restore_mercy_intercession").bind(
				intercessor,
				intercessor_budget_before,
				intercessor_resources_before
			),
			"Mercy Intercession could not spend its Reaction and use.",
			&"mercy_intercession_cost_failed"
		)

	var attacker_effects_before: Dictionary = _attack_effect_snapshot(attacker)
	changes.stage(
		Callable(self, "_apply_attack_feature_updates").bind(
			attacker,
			target,
			attack,
			resolution
		),
		Callable(self, "_restore_attack_feature_updates").bind(
			attacker,
			attacker_effects_before
		),
		"Attack feature state could not be updated.",
		&"attack_feature_update_failed"
	)

	changes.stage(
		Callable(self, "_apply_resolved_attack").bind(
			attacker,
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
	if thrown_item != null:
		changes.stage(
			Callable(self, "_land_thrown_item").bind(
				thrown_item, target.grid_position
			),
			Callable(self, "_restore_thrown_item").bind(
				thrown_item, thrown_item_location_before
			),
			"The thrown Dagger could not be placed on the battlefield.",
			&"thrown_item_landing_failed"
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
				cover_salvage_item_id,
				attack_flags
			),
			Callable(self, "_restore_cover_source_damage_and_salvage").bind(
				cover_source_id,
				cover_source_snapshot,
				cover_salvage_item_id,
				cover_salvage_existed_before,
				cover_salvage_provenance_id,
				cover_provenance_existed_before
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

	# The common attack path changes only one action budget and one target's HP.
	# It does not need a whole-mission body/item/squad/environment audit. Escalate
	# to the full transaction path only for body transitions, structural cover
	# damage/salvage, or a real alert/initiative mutation.
	var target_body_state_changed: bool = (
		StringName(resolution.get("target_combat_state_after"))
		!= target_combat_state_before
		or bool(resolution.get("target_became_defeated"))
	)
	var body_synchronisation_required: bool = (
		target_body_state_changed or attacker_was_disabled
	)
	var structural_state_changed: bool = (
		bool(resolution.get("missed_due_to_cover"))
		and StringName(refreshed.get("primary_cover_source_kind")) in [
			&"opening", &"structure"
		]
	)
	var full_validation_required: bool = (
		body_synchronisation_required
		or structural_state_changed
		or alert_resolution != null
	)

	# Precise attack invalidation. A body transition changes standing occupancy
	# and item representation, but bodies do not block the fog-of-war sight field.
	# Alert/revelation changes awareness and initiative, not map visibility.
	if body_synchronisation_required:
		attack_flags.occupancy_changed = true
		attack_flags.inventory_changed = true
	if target_body_state_changed:
		attack_flags.visibility_changed = true
		if not attack_flags.moved_observer_ids.has(target.unit_id):
			attack_flags.moved_observer_ids.append(target.unit_id)
		if not target.team_id.is_empty() and not attack_flags.affected_team_ids.has(target.team_id):
			attack_flags.affected_team_ids.append(target.team_id)
	if alert_resolution != null and (
		not alert_resolution.newly_aware_squad_ids.is_empty()
		or not alert_resolution.initiative_totals_by_unit_id.is_empty()
	):
		attack_flags.initiative_changed = true

	changes.set_commit_validation_policy(
		body_synchronisation_required,
		full_validation_required
	)
	if full_validation_required:
		_full_validation_attack_commits += 1
	else:
		_lightweight_attack_commits += 1

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
	# Publish visual impact before any journal formatting or log notification.
	# Combat-log presentation itself is frame-deferred by TacticalCombatLog, so
	# the first red pulse/vibration frame is never held behind log rebuilding.
	changes.after_commit(
		Callable(self, "_publish_attack_impact").bind(
			attacker,
			target,
			resolution,
			attack_commit_started_usec
		)
	)
	changes.after_commit(
		Callable(self, "_record_attack_invalidation_profile").bind(attack_flags)
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

	if _detection_service != null and not attacker.squad_id.is_empty():
		_detection_service.request_current_perception_for_squad(
			attacker.squad_id
		)
	_last_attack_commit_total_usec = (
		Time.get_ticks_usec() - attack_commit_started_usec
	)
	return OperationResult.committed(
		resolution,
		_result_message(attacker, target, attack, resolution),
		_state_store.state.revision
	)


func _publish_attack_impact(
	attacker: TacticalUnitState,
	target: TacticalUnitState,
	resolution,
	attack_commit_started_usec: int
) -> void:
	resolution.capacity_after = attacker.action_budget.remaining_turn_capacity_feet
	resolution.target_hp_after = target.current_hp
	resolution.target_nonlethal_after = target.nonlethal_damage
	_last_impact_publish_usec_from_commit_start = (
		Time.get_ticks_usec() - attack_commit_started_usec
	)
	_emit_damage_committed(attacker, target, resolution)


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
	# This signal is emitted from the first post-commit callback after authoritative
	# mutation, before journal publication and broad state_changed handling.
	# Presentation may start immediate non-blocking feedback; gameplay never
	# waits for the animation.
	_combat_impact_events_emitted += 1
	damage_committed.emit({
		"attacker_id": attacker.unit_id,
		"target_id": target.unit_id,
		"amount": applied_damage,
		"damage_channel": StringName(resolution.get("damage_channel")),
		"life_state": target.life_state_id(),
		"hp_after": target.current_hp,
		"nonlethal_after": target.nonlethal_damage,
	})


func performance_snapshot() -> Dictionary:
	return {
		"commit_preview_reuses": _commit_preview_reuses,
		"commit_preview_validation_failures": (
			_commit_preview_validation_failures
		),
		"combat_impact_events_emitted": _combat_impact_events_emitted,
		"lightweight_attack_commits": _lightweight_attack_commits,
		"full_validation_attack_commits": _full_validation_attack_commits,
		"redundant_hostile_action_resolutions_skipped": (
			_redundant_hostile_action_resolutions_skipped
		),
		"last_attack_validation_usec": _last_attack_validation_usec,
		"last_hostile_action_preparation_usec": (
			_last_hostile_action_preparation_usec
		),
		"last_impact_publish_usec_from_commit_start": (
			_last_impact_publish_usec_from_commit_start
		),
		"last_attack_commit_total_usec": _last_attack_commit_total_usec,
		"ordinary_attacks_without_visibility_invalidation": (
			_ordinary_attacks_without_visibility_invalidation
		),
		"attack_visibility_invalidations": _attack_visibility_invalidations,
		"attack_geometry_invalidations": _attack_geometry_invalidations,
	}


func _resolve_sanctuary_check(
		attacker: TacticalUnitState,
		target: TacticalUnitState
) -> Dictionary:
	var result: Dictionary = {
		"checked": false,
		"roll": 0,
		"bonus": 0,
		"total": 0,
		"dc": 0,
		"blocked": false,
	}
	if attacker == null or target == null or not target.has_timed_effect(&"effect.sanctuary"):
		return result
	var dc: int = target.timed_effect_value(&"effect.sanctuary")
	var roll: int = int(_dice_roller.call("roll_die", 20))
	var bonus: int = (
		attacker.resolved_character.stat_value(&"will", 0)
		if attacker.resolved_character != null
		else 0
	)
	if attacker.has_timed_effect(&"effect.resistance"):
		bonus += attacker.timed_effect_value(&"effect.resistance")
	result["checked"] = true
	result["roll"] = roll
	result["bonus"] = bonus
	result["total"] = roll + bonus
	result["dc"] = dc
	result["blocked"] = roll + bonus < dc
	return result


func _build_sanctuary_blocked_resolution(
		preview,
		target_hp_before: int,
		target_nonlethal_before: int,
		target_combat_state_before: StringName,
		sanctuary_check: Dictionary
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
	resolution.sanctuary_blocked = bool(sanctuary_check.get("blocked", false))
	return resolution


func _apply_sanctuary_check_to_resolution(
		resolution,
		sanctuary_check: Dictionary
) -> void:
	resolution.sanctuary_checked = bool(sanctuary_check.get("checked", false))
	resolution.sanctuary_save_roll = int(sanctuary_check.get("roll", 0))
	resolution.sanctuary_save_bonus = int(sanctuary_check.get("bonus", 0))
	resolution.sanctuary_save_total = int(sanctuary_check.get("total", 0))
	resolution.sanctuary_save_dc = int(sanctuary_check.get("dc", 0))
	resolution.sanctuary_blocked = bool(sanctuary_check.get("blocked", false))


func _prepare_mercy_intercession(
		target: TacticalUnitState,
		resolution
) -> TacticalUnitState:
	if (
		target == null
		or resolution == null
		or not bool(resolution.get("hit"))
		or StringName(resolution.get("damage_channel")) != TacticalUnitState.DAMAGE_CHANNEL_LETHAL
		or int(resolution.get("final_damage")) <= 0
		or not target.has_role_tag(&"biological")
		or target.is_dead()
	):
		return null
	var best: TacticalUnitState = null
	for candidate: TacticalUnitState in _state_store.state.get_units():
		if (
			candidate == null
			or candidate.is_dead()
			or candidate.resolved_character == null
			or not candidate.is_ai_controlled()
			or not candidate.resolved_character.has_trait(&"feature.mercy_intercession")
			or not TacticalTeamRelations.are_allied(candidate.team_id, target.team_id)
			or not candidate.can_use_reaction()
			or not candidate.can_spend_ability_resource(&"resource.mercy.intercession", 1)
		):
			continue
		var distance: int = TacticalGridDistance.feet_between(
			candidate.grid_position,
			target.grid_position
		)
		if distance > 30:
			continue
		if best == null or String(candidate.unit_id) < String(best.unit_id):
			best = candidate
	if best == null:
		return null
	var roll: int = int(_dice_roller.call("roll_die", 8))
	var reduction: int = mini(int(resolution.get("final_damage")), roll + 3)
	resolution.mercy_intercession_used = true
	resolution.mercy_intercessor_id = best.unit_id
	resolution.mercy_intercession_roll = roll
	resolution.mercy_intercession_reduction = reduction
	resolution.final_damage = maxi(0, int(resolution.get("final_damage")) - reduction)
	return best


func _spend_mercy_intercession(intercessor: TacticalUnitState) -> bool:
	return (
		intercessor != null
		and intercessor.action_budget.spend_reaction()
		and intercessor.spend_ability_resource(&"resource.mercy.intercession", 1)
	)


func _restore_mercy_intercession(
		intercessor: TacticalUnitState,
		budget_before: Dictionary,
		resources_before: Dictionary
) -> void:
	if intercessor == null:
		return
	_restore_budget(intercessor, budget_before)
	intercessor.restore_ability_resources(resources_before)


func _attack_effect_snapshot(unit: TacticalUnitState) -> Dictionary:
	return {
		"rounds": unit.timed_effect_rounds.duplicate(true),
		"sources": unit.timed_effect_source_ids.duplicate(true),
		"values": unit.timed_effect_values.duplicate(true),
		"subdual_target": unit.subdual_takedown_target_id,
	}


func _apply_attack_feature_updates(
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		attack: AttackDefinition,
		resolution
) -> bool:
	if attacker == null or target == null or attack == null or resolution == null:
		return false
	if bool(resolution.get("sanctuary_checked")) and attacker.has_timed_effect(&"effect.resistance"):
		attacker.clear_timed_effect(&"effect.resistance")
	if not bool(resolution.get("sanctuary_blocked")):
		if attacker.has_timed_effect(&"effect.guidance"):
			attacker.clear_timed_effect(&"effect.guidance")
	if attacker.has_timed_effect(&"effect.sanctuary"):
		attacker.clear_timed_effect(&"effect.sanctuary")
	if (
		bool(resolution.get("hit"))
		and attack.attack_tags.has(&"sanctuary_blackjack")
		and attacker.resolved_character != null
		and attacker.resolved_character.has_trait(&"feat.subdual_takedown")
	):
		attacker.mark_subdual_takedown_target(target.unit_id)
	return true


func _restore_attack_feature_updates(
		attacker: TacticalUnitState,
		snapshot: Dictionary
) -> void:
	attacker.timed_effect_rounds = (snapshot.get("rounds", {}) as Dictionary).duplicate(true)
	attacker.timed_effect_source_ids = (snapshot.get("sources", {}) as Dictionary).duplicate(true)
	attacker.timed_effect_values = (snapshot.get("values", {}) as Dictionary).duplicate(true)
	attacker.subdual_takedown_target_id = StringName(snapshot.get("subdual_target", &""))


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
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		resolution
) -> bool:
	resolution.applied_damage = 0
	var was_nonlethal_unconscious: bool = target.is_nonlethal_unconscious()
	if bool(resolution.get("hit")):
		resolution.applied_damage = target.apply_damage(
			int(resolution.get("final_damage")),
			StringName(resolution.get("damage_channel"))
		)
	if (
		attacker != null
		and not was_nonlethal_unconscious
		and target.is_nonlethal_unconscious()
		and StringName(resolution.get("damage_channel"))
			== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
	):
		target.record_nonlethal_incapacitation(
			attacker.unit_id,
			StringName("attack.%s.%s.r%d" % [
				attacker.unit_id, target.unit_id, _state_store.state.revision
			])
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


func _land_thrown_item(
		item: TacticalItemInstanceState,
		landing_cell: Vector2i
) -> bool:
	if item == null or item.definition == null:
		return false
	item.location = TacticalItemLocationState.ground(
		landing_cell, "Thrown weapon"
	)
	_state_store.state.rebuild_ground_item_index()
	return true


func _restore_thrown_item(
		item: TacticalItemInstanceState,
		location_before: TacticalItemLocationState
) -> void:
	if item != null and location_before != null:
		item.location = location_before.clone()
		_state_store.state.rebuild_ground_item_index()


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
	var roll_records: Array = []
	if bool(resolution.get("sanctuary_checked")):
		roll_records.append(
			ROLL_RECORD_SCRIPT.create(
				&"sanctuary_will_save",
				"d20",
				[resolution.get("sanctuary_save_roll")],
				int(resolution.get("sanctuary_save_total")),
				int(resolution.get("sanctuary_save_dc")),
				&"failed" if bool(resolution.get("sanctuary_blocked")) else &"succeeded",
				[]
			)
		)
	if not bool(resolution.get("sanctuary_blocked")):
		roll_records.append(
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
			)
		)

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
	if bool(resolution.get("sanctuary_checked")):
		details.append(
			"Sanctuary Will save: d20 %d %+d = %d vs DC %d — %s."
			% [
				int(resolution.get("sanctuary_save_roll")),
				int(resolution.get("sanctuary_save_bonus")),
				int(resolution.get("sanctuary_save_total")),
				int(resolution.get("sanctuary_save_dc")),
				"attack blocked" if bool(resolution.get("sanctuary_blocked")) else "attack permitted",
			]
		)
	if bool(resolution.get("mercy_intercession_used")):
		details.append(
			"Mercy Intercession: d8 %d + 3 reduced lethal damage by %d."
			% [
				int(resolution.get("mercy_intercession_roll")),
				int(resolution.get("mercy_intercession_reduction")),
			]
		)
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

	var attacker_observable: bool = _unit_is_player_observable(attacker)
	var target_observable: bool = _unit_is_player_observable(target)
	var hidden_hostile_attacker: bool = (
		attacker.team_id != &"player" and not attacker_observable
	)
	var event_visibility: StringName = (
		&"player" if attacker_observable or target_observable else &"hidden"
	)
	var event_summary: String = (
		"An unseen attacker attacks %s — %s."
		% [target.display_name, str(resolution.call("outcome_label"))]
		if hidden_hostile_attacker and target_observable
		else "%s attacks %s with %s — %s."
		% [
			attacker.display_name,
			target.display_name,
			attack.display_name,
			str(resolution.call("outcome_label")),
		]
	)
	if hidden_hostile_attacker and target_observable:
		details = _redacted_unseen_attack_details(target, resolution, damage_channel_label)
		roll_records = []

	var phase: TacticalPhaseState = _state_store.state.phase_state
	_event_journal.call(
		"record_event",
		&"attack_resolved",
		phase.round_number,
		phase.current_phase,
		event_summary,
		{
			"category": &"combat",
			"visibility": event_visibility,
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


func _unit_is_player_observable(unit: TacticalUnitState) -> bool:
	if unit == null:
		return false
	if unit.team_id == &"player":
		return true
	if _visibility_service == null:
		return false
	if not _visibility_service.has_method("is_unit_visible_to_team"):
		return false
	return bool(
		_visibility_service.call("is_unit_visible_to_team", &"player", unit)
	)


func _redacted_unseen_attack_details(
		target: TacticalUnitState,
		resolution,
		damage_channel_label: String
) -> Array[String]:
	var redacted: Array[String] = [
		"The attacker was outside current player perception.",
		"Damage channel: %s" % damage_channel_label,
	]
	if bool(resolution.get("hit")):
		redacted.append(
			"%s suffers %d damage."
			% [target.display_name, int(resolution.get("final_damage"))]
		)
	elif bool(resolution.get("missed_due_to_cover")):
		redacted.append("The unseen attack struck cover.")
	else:
		redacted.append("The unseen attack missed.")
	if bool(resolution.get("target_became_defeated")):
		redacted.append(
			"%s became %s."
			% [
				target.display_name,
				String(target.life_state_id()).replace("_", " ").capitalize(),
			]
		)
	return redacted


func _apply_cover_source_damage_and_salvage(
		resolution,
		target_tile: Vector2i,
		salvage_item_id: StringName,
		invalidation_flags: TacticalInvalidationFlags
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
	if invalidation_flags != null:
		if int(damage_result.get("applied_damage", 0)) > 0:
			invalidation_flags.environment_visuals_changed = true
		var before_integrity := StringName(damage_result.get("before_integrity", &""))
		var after_integrity := StringName(damage_result.get("after_integrity", &""))
		if before_integrity != after_integrity:
			invalidation_flags.geometry_changed = true
			if invalidation_flags is TacticalInvalidationContract:
				(invalidation_flags as TacticalInvalidationContract).justification = (
					"Attack changed an authored cover source identified by the resolution payload."
				)
			if _cover_integrity_blocks_sight(source_id, before_integrity) != _cover_integrity_blocks_sight(source_id, after_integrity):
				invalidation_flags.visibility_changed = true
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
	if not _register_generated_salvage_provenance(salvage, source_id):
		_state_store.state.remove_item(salvage_item_id, false)
		return false
	if invalidation_flags != null:
		invalidation_flags.inventory_changed = true
	resolution.cover_salvage_item_id = salvage_item_id
	var opening_runtime: TacticalOpeningState = environment.opening_state(source_id)
	if opening_runtime != null:
		opening_runtime.salvage_generated = true
	var structure_runtime: TacticalStructureState = environment.structure_state(source_id)
	if structure_runtime != null:
		structure_runtime.salvage_generated = true
	return true


func _cover_integrity_blocks_sight(
		source_id: StringName,
		integrity_state: StringName
) -> bool:
	var opening: TacticalOpeningDefinition = _map_definition.opening_definition(source_id)
	if opening != null:
		if integrity_state == TacticalOpeningDefinition.STATE_OPEN:
			return false
		if opening.opening_kind == TacticalOpeningDefinition.KIND_WINDOW and opening.clear_glass:
			return false
		if opening.opening_kind == TacticalOpeningDefinition.KIND_BARRED_OPENING:
			return false
		return integrity_state not in [
			TacticalOpeningDefinition.STATE_BROKEN,
			TacticalOpeningDefinition.STATE_DESTROYED,
		]
	var structure: TacticalStructureDefinition = _map_definition.structure_definition(source_id)
	if structure != null:
		if not structure.blocks_sight_intact:
			return false
		return integrity_state not in [
			TacticalStructureDefinition.STATE_BREACHED,
			TacticalStructureDefinition.STATE_DESTROYED,
			TacticalStructureDefinition.STATE_CLEARED,
		]
	return false


func _record_attack_invalidation_profile(
		flags: TacticalInvalidationFlags
) -> void:
	if flags == null:
		return
	if flags.geometry_changed:
		_attack_geometry_invalidations += 1
	if flags.visibility_changed:
		_attack_visibility_invalidations += 1
	else:
		_ordinary_attacks_without_visibility_invalidation += 1


func _restore_cover_source_damage_and_salvage(
		source_id: StringName,
		source_snapshot: Dictionary,
		salvage_item_id: StringName,
		salvage_existed_before: bool,
		provenance_id: StringName,
		provenance_existed_before: bool
) -> void:
	if _state_store.state.environment_state != null and not source_snapshot.is_empty():
		_state_store.state.environment_state.restore_source(source_id, source_snapshot)
	if not salvage_existed_before and _state_store.state.get_item(salvage_item_id) != null:
		_state_store.state.remove_item(salvage_item_id, false)
	if not provenance_existed_before:
		_state_store.state.remove_generated_item_provenance(provenance_id)


func _generated_item_provenance_id(item_id: StringName) -> StringName:
	return StringName(
		"provenance.%s.%s" % [_state_store.state.mission_id, item_id]
	)


func _register_generated_salvage_provenance(
		salvage: TacticalItemInstanceState,
		source_id: StringName
) -> bool:
	var state: TacticalState = _state_store.state
	if state == null or salvage == null:
		return false
	var provenance := TacticalGeneratedItemProvenance.new()
	provenance.provenance_id = _generated_item_provenance_id(salvage.item_id)
	provenance.mission_id = state.mission_id
	provenance.source_setup_hash = state.source_setup_hash
	provenance.generated_item_id = salvage.item_id
	provenance.creation_kind = (
		TacticalGeneratedItemProvenance.CREATION_STRUCTURAL_SALVAGE
	)
	provenance.source_event_id = StringName(
		"event.%s.cover_destroyed.%s.%d"
		% [state.mission_id, source_id, state.revision + 1]
	)
	provenance.source_entity_id = source_id
	provenance.definition_id = salvage.definition_id
	provenance.quantity = salvage.quantity
	provenance.condition = salvage.condition
	provenance.persistent_modifiers = salvage.tactical_modifiers.duplicate(true)
	provenance.creation_revision = state.revision + 1
	return state.register_generated_item_provenance(provenance)


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
	if bool(resolution.get("sanctuary_blocked")):
		return "%s spent %s against %s, but Sanctuary barred the attack." % [attacker.display_name, attack.display_name, target.display_name]
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


func _ammunition_item_for(
		unit_id: StringName,
		attack: AttackDefinition
) -> TacticalItemInstanceState:
	if (
		_state_store == null
		or _state_store.state == null
		or attack == null
		or attack.ammunition_per_attack <= 0
	):
		return null
	for item: TacticalItemInstanceState in _state_store.state.get_items():
		if item == null or item.location == null or item.definition == null:
			continue
		if item.location.owner_id != unit_id:
			continue
		if not item.definition.has_tag(attack.ammunition_tag):
			continue
		if item.quantity >= attack.ammunition_per_attack:
			return item
	return null


func _consume_ammunition(
		item: TacticalItemInstanceState,
		amount: int
) -> bool:
	if item == null or amount <= 0 or item.quantity < amount:
		return false
	if item.quantity == amount:
		return _state_store.state.remove_item(item.item_id, false)
	item.quantity -= amount
	return true


func _restore_ammunition(
		item: TacticalItemInstanceState,
		quantity_before: int
) -> void:
	if item == null or quantity_before <= 0:
		return
	item.quantity = quantity_before
	if _state_store.state.get_item(item.item_id) == null:
		_state_store.state.add_item(item, _map_definition, false)
