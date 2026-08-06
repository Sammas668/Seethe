class_name Stage51aRegionTests
extends RefCounted


static func run() -> Array[String]:
	var failures: Array[String] = []
	var definition: RegionMapDefinition = LifeStarterRegionFactory.create_definition()
	_expect(definition != null, "Authored starter region failed to load.", failures)
	if definition == null:
		return failures
	_expect(definition.width == 20 and definition.height == 15, "Starter region dimensions changed.", failures)
	_expect(definition.all_hexes().size() == 300, "Starter region does not contain 300 hexes.", failures)
	_expect(definition.all_road_edges().size() == 304, "Corrected public-road edge transcription changed.", failures)
	_expect(definition.all_border_edges().size() == 79, "Corrected subregion-border edge transcription changed.", failures)

	var settlements: int = 0
	for site: RegionSiteDefinition in definition.all_sites():
		if site.site_type == &"settlement":
			settlements += 1
	_expect(settlements == 14, "Starter region does not contain fourteen settlements.", failures)

	_expect_footprint(
		definition.site(&"site.settlement.telluria"),
		[Vector2i(9, 6), Vector2i(8, 6), Vector2i(10, 6), Vector2i(9, 7), Vector2i(8, 7), Vector2i(10, 7), Vector2i(9, 8)],
		"Telluria",
		failures
	)
	_expect_footprint(
		definition.site(&"site.settlement.westmarch"),
		[Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 5)],
		"Westmarch",
		failures
	)
	_expect_footprint(
		definition.site(&"site.settlement.solis"),
		[Vector2i(16, 3), Vector2i(16, 4), Vector2i(17, 4)],
		"Solis",
		failures
	)
	_expect_footprint(
		definition.site(&"site.settlement.oakstead"),
		[Vector2i(12, 11), Vector2i(11, 12), Vector2i(12, 12)],
		"Oakstead",
		failures
	)

	var stronghold: RegionSiteDefinition = definition.site(definition.fifth_god_ruin_site_id)
	var ancient_ruin: RegionSiteDefinition = definition.site(&"site.wilderness.deep_forest_ruins")
	_expect(stronghold != null, "Fifth-God stronghold is missing.", failures)
	_expect(ancient_ruin != null and ancient_ruin.site_type == &"ruin", "Separate ancient forest ruin is missing.", failures)
	if stronghold != null:
		var stronghold_hex: RegionHexDefinition = definition.hex_at_offset(
			stronghold.coord.offset_col,
			stronghold.coord.offset_row
		)
		_expect(
			stronghold_hex != null and stronghold_hex.terrain_type == RegionTerrainType.DEEP_FOREST,
			"Fifth-God stronghold is not inside authored deep forest.",
			failures
		)
		for road_edge: RegionMapEdgeDefinition in definition.all_road_edges():
			_expect(
				not road_edge.touches_offset(stronghold.coord.offset_col, stronghold.coord.offset_row),
				"A visible public road touches the Fifth-God stronghold.",
				failures
			)
	if stronghold != null and ancient_ruin != null:
		_expect(
			stronghold.coord.key() != ancient_ruin.coord.key(),
			"Stronghold and ancient forest ruin share one hex.",
			failures
		)

	for road_edge: RegionMapEdgeDefinition in definition.all_road_edges():
		_expect(road_edge.style_id in RegionRoadType.ALL, "Road edge %s has an invalid road style." % road_edge.id, failures)

	var registry := RegionDefinitionRegistry.new()
	var registry_errors: Array[String] = registry.configure()
	_expect(registry_errors.is_empty(), "Region registry failed validation.", failures)
	_expect(
		registry.definition(&"region.life.verdant_march") == definition
		or registry.definition(&"region.life.verdant_march") != null,
		"Legacy Stage 5.0 region alias was not preserved.",
		failures
	)
	var session := CampaignSession.new()
	session.configure("user://stage_5_1a_region_tests.json")
	session.repository.clear_save()
	var created: OperationResult = session.create_new_campaign(5101)
	_expect(created.success, "New campaign failed for Stage 5.1a: %s" % created.message, failures)
	if created.success:
		var campaign: CampaignState = session.current_campaign()
		_expect(campaign.current_region_id == &"region.life.starter", "New campaign does not use the authored starter region.", failures)
		_expect(
			campaign.first_actionable_mission() == null,
			"Farm Raid should remain hidden until the Agent discovers it.",
			failures
		)
		var agent: AgentState = session.primary_agent()
		_expect(agent != null, "Starter region has no campaign Agent.", failures)
		if agent != null:
			_expect(
				agent.current_hex.key() == stronghold.coord.key(),
				"Starter Agent is not located at the Fifth-God stronghold.",
				failures
			)
	session.repository.clear_save()
	return failures


static func _expect_footprint(
	site: RegionSiteDefinition,
	expected: Array[Vector2i],
	label: String,
	failures: Array[String]
) -> void:
	_expect(site != null, "%s settlement is missing." % label, failures)
	if site == null:
		return
	var actual: Dictionary = {}
	for coord: RegionHexCoord in site.footprint:
		actual[Vector2i(coord.offset_col, coord.offset_row)] = true
	_expect(actual.size() == expected.size(), "%s has the wrong footprint size." % label, failures)
	for expected_coord: Vector2i in expected:
		_expect(actual.has(expected_coord), "%s footprint is missing %s." % [label, expected_coord], failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
