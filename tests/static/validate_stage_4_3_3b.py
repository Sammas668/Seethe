#!/usr/bin/env python3
from validation_common import *


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    for path in [
        "STAGE_4_3_3B_WITHDRAWAL_MANIFEST_CORRECTION_RELEASE_NOTES.txt",
        "STAGE_4_3_3B_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_3_3B_WITHDRAWAL_MANIFEST_CORRECTION.md",
        "tests/tactical/run_stage_4_3_3b_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "application/tactical/extraction/tactical_extraction_manifest_query.gd",
        [
            "func _enemy_body_is_eligible_for_withdrawal(",
            "unit.is_dead() or unit.is_unconscious() or unit.restrained",
            "zone.allows_items and zone.contains_tile(",
            "manifest.extracted_item_ids.append(item.item_id)",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_3_extraction_mission_tests.gd",
        [
            "_test_ground_items_in_zone_are_withdrawn(failures)",
            "_test_conscious_unrestrained_enemy_is_not_withdrawn(failures)",
            '&"instance.ground.grain_crate"',
            "A conscious, unrestrained enemy must not be brought through withdrawal.",
        ],
        failures,
    )

    if failures:
        print("Stage 4.3.3b static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.3.3b static validation passed.")
    print(" - Loose items in an enabled withdrawal zone are included in legal extraction.")
    print(" - Conscious, unrestrained enemies are excluded from withdrawal.")
    print(" - Unconscious bodies and properly restrained captives retain their intended semantics.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
