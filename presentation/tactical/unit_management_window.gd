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

@onready var _previous_button: Button = $Modal/Margin/VBox/Header/PreviousUnitButton
@onready var _unit_title: Label = $Modal/Margin/VBox/Header/UnitTitle
@onready var _inventory_tab_button: Button = $Modal/Margin/VBox/Header/InventoryTabButton
@onready var _character_tab_button: Button = $Modal/Margin/VBox/Header/CharacterTabButton
@onready var _next_button: Button = $Modal/Margin/VBox/Header/NextUnitButton
@onready var _close_button: Button = $Modal/Margin/VBox/Header/CloseButton

@onready var _inventory_tab: VBoxContainer = $Modal/Margin/VBox/Content/InventoryTab
@onready var _character_tab: HBoxContainer = $Modal/Margin/VBox/Content/CharacterTab

@onready var _primary_hand_container: HBoxContainer = $Modal/Margin/VBox/Content/InventoryTab/Upper/LoadoutPanel/Margin/VBox/PrimaryHandContainer
@onready var _secondary_hand_container: HBoxContainer = $Modal/Margin/VBox/Content/InventoryTab/Upper/LoadoutPanel/Margin/VBox/SecondaryHandContainer
@onready var _belt_grid: SpatialInventoryGrid = $Modal/Margin/VBox/Content/InventoryTab/Upper/LoadoutPanel/Margin/VBox/BeltGrid
@onready var _stats_text: RichTextLabel = $Modal/Margin/VBox/Content/InventoryTab/Upper/StatsPanel/Margin/StatsText
@onready var _backpack_grid: SpatialInventoryGrid = $Modal/Margin/VBox/Content/InventoryTab/Lower/BackpackPanel/Margin/VBox/BackpackGrid
@onready var _reach_grid: SpatialInventoryGrid = $Modal/Margin/VBox/Content/InventoryTab/Lower/ReachPanel/Margin/VBox/ReachGrid

@onready var _identity_text: RichTextLabel = $Modal/Margin/VBox/Content/CharacterTab/IdentityPanel/Margin/VBox/IdentityText
@onready var _ability_grid: GridContainer = $Modal/Margin/VBox/Content/CharacterTab/AttributePanel/Margin/VBox/AbilityGrid
@onready var _combat_summary: RichTextLabel = $Modal/Margin/VBox/Content/CharacterTab/AttributePanel/Margin/VBox/CombatSummary
@onready var _details_text: RichTextLabel = $Modal/Margin/VBox/Content/CharacterTab/DetailsPanel/Margin/DetailsText

@onready var _item_details: RichTextLabel = $Modal/Margin/VBox/ContextFooter/Margin/Row/ItemDetails
@onready var _action_preview: Label = $Modal/Margin/VBox/ContextFooter/Margin/Row/ActionPreview

var _state_store: TacticalStateStore
var _transfer_handler: TacticalInventoryTransferHandler
var _current_unit_id: StringName = &""
var _unit_order: Array[StringName] = []
var _current_tab: StringName = TAB_INVENTORY

var _primary_hand_slot: UnitManagementSlot
var _secondary_hand_slot: UnitManagementSlot
var _selected_source_kind: StringName = &""
var _selected_source_item_id: StringName = &""


func _ready() -> void:
    set_process_unhandled_key_input(false)

    _previous_button.pressed.connect(func() -> void: _change_unit(-1))
    _next_button.pressed.connect(func() -> void: _change_unit(1))
    _close_button.pressed.connect(close_window)

    _inventory_tab_button.pressed.connect(
        func() -> void: show_tab(TAB_INVENTORY)
    )
    _character_tab_button.pressed.connect(
        func() -> void: show_tab(TAB_CHARACTER)
    )

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
    ]:
        grid.item_activated.connect(_on_grid_item_activated)
        grid.transfer_requested.connect(_on_transfer_requested)
        grid.empty_cell_activated.connect(_on_empty_cell_activated)


func configure(
        state_store: TacticalStateStore,
        initial_unit_id: StringName,
        unit_order_value: Array[StringName]
) -> void:
    _state_store = state_store
    _transfer_handler = TacticalInventoryTransferHandler.new(_state_store)
    _current_unit_id = initial_unit_id
    _unit_order.clear()
    for unit_id: StringName in unit_order_value:
        _unit_order.append(unit_id)


func open_for_unit(
        unit_id: StringName,
        tab_id: StringName = TAB_INVENTORY
) -> void:
    if _state_store == null:
        return

    _current_unit_id = unit_id
    visible = true
    set_process_unhandled_key_input(true)
    show_tab(tab_id)
    _clear_selection()
    refresh()


func close_window() -> void:
    visible = false
    set_process_unhandled_key_input(false)
    _clear_selection()
    closed.emit()


func hide_silently() -> void:
    visible = false
    set_process_unhandled_key_input(false)
    _clear_selection()


func set_current_unit(unit_id: StringName) -> void:
    _current_unit_id = unit_id
    _clear_selection()
    refresh()


