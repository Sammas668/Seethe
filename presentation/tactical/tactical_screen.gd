extends Node2D

const MOVEMENT_TEST_MAP: TacticalMapDefinition = preload(
    "res://content/missions/farm_storehouse/movement_test_map.tres"
)
const UNIT_VIEW_SCENE: PackedScene = preload(
    "res://presentation/tactical/tactical_unit_view.tscn"
)

const MARAUDER_ID: StringName = &"unit.prototype_marauder"
const ARCHER_ID: StringName = &"unit.prototype_archer"
const SCOUT_ID: StringName = &"unit.prototype_scout"

const BOARD_ORIGIN := Vector2(446.0, 48.0)
const TILE_SIZE := 28.0

const FLOOR_COLOR := Color(0.18, 0.21, 0.24, 1.0)
const ALTERNATE_FLOOR_COLOR := Color(0.205, 0.235, 0.265, 1.0)
const GRID_COLOR := Color(0.055, 0.07, 0.085, 0.88)
const BLOCKED_COLOR := Color(0.035, 0.045, 0.055, 1.0)
const DIFFICULT_COLOR := Color(0.40, 0.285, 0.16, 1.0)
const VALID_PATH_COLOR := Color(0.20, 0.76, 0.40, 0.40)
const AMBER_PATH_COLOR := Color(0.95, 0.63, 0.18, 0.42)
const SPRINT_PATH_COLOR := Color(0.78, 0.22, 0.20, 0.40)
const INVALID_PATH_COLOR := Color(0.80, 0.12, 0.13, 0.45)
const HOVER_COLOR := Color(0.94, 0.82, 0.26, 0.30)
const ITEM_COLOR := Color(0.94, 0.70, 0.20, 1.0)

const UNIT_COLORS := {
	MARAUDER_ID: Color(0.14, 0.46, 0.90, 1.0),
	ARCHER_ID: Color(0.14, 0.68, 0.38, 1.0),
	SCOUT_ID: Color(0.64, 0.30, 0.82, 1.0),
}

@onready var _unit_layer: Node2D = $UnitLayer

@onready var _objective_label: Label = $HUD/TopBar/Margin/Row/ObjectiveLabel
@onready var _phase_label: Label = $HUD/TopBar/Margin/Row/PhaseLabel
@onready var _hint_label: Label = $HUD/TopBar/Margin/Row/HintLabel

@onready var _marauder_button: Button = $HUD/RosterPanel/Margin/VBox/MarauderButton
@onready var _archer_button: Button = $HUD/RosterPanel/Margin/VBox/ArcherButton
@onready var _scout_button: Button = $HUD/RosterPanel/Margin/VBox/ScoutButton

@onready var _selected_label: Label = $HUD/RightPanel/Margin/VBox/SelectedLabel
@onready var _hp_label: Label = $HUD/RightPanel/Margin/VBox/HPLabel
@onready var _ac_label: Label = $HUD/RightPanel/Margin/VBox/ACLabel
@onready var _capacity_label: Label = $HUD/RightPanel/Margin/VBox/CapacityLabel
@onready var _capacity_bar: ProgressBar = $HUD/RightPanel/Margin/VBox/CapacityBarContainer/CapacityBar
@onready var _quick_label: Label = $HUD/RightPanel/Margin/VBox/AllowanceRow/QuickLabel
@onready var _reaction_label: Label = $HUD/RightPanel/Margin/VBox/AllowanceRow/ReactionLabel
@onready var _position_label: Label = $HUD/RightPanel/Margin/VBox/PositionLabel
@onready var _path_label: Label = $HUD/RightPanel/Margin/VBox/PathLabel
@onready var _terrain_label: Label = $HUD/RightPanel/Margin/VBox/TerrainLabel
@onready var _context_title: Label = $HUD/RightPanel/Margin/VBox/ContextTitle
@onready var _context_body: Label = $HUD/RightPanel/Margin/VBox/ContextBody
@onready var _status_label: Label = $HUD/RightPanel/Margin/VBox/StatusLabel

@onready var _short_name_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortNameLabel
@onready var _short_hp_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortHPLabel
@onready var _short_capacity_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortCapacityLabel
@onready var _unit_capacity_bar: ProgressBar = $HUD/BottomDeck/Margin/MainRow/UnitBlock/UnitCapacityBarContainer/UnitCapacityBar
@onready var _short_context_label: Label = $HUD/BottomDeck/Margin/MainRow/UnitBlock/ShortContextLabel
@onready var _left_hand_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/HandRow/LeftHandButton
@onready var _right_hand_button: Button = $HUD/BottomDeck/Margin/MainRow/HandBlock/HandRow/RightHandButton

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
]

@onready var _end_phase_button: Button = $HUD/BottomDeck/Margin/MainRow/PhaseBlock/EndPhaseButton
@onready var _round_short_label: Label = $HUD/BottomDeck/Margin/MainRow/PhaseBlock/RoundShortLabel

