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
        "STAGE_4_5E6_INCREMENTAL_VISIBILITY_FOG_HANDOFF_RELEASE_NOTES.txt",
        "STAGE_4_5E6_PATCH_README.txt",
        "STAGE_4_5E6_VALIDATION_RESULTS.txt",
        "docs/architecture/STAGE_4_5E6_INCREMENTAL_VISIBILITY_FOG_HANDOFF.md",
        "domain/tactical/visibility/tactical_visibility_ray_cache.gd",
        "tests/tactical/stage_4_5e6_incremental_visibility_fog_tests.gd",
        "tests/tactical/run_stage_4_5e6_tests.gd",
    ]:
        require_file(path, failures)

    visibility_path = "application/tactical/visibility/tactical_visibility_service.gd"
    visibility_text = require_file(visibility_path, failures)
    for token in [
        "VISIBILITY_RAY_CACHE_SCRIPT",
        "signal visibility_delta_changed",
        "_ray_cache.configure(TacticalGridDistance.GENERAL_SIGHT_RADIUS_TILES)",
        "func last_delta_for_team(",
        "func _publish_visibility_deltas(",
        '"newly_visible"',
        '"no_longer_visible"',
        '"newly_explored"',
        '"visibility_field_cache_hits"',
        '"last_exploration_commit_usec"',
        '"last_visibility_delta_build_usec"',
    ]:
        if token not in visibility_text:
            failures.append(f"Incremental visibility contract missing: {token}")

    exploration = function_block(visibility_path, "_commit_exploration_batch")
    for token in [
        "changes.set_commit_validation_policy(false, false)",
        'Callable(self, "_validate_exploration_batches")',
        "_lightweight_exploration_commit_count += 1",
    ]:
        if token not in exploration:
            failures.append(f"Lightweight exploration commit missing: {token}")
    for forbidden in [
        "synchronise_body_items",
        "validate_all",
    ]:
        if forbidden in exploration:
            failures.append(
                f"Exploration critical path still performs global work: {forbidden}"
            )

    fov = function_block(visibility_path, "_cached_visibility_field")
    shadowcast_path = ROOT / "domain/tactical/visibility/tactical_edge_shadowcast_fov.gd"
    if shadowcast_path.exists():
        for token in [
            "_centre_field_cache",
            "_edge_fov.calculate",
            "geometry_stamp_for_origin",
        ]:
            if token not in fov:
                failures.append(f"Precomputed FOV cache missing: {token}")
        require_tokens(
            "domain/tactical/visibility/tactical_edge_shadowcast_fov.gd",
            [
                "class_name TacticalEdgeShadowcastFov",
                "hybrid_shadowcast_exact_refinement",
                "_shadowcast_superset",
                "_exact_ray_has_line_of_sight",
            ],
            failures,
        )
    else:
        for token in [
            "_ray_cache.rays_for_direction",
            "_ray_cache.all_rays",
            "_visibility_field_cache",
            "_cached_ray_has_line_of_sight",
        ]:
            if token not in fov:
                failures.append(f"Baked FOV cache missing: {token}")
    if "TacticalLineOfSightRules.has_line_of_sight" in fov:
        failures.append(
            "Runtime FOV still rebuilds one complete LOS trace per candidate tile."
        )

    ray_path = "domain/tactical/visibility/tactical_visibility_ray_cache.gd"
    require_tokens(
        ray_path,
        [
            "class_name TacticalVisibilityRayCache",
            "func configure(",
            "func all_rays(",
            "func rays_for_direction(",
            '"intermediate_tiles"',
            '"crossings"',
            '"corner_pairs"',
            '"bake_usec"',
        ],
        failures,
    )

    state_path = "domain/tactical/visibility/tactical_visibility_state.gd"
    require_tokens(
        state_path,
        [
            "func visible_indices(",
            "func tile_from_index(",
        ],
        failures,
    )

    facade_path = "application/tactical/facades/tactical_screen_facade.gd"
    require_tokens(
        facade_path,
        [
            "signal visibility_delta_changed",
            'has_signal("visibility_delta_changed")',
            "func _on_visibility_delta_changed(",
            "func visibility_delta_for_player(",
        ],
        failures,
    )

    board_path = "presentation/tactical/tactical_board_view.gd"
    require_tokens(
        board_path,
        [
            'has_signal("visibility_delta_changed")',
            "func _on_visibility_delta_changed(",
            "_fog_layer.apply_visibility_delta(delta)",
        ],
        failures,
    )

    fog_path = "presentation/tactical/tactical_fog_layer.gd"
    fog_text = require_file(fog_path, failures)
    fog_draw = function_block(fog_path, "_draw")
    for token in [
        "Image.create(",
        "ImageTexture.create_from_image",
        "func apply_visibility_delta(",
        "_fog_texture.update(_fog_image)",
        "draw_texture_rect(",
        '"last_changed_cell_count"',
        '"full_mask_rebuild_count"',
    ]:
        if token not in fog_text:
            failures.append(f"Incremental fog mask missing: {token}")
    for forbidden in [
        "for y: int in range(_map_definition.grid_size.y)",
        "for x: int in range(_map_definition.grid_size.x)",
        "is_tile_explored_by_player",
        "is_tile_visible_to_player",
    ]:
        if forbidden in fog_draw:
            failures.append(
                f"Fog _draw() still scans the whole tactical map: {forbidden}"
            )
    if "draw_texture_rect(" not in fog_draw:
        failures.append("Fog _draw() must issue one mask-texture draw call.")

    require_tokens(
        "tests/tactical/stage_4_5e6_incremental_visibility_fog_tests.gd",
        [
            "The 40-tile Manhattan sight radius must bake 3,281 relative rays.",
            "Cached FOV must preserve authoritative LOS",
            "Exploration must use the targeted lightweight commit path.",
            "A player visibility recalculation must publish one tile delta.",
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "STAGE 4.5e6",
            "INCREMENTAL VISIBILITY AND FOG HANDOFF",
            "run_stage_4_5e6_tests.gd",
        ],
        failures,
    )

    if failures:
        print("Stage 4.5e6 static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.5e6 static validation passed.")
    print(" - Relative LOS traces are baked during mission construction.")
    print(" - Exploration uses targeted knowledge-grid validation.")
    print(" - Visibility publishes changed tile deltas.")
    print(" - Fog updates a compact mask and draws it in one call.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
