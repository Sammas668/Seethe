class_name TacticalState
extends RefCounted

var phase_state: TacticalPhaseState = TacticalPhaseState.new()
var units_by_id: Dictionary = {}
var ground_items_by_id: Dictionary = {}


func add_unit(unit_state: TacticalUnitState) -> void:
    units_by_id[unit_state.unit_id] = unit_state


func get_unit(unit_id: StringName) -> TacticalUnitState:
    return units_by_id.get(unit_id) as TacticalUnitState


func get_units() -> Array[TacticalUnitState]:
    var result: Array[TacticalUnitState] = []
    for value: Variant in units_by_id.values():
        var unit := value as TacticalUnitState
        if unit != null:
            result.append(unit)
    result.sort_custom(func(a: TacticalUnitState, b: TacticalUnitState) -> bool:
        return String(a.unit_id) < String(b.unit_id)
    )
    return result


func get_player_units() -> Array[TacticalUnitState]:
    var result: Array[TacticalUnitState] = []
    for unit: TacticalUnitState in get_units():
        if unit.team_id == &"player":
            result.append(unit)
    return result


func get_unit_at_tile(
        tile: Vector2i,
        except_unit_id: StringName = &""
) -> TacticalUnitState:
    for unit: TacticalUnitState in get_units():
        if unit.unit_id == except_unit_id:
            continue
        if unit.grid_position == tile:
            return unit
    return null


func add_ground_item(item_state: TacticalItemState) -> void:
    ground_items_by_id[item_state.item_id] = item_state


func get_ground_items() -> Array[TacticalItemState]:
    var result: Array[TacticalItemState] = []
    for value: Variant in ground_items_by_id.values():
        var item := value as TacticalItemState
        if item != null:
            result.append(item)
    result.sort_custom(func(a: TacticalItemState, b: TacticalItemState) -> bool:
        return String(a.item_id) < String(b.item_id)
    )
    return result


func get_accessible_ground_items(unit: TacticalUnitState) -> Array[TacticalItemState]:
    var result: Array[TacticalItemState] = []
    if unit == null:
        return result

    for item: TacticalItemState in get_ground_items():
        var offset := item.grid_position - unit.grid_position
        if absi(offset.x) <= 1 and absi(offset.y) <= 1:
            result.append(item)

    result.sort_custom(func(a: TacticalItemState, b: TacticalItemState) -> bool:
        if a.source_label == b.source_label:
            return a.display_name < b.display_name
        return a.source_label < b.source_label
    )
    return result
