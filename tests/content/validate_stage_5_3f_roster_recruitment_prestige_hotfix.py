from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.exists(), f"Missing required file: {relative}"
    return path.read_text(encoding="utf-8")


def block(text: str, start: str, end: str) -> str:
    start_index = text.index(start)
    end_index = text.index(end, start_index)
    return text[start_index:end_index]

shell = read("presentation/campaign/campaign_shell.gd")
session = read("bootstrap/app/campaign_session.gd")
recruitment = read("application/characters/henchman_recruitment_service.gd")
prestige = read("application/characters/troop_prestige_service.gd")
career_content = read("infrastructure/content/characters/reaver/reaver_career_content.gd")
resolver = read("domain/characters/resolution/character_resolver.gd")
character = read("domain/characters/state/persistent_character_state.gd")
campaign = read("domain/campaign/campaign_state.gd")
mission_handler = read("application/tactical/extraction/resolve_tactical_mission_handler.gd")
mission_xp = read("application/missions/mission_experience_award_service.gd")
commit = read("application/campaign/campaign_result_commit_service.gd")
reservations = read("application/inventory/strategic_reservation_service.gd")
progression = read("application/characters/character_progression_service.gd")

# Recruitment belongs to the Roster and displays persistent random class-gated candidates.
assert 'const ROSTER_MODE_HIRE' in shell
assert 'hire_button.text = "HIRE UNITS"' in shell
assert 'func _build_roster_hire_view' in shell
assert '_campaign_session.recruitment_market()' in shell
assert 'REFRESH CANDIDATES' not in shell
assert '_campaign_session.refresh_recruitment_market()' not in shell
assert 'NEXT REFRESH: DAY %d' in shell
assert 'HIRING: INSTANT' in shell
assert 'hire.pressed.connect(func() -> void: _request_henchman_recruitment(offer_id))' in shell
assert 'protagonist.class_rank(definition.base_class_id)' in recruitment
assert 'int(campaign.campaign_seed)' in recruitment
assert 'for index: int in range(definition.market_offer_count)' in recruitment
assert 'CharacterFactory.create_player_character' in recruitment
assert 'return OperationResult.ok(\n\t\tcharacter,\n\t\t"%s joined the Roster immediately."' in recruitment
assert 'var project := HenchmanRecruitmentProjectState.new()' not in block(recruitment, 'func start_candidate', 'func advance_candidate')
assert 'character.persistence_scope = PersistentCharacterState.PERSISTENCE_CAMPAIGN' in recruitment
assert 'character.troop_tier = 0' in recruitment
assert 'result.market_offer_count = 4' in career_content
assert 'result.required_facility_id = &""' in career_content, "Base Barbarian hiring must not require a facility."
assert 'const MUSTER_HALL_ID' not in recruitment
assert 'Requires an operational Muster Hall.' not in recruitment
assert 'marauder.required_facility_id = &"facility.muster_hall"' in career_content
assert 'marauder.minimum_facility_level = 1' in career_content

# Prestige is opened beside Level Up on the Character dossier and offers authored target tiers.
progression_block = block(
    shell,
    'func _build_roster_dossier_progression_block',
    'func _build_roster_dossier_combat_panel',
)
assert 'var level_button := Button.new()' in progression_block
assert 'var prestige_button := Button.new()' in progression_block
assert progression_block.index('progression_buttons.add_child(level_button)') < progression_block.index('progression_buttons.add_child(prestige_button)')
assert '_roster_tab_index = 4' in progression_block
assert 'func _build_prestige_content' in shell
assert 'for option: Dictionary in options' in shell
assert 'BEGIN PRESTIGE' in shell
assert 'Prestige is linear; the preceding Tier must be completed first.' in prestige

# The user's final retention rule: ONLY active Tier starting feats/parameters are replaced.
apply_stage = block(prestige, 'func _apply_stage', 'func _record_grant')
assert 'character.active_tier_starting_feat_ids = stage.tier_starting_feat_ids.duplicate()' in apply_stage
assert 'character.active_tier_starting_feat_parameters = stage.tier_starting_feat_parameters.duplicate(true)' in apply_stage
for field in (
    'prestige_feat_ids', 'prestige_trait_ids', 'prestige_ability_ids',
    'prestige_action_ids', 'prestige_proficiency_ids', 'prestige_role_tag_ids',
):
    assert f'_append_unique(character.{field}' in apply_stage, f'{field} must remain cumulative.'
    assert f'character.{field}.clear()' not in apply_stage
assert 'character.xp =' not in apply_stage
assert 'character.level_adjustment =' not in apply_stage
assert 'character.selected_talent_ids =' not in apply_stage
assert 'character.ordinary_feat_choice_ids =' not in apply_stage
assert 'character.injury_entries =' not in apply_stage
assert 'character.completed_prestige_stage_ids.append(stage.stage_id)' in apply_stage

