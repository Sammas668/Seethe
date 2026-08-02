#!/usr/bin/env python3
"""Validate Hotfix 5b legacy Marauder loadout and Raider's Sack migration."""
from __future__ import annotations

import argparse
from pathlib import Path


def read(root: Path, relative: str, errors: list[str]) -> str:
    path = root / relative
    if not path.is_file():
        errors.append(f"Missing {relative}.")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def require(text: str, fragments: list[str], label: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{label} is missing required contract: {fragment}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path("."))
    args = parser.parse_args()
    root = args.project.resolve()
    errors: list[str] = []

    migration = read(
        root,
        "application/campaign/migrations/marauder_loadout_migration.gd",
        errors,
    )
    repository = read(
        root,
        "infrastructure/persistence/json_campaign_repository.gd",
        errors,
    )
    validator = read(
        root,
        "application/campaign/campaign_item_validator.gd",
        errors,
    )
    sandbox = read(root, "bootstrap/debug/tactical_sandbox_factory.gd", errors)
    authored = read(root, "bootstrap/debug/authored_mission_factory.gd", errors)
    runtime = read(
        root,
        "tests/integration/stage_4_7_hotfix_5_marauder_mechanics_tests.gd",
        errors,
    )

    require(migration, [
        "class_name MarauderLoadoutMigration",
        "static func repair_existing_marauders",
        "static func repair_character",
        '&"item.reinforced_captive_carrying_belt"',
        '&"item.raiders_sack"',
        "CampaignItemLocationState.CONTAINER_PRIMARY_HAND",
        "CampaignItemLocationState.CONTAINER_ARMOUR",
        "CampaignItemLocationState.CONTAINER_BELT",
        "Vector2i(5, 0)",
    ], "Marauder loadout migration", errors)
    require(repository, [
        "MarauderLoadoutMigration.repair_existing_marauders",
        '"migrated": migrated',
        "if _loaded_save_was_migrated and current_campaign != null:",
        "save_campaign(current_campaign)",
    ], "Campaign repository migration", errors)
    require(validator, [
        "CampaignItemLocationState.CONTAINER_ARMOUR",
        "CampaignItemLocationState.CONTAINER_WORN_UTILITY",
        "definition.can_equip_in_slot(location.container_id)",
    ], "Fixed equipment-slot validation", errors)
    require(sandbox, [
        "MarauderLoadoutMigration.repair_character(",
    ], "Sandbox loadout repair", errors)
    require(authored, [
        "Authored mission campaign initialization failed",
        "return null",
    ], "Authored mission fail-closed bootstrap", errors)
    require(runtime, [
        "_test_legacy_marauder_loadout_migration",
        "Legacy migration did not add Raider's Sack.",
        "Deprecated carrying belt survived migration.",
        "Migration did not return Raider's Axe to Primary Hand.",
    ], "Legacy-save runtime coverage", errors)

    if errors:
        print("Stage 4.7 Hotfix 5b Raider's Sack migration validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Stage 4.7 Hotfix 5b Raider's Sack migration validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