@onready var _inventory_panel: PanelContainer = $HUD/InventoryPanel
@onready var _inventory_title: Label = $HUD/InventoryPanel/Margin/VBox/Header/InventoryTitle
@onready var _inventory_close_button: Button = $HUD/InventoryPanel/Margin/VBox/Header/CloseButton
@onready var _inventory_equipped_text: RichTextLabel = $HUD/InventoryPanel/Margin/VBox/Body/UnitInventoryPanel/Margin/VBox/EquippedText
@onready var _inventory_quick_text: RichTextLabel = $HUD/InventoryPanel/Margin/VBox/Body/UnitInventoryPanel/Margin/VBox/QuickText
@onready var _inventory_packed_text: RichTextLabel = $HUD/InventoryPanel/Margin/VBox/Body/UnitInventoryPanel/Margin/VBox/PackedText
@onready var _inventory_weight_label: Label = $HUD/InventoryPanel/Margin/VBox/Body/UnitInventoryPanel/Margin/VBox/WeightLabel
@onready var _local_access_text: RichTextLabel = $HUD/InventoryPanel/Margin/VBox/Body/LocalAccessPanel/Margin/VBox/LocalAccessText
@onready var _inventory_action_label: Label = $HUD/InventoryPanel/Margin/VBox/InventoryActionLabel
@onready var _inventory_confirm_button: Button = $HUD/InventoryPanel/Margin/VBox/Footer/ConfirmButton
@onready var _inventory_footer_close_button: Button = $HUD/InventoryPanel/Margin/VBox/Footer/FooterCloseButton

var _state_store: TacticalStateStore
var _command_handler: TacticalCommandHandler
var _spend_action_handler: SpendActionHandler
var _sprint_handler: SprintMoveHandler
var _end_phase_handler: EndPhaseHandler

var _unit_views: Dictionary = {}
var _unit_buttons: Dictionary = {}
var _selected_unit_id: StringName = &""
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _preview_result: MovementPathResult
var _world_phase_in_progress: bool = false
var _inventory_open: bool = false
var _active_category: StringName = &""
var _context_action_ids: Array[StringName] = [&"", &"", &"", &""]
var _movement_mode: StringName = &"normal"
var _last_status_message: String = "Ready."
var _active_hand_name: String = ""
var _active_hand_item: String = ""


func _ready() -> void:
	var initial_state := TacticalState.new()

	var marauder := TacticalUnitState.new(
		MARAUDER_ID,
		"Test Marauder",
		MOVEMENT_TEST_MAP.get_player_starting_tile(0, Vector2i(2, 2)),
		30,
		&"player",
		24,
		14
	)
	marauder.configure_inventory(
		TacticalInventoryState.new(
			"Training Axe",
			"Empty",
			"Hide Armour",
			"Shortbow + Quiver",
			["Bandage", "Rope"],
			["Manacles", "Rations"],
			42.0,
			80.0
		)
	)
	initial_state.add_unit(marauder)

	var archer := TacticalUnitState.new(
		ARCHER_ID,
		"Test Archer",
		MOVEMENT_TEST_MAP.get_player_starting_tile(1, Vector2i(2, 4)),
		30,
		&"player",
		18,
		13
	)
	archer.configure_inventory(
		TacticalInventoryState.new(
			"Training Shortbow",
			"Dagger",
			"Leather Armour",
			"Dagger + Buckler",
			["Bandage", "Smoke Pellet"],
			["Spare Arrows", "Chalk"],
			31.0,
			60.0
		)
	)
	initial_state.add_unit(archer)

	var scout := TacticalUnitState.new(
		SCOUT_ID,
		"Test Scout",
		MOVEMENT_TEST_MAP.get_player_starting_tile(2, Vector2i(4, 2)),
		40,
		&"player",
		20,
		14
	)
	scout.configure_inventory(
		TacticalInventoryState.new(
			"Training Spear",
			"Knife",
			"Light Armour",
			"Sling",
			["Lockpicks", "Bandage"],
			["Coil of Rope", "Empty Sack"],
			28.0,
			55.0
		)
	)
	initial_state.add_unit(scout)

	initial_state.add_ground_item(
		TacticalItemState.new(
			&"item.training_dropped_spear",
			"Dropped Spear",
			Vector2i(3, 2),
			1,
			6.0,
            "Ground"
		)
	)
	initial_state.add_ground_item(
		TacticalItemState.new(
			&"item.training_grain_crate",
			"Grain Crate",
			Vector2i(2, 3),
			1,
			25.0,
            "Ground"
		)
	)
	initial_state.add_ground_item(
		TacticalItemState.new(
			&"item.training_bandages",
			"Bandage Bundle",
			Vector2i(3, 4),
			2,
			1.0,
            "Ground"
		)
	)

	_state_store = TacticalStateStore.new(initial_state)
	_command_handler = TacticalCommandHandler.new(_state_store, MOVEMENT_TEST_MAP)
	_spend_action_handler = SpendActionHandler.new(_state_store)
	_sprint_handler = SprintMoveHandler.new(_state_store, MOVEMENT_TEST_MAP)
	_end_phase_handler = EndPhaseHandler.new(_state_store)

	_unit_buttons = {
		MARAUDER_ID: _marauder_button,
		ARCHER_ID: _archer_button,
		SCOUT_ID: _scout_button,
	}

	_state_store.state_changed.connect(_on_state_changed)

	_marauder_button.pressed.connect(func() -> void: _select_unit(MARAUDER_ID))
	_archer_button.pressed.connect(func() -> void: _select_unit(ARCHER_ID))
	_scout_button.pressed.connect(func() -> void: _select_unit(SCOUT_ID))

	_attack_button.pressed.connect(func() -> void: _toggle_action_category(&"attack"))
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
		func() -> void: _open_hand_actions("Left Hand", false)
	)
	_right_hand_button.pressed.connect(
		func() -> void: _open_hand_actions("Right Hand", true)
	)

	_inventory_close_button.pressed.connect(_close_inventory)
	_inventory_footer_close_button.pressed.connect(_close_inventory)
	_inventory_confirm_button.pressed.connect(_on_inventory_confirm_pressed)

	_create_unit_views()
	_select_unit(MARAUDER_ID)
	_set_status(
        "Xenonauts-inspired HUD foundation active. Normal movement remains map-driven; Inventory is always available."
	)
	_refresh_all_presentation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		match key_event.keycode:
			KEY_I:
				_toggle_inventory()
			KEY_ESCAPE:
				if _inventory_open:
					_close_inventory()
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
			KEY_1:
				_select_unit(MARAUDER_ID)
			KEY_2:
				_select_unit(ARCHER_ID)
			KEY_3:
				_select_unit(SCOUT_ID)
		return

	if _inventory_open:
		return

	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		var tile := _screen_to_tile(mouse_event.position)
		if tile != _hovered_tile:
			_hovered_tile = tile
			_refresh_path_preview()
			queue_redraw()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed:
			return

		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(_screen_to_tile(mouse_button.position))
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			if _movement_mode != &"normal":
				_movement_mode = &"normal"
				_set_status("Special movement mode cancelled.")
			else:
				_selected_unit_id = &""
				_set_status("Unit deselected. Select a unit on the board or roster.")
			_preview_result = null
			_update_unit_selection_visuals()
			_refresh_all_presentation()