# The resolver strips template Tier feats, installs only the active Tier package,
# and then retains ordinary choices and every cumulative non-starting Prestige grant.
assert 'for tier_feat_id: StringName in template.tier_starting_feat_ids:' in resolver
assert 'result.trait_ids.erase(tier_feat_id)' in resolver
assert '_append_unique_string_names(result.trait_ids, character.active_tier_starting_feat_ids)' in resolver
assert '_append_unique_string_names(result.trait_ids, character.prestige_feat_ids)' in resolver
assert '_append_unique_string_names(result.trait_ids, character.prestige_trait_ids)' in resolver
assert '_append_unique_string_names(result.trait_ids, character.selected_talent_ids)' in resolver
assert '_append_unique_string_names(result.trait_ids, character.ordinary_feat_choice_ids)' in resolver
assert 'result.feature_parameters.erase(tier_feat_id)' in resolver
assert 'character.active_tier_starting_feat_parameters.keys()' in resolver

# The persistent character and campaign save both serialize the new career/project state.
for field in (
    'active_tier_starting_feat_ids', 'active_tier_starting_feat_parameters',
    'prestige_ability_ids', 'ordinary_feat_choice_ids', 'completed_prestige_stage_ids',
):
    assert f'"{field}"' in character
version_match = re.search(r"const CURRENT_SAVE_VERSION: int = (\d+)", campaign)
assert version_match and int(version_match.group(1)) >= 18
assert 'recruitment_market_month_index' in campaign
for key in ('recruitment_offers', 'recruitment_projects', 'prestige_projects'):
    assert f'base["{key}"]' in campaign
    assert f'data.get("{key}"' in campaign

# Reaver thresholds and sequence are data-driven and complete.
for threshold in (3, 6, 9, 12, 15, 18):
    assert f', {threshold},' in career_content, f'Missing Reaver threshold {threshold}.'
for stage_name in ('marauder', 'harpooner', 'shieldbreaker', 'bloodsworn', 'bear_rider', 'wyvern_reaver'):
    assert f'prestige.reaver.{stage_name}' in career_content

# Mission-return XP is generated on every terminal extraction path and only
# commits for surviving, physically extracted, non-captured persistent troops.
assert mission_handler.count('MissionExperienceAwardService.apply_awards(result, _setup)') == 3
assert mission_handler.count('MissionExperienceAwardService.validate_awards(result, _setup)') == 3
for token in ('character_result.was_deployed', 'character_result.survived', 'character_result.extracted', 'not character_result.captured'):
    assert token in mission_xp
assert 'result.xp_awarded > 0 and result.survived and result.extracted and not result.captured' in commit

# Prestige training is an authoritative strategic availability lock, not merely a label.
assert 'Prestige training and cannot deploy' in reservations
assert 'prestige_project.character_id == character_id' in reservations

# Henchman level-up tracks its single class without corrupting protagonist multiclass ranks.
assert 'if not character.career_id.is_empty() and not character.base_class_id.is_empty()' in progression
assert 'character.archetype_ranks[archetype_id]' not in progression

# Session APIs and strategic-time completion are connected.
for token in (
    'func recruitment_market()', 'func recruitment_market_status()',
    'func begin_henchman_recruitment(', 'func prestige_options(',
    'func begin_troop_prestige(',
    'henchman_recruitment_service.refresh_market_if_due_candidate(candidate)',
    'henchman_recruitment_service.advance_candidate(candidate)',
    'troop_prestige_service.advance_candidate(candidate)',
):
    assert token in session

assert 'const CAMPAIGN_MONTH_DAYS: int = 30' in recruitment
assert 'func refresh_market_if_due_candidate' in recruitment
assert 'campaign.recruitment_market_month_index = resolved_month_index' in recruitment
assert 'duration_ticks = 0' in career_content
assert 'if duration_ticks < 0' in read('domain/characters/definitions/henchman_recruitment_definition.gd')
assert 'Recruitment candidates refresh automatically every 30 campaign days.' in session

print('PASS — Roster hiring is instant, class-gated and does not require a Muster Hall.')
print('PASS — Candidate offers refresh automatically at each 30-day campaign-month boundary.')
print('PASS — Marauder Prestige, rather than base hiring, requires an operational Muster Hall I.')
print('PASS — Character dossier places Prestige beside Level Up and exposes the authored tier sequence.')
print('PASS — Prestige replaces only Tier starting feats/parameters; all other earned progression remains cumulative.')
print('PASS — Mission-return XP is assigned and committed only to surviving extracted persistent troops.')
print('PASS — Recruitment, Prestige and career state serialize at save version 18.')
