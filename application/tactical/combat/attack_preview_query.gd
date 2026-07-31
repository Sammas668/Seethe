class_name AttackPreviewQuery
extends RefCounted

const TacticalGridDistance: Script = preload(
	"res://domain/tactical/tactical_grid_distance.gd"
)
const TacticalMeleeReachRules: Script = preload(
	"res://domain/tactical/combat/tactical_melee_reach_rules.gd"
)

const ATTACK_PREVIEW_SCRIPT: Script = preload(
	"res://application/tactical/combat/tactical_attack_preview.gd"
)
const TEAM_RELATIONS_SCRIPT: Script = preload(
	"res://domain/tactical/tactical_team_relations.gd"
)
const TacticalLineOfSightRules: Script = preload(
	"res://domain/tactical/visibility/tactical_line_of_sight_rules.gd"
)

var _state_store: TacticalStateStore
var _map_definition: TacticalMapDefinition
var _catalogue: ContentCatalogue
var _visibility_service: RefCounted
var _geometry_cache: TacticalGeometryCacheService
var _automatic_lean_candidates_evaluated: int = 0
var _automatic_lean_candidates_rejected_cheaply: int = 0
# Stage 4.4 compatibility marker; the cache service is the sole wrapper around:
# TacticalCombatGeometryQuery.evaluate(


func configure(
		state_store: TacticalStateStore,
		map_definition: TacticalMapDefinition,
		catalogue: ContentCatalogue,
		visibility_service: RefCounted = null,
		geometry_cache: TacticalGeometryCacheService = null
) -> void:
	_state_store = state_store
	_map_definition = map_definition
	_catalogue = catalogue
	_visibility_service = visibility_service
	_geometry_cache = geometry_cache
	if _geometry_cache == null:
		_geometry_cache = TacticalGeometryCacheService.new()
		_geometry_cache.configure(_state_store, _map_definition)


func is_supported_action(action_id: StringName) -> bool:
	var attack: AttackDefinition = (
		_catalogue.attack_definition(action_id)
		if _catalogue != null
		else null
	)
	return _definition_is_supported(attack, false)


func is_supported_ai_action(action_id: StringName) -> bool:
	var attack: AttackDefinition = (
		_catalogue.attack_definition(action_id)
		if _catalogue != null
		else null
	)
	return _definition_is_supported(attack, true)


func _definition_is_supported(
		attack: AttackDefinition,
		is_ai_controller: bool
) -> bool:
	return (
		attack != null
		and attack.damage_profile != null
		and attack.range_profile != null
		and (
			attack.is_implemented_melee_weapon_attack()
			or attack.is_implemented_ranged_weapon_attack()
		)
		and attack.controller_can_use(is_ai_controller)
	)


func _is_supported_for_attacker(
		attacker: TacticalUnitState,
		attack: AttackDefinition
) -> bool:
	if attacker == null:
		return false
	return _definition_is_supported(attack, attacker.is_ai_controlled())


