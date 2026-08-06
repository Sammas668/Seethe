class_name UnitManagementWindow
extends Control

signal closed
signal unit_changed(unit_id: StringName)
signal message_requested(message: String)

const TAB_INVENTORY: StringName = &"equipment"
const TAB_CHARACTER: StringName = &"character"

const KIND_PRIMARY_HAND: StringName = &"main_hand"
const KIND_SECONDARY_HAND: StringName = &"off_hand"
const KIND_BELT: StringName = &"belt"
const KIND_BACKPACK: StringName = &"backpack"
const KIND_GROUND: StringName = &"ground"
const KIND_RAIDER_SACK: StringName = TacticalInventoryState.KIND_RAIDER_SACK

const BODY_MENU_LOOT: int = 0
const BODY_MENU_FIRST_AID: int = 1
const BODY_MENU_FINISH_OFF: int = 2
const BODY_MENU_UNTIE: int = 3

const RAIDER_SACK_POPUP_SIZE: Vector2i = Vector2i(340, 310)
const RAIDER_SACK_CELL_SIZE: Vector2 = Vector2(70.0, 56.0)

@onready var _previous_button: Button = $Modal/Margin/VBox/Header/PreviousUnitButton
@onready var _unit_title: Label = $Modal/Margin/VBox/Header/UnitTitle
@onready var _inventory_tab_button: Button = $Modal/Margin/VBox/Header/TabGroup/InventoryTabButton
@onready var _character_tab_button: Button = $Modal/Margin/VBox/Header/TabGroup/CharacterTabButton
@onready var _next_button: Button = $Modal/Margin/VBox/Header/NextUnitButton
@onready var _close_button: Button = $Modal/Margin/VBox/Header/CloseButton

@onready var _inventory_tab: VBoxContainer = $Modal/Margin/VBox/Content/InventoryTab
@onready var _character_tab: HBoxContainer = $Modal/Margin/VBox/Content/CharacterTab

@onready var _primary_hand_container: HBoxContainer = $Modal/Margin/VBox/Content/InventoryTab/Upper/LoadoutPanel/Margin/VBox/PrimaryHandContainer
@onready var _secondary_hand_container: HBoxContainer = $Modal/Margin/VBox/Content/InventoryTab/Upper/LoadoutPanel/Margin/VBox/SecondaryHandContainer
@onready var _belt_grid: SpatialInventoryGrid = $Modal/Margin/VBox/Content/InventoryTab/Upper/LoadoutPanel/Margin/VBox/BeltGrid
@onready var _stats_text: RichTextLabel = $Modal/Margin/VBox/Content/InventoryTab/Upper/StatsPanel/Margin/StatsText
@onready var _inventory_portrait_stack: Control = $Modal/Margin/VBox/Content/InventoryTab/Upper/PortraitPanel/PortraitMargin/PortraitStack
@onready var _inventory_silhouette: Control = $Modal/Margin/VBox/Content/InventoryTab/Upper/PortraitPanel/PortraitMargin/PortraitStack/Silhouette
@onready var _portrait_caption: Label = $Modal/Margin/VBox/Content/InventoryTab/Upper/PortraitPanel/PortraitMargin/PortraitStack/PortraitCaption
@onready var _backpack_grid: SpatialInventoryGrid = $Modal/Margin/VBox/Content/InventoryTab/Lower/BackpackPanel/Margin/VBox/BackpackGrid
@onready var _reach_grid: SpatialInventoryGrid = $Modal/Margin/VBox/Content/InventoryTab/Lower/ReachPanel/Margin/VBox/ReachGrid

@onready var _character_portrait_host: ColorRect = $Modal/Margin/VBox/Content/CharacterTab/IdentityPanel/Margin/VBox/Portrait
@onready var _identity_text: RichTextLabel = $Modal/Margin/VBox/Content/CharacterTab/IdentityPanel/Margin/VBox/IdentityText
@onready var _ability_grid: GridContainer = $Modal/Margin/VBox/Content/CharacterTab/AttributePanel/Margin/VBox/AbilityGrid
@onready var _combat_summary: RichTextLabel = $Modal/Margin/VBox/Content/CharacterTab/AttributePanel/Margin/VBox/CombatSummary
@onready var _details_text: RichTextLabel = $Modal/Margin/VBox/Content/CharacterTab/DetailsPanel/Margin/DetailsText

@onready var _item_details: RichTextLabel = $Modal/Margin/VBox/Content/InventoryTab/Upper/LoadoutPanel/Margin/VBox/CompactItemDetails
@onready var _action_preview: Label = $Modal/Margin/VBox/Content/InventoryTab/Upper/LoadoutPanel/Margin/VBox/CompactActionPreview

var _facade
var _portrait_resolver: PortraitAssetResolver
var _current_unit_id: StringName = &""
var _unit_order: Array[StringName] = []
var _current_tab: StringName = TAB_INVENTORY

var _primary_hand_slot: UnitManagementSlot
var _secondary_hand_slot: UnitManagementSlot
var _selected_source_kind: StringName = &""
var _selected_source_item_id: StringName = &""
var _expanded_breakdowns: Dictionary = {}
var _inventory_portrait_texture: TextureRect
var _character_portrait_texture: TextureRect
var _body_context_menu: PopupMenu
var _body_context_item_id: StringName = &""
var _loot_popup: PopupPanel
var _loot_list: ItemList
var _loot_body_item_id: StringName = &""
var _loot_take_button: Button
var _loot_search_button: Button
var _raider_sack_popup: PanelContainer
var _raider_sack_grid: SpatialInventoryGrid
var _raider_sack_close_button: Button


