class_name TacticalUnitState
extends RefCounted

var unit_id: StringName
var display_name: String
var team_id: StringName
var grid_position: Vector2i
var action_budget: ActionBudgetState
var diagonal_steps_used: int
var footprint: Vector2i

var maximum_hp: int
var current_hp: int
var armour_class: int
var inventory: TacticalInventoryState


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
    grid_position = grid_position_value
    action_budget = ActionBudgetState.new(maximum_capacity_value)
    diagonal_steps_used = 0
    footprint = Vector2i.ONE

    maximum_hp = maxi(1, maximum_hp_value)
    current_hp = maximum_hp
    armour_class = maxi(0, armour_class_value)
    inventory = TacticalInventoryState.new()


func configure_inventory(inventory_value: TacticalInventoryState) -> void:
    inventory = inventory_value if inventory_value != null else TacticalInventoryState.new()


func refresh_for_new_round() -> void:
    action_budget.refresh_for_new_round()
    diagonal_steps_used = 0


func mark_activation_ended() -> void:
    action_budget.ended_activation = true


func reactivate_without_refresh() -> void:
    action_budget.ended_activation = false