func _draw() -> void:
	_draw_board()
	_draw_ground_items()
	_draw_path_preview()
	_draw_selection_outline()


func _draw_board() -> void:
	for y: int in range(MOVEMENT_TEST_MAP.grid_size.y):
		for x: int in range(MOVEMENT_TEST_MAP.grid_size.x):
			var tile := Vector2i(x, y)
			var rectangle := _tile_rect(tile)
			var fill_color := FLOOR_COLOR if (x + y) % 2 == 0 else ALTERNATE_FLOOR_COLOR

			if MOVEMENT_TEST_MAP.is_blocked(tile):
				fill_color = BLOCKED_COLOR
			elif MOVEMENT_TEST_MAP.is_difficult(tile):
				fill_color = DIFFICULT_COLOR

			draw_rect(rectangle, fill_color, true)
			draw_rect(rectangle, GRID_COLOR, false, 1.0)

	var board_size := Vector2(MOVEMENT_TEST_MAP.grid_size) * TILE_SIZE
	draw_rect(
		Rect2(BOARD_ORIGIN, board_size),
		Color(0.55, 0.61, 0.66, 1.0),
		false,
		2.0
	)


func _draw_ground_items() -> void:
	for item: TacticalItemState in _state_store.state.get_ground_items():
		var centre := _tile_to_world(item.grid_position)
		var points := PackedVector2Array([
			centre + Vector2(0.0, -6.0),
			centre + Vector2(6.0, 0.0),
			centre + Vector2(0.0, 6.0),
			centre + Vector2(-6.0, 0.0),
		])
		draw_colored_polygon(points, ITEM_COLOR)
		draw_polyline(
			PackedVector2Array([
				points[0], points[1], points[2], points[3], points[0]
			]),
			Color(0.20, 0.12, 0.03, 1.0),
			1.5
		)