func _ready() -> void:
	set_process_unhandled_key_input(false)
	_initialize_portrait_views()
	_initialize_body_interaction_ui()
	_initialize_raider_sack_ui()

	_previous_button.pressed.connect(func() -> void: _change_unit(-1))
	_next_button.pressed.connect(func() -> void: _change_unit(1))
	_close_button.pressed.connect(close_window)

	_inventory_tab_button.pressed.connect(
		func() -> void: show_tab(TAB_INVENTORY)
	)
	_character_tab_button.pressed.connect(
		func() -> void: show_tab(TAB_CHARACTER)
	)

	_identity_text.meta_clicked.connect(_on_sheet_meta_clicked)
	_combat_summary.meta_clicked.connect(_on_sheet_meta_clicked)
	_details_text.meta_clicked.connect(_on_sheet_meta_clicked)

	_belt_grid.configure(
		KIND_BELT,
		TacticalInventoryState.BELT_WIDTH,
		TacticalInventoryState.BELT_HEIGHT,
		Vector2(48.0, 44.0)
	)
	_backpack_grid.configure(
		KIND_BACKPACK,
		TacticalInventoryState.BACKPACK_WIDTH,
		TacticalInventoryState.BACKPACK_HEIGHT,
		Vector2(50.0, 44.0)
	)
	_reach_grid.configure(
		KIND_GROUND,
		9,
		4,
		Vector2(50.0, 44.0)
	)

	for grid: SpatialInventoryGrid in [
		_belt_grid,
		_backpack_grid,
		_reach_grid,
		_raider_sack_grid,
	]:
		grid.item_activated.connect(_on_grid_item_activated)
		grid.transfer_requested.connect(_on_transfer_requested)
		grid.empty_cell_activated.connect(_on_empty_cell_activated)
		grid.item_dropped_onto.connect(_on_item_dropped_onto)



func _initialize_raider_sack_ui() -> void:
	_raider_sack_popup = PanelContainer.new()
	_raider_sack_popup.name = "RaiderSackPopup"
	_raider_sack_popup.visible = false
	_raider_sack_popup.custom_minimum_size = Vector2(RAIDER_SACK_POPUP_SIZE)
	_raider_sack_popup.size = Vector2(RAIDER_SACK_POPUP_SIZE)
	_raider_sack_popup.z_index = 200
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.018, 0.025, 0.031, 0.998)
	popup_style.border_color = Color(0.69, 0.50, 0.18, 1.0)
	popup_style.border_width_left = 2
	popup_style.border_width_top = 2
	popup_style.border_width_right = 2
	popup_style.border_width_bottom = 2
	popup_style.corner_radius_top_left = 4
	popup_style.corner_radius_top_right = 4
	popup_style.corner_radius_bottom_left = 4
	popup_style.corner_radius_bottom_right = 4
	_raider_sack_popup.add_theme_stylebox_override("panel", popup_style)
	add_child(_raider_sack_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_raider_sack_popup.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 34.0)
	box.add_child(header)

	var title := Label.new()
	title.text = "RAIDER'S SACK"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.92, 0.81, 0.55, 1.0))
	title.add_theme_font_size_override("font_size", 17)
	header.add_child(title)

	_raider_sack_close_button = Button.new()
	_raider_sack_close_button.name = "CloseButton"
	_raider_sack_close_button.text = "X"
	_raider_sack_close_button.tooltip_text = "Close Raider's Sack"
	_raider_sack_close_button.custom_minimum_size = Vector2(34.0, 30.0)
	_raider_sack_close_button.add_theme_color_override("font_color", Color.WHITE)
	_raider_sack_close_button.add_theme_font_size_override("font_size", 15)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.63, 0.08, 0.08, 1.0)
	close_style.border_color = Color(0.96, 0.36, 0.31, 1.0)
	close_style.border_width_left = 1
	close_style.border_width_top = 1
	close_style.border_width_right = 1
	close_style.border_width_bottom = 1
	close_style.corner_radius_top_left = 3
	close_style.corner_radius_top_right = 3
	close_style.corner_radius_bottom_left = 3
	close_style.corner_radius_bottom_right = 3
	var close_hover := close_style.duplicate() as StyleBoxFlat
	close_hover.bg_color = Color(0.82, 0.11, 0.09, 1.0)
	_raider_sack_close_button.add_theme_stylebox_override("normal", close_style)
	_raider_sack_close_button.add_theme_stylebox_override("hover", close_hover)
	_raider_sack_close_button.add_theme_stylebox_override("pressed", close_hover)
	_raider_sack_close_button.pressed.connect(_close_raider_sack_popup)
	header.add_child(_raider_sack_close_button)

	var instruction := Label.new()
	instruction.text = "One restrained Medium-or-smaller captive or compatible burden. Medium bodies occupy the full 4×3 grid."
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_color_override("font_color", Color(0.68, 0.74, 0.77, 1.0))
	instruction.add_theme_font_size_override("font_size", 11)
	box.add_child(instruction)

	_raider_sack_grid = SpatialInventoryGrid.new()
	_raider_sack_grid.name = "RaiderSackGrid"
	_raider_sack_grid.configure(
		KIND_RAIDER_SACK,
		TacticalInventoryState.RAIDER_SACK_WIDTH,
		TacticalInventoryState.RAIDER_SACK_HEIGHT,
		RAIDER_SACK_CELL_SIZE
	)
	box.add_child(_raider_sack_grid)


func _initialize_body_interaction_ui() -> void:
	_body_context_menu = PopupMenu.new()
	add_child(_body_context_menu)
	_body_context_menu.add_item("Loot Equipment", BODY_MENU_LOOT)
	_body_context_menu.add_item("Administer First Aid", BODY_MENU_FIRST_AID)
	_body_context_menu.add_item("Finish Off", BODY_MENU_FINISH_OFF)
	_body_context_menu.add_item("Untie", BODY_MENU_UNTIE)
	_body_context_menu.id_pressed.connect(_on_body_context_action)

	_loot_popup = PopupPanel.new()
	_loot_popup.name = "BodyLootPopup"
	_loot_popup.size = Vector2i(520, 420)
	add_child(_loot_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_loot_popup.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "LOOT EQUIPMENT"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	_loot_list = ItemList.new()
	_loot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_loot_list)
	var actions := HBoxContainer.new()
	vbox.add_child(actions)
	_loot_take_button = Button.new()
	_loot_take_button.text = "Take Selected"
	_loot_take_button.pressed.connect(_take_selected_body_item)
	actions.add_child(_loot_take_button)
	_loot_search_button = Button.new()
	_loot_search_button.text = "Search — drop all to floor"
	_loot_search_button.pressed.connect(_search_open_body)
	actions.add_child(_loot_search_button)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_loot_popup.hide)
	actions.add_child(close_button)


func _initialize_portrait_views() -> void:
	_inventory_portrait_texture = _create_portrait_texture_rect(
		_inventory_portrait_stack
	)
	_inventory_portrait_stack.move_child(_inventory_portrait_texture, 0)

	_character_portrait_texture = _create_portrait_texture_rect(
		_character_portrait_host
	)


func _create_portrait_texture_rect(parent: Control) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.name = "ResolvedPortraitTexture"
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(texture_rect)
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return texture_rect


