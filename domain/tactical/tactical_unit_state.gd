class_name TacticalUnitState
extends RefCounted

const CONTROLLER_PLAYER: StringName = &"player"
const CONTROLLER_AI: StringName = &"ai"
const CONTROLLER_WORLD: StringName = &"world"

const TURN_BEHAVIOR_STANDARD: StringName = &"standard"
const TURN_BEHAVIOR_AUTO_PASS: StringName = &"auto_pass"
const TURN_BEHAVIOR_NONE: StringName = &"none"

const DAMAGE_CHANNEL_LETHAL: StringName = &"lethal"
const DAMAGE_CHANNEL_NONLETHAL: StringName = &"nonlethal"

const COMBAT_STATE_ACTIVE: StringName = &"active"
const COMBAT_STATE_DEFEATED: StringName = &"defeated"

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

var maximum_hp: int
var current_hp: int
# Nonlethal damage is tracked independently from lethal HP loss. Stage 4.0.5
# exposes the damage channel but deliberately defers unconsciousness rules.
var nonlethal_damage: int = 0
# Stage 4.1 uses a deliberately minimal lethal outcome. A unit at 0 HP is
# Defeated, remains on the map, and cannot act. Corpse/death rules are later.
var combat_state: StringName = COMBAT_STATE_ACTIVE
# Deprecated compatibility cache for unresolved fixtures only.
var base_armour_class: int
# Runtime cache rebuilt exclusively from resolved_character.armour_class.
var armour_class: int
var inventory: TacticalInventoryState
var resolved_character: ResolvedCharacterSnapshot
var character_sheet: TacticalCharacterSheetState
var active_character_modifier_ids: Array[StringName] = []


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
	action_budget = ActionBudgetState.new(maximum_capacity_value)
	diagonal_steps_used = 0
	footprint = Vector2i.ONE

	maximum_hp = maxi(1, maximum_hp_value)
	current_hp = maximum_hp
	nonlethal_damage = 0
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

	var previous_damage := maxi(0, maximum_hp - current_hp)
	var previous_nonlethal_damage: int = maxi(0, nonlethal_damage)
	var previous_spent := action_budget.normal_capacity_spent_feet
	var previous_quick := action_budget.quick_action_available
	var previous_reaction := action_budget.reaction_available
	var previous_ordinary_attack_available: bool = (
		action_budget.ordinary_attack_available
	)
	var previous_ended := action_budget.ended_activation

	resolved_character = snapshot
	character_sheet.configure_from_snapshot(snapshot)
	display_name = snapshot.display_name
	team_id = snapshot.team_id
	faction_id = snapshot.faction_id
	roster_role = snapshot.roster_role
	persistence_scope = snapshot.persistence_scope
	footprint = snapshot.footprint
	maximum_hp = maxi(1, snapshot.stat_value(&"maximum_hp", 1))
	# ResolvedCharacterSnapshot is the sole combat authority for Armour Class.
	armour_class = snapshot.stat_value(&"armour_class", 10)
	base_armour_class = armour_class

	var capacity := maxi(5, snapshot.stat_value(&"turn_capacity", 30))
	if not preserve_runtime_state:
		current_hp = maximum_hp
		nonlethal_damage = 0
		combat_state = COMBAT_STATE_ACTIVE
		action_budget = ActionBudgetState.new(capacity)
	else:
		current_hp = clampi(maximum_hp - previous_damage, 0, maximum_hp)
		nonlethal_damage = previous_nonlethal_damage
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
		action_budget.reaction_available = previous_reaction
		action_budget.ordinary_attack_available = (
			previous_ordinary_attack_available
		)
		action_budget.ended_activation = previous_ended
		_sync_combat_state_from_hp()

	inventory.maximum_weight_lb = float(
		snapshot.stat_value(&"maximum_weight_lb", 60)
	)


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
	action_budget.refresh_for_new_round()
	diagonal_steps_used = 0
	if is_defeated():
		mark_activation_ended()


func lethal_damage_taken() -> int:
	return maxi(0, maximum_hp - current_hp)


func apply_damage(
		amount: int,
		damage_channel: StringName = DAMAGE_CHANNEL_LETHAL
) -> int:
	var requested: int = maxi(0, amount)
	if requested <= 0:
		return 0

	if damage_channel == DAMAGE_CHANNEL_NONLETHAL:
		nonlethal_damage += requested
		return requested

	var hp_before: int = current_hp
	current_hp = maxi(0, current_hp - requested)
	_sync_combat_state_from_hp()
	return hp_before - current_hp


func restore_damage_state(
		hp_value: int,
		nonlethal_value: int
) -> void:
	current_hp = clampi(hp_value, 0, maximum_hp)
	nonlethal_damage = maxi(0, nonlethal_value)
	_sync_combat_state_from_hp()


func is_defeated() -> bool:
	return combat_state == COMBAT_STATE_DEFEATED or current_hp <= 0


func can_take_actions() -> bool:
	return not is_defeated()


func _sync_combat_state_from_hp() -> void:
	combat_state = (
		COMBAT_STATE_DEFEATED
		if current_hp <= 0
		else COMBAT_STATE_ACTIVE
	)


func mark_activation_ended() -> void:
	action_budget.ended_activation = true


func reactivate_without_refresh() -> void:
	action_budget.ended_activation = false


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


func should_receive_enemy_turn() -> bool:
	return (
		team_id == &"enemy"
		and controller_type == CONTROLLER_AI
		and participates_in_enemy_turn
	)