func _draw_path_preview() -> void:
	if _selected_unit_id == &"" or _hovered_tile.x < 0:
		return
	if not _state_store.state.phase_state.is_player_phase():
		return

	if _preview_result == null or not _preview_result.success:
		if MOVEMENT_TEST_MAP.is_inside(_hovered_tile):
			draw_rect(_tile_rect(_hovered_tile), INVALID_PATH_COLOR, true)
		return

	var unit := _state_store.state.get_unit(_selected_unit_id)
	if unit == null:
		return

	var path_color := VALID_PATH_COLOR
	if _movement_mode == &"sprint":
		path_color = SPRINT_PATH_COLOR
	elif _preview_result.cost_feet > unit.action_budget.remaining_turn_capacity_feet:
		path_color = INVALID_PATH_COLOR
	else:
		var half_cost := ActionCost.half_action().resolved_normal_capacity_feet(
			unit.action_budget.maximum_turn_capacity_feet
		)
		var remaining_after := (
			unit.action_budget.remaining_turn_capacity_feet
			- _preview_result.cost_feet
		)
		if remaining_after < half_cost:
			path_color = AMBER_PATH_COLOR

	for index: int in range(1, _preview_result.path.size()):
		draw_rect(_tile_rect(_preview_result.path[index]), path_color, true)

	if MOVEMENT_TEST_MAP.is_inside(_hovered_tile):
		draw_rect(_tile_rect(_hovered_tile), HOVER_COLOR, true)


func _draw_selection_outline() -> void:
	if _selected_unit_id == &"":
		return

	var unit := _state_store.state.get_unit(_selected_unit_id)
	if unit == null:
		return

	draw_rect(
		_tile_rect(unit.grid_position).grow(-2.0),
		Color(1.0, 0.82, 0.22, 1.0),
		false,
		3.0
	)


func _create_unit_views() -> void:
	for unit: TacticalUnitState in _state_store.state.get_units():
		var view := UNIT_VIEW_SCENE.instantiate() as TacticalUnitView
		_unit_layer.add_child(view)
		var display_color: Color = UNIT_COLORS.get(unit.unit_id, Color.WHITE)
		view.configure(unit, BOARD_ORIGIN, TILE_SIZE, display_color)
		_unit_views[unit.unit_id] = view


func _handle_left_click(tile: Vector2i) -> void:
	if not MOVEMENT_TEST_MAP.is_inside(tile):
		return
	if not _state_store.state.phase_state.is_player_phase():
		_set_status("Wait for the World Phase to finish.")
		return

	var clicked_unit := _state_store.state.get_unit_at_tile(tile)
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
		queue_redraw()
		return

	var selected_unit := _state_store.state.get_unit(_selected_unit_id)
	if selected_unit == null:
		return
	if selected_unit.action_budget.ended_activation:
		_set_status("This unit is marked as ended. Select it again to reactivate it.")
		return

	var result: OperationResult
	if _movement_mode == &"sprint":
		result = _sprint_handler.execute(
			SprintMoveCommand.new(_selected_unit_id, tile)
		)
	else:
		result = _command_handler.execute_move(
			MoveCommand.new(_selected_unit_id, tile)
		)

	if not result.success:
		_set_status(result.message)
		queue_redraw()
		return

	var completed_path := result.data as MovementPathResult
	var unit_view := _unit_views.get(_selected_unit_id) as TacticalUnitView
	if unit_view != null and completed_path != null:
		unit_view.animate_path(completed_path.path)

	_movement_mode = &"normal"
	_preview_result = null
	_set_status(result.message)
	_refresh_all_presentation()


func _select_unit(unit_id: StringName) -> void:
	if not _state_store.state.phase_state.is_player_phase():
		return

	var unit := _state_store.state.get_unit(unit_id)
	if unit == null:
		return

	if unit.action_budget.ended_activation:
		var result := _command_handler.reactivate_unit(unit_id)
		_set_status(result.message)
	else:
		_set_status("%s selected." % unit.display_name)

	_selected_unit_id = unit_id
	_movement_mode = &"normal"
	_hide_context_tray()
	_update_unit_selection_visuals()
	_refresh_path_preview()
	_refresh_all_presentation()


func _execute_budget_action(action_name: String, action_cost: ActionCost) -> void:
	if _selected_unit_id == &"":
		_set_status("Select a unit before using an action.")
		return

	var result := _spend_action_handler.execute(
		SpendActionCommand.new(_selected_unit_id, action_name, action_cost)
	)
	_set_status(result.message)
	_preview_result = null
	_refresh_path_preview()
	_refresh_all_presentation()


