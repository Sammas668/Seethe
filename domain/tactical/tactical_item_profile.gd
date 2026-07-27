class_name TacticalItemProfile
extends RefCounted


static func footprint_for(item_name: String) -> Vector2i:
    var lower := item_name.to_lower()

    if "grain crate" in lower:
        return Vector2i(3, 2)
    if "shortbow" in lower or "bow" in lower:
        return Vector2i(3, 2)
    if "spear" in lower:
        return Vector2i(1, 4)
    if "shield" in lower or "buckler" in lower:
        return Vector2i(2, 2)
    if "axe" in lower:
        return Vector2i(2, 3)
    if "dagger" in lower or "knife" in lower:
        return Vector2i(1, 2)
    if "rope" in lower:
        return Vector2i(2, 1)
    if "arrows" in lower or "quiver" in lower:
        return Vector2i(1, 2)
    if "manacles" in lower:
        return Vector2i(2, 1)
    if "rations" in lower:
        return Vector2i(2, 1)
    if "sack" in lower:
        return Vector2i(2, 2)
    if "armour" in lower:
        return Vector2i(3, 3)
    return Vector2i.ONE


static func weight_for(item_name: String) -> float:
    var lower := item_name.to_lower()

    if "grain crate" in lower:
        return 25.0
    if "armour" in lower:
        return 12.0
    if "shield" in lower or "buckler" in lower:
        return 6.0
    if "shortbow" in lower or "bow" in lower:
        return 4.0
    if "spear" in lower:
        return 6.0
    if "axe" in lower:
        return 7.0
    if "dagger" in lower or "knife" in lower:
        return 1.0
    if "rope" in lower:
        return 4.0
    if "arrows" in lower or "quiver" in lower:
        return 3.0
    if "manacles" in lower:
        return 2.0
    if "rations" in lower:
        return 2.5
    if "bandage" in lower or "pellet" in lower or "lockpick" in lower:
        return 0.5
    if "sack" in lower:
        return 1.0
    return 1.0


static func is_two_handed(item_name: String) -> bool:
    var lower := item_name.to_lower()
    return (
        "shortbow" in lower
        or "longbow" in lower
        or "greatsword" in lower
        or "greataxe" in lower
        or "two-handed" in lower
    )


static func backpack_allowed(item_name: String) -> bool:
    var lower := item_name.to_lower()
    return not ("grain crate" in lower or "armour" in lower)


static func belt_allowed(item_name: String) -> bool:
    var lower := item_name.to_lower()
    var footprint := footprint_for(item_name)

    if "grain crate" in lower or "armour" in lower:
        return false
    if "bow" in lower or "spear" in lower or "shield" in lower:
        return false
    if footprint.x > 2 or footprint.y > 2:
        return false
    return true


static func description_for(item_name: String) -> String:
    var lower := item_name.to_lower()

    if item_name.is_empty() or lower == "empty":
        return "Empty inventory space."
    if "armour" in lower:
        return "Worn protection. Armour is listed on the Character Sheet and cannot be changed during battle."
    if "grain crate" in lower:
        return "Bulky physical loot. It cannot fit in the Belt or Backpack."
    if "bow" in lower or "sling" in lower:
        return "Ranged weapon. When held, it supplies ranged attacks and later Overwatch."
    if (
        "spear" in lower
        or "axe" in lower
        or "dagger" in lower
        or "knife" in lower
    ):
        return "Weapon. When held, it supplies its associated attack actions."
    if "bandage" in lower:
        return "Medical item. Keeping it on the Belt makes it faster to draw or stow."
    if "rope" in lower or "lockpick" in lower or "manacles" in lower:
        return "Tactical tool used by interactions and abilities."
    return "Portable tactical item."