func _refresh_portraits(unit: TacticalUnitState) -> void:
	var snapshot: ResolvedCharacterSnapshot = unit.resolved_character
	var portrait_id: StringName = (
		snapshot.portrait_id if snapshot != null else &""
	)
	var portrait_texture: Texture2D = (
		_portrait_resolver.resolve(portrait_id)
		if _portrait_resolver != null
		else null
	)

	_inventory_portrait_texture.texture = portrait_texture
	_character_portrait_texture.texture = portrait_texture

	var has_portrait: bool = portrait_texture != null
	_inventory_silhouette.visible = not has_portrait
	_portrait_caption.text = (
		unit.display_name.to_upper()
		if has_portrait
		else "CHARACTER ART PLACEHOLDER"
	)


func configure(
		facade,
		portrait_resolver: PortraitAssetResolver,
		initial_unit_id: StringName,
		unit_order_value: Array[StringName]
) -> void:
	_facade = facade
	_portrait_resolver = portrait_resolver
	_current_unit_id = initial_unit_id
	_unit_order.clear()
	for unit_id: StringName in unit_order_value:
		_unit_order.append(unit_id)


func open_for_unit(
		unit_id: StringName,
		tab_id: StringName = TAB_INVENTORY
) -> void:
	if _facade == null:
		return

	_current_unit_id = unit_id
	visible = true
	set_process_unhandled_key_input(true)
	show_tab(tab_id)
	_clear_selection()
	refresh()


func close_window() -> void:
	_close_raider_sack_popup()
	visible = false
	set_process_unhandled_key_input(false)
	_clear_selection()
	closed.emit()


func hide_silently() -> void:
	_close_raider_sack_popup()
	visible = false
	set_process_unhandled_key_input(false)
	_clear_selection()


func set_current_unit(unit_id: StringName) -> void:
	_close_raider_sack_popup()
	_current_unit_id = unit_id
	_clear_selection()
	refresh()


func refresh() -> void:
	if not visible or _facade == null:
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_current_unit_id)
	if unit == null:
		return

	_unit_title.text = unit.display_name.to_upper()
	_refresh_portraits(unit)

	if _current_tab == TAB_INVENTORY:
		_render_inventory_tab(unit)
	else:
		_render_character_tab(unit)


func show_tab(tab_id: StringName) -> void:
	_current_tab = TAB_CHARACTER if tab_id == TAB_CHARACTER else TAB_INVENTORY
	if _current_tab != TAB_INVENTORY:
		_close_raider_sack_popup()
	_inventory_tab.visible = _current_tab == TAB_INVENTORY
	_character_tab.visible = _current_tab == TAB_CHARACTER
	_inventory_tab_button.button_pressed = _current_tab == TAB_INVENTORY
	_character_tab_button.button_pressed = _current_tab == TAB_CHARACTER
	_clear_selection()
	refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_ESCAPE, KEY_I:
			close_window()
		KEY_E:
			show_tab(TAB_INVENTORY)
		KEY_C:
			show_tab(TAB_CHARACTER)
		KEY_LEFT:
			_change_unit(-1)
		KEY_RIGHT:
			_change_unit(1)
		KEY_1:
			_select_unit_by_index(0)
		KEY_2:
			_select_unit_by_index(1)
		KEY_3:
			_select_unit_by_index(2)


func _render_inventory_tab(unit: TacticalUnitState) -> void:
	_clear_children(_primary_hand_container)
	_clear_children(_secondary_hand_container)

	var state: TacticalState = _facade.state()
	var primary_item := state.get_hand_item(unit.unit_id, KIND_PRIMARY_HAND)
	var secondary_item := state.get_hand_item(unit.unit_id, KIND_SECONDARY_HAND)

	_primary_hand_slot = _create_hand_slot(
		_primary_hand_container,
		KIND_PRIMARY_HAND,
		"PRIMARY HAND",
		primary_item,
		true,
		""
	)

	var secondary_accepts_items := true
	var secondary_reserved_text := ""
	if primary_item != null and primary_item.two_handed:
		secondary_accepts_items = false
		secondary_reserved_text = (
			"RESERVED BY %s" % primary_item.display_name.to_upper()
		)

	_secondary_hand_slot = _create_hand_slot(
		_secondary_hand_container,
		KIND_SECONDARY_HAND,
		"SECONDARY HAND",
		secondary_item,
		secondary_accepts_items,
		secondary_reserved_text
	)

	_belt_grid.render_inventory_items(
		state.get_unit_container_items(unit.unit_id, KIND_BELT),
		state
	)
	_backpack_grid.render_inventory_items(
		state.get_unit_container_items(unit.unit_id, KIND_BACKPACK),
		state
	)
	var raider_sack: TacticalItemInstanceState = state.raider_sack_item_for_unit(unit.unit_id)
	if raider_sack == null and _raider_sack_popup.visible:
		_close_raider_sack_popup()
	if _raider_sack_popup.visible:
		_raider_sack_grid.render_inventory_items(
			state.get_unit_container_items(unit.unit_id, KIND_RAIDER_SACK),
			state
		)
	_reach_grid.render_ground_items(
		state.get_accessible_ground_items(unit),
		state
	)

	_refresh_inventory_stats(unit)
	_refresh_selection_visuals()
	_refresh_footer()


func _create_hand_slot(
		parent: Control,
		hand_kind: StringName,
		label_text: String,
		item: TacticalItemInstanceState,
		accepts_items: bool,
		reserved_text: String
) -> UnitManagementSlot:
	var slot := UnitManagementSlot.new()
	slot.custom_minimum_size = Vector2(248.0, 60.0)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slot)
	slot.configure(
		hand_kind,
		label_text,
		item,
		accepts_items,
		reserved_text,
		TacticalStatusBadgeProvider.for_body_item(_facade.state(), item)
		if item != null and item.is_body()
		else {}
	)
	slot.item_activated.connect(_on_hand_slot_activated)
	slot.transfer_requested.connect(_on_transfer_requested)
	return slot


