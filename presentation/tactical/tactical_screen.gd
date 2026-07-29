extends Node2D

const UNIT_VIEW_SCENE: PackedScene = preload(
	"res://presentation/tactical/tactical_unit_view.tscn"
)
const UNIT_MANAGEMENT_WINDOW_SCENE: PackedScene = preload(
	"res://presentation/tactical/unit_management_window.tscn"
)
const TACTICAL_BOARD_VIEW_SCRIPT: Script = preload(
	"res://presentation/tactical/tactical_board_view.gd"
)
const TACTICAL_COMBAT_LOG_SCENE: PackedScene = preload(
	"res://presentation/tactical/combat_log/tactical_combat_log.tscn"
)
const ROSTER_UNIT_BUTTON_SCRIPT: Script = preload(
	"res://presentation/tactical/widgets/roster_unit_button.gd"
)

@onready var _board_view: Variant = $BoardView
@onready var _unit_layer: Node2D = $BoardView/UnitLayer

@onready var _objective_label: Label = $HUD/TopBar/Margin/Row/ObjectiveLabel
@onready var _phase_label: Label = $HUD/TopBar/Margin/Row/PhaseLabel
@onready var _hint_label: Label = $HUD/TopBar/Margin/Row/HintLabel

@onready var _roster_container: VBoxContainer = $HUD/RosterPanel/Margin/VBox

@onready var _short_name_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortNameLabel
@onready var _unit_health_bar: Control = $HUD/BottomDeck/Margin/MainRow/UnitBlock/UnitHealthBar
@onready var _short_hp_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortHPLabel
@onready var _short_capacity_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortCapacityLabel
@onready var _unit_capacity_bar: ProgressBar = $HUD/BottomDeck/Margin/MainRow/UnitBlock/UnitCapacityBarContainer/UnitCapacityBar
@onready var _unit_capacity_value_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/UnitCapacityBarContainer/UnitCapacityValueLabel
@onready var _short_context_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortContextLabel
@onready var _attack_mode_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/AttackOptions/AttackModeButton
@onready var _power_attack_down_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/AttackOptions/PowerAttackDownButton
@onready var _power_attack_value_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/AttackOptions/PowerAttackValueButton
@onready var _power_attack_up_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/AttackOptions/PowerAttackUpButton
@onready var _left_hand_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/HandRow/LeftHandButton
@onready var _right_hand_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/HandRow/RightHandButton
@onready var _attack_cursor_preview: PanelContainer = $HUD/AttackCursorPreview
@onready var _attack_cursor_label: Label = $HUD/AttackCursorPreview/Margin/Label

@onready var _attack_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/AttackButton
@onready var _abilities_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/AbilitiesButton
@onready var _tactics_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/TacticsButton
@onready var _inventory_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/InventoryButton
@onready var _interact_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/InteractButton
@onready var _end_unit_button: Button = $HUD/BottomDeck/Margin/MainRow/CommandBlock/CommandButtons/EndUnitButton

@onready var _context_tray: PanelContainer = $HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray
@onready var _context_action_buttons: Array[Button] = [
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action1,
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action2,
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action3,
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action4,
	$HUD/BottomDeck/Margin/MainRow/CommandBlock/ContextTray/Margin/Actions/Action5,
]

@onready var _end_phase_button: Button = $HUD/BottomDeck/Margin/MainRow/PhaseBlock/EndPhaseButton
@onready var _round_short_label: Label = $HUD/BottomDeck/Margin/MainRow/PhaseBlock/RoundShortLabel

var _facade
var _map_definition: TacticalMapDefinition
var _player_unit_order: Array[StringName] = []
var _portrait_resolver: PortraitAssetResolver

var _unit_views: Dictionary = {}
var _unit_buttons: Dictionary = {}
var _selected_unit_id: StringName = &""
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _preview_result: MovementPathResult
var _world_phase_in_progress: bool = false
var _inventory_open: bool = false
var _active_category: StringName = &""
var _context_action_ids: Array[StringName] = [&"", &"", &"", &"", &""]
var _movement_mode: StringName = &"normal"
var _last_status_message: String = "Ready."
var _active_hand_name: String = ""
var _active_hand_item: String = ""
var _active_hand_item_id: StringName = &""
var _selected_weapon_hand_kind: StringName = &""
var _selected_weapon_item_id: StringName = &""
var _unit_management_window: UnitManagementWindow
var _combat_log: Variant
var _attack_targeting: bool = false
var _selected_attack_id: StringName = &""
var _selected_attack_target_id: StringName = &""
var _power_attack_value: int = 0
var _selected_damage_channel: StringName = (
	TacticalUnitState.DAMAGE_CHANNEL_LETHAL
)
var _legal_attack_target_ids: Array[StringName] = []
var _attack_preview


func configure(session: TacticalSession) -> void:
	_facade = session.screen_facade if session != null else null


func _ready() -> void:
	if _facade == null:
		push_error("TacticalScreen requires a configured TacticalScreenFacade.")
		return

	if (
		_board_view == null
		or _board_view.get_script() != TACTICAL_BOARD_VIEW_SCRIPT
		or not _board_view.has_method("configure")
	):
		push_error(
			"TacticalScreen requires BoardView to use "
			+ "tactical_board_view.gd."
		)
		return

	_map_definition = _facade.map_definition()
	_player_unit_order = _facade.player_unit_order()
	_portrait_resolver = PortraitAssetResolver.new()

	_board_view.configure(_map_definition, _facade)
	_board_view.tile_hovered.connect(_on_board_tile_hovered)
	_board_view.tile_left_clicked.connect(_on_board_tile_left_clicked)
	_board_view.board_right_clicked.connect(_on_board_right_clicked)

	_combat_log = TACTICAL_COMBAT_LOG_SCENE.instantiate()
	$HUD.add_child(_combat_log)
	if (
		_combat_log != null
		and _combat_log.has_method("configure")
	):
		_combat_log.call("configure", _facade.event_journal())

	_unit_management_window = (
		UNIT_MANAGEMENT_WINDOW_SCENE.instantiate()
		as UnitManagementWindow
	)
	$HUD.add_child(_unit_management_window)
	var initial_unit_id: StringName = (
		_player_unit_order[0]
		if not _player_unit_order.is_empty()
		else &""
	)
	_unit_management_window.configure(
		_facade,
		_portrait_resolver,
		initial_unit_id,
		_player_unit_order
	)
	_unit_management_window.closed.connect(_on_unit_management_closed)
	_unit_management_window.unit_changed.connect(
		_on_unit_management_unit_changed
	)
	_unit_management_window.message_requested.connect(_set_status)

	_create_roster_buttons()

	_facade.state_changed.connect(_on_state_changed)


	_abilities_button.pressed.connect(func() -> void: _toggle_action_category(&"abilities"))
	_tactics_button.pressed.connect(func() -> void: _toggle_action_category(&"tactics"))
	_inventory_button.pressed.connect(_toggle_inventory)
	_interact_button.pressed.connect(func() -> void: _toggle_action_category(&"interact"))
	_end_unit_button.pressed.connect(_on_end_unit_pressed)
	_end_phase_button.pressed.connect(_on_end_phase_pressed)

	for index: int in range(_context_action_buttons.size()):
		_context_action_buttons[index].pressed.connect(
			_on_context_action_pressed.bind(index)
		)

	_left_hand_button.pressed.connect(
		_select_weapon_from_hand.bind(TacticalInventoryState.KIND_SECONDARY_HAND)
	)
	_right_hand_button.pressed.connect(
		_select_weapon_from_hand.bind(TacticalInventoryState.KIND_PRIMARY_HAND)
	)
	_attack_mode_button.pressed.connect(_cycle_attack_mode)
	_power_attack_down_button.pressed.connect(_adjust_power_attack.bind(-1))
	_power_attack_value_button.pressed.connect(_cycle_power_attack)
	_power_attack_up_button.pressed.connect(_adjust_power_attack.bind(1))

	_create_unit_views()
	if not initial_unit_id.is_empty():
		_select_unit(initial_unit_id)
	_set_status(
		"Stage 4.1.1 active: select a held weapon, hover a hostile, then left-click to attack."
	)
	_refresh_all_presentation()


