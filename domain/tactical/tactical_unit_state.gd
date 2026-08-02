class_name TacticalUnitState
extends RefCounted

const LIFE_STATE_RULES_SCRIPT: Script = preload(
	"res://domain/tactical/life/tactical_life_state_rules.gd"
)

const CONTROLLER_PLAYER: StringName = &"player"
const CONTROLLER_AI: StringName = &"ai"
const CONTROLLER_WORLD: StringName = &"world"

const TURN_BEHAVIOR_STANDARD: StringName = &"standard"
const TURN_BEHAVIOR_AUTO_PASS: StringName = &"auto_pass"
const TURN_BEHAVIOR_NONE: StringName = &"none"

const DAMAGE_CHANNEL_LETHAL: StringName = &"lethal"
const DAMAGE_CHANNEL_NONLETHAL: StringName = &"nonlethal"

const COMBAT_STATE_ACTIVE: StringName = &"active"
# Compatibility value retained for older event payloads and tests. New code
# should query life_state_id() rather than treating every downed unit as dead.
const COMBAT_STATE_DEFEATED: StringName = &"defeated"

const LIFE_STATE_NORMAL: StringName = &"normal"
const LIFE_STATE_DISABLED: StringName = &"disabled"
const LIFE_STATE_DYING: StringName = &"dying"
const LIFE_STATE_STABLE_UNCONSCIOUS: StringName = &"stable_unconscious"
const LIFE_STATE_NONLETHAL_UNCONSCIOUS: StringName = &"nonlethal_unconscious"
const LIFE_STATE_DEAD: StringName = &"dead"

var unit_id: StringName
var persistent_character_id: StringName = &""
var display_name: String
var team_id: StringName
var faction_id: StringName = &""
var roster_role: StringName = &"neutral"
var persistence_scope: StringName = &"mission"
var controller_type: StringName = CONTROLLER_PLAYER
var turn_behavior: StringName = TURN_BEHAVIOR_STANDARD
var participates_in_enemy_turn: bool = false
var counts_for_victory: bool = true
var grid_position: Vector2i
var action_budget: ActionBudgetState
var diagonal_steps_used: int
var footprint: Vector2i
# Stage 4.3.2 body/captive authority. The linked item owns physical location;
# these fields retain character-side state only.
var body_item_id: StringName = &""
var body_weight_lb: float = 150.0
var restrained: bool = false
var captive: bool = false
var restraint_item_id: StringName = &""
var awaiting_body_placement: bool = false
# Stage 4.5: Disengage protects only voluntary movement for the current activation.
var disengage_active: bool = false

var maximum_hp: int
var current_hp: int
# Nonlethal damage remains a separate channel. It causes unconsciousness when
# it exceeds current positive HP, but it never starts the Dying track.
var nonlethal_damage: int = 0
# The authoritative life-state fields required by Stage 4.3.1. Current HP may
# be negative. Stable and Dead are explicit because they cannot be derived from
# HP alone, while successes and failures make the rescue race readable.
var dying_successes: int = 0
var dying_failures: int = 0
var stable: bool = false
var dead: bool = false
var last_dying_check_round: int = 0
# Compatibility cache for older systems. It is ACTIVE for characters who may
# act (including Disabled) and DEFEATED for unconscious or dead units.
var combat_state: StringName = COMBAT_STATE_ACTIVE
# Generic action incapacitation remains available for later conditions such as
# Stunned. Life-state unconsciousness is resolved separately.
var action_incapacitated: bool = false
# Deprecated compatibility cache for unresolved fixtures only.
var base_armour_class: int
# Runtime cache rebuilt exclusively from resolved_character.armour_class.
var armour_class: int
var inventory: TacticalInventoryState
var resolved_character: ResolvedCharacterSnapshot
var character_sheet: TacticalCharacterSheetState
var active_character_modifier_ids: Array[StringName] = []
var role_tags: Array[StringName] = []
var proficiency_ids: Array[StringName] = []
var ai_profile_id: StringName = &""
var combatant_classification: StringName = &"combatant"
var capture_eligible: bool = true
var surrender_eligible: bool = true
var loot_profile_id: StringName = &""
var provisional_content: bool = false

# Stage 4.7 Hotfix 1 — per-mission ability resources and compact authored
# conditions. These remain authoritative tactical state, not UI flags.
var ability_uses_remaining: Dictionary = {}
var ability_resource_maximums: Dictionary = {}
var timed_effect_rounds: Dictionary = {}
var timed_effect_source_ids: Dictionary = {}
var timed_effect_values: Dictionary = {}
var concentration_action_id: StringName = &""
var kneeling: bool = false
var subdual_takedown_target_id: StringName = &""
var rage_rounds_remaining: int = 0
var fatigued_after_rage: bool = false
var character_resolution_refresh_pending: bool = false
# Stage 4.7 Hotfix 5 runtime mechanics.
const LOAD_LIGHT: StringName = &"light"
const LOAD_MEDIUM: StringName = &"medium"
const LOAD_HEAVY: StringName = &"heavy"
const LOAD_OVER_CAPACITY: StringName = &"over_capacity"
var carried_weight_lb: float = 0.0
var load_category: StringName = LOAD_LIGHT
var sprint_distance_feet: int = 0
var fast_movement_active: bool = false
var grappled_by_unit_id: StringName = &""
var grappling_target_unit_id: StringName = &""
var nonlethal_incapacitation_source_unit_id: StringName = &""
var nonlethal_incapacitation_event_id: StringName = &""

