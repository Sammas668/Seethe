#!/usr/bin/env python3
import sys
from validation_common import *

def main() -> int:
    failures: list[str] = []
    for path in [
        "application/campaign/ports/campaign_repository.gd",
        "infrastructure/persistence/json_campaign_repository.gd",
        "application/tactical/transactions/tactical_change_set.gd",
        "application/tactical/transactions/tactical_mutation_step.gd",
        "application/tactical/transactions/tactical_validation_rule.gd",
        "application/tactical/tactical_state_store.gd",
        "application/missions/mission_result_validator.gd",
    ]:
        require_file(path, failures)
    require_tokens("infrastructure/persistence/json_campaign_repository.gd", [
        "temporary_path", "backup_path", "_preserve_corrupt_file", "Temporary campaign save failed verification",
        "will not be overwritten", "DirAccess.rename_absolute",
    ], failures)
    require_tokens("application/campaign/campaign_result_commit_service.gd", [
        "campaign.revision != result.source_campaign_revision", "MissionResultValidator.validate",
        "has_applied_result", "CAMPAIGN_CHANGE_SET_SCRIPT",
    ], failures)
    require_tokens("application/tactical/tactical_state_store.gd", [
        "change_set.execute(_state, map_definition)", "change_set.publish_post_commit()", "state_changed.emit",
    ], failures)
    require_tokens("application/tactical/transactions/tactical_change_set.gd", [
        "Array[TacticalMutationStep]", "Array[TacticalValidationRule]", "state.validate_all", "_rollback",
    ], failures)
    forbid_tokens("application/tactical/tactical_state_store.gd", ["notify_changed"], failures)
    return finish("Stage 3.15", failures, ["Save replacement and tactical commits are validated and rollback-capable."])

if __name__ == "__main__":
    sys.exit(main())