func _process(_delta: float) -> void:
	if _attack_cursor_preview != null and _attack_cursor_preview.visible:
		_position_attack_cursor_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_L:
			if (
				not _inventory_open
				and _combat_log != null
				and _combat_log.has_method("toggle_expanded")
			):
				_combat_log.call("toggle_expanded")
			return

		if _inventory_open:
			return

		match key_event.keycode:
			KEY_I:
				_toggle_inventory()
			KEY_A:
				_select_weapon_from_hand(TacticalInventoryState.KIND_PRIMARY_HAND)
			KEY_ESCAPE:
				if _attack_targeting:
					_clear_weapon_selection("Weapon targeting cancelled.")
				elif _movement_mode != &"normal":
					_movement_mode = &"normal"
					_set_status("Special movement mode cancelled.")
					_refresh_path_preview()
				elif _active_category != &"":
					_hide_context_tray()
				else:
					_selected_unit_id = &""
					_preview_result = null
					_update_unit_selection_visuals()
					_set_status("Unit deselected.")
					_refresh_all_presentation()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				_select_unit_by_shortcut(int(key_event.keycode - KEY_1))
		return

func _on_board_tile_hovered(tile: Vector2i) -> void:
	if _inventory_open:
		return
	_hovered_tile = tile
	_refresh_path_preview()

func _on_board_tile_left_clicked(tile: Vector2i) -> void:
	if _inventory_open:
		return
	if _attack_targeting:
		var target: TacticalUnitState = _facade.state().get_unit_at_tile(
			tile,
			_selected_unit_id
		)
		if target != null:
			if not _facade.are_units_hostile(
				_selected_unit_id,
				target.unit_id
			):
				# Friendly and neutral units are selection/inspection targets,
				# never accidental attack targets.
				_select_unit(target.unit_id)
				return
			_execute_direct_attack(target)
			return
	_handle_left_click(tile)

func _on_board_right_clicked(tile: Vector2i) -> void:
	if _inventory_open:
		return
	if _attack_targeting:
		var target: TacticalUnitState = _facade.state().get_unit_at_tile(
			tile,
			_selected_unit_id
		)
		if (
			target != null
			and _facade.are_units_hostile(_selected_unit_id, target.unit_id)
		):
			_cycle_attack_mode()
			return
		_clear_weapon_selection("Weapon targeting cancelled.")
		return
	if _movement_mode != &"normal":
		_movement_mode = &"normal"
		_set_status("Special movement mode cancelled.")
	else:
		_selected_unit_id = &""
		_set_status("Unit deselected. Select a unit on the board or roster.")
	_preview_result = null
	_update_unit_selection_visuals()
	_refresh_all_presentation()

func _create_roster_buttons() -> void:
	for child: Node in _roster_container.get_children():
		if child.name in [&"MarauderButton", &"ArcherButton", &"ScoutButton"]:
			child.queue_free()
	_unit_buttons.clear()
	for index: int in range(_player_unit_order.size()):
		var unit_id: StringName = _player_unit_order[index]
		var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
		if unit == null:
			continue
		var button: Button = ROSTER_UNIT_BUTTON_SCRIPT.new() as Button
		button.name = "RosterUnit%d" % (index + 1)
		button.pressed.connect(_select_unit.bind(unit_id))
		_roster_container.add_child(button)
		_roster_container.move_child(button, 1 + index)
		button.call(
			"refresh_unit",
			unit,
			index + 1,
			_facade.state().phase_state.is_player_phase(),
			unit_id == _selected_unit_id
		)
		_unit_buttons[unit_id] = button


func _select_unit_by_shortcut(index: int) -> void:
	if index < 0 or index >= _player_unit_order.size():
		return
	_select_unit(_player_unit_order[index])


func _unit_color(unit: TacticalUnitState) -> Color:
	if unit.team_id != &"player":
		return (
			Color(0.78, 0.20, 0.16, 1.0)
			if unit.roster_role == &"enemy"
			else Color(0.78, 0.68, 0.28, 1.0)
		)
	var index: int = _player_unit_order.find(unit.unit_id)
	var palette: Array[Color] = [
		Color(0.14, 0.46, 0.90, 1.0),
		Color(0.14, 0.68, 0.38, 1.0),
		Color(0.64, 0.30, 0.82, 1.0),
		Color(0.80, 0.42, 0.16, 1.0),
		Color(0.16, 0.66, 0.72, 1.0),
	]
	return palette[posmod(index, palette.size())] if index >= 0 else Color.WHITE


func _create_unit_views() -> void:
	for unit: TacticalUnitState in _facade.state().get_units():
		var view := UNIT_VIEW_SCENE.instantiate() as TacticalUnitView
		_unit_layer.add_child(view)
		var display_color: Color = _unit_color(unit)
		view.configure(
			unit,
			_board_view.board_origin(),
			_board_view.tile_size(),
			display_color
		)
		_unit_views[unit.unit_id] = view


func _handle_left_click(tile: Vector2i) -> void:
	if not _map_definition.is_inside(tile):
		return
	if not _facade.state().phase_state.is_player_phase():
		_set_status("Wait for the World Phase to finish.")
		return

	var clicked_unit: TacticalUnitState = _facade.state().get_unit_at_tile(tile)
	if clicked_unit != null:
		_select_unit(clicked_unit.unit_id)
		return

	if _selected_unit_id == &"":
		_set_status("Select a friendly unit before choosing a destination.")
		return

	_hovered_tile = tile
	_refresh_path_preview()

	if _preview_result == null or not _preview_result.success:
		var reason := "That destination cannot be reached."
		if _preview_result != null and not _preview_result.failure_reason.is_empty():
			reason = _preview_result.failure_reason
		_set_status(reason)
		_refresh_board_view()
		return

	var selected_unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if selected_unit == null:
		return
	if not selected_unit.is_player_controlled():
		_set_status("This unit is available for inspection only.")
		_preview_result = null
		_refresh_board_view()
		return
	if selected_unit.is_defeated():
		_set_status("Defeated units cannot move.")
		return
	if selected_unit.action_budget.ended_activation:
		_set_status("This unit is marked as ended. Select it again to reactivate it.")
		return

	var result: OperationResult = _facade.execute_movement(
		_selected_unit_id,
		tile,
		_movement_mode
	)

	if not result.success:
		_set_status(result.message)
		_refresh_board_view()
		return

	var completed_path := result.data as MovementPathResult
	var unit_view := _unit_views.get(_selected_unit_id) as TacticalUnitView
	if unit_view != null and completed_path != null:
		unit_view.animate_path(completed_path.path)

	_movement_mode = &"normal"
	_preview_result = null
	_set_status(result.message)
	_refresh_hud()
	_refresh_board_view()