# Stage 4.2.5 — stealth, awareness and alert foundation.
# Awareness belongs to the enemy squad; revelation belongs to the player unit
# relative to each squad. This prevents one squad from gaining another squad's
# knowledge and keeps hidden units out of alerted AI target lists.
var squad_id: StringName = &""
var facing_direction: Vector2i = Vector2i(0, 1)
var stealth_enabled: bool = false
var revealed_to_squad_ids: Array[StringName] = []
# A hidden unit keeps one current Stealth result while stationary. Turning an
# observer away and back compares against this same result rather than fishing
# for fresh passive-detection rolls.
var current_stealth_roll_valid: bool = false
var current_stealth_roll_value: int = 0
var current_stealth_total: int = 0
# The first implementation treats a guard's original post as its prior task.
# After searching a Last Seen Position, simple AI returns to this anchor.
var assigned_task_position: Vector2i = Vector2i(-1, -1)


func _init(
		unit_id_value: StringName = &"",
		display_name_value: String = "Unnamed Unit",
		grid_position_value: Vector2i = Vector2i.ZERO,
		maximum_capacity_value: int = 30,
		team_id_value: StringName = &"player",
		maximum_hp_value: int = 20,
		armour_class_value: int = 10
) -> void:
	unit_id = unit_id_value
	display_name = display_name_value
	team_id = team_id_value
	configure_control_from_team(team_id_value)
	grid_position = grid_position_value
	assigned_task_position = grid_position_value
	action_budget = ActionBudgetState.new(maximum_capacity_value)
	diagonal_steps_used = 0
	footprint = Vector2i.ONE

	maximum_hp = maxi(1, maximum_hp_value)
	current_hp = maximum_hp
	nonlethal_damage = 0
	dying_successes = 0
	dying_failures = 0
	stable = false
	dead = false
	last_dying_check_round = 0
	combat_state = COMBAT_STATE_ACTIVE
	base_armour_class = maxi(0, armour_class_value)
	armour_class = base_armour_class
	inventory = TacticalInventoryState.new()
	resolved_character = ResolvedCharacterSnapshot.new()
	character_sheet = TacticalCharacterSheetState.new()
	character_sheet.configure_from_snapshot(resolved_character)


func apply_defence_profile(profile: DefenceProfile) -> void:
	armour_class = base_armour_class
	# Resolved characters already include their equipped defence profile in AC.
	# Preserve this method only for legacy, non-resolved tactical fixtures.
	if (
			profile != null
			and (
				resolved_character == null
				or resolved_character.template_id.is_empty()
			)
	):
		armour_class += profile.armour_class_bonus


func configure_inventory(inventory_value: TacticalInventoryState) -> void:
	inventory = inventory_value if inventory_value != null else TacticalInventoryState.new()


