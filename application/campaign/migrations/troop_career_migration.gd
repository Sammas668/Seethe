class_name TroopCareerMigration
extends RefCounted

const REAVER_CAREER_ID: StringName = &"career.reaver"
const BARBARIAN_CLASS_ID: StringName = &"class.barbarian"
const REAVER_ARCHETYPE_ID: StringName = &"archetype.barbarian.reaver"
const MARAUDER_TEMPLATE_ID: StringName = &"character_template.reaver.marauder_tier_1"
const HENCHMAN_TEMPLATE_ID: StringName = &"character_template.reaver.barbarian_henchman"


static func migrate(campaign: CampaignState, catalogue: ContentCatalogue) -> bool:
	if campaign == null or catalogue == null:
		return false
	var changed := false
	var protagonist := campaign.get_character(campaign.protagonist_character_id)
	if protagonist != null:
		var protagonist_changed := false
		var protagonist_template := catalogue.character_template(protagonist.template_id)
		var protagonist_level := protagonist.resolved_level(protagonist_template) if protagonist_template != null else maxi(1, protagonist.level_adjustment + 1)
		if protagonist.base_class_id.is_empty():
			protagonist.base_class_id = BARBARIAN_CLASS_ID
			protagonist_changed = true
		if protagonist.class_rank(BARBARIAN_CLASS_ID) < protagonist_level:
			protagonist.class_ranks[BARBARIAN_CLASS_ID] = protagonist_level
			protagonist_changed = true
		if protagonist.archetype_rank(REAVER_ARCHETYPE_ID) < protagonist_level:
			protagonist.archetype_ranks[REAVER_ARCHETYPE_ID] = protagonist_level
			protagonist_changed = true
		if protagonist_changed:
			protagonist.revision += 1
			changed = true

	for character: PersistentCharacterState in campaign.get_characters():
		if character == protagonist or character.template_id not in [MARAUDER_TEMPLATE_ID, HENCHMAN_TEMPLATE_ID]:
			continue
		var template := catalogue.character_template(character.template_id)
		if template == null:
			continue
		var character_changed := false
		var level := character.resolved_level(template)
		if character.base_class_id.is_empty():
			character.base_class_id = BARBARIAN_CLASS_ID
			character_changed = true
		if character.class_rank(BARBARIAN_CLASS_ID) < level:
			character.class_ranks[BARBARIAN_CLASS_ID] = level
			character_changed = true
		if character.career_id.is_empty():
			character.career_id = REAVER_CAREER_ID
			character_changed = true
		if character.base_henchman_type_id.is_empty():
			character.base_henchman_type_id = &"troop.reaver.barbarian_henchman"
			character_changed = true
		if character.template_id == MARAUDER_TEMPLATE_ID:
			if character.current_troop_type_id.is_empty():
				character.current_troop_type_id = &"troop.reaver.marauder"
				character_changed = true
			if character.troop_tier < 1:
				character.troop_tier = 1
				character_changed = true
			if not character.completed_prestige_stage_ids.has(&"prestige.reaver.marauder"):
				character.completed_prestige_stage_ids.append(&"prestige.reaver.marauder")
				character_changed = true
			if character.active_tier_starting_feat_ids.is_empty():
				character.active_tier_starting_feat_ids = template.tier_starting_feat_ids.duplicate()
				character_changed = true
			if character.active_tier_starting_feat_parameters.is_empty():
				for feat_id: StringName in template.tier_starting_feat_ids:
					if template.feature_parameters.has(feat_id):
						var value: Variant = template.feature_parameters[feat_id]
						character.active_tier_starting_feat_parameters[feat_id] = value.duplicate(true) if value is Dictionary else value
				character_changed = true
		elif character.current_troop_type_id.is_empty():
			character.current_troop_type_id = &"troop.reaver.barbarian_henchman"
			character_changed = true
		if character_changed:
			character.revision += 1
			changed = true
	if changed:
		campaign.revision += 1
	return changed