func _select_unit(unit_id: StringName) -> void:
	if _attack_targeting:
		_clear_attack_targeting_state()
	_selected_weapon_hand_kind = &""
	_selected_weapon_item_id = &""
	if not _facade.state().phase_state.is_player_phase():
		return

	var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
	if unit == null:
		return

	if not unit.is_player_controlled():
		_selected_unit_id = unit_id
		_selected_weapon_hand_kind = &""
		_selected_weapon_item_id = &""
		_movement_mode = &"normal"
		_hide_context_tray()
		_update_unit_selection_visuals()
		_refresh_path_preview()
		_set_status(
			"%s selected for inspection. This %s is not player-controlled."
			% [unit.display_name, unit.roster_role]
		)
		_refresh_hud()
		return

	if unit.is_defeated():
		_set_status(
			"%s is Defeated and can only be inspected." % unit.display_name
		)
	elif unit.action_budget.ended_activation:
		var result: OperationResult = _facade.reactivate_unit(unit_id)
		_set_status(result.message)
	else:
		_set_status("%s selected." % unit.display_name)

	_selected_unit_id = unit_id
	if (
		_unit_management_window != null
		and _unit_management_window.visible
	):
		_unit_management_window.set_current_unit(unit_id)
	_movement_mode = &"normal"
	_hide_context_tray()
	_select_default_weapon_for_unit()
	_update_unit_selection_visuals()
	_refresh_path_preview()


func _execute_budget_action(
		action_name: String,
		action_id: StringName
) -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units can use tactical commands.")
		return

	var result: OperationResult = _facade.spend_action(
		_selected_unit_id,
		action_name,
		action_id
	)
	_set_status(result.message)
	_preview_result = null
	_refresh_path_preview()


func _toggle_action_category(category: StringName) -> void:
	if _attack_targeting:
		_clear_attack_targeting_state()
	if _inventory_open:
		_close_inventory()

	if _active_category == category and _context_tray.visible:
		_hide_context_tray()
		return

	_active_category = category
	_context_tray.visible = true

	match category:
		&"abilities":
			_configure_ability_actions()
		&"tactics":
			_configure_context_actions(
				[
					"Sprint [Full]",
					"Disengage [Half]",
					"Overwatch [Half + Reaction]",
					"More Tactics",
				],
				[&"sprint", &"disengage", &"overwatch", &"more_tactics"]
			)
		&"interact":
			_configure_context_actions(
				[
					"Context Interaction",
					"Open / Close",
					"Objective",
					"Climb / Drop",
				],
				[&"context_interact", &"open_close", &"objective", &"climb_drop"]
			)
			_refresh_path_preview()
		&"hand_inspect":
			_inspect_active_hand_item()
		&"hand_open_inventory":
			_open_inventory()
		_:
			_set_status("That action is displayed for UI planning but is not implemented yet.")

	_set_status("%s options opened." % String(category).capitalize())
	_refresh_context_action_availability()
	_refresh_hud()


func _configure_typed_attack_actions() -> void:
	var labels: Array[String] = []
	var ids: Array[StringName] = []
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)

	if unit != null and _facade != null:
		for action_id: StringName in _facade.granted_action_ids_for_unit(
			unit.unit_id
		):
			if not _facade.is_stage_4_attack(action_id):
				continue
			var attack: AttackDefinition = _facade.attack_definition(action_id)
			if attack == null:
				continue
			labels.append(
				"%s %+d [%s]"
				% [
					attack.display_name,
					unit.resolved_character.attack_bonus_for(attack),
					attack.cost_label(),
				]
			)
			ids.append(action_id)
			if labels.size() >= _context_action_buttons.size():
				break

	if labels.is_empty():
		labels.append("Equip Axe, Mace or Dagger")
		ids.append(&"")

	while labels.size() < _context_action_buttons.size():
		labels.append("")
		ids.append(&"")

	_configure_context_actions(labels, ids)

func _configure_context_actions(
		labels: Array[String],
		ids: Array[StringName]
) -> void:
	for index: int in range(_context_action_buttons.size()):
		var button := _context_action_buttons[index]
		var label := labels[index] if index < labels.size() else ""
		var action_id := ids[index] if index < ids.size() else &""

		button.text = label
		button.visible = not label.is_empty()
		_context_action_ids[index] = action_id


func _refresh_context_action_availability() -> void:
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)

	for index: int in range(_context_action_buttons.size()):
		var button: Button = _context_action_buttons[index]
		var action_id: StringName = _context_action_ids[index]

		button.disabled = false
		button.tooltip_text = ""

		if not button.visible:
			continue

		if unit == null:
			button.disabled = true
			button.tooltip_text = "Select a unit first."
			continue

		if not _facade.state().phase_state.is_player_phase():
			button.disabled = true
			button.tooltip_text = "Unavailable during the World Phase."
			continue

		var typed_action: ActionDefinition = _facade.action_definition(action_id)
		if typed_action != null:
			var typed_reason: String = _facade.action_unavailable_reason(
				unit.unit_id,
				action_id
			)
			if not _facade.is_stage_4_attack(action_id):
				button.disabled = true
				button.tooltip_text = "This attack is reserved for a later combat stage."
			else:
				button.disabled = not typed_reason.is_empty()
				button.tooltip_text = (
					typed_reason
					if not typed_reason.is_empty()
					else "Select this attack, then choose a highlighted target."
				)
			continue

		match action_id:
			&"attack_confirm":
				button.disabled = (
					_attack_preview == null
					or not bool(_attack_preview.get("success"))
					or _selected_attack_target_id.is_empty()
				)
				button.tooltip_text = (
					"Choose a highlighted target first."
					if button.disabled
					else "Commit the previewed attack and roll."
				)
			&"damage_mode_toggle":
				button.disabled = false
				button.tooltip_text = (
					"Switch between lethal and nonlethal damage. "
					+ "Nonlethal attacks normally take a −4 attack penalty."
				)
			&"power_attack_down":
				button.disabled = _power_attack_value <= 0
				button.tooltip_text = "Reduce Power Attack by 1."
			&"power_attack_up":
				button.disabled = _power_attack_value >= 3
				button.tooltip_text = "Increase Power Attack by 1: −1 attack, +1 damage."
			&"attack_cancel":
				button.disabled = false
			&"ready_stance", &"sprint":
				var reason: String = _facade.action_unavailable_reason(
					unit.unit_id,
					action_id
				)
				button.disabled = not reason.is_empty()
				button.tooltip_text = reason
			&"disengage":
				var reason: String = _facade.action_unavailable_reason(
					unit.unit_id,
					action_id
				)
				button.disabled = true
				button.tooltip_text = (
					reason
					if not reason.is_empty()
					else "Disengage becomes functional with Reactions later."
				)
			&"hand_inspect", &"hand_open_inventory":
				button.disabled = false
			&"hand_attack":
				button.disabled = not _active_hand_has_stage_4_attack()
				button.tooltip_text = (
					"Begin targeting with this held weapon."
					if not button.disabled
					else "This held item has no Stage 4.0 melee attack."
				)
			&"hand_full_attack", &"hand_overwatch":
				button.disabled = true
				button.tooltip_text = "Full Attacks and Overwatch are outside Stage 4.0."
			&"hand_drop":
				button.disabled = true
				button.tooltip_text = "Open Inventory to drop this item."
			_:
				button.disabled = true
				button.tooltip_text = "Visible placeholder for a later stage."

