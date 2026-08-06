class_name ReaverCareerContent
extends RefCounted

const CAREER_ID: StringName = &"career.reaver"
const RECRUITMENT_ID: StringName = &"recruitment.barbarian_henchman.reaver"
const BASE_TEMPLATE_ID: StringName = &"character_template.reaver.barbarian_henchman"


static func career_definition() -> TroopCareerDefinition:
	var result := TroopCareerDefinition.new()
	result.career_id = CAREER_ID
	result.base_class_id = &"class.barbarian"
	result.archetype_id = &"archetype.barbarian.reaver"
	result.base_henchman_type_id = &"troop.reaver.barbarian_henchman"
	result.base_recruitment_definition_id = RECRUITMENT_ID
	result.signature_facility_id = &"facility.reaver_warcamp"
	result.display_name = "Reaver"
	result.description = "A named veteran's linear raiding career. Levels and all earned features remain; only the active Tier's starting feats are replaced at Prestige."
	result.stage_ids = [
		&"prestige.reaver.marauder", &"prestige.reaver.harpooner",
		&"prestige.reaver.shieldbreaker", &"prestige.reaver.bloodsworn",
		&"prestige.reaver.bear_rider", &"prestige.reaver.wyvern_reaver",
	]
	return result


static func recruitment_definition() -> HenchmanRecruitmentDefinition:
	var result := HenchmanRecruitmentDefinition.new()
	result.recruitment_id = RECRUITMENT_ID
	result.base_class_id = &"class.barbarian"
	result.career_id = CAREER_ID
	result.resulting_character_template_id = BASE_TEMPLATE_ID
	result.display_name = "Barbarian Henchman"
	result.description = "A random named Level 1 Barbarian recruit whose Reaver career can be developed in the Roster."
	result.starting_level = 1
	result.starting_xp = 0
	result.required_protagonist_class_level = 1
	result.required_facility_id = &""
	result.resource_costs = {&"gold": 35, &"food": 10}
	result.starting_loadout_id = &"loadout.barbarian_henchman.basic"
	result.duration_ticks = 0
	result.roster_capacity_cost = 1
	result.market_offer_count = 4
	result.name_pool_id = &"name_pool.reaver.human"
	result.portrait_pool_id = &"portrait_pool.reaver.henchman"
	return result