func _refresh_inventory_stats(unit: TacticalUnitState) -> void:
	var snapshot := unit.resolved_character
	var quick_text := (
		"READY"
		if unit.action_budget.quick_action_available
		else "SPENT"
	)
	var reaction_text := (
		"READY"
		if unit.action_budget.reaction_available
		else "SPENT"
	)

	_stats_text.text = (
		"[b]%s[/b]\n"
		+ "Level %d %s\n"
		+ "%s\n\n"
		+ "HP                         %d / %d\n"
		+ "ARMOUR CLASS              %d\n"
		+ "SPEED                      %d ft\n"
		+ "PERCEPTION                 %d\n\n"
		+ "TURN CAPACITY              %d / %d ft\n"
		+ "WEIGHT                     %.1f / %.1f lb\n\n"
		+ "QUICK ACTION               %s\n"
		+ "REACTION                   %s"
	) % [
		unit.display_name.to_upper(),
		snapshot.level,
		snapshot.class_name_text,
		snapshot.archetype_name,
		unit.current_hp,
		unit.maximum_hp,
		unit.armour_class,
		unit.action_budget.maximum_turn_capacity_feet,
		snapshot.stat_value(&"passive_perception", 10),
		unit.action_budget.remaining_turn_capacity_feet,
		unit.action_budget.maximum_turn_capacity_feet,
		_facade.state().calculated_carried_weight(unit.unit_id),
		unit.inventory.maximum_weight_lb,
		quick_text,
		reaction_text,
	]


func _render_character_tab(unit: TacticalUnitState) -> void:
	var snapshot := unit.resolved_character
	var defence_profile: DefenceProfile = (
		_facade.defence_profile(snapshot.defence_profile_id)
		if _facade != null
		else null
	)
	var armour_name := (
		defence_profile.display_name
		if defence_profile != null
		else "Unconfigured"
	)

	_identity_text.text = (
		"[b]%s[/b]\n\n"
		+ "Level %d\n"
		+ "XP: %d\n"
		+ "Class: %s\n"
		+ "Archetype: %s\n"
		+ "Type: %s\n"
		+ "Role: %s\n"
		+ "Team: %s\n"
		+ "Controller: %s\n"
		+ "Turn: %s\n"
		+ "Persistence: %s\n"
		+ "Faction: %s\n"
		+ "Troop Tier: %d\n"
		+ "Classification: %s\n"
		+ "AI Profile: %s\n"
		+ "Reaction: %s\n\n"
		+ "HP: %d / %d\n"
		+ "Armour: %s\n"
		+ "%s\n"
		+ "%s\n"
		+ "Half Action: %d ft\n"
		+ "Sprint: %d ft\n"
		+ "Reach: 5 ft\n"
		+ "Footprint: %d × %d tile%s\n"
		+ "Quick Action: %s\n"
		+ "Weight: %.1f / %.1f lb\n\n"
		+ "[font_size=10]Persistent ID: %s[/font_size]"
	) % [
		unit.display_name,
		snapshot.level,
		snapshot.xp,
		snapshot.class_name_text,
		snapshot.archetype_name,
		snapshot.troop_type,
		String(snapshot.roster_role).capitalize(),
		String(unit.team_id).capitalize(),
		String(unit.controller_type).capitalize(),
		String(unit.turn_behavior).replace("_", " ").capitalize(),
		String(snapshot.persistence_scope).capitalize(),
		String(snapshot.faction_id),
		snapshot.troop_tier,
		String(snapshot.combatant_classification).capitalize(),
		String(snapshot.ai_profile_id),
		String(unit.action_budget.reaction_state).replace("_", " ").capitalize(),
		unit.current_hp,
		unit.maximum_hp,
		armour_name,
		_formatted_stat(snapshot, &"armour_class", "Armour Class", false),
		_formatted_stat(snapshot, &"turn_capacity", "Movement", false, " ft"),
		snapshot.stat_value(&"half_action_cost", 0),
		unit.sprint_distance_feet,
		unit.footprint.x,
		unit.footprint.y,
		"" if unit.footprint == Vector2i.ONE else "s",
		"Available" if unit.action_budget.quick_action_available else "Spent",
		_facade.state().calculated_carried_weight(unit.unit_id),
		unit.inventory.maximum_weight_lb,
		String(unit.persistent_character_id),
	]

	_clear_children(_ability_grid)
	for abbreviation: String in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		var label := Label.new()
		label.custom_minimum_size = Vector2(125.0, 30.0)
		label.text = snapshot.ability_line(abbreviation)
		label.tooltip_text = "\n".join(
			PackedStringArray(
				snapshot.stat_breakdown(
					StringName("ability.%s" % abbreviation.to_lower())
				)
			)
		)
		_ability_grid.add_child(label)

	_combat_summary.text = (
		"[b]COMBAT SUMMARY[/b]\n"
		+ "[font_size=10]Select a statistic to show or hide its sources.[/font_size]\n\n"
		+ "%s\n"
		+ "%s\n"
		+ "%s\n"
		+ "%s\n"
		+ "%s\n"
		+ "%s\n"
		+ "%s\n"
		+ "%s\n"
		+ "%s\n\n"
		+ "[b]SKILLS[/b]\n%s"
	) % [
		_formatted_stat(snapshot, &"base_attack_bonus", "Base Attack Bonus", true),
		_formatted_stat(snapshot, &"initiative", "Initiative", true),
		_formatted_stat(snapshot, &"passive_perception", "Passive Perception", false),
		_formatted_stat(snapshot, &"fortitude", "Fortitude", true),
		_formatted_stat(snapshot, &"reflex", "Reflex", true),
		_formatted_stat(snapshot, &"will", "Will", true),
		_formatted_stat(snapshot, &"grapple", "Grapple", true),
		_formatted_stat(snapshot, &"manoeuvre", "Manoeuvre", true),
		_formatted_stat(snapshot, &"manoeuvre_defence", "Manoeuvre Defence", false),
		_skill_summary(snapshot),
	]

	_details_text.text = (
		"[b]CURRENT EQUIPMENT[/b]\n"
		+ "Primary Hand: %s\n"
		+ "Secondary Hand: %s\n"
		+ "Armour: %s\n"
		+ "Belt: %s\n"
		+ "Backpack: %s\n\n"
		+ "[b]ATTACKS[/b]\n%s\n\n"
		+ "[b]DEFENCES & RESISTANCES[/b]\n%s\n\n"
		+ "[b]ABILITIES[/b]\n%s\n\n"
		+ "[b]PROFICIENCIES[/b]\n%s\n\n"
		+ "[b]ROLE TAGS[/b]\n%s\n\n"
		+ "[b]CARRYING[/b]\n%s\n\n"
		+ "[b]CONDITIONS[/b]\n%s\n\n"
		+ "[b]INJURIES[/b]\n%s\n\n"
		+ "[b]HISTORY[/b]\n%s"
	) % [
		_facade.state().hand_display_name(unit.unit_id, KIND_PRIMARY_HAND),
		_facade.state().hand_display_name(unit.unit_id, KIND_SECONDARY_HAND),
		_facade.state().container_summary(unit.unit_id, TacticalInventoryState.KIND_ARMOUR),
		_facade.state().container_summary(unit.unit_id, KIND_BELT),
		_facade.state().container_summary(unit.unit_id, KIND_BACKPACK),
		_attack_summary_for_unit(unit),
		_defence_summary_for_unit(snapshot, defence_profile),
		_ability_summary_for_unit(unit),
		snapshot.list_or_none(snapshot.proficiency_ids),
		snapshot.list_or_none(snapshot.role_tags),
		_carrying_summary_for_unit(unit),
		snapshot.list_or_none(snapshot.condition_entries, "No active conditions."),
		snapshot.list_or_none(snapshot.injury_entries, "No injuries."),
		snapshot.list_or_none(snapshot.history_entries, "No recorded history."),
	]

	_item_details.text = (
		"[b]CHARACTER SHEET[/b]\n"
		+ "Resolved from template, persistent identity, equipment and effects."
	)
	_action_preview.text = (
		"Inspecting and expanding calculations is free."
		if unit.is_player_controlled()
		else "Inspection only — this unit is not player-controlled."
	)