func configure_resolved_character(
		snapshot: ResolvedCharacterSnapshot,
		preserve_runtime_state: bool = true
) -> void:
	if snapshot == null:
		return

	var previous_maximum_hp: int = maximum_hp
	var previous_damage := maxi(0, maximum_hp - current_hp)
	var previous_nonlethal_damage: int = maxi(0, nonlethal_damage)
	var previous_dying_successes: int = dying_successes
	var previous_dying_failures: int = dying_failures
	var previous_stable: bool = stable
	var previous_dead: bool = dead
	var previous_last_dying_check_round: int = last_dying_check_round
	var previous_hp: int = current_hp
	var previous_spent := action_budget.normal_capacity_spent_feet
	var previous_quick := action_budget.quick_action_available
	var previous_reaction_snapshot: Dictionary = action_budget.reaction_snapshot()
	var previous_ordinary_attack_available: bool = (
		action_budget.ordinary_attack_available
	)
	var previous_ended := action_budget.ended_activation
	var previous_ability_uses: Dictionary = ability_uses_remaining.duplicate(true)
	var previous_timed_effects: Dictionary = timed_effect_rounds.duplicate(true)
	var previous_timed_sources: Dictionary = timed_effect_source_ids.duplicate(true)
	var previous_timed_values: Dictionary = timed_effect_values.duplicate(true)
	var previous_concentration: StringName = concentration_action_id
	var previous_kneeling: bool = kneeling
	var previous_subdual_target: StringName = subdual_takedown_target_id
	var previous_rage_rounds: int = rage_rounds_remaining
	var previous_fatigued: bool = fatigued_after_rage
	var previous_resolution_refresh_pending: bool = character_resolution_refresh_pending

	resolved_character = snapshot
	character_sheet.configure_from_snapshot(snapshot)
	display_name = snapshot.display_name
	team_id = snapshot.team_id
	faction_id = snapshot.faction_id
	roster_role = snapshot.roster_role
	persistence_scope = snapshot.persistence_scope
	footprint = snapshot.footprint
	role_tags = snapshot.role_tags.duplicate()
	proficiency_ids = snapshot.proficiency_ids.duplicate()
	ai_profile_id = snapshot.ai_profile_id
	combatant_classification = snapshot.combatant_classification
	capture_eligible = snapshot.capture_eligible
	surrender_eligible = snapshot.surrender_eligible
	loot_profile_id = snapshot.loot_profile_id
	provisional_content = snapshot.provisional_content
	ability_resource_maximums = snapshot.ability_resource_maximums.duplicate(true)
	maximum_hp = maxi(1, snapshot.stat_value(&"maximum_hp", 1))
	# ResolvedCharacterSnapshot is the sole combat authority for Armour Class.
	armour_class = snapshot.stat_value(&"armour_class", 10)
	base_armour_class = armour_class

	var capacity := maxi(5, snapshot.stat_value(&"turn_capacity", 30))
	if not preserve_runtime_state:
		current_hp = maximum_hp
		nonlethal_damage = 0
		dying_successes = 0
		dying_failures = 0
		stable = false
		dead = false
		last_dying_check_round = 0
		combat_state = COMBAT_STATE_ACTIVE
		action_budget = ActionBudgetState.new(capacity)
		ability_uses_remaining.clear()
		for raw_resource_id: Variant in ability_resource_maximums.keys():
			ability_uses_remaining[StringName(raw_resource_id)] = int(
				ability_resource_maximums.get(raw_resource_id, 0)
			)
		timed_effect_rounds.clear()
		timed_effect_source_ids.clear()
		timed_effect_values.clear()
		concentration_action_id = &""
		kneeling = false
		subdual_takedown_target_id = &""
		rage_rounds_remaining = 0
		fatigued_after_rage = false
		character_resolution_refresh_pending = false
	else:
		# Preserve actual negative HP rather than converting it to ordinary
		# damage against the newly resolved maximum. Positive HP still tracks
		# previous damage when maximum HP changes.
		if previous_hp <= 0:
			current_hp = previous_hp
		elif maximum_hp < previous_maximum_hp:
			# Constitution/maximum-HP loss removes the matching current HP. This is
			# required when Rage ends; it may leave the Marauder Dying or Dead.
			current_hp = maximum_hp - previous_damage
		else:
			current_hp = clampi(maximum_hp - previous_damage, 1, maximum_hp)
		nonlethal_damage = previous_nonlethal_damage
		dying_successes = previous_dying_successes
		dying_failures = previous_dying_failures
		stable = previous_stable
		dead = previous_dead
		last_dying_check_round = previous_last_dying_check_round
		action_budget.maximum_turn_capacity_feet = capacity
		action_budget.normal_capacity_spent_feet = clampi(
			previous_spent,
			0,
			capacity
		)
		action_budget.remaining_turn_capacity_feet = maxi(
			0,
			capacity - action_budget.normal_capacity_spent_feet
		)
		action_budget.quick_action_available = previous_quick
		action_budget.restore_reaction_snapshot(previous_reaction_snapshot)
		action_budget.ordinary_attack_available = (
			previous_ordinary_attack_available
		)
		action_budget.ended_activation = previous_ended
		ability_uses_remaining = previous_ability_uses
		for raw_resource_id: Variant in ability_resource_maximums.keys():
			var resource_id := StringName(raw_resource_id)
			if not ability_uses_remaining.has(resource_id):
				ability_uses_remaining[resource_id] = int(
					ability_resource_maximums.get(raw_resource_id, 0)
				)
		timed_effect_rounds = previous_timed_effects
		timed_effect_source_ids = previous_timed_sources
		timed_effect_values = previous_timed_values
		concentration_action_id = previous_concentration
		kneeling = previous_kneeling
		subdual_takedown_target_id = previous_subdual_target
		rage_rounds_remaining = previous_rage_rounds
		fatigued_after_rage = previous_fatigued
		character_resolution_refresh_pending = previous_resolution_refresh_pending
		if previous_hp > 0 and current_hp < 0:
			stable = false
		dead = dead or current_hp <= death_threshold_hp()
		if dead:
			stable = false
		_sync_combat_state_from_life()

	character_resolution_refresh_pending = false
	inventory.maximum_weight_lb = float(
		snapshot.stat_value(&"maximum_weight_lb", 60)
	)


func has_role_tag(tag: StringName) -> bool:
	return role_tags.has(tag)


func configure_character_sheet(
		character_sheet_value: TacticalCharacterSheetState
) -> void:
	character_sheet = (
		character_sheet_value
		if character_sheet_value != null
		else TacticalCharacterSheetState.new()
	)
	if character_sheet.resolved_snapshot != null:
		resolved_character = character_sheet.resolved_snapshot


func set_character_modifier_active(
		modifier_id: StringName,
		active: bool
) -> void:
	if active:
		if not active_character_modifier_ids.has(modifier_id):
			active_character_modifier_ids.append(modifier_id)
	else:
		active_character_modifier_ids.erase(modifier_id)


func refresh_for_new_round() -> void:
	_tick_timed_effects()
	if rage_rounds_remaining > 0:
		rage_rounds_remaining -= 1
		if rage_rounds_remaining <= 0:
			active_character_modifier_ids.erase(&"effect.rage")
			if not active_character_modifier_ids.has(&"effect.fatigued"):
				active_character_modifier_ids.append(&"effect.fatigued")
			fatigued_after_rage = true
			character_resolution_refresh_pending = true
	action_budget.refresh_for_new_round()
	diagonal_steps_used = 0
	disengage_active = false
	subdual_takedown_target_id = &""
	if is_disabled():
		# Disabled characters receive half normal capacity and no Reaction.
		var disabled_capacity: int = maxi(5, int(
			floor(float(action_budget.maximum_turn_capacity_feet) * 0.5)
		))
		action_budget.remaining_turn_capacity_feet = disabled_capacity
		action_budget.normal_capacity_spent_feet = (
			action_budget.maximum_turn_capacity_feet - disabled_capacity
		)
		action_budget.spend_reaction()
	if not can_take_actions():
		mark_activation_ended()


