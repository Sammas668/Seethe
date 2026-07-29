class_name AttackPreviewQuery
extends RefCounted

const ATTACK_PREVIEW_SCRIPT: Script = preload(
	"res://application/tactical/combat/tactical_attack_preview.gd"
)
const TEAM_RELATIONS_SCRIPT: Script = preload(
	"res://domain/tactical/tactical_team_relations.gd"
)

const SUPPORTED_ACTION_IDS: Array[StringName] = [
	&"action.raiders_axe_attack",
	&"action.mace_attack",
	&"action.reaver_dagger_attack",
]

const AI_SUPPORTED_ACTION_IDS: Array[StringName] = [
	&"action.training_spear_attack",
]

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue


func is_supported_action(action_id: StringName) -> bool:
	# Player action menus remain intentionally limited to Hakon's Stage 4.0 set.
	return SUPPORTED_ACTION_IDS.has(action_id)


func is_supported_ai_action(action_id: StringName) -> bool:
	return AI_SUPPORTED_ACTION_IDS.has(action_id)


func _is_supported_for_attacker(
		attacker: TacticalUnitState,
		action_id: StringName
) -> bool:
	if attacker != null and attacker.is_ai_controlled():
		return AI_SUPPORTED_ACTION_IDS.has(action_id)
	return SUPPORTED_ACTION_IDS.has(action_id)


func execute(
		attacker_id: StringName,
		target_id: StringName,
		action_id: StringName,
		power_attack_value: int = 0,
		damage_channel: StringName = TacticalUnitState.DAMAGE_CHANNEL_LETHAL
):
	var preview = ATTACK_PREVIEW_SCRIPT.new()
	preview.attacker_id = attacker_id
	preview.target_id = target_id
	preview.action_id = action_id
	preview.power_attack_value = clampi(power_attack_value, 0, 3)
	preview.damage_channel = damage_channel

	if damage_channel not in [
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL,
		TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL,
	]:
		return preview.reject("Choose either lethal or nonlethal damage.")

	if _state_store == null or _catalogue == null:
		return preview.reject("Combat services are unavailable.")
	var state: TacticalState = _state_store.state
	if state == null:
		return preview.reject("The tactical state is unavailable.")
	preview.expected_state_revision = state.revision

	var attacker: TacticalUnitState = state.get_unit(attacker_id)
	var target: TacticalUnitState = state.get_unit(target_id)
	if attacker == null:
		return preview.reject("The attacker no longer exists.")
	if target == null:
		return preview.reject("The target no longer exists.")
	preview.attacker_display_name = attacker.display_name
	preview.target_display_name = target.display_name

	if attacker.is_player_controlled():
		if not state.phase_state.is_player_phase():
			return preview.reject("Player attacks are available only during the Player Phase.")
	elif attacker.is_ai_controlled():
		if not state.phase_state.is_enemy_turn():
			return preview.reject("AI attacks are available only during the Enemy Turn.")
	else:
		return preview.reject("This unit has no combat controller.")
	if attacker.is_defeated():
		return preview.reject("Defeated units cannot attack.")
	if attacker.action_budget.ended_activation:
		return preview.reject("This unit is marked as ended. Reactivate it before attacking.")
	if attacker_id == target_id:
		return preview.reject("A unit cannot attack itself.")
	if not TEAM_RELATIONS_SCRIPT.are_hostile(
		attacker.team_id,
		target.team_id
	):
		var relationship: StringName = TEAM_RELATIONS_SCRIPT.relationship(
			attacker.team_id,
			target.team_id
		)
		if relationship == TEAM_RELATIONS_SCRIPT.RELATION_ALLIED:
			return preview.reject("Allied targets are unavailable in Stage 4.0.1.")
		return preview.reject("Neutral targets are unavailable in Stage 4.0.1.")
	if target.is_defeated():
		return preview.reject("That target is already Defeated.")
	if not _is_supported_for_attacker(attacker, action_id):
		return preview.reject("That attack is reserved for a later combat stage.")

	var attack: AttackDefinition = _catalogue.attack_definition(action_id)
	if attack == null:
		return preview.reject("The selected attack definition is missing.")
	if attack.attack_kind != AttackDefinition.ATTACK_MELEE:
		return preview.reject("Stage 4.0 supports melee attacks only.")
	if not state.granted_action_ids_for_unit(attacker_id).has(action_id):
		return preview.reject("The selected attack is not granted by an equipped weapon.")

	var unavailable_reason: String = ActionEconomyRules.attack_unavailable_reason(
		attacker,
		attack
	)
	if not unavailable_reason.is_empty():
		return preview.reject(unavailable_reason)

	var distance_feet: int = _minimum_distance_feet(attacker, target)
	var reach_feet: int = (
		attack.range_profile.reach_feet
		if attack.range_profile != null
		else 5
	)
	if distance_feet > reach_feet:
		return preview.reject(
			"%s is %d ft away; %s reaches %d ft."
			% [target.display_name, distance_feet, attack.display_name, reach_feet]
		)

	var snapshot: ResolvedCharacterSnapshot = attacker.resolved_character
	if snapshot == null:
		return preview.reject("The attacker has no resolved character statistics.")
	var power_attack: int = preview.power_attack_value
	var nonlethal_penalty: int = 0
	var ignores_nonlethal_penalty: bool = false
	if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL:
		ignores_nonlethal_penalty = _ignores_nonlethal_penalty(
			attacker,
			attack
		)
		if not ignores_nonlethal_penalty:
			nonlethal_penalty = -4
	var attack_bonus: int = (
		snapshot.attack_bonus_for(attack)
		- power_attack
		+ nonlethal_penalty
	)
	var damage_bonus: int = (
		snapshot.damage_bonus_for(attack)
		+ int(attack.damage_profile.flat_bonus)
		+ power_attack
	)
	var cost_feet: int = attack.resolved_cost().resolved_normal_capacity_feet(
		attacker.action_budget.maximum_turn_capacity_feet
	)

	preview.source_item_id = _source_item_id(state, attacker_id, action_id)
	preview.attack_display_name = attack.display_name
	preview.attack_bonus = attack_bonus
	preview.target_armour_class = target.armour_class
	preview.hit_chance_percent = _hit_chance_percent(
		attack_bonus,
		target.armour_class
	)
	preview.critical_threat_minimum = attack.critical_threat_minimum
	preview.critical_multiplier = attack.critical_multiplier
	preview.damage_dice_count = attack.damage_profile.dice_count
	preview.damage_die_size = attack.damage_profile.die_size
	preview.damage_bonus = damage_bonus
	preview.damage_type = attack.damage_profile.damage_type
	preview.damage_channel = damage_channel
	preview.nonlethal_attack_penalty = nonlethal_penalty
	preview.nonlethal_penalty_ignored = ignores_nonlethal_penalty
	preview.damage_notation = _damage_notation(
		preview.damage_dice_count,
		preview.damage_die_size,
		damage_bonus
	)
	preview.range_feet = distance_feet
	preview.action_cost_feet = cost_feet
	preview.capacity_before = attacker.action_budget.remaining_turn_capacity_feet
	preview.capacity_after = preview.capacity_before - cost_feet
	return preview.accept()


