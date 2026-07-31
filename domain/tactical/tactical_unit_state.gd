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
		dying_successes = 0
		dying_failures = 0
		stable = false
		dead = false
		last_dying_check_round = 0
		combat_state = COMBAT_STATE_ACTIVE
		action_budget = ActionBudgetState.new(capacity)
	else:
		# Preserve actual negative HP rather than converting it to ordinary
		# damage against the newly resolved maximum. Positive HP still tracks
		# previous damage when maximum HP changes.
		current_hp = (
			previous_hp
			if previous_hp <= 0
			else clampi(maximum_hp - previous_damage, 1, maximum_hp)
		)
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
		_sync_combat_state_from_life()

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
	disengage_active = false
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
	return hp_before - current_hp


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
	return Vector2i(4, 4)


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
	if resolved_character.skill_bonuses.has("Stealth"):
		return int(resolved_character.skill_bonuses.get("Stealth", 0))
	if resolved_character.skill_bonuses.has(&"Stealth"):
		return int(resolved_character.skill_bonuses.get(&"Stealth", 0))
	# The complete 3.5e skill-rank implementation is later. Dexterity is the
	# explicit fallback so the preview and roll still share one authority.
	return resolved_character.ability_modifier("DEX")


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
