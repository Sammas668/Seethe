class_name RegionDefinitionRegistry
extends RefCounted

var _definitions_by_id: Dictionary = {}
var _aliases: Dictionary = {}


func configure() -> Array[String]:
	_definitions_by_id.clear()
	_aliases.clear()
	var starter: RegionMapDefinition = LifeStarterRegionFactory.create_definition()
	if starter == null:
		return ["The authored starter Life region could not be loaded."]
	_definitions_by_id[starter.id] = starter
	for alias_id: StringName in starter.aliases:
		_aliases[alias_id] = starter.id
	return validate_registry()


func definition(region_id: StringName) -> RegionMapDefinition:
	var canonical_id: StringName = StringName(_aliases.get(region_id, region_id))
	return _definitions_by_id.get(canonical_id) as RegionMapDefinition


func site(region_id: StringName, site_id: StringName) -> RegionSiteDefinition:
	var region: RegionMapDefinition = definition(region_id)
	return region.site(site_id) if region != null else null


func validate_registry() -> Array[String]:
	var errors: Array[String] = []
	for raw_definition: Variant in _definitions_by_id.values():
		var definition: RegionMapDefinition = raw_definition as RegionMapDefinition
		if definition == null:
			errors.append("Region registry contains a missing definition.")
			continue
		errors.append_array(definition.validate_definition())
	return errors