func legal_target_ids(
		attacker_id: StringName,
		action_id: StringName,
		power_attack_value: int = 0,
		damage_channel: StringName = TacticalUnitState.DAMAGE_CHANNEL_LETHAL
) -> Array[StringName]:
	var result: Array[StringName] = []
	if _state_store == null or _state_store.state == null:
		return result
	for target: TacticalUnitState in _state_store.state.get_units():
		var preview = execute(
			attacker_id,
			target.unit_id,
			action_id,
			power_attack_value,
			damage_channel
		)
		if preview.success:
			result.append(target.unit_id)
	return result


func _ignores_nonlethal_penalty(
		attacker: TacticalUnitState,
		attack: AttackDefinition
) -> bool:
	if (
		attacker == null
		or attacker.resolved_character == null
		or attack == null
		or attack.damage_profile == null
	):
		return false
	if not attacker.resolved_character.has_trait(&"trait.take_them_alive"):
		return false
	return _is_blunt_damage_type(attack.damage_profile.damage_type)


func _is_blunt_damage_type(damage_type: StringName) -> bool:
	return damage_type in [&"blunt", &"bludgeoning"]


func _minimum_distance_feet(
		attacker: TacticalUnitState,
		target: TacticalUnitState
) -> int:
	var best_steps: int = 999999
	for attacker_cell: Vector2i in _occupied_cells(attacker):
		for target_cell: Vector2i in _occupied_cells(target):
			var delta: Vector2i = target_cell - attacker_cell
			var steps: int = maxi(absi(delta.x), absi(delta.y))
			best_steps = mini(best_steps, steps)
	return maxi(0, best_steps) * 5


func _occupied_cells(unit: TacticalUnitState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(maxi(1, unit.footprint.y)):
		for x: int in range(maxi(1, unit.footprint.x)):
			result.append(unit.grid_position + Vector2i(x, y))
	return result


func _source_item_id(
		state: TacticalState,
		attacker_id: StringName,
		action_id: StringName
) -> StringName:
	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item: TacticalItemInstanceState = state.get_hand_item(
			attacker_id,
			hand_kind
		)
		if (
			item != null
			and item.definition != null
			and item.definition.granted_action_ids.has(action_id)
		):
			return item.item_id
	return &""


func _hit_chance_percent(attack_bonus: int, armour_class: int) -> int:
	var successful_faces: int = 0
	for natural_roll: int in range(1, 21):
		if natural_roll == 1:
			continue
		if natural_roll == 20 or natural_roll + attack_bonus >= armour_class:
			successful_faces += 1
	return successful_faces * 5


func _damage_notation(count: int, size: int, bonus: int) -> String:
	var result: String = "%dd%d" % [maxi(1, count), maxi(2, size)]
	if bonus > 0:
		result += "+%d" % bonus
	elif bonus < 0:
		result += "%d" % bonus
	return result
