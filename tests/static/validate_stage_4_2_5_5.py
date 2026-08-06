#!/usr/bin/env python3
import sys
from pathlib import Path
from validation_common import *


PRESENTATION_MUTATOR_TOKENS = [
    ".state().add_unit(",
    ".state().remove_unit(",
    ".state().set_unit_position(",
    ".state().move_item(",
    ".state().remove_item(",
    ".state().begin_initiative_combat(",
    ".state().append_initiative_participants(",
    ".state().advance_initiative_turn(",
]


def main() -> int:
    failures: list[str] = []

    required = [
        "STAGE_4_2_5_5_TACTICAL_VISIBILITY_DETECTION_HARDENING_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_2_5_5_TACTICAL_VISIBILITY_DETECTION_HARDENING.md",
        "domain/tactical/knowledge/tactical_knowledge_state.gd",
        "domain/tactical/visibility/tactical_line_of_sight_rules.gd",
        "domain/tactical/visibility/tactical_visibility_state.gd",
        "application/tactical/visibility/tactical_visibility_service.gd",
        "application/tactical/awareness/detection_observer_query.gd",
        "application/tactical/awareness/detection_preview_query.gd",
        "application/tactical/awareness/contact_initiative_resolver.gd",
        "application/tactical/awareness/detection_batch_transaction_support.gd",
        "application/tactical/awareness/tactical_detection_service.gd",
        "tests/tactical/stage_4_2_5_5_visibility_detection_hardening_tests.gd",
        "tests/tactical/run_stage_4_2_5_5_tests.gd",
        "README_FIRST.txt",
        "PROJECT_TREE.txt",
    ]
    for path in required:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/knowledge/tactical_knowledge_state.gd",
        [
            "class_name TacticalKnowledgeState",
            "func mark_many_explored(",
            "func snapshot() -> Dictionary:",
            "func restore(snapshot_value: Dictionary) -> void:",
            "func validate_state(",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_state.gd",
        [
            "var knowledge_state = TacticalKnowledgeState.new()",
            "func configure_knowledge_grid(",
            "func is_tile_explored(",
            "func knowledge_snapshot() -> Dictionary:",
            "knowledge_state.validate_state(",
        ],
        failures,
    )
    forbid_tokens(
        "domain/tactical/visibility/tactical_visibility_state.gd",
        ["_explored_by_team", "func is_explored(", "func explored_tile_count("],
        failures,
    )
    require_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        [
            "VISIBILITY_AFFECTING_REASONS",
            "_skipped_change_count += 1",
            "_state_store.state.knowledge_state.mark_many_explored",
            "func performance_snapshot() -> Dictionary:",
            "TacticalLineOfSightRules.has_line_of_sight",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/visibility/tactical_line_of_sight_rules.gd",
        [
            "class_name TacticalLineOfSightRules",
            "static func trace_line(",
            "static func has_line_of_sight(",
            "static func first_blocking_tile(",
        ],
        failures,
    )
    forbid_tokens(
        "application/tactical/visibility/tactical_visibility_service.gd",
        ["func _bresenham_line(", "func _has_line_of_sight("],
        failures,
    )
    forbid_tokens(
        "domain/tactical/awareness/tactical_perception_rules.gd",
        ["static func bresenham_line(", "static func has_line_of_sight("],
        failures,
    )
    require_tokens(
        "domain/tactical/awareness/tactical_perception_rules.gd",
        ["TacticalLineOfSightRules.has_line_of_sight"],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/detection_observer_query.gd",
        [
            "class_name DetectionObserverQuery",
            "func collect_tile_exposures(",
            "func perceiving_observers_for_squad(",
            "_perception_tile_cache",
            "func performance_snapshot() -> Dictionary:",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/detection_preview_query.gd",
        [
            "class_name DetectionPreviewQuery",
            "func preview_for_path(",
            "_build_tile_preview",
            "_aggregate_tile_preview",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/contact_initiative_resolver.gd",
        [
            "class_name ContactInitiativeResolver",
            "func finalize_resolution(",
            "func finalize_batch(",
            "_roll_contact_participants",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/detection_batch_transaction_support.gd",
        [
            "class_name DetectionBatchTransactionSupport",
            "func snapshot_for_resolutions(",
            "func restore_snapshot(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/awareness/tactical_detection_service.gd",
        [
            "return _preview_query.preview_for_path(unit_id, path)",
            "_batch_transaction_support.snapshot_for_resolutions(resolutions)",
            "func apply_resolution_batch(",
            'Callable(_batch_transaction_support, "restore_snapshot")',
            "_contact_resolver.finalize_batch(resolutions)",
            "Current squad perception could not be committed atomically.",
        ],
        failures,
    )
    detection_text = require_file(
        "application/tactical/awareness/tactical_detection_service.gd", failures
    )
    if detection_text and len(detection_text.splitlines()) >= 1000:
        failures.append(
            "TacticalDetectionService remained at or above 1000 lines after responsibility extraction."
        )

    require_tokens(
        "domain/tactical/movement_rules.gd",
        ["static func movement_step_cost("],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        [
            "var accumulated_cost: int = 0",
            "MovementRules.movement_step_cost(",
        ],
        failures,
    )
    forbid_tokens(
        "application/tactical/ai/enemy_action_planner.gd",
        ["var prefix: Array[Vector2i] = []"],
        failures,
    )

    for path in (ROOT / "presentation").rglob("*.gd"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for token in PRESENTATION_MUTATOR_TOKENS:
            if token in text:
                failures.append(
                    f"presentation mutator boundary violation in {path.relative_to(ROOT)}: {token}"
                )

    require_tokens(
        "presentation/tactical/tactical_board_view.gd",
        ["func performance_snapshot() -> Dictionary:", "_last_board_draw_usec"],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_2_5_5_visibility_detection_hardening_tests.gd",
        [
            "_test_explored_knowledge_survives_service_recreation",
            "_test_shared_line_of_sight_authority",
            "_test_visibility_invalidation_filters_non_spatial_changes",
            "_test_perception_overlay_cache",
            "_test_squad_perception_commits_once",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        ["Stage 4.2.5.5 tactical visibility and detection hardening loaded."],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.2.5.5",
        failures,
        [
            "Explored fog history is authoritative tactical knowledge.",
            "Visibility and perception consume one line-of-sight authority.",
            "Squad perception prepares and commits atomically.",
            "Visibility invalidation and perception overlays avoid redundant work.",
            "Detection preview and contact initiative responsibilities are separated.",
            "Presentation remains read-only against known tactical root mutators.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
