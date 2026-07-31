#!/usr/bin/env python3
from validation_common import *


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    for path in [
        "STAGE_4_3_3C_MISSION_LOOP_STABILISATION_RELEASE_NOTES.txt",
        "STAGE_4_3_3C_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_3_3C_MISSION_LOOP_STABILISATION.md",
        "application/tactical/extraction/tactical_extraction_manifest_validator.gd",
        "tests/tactical/stage_4_3_3c_mission_loop_stabilisation_tests.gd",
        "tests/tactical/run_stage_4_3_3c_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/extraction/tactical_extraction_manifest.gd",
        [
            "var source_tactical_revision: int = -1",
            '"source_tactical_revision": source_tactical_revision',
        ],
        failures,
    )
    require_tokens(
        "application/tactical/extraction/tactical_extraction_manifest_validator.gd",
        [
            "class_name TacticalExtractionManifestValidator",
            "static func validate(",
            "_validate_friendly_partition(manifest, state, errors)",
            "_validate_item_partition(manifest, state, errors)",
            "_validate_enemy_recovery(manifest, state, errors)",
            "_validate_defeat_recovery(manifest, errors)",
            "Conscious unrestrained enemy",
            "Defeat manifests cannot recover",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/extraction/tactical_extraction_manifest_query.gd",
        [
            "manifest.source_tactical_revision = state.revision",
            "TacticalExtractionManifestValidator.validate(manifest, state)",
            "func _finalize_manifest(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/extraction/resolve_tactical_mission_handler.gd",
        [
            "expected_tactical_revision: int = -1",
            '&"extraction_preview_stale"',
            "TacticalExtractionManifestValidator.validate(",
            '&"extraction_manifest_integrity_failed"',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/missions/tactical_mission_resolution_window.gd",
        [
            "signal confirm_requested(zone_id: StringName, tactical_revision: int)",
            "_preview_tactical_revision = manifest.source_tactical_revision",
            "func is_confirmation_open() -> bool:",
            "confirm_requested.emit(_zone_id, _preview_tactical_revision)",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "func _refresh_open_extraction_confirmation() -> void:",
            "expected_tactical_revision: int",
            "zone_id, expected_tactical_revision",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/debug/tactical_sandbox_factory.gd",
        [
            "campaign_save_path: String = CampaignRepository.DEFAULT_SAVE_PATH",
            "campaign_save_path,",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_3c_mission_loop_stabilisation_tests.gd",
        [
            "_test_startup_map_visibility_and_tokens(failures)",
            "_test_manifest_integrity_and_stale_preview_guard(failures)",
            "_test_carried_and_dragged_friendly_bodies_build_results(failures)",
            "_test_defeat_result_recovers_no_property(failures)",
            "_test_withdrawal_end_to_end_persists_once(failures)",
            "pre_resolution_reload",
            "reloaded_store.current_campaign().get_captives().size() == 1",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.3.3c",
            "MISSION-LOOP STABILISATION",
            "run_stage_4_3_3c_tests.gd",
            "validate_stage_4_3_3c.py",
        ],
        failures,
    )
    require_tokens(
        "SEETHE_PROJECT_STRUCTURE_GUIDE_V2.md",
        [
            "Stage 4.3.3c — Mission-Loop Stabilisation",
            "TacticalExtractionManifestValidator",
            "source_tactical_revision",
        ],
        failures,
    )

    if failures:
        print("Stage 4.3.3c static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.3.3c static validation passed.")
    print(" - Extraction previews are revision-bound and reject stale confirmation.")
    print(" - Manifest partitions and hostile/captive semantics are validated before commit.")
    print(" - End-to-end Withdrawal persistence and idempotent reload coverage is present.")
    print(" - Active-stage documentation identifies the stabilised vertical slice.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