func _ability_summary_for_unit(unit: TacticalUnitState) -> String:
	var lines: Array[String] = []
	for entry: Variant in unit.resolved_character.ability_entries:
		lines.append(String(entry))
	if not unit.ability_resource_maximums.is_empty():
		lines.append("")
		lines.append("[b]REMAINING USES[/b]")
		var resource_ids: Array[String] = []
		for raw_id: Variant in unit.ability_resource_maximums.keys():
			resource_ids.append(String(raw_id))
		resource_ids.sort()
		for resource_text: String in resource_ids:
			var resource_id := StringName(resource_text)
			var maximum: int = int(unit.ability_resource_maximums.get(resource_id, 0))
			var remaining: int = unit.ability_uses(resource_id)
			var label: String = resource_text.trim_prefix("resource.").replace(".", " ").capitalize()
			lines.append(
				"%s: At will" % label
				if maximum < 0
				else "%s: %d / %d" % [label, remaining, maximum]
			)
	if unit.fatigued_after_rage:
		lines.append("Fatigued after Rage for this encounter")
	lines.append_array(_rage_live_summary(unit))
	return "None" if lines.is_empty() else "\n".join(PackedStringArray(lines))


func _carrying_summary_for_unit(unit: TacticalUnitState) -> String:
	var snapshot: ResolvedCharacterSnapshot = unit.resolved_character
	var actual_strength: int = snapshot.ability_score("STR")
	var carrying_strength: int = snapshot.stat_value(
		&"effective_carrying_strength", actual_strength
	)
	return (
		"Effective Strength for carrying: %d (actual %d + %d Raider's Burden)\n"
		+ "Light: 0-%d lb · Medium: %d-%d lb · Heavy: %d-%d lb\n"
		+ "Current: %.1f / %d lb\n"
		+ "Load: %s · Movement: %d ft · Half Action: %d ft · Sprint: %s"
	) % [
		carrying_strength,
		actual_strength,
		snapshot.carrying_strength_bonus,
		snapshot.stat_value(&"light_load_max_lb", 0),
		snapshot.stat_value(&"light_load_max_lb", 0) + 1,
		snapshot.stat_value(&"medium_load_max_lb", 0),
		snapshot.stat_value(&"medium_load_max_lb", 0) + 1,
		snapshot.stat_value(&"maximum_weight_lb", 0),
		_facade.state().calculated_carried_weight(unit.unit_id),
		snapshot.stat_value(&"maximum_weight_lb", 0),
		String(unit.load_category).replace("_", " ").capitalize(),
		unit.action_budget.maximum_turn_capacity_feet,
		int(floor(float(unit.action_budget.maximum_turn_capacity_feet) * 0.5)),
		("Unavailable" if unit.sprint_distance_feet <= 0 else "%d ft" % unit.sprint_distance_feet),
	]


func _rage_live_summary(unit: TacticalUnitState) -> Array[String]:
	var lines: Array[String] = []
	var snapshot: ResolvedCharacterSnapshot = unit.resolved_character
	if snapshot == null or not snapshot.has_trait(&"feature.rage"):
		return lines
	lines.append("")
	lines.append("[b]RAGE — LIVE RESOLVED SHEET[/b]")
	lines.append(
		"Status: Active · %d rounds remaining" % unit.rage_rounds_remaining
		if unit.active_character_modifier_ids.has(&"effect.rage")
		else "Status: Inactive"
	)
	lines.append("Uses: %d / %d" % [
		unit.ability_uses(&"resource.rage"),
		int(unit.ability_resource_maximums.get(&"resource.rage", 1)),
	])
	lines.append("Strength %d · Constitution %d · HP %d/%d · AC %d" % [
		snapshot.ability_score("STR"), snapshot.ability_score("CON"),
		unit.current_hp, unit.maximum_hp, unit.armour_class,
	])
	lines.append("Fort %+d · Reflex %+d · Will %+d · Grapple %+d" % [
		snapshot.stat_value(&"fortitude"), snapshot.stat_value(&"reflex"),
		snapshot.stat_value(&"will"), snapshot.stat_value(&"grapple"),
	])
	return lines


func _attack_summary_for_unit(unit: TacticalUnitState) -> String:
	if _facade == null:
		return "Combat catalogue unavailable."

	var snapshot := unit.resolved_character
	var ready_ids: Array[StringName] = _facade.granted_action_ids_for_unit(unit.unit_id)
	var lines: Array[String] = []
	for action_id: StringName in snapshot.granted_action_ids:
		var action: ActionDefinition = _facade.action_definition(action_id)
		if not action is AttackDefinition:
			continue
		var attack := action as AttackDefinition
		var key := "attack:%s" % action_id
		var marker := "▼" if _expanded_breakdowns.has(key) else "▶"
		var readiness := "READY" if ready_ids.has(action_id) else "STOWED"
		lines.append(
			"[url=%s]%s %s %+d · %s %s · Critical %s · %s · %s · %s[/url]"
			% [
				key,
				marker,
				attack.display_name,
				snapshot.attack_bonus_for(attack),
				snapshot.damage_notation_for(attack),
				_damage_type_and_mode_summary(attack),
				_critical_summary(attack),
				attack.range_profile.summary(),
				attack.cost_label(),
				readiness,
			]
		)
		if _expanded_breakdowns.has(key):
			lines.append("[font_size=10]  Attack roll")
			for breakdown_line: String in snapshot.attack_breakdown_for(attack):
				lines.append("    %s" % breakdown_line)
			lines.append("  Damage bonus")
			for breakdown_line: String in snapshot.damage_breakdown_for(attack):
				lines.append("    %s" % breakdown_line)
			lines.append("[/font_size]")

	if lines.is_empty():
		return "No typed attacks available."
	return "\n".join(PackedStringArray(lines))


