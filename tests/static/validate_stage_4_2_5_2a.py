#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []

    for path in [
        "STAGE_4_2_5_2A_CHARACTER_TEST_STATIC_HELPER_HOTFIX.txt",
        "docs/architecture/STAGE_4_2_5_2A_CHARACTER_TEST_STATIC_HELPER_HOTFIX.md",
        "tests/characters/stage_3_12_character_system_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "tests/characters/stage_3_12_character_system_tests.gd",
        [
            "static func _test_marauder_baseline_resolution(",
            "static func _test_rage_recalculates_from_sources(",
            "static func _resolution_service(",
            "_resolution_service(catalogue).resolve_character(",
        ],
        failures,
    )
    forbid_tokens(
        "tests/characters/stage_3_12_character_system_tests.gd",
        ["\nfunc _resolution_service("],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.2a",
        failures,
        [
            "The Stage 3.12 character-resolution helper is static.",
            "Static character tests no longer call an instance helper.",
            "No runtime gameplay behaviour is changed.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