func refresh() -> void:
    if not visible or _state_store == null:
        return

    var unit := _state_store.state.get_unit(_current_unit_id)
    if unit == null:
        return

    _unit_title.text = unit.display_name.to_upper()

    if _current_tab == TAB_INVENTORY:
        _render_inventory_tab(unit)
    else:
        _render_character_tab(unit)


func show_tab(tab_id: StringName) -> void:
    _current_tab = TAB_CHARACTER if tab_id == TAB_CHARACTER else TAB_INVENTORY
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

    _primary_hand_slot = _create_hand_slot(
        _primary_hand_container,
        KIND_PRIMARY_HAND,
        "PRIMARY HAND",
        unit.inventory.primary_hand_item,
        true,
        ""
    )

    var secondary_accepts_items := true
    var secondary_reserved_text := ""
    if (
        unit.inventory.primary_hand_item != null
        and unit.inventory.primary_hand_item.two_handed
    ):
        secondary_accepts_items = false
        secondary_reserved_text = (
            "RESERVED BY %s"
            % unit.inventory.primary_hand_item.display_name.to_upper()
        )

    _secondary_hand_slot = _create_hand_slot(
        _secondary_hand_container,
        KIND_SECONDARY_HAND,
        "SECONDARY HAND",
        unit.inventory.secondary_hand_item,
        secondary_accepts_items,
        secondary_reserved_text
    )

    _belt_grid.render_inventory_items(unit.inventory.belt_items)
    _backpack_grid.render_inventory_items(unit.inventory.backpack_items)
    _reach_grid.render_ground_items(
        _state_store.state.get_accessible_ground_items(unit)
    )

    _refresh_inventory_stats(unit)
    _refresh_selection_visuals()
    _refresh_footer()


func _create_hand_slot(
        parent: Control,
        hand_kind: StringName,
        label_text: String,
        item: TacticalInventoryItemState,
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
        reserved_text
    )
    slot.item_activated.connect(_on_hand_slot_activated)
    slot.transfer_requested.connect(_on_transfer_requested)
    return slot


func _refresh_inventory_stats(unit: TacticalUnitState) -> void:
    var sheet := unit.character_sheet
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
        sheet.level,
        sheet.class_name_text,
        sheet.archetype_name,
        unit.current_hp,
        unit.maximum_hp,
        unit.armour_class,
        unit.action_budget.maximum_turn_capacity_feet,
        sheet.passive_perception,
        unit.action_budget.remaining_turn_capacity_feet,
        unit.action_budget.maximum_turn_capacity_feet,
        unit.inventory.current_weight_lb,
        unit.inventory.maximum_weight_lb,
        quick_text,
        reaction_text,
    ]


func _render_character_tab(unit: TacticalUnitState) -> void:
    var sheet := unit.character_sheet

    _identity_text.text = (
        "[b]%s[/b]\n\n"
        + "Level %d\n"
        + "Class: %s\n"
        + "Archetype: %s\n"
        + "Type: %s\n\n"
        + "HP: %d / %d\n"
        + "Armour: %s\n"
        + "Armour Class: %d\n"
        + "Speed: %d ft\n"
        + "Weight: %.1f / %.1f lb"
    ) % [
        unit.display_name,
        sheet.level,
        sheet.class_name_text,
        sheet.archetype_name,
        sheet.troop_type,
        unit.current_hp,
        unit.maximum_hp,
        unit.inventory.armour,
        unit.armour_class,
        unit.action_budget.maximum_turn_capacity_feet,
        unit.inventory.current_weight_lb,
        unit.inventory.maximum_weight_lb,
    ]

    _clear_children(_ability_grid)
    for abbreviation: String in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
        var label := Label.new()
        label.custom_minimum_size = Vector2(125.0, 30.0)
        label.text = sheet.ability_line(abbreviation)
        _ability_grid.add_child(label)

    _combat_summary.text = (
        "[b]COMBAT SUMMARY[/b]\n\n"
        + "Initiative: %+d\n"
        + "Passive Perception: %d\n"
        + "Fortitude: %+d\n"
        + "Reflex: %+d\n"
        + "Will: %+d\n\n"
        + "[b]SKILLS[/b]\n%s"
    ) % [
        sheet.initiative_bonus,
        sheet.passive_perception,
        sheet.fortitude_save,
        sheet.reflex_save,
        sheet.will_save,
        sheet.list_or_none(sheet.skill_entries),
    ]

    _details_text.text = (
        "[b]CURRENT EQUIPMENT[/b]\n"
        + "Primary Hand: %s\n"
        + "Secondary Hand: %s\n"
        + "Belt: %s\n\n"
        + "[b]ATTACKS[/b]\n%s\n\n"
        + "[b]DEFENCES & RESISTANCES[/b]\n%s\n\n"
        + "[b]ABILITIES[/b]\n%s\n\n"
        + "[b]CONDITIONS[/b]\n%s\n\n"
        + "[b]INJURIES[/b]\n%s"
    ) % [
        unit.inventory.main_hand,
        unit.inventory.off_hand,
        unit.inventory.belt_summary(),
        sheet.list_or_none(sheet.attack_entries, "No attacks configured."),
        sheet.list_or_none(sheet.defence_entries),
        sheet.list_or_none(sheet.ability_entries),
        sheet.list_or_none(sheet.condition_entries, "No active conditions."),
        sheet.list_or_none(sheet.injury_entries, "No injuries."),
    ]

    _item_details.text = (
        "[b]CHARACTER SHEET[/b]\n"
        + "Armour is read-only during battle."
    )
    _action_preview.text = "Switching tabs and inspecting statistics are free."


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
    if mouse_button == MOUSE_BUTTON_RIGHT:
        _quick_move(item_control.source_kind, item_control.item_id)
        return

    _select_source(item_control.source_kind, item_control.item_id)


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
    var command := TacticalInventoryTransferCommand.new(
        _current_unit_id,
        source_kind,
        source_item_id,
        target_kind,
        target_cell_index
    )

    var preview := _transfer_handler.preview(command)
    if not preview.success:
        _action_preview.text = preview.reason
        message_requested.emit(preview.reason)
        return

    _action_preview.text = _format_preview(preview)
    var result := _transfer_handler.execute(command)
    message_requested.emit(result.message)

    if result.success:
        _clear_selection()
        refresh()
    else:
        _action_preview.text = result.message


