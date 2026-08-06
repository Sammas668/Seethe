class_name RegionSymbolCatalogue
extends RefCounted

const WHEAT_WAREHOUSE: StringName = &"district_wheat_warehouse"
const LUMBERMILL: StringName = &"district_lumbermill"
const TEXTILES_WAREHOUSE: StringName = &"district_textiles_warehouse"
const CRAFTSMANS_DISTRICT: StringName = &"district_craftsmans_district"
const GUILD_HOUSE: StringName = &"district_guild_house"
const NOBLE_HOUSING: StringName = &"district_noble_housing"
const TOWN_CENTRE: StringName = &"settlement_town_centre"
const VILLAGE_CENTRE: StringName = &"settlement_village_centre"
const HAMLET: StringName = &"settlement_hamlet"
const TEMPLE: StringName = &"district_temple"
const MARKET: StringName = &"district_market"
const FARM_ESTATE: StringName = &"district_farm_estate"

const FIFTH_GOD_STRONGHOLD: StringName = &"site_fifth_god_stronghold"
const ANCIENT_RUIN: StringName = &"site_ancient_ruin"
const FARM: StringName = &"site_farm"
const STOREHOUSE: StringName = &"site_storehouse"
const RELIGIOUS_SITE: StringName = &"site_religious"
const MILITARY_SITE: StringName = &"site_military"
const WILDERNESS_SITE: StringName = &"site_wilderness"

const _DEFINITIONS: Dictionary = {
	WHEAT_WAREHOUSE: {"display_name": "Wheat Warehouse", "category": "district"},
	LUMBERMILL: {"display_name": "Lumbermill", "category": "district"},
	TEXTILES_WAREHOUSE: {"display_name": "Textiles Warehouse", "category": "district"},
	CRAFTSMANS_DISTRICT: {"display_name": "Craftsman's District", "category": "district"},
	GUILD_HOUSE: {"display_name": "Guild House", "category": "district"},
	NOBLE_HOUSING: {"display_name": "Noble Housing", "category": "district"},
	TOWN_CENTRE: {"display_name": "Town Centre", "category": "district"},
	VILLAGE_CENTRE: {"display_name": "Village Centre", "category": "district"},
	HAMLET: {"display_name": "Hamlet", "category": "district"},
	TEMPLE: {"display_name": "Temple", "category": "district"},
	MARKET: {"display_name": "Market", "category": "district"},
	FARM_ESTATE: {"display_name": "Farm Estate", "category": "district"},
	FIFTH_GOD_STRONGHOLD: {"display_name": "Fifth-God Stronghold", "category": "site"},
	ANCIENT_RUIN: {"display_name": "Ancient Ruin", "category": "site"},
	FARM: {"display_name": "Farm", "category": "site"},
	STOREHOUSE: {"display_name": "Storehouse", "category": "site"},
	RELIGIOUS_SITE: {"display_name": "Religious Site", "category": "site"},
	MILITARY_SITE: {"display_name": "Military Site", "category": "site"},
	WILDERNESS_SITE: {"display_name": "Wilderness Site", "category": "site"},
}


static func is_valid(symbol_id: StringName) -> bool:
	return _DEFINITIONS.has(symbol_id)


static func display_name(symbol_id: StringName) -> String:
	var definition: Dictionary = _DEFINITIONS.get(symbol_id, {}) as Dictionary
	return String(definition.get("display_name", symbol_id))


static func category(symbol_id: StringName) -> StringName:
	var definition: Dictionary = _DEFINITIONS.get(symbol_id, {}) as Dictionary
	return StringName(definition.get("category", ""))


static func district_symbols() -> Array[StringName]:
	return [
		WHEAT_WAREHOUSE,
		LUMBERMILL,
		TEXTILES_WAREHOUSE,
		CRAFTSMANS_DISTRICT,
		GUILD_HOUSE,
		NOBLE_HOUSING,
		TOWN_CENTRE,
		VILLAGE_CENTRE,
		HAMLET,
		TEMPLE,
		MARKET,
		FARM_ESTATE,
	]


static func site_symbols() -> Array[StringName]:
	return [
		FIFTH_GOD_STRONGHOLD,
		ANCIENT_RUIN,
		FARM,
		STOREHOUSE,
		RELIGIOUS_SITE,
		MILITARY_SITE,
		WILDERNESS_SITE,
	]