func _on_context_action_pressed(index: int) -> void:
	if index < 0 or index >= _context_action_ids.size():
		return

	var action_id: StringName = _context_action_ids[index]
	var typed_action: ActionDefinition = (
		_facade.action_definition(action_id)
		if _facade != null
		else null
	)
	if typed_action is AttackDefinition:
		_begin_attack_targeting(action_id)
		return
	if typed_action != null:
		_set_status("That typed action is reserved for a later stage.")
		return

	match action_id:
		&"attack_confirm":
			_confirm_selected_attack()
		&"damage_mode_toggle":
			_toggle_damage_mode()
		&"power_attack_down":
			_adjust_power_attack(-1)
		&"power_attack_up":
			_adjust_power_attack(1)
		&"attack_cancel":
			_cancel_attack_targeting("Attack targeting cancelled.")
		&"ready_stance":
			_execute_budget_action("Ready Stance", &"ready_stance")
		&"rage_toggle":
			_toggle_rage()
		&"sprint":
			_movement_mode = &"sprint"
			_hide_context_tray()
			_set_status(
				"Sprint selected. Choose a legal destination up to 150% "
				+ "Speed. Difficult terrain is unavailable."
			)
			_refresh_path_preview()
		&"hand_attack":
			_begin_active_hand_attack()
		&"hand_inspect":
			_inspect_active_hand_item()
		&"hand_open_inventory":
			_open_inventory()
		_:
			_set_status("That action is not implemented in Stage 4.0.")

func _select_default_weapon_for_unit() -> void:
	if not _selected_unit_is_player_controlled():
		_clear_attack_targeting_state()
		_selected_weapon_hand_kind = &""
		_selected_weapon_item_id = &""
		return
	for hand_kind: StringName in [
		TacticalInventoryState.KIND_PRIMARY_HAND,
		TacticalInventoryState.KIND_SECONDARY_HAND,
	]:
		var item: TacticalItemInstanceState = _facade.state().get_hand_item(
			_selected_unit_id,
			hand_kind
		)
		if not _stage_4_attack_id_for_item(item).is_empty():
			_select_weapon_from_hand(hand_kind)
			return
	_clear_attack_targeting_state()
	_selected_weapon_hand_kind = &""
	_selected_weapon_item_id = &""
	_refresh_weapon_attack_strip()


func _select_weapon_from_hand(hand_kind: StringName) -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units can select weapons.")
		return
	var item: TacticalItemInstanceState = _facade.state().get_hand_item(
		_selected_unit_id,
		hand_kind
	)
	var action_id: StringName = _stage_4_attack_id_for_item(item)
	if item == null or action_id.is_empty():
		_set_status("That hand does not contain a currently supported weapon attack.")
		_refresh_weapon_attack_strip()
		return
	_selected_weapon_hand_kind = hand_kind
	_selected_weapon_item_id = item.item_id
	_begin_attack_targeting(action_id)


func _stage_4_attack_id_for_item(
	item: TacticalItemInstanceState
) -> StringName:
	if item == null or item.definition == null or _facade == null:
		return &""
	for action_id: StringName in item.definition.granted_action_ids:
		if _facade.is_stage_4_attack(action_id):
			return action_id
	return &""


func _cycle_attack_mode() -> void:
	if not _attack_targeting:
		_set_status("Select a held weapon before changing attack mode.")
		return
	_toggle_damage_mode()


func _cycle_power_attack() -> void:
	if not _attack_targeting:
		return
	_power_attack_value = (_power_attack_value + 1) % 4
	_refresh_attack_configuration()


func _refresh_attack_configuration() -> void:
	_refresh_legal_attack_targets()
	if not _selected_attack_target_id.is_empty():
		_attack_preview = _facade.preview_attack(
			_selected_unit_id,
			_selected_attack_target_id,
			_selected_attack_id,
			_power_attack_value,
			_selected_damage_channel
		)
	_refresh_weapon_attack_strip()
	_refresh_attack_cursor_preview()
	_set_status(_attack_preview_status())
	_refresh_all_presentation()


func _execute_direct_attack(target: TacticalUnitState) -> void:
	if target == null or not _attack_targeting:
		return
	var preview = _facade.preview_attack(
		_selected_unit_id,
		target.unit_id,
		_selected_attack_id,
		_power_attack_value,
		_selected_damage_channel
	)
	_selected_attack_target_id = target.unit_id
	_attack_preview = preview
	if preview == null or not bool(preview.get("success")):
		_set_status(
			str(preview.get("reason"))
			if preview != null
			else "That target is unavailable."
		)
		_refresh_attack_cursor_preview()
		_refresh_all_presentation()
		return
	var result: OperationResult = _facade.execute_attack_preview(preview)
	_set_status(result.message)
	_selected_attack_target_id = &""
	_attack_preview = null
	_refresh_legal_attack_targets()
	_refresh_weapon_attack_strip()
	_refresh_attack_cursor_preview()
	_refresh_all_presentation()


func _clear_weapon_selection(message: String = "") -> void:
	_clear_attack_targeting_state()
	_selected_weapon_hand_kind = &""
	_selected_weapon_item_id = &""
	_context_tray.visible = false
	_active_category = &""
	_hide_attack_cursor_preview()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not message.is_empty():
		_set_status(message)
	_refresh_weapon_attack_strip()
	_refresh_all_presentation()


func _refresh_weapon_attack_strip() -> void:
	if _attack_mode_button == null or _facade == null:
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	var attack_reason: String = ""
	if unit != null and not _selected_attack_id.is_empty():
		attack_reason = _facade.action_unavailable_reason(
			unit.unit_id,
			_selected_attack_id
		)
	var usable: bool = (
		unit != null
		and unit.is_player_controlled()
		and not unit.is_defeated()
		and _facade.state().phase_state.is_player_phase()
		and not _selected_attack_id.is_empty()
		and attack_reason.is_empty()
	)
	var mode_text: String = (
		"NONLETHAL"
		if _selected_damage_channel
			== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
		else "LETHAL"
	)
	_attack_mode_button.text = (
		"NORMAL · %s" % mode_text
		if not _selected_attack_id.is_empty()
		else "NO WEAPON ATTACK"
	)
	_attack_mode_button.disabled = not usable
	_power_attack_down_button.disabled = not usable or _power_attack_value <= 0
	_power_attack_up_button.disabled = not usable or _power_attack_value >= 3
	_power_attack_value_button.disabled = not usable
	_power_attack_value_button.text = str(_power_attack_value)
	_left_hand_button.button_pressed = (
		not _selected_attack_id.is_empty()
		and _selected_weapon_hand_kind
			== TacticalInventoryState.KIND_SECONDARY_HAND
	)
	_right_hand_button.button_pressed = (
		not _selected_attack_id.is_empty()
		and _selected_weapon_hand_kind
			== TacticalInventoryState.KIND_PRIMARY_HAND
	)
	if usable:
		_attack_mode_button.tooltip_text = (
			"Normal %s attack. Click this button or right-click a hostile target to cycle damage mode."
			% mode_text.to_lower()
		)
	elif not attack_reason.is_empty():
		_attack_mode_button.tooltip_text = attack_reason
	else:
		_attack_mode_button.tooltip_text = "Select a supported held weapon."


