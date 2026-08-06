#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    for path in [
        "application/campaign/campaign_state_store.gd",
        "application/campaign/transactions/campaign_change_set.gd",
        "domain/characters/resolution/resolved_equipment_input.gd",
        "tests/integration/stage_3_17_combat_foundation_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "application/campaign/campaign_state_store.gd",
        [
            "CampaignState.from_dictionary",
            "candidate.validate_campaign()",
            "save_campaign",
            "_campaign = candidate",
            "candidate.revision = expected_revision + 1",
        ],
        failures,
    )
    require_tokens(
        "application/campaign/campaign_result_commit_service.gd",
        [
            "CAMPAIGN_CHANGE_SET_SCRIPT",
            "_state_store.call(\"commit\"",
            "_apply_result_to_candidate",
        ],
        failures,
    )
    forbid_tokens(
        "application/campaign/campaign_result_commit_service.gd",
        ["restore_from_dictionary", "save_campaign(campaign)"],
        failures,
    )
    require_tokens(
        "domain/missions/mission_setup_snapshot.gd",
        [
            "var _finalized: bool",
            "func finalize()",
            "if _finalized:",
            "func is_finalized()",
            "_canonical_dictionary",
        ],
        failures,
    )
    require_tokens(
        "application/missions/mission_setup_builder.gd",
        ["finalize_setup", "mark_intended_participants"],
        failures,
    )
    require_tokens(
        "application/characters/character_resolution_service.gd",
        [
            "RESOLVED_EQUIPMENT_INPUT_SCRIPT",
            "_equipment_inputs",
            "persistent_modifiers",
            "condition",
            "equipped",
            "carried",
        ],
        failures,
    )
    forbid_tokens(
        "application/characters/character_resolution_service.gd",
        ["seen_ids.has(definition_id)"],
        failures,
    )
    require_tokens(
        "domain/characters/resolution/character_resolver.gd",
        [
            "_resolve_equipment_manifest",
            "_append_equipment_stat_modifiers",
            "result.equipped_item_ids",
            "definition.defence_profile_id",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "ResolvedCharacterSnapshot is the sole combat authority for Armour Class",
            "armour_class = snapshot.stat_value(&\"armour_class\"",
        ],
        failures,
    )
    require_tokens(
        "domain/characters/state/persistent_character_state.gd",
        ["Stage 3 compatibility fallback. Real equipped armour items override this."],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)
    return finish(
        "Stage 3.17",
        failures,
        [
            "Campaign changes validate and save a candidate before replacing the active root.",
            "Mission setup becomes immutable before deployment.",
            "Character resolution preserves item-instance equipment data and one AC authority.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