func ability_uses(resource_id: StringName) -> int:
	return int(ability_uses_remaining.get(resource_id, 0))


func can_spend_ability_resource(resource_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or resource_id.is_empty():
		return true
	var current: int = ability_uses(resource_id)
	return current < 0 or current >= amount


func spend_ability_resource(resource_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or resource_id.is_empty():
		return true
	var current: int = ability_uses(resource_id)
	if current < 0:
		return true
	if current < amount:
		return false
	ability_uses_remaining[resource_id] = current - amount
	return true


func restore_ability_resources(snapshot: Dictionary) -> void:
	ability_uses_remaining = snapshot.duplicate(true)


func apply_timed_effect(
		effect_id: StringName,
		rounds: int,
		source_id: StringName = &"",
		value: int = 0
) -> void:
	if effect_id.is_empty():
		return
	timed_effect_rounds[effect_id] = maxi(1, rounds)
	timed_effect_source_ids[effect_id] = source_id
	timed_effect_values[effect_id] = value
	if effect_id == &"condition.hold_person":
		action_incapacitated = true
		action_budget.spend_reaction()
	if effect_id == &"condition.command_kneel":
		kneeling = true
		action_budget.remaining_turn_capacity_feet = 0
		action_budget.normal_capacity_spent_feet = action_budget.maximum_turn_capacity_feet


func clear_timed_effect(effect_id: StringName) -> void:
	timed_effect_rounds.erase(effect_id)
	timed_effect_source_ids.erase(effect_id)
	timed_effect_values.erase(effect_id)
	if effect_id == &"condition.hold_person":
		action_incapacitated = false
	if effect_id == &"condition.command_kneel":
		kneeling = false


func has_timed_effect(effect_id: StringName) -> bool:
	return int(timed_effect_rounds.get(effect_id, 0)) > 0


func timed_effect_value(effect_id: StringName) -> int:
	return int(timed_effect_values.get(effect_id, 0))


func _tick_timed_effects() -> void:
	var expired: Array[StringName] = []
	for raw_effect_id: Variant in timed_effect_rounds.keys():
		var effect_id := StringName(raw_effect_id)
		var remaining := int(timed_effect_rounds.get(raw_effect_id, 0)) - 1
		if remaining <= 0:
			expired.append(effect_id)
		else:
			timed_effect_rounds[effect_id] = remaining
	for effect_id: StringName in expired:
		clear_timed_effect(effect_id)


func rage_available() -> bool:
	return (
		resolved_character != null
		and resolved_character.has_trait(&"feature.rage")
		and not fatigued_after_rage
		and ability_uses(&"resource.rage") > 0
	)


func begin_rage() -> bool:
	if active_character_modifier_ids.has(&"effect.rage") or not rage_available():
		return false
	if not spend_ability_resource(&"resource.rage", 1):
		return false
	active_character_modifier_ids.append(&"effect.rage")
	rage_rounds_remaining = int(resolved_character.feature_parameter(
		&"feature.rage", &"duration_rounds", 7
	))
	return true


func end_rage() -> bool:
	if not active_character_modifier_ids.has(&"effect.rage"):
		return false
	active_character_modifier_ids.erase(&"effect.rage")
	if not active_character_modifier_ids.has(&"effect.fatigued"):
		active_character_modifier_ids.append(&"effect.fatigued")
	rage_rounds_remaining = 0
	fatigued_after_rage = true
	character_resolution_refresh_pending = true
	return true


func mark_subdual_takedown_target(target_id: StringName) -> void:
	subdual_takedown_target_id = target_id


func subdual_takedown_bonus(target_id: StringName, manoeuvre_id: StringName) -> int:
	if target_id != subdual_takedown_target_id:
		return 0
	return 2 if manoeuvre_id in [&"grapple", &"trip", &"shove"] else 0


func saving_throw_bonus(save_id: StringName) -> int:
	if resolved_character == null:
		return 0
	var result: int = resolved_character.stat_value(save_id, 0)
	if has_timed_effect(&"effect.resistance"):
		result += timed_effect_value(&"effect.resistance")
	return result


func is_raging() -> bool:
	return active_character_modifier_ids.has(&"effect.rage")


func is_fatigued() -> bool:
	return fatigued_after_rage or active_character_modifier_ids.has(&"effect.fatigued")


func is_grappled() -> bool:
	return not grappled_by_unit_id.is_empty()


func is_grappling() -> bool:
	return not grappling_target_unit_id.is_empty()


func apply_grapple(controller_id: StringName, target_id: StringName) -> bool:
	if controller_id.is_empty() or target_id.is_empty():
		return false
	if unit_id == controller_id:
		grappling_target_unit_id = target_id
	else:
		grappled_by_unit_id = controller_id
	return true


func clear_grapple() -> void:
	grappled_by_unit_id = &""
	grappling_target_unit_id = &""


func armour_class_for_context(
		deny_dexterity: bool = false,
		source_kind: StringName = &""
) -> int:
	var result: int = armour_class
	if deny_dexterity and resolved_character != null:
		var helpless_denial: bool = is_unconscious() or action_incapacitated
		var retains_dexterity: bool = (
			resolved_character.has_trait(&"feature.uncanny_dodge")
			and not helpless_denial
		)
		if not retains_dexterity:
			result -= maxi(0, resolved_character.ability_modifier("DEX"))
	if source_kind == &"trap" and resolved_character != null:
		result += resolved_character.trap_armour_class_bonus()
	return result


func reflex_bonus_for_context(source_kind: StringName = &"") -> int:
	var result: int = saving_throw_bonus(&"reflex")
	if source_kind == &"trap" and resolved_character != null:
		result += resolved_character.trap_reflex_bonus()
	return result


func record_nonlethal_incapacitation(source_unit_id: StringName, event_id: StringName) -> void:
	nonlethal_incapacitation_source_unit_id = source_unit_id
	nonlethal_incapacitation_event_id = event_id


func qualifies_for_take_them_alive(actor_id: StringName) -> bool:
	return is_nonlethal_unconscious() and nonlethal_incapacitation_source_unit_id == actor_id


func apply_encumbrance(weight_lb: float, category: StringName, capacity_feet: int, sprint_feet: int, fast_active: bool) -> void:
	carried_weight_lb = maxf(0.0, weight_lb)
	load_category = category
	sprint_distance_feet = maxi(0, sprint_feet)
	fast_movement_active = fast_active
	var spent: int = action_budget.normal_capacity_spent_feet
	action_budget.maximum_turn_capacity_feet = maxi(0, capacity_feet)
	action_budget.remaining_turn_capacity_feet = maxi(0, capacity_feet - spent)


func movement_unavailable_reason() -> String:
	if load_category == LOAD_OVER_CAPACITY:
		return "Movement unavailable: Over Capacity."
	if is_grappled() or is_grappling():
		return "Ordinary movement is unavailable while Grappled."
	return ""


func active_condition_labels() -> Array[String]:
	var result: Array[String] = []
	for raw_effect_id: Variant in timed_effect_rounds.keys():
		var effect_id := StringName(raw_effect_id)
		if not has_timed_effect(effect_id):
			continue
		result.append(
			"%s (%d round%s)" % [
				String(effect_id).replace("effect.", "").replace("condition.", "").replace("_", " ").capitalize(),
				int(timed_effect_rounds.get(effect_id, 0)),
				"" if int(timed_effect_rounds.get(effect_id, 0)) == 1 else "s",
			]
		)
	if active_character_modifier_ids.has(&"effect.rage"):
		result.append("Rage (%d rounds)" % rage_rounds_remaining)
	if fatigued_after_rage:
		result.append("Fatigued (STR -2, DEX -2, cannot Sprint)")
	return result


func lethal_damage_taken() -> int:
	return maxi(0, maximum_hp - current_hp)


func apply_damage(
		amount: int,
		damage_channel: StringName = DAMAGE_CHANNEL_LETHAL
) -> int:
	var requested: int = maxi(0, amount)
	if requested <= 0 or is_dead():
		return 0

	if damage_channel == DAMAGE_CHANNEL_NONLETHAL:
		nonlethal_damage += requested
		_sync_combat_state_from_life()
		return requested

	var hp_before: int = current_hp
	current_hp -= requested
	if current_hp < 0:
		stable = false
	if current_hp <= death_threshold_hp():
		dead = true
		stable = false
	_sync_combat_state_from_life()
	_end_rage_if_incapacitated()
	return hp_before - current_hp


func _end_rage_if_incapacitated() -> void:
	if (is_unconscious() or is_dead()) and active_character_modifier_ids.has(&"effect.rage"):
		active_character_modifier_ids.erase(&"effect.rage")
		if not active_character_modifier_ids.has(&"effect.fatigued"):
			active_character_modifier_ids.append(&"effect.fatigued")
		rage_rounds_remaining = 0
		fatigued_after_rage = true
		character_resolution_refresh_pending = true


func apply_healing(amount: int) -> int:
	var requested: int = maxi(0, amount)
	if requested <= 0 or is_dead():
		return 0
	var before: int = current_hp
	current_hp = mini(maximum_hp, current_hp + requested)
	# Healing a living downed character ends the current Dying track. If the
	# result remains below 0 HP, the character is Stable; at 0 HP they are
	# Disabled, and above 0 HP they wake normally.
	stable = current_hp < 0
	dying_successes = 0
	dying_failures = 0
	last_dying_check_round = 0
	_sync_combat_state_from_life()
	return current_hp - before


func restore_damage_state(
		hp_value: int,
		nonlethal_value: int
) -> void:
	current_hp = mini(maximum_hp, hp_value)
	nonlethal_damage = maxi(0, nonlethal_value)
	dead = current_hp <= death_threshold_hp()
	stable = false
	dying_successes = 0
	dying_failures = 0
	last_dying_check_round = 0
	_sync_combat_state_from_life()


func life_state_snapshot() -> Dictionary:
	return {
		"current_hp": current_hp,
		"nonlethal_damage": nonlethal_damage,
		"dying_successes": dying_successes,
		"dying_failures": dying_failures,
		"stable": stable,
		"dead": dead,
		"last_dying_check_round": last_dying_check_round,
		"combat_state": combat_state,
		"restrained": restrained,
		"captive": captive,
		"restraint_item_id": restraint_item_id,
		"awaiting_body_placement": awaiting_body_placement,
		"ability_uses_remaining": ability_uses_remaining.duplicate(true),
		"timed_effect_rounds": timed_effect_rounds.duplicate(true),
		"timed_effect_source_ids": timed_effect_source_ids.duplicate(true),
		"timed_effect_values": timed_effect_values.duplicate(true),
		"concentration_action_id": concentration_action_id,
		"kneeling": kneeling,
		"subdual_takedown_target_id": subdual_takedown_target_id,
		"rage_rounds_remaining": rage_rounds_remaining,
		"fatigued_after_rage": fatigued_after_rage,
		"character_resolution_refresh_pending": character_resolution_refresh_pending,
		"carried_weight_lb": carried_weight_lb,
		"load_category": load_category,
		"sprint_distance_feet": sprint_distance_feet,
		"fast_movement_active": fast_movement_active,
		"grappled_by_unit_id": grappled_by_unit_id,
		"grappling_target_unit_id": grappling_target_unit_id,
		"nonlethal_incapacitation_source_unit_id": nonlethal_incapacitation_source_unit_id,
		"nonlethal_incapacitation_event_id": nonlethal_incapacitation_event_id,
	}


func restore_life_state(snapshot: Dictionary) -> void:
	current_hp = int(snapshot.get("current_hp", current_hp))
	nonlethal_damage = maxi(0, int(
		snapshot.get("nonlethal_damage", nonlethal_damage)
	))
	dying_successes = clampi(int(
		snapshot.get("dying_successes", dying_successes)
	), 0, 3)
	dying_failures = clampi(int(
		snapshot.get("dying_failures", dying_failures)
	), 0, 3)
	stable = bool(snapshot.get("stable", stable))
	dead = bool(snapshot.get("dead", dead))
	last_dying_check_round = maxi(0, int(
		snapshot.get("last_dying_check_round", last_dying_check_round)
	))
	restrained = bool(snapshot.get("restrained", restrained))
	captive = bool(snapshot.get("captive", captive))
	restraint_item_id = StringName(snapshot.get(
		"restraint_item_id", restraint_item_id
	))
	awaiting_body_placement = bool(snapshot.get(
		"awaiting_body_placement", awaiting_body_placement
	))
	ability_uses_remaining = (snapshot.get(
		"ability_uses_remaining", ability_uses_remaining
	) as Dictionary).duplicate(true)
	timed_effect_rounds = (snapshot.get(
		"timed_effect_rounds", timed_effect_rounds
	) as Dictionary).duplicate(true)
	timed_effect_source_ids = (snapshot.get(
		"timed_effect_source_ids", timed_effect_source_ids
	) as Dictionary).duplicate(true)
	timed_effect_values = (snapshot.get(
		"timed_effect_values", timed_effect_values
	) as Dictionary).duplicate(true)
	concentration_action_id = StringName(snapshot.get(
		"concentration_action_id", concentration_action_id
	))
	kneeling = bool(snapshot.get("kneeling", kneeling))
	subdual_takedown_target_id = StringName(snapshot.get(
		"subdual_takedown_target_id", subdual_takedown_target_id
	))
	rage_rounds_remaining = int(snapshot.get(
		"rage_rounds_remaining", rage_rounds_remaining
	))
	fatigued_after_rage = bool(snapshot.get(
		"fatigued_after_rage", fatigued_after_rage
	))
	character_resolution_refresh_pending = bool(snapshot.get(
		"character_resolution_refresh_pending", character_resolution_refresh_pending
	))
	carried_weight_lb = float(snapshot.get("carried_weight_lb", carried_weight_lb))
	load_category = StringName(snapshot.get("load_category", load_category))
	sprint_distance_feet = int(snapshot.get("sprint_distance_feet", sprint_distance_feet))
	fast_movement_active = bool(snapshot.get("fast_movement_active", fast_movement_active))
	grappled_by_unit_id = StringName(snapshot.get("grappled_by_unit_id", grappled_by_unit_id))
	grappling_target_unit_id = StringName(snapshot.get("grappling_target_unit_id", grappling_target_unit_id))
	nonlethal_incapacitation_source_unit_id = StringName(snapshot.get("nonlethal_incapacitation_source_unit_id", nonlethal_incapacitation_source_unit_id))
	nonlethal_incapacitation_event_id = StringName(snapshot.get("nonlethal_incapacitation_event_id", nonlethal_incapacitation_event_id))
	_sync_combat_state_from_life()


func life_state_id() -> StringName:
	return StringName(LIFE_STATE_RULES_SCRIPT.call(
		"resolve_state",
		current_hp,
		constitution_score(),
		stable,
		dead,
		nonlethal_damage
	))


func constitution_score() -> int:
	if resolved_character == null:
		return 10
	return maxi(1, resolved_character.ability_score("CON"))


func fortitude_bonus() -> int:
	if resolved_character == null:
		return 0
	return resolved_character.stat_value(&"fortitude", 0)


func medicine_bonus() -> int:
	if resolved_character == null:
		return 0
	if resolved_character.skill_bonuses.has("Medicine"):
		return int(resolved_character.skill_bonuses.get("Medicine", 0))
	if resolved_character.skill_bonuses.has(&"Medicine"):
		return int(resolved_character.skill_bonuses.get(&"Medicine", 0))
	# Heal/Medicine ranks are not implemented yet. Wisdom is the explicit
	# 3.5-style fallback so the working action has one visible authority.
	return resolved_character.ability_modifier("WIS")


func death_threshold_hp() -> int:
	return int(LIFE_STATE_RULES_SCRIPT.call(
		"death_threshold_hp", constitution_score()
	))


func dying_check_dc() -> int:
	return int(LIFE_STATE_RULES_SCRIPT.call("dying_check_dc", current_hp))


func is_disabled() -> bool:
	return life_state_id() == LIFE_STATE_DISABLED


func is_dying() -> bool:
	return life_state_id() == LIFE_STATE_DYING


func is_stable_unconscious() -> bool:
	return life_state_id() == LIFE_STATE_STABLE_UNCONSCIOUS


func is_nonlethal_unconscious() -> bool:
	return life_state_id() == LIFE_STATE_NONLETHAL_UNCONSCIOUS


func is_unconscious() -> bool:
	return bool(LIFE_STATE_RULES_SCRIPT.call(
		"is_unconscious_state", life_state_id()
	))


func is_dead() -> bool:
	return life_state_id() == LIFE_STATE_DEAD


func is_downed() -> bool:
	return bool(LIFE_STATE_RULES_SCRIPT.call(
		"is_downed_state", life_state_id()
	))


func has_fallen_body_state() -> bool:
	return is_dying() or is_unconscious() or is_dead()


func requires_body_item() -> bool:
	return has_fallen_body_state() or restrained or awaiting_body_placement


func blocks_standing_space() -> bool:
	# Exactly 0 HP remains Disabled and continues to occupy its footprint.
	# A conscious character awaiting removal from a Backpack/dragging slot remains
	# represented by its body item until a legal ground cell is available.
	return not requires_body_item()


func is_helpless_body() -> bool:
	return (has_fallen_body_state() or restrained) and not is_dead()


func body_inventory_footprint() -> Vector2i:
	if footprint.x >= 2 or footprint.y >= 2:
		# Large bodies cannot fit in the current 10x4 ordinary Backpack.
		return Vector2i(11, 4)
	return Vector2i(4, 3)


func apply_restraint(item_id: StringName) -> bool:
	if not is_helpless_body() or item_id.is_empty() or restrained:
		return false
	restrained = true
	captive = true
	restraint_item_id = item_id
	_sync_combat_state_from_life()
	return true


func remove_restraint() -> StringName:
	var released_item_id: StringName = restraint_item_id
	restrained = false
	captive = false
	restraint_item_id = &""
	_sync_combat_state_from_life()
	return released_item_id


func set_awaiting_body_placement(value: bool) -> void:
	awaiting_body_placement = value
	_sync_combat_state_from_life()


func is_defeated() -> bool:
	# Compatibility semantic: defeated means unable to take ordinary actions.
	return is_unconscious() or is_dead() or restrained or awaiting_body_placement


func is_incapacitated() -> bool:
	return (
		action_incapacitated
		or is_unconscious()
		or is_dead()
		or restrained
		or awaiting_body_placement
	)


func set_action_incapacitated(value: bool) -> void:
	action_incapacitated = value
	if value:
		mark_activation_ended()


func can_take_actions() -> bool:
	return (
		not is_unconscious()
		and not is_dead()
		and not restrained
		and not awaiting_body_placement
		and not action_incapacitated
	)


func participates_in_initiative() -> bool:
	return can_take_actions() or is_dying()


func can_receive_dying_turn() -> bool:
	return is_dying()


func reset_dying_track() -> void:
	dying_successes = 0
	dying_failures = 0
	last_dying_check_round = 0


func become_stable() -> void:
	if current_hp >= 0 or is_dead():
		return
	stable = true
	dying_successes = 0
	dying_failures = 0
	last_dying_check_round = 0
	_sync_combat_state_from_life()


func add_dying_successes(amount: int) -> void:
	if not is_dying():
		return
	dying_successes = clampi(dying_successes + maxi(0, amount), 0, 3)
	if dying_successes >= 3:
		become_stable()


func add_dying_failures(amount: int) -> void:
	if not is_dying():
		return
	dying_failures = clampi(dying_failures + maxi(0, amount), 0, 3)
	if dying_failures >= 3:
		dead = true
		stable = false
		_sync_combat_state_from_life()


func finish_off() -> bool:
	if is_dead() or not is_helpless_body():
		return false
	dead = true
	stable = false
	_sync_combat_state_from_life()
	return is_dead()


func apply_disabled_strain() -> bool:
	if not is_disabled():
		return false
	apply_damage(1, DAMAGE_CHANNEL_LETHAL)
	return true


func _sync_combat_state_from_life() -> void:
	combat_state = (
		COMBAT_STATE_DEFEATED
		if is_unconscious() or is_dead() or restrained or awaiting_body_placement
		else COMBAT_STATE_ACTIVE
	)
	if is_disabled() and action_budget != null:
		var disabled_capacity: int = maxi(5, int(
			floor(float(action_budget.maximum_turn_capacity_feet) * 0.5)
		))
		if action_budget.remaining_turn_capacity_feet > disabled_capacity:
			action_budget.remaining_turn_capacity_feet = disabled_capacity
			action_budget.normal_capacity_spent_feet = (
				action_budget.maximum_turn_capacity_feet - disabled_capacity
			)
		action_budget.spend_reaction()
	if is_unconscious() or is_dead():
		mark_activation_ended()


func mark_activation_ended() -> void:
	action_budget.ended_activation = true
	disengage_active = false


func reactivate_without_refresh() -> void:
	action_budget.ended_activation = false


func activate_disengage() -> void:
	disengage_active = true


func clear_disengage() -> void:
	disengage_active = false


func can_use_reaction() -> bool:
	return (
		can_take_actions()
		and not is_disabled()
		and action_budget.reaction_state != ReactionResourceState.SPENT
	)


func configure_control_from_team(team: StringName) -> void:
	match team:
		&"player":
			controller_type = CONTROLLER_PLAYER
			turn_behavior = TURN_BEHAVIOR_STANDARD
			participates_in_enemy_turn = false
			counts_for_victory = true
		&"enemy":
			controller_type = CONTROLLER_AI
			turn_behavior = TURN_BEHAVIOR_AUTO_PASS
			participates_in_enemy_turn = true
			counts_for_victory = true
		_:
			controller_type = CONTROLLER_WORLD
			turn_behavior = TURN_BEHAVIOR_NONE
			participates_in_enemy_turn = false
			counts_for_victory = false


func configure_tactical_control(
		controller: StringName,
		behavior: StringName,
		receives_enemy_turn: bool,
		victory_relevant: bool
) -> void:
	controller_type = controller
	turn_behavior = behavior
	participates_in_enemy_turn = receives_enemy_turn
	counts_for_victory = victory_relevant


func is_player_controlled() -> bool:
	return team_id == &"player" and controller_type == CONTROLLER_PLAYER


func is_ai_controlled() -> bool:
	return controller_type == CONTROLLER_AI


func set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	facing_direction = Vector2i(signi(direction.x), signi(direction.y))


func enter_stealth() -> void:
	stealth_enabled = true


func leave_stealth() -> void:
	stealth_enabled = false
	clear_current_stealth_roll()


func set_current_stealth_roll(raw_roll: int, total: int) -> void:
	current_stealth_roll_valid = true
	current_stealth_roll_value = clampi(raw_roll, 1, 20)
	current_stealth_total = total


func clear_current_stealth_roll() -> void:
	current_stealth_roll_valid = false
	current_stealth_roll_value = 0
	current_stealth_total = 0


func reveal_to_squad(revealing_squad_id: StringName) -> bool:
	if revealing_squad_id.is_empty():
		return false
	if revealed_to_squad_ids.has(revealing_squad_id):
		return false
	revealed_to_squad_ids.append(revealing_squad_id)
	revealed_to_squad_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b)
	)
	return true