func _refresh_attack_cursor_preview() -> void:
	if (
		not _attack_targeting
		or _selected_attack_target_id.is_empty()
		or _attack_preview == null
	):
		_hide_attack_cursor_preview()
		return
	_attack_cursor_preview.visible = true
	if bool(_attack_preview.get("success")):
		var mode_text: String = (
			"NONLETHAL"
			if StringName(_attack_preview.get("damage_channel"))
				== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
			else "LETHAL"
		)
		_attack_cursor_label.text = (
			"%d%% HIT\n%s %s\n%d ft · PA %d"
			% [
				int(_attack_preview.get("hit_chance_percent")),
				str(_attack_preview.get("damage_notation")),
				mode_text,
				int(_attack_preview.get("action_cost_feet")),
				int(_attack_preview.get("power_attack_value")),
			]
		)
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		_attack_cursor_label.text = "INVALID TARGET\n%s" % str(
			_attack_preview.get("reason")
		)
		Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
	_position_attack_cursor_preview()


func _position_attack_cursor_preview() -> void:
	if _attack_cursor_preview == null or not _attack_cursor_preview.visible:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var desired: Vector2 = (
		get_viewport().get_mouse_position() + Vector2(18.0, 18.0)
	)
	var panel_size: Vector2 = _attack_cursor_preview.size
	_attack_cursor_preview.position = Vector2(
		clampf(
			desired.x,
			4.0,
			maxf(4.0, viewport_size.x - panel_size.x - 4.0)
		),
		clampf(
			desired.y,
			4.0,
			maxf(4.0, viewport_size.y - panel_size.y - 4.0)
		)
	)


func _hide_attack_cursor_preview() -> void:
	if _attack_cursor_preview != null:
		_attack_cursor_preview.visible = false


func _begin_attack_targeting(action_id: StringName) -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units can attack in Stage 4.0.")
		return
	if not _facade.is_stage_4_attack(action_id):
		_set_status("That attack is reserved for a later combat stage.")
		return
	var reason: String = _facade.action_unavailable_reason(
		_selected_unit_id,
		action_id
	)
	if not reason.is_empty():
		_set_status(reason)
		return

	_attack_targeting = true
	_selected_attack_id = action_id
	_selected_attack_target_id = &""
	_attack_preview = null
	_movement_mode = &"normal"
	_preview_result = null
	_context_tray.visible = false
	_active_category = &""
	_refresh_legal_attack_targets()
	_refresh_weapon_attack_strip()
	var attack: AttackDefinition = _facade.attack_definition(action_id)
	_set_status(
		"%s selected. Hover a hostile for hit chance; left-click attacks and right-click cycles damage mode."
		% (attack.display_name if attack != null else "Attack")
	)
	_refresh_all_presentation()


func _begin_active_hand_attack() -> void:
	if _active_hand_item_id.is_empty():
		_set_status("The selected hand is empty.")
		return
	var item: TacticalItemInstanceState = _facade.state().get_item(
		_active_hand_item_id
	)
	if item == null or item.definition == null:
		_set_status("The held item definition is unavailable.")
		return
	for action_id: StringName in item.definition.granted_action_ids:
		if _facade.is_stage_4_attack(action_id):
			_begin_attack_targeting(action_id)
			return
	_set_status("This held item has no Stage 4.0 melee attack.")


func _active_hand_has_stage_4_attack() -> bool:
	if _active_hand_item_id.is_empty() or _facade == null:
		return false
	var item: TacticalItemInstanceState = _facade.state().get_item(
		_active_hand_item_id
	)
	if item == null or item.definition == null:
		return false
	for action_id: StringName in item.definition.granted_action_ids:
		if _facade.is_stage_4_attack(action_id):
			return true
	return false


func _refresh_legal_attack_targets() -> void:
	_legal_attack_target_ids = _facade.legal_attack_target_ids(
		_selected_unit_id,
		_selected_attack_id,
		_power_attack_value,
		_selected_damage_channel
	)


func _refresh_attack_hover_preview() -> void:
	if not _attack_targeting:
		return
	var target: TacticalUnitState = _facade.state().get_unit_at_tile(
		_hovered_tile,
		_selected_unit_id
	)
	if target == null:
		_selected_attack_target_id = &""
		_attack_preview = null
		_hide_attack_cursor_preview()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_refresh_hud()
		_refresh_board_view()
		return
	if not _facade.are_units_hostile(
		_selected_unit_id,
		target.unit_id
	):
		# A friendly unit remains directly selectable even while a weapon is
		# active. Do not construct or display an invalid attack preview.
		_selected_attack_target_id = &""
		_attack_preview = null
		_hide_attack_cursor_preview()
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		_refresh_hud()
		_refresh_board_view()
		return
	var preview = _facade.preview_attack(
		_selected_unit_id,
		target.unit_id,
		_selected_attack_id,
		_power_attack_value,
		_selected_damage_channel
	)
	_selected_attack_target_id = target.unit_id
	_attack_preview = preview
	_refresh_attack_cursor_preview()
	_refresh_hud()
	_refresh_board_view()


func _select_attack_target_at_tile(tile: Vector2i) -> void:
	var target: TacticalUnitState = _facade.state().get_unit_at_tile(
		tile,
		_selected_unit_id
	)
	if target == null:
		_set_status("Choose a highlighted target.")
		return
	var preview = _facade.preview_attack(
		_selected_unit_id,
		target.unit_id,
		_selected_attack_id,
		_power_attack_value,
		_selected_damage_channel
	)
	if preview == null or not bool(preview.get("success")):
		_set_status(
			str(preview.get("reason"))
			if preview != null
			else "That target is unavailable."
		)
		return
	_selected_attack_target_id = target.unit_id
	_attack_preview = preview
	_configure_attack_targeting_controls()
	_set_status(_attack_preview_status())
	_refresh_all_presentation()


func _configure_attack_targeting_controls() -> void:
	_active_category = &"attack_targeting"
	_context_tray.visible = true
	var confirm_label: String = "Choose Target"
	if (
		_attack_preview != null
		and bool(_attack_preview.get("success"))
		and not _selected_attack_target_id.is_empty()
	):
		confirm_label = "Confirm %s [%d ft]" % [
			String(_attack_preview.get("attack_display_name")),
			int(_attack_preview.get("action_cost_feet")),
		]
	var damage_mode_label: String = (
		"Mode: Nonlethal"
		if _selected_damage_channel
			== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
		else "Mode: Lethal"
	)
	_configure_context_actions(
		[
			confirm_label,
			damage_mode_label,
			"Power Attack − [%d]" % _power_attack_value,
			"Power Attack + [%d]" % _power_attack_value,
			"Cancel",
		],
		[
			&"attack_confirm",
			&"damage_mode_toggle",
			&"power_attack_down",
			&"power_attack_up",
			&"attack_cancel",
		]
	)
	_refresh_context_action_availability()


func _toggle_damage_mode() -> void:
	_selected_damage_channel = (
		TacticalUnitState.DAMAGE_CHANNEL_LETHAL
		if _selected_damage_channel
			== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
		else TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
	)
	_refresh_legal_attack_targets()
	if not _selected_attack_target_id.is_empty():
		_attack_preview = _facade.preview_attack(
			_selected_unit_id,
			_selected_attack_target_id,
			_selected_attack_id,
			_power_attack_value,
			_selected_damage_channel
		)
	_refresh_weapon_attack_strip()
	_refresh_attack_cursor_preview()
	_set_status(_attack_preview_status())
	_refresh_all_presentation()