func _toggle_action_category(category: StringName) -> void:
	if _inventory_open:
		_close_inventory()

	if _active_category == category and _context_tray.visible:
		_hide_context_tray()
		return

	_active_category = category
	_context_tray.visible = true

	match category:
		&"attack":
			_configure_context_actions(
				[
					"Melee Attack [Half]",
					"Ranged Attack [Half]",
					"Full Attack [Full]",
					"",
				],
				[&"attack_melee", &"attack_ranged", &"full_attack", &""]
			)
			_context_title.text = "ATTACK"
			_context_body.text = (
                "The command deck is ready for the practice-dummy combat stage. "
				+ "Attack buttons are visible now but remain disabled until targeting and damage are implemented."
			)
		&"abilities":
			_configure_context_actions(
				[
					"Ready Stance [Quick]",
					"Class Ability",
					"Archetype Ability",
					"Spellbook",
				],
				[&"ready_stance", &"class_ability", &"archetype_ability", &"spellbook"]
			)
			_context_title.text = "ABILITIES"
			_context_body.text = (
                "Quick, class, archetype and spell actions share this contextual tray. "
				+ "Only Ready Stance currently spends a real Quick Action."
			)
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
			_context_title.text = "TACTICS & MOVEMENT MODES"
			_context_body.text = (
                "Normal movement stays map-driven. Sprint changes the path preview and is functional. "
				+ "Other tactical modes remain visible without permanently cluttering the HUD."
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
			_context_title.text = "INTERACT"
			_context_body.text = (
                "World-object and objective actions will appear here only when the selected unit has a valid context."
			)

	_set_status("%s options opened." % String(category).capitalize())
	_refresh_context_action_availability()
	_refresh_all_presentation()


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
	var unit := _state_store.state.get_unit(_selected_unit_id)

	for index: int in range(_context_action_buttons.size()):
		var button := _context_action_buttons[index]
		var action_id := _context_action_ids[index]
		button.disabled = false
		button.tooltip_text = ""

		if not button.visible:
			continue
		if unit == null:
			button.disabled = true
			button.tooltip_text = "Select a unit first."
			continue
		if not _state_store.state.phase_state.is_player_phase():
			button.disabled = true
			button.tooltip_text = "Unavailable during the World Phase."
			continue

		match action_id:
			&"ready_stance":
				var quick_reason := ActionEconomyRules.unavailable_reason(
					unit,
					ActionCost.quick_action()
				)
				button.disabled = not quick_reason.is_empty()
				button.tooltip_text = quick_reason
			&"sprint":
				var full_reason := ActionEconomyRules.unavailable_reason(
					unit,
					ActionCost.full_action()
				)
				button.disabled = not full_reason.is_empty()
				button.tooltip_text = full_reason
			&"disengage":
				var half_reason := ActionEconomyRules.unavailable_reason(
					unit,
					ActionCost.half_action()
				)
				button.disabled = true
				button.tooltip_text = (
					half_reason
					if not half_reason.is_empty()
					else "Visible UI option; opportunity-attack protection is implemented with Reactions later."
				)
			&"hand_inspect", &"hand_open_inventory":
				button.disabled = false
			&"hand_attack", &"hand_full_attack", &"hand_overwatch":
				button.disabled = true
				button.tooltip_text = (
                    "This held-item action becomes functional in the practice-dummy combat stage."
				)
			&"hand_drop":
				button.disabled = true
				button.tooltip_text = (
                    "Dropping held items becomes functional with tactical item-transfer commands."
				)
			_:
				button.disabled = true
				button.tooltip_text = "Visible UI placeholder for a later implementation stage."


func _on_context_action_pressed(index: int) -> void:
	if index < 0 or index >= _context_action_ids.size():
		return

	var action_id := _context_action_ids[index]
	match action_id:
		&"ready_stance":
			_execute_budget_action("Ready Stance", ActionCost.quick_action())
		&"sprint":
			_movement_mode = &"sprint"
			_hide_context_tray()
			_set_status(
                "Sprint selected. Choose a legal destination up to 150% Speed. "
				+ "Difficult terrain is unavailable in this prototype."
			)
			_refresh_path_preview()
		&"hand_inspect":
			_inspect_active_hand_item()
		&"hand_open_inventory":
			_open_inventory()
		_:
			_set_status("That action is displayed for UI planning but is not implemented yet.")


func _hide_context_tray() -> void:
	_active_category = &""
	_active_hand_name = ""
	_active_hand_item = ""
	_context_tray.visible = false


func _open_hand_actions(hand_name: String, use_main_hand: bool) -> void:
	if _selected_unit_id == &"":
		_set_status("Select a unit before choosing a held item.")
		return

	if _inventory_open:
		_close_inventory()

	var unit := _state_store.state.get_unit(_selected_unit_id)
	if unit == null:
		return

	var item_name := (
		unit.inventory.main_hand
		if use_main_hand
		else unit.inventory.off_hand
	)
	if item_name.is_empty():
		item_name = "Empty"

	_active_hand_name = hand_name
	_active_hand_item = item_name
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
		var lower_name := item_name.to_lower()
		var ranged_item := (
			"bow" in lower_name
			or "sling" in lower_name
			or "crossbow" in lower_name
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
	_refresh_all_presentation()


func _inspect_active_hand_item() -> void:
	if _active_hand_item.is_empty() or _active_hand_item.to_lower() == "empty":
		_set_status("%s is empty." % _active_hand_name)
		return

	_set_status(
        "%s holds %s. Detailed item statistics will come from ItemDefinition later."
		% [_active_hand_name, _active_hand_item]
	)

func _toggle_inventory() -> void:
	if _inventory_open:
		_close_inventory()
	else:
		_open_inventory()


func _open_inventory() -> void:
	if _selected_unit_id == &"":
		_set_status("Select a unit before opening Inventory.")
		return

	_inventory_open = true
	_inventory_panel.visible = true
	_hide_context_tray()
	_movement_mode = &"normal"
	_preview_result = null
	_refresh_inventory_panel()
	_set_status(
        "Inventory opened for free. Item movement remains read-only in this UI foundation."
	)
	queue_redraw()


func _close_inventory() -> void:
	_inventory_open = false
	_inventory_panel.visible = false
	_set_status("Inventory closed.")
	_refresh_all_presentation()


func _refresh_inventory_panel() -> void:
	var unit := _state_store.state.get_unit(_selected_unit_id)
	if unit == null:
		return

	_inventory_title.text = "%s — TACTICAL INVENTORY" % unit.display_name
	_inventory_equipped_text.text = (
        "[b]Main hand[/b]\n%s\n\n[b]Off hand[/b]\n%s\n\n[b]Armour[/b]\n%s\n\n[b]Prepared secondary set[/b]\n%s"
		% [
			unit.inventory.main_hand,
			unit.inventory.off_hand,
			unit.inventory.armour,
			unit.inventory.secondary_set,
		]
	)
	_inventory_quick_text.text = (
		"[b]Quick access[/b]\n%s" % unit.inventory.quick_access_summary()
	)
	_inventory_packed_text.text = (
		"[b]Packed inventory[/b]\n%s" % unit.inventory.packed_summary()
	)
	_inventory_weight_label.text = (
        "Carried weight: %.1f / %.1f lb"
		% [
			unit.inventory.current_weight_lb,
			unit.inventory.maximum_weight_lb,
		]
	)

	var accessible := _state_store.state.get_accessible_ground_items(unit)
	if accessible.is_empty():
		_local_access_text.text = (
            "[b]Locally accessible[/b]\n\nNo known items on the selected unit's tile or adjacent tiles."
		)
	else:
		var lines: Array[String] = ["[b]Locally accessible[/b]", ""]
		for item: TacticalItemState in accessible:
			lines.append(
                "• %s\n  %s tile (%d, %d)"
				% [
					item.display_line(),
					item.source_label,
					item.grid_position.x,
					item.grid_position.y,
				]
			)
		_local_access_text.text = "\n".join(PackedStringArray(lines))

	_inventory_action_label.text = (
        "Opening and inspection are free. Pickup, transfer, quick-access and packed-storage costs "
		+ "are displayed here when tactical item commands are implemented."
	)
	_inventory_confirm_button.disabled = true
	_inventory_confirm_button.tooltip_text = (
        "Item-transfer commands are deliberately deferred; this stage establishes the permanent UI contract."
	)


func _on_inventory_confirm_pressed() -> void:
	_set_status("No item transfer is selected. Tactical item commands are a later stage.")


func _update_unit_selection_visuals() -> void:
	for key: Variant in _unit_views.keys():
		var view := _unit_views[key] as TacticalUnitView
		if view != null:
			view.set_selected(StringName(key) == _selected_unit_id)


func _update_unit_finished_visuals() -> void:
	for unit: TacticalUnitState in _state_store.state.get_units():
		var view := _unit_views.get(unit.unit_id) as TacticalUnitView
		if view != null:
			view.set_visibly_finished(unit.action_budget.is_visibly_finished())


func _refresh_path_preview() -> void:
	_preview_result = null

	if not _state_store.state.phase_state.is_player_phase():
		_refresh_hud()
		return
	if _selected_unit_id == &"" or not MOVEMENT_TEST_MAP.is_inside(_hovered_tile):
		_refresh_hud()
		return

	var unit := _state_store.state.get_unit(_selected_unit_id)
	if unit == null or unit.action_budget.ended_activation:
		_refresh_hud()
		return

	var occupying_unit := _state_store.state.get_unit_at_tile(
		_hovered_tile,
		_selected_unit_id
	)
	if occupying_unit != null:
		_preview_result = MovementPathResult.failed(
			"%s occupies that tile." % occupying_unit.display_name
		)
		_refresh_hud()
		return

	if _movement_mode == &"sprint":
		_preview_result = _sprint_handler.preview(unit, _hovered_tile)
	else:
		_preview_result = MovementRules.find_path(
			unit.grid_position,
			_hovered_tile,
			MOVEMENT_TEST_MAP,
			unit.diagonal_steps_used
		)
	_refresh_hud()


func _refresh_all_presentation() -> void:
	_update_unit_selection_visuals()
	_update_unit_finished_visuals()
	_refresh_hud()
	if _inventory_open:
		_refresh_inventory_panel()
	queue_redraw()


func _refresh_hud() -> void:
	var phase_state := _state_store.state.phase_state
	var phase_name := "PLAYER PHASE" if phase_state.is_player_phase() else "WORLD PHASE"

	_phase_label.text = "ROUND %d · %s" % [phase_state.round_number, phase_name]
	_round_short_label.text = "Round %d\n%s" % [phase_state.round_number, phase_name]
	_objective_label.text = "OBJECTIVE · Tactical UI and local-inventory sandbox"
	_hint_label.text = "1–3 Select · I Inventory · Esc Cancel"

	_refresh_unit_buttons()
	_end_phase_button.disabled = not phase_state.is_player_phase() or _world_phase_in_progress

	if _selected_unit_id == &"":
		_selected_label.text = "NO UNIT SELECTED"
		_hp_label.text = "HP: -"
		_ac_label.text = "Armour Class: -"
		_capacity_label.text = "Turn capacity: -"
		_capacity_bar.max_value = 1.0
		_capacity_bar.value = 0.0
		_quick_label.text = "Q: -"
		_reaction_label.text = "R: -"
		_position_label.text = "Position: -"
		_path_label.text = "Path preview: -"
		_terrain_label.text = "Terrain: -"
		_short_name_label.text = "No unit"
		_short_hp_label.text = "HP - · AC -"
		_short_capacity_label.text = "Capacity - · Q - · R -"
		_unit_capacity_bar.max_value = 1.0
		_unit_capacity_bar.value = 0.0
		_short_context_label.text = "Select a unit."
		_short_context_label.tooltip_text = "Select a unit."
		_disable_command_buttons("Select a unit first.")
		return

	var unit := _state_store.state.get_unit(_selected_unit_id)
	if unit == null:
		_disable_command_buttons("The selected unit does not exist.")
		return

	_selected_label.text = unit.display_name.to_upper()
	_hp_label.text = "HP: %d / %d" % [unit.current_hp, unit.maximum_hp]
	_ac_label.text = "Armour Class: %d" % unit.armour_class
	_capacity_label.text = (
        "Turn capacity: %d / %d ft"
		% [
			unit.action_budget.remaining_turn_capacity_feet,
			unit.action_budget.maximum_turn_capacity_feet,
		]
	)
	_capacity_bar.max_value = unit.action_budget.maximum_turn_capacity_feet
	_capacity_bar.value = unit.action_budget.remaining_turn_capacity_feet
	_quick_label.text = (
        "Q: Available"
		if unit.action_budget.quick_action_available
		else "Q: Spent"
	)
	_reaction_label.text = (
        "R: Available"
		if unit.action_budget.reaction_available
		else "R: Spent"
	)
	_position_label.text = "Position: (%d, %d)" % [unit.grid_position.x, unit.grid_position.y]

	_short_name_label.text = unit.display_name
	_short_hp_label.text = "HP %d/%d · AC %d" % [
		unit.current_hp,
		unit.maximum_hp,
		unit.armour_class,
	]
	_short_capacity_label.text = "%d/%d ft · %s · %s" % [
		unit.action_budget.remaining_turn_capacity_feet,
		unit.action_budget.maximum_turn_capacity_feet,
		"Q ready" if unit.action_budget.quick_action_available else "Q spent",
		"R ready" if unit.action_budget.reaction_available else "R spent",
	]
	_unit_capacity_bar.max_value = unit.action_budget.maximum_turn_capacity_feet
	_unit_capacity_bar.value = unit.action_budget.remaining_turn_capacity_feet

	_left_hand_button.disabled = false
	_right_hand_button.disabled = false

	for command_button: Button in [
		_attack_button,
		_abilities_button,
		_tactics_button,
		_inventory_button,
		_interact_button,
		_end_unit_button,
	]:
		command_button.tooltip_text = ""

	var left_hand_name := unit.inventory.off_hand
	if left_hand_name.is_empty():
		left_hand_name = "Empty"

	var right_hand_name := unit.inventory.main_hand
	if right_hand_name.is_empty():
		right_hand_name = "Empty"

	_left_hand_button.text = "LEFT HAND\n%s" % left_hand_name
	_right_hand_button.text = "RIGHT HAND\n%s" % right_hand_name
	_left_hand_button.tooltip_text = (
        "Left hand: %s\nClick to show actions supplied by this held item."
		% left_hand_name
	)
	_right_hand_button.tooltip_text = (
        "Right hand: %s\nClick to show actions supplied by this held item."
		% right_hand_name
	)

	var nearby_count := _state_store.state.get_accessible_ground_items(unit).size()
	_inventory_button.text = (
		"Inventory (%d)" % nearby_count
		if nearby_count > 0
		else "Inventory"
	)

	if not MOVEMENT_TEST_MAP.is_inside(_hovered_tile):
		_path_label.text = "Path preview: move the cursor over the map"
		_terrain_label.text = "Terrain: -"
	else:
		if MOVEMENT_TEST_MAP.is_blocked(_hovered_tile):
			_terrain_label.text = "Terrain: blocked"
		elif MOVEMENT_TEST_MAP.is_difficult(_hovered_tile):
			_terrain_label.text = "Terrain: difficult · double cost"
		else:
			_terrain_label.text = "Terrain: normal"

		if _preview_result == null or not _preview_result.success:
			var reason := (
				_preview_result.failure_reason
				if _preview_result != null
				else "Unavailable"
			)
			_path_label.text = "Path preview: %s" % reason
		else:
			if _movement_mode == &"sprint":
				_path_label.text = (
                    "SPRINT: %d ft · Full Action · Reaction lost"
					% _preview_result.cost_feet
				)
			else:
				var remaining_after := (
					unit.action_budget.remaining_turn_capacity_feet
					- _preview_result.cost_feet
				)
				var half_cost := ActionCost.half_action().resolved_normal_capacity_feet(
					unit.action_budget.maximum_turn_capacity_feet
				)
				var action_note := (
                    "Half Action remains"
					if remaining_after >= half_cost
					else "No Half Action remains"
				)
				_path_label.text = (
                    "Path: %d ft · %d ft after · %s"
					% [_preview_result.cost_feet, remaining_after, action_note]
				)

	if not MOVEMENT_TEST_MAP.is_inside(_hovered_tile):
		_short_context_label.text = "Tile (%d, %d) · %s" % [
			unit.grid_position.x,
			unit.grid_position.y,
			_last_status_message,
		]
	else:
		_short_context_label.text = "%s · %s" % [
			_path_label.text,
			_terrain_label.text,
		]
	_short_context_label.tooltip_text = _short_context_label.text

	_attack_button.disabled = not phase_state.is_player_phase()
	_abilities_button.disabled = not phase_state.is_player_phase()
	_tactics_button.disabled = not phase_state.is_player_phase()
	_inventory_button.disabled = false
	_interact_button.disabled = not phase_state.is_player_phase()
	_end_unit_button.disabled = not phase_state.is_player_phase()
	_end_unit_button.text = (
        "Reactivate"
		if unit.action_budget.ended_activation
		else "End Unit"
	)

	_refresh_context_action_availability()


func _refresh_unit_buttons() -> void:
	var player_phase := _state_store.state.phase_state.is_player_phase()
	for unit: TacticalUnitState in _state_store.state.get_player_units():
		var button := _unit_buttons.get(unit.unit_id) as Button
		if button == null:
			continue

		var state_text := ""
		if unit.action_budget.ended_activation:
			state_text = "\nENDED"
		elif not unit.action_budget.has_any_option_remaining():
			state_text = "\nSPENT"

		button.text = "%s\nHP %d/%d\n%d/%d ft%s" % [
			unit.display_name,
			unit.current_hp,
			unit.maximum_hp,
			unit.action_budget.remaining_turn_capacity_feet,
			unit.action_budget.maximum_turn_capacity_feet,
			state_text,
		]
		button.disabled = not player_phase


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


func _on_end_unit_pressed() -> void:
	if _selected_unit_id == &"":
		return

	var unit := _state_store.state.get_unit(_selected_unit_id)
	if unit == null:
		return

	var result: OperationResult
	if unit.action_budget.ended_activation:
		result = _command_handler.reactivate_unit(_selected_unit_id)
	else:
		result = _command_handler.mark_unit_ended(_selected_unit_id)

	_set_status(result.message)
	_movement_mode = &"normal"
	_preview_result = null
	_refresh_all_presentation()


func _on_end_phase_pressed() -> void:
	if _world_phase_in_progress:
		return

	var begin_result := _end_phase_handler.begin_world_phase(EndPhaseCommand.new())
	if not begin_result.success:
		_set_status(begin_result.message)
		return

	_close_inventory_silently()
	_world_phase_in_progress = true
	_movement_mode = &"normal"
	_preview_result = null
	_set_status("World Phase: placeholder world activity is resolving.")
	_refresh_all_presentation()
	await get_tree().create_timer(0.45).timeout

	var complete_result := _end_phase_handler.complete_world_phase()
	_world_phase_in_progress = false
	_set_status(complete_result.message)
	_refresh_all_presentation()


func _close_inventory_silently() -> void:
	_inventory_open = false
	_inventory_panel.visible = false


func _on_state_changed(_reason: StringName) -> void:
	_refresh_all_presentation()


func _set_status(message: String) -> void:
	_last_status_message = message
	_status_label.text = message
	if _short_context_label != null:
		_short_context_label.text = message
		_short_context_label.tooltip_text = message


func _screen_to_tile(screen_position: Vector2) -> Vector2i:
	var local_position := screen_position - BOARD_ORIGIN
	return Vector2i(
		int(floor(local_position.x / TILE_SIZE)),
		int(floor(local_position.y / TILE_SIZE))
	)


func _tile_to_world(tile: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(tile) * TILE_SIZE + Vector2.ONE * (TILE_SIZE * 0.5)


func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(
		BOARD_ORIGIN + Vector2(tile) * TILE_SIZE,
		Vector2.ONE * TILE_SIZE
	)
