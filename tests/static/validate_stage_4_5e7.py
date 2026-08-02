#!/usr/bin/env python3
from validation_common import *


def function_block(path: str, function_name: str) -> str:
    text = (ROOT / path).read_text(encoding="utf-8")
    marker = f"func {function_name}("
    start = text.find(marker)
    if start < 0:
        return ""
    end = text.find("\nfunc ", start + len(marker))
    return text[start:] if end < 0 else text[start:end]


def main() -> int:
    failures: list[str] = []
    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    for path in [
        "STAGE_4_5E7_PRECOMPUTED_SHADOWCAST_VISIBILITY_RELEASE_NOTES.txt",
        "STAGE_4_5E7_PATCH_README.txt",
        "STAGE_4_5E7A_STARTUP_VISIBILITY_SAFETY_RELEASE_NOTES.txt",
        "STAGE_4_5E7A_PATCH_README.txt",
        "docs/architecture/STAGE_4_5E7_PRECOMPUTED_SHADOWCAST_VISIBILITY.md",
        "docs/architecture/STAGE_4_5E7A_STARTUP_VISIBILITY_SAFETY.md",
        "domain/tactical/visibility/tactical_visibility_field.gd",
        "domain/tactical/visibility/tactical_edge_shadowcast_fov.gd",
        "tests/tactical/stage_4_5e7_precomputed_shadowcast_visibility_tests.gd",
        "tests/tactical/run_stage_4_5e7_tests.gd",
        "tests/tactical/run_stage_4_5e7a_tests.gd",
    ]:
        require_file(path, failures)

    field_path = "domain/tactical/visibility/tactical_visibility_field.gd"
    require_tokens(
        field_path,
        [
            "class_name TacticalVisibilityField",
            "var bits: PackedByteArray",
            "func merge_from(",
            "func visible_indices(",
            "func duplicate_bits(",
            "var byte_index: int = index >> 3",
        ],
        failures,
    )

    fov_path = "domain/tactical/visibility/tactical_edge_shadowcast_fov.gd"
    fov_text = require_file(fov_path, failures)
    for token in [
        "class_name TacticalEdgeShadowcastFov",
        '"algorithm": "hybrid_shadowcast_exact_refinement"',
        "func _shadowcast_superset(",
        "func _conservative_angular_field(",
        "func _exact_ray_has_line_of_sight(",
        "func geometry_stamp_for_origin(",
        "const CHUNK_SIZE_TILES: int = 8",
        "_ray_cache.ray_for_offset",
        "environment.edge_blocks_sight",
    ]:
        if token not in fov_text:
            failures.append(f"Hybrid FOV contract missing: {token}")
    if "TacticalLineOfSightRules.has_line_of_sight" in fov_text:
        failures.append("Hybrid FOV must not rebuild a complete LOS query per candidate tile.")

    ray_path = "domain/tactical/visibility/tactical_visibility_ray_cache.gd"
    require_tokens(
        ray_path,
        [
            "var _ray_by_offset: Dictionary",
            "func ray_for_offset(",
            "_ray_by_offset[offset] = ray",
        ],
        failures,
    )

    state_path = "domain/tactical/visibility/tactical_visibility_state.gd"
    state_text = require_file(state_path, failures)
    for token in [
        "var _visibility_bits_by_unit: Dictionary",
        "func replace_unit_visibility_field(",
        "if before_add == 0:",
        "if before_remove == 1:",
        "var removed_bits: int",
        "var added_bits: int",
        '"newly_visible_indices"',
        '"no_longer_visible_indices"',
    ]:
        if token not in state_text:
            failures.append(f"Direct visibility-delta contract missing: {token}")

    replacement = function_block(state_path, "replace_unit_visibility_field")
    if "field.visible_indices()" in replacement:
        failures.append(
            "Moved-unit visibility replacement still enumerates the complete new field."
        )
    for required in ["removed_bits", "added_bits", "byte_index << 3"]:
        if required not in replacement:
            failures.append(f"Bytewise visibility diff missing: {required}")

    service_path = "application/tactical/visibility/tactical_visibility_service.gd"
    service_text = require_file(service_path, failures)
    for token in [
        "EDGE_SHADOWCAST_FOV_SCRIPT",
        "VISIBILITY_FIELD_SCRIPT",
        "var _centre_field_cache: Array",
        "func _prewarm_active_unit_visibility_fields(",
        "func _prebake_walkable_visibility_fields(",
        "func prepare_visibility_for_destination(",
        "func prepare_visibility_for_units(",
        "func _publish_direct_visibility_deltas(",
        "func _queue_exploration_from_boundary_deltas(",
        "_edge_fov.geometry_stamp_for_origin",
        '"prebaked_centre_field_count"',
        '"prebaked_bitset_bytes"',
        '"prepared_field_hits"',
        '"direct_delta_update_count"',
    ]:
        if token not in service_text:
            failures.append(f"Precomputed visibility service missing: {token}")

    incremental = function_block(service_path, "recalculate_units")
    for forbidden in [
        "_visible_indices_snapshot",
        "_publish_visibility_deltas",
        'call("visible_indices"',
    ]:
        if forbidden in incremental:
            failures.append(
                f"Incremental movement visibility still performs a full-map delta scan: {forbidden}"
            )
    for required in [
        "_merge_boundary_deltas",
        "_publish_direct_visibility_deltas",
        "remove_unit_visibility_with_delta",
    ]:
        if required not in incremental:
            failures.append(f"Incremental direct-delta path missing: {required}")

    configure = function_block(service_path, "configure")
    if "_prebake_walkable_visibility_fields()" in configure:
        failures.append(
            "Mission startup still invokes the unsafe all-walkable-origin bake."
        )
    if "_prewarm_active_unit_visibility_fields()" not in configure:
        failures.append("Mission startup no longer performs bounded active-observer prewarming.")

    prewarm = function_block(service_path, "_prewarm_active_unit_visibility_fields")
    for required in [
        "STARTUP_PREWARM_MAX_FIELD_COUNT",
        "for unit: TacticalUnitState in _state_store.state.get_units()",
        "fields_built >= STARTUP_PREWARM_MAX_FIELD_COUNT",
        "_cached_visibility_field(",
        "_prebaked_centre_field_count",
    ]:
        if required not in prewarm:
            failures.append(f"Bounded startup visibility prewarm missing: {required}")
    for forbidden in [
        "for y: int in range(_map_definition.grid_size.y)",
        "for x: int in range(_map_definition.grid_size.x)",
        "_peek_field_requests(origin)",
    ]:
        if forbidden in prewarm:
            failures.append(
                f"Startup prewarm still attempts a full-map visibility bake: {forbidden}"
            )

    destination_prepare = function_block(
        service_path, "prepare_visibility_for_destination"
    )
    for required in [
        "_build_visibility_field_for_unit_at(",
        '"position": destination',
        '"geometry_revision"',
        '"field": prepared',
    ]:
        if required not in destination_prepare:
            failures.append(f"Clicked-destination visibility preparation missing: {required}")


    prepare = function_block(service_path, "prepare_visibility_for_units")
    for required in [
        "_try_build_prepared_field(unit)",
        '"geometry_revision"',
        '"field"',
    ]:
        if required not in prepare:
            failures.append(f"Movement visibility preparation missing: {required}")

    screen_path = "presentation/tactical/tactical_screen.gd"
    require_tokens(
        screen_path,
        [
            "_begin_movement_presentation_batch(events)",
            "_facade.prepare_visibility_for_destination(unit.unit_id, final_tile)",
            "_facade.prepare_visibility_for_units(preparing_unit_ids)",
            "_facade.end_visibility_recalculation_deferral_for_units(",
        ],
        failures,
    )

    facade_path = "application/tactical/facades/tactical_screen_facade.gd"
    require_tokens(
        facade_path,
        [
            "func prepare_visibility_for_destination(",
            'has_method("prepare_visibility_for_destination")',
            "func prepare_visibility_for_units(",
            'has_method("prepare_visibility_for_units")',
        ],
        failures,
    )

    boot_path = "bootstrap/boot/boot.gd"
    require_tokens(
        boot_path,
        [
            "func _show_loading_screen(",
            'label.text = "Preparing tactical map and initial visibility…"',
            "await get_tree().process_frame",
            "Stage 4.5e7a bounded visibility prewarm loaded.",
        ],
        failures,
    )

    exploration = function_block(service_path, "_commit_exploration_batch")
    if "changes.set_commit_validation_policy(false, false)" not in exploration:
        failures.append("Exploration no longer uses its lightweight knowledge-only transaction.")

    require_tokens(
        "tests/tactical/stage_4_5e7_precomputed_shadowcast_visibility_tests.gd",
        [
            "Mission construction must skip the unsafe all-walkable-origin bake.",
            "Precomputed FOV differs from authoritative LOS:",
            "Moved-observer visibility must publish reference-count boundary crossings directly.",
            "A clicked movement destination must prepare its centre and Peek masks during planning.",
            "Opening a distant door must not invalidate unrelated origin masks.",
        ],
        failures,
    )

    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.5e7a",
            "BOUNDED VISIBILITY PREWARM AND STARTUP SAFETY",
            "run_stage_4_5e7_tests.gd",
        ],
        failures,
    )

    return finish(
        "Stage 4.5e7a",
        failures,
        [
            "Startup warms only deployed observers under a hard field-count limit.",
            "Clicked destinations prepare compact centre and Peek fields before movement.",
            "Hybrid shadowcasting and direct visibility crossings remain intact.",
            "The unsafe synchronous all-map startup bake is no longer invoked.",
        ],
    )


if __name__ == "__main__":
    raise SystemExit(main())