func _adjust_power_attack(delta: int = 0) -> void:
	_power_attack_value = clampi(_power_attack_value + delta, 0, 3)
	_refresh_legal_attack_targets()
	if not _selected_attack_target_id.is_empty():
		_attack_preview = _facade.preview_attack(
			_selected_unit_id,
			_selected_attack_target_id,
			_selected_attack_id,
			_power_attack_value,
			_selected_damage_channel
		)
	_refresh_weapon_attack_strip()
	_refresh_attack_cursor_preview()
	_set_status(_attack_preview_status())
	_refresh_all_presentation()


func _confirm_selected_attack() -> void:
	if (
		_attack_preview == null
		or not bool(_attack_preview.get("success"))
		or _selected_attack_target_id.is_empty()
	):
		_set_status("Choose a highlighted target before confirming the attack.")
		return
	var result: OperationResult = _facade.execute_attack_preview(_attack_preview)
	if not result.success:
		_set_status(result.message)
		_refresh_legal_attack_targets()
		_configure_attack_targeting_controls()
		_refresh_all_presentation()
		return
	_clear_attack_targeting_state()
	_context_tray.visible = false
	_active_category = &""
	_set_status(result.message)
	_refresh_all_presentation()


func _cancel_attack_targeting(message: String) -> void:
	_clear_attack_targeting_state()
	_context_tray.visible = false
	_active_category = &""
	_set_status(message)
	_refresh_all_presentation()


func _clear_attack_targeting_state() -> void:
	_attack_targeting = false
	_selected_attack_id = &""
	_selected_attack_target_id = &""
	_legal_attack_target_ids.clear()
	_attack_preview = null
	_hide_attack_cursor_preview()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _attack_preview_status() -> String:
	if not _attack_targeting:
		return _last_status_message
	if _attack_preview == null:
		return (
			"Choose a highlighted hostile target · %s · Power Attack %d"
			% [
				"Nonlethal"
				if _selected_damage_channel
					== TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL
				else "Lethal",
				_power_attack_value,
			]
		)
	if not bool(_attack_preview.get("success")):
		return str(_attack_preview.get("reason"))
	var damage_channel: StringName = StringName(
		_attack_preview.get("damage_channel")
	)
	var channel_label: String = "Lethal"
	if damage_channel == TacticalUnitState.DAMAGE_CHANNEL_NONLETHAL:
		if bool(_attack_preview.get("nonlethal_penalty_ignored")):
			channel_label = "Nonlethal · no penalty"
		else:
			channel_label = "Nonlethal · −4"
	return (
		"%s vs %s · %+d vs AC %d · %d%% hit · %s %s · PA %d · %d/%d ft after"
		% [
			String(_attack_preview.get("attack_display_name")),
			String(_attack_preview.get("target_display_name")),
			int(_attack_preview.get("attack_bonus")),
			int(_attack_preview.get("target_armour_class")),
			int(_attack_preview.get("hit_chance_percent")),
			String(_attack_preview.get("damage_notation")),
			channel_label,
			int(_attack_preview.get("power_attack_value")),
			int(_attack_preview.get("capacity_after")),
			int(_attack_preview.get("capacity_before")),
		]
	)


func _configure_ability_actions() -> void:
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	var can_rage: bool = (
		unit != null
		and unit.resolved_character.archetype_name == "Reaver"
		and _facade.has_character_modifier(&"effect.rage")
	)
	var rage_label := "Rage [Quick]"
	if can_rage and unit.active_character_modifier_ids.has(&"effect.rage"):
		rage_label = "End Rage [Quick]"

	_configure_context_actions(
		[
			"Ready Stance [Quick]",
			rage_label if can_rage else "Class Ability",
			"Archetype Ability",
			"Spellbook",
		],
		[
			&"ready_stance",
			&"rage_toggle" if can_rage else &"class_ability",
			&"archetype_ability",
			&"spellbook",
		]
	)


func _toggle_rage() -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units can activate abilities.")
		return
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return
	var activating := not unit.active_character_modifier_ids.has(&"effect.rage")
	var result: OperationResult = _facade.spend_action(
		unit.unit_id,
		"Rage" if activating else "End Rage",
		&"rage_toggle"
	)
	if not result.success:
		_set_status(result.message)
		return
	if not _facade.set_character_modifier_active(
		unit.unit_id,
		&"effect.rage",
		activating
	):
		_set_status("Rage could not be resolved for this character.")
		return
	_set_status(
		"%s. Character statistics were recalculated from their sources."
		% ("Rage activated" if activating else "Rage ended")
	)
	_hide_context_tray()
	_refresh_all_presentation()


func _hide_context_tray() -> void:
	if _attack_targeting:
		_clear_attack_targeting_state()
	_active_category = &""
	_active_hand_name = ""
	_active_hand_item = ""
	_active_hand_item_id = &""
	_context_tray.visible = false

func _open_hand_actions(hand_name: String, use_main_hand: bool) -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Held-item commands are unavailable for inspected non-player units.")
		return

	if _inventory_open:
		_close_inventory()

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return

	var hand_kind := (
		TacticalInventoryState.KIND_PRIMARY_HAND
		if use_main_hand
		else TacticalInventoryState.KIND_SECONDARY_HAND
	)
	var hand_item: TacticalItemInstanceState = _facade.state().get_hand_item(unit.unit_id, hand_kind)
	var item_name := hand_item.display_name if hand_item != null else "Empty"
	if item_name.is_empty():
		item_name = "Empty"

	_active_hand_name = hand_name
	_active_hand_item = item_name
	_active_hand_item_id = hand_item.item_id if hand_item != null else &""
	_active_category = &"hand"
	_context_tray.visible = true

	if item_name.to_lower() == "empty":
		_configure_context_actions(
			[
				"Open Inventory",
				"",
				"",
				"",
			],
			[
				&"hand_open_inventory",
				&"",
				&"",
				&"",
			]
		)
		_set_status("%s is empty. Open Inventory to place an item there." % hand_name)
	else:
		var ranged_item := (
			hand_item != null
			and hand_item.definition != null
			and hand_item.definition.has_tag(&"ranged")
		)

		_configure_context_actions(
			[
				"Ranged Attack [Half]" if ranged_item else "Attack [Half]",
				"Overwatch" if ranged_item else "Full Attack [Full]",
				"Drop",
				"Inspect",
			],
			[
				&"hand_attack",
				&"hand_overwatch" if ranged_item else &"hand_full_attack",
				&"hand_drop",
				&"hand_inspect",
			]
		)
		_set_status("%s selected: %s." % [hand_name, item_name])

	_refresh_context_action_availability()
	_refresh_hud()


func _inspect_active_hand_item() -> void:
	if _active_hand_item_id.is_empty():
		_set_status("%s is empty." % _active_hand_name)
		return

	var item: TacticalItemInstanceState = _facade.state().get_item(_active_hand_item_id)
	if item == null or item.definition == null:
		_set_status("The held item's definition is unavailable.")
		return

	var tags: Array[String] = []
	for tag: StringName in item.definition.equipment_tags:
		tags.append(String(tag).replace("_", " "))
	var tag_text := (
		", ".join(PackedStringArray(tags))
		if not tags.is_empty()
		else "uncategorised"
	)
	_set_status(
		"%s: %s · %.1f lb · %s · %s."
		% [
			_active_hand_name,
			item.display_name,
			item.weight_lb,
			item.definition.description,
			tag_text,
		]
	)