func conceal_from_squad(concealing_squad_id: StringName) -> void:
	revealed_to_squad_ids.erase(concealing_squad_id)


func clear_revelation() -> void:
	revealed_to_squad_ids.clear()


func is_revealed_to_squad(observer_squad_id: StringName) -> bool:
	return revealed_to_squad_ids.has(observer_squad_id)


func is_hidden_from_squad(observer_squad_id: StringName) -> bool:
	return stealth_enabled and not is_revealed_to_squad(observer_squad_id)


func shows_hidden_badge() -> bool:
	return (
		team_id == &"player"
		and stealth_enabled
		and not is_downed()
		and revealed_to_squad_ids.is_empty()
	)


func stealth_bonus() -> int:
	if resolved_character == null:
		return 0
	var base_value: int = resolved_character.ability_modifier("DEX")
	if resolved_character.skill_bonuses.has("Stealth"):
		base_value = int(resolved_character.skill_bonuses.get("Stealth", 0))
	elif resolved_character.skill_bonuses.has(&"Stealth"):
		base_value = int(resolved_character.skill_bonuses.get(&"Stealth", 0))
	# Only the already-used Stealth calculation is made dynamic in Hotfix 5.
	# The authored value is the lightly loaded, armoured total. Reconstruct the
	# current value when Dexterity or equipped armour changes.
	var template_dex: int = 1 if resolved_character.template_id == &"character_template.reaver.marauder_tier_1" else resolved_character.ability_modifier("DEX")
	var template_armour_penalty: int = -1 if resolved_character.template_id == &"character_template.reaver.marauder_tier_1" else 0
	base_value += resolved_character.ability_modifier("DEX") - template_dex
	base_value += resolved_character.stat_value(&"armour_check_penalty", 0) - template_armour_penalty
	return base_value


func passive_perception() -> int:
	if resolved_character == null:
		return 10
	return resolved_character.stat_value(&"passive_perception", 10)


func initiative_modifier() -> int:
	if resolved_character == null:
		return 0
	return resolved_character.stat_value(&"initiative", 0)


func should_receive_enemy_turn() -> bool:
	return (
		team_id == &"enemy"
		and controller_type == CONTROLLER_AI
		and participates_in_enemy_turn
	)
