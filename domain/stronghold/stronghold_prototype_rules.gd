class_name StrongholdPrototypeRules
extends RefCounted

var open_grid: bool = true
var unlock_all_facilities: bool = true
var unlock_all_upgrades: bool = true
var ignore_construction_costs: bool = true
var instant_construction: bool = false
var instant_upgrades: bool = false


static func enabled_defaults() -> StrongholdPrototypeRules:
	return StrongholdPrototypeRules.new()