func _quick_move(
        source_kind: StringName,
        source_item_id: StringName
) -> void:
    var unit := _state_store.state.get_unit(_current_unit_id)
    if unit == null:
        return

    var probe := TacticalInventoryTransferCommand.new(
        _current_unit_id,
        source_kind,
        source_item_id,
        &"",
        -1
    )
    var item := _transfer_handler.resolve_source_item(probe)
    if item == null:
        return

    var target_kind: StringName = &""
    var target_index := -1

    match source_kind:
        KIND_GROUND:
            if TacticalItemProfile.backpack_allowed(item.display_name):
                target_kind = KIND_BACKPACK
                target_index = _transfer_handler.first_fit_for_item(
                    _current_unit_id,
                    item,
                    target_kind
                )
            if target_index < 0 and item.belt_allowed:
                target_kind = KIND_BELT
                target_index = _transfer_handler.first_fit_for_item(
                    _current_unit_id,
                    item,
                    target_kind
                )
            if target_index < 0 and unit.inventory.primary_hand_item == null:
                target_kind = KIND_PRIMARY_HAND
        KIND_BACKPACK:
            if item.belt_allowed:
                target_kind = KIND_BELT
                target_index = _transfer_handler.first_fit_for_item(
                    _current_unit_id,
                    item,
                    target_kind
                )
            if target_index < 0 and unit.inventory.primary_hand_item == null:
                target_kind = KIND_PRIMARY_HAND
            elif (
                target_index < 0
                and not item.two_handed
                and unit.inventory.secondary_hand_item == null
            ):
                target_kind = KIND_SECONDARY_HAND
        KIND_BELT:
            if unit.inventory.primary_hand_item == null:
                target_kind = KIND_PRIMARY_HAND
            elif (
                not item.two_handed
                and unit.inventory.secondary_hand_item == null
            ):
                target_kind = KIND_SECONDARY_HAND
            else:
                target_kind = KIND_BACKPACK
                target_index = _transfer_handler.first_fit_for_item(
                    _current_unit_id,
                    item,
                    target_kind
                )
        KIND_PRIMARY_HAND, KIND_SECONDARY_HAND:
            target_kind = KIND_BACKPACK
            target_index = _transfer_handler.first_fit_for_item(
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
    return _transfer_handler.preview(command).success


func _refresh_footer() -> void:
    if _selected_source_item_id.is_empty():
        _item_details.text = (
            "[b]INVENTORY[/b]\n"
            + "Drag an item, click an item then a destination, or right-click for a quick move."
        )
        _action_preview.text = (
            "Belt to Hand or Hand to Belt costs a Quick Action. Backpack access is slower."
        )
        return

    var command := TacticalInventoryTransferCommand.new(
        _current_unit_id,
        _selected_source_kind,
        _selected_source_item_id,
        &"",
        -1
    )
    var item := _transfer_handler.resolve_source_item(command)
    if item == null:
        return

    var source_text := ""
    if _selected_source_kind == KIND_GROUND and not item.source_label.is_empty():
        source_text = " · %s" % item.source_label

    _item_details.text = (
        "[b]%s[/b] · %.1f lb · %d × %d%s\n%s"
    ) % [
        item.display_name,
        item.weight_lb,
        item.footprint.x,
        item.footprint.y,
        source_text,
        TacticalItemProfile.description_for(item.display_name),
    ]
    _action_preview.text = "Choose an empty highlighted hand or a valid grid position."


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
        if _state_store.state.get_unit(unit_id) != null:
            result.append(unit_id)

    if result.is_empty():
        for unit: TacticalUnitState in _state_store.state.get_player_units():
            result.append(unit.unit_id)

    return result


func _clear_children(parent: Node) -> void:
    for child: Node in parent.get_children():
        parent.remove_child(child)
        child.queue_free()
