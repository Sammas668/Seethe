class_name CampaignResourceBalances
extends RefCounted

const RESOURCE_IDS: Array[StringName] = [
	&"wood",
	&"stone",
	&"metal",
	&"food",
	&"textiles",
	&"magic",
	&"gold",
]

const STORAGE_RESOURCE_IDS: Array[StringName] = [
	&"wood",
	&"stone",
	&"metal",
	&"food",
	&"textiles",
	&"magic",
]

const RESOURCE_STORAGE_UNITS_PER_SPACE: int = 100

var wood: int = 0
var stone: int = 0
var metal: int = 0
var food: int = 0
var textiles: int = 0
var magic: int = 0
var gold: int = 0


func amount(resource_id: StringName) -> int:
	match resource_id:
		&"wood":
			return wood
		&"stone":
			return stone
		&"metal":
			return metal
		&"food":
			return food
		&"textiles":
			return textiles
		&"magic":
			return magic
		&"gold":
			return gold
		_:
			return 0


func set_amount(resource_id: StringName, value: int) -> bool:
	var clean_value: int = maxi(0, value)
	match resource_id:
		&"wood":
			wood = clean_value
		&"stone":
			stone = clean_value
		&"metal":
			metal = clean_value
		&"food":
			food = clean_value
		&"textiles":
			textiles = clean_value
		&"magic":
			magic = clean_value
		&"gold":
			gold = clean_value
		_:
			return false
	return true


func add(resource_id: StringName, delta: int) -> bool:
	var next_value: int = amount(resource_id) + delta
	if next_value < 0:
		return false
	return set_amount(resource_id, next_value)


func storage_space_for(resource_id: StringName) -> int:
	if resource_id == &"gold" or not STORAGE_RESOURCE_IDS.has(resource_id):
		return 0
	var stored_amount: int = amount(resource_id)
	if stored_amount <= 0:
		return 0
	return ceili(float(stored_amount) / float(RESOURCE_STORAGE_UNITS_PER_SPACE))


func total_storage_space() -> int:
	var total: int = 0
	for resource_id: StringName in STORAGE_RESOURCE_IDS:
		total += storage_space_for(resource_id)
	return total


func storage_space_by_resource() -> Dictionary:
	var result: Dictionary = {}
	for resource_id: StringName in STORAGE_RESOURCE_IDS:
		result[resource_id] = storage_space_for(resource_id)
	return result


func validate_state() -> Array[String]:
	var errors: Array[String] = []
	for resource_id: StringName in RESOURCE_IDS:
		if amount(resource_id) < 0:
			errors.append("Campaign resource %s cannot be negative." % resource_id)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"wood": wood,
		"stone": stone,
		"metal": metal,
		"food": food,
		"textiles": textiles,
		"magic": magic,
		"gold": gold,
	}


static func from_dictionary(data: Dictionary) -> CampaignResourceBalances:
	var result := CampaignResourceBalances.new()
	for resource_id: StringName in RESOURCE_IDS:
		result.set_amount(resource_id, int(data.get(String(resource_id), 0)))
	return result
