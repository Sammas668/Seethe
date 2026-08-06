#!/usr/bin/env python3
import sys
from validation_common import *

def main() -> int:
    failures: list[str] = []
    for path in [
        "domain/campaign/campaign_state.gd", "domain/campaign/campaign_item_state.gd",
        "domain/campaign/campaign_item_location_state.gd", "application/campaign/campaign_item_validator.gd",
        "infrastructure/persistence/json_campaign_repository.gd",
    ]:
        require_file(path, failures)
    require_tokens("domain/campaign/campaign_state.gd", [
        "items_by_id", "items_for_character", "stronghold_storage_items", "upsert_item",
    ], failures)
    forbid_tokens("domain/characters/state/persistent_character_state.gd", ["loadout_entries"], failures)
    require_tokens("application/campaign/campaign_item_validator.gd", [
        "maximum_stack_size", "_validate_inventory_overlaps", "_validate_hand_conflicts",
        "LOCATION_STRONGHOLD_STORAGE", "LOCATION_CHARACTER_INVENTORY",
    ], failures)
    require_tokens("application/characters/character_resolution_service.gd", ["item_states", "_item_definitions"], failures)
    require_tokens("domain/campaign/campaign_state.gd", ["_migrate_legacy_loadouts"], failures)
    return finish("Stage 3.14", failures, ["CampaignState is the single authority for persistent item identity and location."])

if __name__ == "__main__":
    sys.exit(main())