func _toggle_inventory() -> void:
	if _inventory_open:
		_close_inventory()
	else:
		_open_inventory()


func _open_inventory() -> void:
	if _selected_unit_id == &"":
		_set_status("Select a unit before opening Unit Management.")
		return

	_inventory_open = true
	_board_view.set_input_enabled(false)
	if (
		_combat_log != null
		and _combat_log.has_method("collapse")
	):
		_combat_log.call("collapse")
	_hide_context_tray()
	_movement_mode = &"normal"
	_preview_result = null
	_unit_management_window.open_for_unit(
		_selected_unit_id,
		&"equipment"
	)
	_set_status(
		"Unit Management opened. Equipment and Character Sheet tabs are free to inspect."
	)
	_refresh_board_view()


func _close_inventory() -> void:
	if _unit_management_window != null:
		_unit_management_window.close_window()
	else:
		_inventory_open = false


func _refresh_inventory_panel() -> void:
	if _unit_management_window != null:
		_unit_management_window.refresh()


func _on_unit_management_closed() -> void:
	_inventory_open = false
	_board_view.set_input_enabled(true)
	_set_status("Unit Management closed.")
	_refresh_all_presentation()


func _on_unit_management_unit_changed(unit_id: StringName) -> void:
	if unit_id == _selected_unit_id:
		return
	_select_unit_for_management(unit_id)


func _select_unit_for_management(unit_id: StringName) -> void:
	var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
	if unit == null:
		return

	_selected_unit_id = unit_id
	_movement_mode = &"normal"
	_hide_context_tray()
	_update_unit_selection_visuals()
	_refresh_path_preview()
	_set_status("%s selected for inspection." % unit.display_name)


func _update_unit_selection_visuals() -> void:
	for key: Variant in _unit_views.keys():
		var view := _unit_views[key] as TacticalUnitView
		if view != null:
			view.set_selected(StringName(key) == _selected_unit_id)


func _update_unit_finished_visuals() -> void:
	for unit: TacticalUnitState in _facade.state().get_units():
		var view := _unit_views.get(unit.unit_id) as TacticalUnitView
		if view != null:
			view.snap_to_tile(unit.grid_position)
			view.set_visibly_finished(
				unit.action_budget.is_visibly_finished() or unit.is_defeated()
			)


func _refresh_path_preview() -> void:
	if _attack_targeting:
		var hovered_unit: TacticalUnitState = _facade.state().get_unit_at_tile(
			_hovered_tile,
			_selected_unit_id
		)
		if hovered_unit != null:
			_preview_result = null
			_refresh_attack_hover_preview()
			return
		_selected_attack_target_id = &""
		_attack_preview = null
		_hide_attack_cursor_preview()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_preview_result = null

	if not _facade.state().phase_state.is_player_phase():
		_refresh_hud()
		_refresh_board_view()
		return
	if _selected_unit_id == &"" or not _map_definition.is_inside(_hovered_tile):
		_refresh_hud()
		_refresh_board_view()
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if (
		unit == null
		or not unit.is_player_controlled()
		or unit.action_budget.ended_activation
	):
		_refresh_hud()
		_refresh_board_view()
		return

	var occupying_unit: TacticalUnitState = _facade.state().get_unit_at_tile(
		_hovered_tile,
		_selected_unit_id
	)
	if occupying_unit != null:
		_preview_result = MovementPathResult.failed(
			"%s occupies that tile." % occupying_unit.display_name
		)
		_refresh_hud()
		_refresh_board_view()
		return

	_preview_result = _facade.preview_movement(
		unit.unit_id,
		_hovered_tile,
		_movement_mode
	)
	_refresh_hud()
	_refresh_board_view()


func _refresh_all_presentation() -> void:
	_update_unit_selection_visuals()
	_update_unit_finished_visuals()
	_refresh_hud()
	if _inventory_open:
		_refresh_inventory_panel()
	_refresh_board_view()


func _selected_unit_is_player_controlled() -> bool:
	if _facade == null or _selected_unit_id.is_empty():
		return false
	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	return unit != null and unit.is_player_controlled()