static func prestige_stages() -> Array[TroopPrestigeStageDefinition]:
	var result: Array[TroopPrestigeStageDefinition] = []
	var marauder := _stage(
		&"prestige.reaver.marauder", 1, 3,
		&"troop.reaver.barbarian_henchman", &"troop.reaver.marauder",
		"Marauder", "Raiding, nonlethal capture and burden extraction.",
		[&"trait.take_them_alive", &"trait.raiders_burden"],
		[], [], [],
		[&"marauder", &"capture_specialist", &"loot_extractor"],
		[],
		{}, &"role", &"", 1, 720, {&"gold": 25, &"food": 5}
	)
	marauder.tier_starting_feat_parameters = {
		&"trait.take_them_alive": {"nonlethal_penalty_offset": 4, "restrain_cost": &"quick", "requires_blunt_melee": true},
		&"trait.raiders_burden": {"carrying_strength_bonus": 4, "secured_burden_limit": 1, "maximum_secured_size": &"medium"},
	}
	# Base Barbarian henchmen can be hired without infrastructure. The Muster Hall
	# is the organisational gate that turns a trained Level 3 henchman into a Marauder.
	marauder.required_facility_id = &"facility.muster_hall"
	marauder.minimum_facility_level = 1
	result.append(marauder)
	result.append(_stage(
		&"prestige.reaver.harpooner", 2, 6,
		&"troop.reaver.marauder", &"troop.reaver.harpooner",
		"Harpooner", "Ranged restraint, pulling and forced movement.",
		[&"feat.heaving_cast", &"feat.binding_line"],
		[&"ability.ranged_grapple", &"ability.haul_hooked_target", &"ability.overpower_the_line"],
		[&"proficiency.harpoon"], [],
		[&"harpooner", &"control_specialist", &"ranged_capture"],
		["Ranged Grapple — begin a restraint attempt using a barbed harpoon.", "Haul Hooked Target — pull a hooked target toward the Harpooner.", "Overpower the Line — contest escape and movement along a secured line."],
		{}, &"role", &"", 1, 1080, {&"gold": 45, &"metal": 4}
	))
	result.append(_stage(
		&"prestige.reaver.shieldbreaker", 3, 9,
		&"troop.reaver.harpooner", &"troop.reaver.shieldbreaker",
		"Shieldbreaker", "Breaching, anti-armour pressure and formation disruption.",
		[&"feat.breach_training", &"feat.formation_cracker"],
		[&"ability.shatter_guard", &"ability.break_the_line"],
		[&"proficiency.breaching_weapons"], [],
		[&"shieldbreaker", &"breach_specialist", &"anti_armour"],
		["Shatter Guard — punish armour, shields and defensive stances.", "Break the Line — disrupt a defended formation and open a route."],
		{}, &"role", &"", 2, 1440, {&"gold": 70, &"metal": 8}
	))
	result.append(_stage(
		&"prestige.reaver.bloodsworn", 4, 12,
		&"troop.reaver.shieldbreaker", &"troop.reaver.bloodsworn",
		"Bloodsworn", "Elite shock assault and violent momentum.",
		[&"feat.bloodsworn_dual_wield", &"feat.oath_fuelled_assault"],
		[&"ability.violent_momentum", &"ability.blood_oath_assault"],
		[&"proficiency.reaver_twin_axes"], [],
		[&"bloodsworn", &"shock_assault", &"dual_wield"],
		["Violent Momentum — continue offensive pressure after a successful assault.", "Blood-Oath Assault — commit to a powerful paired-axe shock attack."],
		{}, &"role", &"", 2, 2160, {&"gold": 110, &"metal": 12, &"magic": 2}
	))
	result.append(_stage(
		&"prestige.reaver.bear_rider", 5, 15,
		&"troop.reaver.bloodsworn", &"troop.reaver.bear_rider",
		"Bear Rider", "Mounted disruption, pursuit and heavy-body interaction.",
		[&"feat.mounted_reaver", &"feat.saddle_butcher"],
		[&"ability.bear_charge", &"ability.mauling_pursuit"],
		[&"proficiency.war_bear"], [],
		[&"bear_rider", &"mounted", &"pursuit"],
		["Bear Charge — mounted disruption with the combined rider-and-mount body.", "Mauling Pursuit — pressure fleeing or displaced enemies."],
		{}, &"mounted", &"companion.reaver.war_bear", 3, 2880, {&"gold": 180, &"food": 30, &"magic": 3}
	))
	result.append(_stage(
		&"prestige.reaver.wyvern_reaver", 6, 18,
		&"troop.reaver.bear_rider", &"troop.reaver.wyvern_reaver",
		"Wyvern Reaver", "Aerial assault, vertical mobility and rapid extraction.",
		[&"feat.aerial_reaver", &"feat.sky_reaver"],
		[&"ability.wyvern_dive", &"ability.aerial_extraction", &"ability.vertical_assault"],
		[&"proficiency.wyvern_mount"], [],
		[&"wyvern_reaver", &"aerial", &"rapid_extraction"],
		["Wyvern Dive — descending aerial shock assault.", "Aerial Extraction — remove a secured burden through vertical movement.", "Vertical Assault — attack routes unavailable to ordinary ground troops."],
		{}, &"mounted", &"companion.reaver.wyvern", 3, 4320, {&"gold": 300, &"food": 45, &"magic": 8}
	))
	return result


static func _stage(
		stage_id: StringName, tier: int, minimum_level: int,
		source_type: StringName, resulting_type: StringName,
		display_name: String, description: String,
		starting_feats: Array[StringName], abilities: Array[StringName],
		proficiencies: Array[StringName], traits: Array[StringName],
		role_tags: Array[StringName], ability_entries: Array[String],
		stats: Dictionary, transition: StringName, companion: StringName,
		facility_level: int, duration: int, costs: Dictionary
) -> TroopPrestigeStageDefinition:
	var result := TroopPrestigeStageDefinition.new()
	result.stage_id = stage_id
	result.career_id = CAREER_ID
	result.stage_index = tier
	result.troop_tier = tier
	result.minimum_character_level = minimum_level
	result.source_troop_type_id = source_type
	result.resulting_troop_type_id = resulting_type
	result.display_name = display_name
	result.description = description
	result.tier_starting_feat_ids = starting_feats
	result.granted_ability_ids = abilities
	result.granted_proficiency_ids = proficiencies
	result.granted_trait_ids = traits
	result.granted_role_tags = role_tags
	result.ability_entries = ability_entries
	result.permanent_stat_adjustments = stats
	result.transition_type = transition
	result.resulting_companion_definition_id = companion
	result.required_facility_id = &"facility.reaver_warcamp"
	result.minimum_facility_level = facility_level
	result.required_protagonist_class_id = &"class.barbarian"
	result.minimum_protagonist_class_level = minimum_level
	result.required_protagonist_archetype_id = &"archetype.barbarian.reaver"
	result.minimum_protagonist_archetype_rank = minimum_level
	result.duration_ticks = duration
	result.resource_costs = costs
	return result