func _critical_summary(attack: AttackDefinition) -> String:
	if attack == null:
		return "—"
	if attack.critical_threat_minimum >= 20:
		return "×%d" % attack.critical_multiplier
	return "%d–20/×%d" % [
		attack.critical_threat_minimum,
		attack.critical_multiplier,
	]


func _damage_type_and_mode_summary(attack: AttackDefinition) -> String:
	if attack == null or attack.damage_profile == null:
		return "damage"
	var type_text: String = String(attack.damage_profile.damage_type).replace("_", "/")
	match attack.damage_mode_policy:
		AttackDefinition.DAMAGE_POLICY_NONLETHAL_ONLY:
			return "nonlethal %s" % type_text
		AttackDefinition.DAMAGE_POLICY_LETHAL_ONLY:
			return "lethal %s" % type_text
		_:
			if attack.supports_nonlethal:
				return "lethal/nonlethal %s" % type_text
			return type_text


func _defence_summary_for_unit(
		snapshot: ResolvedCharacterSnapshot,
		profile: DefenceProfile
) -> String:
	var lines: Array[String] = []
	if profile == null:
		lines.append("No typed defence profile configured.")
	else:
		lines.append(profile.display_name)
		if not profile.notes.is_empty():
			lines.append(profile.notes)
	lines.append(_formatted_stat(snapshot, &"armour_class", "Armour Class", false))
	return "\n".join(PackedStringArray(lines))


func _formatted_stat(
		snapshot: ResolvedCharacterSnapshot,
		stat_id: StringName,
		label: String,
		signed: bool,
		suffix: String = ""
) -> String:
	var key := "stat:%s" % stat_id
	var marker := "▼" if _expanded_breakdowns.has(key) else "▶"
	var value := snapshot.stat_value(stat_id)
	var value_text := "%+d" % value if signed else "%d" % value
	var result := "[url=%s]%s %s: %s%s[/url]" % [
		key,
		marker,
		label,
		value_text,
		suffix,
	]
	if _expanded_breakdowns.has(key):
		var details: Array[String] = [result, "[font_size=10]"]
		for line: String in snapshot.stat_breakdown(stat_id):
			details.append("  %s" % line)
		details.append("[/font_size]")
		return "\n".join(PackedStringArray(details))
	return result


func _skill_summary(snapshot: ResolvedCharacterSnapshot) -> String:
	if snapshot.skill_bonuses.is_empty():
		return "None"
	var names: Array[String] = []
	for key: Variant in snapshot.skill_bonuses.keys():
		names.append(String(key))
	names.sort()
	var lines: Array[String] = []
	for skill_name: String in names:
		lines.append(
			"%s %+d"
			% [skill_name, int(snapshot.skill_bonuses.get(skill_name, 0))]
		)
	return "\n".join(PackedStringArray(lines))


func _on_sheet_meta_clicked(meta: Variant) -> void:
	var key := String(meta)
	if _expanded_breakdowns.has(key):
		_expanded_breakdowns.erase(key)
	else:
		_expanded_breakdowns[key] = true
	refresh()


func _on_hand_slot_activated(
		slot: UnitManagementSlot,
		mouse_button: int
) -> void:
	if mouse_button == MOUSE_BUTTON_RIGHT:
		if not slot.item_id.is_empty():
			_quick_move(slot.slot_kind, slot.item_id)
		return

	if not slot.item_id.is_empty():
		_select_source(slot.slot_kind, slot.item_id)
		return

	if not _selected_source_item_id.is_empty():
		_execute_transfer(
			_selected_source_kind,
			_selected_source_item_id,
			slot.slot_kind,
			-1
		)


func _on_grid_item_activated(
		item_control: SpatialInventoryItemControl,
		mouse_button: int
) -> void:
	var activated_item: TacticalItemInstanceState = _facade.state().get_item(item_control.item_id)
	if activated_item != null and activated_item.definition != null and activated_item.definition.has_tag(&"raiders_sack"):
		if mouse_button == MOUSE_BUTTON_LEFT:
			_open_raider_sack_popup()
		else:
			message_requested.emit("Raider's Sack is a permanent Belt item. Left-click it to open.")
		return
	if mouse_button == MOUSE_BUTTON_RIGHT:
		var item: TacticalItemInstanceState = _facade.state().get_item(
			item_control.item_id
		)
		if item != null and item.is_body():
			_open_body_context_menu(item.item_id)
		else:
			_quick_move(item_control.source_kind, item_control.item_id)
		return

	_select_source(item_control.source_kind, item_control.item_id)


func _open_raider_sack_popup() -> void:
	if _facade == null or _current_unit_id.is_empty():
		return
	var state: TacticalState = _facade.state()
	var sack: TacticalItemInstanceState = state.raider_sack_item_for_unit(
		_current_unit_id
	)
	if sack == null:
		message_requested.emit(
			"This Marauder has no Raider's Sack item. Reopen the mission so the loadout migration can repair it."
		)
		return
	_raider_sack_grid.render_inventory_items(
		state.get_unit_container_items(_current_unit_id, KIND_RAIDER_SACK),
		state
	)
	var popup_size := RAIDER_SACK_POPUP_SIZE
	var viewport_size := Vector2i(get_viewport_rect().size)
	var desired := Vector2i(get_viewport().get_mouse_position()) + Vector2i(18, 18)
	desired.x = clampi(desired.x, 8, maxi(8, viewport_size.x - popup_size.x - 8))
	desired.y = clampi(desired.y, 8, maxi(8, viewport_size.y - popup_size.y - 8))
	_raider_sack_popup.position = Vector2(desired)
	_raider_sack_popup.size = Vector2(popup_size)
	_raider_sack_popup.visible = true
	_raider_sack_popup.move_to_front()
	message_requested.emit("Raider's Sack opened.")


func _close_raider_sack_popup() -> void:
	if _raider_sack_popup != null and _raider_sack_popup.visible:
		_raider_sack_popup.hide()


