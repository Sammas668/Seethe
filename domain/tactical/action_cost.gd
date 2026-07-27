class_name ActionCost
extends RefCounted

enum Category {
    MINOR,
    HALF,
    FULL,
    QUICK,
    FIXED_FEET,
}

var category: int = Category.HALF
var fixed_feet: int = 0


func _init(category_value: int = Category.HALF, fixed_feet_value: int = 0) -> void:
    category = category_value
    fixed_feet = max(0, fixed_feet_value)


static func minor_interaction() -> ActionCost:
    return ActionCost.new(Category.MINOR)


static func half_action() -> ActionCost:
    return ActionCost.new(Category.HALF)


static func full_action() -> ActionCost:
    return ActionCost.new(Category.FULL)


static func quick_action() -> ActionCost:
    return ActionCost.new(Category.QUICK)


static func fixed_capacity(feet: int) -> ActionCost:
    return ActionCost.new(Category.FIXED_FEET, feet)


func resolved_normal_capacity_feet(maximum_capacity_feet: int) -> int:
    match category:
        Category.MINOR:
            return 5
        Category.HALF:
            return int(floor(maximum_capacity_feet * 0.5))
        Category.FULL:
            return maximum_capacity_feet
        Category.FIXED_FEET:
            return fixed_feet
        Category.QUICK:
            return 0
        _:
            return 0


func consumes_normal_capacity() -> bool:
    return category != Category.QUICK


func is_quick_action() -> bool:
    return category == Category.QUICK
