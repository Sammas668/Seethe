#!/usr/bin/env python3
from pathlib import Path

from validation_common import *


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    factory_path = Path("bootstrap/debug/tactical_sandbox_factory.gd")
    if not factory_path.is_file():
        failures.append(f"Missing required file: {factory_path}")
    else:
        text = factory_path.read_text(encoding="utf-8")
        state_index = text.find("var state: TacticalState = TacticalState.new()")
        configure_index = text.find("state.configure_extraction_zones(MOVEMENT_TEST_MAP)")
        knowledge_index = text.find("state.configure_knowledge_grid(MOVEMENT_TEST_MAP.grid_size)")
        deploy_index = text.find("\n\t_deploy_or_error(", max(state_index, 0))
        if state_index < 0:
            failures.append("Sandbox factory no longer creates an assembly TacticalState.")
        if configure_index < 0:
            failures.append("Sandbox factory does not configure extraction zones before deployment.")
        if knowledge_index < 0:
            failures.append("Sandbox factory does not configure the knowledge grid before deployment.")
        if deploy_index < 0:
            failures.append("Sandbox factory has no initial deployment call.")
        if not (
            state_index >= 0
            and configure_index > state_index
            and knowledge_index > configure_index
            and deploy_index > knowledge_index
        ):
            failures.append(
                "Extraction-zone and knowledge-grid configuration must occur after state creation "
                "and before the first character deployment."
            )

    require_tokens(
        "domain/tactical/tactical_state.gd",
        [
            "func configure_extraction_zones(",
            'errors.append("Tactical state is missing extraction zone %s." % zone_id)',
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_3_extraction_mission_tests.gd",
        [
            "TacticalSandboxFactory.create_session(false)",
            "state.extraction_zone_state(ZONE_ID) != null",
            "manifest.extracted_friendly_unit_ids.size() == 3",
        ],
        failures,
    )
    require_file(
        "STAGE_4_3_3A_EXTRACTION_ZONE_ASSEMBLY_ORDER_HOTFIX_RELEASE_NOTES.txt",
        failures,
    )
    require_file("STAGE_4_3_3A_VALIDATION_RESULTS.txt", failures)

    if failures:
        print("Stage 4.3.3a static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Stage 4.3.3a static validation passed.")
    print(" - Authored extraction-zone state exists before assembly deployment validation.")
    print(" - The sandbox can deploy its player and non-player participants before session creation.")
    print(" - The tactical map can initialise visibility from the deployed player squad.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