func _on_item_dropped_onto(
		target_item_id: StringName,
		drag_data: Dictionary
) -> void:
	if not _current_unit_is_player_controlled():
		return
	var source_item_id := StringName(drag_data.get("source_item_id", &""))
	if source_item_id.is_empty() or source_item_id == target_item_id:
		return
	var result: OperationResult = _facade.apply_item_to_body(
		_current_unit_id, source_item_id, target_item_id
	)
	message_requested.emit(result.message)
	if result.success:
		_clear_selection()
		refresh()


func _open_body_context_menu(body_item_id: StringName) -> void:
	_body_context_item_id = body_item_id
	var action_ids: Array[StringName] = [
		TacticalBodyActionHandler.ACTION_LOOT,
		TacticalBodyActionHandler.ACTION_FIRST_AID,
		TacticalBodyActionHandler.ACTION_FINISH_OFF,
		TacticalBodyActionHandler.ACTION_UNTIE,
	]
	for index: int in range(action_ids.size()):
		var reason: String = _facade.body_action_unavailable_reason(
			_current_unit_id, body_item_id, action_ids[index]
		)
		_body_context_menu.set_item_disabled(index, not reason.is_empty())
		_body_context_menu.set_item_tooltip(index, reason)
	_body_context_menu.position = Vector2i(get_viewport().get_mouse_position())
	_body_context_menu.popup()


func _on_body_context_action(action_id: int) -> void:
	if _body_context_item_id.is_empty():
		return
	match action_id:
		BODY_MENU_LOOT:
			_open_body_loot(_body_context_item_id)
		BODY_MENU_FIRST_AID:
			_report_body_result(_facade.body_administer_first_aid(
				_current_unit_id, _body_context_item_id
			))
		BODY_MENU_FINISH_OFF:
			_report_body_result(_facade.finish_off_body(
				_current_unit_id, _body_context_item_id
			))
		BODY_MENU_UNTIE:
			_report_body_result(_facade.untie_body(
				_current_unit_id, _body_context_item_id
			))


func _report_body_result(result: OperationResult) -> void:
	message_requested.emit(result.message)
	_action_preview.text = result.message
	refresh()


func _open_body_loot(body_item_id: StringName) -> void:
	_loot_body_item_id = body_item_id
	_refresh_body_loot_list()
	_loot_popup.position = Vector2i(
		get_viewport_rect().size * 0.5 - Vector2(260.0, 210.0)
	)
	_loot_popup.popup()


func _refresh_body_loot_list() -> void:
	_loot_list.clear()
	for item: TacticalItemInstanceState in _facade.equipment_for_body(
		_loot_body_item_id
	):
		var index: int = _loot_list.add_item(item.display_line())
		_loot_list.set_item_metadata(index, item.item_id)
	var has_items: bool = _loot_list.item_count > 0
	_loot_take_button.disabled = not has_items
	_loot_search_button.disabled = not has_items


func _take_selected_body_item() -> void:
	var selected: PackedInt32Array = _loot_list.get_selected_items()
	if selected.is_empty():
		message_requested.emit("Select an item to loot.")
		return
	var item_id := StringName(_loot_list.get_item_metadata(selected[0]))
	var item: TacticalItemInstanceState = _facade.state().get_item(item_id)
	if item == null or item.location == null:
		return
	var target_index: int = _facade.first_fit_for_item(
		_current_unit_id, item, KIND_BACKPACK
	)
	if target_index < 0:
		message_requested.emit("The item does not fit in the acting character's Backpack.")
		return
	_execute_transfer(
		item.location.container_kind, item.item_id, KIND_BACKPACK, target_index
	)
	_refresh_body_loot_list()


func _search_open_body() -> void:
	var result: OperationResult = _facade.search_body_inventory(
		_current_unit_id, _loot_body_item_id
	)
	message_requested.emit(result.message)
	_action_preview.text = result.message
	_refresh_body_loot_list()
	refresh()


func _on_empty_cell_activated(
		target_kind: StringName,
		target_cell_index: int
) -> void:
	if _selected_source_item_id.is_empty():
		return

	_execute_transfer(
		_selected_source_kind,
		_selected_source_item_id,
		target_kind,
		target_cell_index
	)


func _on_transfer_requested(
		source_kind: StringName,
		source_item_id: StringName,
		target_kind: StringName,
		target_cell_index: int
) -> void:
	_execute_transfer(
		source_kind,
		source_item_id,
		target_kind,
		target_cell_index
	)


func _select_source(
		source_kind: StringName,
		source_item_id: StringName
) -> void:
	_selected_source_kind = source_kind
	_selected_source_item_id = source_item_id
	_refresh_selection_visuals()
	_refresh_footer()


func _execute_transfer(
		source_kind: StringName,
		source_item_id: StringName,
		target_kind: StringName,
		target_cell_index: int
) -> void:
	if not _current_unit_is_player_controlled():
		var read_only_message := (
			"Enemy and neutral inventories are inspection-only during this stage."
		)
		_action_preview.text = read_only_message
		message_requested.emit(read_only_message)
		return

	var command := TacticalInventoryTransferCommand.new(
		_current_unit_id,
		source_kind,
		source_item_id,
		target_kind,
		target_cell_index
	)

	var preview: TacticalInventoryTransferPreview = _facade.preview_inventory_transfer(command)
	if not preview.success:
		_action_preview.text = preview.reason
		message_requested.emit(preview.reason)
		return

	_action_preview.text = _format_preview(preview)
	var result: OperationResult = _facade.execute_inventory_transfer_plan(preview.plan, preview)
	message_requested.emit(result.message)

	if result.success:
		_clear_selection()
	else:
		_action_preview.text = result.message


