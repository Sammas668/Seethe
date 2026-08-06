#!/usr/bin/env python3
from validation_common import *


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)
    for path in [
        "STAGE_4_3_3_EXTRACTION_CAPTIVE_MISSION_RESOLUTION_RELEASE_NOTES.txt",
        "STAGE_4_3_3_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_3_3_EXTRACTION_CAPTIVE_MISSION_RESOLUTION.md",
        "tests/tactical/stage_4_3_3_extraction_mission_tests.gd",
        "tests/tactical/run_stage_4_3_3_tests.gd",
        "domain/tactical/extraction/tactical_extraction_zone_definition.gd",
        "domain/tactical/extraction/tactical_extraction_zone_state.gd",
        "domain/tactical/extraction/tactical_extraction_manifest.gd",
        "application/tactical/extraction/tactical_extraction_manifest_query.gd",
        "application/tactical/extraction/resolve_tactical_mission_handler.gd",
        "domain/missions/mission_outcome.gd",
        "domain/missions/mission_captive_result.gd",
        "domain/campaign/campaign_captive_state.gd",
        "presentation/tactical/missions/tactical_mission_resolution_window.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_map_definition.gd",
        [
            "@export var mission_display_name",
            "@export var primary_objective_tiles",
            "@export var extraction_zones: Array[TacticalExtractionZoneDefinition]",
            "func extraction_zone(",
            "func is_primary_objective_tile(",
        ],
        failures,
    )
    require_tokens(
        "content/missions/farm_storehouse/movement_test_map.tres",
        [
            'mission_display_name = "Raid the Storehouse"',
            'zone_id = &"extraction.player.start"',
            "tile_coordinates = Array[Vector2i]",
            "primary_objective_tiles = Array[Vector2i]",
            "extraction_zones = Array[TacticalExtractionZoneDefinition]",
        ],
        failures,
    )
    require_tokens(
        "domain/missions/mission_setup_snapshot.gd",
        [
            "var protagonist_character_id",
            "var primary_objective_id",
            "var allows_withdrawal",
            "var requires_protagonist_extraction",
            "func configure_mission_definition(",
            "func extraction_zones()",
            'errors.append("MissionSetupSnapshot has no extraction zones.")',
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_state.gd",
        [
            "var extraction_zone_states_by_id",
            "var mission_resolution_locked",
            "func configure_extraction_zones(",
            "func lock_mission_resolution(",
            "func can_accept_tactical_commands()",
            "if mission_resolution_locked:",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/extraction/tactical_extraction_manifest_query.gd",
        [
            "contains_complete_footprint",
            "body_ground_cell(body)",
            "manifest.extracted_item_ids",
            "manifest.captured_enemy_unit_ids",
            "unit.restrained and unit.captive",
            "MissionOutcome.VICTORY",
            "MissionOutcome.WITHDRAWAL",
            "MissionOutcome.DEFEAT",
            "MissionOutcome.CAMPAIGN_DEFEAT",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/extraction/resolve_tactical_mission_handler.gd",
        [
            "MissionResultBuilder.build_extraction_result",
            "lock_mission_resolution",
            "CampaignResultCommitService.new()",
            "commit_result(",
            "_resolve_tactical_defeat",
            "_resolve_campaign_defeat",
            "committed exactly once",
        ],
        failures,
    )
    require_tokens(
        "domain/missions/mission_result.gd",
        [
            "var mission_outcome",
            "var completed_objective_ids",
            "var failed_objective_ids",
            "var extracted_zone_id",
            "var protagonist_extracted",
            "var captive_results_by_character_id",
            "var abandoned_item_ids",
            "var mission_statistics",
        ],
        failures,
    )
    require_tokens(
        "domain/missions/mission_character_result.gd",
        [
            "OUTCOME_EXTRACTED_READY",
            "OUTCOME_EXTRACTED_WOUNDED",
            "OUTCOME_EXTRACTED_CRITICAL",
            "OUTCOME_EXTRACTED_DEAD",
            "OUTCOME_DEAD_UNRECOVERED",
            "OUTCOME_ALIVE_UNRECOVERED",
            "OUTCOME_CAPTURED_ENEMY",
            "func outcome_display_name(",
        ],
        failures,
    )
    require_tokens(
        "application/missions/mission_result_builder.gd",
        [
            "func build_extraction_result(",
            "manifest.has_extracted_body_item",
            "unit.nonlethal_damage",
            "Missing / Unrecovered",
            "MissionCaptiveResult.new()",
            "authorize_generated_item",
        ],
        failures,
    )
    require_tokens(
        "application/missions/mission_result_validator.gd",
        [
            "_validate_extraction_semantics",
            "MissionOutcome.WITHDRAWAL",
            "setup.requires_protagonist_extraction",
            "Captive %s restraint was not extracted.",
        ],
        failures,
    )
    require_tokens(
        "domain/campaign/campaign_state.gd",
        [
            "const CURRENT_SAVE_VERSION: int = 4",
            "var captives_by_id",
            "var mission_history_by_id",
            "func has_resolved_mission(",
            "func record_mission_result(",
        ],
        failures,
    )
    require_tokens(
        "application/campaign/campaign_result_commit_service.gd",
        [
            "campaign.has_resolved_mission",
            "CampaignCaptiveState.new()",
            "candidate.upsert_captive",
            "candidate.record_mission_result",
            "candidate.mark_result_applied",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        [
            "EXTRACTION_ZONE_COLOR",
            "func _draw_extraction_zones()",
            "_facade.extraction_zone_definitions()",
            "draw_colored_polygon(arrow, border)",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.tscn",
        ['[node name="ExtractButton"', 'text = "EXTRACT"'],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "func _on_extract_pressed()",
            "func _on_mission_resolution_confirmed",
            "show_confirmation(",
            "show_summary(",
            "func _resolve_campaign_defeat_if_needed()",
            "func _resolve_tactical_defeat_if_needed()",
            "mission_resolution_locked()",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/missions/tactical_mission_resolution_window.gd",
        [
            "signal confirm_requested",
            "func show_confirmation(",
            "func show_summary(",
            '"[b]Leaving safely[/b]"',
            '"[b]Being abandoned[/b]"',
            '"[b]Captives[/b]"',
            '"[b]Mission record[/b]"',
        ],
        failures,
    )
    require_tokens(
        "bootstrap/debug/tactical_sandbox_factory.gd",
        [
            "configure_mission_definition(",
            "MOVEMENT_TEST_MAP, MARAUDER_ID",
            "campaign_store",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/tactical_session.gd",
        [
            "configure_extraction_zones(map_definition_value)",
            "mission_resolution_handler",
            "RESOLVE_TACTICAL_MISSION_HANDLER_SCRIPT",
        ],
        failures,
    )

    if failures:
        print("Stage 4.3.3 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.3.3 static validation passed.")
    print(" - Authored zones and physical manifests now govern extraction.")
    print(" - Victory, Withdrawal, Defeat and Campaign Defeat have explicit results.")
    print(" - Captives, bodies, personnel and items commit through one idempotent campaign boundary.")
    print(" - The tactical HUD now previews and confirms mission resolution before showing the committed summary.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
