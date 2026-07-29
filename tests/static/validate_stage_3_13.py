#!/usr/bin/env python3
import sys
from validation_common import *

def main() -> int:
    failures: list[str] = []
    for path in [
        "application/missions/mission_setup_builder.gd", "domain/missions/mission_setup_snapshot.gd",
        "domain/missions/mission_result.gd", "application/missions/mission_result_builder.gd",
        "application/missions/mission_result_validator.gd", "application/campaign/campaign_result_commit_service.gd",
        "bootstrap/debug/tactical_sandbox_factory.gd",
    ]:
        require_file(path, failures)
    forbid_tokens("domain/missions/mission_setup_snapshot.gd", ["CharacterFactory", "application/"], failures)
    require_tokens("application/missions/mission_setup_builder.gd", [
        "create_from_campaign", "add_isolated_character", "CharacterFactory.create_default_item_states",
    ], failures)
    require_tokens("domain/missions/mission_setup_snapshot.gd", [
        "deployed_character_ids", "mark_deployed", "was_deployed", "get_deployed_character_ids",
    ], failures)
    require_tokens("application/characters/tactical_character_deployment_service.gd", [
        "prepare_deployment", "commit_deployment", "shallow_copy_for_assembly_validation", "Character deployed atomically",
    ], failures)
    require_absent("application/characters/tactical_character_persistence_service.gd", failures)
    return finish("Stage 3.13", failures, ["Tactical missions use isolated setup state and explicit results."])

if __name__ == "__main__":
    sys.exit(main())