func _quick_move(
		source_kind: StringName,
		source_item_id: StringName
) -> void:
	if not _current_unit_is_player_controlled():
		var read_only_message := (
			"Enemy and neutral inventories are inspection-only during this stage."
		)
		_action_preview.text = read_only_message
		message_requested.emit(read_only_message)
		return

	var unit: TacticalUnitState = _facade.state().get_unit(_current_unit_id)
	if unit == null:
		return

	var probe := TacticalInventoryTransferCommand.new(
		_current_unit_id,
		source_kind,
		source_item_id,
		&"",
		-1
	)
	var item: TacticalItemInstanceState = _facade.resolve_inventory_source_item(probe)
	if item == null:
		return

	var target_kind: StringName = &""
	var target_index := -1

	match source_kind:
		KIND_GROUND:
			if item.backpack_allowed:
				target_kind = KIND_BACKPACK
				target_index = _facade.first_fit_for_item(
					_current_unit_id,
					item,
					target_kind
				)
			if target_index < 0 and item.belt_allowed:
				target_kind = KIND_BELT
				target_index = _facade.first_fit_for_item(
					_current_unit_id,
					item,
					target_kind
				)
			if target_index < 0 and _facade.state().get_hand_item(unit.unit_id, KIND_PRIMARY_HAND) == null:
				target_kind = KIND_PRIMARY_HAND
		KIND_BACKPACK:
			if item.belt_allowed:
				target_kind = KIND_BELT
				target_index = _facade.first_fit_for_item(
					_current_unit_id,
					item,
					target_kind
				)
			if target_index < 0 and _facade.state().get_hand_item(unit.unit_id, KIND_PRIMARY_HAND) == null:
				target_kind = KIND_PRIMARY_HAND
			elif (
				target_index < 0
				and not item.two_handed
				and _facade.state().get_hand_item(unit.unit_id, KIND_SECONDARY_HAND) == null
			):
				target_kind = KIND_SECONDARY_HAND
		KIND_BELT:
			if _facade.state().get_hand_item(unit.unit_id, KIND_PRIMARY_HAND) == null:
				target_kind = KIND_PRIMARY_HAND
			elif (
				not item.two_handed
				and _facade.state().get_hand_item(unit.unit_id, KIND_SECONDARY_HAND) == null
			):
				target_kind = KIND_SECONDARY_HAND
			else:
				target_kind = KIND_BACKPACK
				target_index = _facade.first_fit_for_item(
					_current_unit_id,
					item,
					target_kind
				)
		KIND_PRIMARY_HAND, KIND_SECONDARY_HAND:
			target_kind = KIND_BACKPACK
			target_index = _facade.first_fit_for_item(
				_current_unit_id,
				item,
				target_kind
			)

	if target_kind.is_empty() or (
		target_kind in [KIND_BELT, KIND_BACKPACK]
		and target_index < 0
	):
		_action_preview.text = "No sensible empty destination is available."
		return

	_execute_transfer(
		source_kind,
		source_item_id,
		target_kind,
		target_index
	)


func _current_unit_is_player_controlled() -> bool:
	if _facade == null:
		return false
	var unit: TacticalUnitState = _facade.state().get_unit(_current_unit_id)
	return unit != null and unit.is_player_controlled()


func _refresh_selection_visuals() -> void:
	_belt_grid.set_selected_item(_selected_source_item_id)
	_backpack_grid.set_selected_item(_selected_source_item_id)
	_reach_grid.set_selected_item(_selected_source_item_id)

	if _primary_hand_slot != null:
		_primary_hand_slot.set_selected(
			_primary_hand_slot.item_id == _selected_source_item_id
		)
		_primary_hand_slot.set_valid_target(
			_hand_is_valid_target(KIND_PRIMARY_HAND)
		)

	if _secondary_hand_slot != null:
		_secondary_hand_slot.set_selected(
			_secondary_hand_slot.item_id == _selected_source_item_id
		)
		_secondary_hand_slot.set_valid_target(
			_hand_is_valid_target(KIND_SECONDARY_HAND)
		)


func _hand_is_valid_target(hand_kind: StringName) -> bool:
	if _selected_source_item_id.is_empty():
		return false

	var command := TacticalInventoryTransferCommand.new(
		_current_unit_id,
		_selected_source_kind,
		_selected_source_item_id,
		hand_kind,
		-1
	)
	return _facade.preview_inventory_transfer(command).success


func _refresh_footer() -> void:
	if _selected_source_item_id.is_empty():
		_item_details.text = (
			"Drag an item, click a destination, or right-click for a quick move."
		)
		_action_preview.text = (
			"Belt ↔ Hand: Quick Action. Backpack is slower."
		)
		return

	var command := TacticalInventoryTransferCommand.new(
		_current_unit_id,
		_selected_source_kind,
		_selected_source_item_id,
		&"",
		-1
	)
	var item: TacticalItemInstanceState = _facade.resolve_inventory_source_item(command)
	if item == null:
		return

	var source_text := ""
	if _selected_source_kind == KIND_GROUND and not item.source_label.is_empty():
		source_text = " · %s" % item.source_label

	var quantity_text := ""
	if item.quantity > 1:
		quantity_text = " · Quantity %d" % item.quantity
	var description := (
		item.definition.description
		if item.definition != null
		else "Portable tactical item."
	)
	var displayed_weight: float = _facade.state().effective_item_weight(item)
	_item_details.text = (
		"[b]%s[/b] · %.1f lb · %d × %d%s%s
%s"
	) % [
		item.display_name,
		displayed_weight,
		item.footprint.x,
		item.footprint.y,
		quantity_text,
		source_text,
		description,
	]
	_action_preview.text = "Choose a highlighted hand or valid grid position."


func _format_preview(preview: TacticalInventoryTransferPreview) -> String:
	var parts: Array[String] = []

	if preview.action_cost.is_quick_action():
		parts.append("Quick Action")
	elif preview.cost_feet <= 0:
		parts.append("Free")
	else:
		parts.append("%d ft" % preview.cost_feet)

	if preview.requires_quick_action:
		parts.append("Quick Action")
	if preview.provokes:
		parts.append("Normally Provokes")

	return "%s · %s" % [
		preview.action_name,
		" · ".join(PackedStringArray(parts)),
	]


func _clear_selection() -> void:
	_selected_source_kind = &""
	_selected_source_item_id = &""
	if visible and _current_tab == TAB_INVENTORY:
		_refresh_selection_visuals()


func _change_unit(direction: int) -> void:
	_close_raider_sack_popup()
	var order := _resolved_unit_order()
	if order.is_empty():
		return

	var current_index := order.find(_current_unit_id)
	if current_index < 0:
		current_index = 0

	var next_index := posmod(current_index + direction, order.size())
	_current_unit_id = order[next_index]
	_clear_selection()
	unit_changed.emit(_current_unit_id)
	refresh()


func _select_unit_by_index(index: int) -> void:
	var order := _resolved_unit_order()
	if index < 0 or index >= order.size():
		return

	_current_unit_id = order[index]
	_clear_selection()
	unit_changed.emit(_current_unit_id)
	refresh()


func _resolved_unit_order() -> Array[StringName]:
	var result: Array[StringName] = []

	for unit_id: StringName in _unit_order:
		if _facade.state().get_unit(unit_id) != null:
			result.append(unit_id)

	if result.is_empty():
		for unit: TacticalUnitState in _facade.state().get_player_units():
			result.append(unit.unit_id)

	return result


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