func execute(
		attacker_id: StringName,
		target_id: StringName,
		action_id: StringName,
		power_attack_value: int = 0,
		damage_channel: StringName = TacticalUnitState.DAMAGE_CHANNEL_LETHAL,
		origin_override: Variant = null,
		target_position_override: Variant = null,
		reaction_context: Dictionary = {}
):
	var preview = ATTACK_PREVIEW_SCRIPT.new()
	preview.attacker_id = attacker_id
	preview.target_id = target_id
	preview.action_id = action_id
	preview.power_attack_value = clampi(power_attack_value, 0, 3)
	preview.damage_channel = damage_channel
	preview.attack_origin_override = origin_override
	preview.target_position_override = target_position_override
	preview.reaction_context = reaction_context.duplicate(true)
	var is_reaction: bool = bool(reaction_context.get("is_reaction", false))
	preview.action_source = &"reaction" if is_reaction else &"ordinary"
	preview.reaction_kind = StringName(reaction_context.get("reaction_kind", &""))
	preview.reaction_attack_modifier = int(reaction_context.get("attack_modifier", 0))

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
	preview.expected_geometry_revision = state.geometry_revision()

	var attacker: TacticalUnitState = state.get_unit(attacker_id)
	var target: TacticalUnitState = state.get_unit(target_id)
	if attacker == null:
		return preview.reject("The attacker no longer exists.")
	if target == null:
		return preview.reject("The target no longer exists.")
	preview.attacker_display_name = attacker.display_name
	preview.target_display_name = target.display_name

	if not attacker.is_player_controlled() and not attacker.is_ai_controlled():
		return preview.reject("This unit has no combat controller.")
	# Compatibility note: side-based enemy legality was formerly checked with
	# state.phase_state.is_enemy_turn; can_unit_act now also enforces initiative.
	if not is_reaction and not state.can_unit_act(attacker_id):
		return preview.reject("This unit is not the active unit for the current turn mode.")
	if attacker.is_defeated():
		return preview.reject("Defeated units cannot attack.")
	if not is_reaction and attacker.action_budget.ended_activation:
		return preview.reject(
			"This unit is marked as ended. Reactivate it before attacking."
		)
	if is_reaction and not attacker.can_use_reaction():
		return preview.reject("This unit cannot currently use a Reaction.")
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
			return preview.reject("Allied targets are unavailable for this attack.")
		return preview.reject("Neutral targets are unavailable for this attack.")
	if target.is_defeated():
		return preview.reject("That target is already Defeated.")
	if (
		attacker.is_ai_controlled()
		and target.team_id == &"player"
		and (
			attacker.squad_id.is_empty()
			or not state.is_unit_revealed_to_squad(target.unit_id, attacker.squad_id)
		)
	):
		return preview.reject("That target has not been revealed to this enemy squad.")
	if (
		_visibility_service != null
		and not is_reaction
		and not bool(
			_visibility_service.call(
				"is_unit_visible_to_team",
				attacker.team_id,
				target
			)
		)
	):
		return preview.reject("That target is not currently visible.")

	var attack: AttackDefinition = _catalogue.attack_definition(action_id)
	if attack == null:
		return preview.reject("The selected attack definition is missing.")
	if not _is_supported_for_attacker(attacker, attack):
		return preview.reject(
			"This attack's implementation profile is not available in the current combat slice."
		)
	if not state.granted_action_ids_for_unit(attacker_id).has(action_id):
		return preview.reject(
			"The selected attack is not granted by an equipped weapon."
		)
	if preview.power_attack_value > 0 and not attack.allows_power_attack():
		return preview.reject("This attack does not support Power Attack.")
	if (
		damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
		and not attack.supports_nonlethal
	):
		return preview.reject("This attack cannot deal nonlethal damage.")

	if not is_reaction:
		var unavailable_reason: String = ActionEconomyRules.attack_unavailable_reason(
			attacker,
			attack
		)
		if not unavailable_reason.is_empty():
			return preview.reject(unavailable_reason)

	var attacker_cells: Array[Vector2i] = _occupied_cells(attacker)
	var target_cells: Array[Vector2i] = _occupied_cells_at(
		target,
		target_position_override
	)
	var distance_feet: int = _minimum_distance_between_cells(
		attacker_cells,
		target_cells
	)
	var range_penalty: int = 0
	if attack.attack_kind == AttackDefinition.ATTACK_RANGED:
		var increment_feet: int = maxi(
			5,
			attack.range_profile.range_increment_feet
		)
		var maximum_range_feet: int = (
			increment_feet * maxi(1, attack.range_profile.maximum_increments)
		)
		if distance_feet > maximum_range_feet:
			return preview.reject(
				"%s is %d ft away; %s has a maximum range of %d ft."
				% [
					target.display_name,
					distance_feet,
					attack.display_name,
					maximum_range_feet,
				]
			)
		var increment_index: int = maxi(0, int(ceil(
			float(distance_feet) / float(increment_feet)
		)) - 1)
		range_penalty = -2 * increment_index
	else:
		var reach_feet: int = maxi(5, attack.range_profile.reach_feet)
		distance_feet = TacticalMeleeReachRules.minimum_reach_distance_feet(
			attacker_cells,
			target_cells,
			_map_definition
		)
		if not TacticalMeleeReachRules.can_reach(
			attacker_cells,
			target_cells,
			_map_definition,
			reach_feet
		):
			if TacticalMeleeReachRules.has_sealed_diagonal_contact(
				attacker_cells,
				target_cells,
				_map_definition
			):
				return preview.reject(
					"A sealed corner blocks the diagonal melee attack."
				)
			var grid_distance_feet: int = _minimum_distance_feet(
				attacker,
				target
			)
			return preview.reject(
				"%s is %d ft away; %s reaches %d ft."
				% [
					target.display_name,
					grid_distance_feet,
					attack.display_name,
					reach_feet,
				]
			)

	var origin_selection: Dictionary = _best_geometry_for_attack(
		state, attacker, target, attack, origin_override, target_position_override
	)
	var geometry: TacticalCombatGeometryResult = origin_selection.get("geometry") as TacticalCombatGeometryResult
	if geometry == null:
		geometry = TacticalCombatGeometryResult.new()
	preview.attack_origin_override = origin_selection.get("origin_override", origin_override)
	preview.uses_automatic_lean = bool(origin_selection.get("uses_automatic_lean", false))
	preview.firing_origin_kind = StringName(origin_selection.get("origin_kind", &"centre"))
	preview.firing_edge_id = StringName(origin_selection.get("source_edge_id", &""))
	var normal_geometry: TacticalCombatGeometryResult = origin_selection.get("normal_geometry") as TacticalCombatGeometryResult
	preview.normal_origin_legal = _geometry_allows_direct_attack(normal_geometry)
	preview.has_line_of_sight = geometry.has_line_of_sight
	preview.has_line_of_effect = geometry.has_line_of_effect
	preview.cover_category = geometry.cover_category
	preview.cover_ac_bonus = geometry.cover_ac_bonus
	preview.cover_reflex_bonus = geometry.cover_reflex_bonus
	preview.clear_exposure_samples = geometry.clear_exposure_samples
	preview.total_exposure_samples = geometry.total_exposure_samples
	preview.primary_cover_source_id = geometry.primary_cover_source_id
	preview.primary_cover_source_kind = geometry.primary_cover_source_kind
	if not geometry.has_line_of_sight:
		return preview.reject("No line of sight to the target from this position.")
	if not geometry.has_line_of_effect:
		return preview.reject(
			"The target is visible, but a solid opening or barrier blocks line of effect."
		)
	if geometry.cover_category == TacticalCombatGeometryResult.COVER_TOTAL:
		return preview.reject("The target has Total Cover from this position.")

	var snapshot: ResolvedCharacterSnapshot = attacker.resolved_character
	if snapshot == null:
		return preview.reject(
			"The attacker has no resolved character statistics."
		)
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
		+ range_penalty
		+ preview.reaction_attack_modifier
	)
	var damage_bonus: int = (
		snapshot.damage_bonus_for(attack)
		+ int(attack.damage_profile.flat_bonus)
		+ power_attack
	)
	var cost_feet: int = (
		0
		if is_reaction
		else attack.resolved_cost().resolved_normal_capacity_feet(
			attacker.action_budget.maximum_turn_capacity_feet
		)
	)

	preview.source_item_id = _source_item_id(state, attacker_id, action_id)
	preview.attack_display_name = attack.display_name
	preview.attack_bonus = attack_bonus
	preview.base_target_armour_class = target.armour_class
	preview.cover_ac_bonus = geometry.cover_ac_bonus
	preview.effective_target_armour_class = (
		target.armour_class + geometry.cover_ac_bonus
	)
	# Compatibility field remains the opposing value used by attack resolution.
	preview.target_armour_class = preview.effective_target_armour_class
	preview.hit_chance_percent = _hit_chance_percent(
		attack_bonus,
		preview.effective_target_armour_class
	)
	preview.chosen_origin_hit_chance = preview.hit_chance_percent
	preview.chosen_origin_cover_category = geometry.cover_category
	if normal_geometry != null and _geometry_allows_direct_attack(normal_geometry):
		preview.normal_origin_hit_chance = _hit_chance_percent(
			attack_bonus,
			target.armour_class + normal_geometry.cover_ac_bonus
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
	preview.range_penalty = range_penalty
	preview.action_cost_feet = cost_feet
	preview.capacity_before = attacker.action_budget.remaining_turn_capacity_feet
	preview.capacity_after = preview.capacity_before - cost_feet
	return preview.accept()


func execute_reaction(
		attacker_id: StringName,
		target_id: StringName,
		action_id: StringName,
		reaction_kind: StringName,
		attack_modifier: int = 0,
		target_position_override: Variant = null
):
	return execute(
		attacker_id,
		target_id,
		action_id,
		0,
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL,
		null,
		target_position_override,
		{
			"is_reaction": true,
			"reaction_kind": reaction_kind,
			"attack_modifier": attack_modifier,
		}
	)


func _occupied_cells_at(
		unit: TacticalUnitState,
		position_override: Variant
) -> Array[Vector2i]:
	if unit == null:
		return []
	if not (position_override is Vector2i):
		return _occupied_cells(unit)
	var result: Array[Vector2i] = []
	var origin := Vector2i(position_override)
	for y: int in range(maxi(1, unit.footprint.y)):
		for x: int in range(maxi(1, unit.footprint.x)):
			result.append(origin + Vector2i(x, y))
	return result


func _minimum_distance_between_cells(
		first_cells: Array[Vector2i],
		second_cells: Array[Vector2i]
) -> int:
	var result: int = 1000000
	for first: Vector2i in first_cells:
		for second: Vector2i in second_cells:
			result = mini(result, TacticalGridDistance.feet_between(first, second))
	return 0 if result == 1000000 else result


func _best_geometry_for_attack(
		state: TacticalState,
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		attack: AttackDefinition,
		origin_override: Variant,
		target_position_override: Variant
) -> Dictionary:
	var normal_geometry: TacticalCombatGeometryResult = _geometry_for(
		attacker,
		target,
		null,
		target_position_override
	)
	if origin_override != null or attack.attack_kind != AttackDefinition.ATTACK_RANGED:
		var direct_geometry: TacticalCombatGeometryResult = _geometry_for(
			attacker,
			target,
			origin_override,
			target_position_override
		)
		return {
			"geometry": direct_geometry,
			"normal_geometry": normal_geometry,
			"origin_override": origin_override,
			"uses_automatic_lean": false,
			"origin_kind": &"centre",
			"source_edge_id": &"",
		}

	# An uncovered legal centre shot is already optimal. Do not enumerate or
	# sample every corner and opening merely to rediscover the same result.
	if (
		_geometry_allows_direct_attack(normal_geometry)
		and normal_geometry.cover_category == TacticalCombatGeometryResult.COVER_NONE
	):
		return {
			"geometry": normal_geometry,
			"normal_geometry": normal_geometry,
			"origin_override": null,
			"uses_automatic_lean": false,
			"origin_kind": &"centre",
			"source_edge_id": &"",
		}

	var origins: Array[TacticalFiringOrigin] = TacticalFiringOriginQuery.legal_origins(
		state,
		_map_definition,
		attacker
	)
	var target_world: Vector2 = (
		Vector2(target_position_override)
		if target_position_override is Vector2
		else Vector2(target.grid_position) + Vector2(0.5, 0.5)
	)
	var attacker_world: Vector2 = Vector2(attacker.grid_position) + Vector2(0.5, 0.5)
	var target_direction: Vector2 = (target_world - attacker_world).normalized()
	var chosen_origin: TacticalFiringOrigin = TacticalFiringOrigin.centre(
		attacker.grid_position
	)
	var chosen_geometry: TacticalCombatGeometryResult = normal_geometry
	for firing_origin: TacticalFiringOrigin in origins:
		if firing_origin == null or not firing_origin.uses_automatic_lean:
			continue
		var origin_direction: Vector2 = Vector2(firing_origin.direction).normalized()
		if (
			origin_direction != Vector2.ZERO
			and target_direction != Vector2.ZERO
			and origin_direction.dot(target_direction) < 0.05
		):
			_automatic_lean_candidates_rejected_cheaply += 1
			continue
		_automatic_lean_candidates_evaluated += 1
		var geometry: TacticalCombatGeometryResult = _geometry_for(
			attacker,
			target,
			firing_origin.world_position,
			target_position_override
		)
		var candidate_legal: bool = _geometry_allows_direct_attack(geometry)
		var chosen_legal: bool = _geometry_allows_direct_attack(chosen_geometry)
		if candidate_legal and not chosen_legal:
			chosen_origin = firing_origin
			chosen_geometry = geometry
			continue
		if candidate_legal != chosen_legal:
			continue
		if _cover_rank(geometry.cover_category) < _cover_rank(
			chosen_geometry.cover_category
		):
			chosen_origin = firing_origin
			chosen_geometry = geometry

	return {
		"geometry": chosen_geometry,
		"normal_geometry": normal_geometry,
		"origin_override": (
			chosen_origin.world_position
			if chosen_origin != null and chosen_origin.uses_automatic_lean
			else null
		),
		"uses_automatic_lean": (
			chosen_origin != null and chosen_origin.uses_automatic_lean
		),
		"origin_kind": (
			chosen_origin.origin_kind if chosen_origin != null else &"centre"
		),
		"source_edge_id": (
			chosen_origin.source_edge_id if chosen_origin != null else &""
		),
	}


func combat_geometry_between(
		attacker_id: StringName,
		target_id: StringName,
		origin_override: Variant = null,
		target_position_override: Variant = null
) -> TacticalCombatGeometryResult:
	if _state_store == null or _state_store.state == null:
		return TacticalCombatGeometryResult.new()
	var attacker: TacticalUnitState = _state_store.state.get_unit(attacker_id)
	var target: TacticalUnitState = _state_store.state.get_unit(target_id)
	if attacker == null or target == null:
		return TacticalCombatGeometryResult.new()
	return _geometry_for(
		attacker,
		target,
		origin_override,
		target_position_override
	)


func performance_snapshot() -> Dictionary:
	return {
		"geometry_cache": (
			_geometry_cache.performance_snapshot()
			if _geometry_cache != null
			else {}
		),
		"automatic_lean_candidates_evaluated": (
			_automatic_lean_candidates_evaluated
		),
		"automatic_lean_candidates_rejected_cheaply": (
			_automatic_lean_candidates_rejected_cheaply
		),
	}


func _geometry_for(
		attacker: TacticalUnitState,
		target: TacticalUnitState,
		origin_override: Variant = null,
		target_position_override: Variant = null
) -> TacticalCombatGeometryResult:
	return _geometry_cache.evaluate(
		attacker,
		target,
		origin_override,
		target_position_override
	)


func _geometry_allows_direct_attack(geometry: TacticalCombatGeometryResult) -> bool:
	return (
		geometry != null
		and geometry.has_line_of_sight
		and geometry.has_line_of_effect
		and geometry.cover_category != TacticalCombatGeometryResult.COVER_TOTAL
	)


func _cover_rank(category: StringName) -> int:
	match category:
		TacticalCombatGeometryResult.COVER_NONE:
			return 0
		TacticalCombatGeometryResult.COVER_LIGHT:
			return 1
		TacticalCombatGeometryResult.COVER_HEAVY:
			return 2
		TacticalCombatGeometryResult.COVER_TOTAL:
			return 3
		_:
			return 4


func legal_target_ids(
		attacker_id: StringName,
		action_id: StringName,
		power_attack_value: int = 0,
		damage_channel: StringName = TacticalUnitState.DAMAGE_CHANNEL_LETHAL,
		origin_override: Variant = null,
		target_position_override: Variant = null
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
			damage_channel,
			origin_override,
			target_position_override
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
	var best_steps: int = TacticalGridDistance.minimum_steps_between_sets(
		_occupied_cells(attacker),
		_occupied_cells(target)
	)
	return best_steps * TacticalGridDistance.TILE_SIZE_FEET


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