func _refresh_hud() -> void:
	var phase_state: TacticalPhaseState = _facade.state().phase_state
	var phase_name := "PLAYER PHASE" if phase_state.is_player_phase() else "ENEMY TURN"

	_phase_label.text = "ROUND %d · %s" % [phase_state.round_number, phase_name]
	_round_short_label.text = "Round %d\n%s" % [phase_state.round_number, phase_name]
	_objective_label.text = "OBJECTIVE · Fight the enemy Settlement Guard"
	_hint_label.text = (
		"Hover hostile · Left-click attack · Right-click target cycles mode · Esc cancels weapon"
		if _attack_targeting
		else "1–9 Select · A Primary Weapon · I Inventory · L Log · Esc Cancel"
	)

	_refresh_unit_buttons()
	_end_phase_button.disabled = not phase_state.is_player_phase() or _world_phase_in_progress

	if _selected_unit_id == &"":
		_short_name_label.text = "No unit"
		_unit_health_bar.visible = false
		_unit_health_bar.call("set_values", 0, 1, 0)
		_short_hp_label.text = "AC -"
		_short_capacity_label.text = "Capacity - · Q - · R -"
		_unit_capacity_bar.max_value = 1.0
		_unit_capacity_bar.value = 0.0
		_unit_capacity_value_label.text = "— / — ft"
		_unit_capacity_value_label.tooltip_text = "No unit selected."
		_short_context_label.text = "Select a unit."
		_short_context_label.tooltip_text = "Select a unit."
		_disable_command_buttons("Select a unit first.")
		_refresh_weapon_attack_strip()
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		_disable_command_buttons("The selected unit does not exist.")
		return



	_short_name_label.text = unit.display_name
	_unit_health_bar.visible = true
	_unit_health_bar.call(
		"set_values",
		unit.current_hp,
		unit.maximum_hp,
		unit.nonlethal_damage
	)
	_short_hp_label.text = "AC %d" % unit.armour_class
	_short_capacity_label.text = (
		"DEFEATED — cannot act"
		if unit.is_defeated()
		else "%d/%d ft · %s · %s · %s" % [
		unit.action_budget.remaining_turn_capacity_feet,
		unit.action_budget.maximum_turn_capacity_feet,
		"A ready"
			if unit.action_budget.ordinary_attack_available
			else "A spent",
		"Q ready" if unit.action_budget.quick_action_available else "Q spent",
		"R ready" if unit.action_budget.reaction_available else "R spent",
		]
	)
	_unit_capacity_bar.max_value = unit.action_budget.maximum_turn_capacity_feet
	_unit_capacity_bar.value = unit.action_budget.remaining_turn_capacity_feet
	_unit_capacity_value_label.text = "%d / %d ft" % [
		unit.action_budget.remaining_turn_capacity_feet,
		unit.action_budget.maximum_turn_capacity_feet,
	]
	_unit_capacity_value_label.tooltip_text = (
		"Turn capacity: %d / %d ft\nHalf Action threshold: %d ft"
		% [
			unit.action_budget.remaining_turn_capacity_feet,
			unit.action_budget.maximum_turn_capacity_feet,
			_facade.half_action_cost_feet(unit.unit_id),
		]
	)

	_left_hand_button.disabled = false
	_right_hand_button.disabled = false

	for command_button: Button in [
		_abilities_button,
		_tactics_button,
		_inventory_button,
		_interact_button,
		_end_unit_button,
	]:
		command_button.tooltip_text = ""

	var secondary_hand_name: String = _facade.state().hand_display_name(unit.unit_id, TacticalInventoryState.KIND_SECONDARY_HAND)
	if secondary_hand_name.is_empty():
		secondary_hand_name = "Empty"

	var primary_hand_name: String = _facade.state().hand_display_name(unit.unit_id, TacticalInventoryState.KIND_PRIMARY_HAND)
	if primary_hand_name.is_empty():
		primary_hand_name = "Empty"

	_left_hand_button.text = "SECONDARY\n%s" % secondary_hand_name
	_right_hand_button.text = "PRIMARY\n%s" % primary_hand_name
	_left_hand_button.tooltip_text = (
		"Secondary Hand: %s\nClick to select this weapon for direct targeting."
		% secondary_hand_name
	)
	_right_hand_button.tooltip_text = (
		"Primary Hand: %s\nClick to select this weapon for direct targeting."
		% primary_hand_name
	)

	var nearby_count: int = _facade.state().get_accessible_ground_items(unit).size()
	_inventory_button.text = (
		"Inventory (%d)" % nearby_count
		if nearby_count > 0
		else "Inventory"
	)

	var quick_text := (
		"Q ready"
		if unit.action_budget.quick_action_available
		else "Q spent"
	)
	var reaction_text := (
		"R ready"
		if unit.action_budget.reaction_available
		else "R spent"
	)
	var path_context := _last_status_message
	if unit.is_defeated():
		path_context = "Defeated at 0 HP — this unit cannot move or attack."

	if _attack_targeting and not _selected_attack_target_id.is_empty():
		path_context = _attack_preview_status()
	elif _map_definition.is_inside(_hovered_tile):
		if _preview_result == null or not _preview_result.success:
			path_context = (
				_preview_result.failure_reason
				if _preview_result != null
				else "Unavailable"
			)
		elif _movement_mode == &"sprint":
			path_context = (
				"SPRINT: %d ft · Full Action · Reaction lost"
				% _preview_result.cost_feet
			)
		else:
			var remaining_after := (
				unit.action_budget.remaining_turn_capacity_feet
				- _preview_result.cost_feet
			)
			var half_cost: int = _facade.half_action_cost_feet(unit.unit_id)
			var action_note := (
				"Half Action remains"
				if remaining_after >= half_cost
				else "No Half Action remains"
			)
			path_context = (
				"Path: %d ft · %d ft after · %s"
				% [_preview_result.cost_feet, remaining_after, action_note]
			)

	_short_context_label.text = "%s · %s · %s" % [
		quick_text,
		reaction_text,
		path_context,
	]
	_short_context_label.tooltip_text = _short_context_label.text

	var player_controlled: bool = (
		unit.is_player_controlled() and not unit.is_defeated()
	)
	_left_hand_button.disabled = not player_controlled
	_right_hand_button.disabled = not player_controlled
	_attack_button.disabled = true
	_abilities_button.disabled = not phase_state.is_player_phase() or not player_controlled
	_tactics_button.disabled = not phase_state.is_player_phase() or not player_controlled
	_inventory_button.disabled = false
	_interact_button.disabled = not phase_state.is_player_phase() or not player_controlled
	_end_unit_button.disabled = not phase_state.is_player_phase() or not player_controlled
	_end_unit_button.text = (
		"Reactivate"
		if unit.action_budget.ended_activation
		else "End Unit"
	)

	_refresh_context_action_availability()
	_refresh_weapon_attack_strip()


func _refresh_unit_buttons() -> void:
	var player_phase: bool = _facade.state().phase_state.is_player_phase()
	for index: int in range(_player_unit_order.size()):
		var unit_id: StringName = _player_unit_order[index]
		var unit: TacticalUnitState = _facade.state().get_unit(unit_id)
		if unit == null:
			continue
		var button: Button = _unit_buttons.get(unit.unit_id) as Button
		if button == null:
			continue
		button.call(
			"refresh_unit",
			unit,
			index + 1,
			player_phase,
			unit.unit_id == _selected_unit_id
		)


func _disable_command_buttons(reason: String) -> void:
	for button: Button in [
		_attack_button,
		_abilities_button,
		_tactics_button,
		_interact_button,
		_end_unit_button,
	]:
		button.disabled = true
		button.tooltip_text = reason

	_inventory_button.disabled = _selected_unit_id == &""
	_inventory_button.tooltip_text = reason
	_left_hand_button.disabled = true
	_right_hand_button.disabled = true
	_attack_mode_button.disabled = true
	_power_attack_down_button.disabled = true
	_power_attack_value_button.disabled = true
	_power_attack_up_button.disabled = true


func _on_end_unit_pressed() -> void:
	if not _selected_unit_is_player_controlled():
		_set_status("Only player-controlled units have Player Phase activations.")
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_selected_unit_id)
	if unit == null:
		return

	var result: OperationResult
	if unit.action_budget.ended_activation:
		result = _facade.reactivate_unit(_selected_unit_id)
	else:
		result = _facade.end_unit(_selected_unit_id)

	_set_status(result.message)
	_movement_mode = &"normal"
	_preview_result = null
	_refresh_hud()
	_refresh_board_view()


func _on_end_phase_pressed() -> void:
	if _world_phase_in_progress:
		return

	var begin_result: OperationResult = _facade.begin_world_phase()
	if not begin_result.success:
		_set_status(begin_result.message)
		return

	_close_inventory_silently()
	_clear_attack_targeting_state()
	_selected_weapon_hand_kind = &""
	_selected_weapon_item_id = &""
	_world_phase_in_progress = true
	_movement_mode = &"normal"
	_preview_result = null
	_set_status("Enemy Turn: AI-controlled enemy units are activating.")
	_refresh_all_presentation()
	await get_tree().create_timer(0.20).timeout

	var enemy_result: OperationResult = _facade.resolve_enemy_turn()
	_set_status(enemy_result.message)
	_refresh_all_presentation()
	await get_tree().create_timer(0.35).timeout

	var complete_result: OperationResult = _facade.complete_world_phase()
	_world_phase_in_progress = false
	_set_status(complete_result.message)
	_select_default_weapon_for_unit()
	_refresh_all_presentation()


func _close_inventory_silently() -> void:
	_inventory_open = false
	_board_view.set_input_enabled(true)
	if _unit_management_window != null:
		_unit_management_window.hide_silently()


func _refresh_board_view() -> void:
	if _board_view == null:
		return
	_board_view.update_presentation(
		_selected_unit_id,
		_hovered_tile,
		_preview_result,
		_movement_mode,
		_attack_targeting,
		_legal_attack_target_ids,
		_selected_attack_target_id
	)


func _on_state_changed(_reason: StringName) -> void:
	if _attack_targeting:
		var selected_item: TacticalItemInstanceState = _facade.state().get_item(
			_selected_weapon_item_id
		)
		if (
			selected_item == null
			or _stage_4_attack_id_for_item(selected_item).is_empty()
		):
			_select_default_weapon_for_unit()
	_refresh_all_presentation()


func _set_status(message: String) -> void:
	_last_status_message = message
	if _short_context_label != null:
		_short_context_label.text = message
		_short_context_label.tooltip_text = message
