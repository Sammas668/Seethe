#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

from validation_common import *


def _forbid_in_tree(root: str, tokens: list[str], failures: list[str]) -> None:
    base = ROOT / root
    if not base.exists():
        failures.append(f"missing required directory: {root}")
        return
    for path in base.rglob("*.gd"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for token in tokens:
            if token in text:
                failures.append(
                    f"{path.relative_to(ROOT)} contains forbidden dependency token: {token}"
                )


def _require_no_reference(fragment: str, failures: list[str]) -> None:
    for path in ROOT.rglob("*.gd"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        if fragment in text:
            failures.append(
                f"{path.relative_to(ROOT)} still references obsolete path: {fragment}"
            )


def main() -> int:
    failures: list[str] = []

    # Removed or moved boundary violations.
    for obsolete in [
        "application/characters/tactical_character_persistence_service.gd",
        "application/characters/character_roster_repository.gd",
        "infrastructure/content/content_catalogue.gd",
        "application/tactical/tactical_sandbox_factory.gd",
    ]:
        require_absent(obsolete, failures)

    for obsolete_path in [
        "res://application/characters/tactical_character_persistence_service.gd",
        "res://application/characters/character_roster_repository.gd",
        "res://infrastructure/content/content_catalogue.gd",
        "res://application/tactical/tactical_sandbox_factory.gd",
    ]:
        _require_no_reference(obsolete_path, failures)

    # Persistence port and concrete implementation.
    require_tokens(
        "application/campaign/ports/campaign_repository.gd",
        ["class_name CampaignRepository", "load_campaign", "save_campaign", "clear_save"],
        failures,
    )
    require_tokens(
        "infrastructure/persistence/json_campaign_repository.gd",
        [
            "class_name JsonCampaignRepository",
            "extends CampaignRepository",
            "backup_path",
            "temporary_path",
            "_preserve_corrupt_file",
            "_read_campaign_file",
            "_write_text_file",
            "CampaignItemValidator.validate_campaign",
        ],
        failures,
    )

    # Content contract moved inward; Godot loading remains infrastructure.
    require_tokens(
        "application/content/content_catalogue.gd",
        [
            "class_name ContentCatalogue",
            "register_item_definition",
            "item_definition",
            "character_template",
            "freeze",
            "is_frozen",
        ],
        failures,
    )
    require_tokens(
        "infrastructure/content/godot_content_loader.gd",
        ["class_name GodotContentLoader", "populate_catalogue"],
        failures,
    )
    require_tokens(
        "infrastructure/content/sandbox_content_catalogue_factory.gd",
        ["GodotContentLoader.populate_catalogue", "catalogue.freeze()"],
        failures,
    )

    # Composition belongs to bootstrap/debug.
    require_tokens(
        "bootstrap/debug/tactical_sandbox_factory.gd",
        [
            "class_name TacticalSandboxFactory",
            "JsonCampaignRepository.new",
            "SandboxContentCatalogueFactory.create_catalogue",
            "MISSION_SETUP_BUILDER_SCRIPT",
        ],
        failures,
    )

    # Presentation consumes a facade and stable portrait IDs, not infrastructure/rules.
    require_tokens(
        "application/tactical/facades/tactical_screen_facade.gd",
        [
            "class_name TacticalScreenFacade",
            "preview_movement",
            "execute_movement",
            "action_unavailable_reason",
            "preview_inventory_transfer",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/queries/movement_preview_query.gd",
        ["class_name MovementPreviewQuery", "func execute"],
        failures,
    )
    require_tokens(
        "application/tactical/queries/action_availability_query.gd",
        ["class_name ActionAvailabilityQuery", "unavailable_reason", "cost_for_action"],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        ["_facade", "_player_unit_order", "_create_roster_buttons", "_unit_buttons"],
        failures,
    )
    _forbid_in_tree(
        "presentation",
        [
            "ContentCatalogue",
            "SandboxContentCatalogueFactory",
            "MovementRules.",
            "ActionEconomyRules.",
            "ResourceLoader.",
            "load(portrait",
            ".set_unit_position(",
            ".move_item(",
            ".add_unit(",
            ".remove_unit(",
        ],
        failures,
    )

    # Stable portrait identity and migration from prior path-based saves.
    require_tokens(
        "domain/characters/state/persistent_character_state.gd",
        ["portrait_override_id", "effective_portrait_id", "_migrate_legacy_portrait_path"],
        failures,
    )
    require_tokens(
        "presentation/assets/portrait_asset_resolver.gd",
        ["class_name PortraitAssetResolver", "portrait.hakon_rusk", "resolve"],
        failures,
    )
    forbid_tokens(
        "domain/characters/state/persistent_character_state.gd",
        ['"portrait_override_path":'],
        failures,
    )

    # Mandatory resolver script is explicit without relying on global class-cache order.
    require_tokens(
        "domain/characters/resolution/character_resolver.gd",
        ["class_name CharacterResolver", "RESOLVED_CHARACTER_SNAPSHOT_SCRIPT"],
        failures,
    )
    require_tokens(
        "application/characters/character_resolution_service.gd",
        [
            "CHARACTER_RESOLVER_SCRIPT",
            "var _resolver: RefCounted",
            '_resolver.call(',
            '"resolve"',
        ],
        failures,
    )
    forbid_tokens(
        "application/characters/character_resolution_service.gd",
        [
            "var _resolver: CharacterResolver",
            "CharacterResolver.new()",
            "resolver: CharacterResolver",
            'load("res://domain/characters/resolution',
        ],
        failures,
    )

    # Tactical commits use typed wrappers; runtime spawning uses the commit boundary.
    require_tokens(
        "application/tactical/transactions/tactical_mutation_step.gd",
        ["class_name TacticalMutationStep", "apply_change", "rollback_change"],
        failures,
    )
    require_tokens(
        "application/tactical/transactions/tactical_validation_rule.gd",
        ["class_name TacticalValidationRule", "validate"],
        failures,
    )
    require_tokens(
        "application/tactical/transactions/tactical_change_set.gd",
        [
            "Array[TacticalMutationStep]",
            "Array[TacticalValidationRule]",
            "_rollback",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/tactical_state_store.gd",
        ["var _state: TacticalState", "func commit", "change_set.execute"],
        failures,
    )
    forbid_tokens(
        "application/tactical/tactical_state_store.gd",
        ["func notify_changed"],
        failures,
    )
    require_tokens(
        "application/tactical/runtime_spawn_handler.gd",
        ["class_name RuntimeSpawnHandler", "TacticalChangeSet.new", "_state_store.commit"],
        failures,
    )
    require_tokens(
        "application/characters/tactical_character_deployment_service.gd",
        ["deploy_character_for_assembly", "shallow_copy_for_assembly_validation"],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_state.gd",
        ["func shallow_copy_for_assembly_validation"],
        failures,
    )
    forbid_tokens(
        "domain/tactical/tactical_state.gd",
        ["func duplicate_for_validation"],
        failures,
    )

    # Mission and campaign item outcomes conserve identity and authorised changes.
    require_tokens(
        "domain/missions/mission_result.gd",
        ["generated_item_provenance_by_id", "authorize_generated_item"],
        failures,
    )
    require_tokens(
        "application/missions/mission_result_validator.gd",
        [
            "source_campaign_revision",
            "generated_item_provenance_by_id",
            "quantity",
            "condition",
            "persistent_modifiers",
            "_validate_generated_item_authority",
            "CampaignItemValidator.validate_item",
        ],
        failures,
    )
    require_tokens(
        "domain/missions/mission_character_result.gd",
        [
            "OUTCOME_NOT_DEPLOYED",
            "OUTCOME_ACTIVE",
            "OUTCOME_DOWNED",
            "OUTCOME_STABILISED",
            "OUTCOME_DEAD",
        ],
        failures,
    )
    require_tokens(
        "application/campaign/campaign_item_validator.gd",
        [
            "maximum_stack_size",
            "LOCATION_STRONGHOLD_STORAGE",
            "_validate_inventory_overlaps",
            "_validate_hand_conflicts",
        ],
        failures,
    )

    # Repository-wide static guardrails.
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 3.16",
        failures,
        [
            "Application contracts no longer depend on concrete persistence/content loaders.",
            "Presentation uses the tactical facade and shared preview queries.",
            "Mission item outcomes and runtime mutations have stronger validation boundaries.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
