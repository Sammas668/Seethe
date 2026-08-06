class_name DamageProfile
extends Resource

const CHANNEL_LETHAL: StringName = &"lethal"
const CHANNEL_NONLETHAL: StringName = &"nonlethal"

@export var dice_count: int = 1
@export var die_size: int = 4
@export var flat_bonus: int = 0
@export var damage_type: StringName = &"physical"
@export var damage_channel: StringName = CHANNEL_LETHAL


func notation() -> String:
	var result := "%dd%d" % [maxi(1, dice_count), maxi(2, die_size)]
	if flat_bonus > 0:
		result += "+%d" % flat_bonus
	elif flat_bonus < 0:
		result += "%d" % flat_bonus
	return result


func validate_profile(owner_id: StringName = &"") -> Array[String]:
	var errors: Array[String] = []
	if dice_count < 1:
		errors.append("Damage profile for %s has fewer than one die." % owner_id)
	if die_size < 2:
		errors.append("Damage profile for %s has an invalid die size." % owner_id)
	if damage_type.is_empty():
		errors.append("Damage profile for %s has no damage type." % owner_id)
	if damage_channel not in [CHANNEL_LETHAL, CHANNEL_NONLETHAL]:
		errors.append(
			"Damage profile for %s has unsupported channel %s."
			% [owner_id, damage_channel]
		)
	return errors
