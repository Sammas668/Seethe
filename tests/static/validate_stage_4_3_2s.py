#!/usr/bin/env python3
from validation_common import *


def main() -> int:
    failures: list[str] = []
    for path in [
        "STAGE_4_3_2S_BODY_ITEM_STATUS_CARRIER_DOWNING_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_3_2S_BODY_ITEM_STATUS_AND_CARRIER_DOWNING.md",
        "presentation/tactical/tactical_status_badge_provider.gd",
        "presentation/tactical/tactical_body_status_overlay.gd",
        "tests/tactical/stage_4_3_2_body_item_tests.gd",
    ]:
        require_file(path, failures)

    require_tokens(
        "presentation/tactical/tactical_status_badge_provider.gd",
        [
            "class_name TacticalStatusBadgeProvider",
            "static func for_unit(",
            "static func for_body_item(",
            "static func snapshot_from_values(",
            '"dying_successes"',
            '"dying_failures"',
            '"stable"',
            '"unconscious"',
            '"restrained"',
            "static func primary_kind_for_life_state(",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_body_status_overlay.gd",
        [
            "class_name TacticalBodyStatusOverlay",
            "mouse_filter = Control.MOUSE_FILTER_IGNORE",
            "func configure(snapshot: Dictionary)",
            "func _draw_dying_badge(",
            "func _draw_unconscious_badge(",
            "func _draw_dead_badge(",
            "func _draw_stable_marker(",
            "func _draw_restrained_badge(",
            'Color(0.24, 0.78, 0.35, 1.0)',
            'Color(0.92, 0.16, 0.19, 1.0)',
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/spatial_inventory_item_control.gd",
        [
            "var _status_overlay: TacticalBodyStatusOverlay",
            "status_snapshot_value: Dictionary = {}",
            "func _refresh_status_overlay()",
            "preview_overlay.configure(_status_snapshot)",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/spatial_inventory_grid.gd",
        [
            "state: TacticalState = null",
            "TacticalStatusBadgeProvider.for_body_item(state, item)",
            "TacticalStatusBadgeProvider.for_body_item(state, ground_item)",
            "status_snapshot: Dictionary = {}",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/unit_management_slot.gd",
        [
            "var _status_overlay: TacticalBodyStatusOverlay",
            "status_snapshot_value: Dictionary = {}",
            'item_line = "Dragging %s" % item_name',
            "preview_overlay.configure(_status_snapshot)",
            "func _refresh_status_overlay()",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/unit_management_window.gd",
        [
            "_belt_grid.render_inventory_items(",
            "_backpack_grid.render_inventory_items(",
            "_reach_grid.render_ground_items(",
            "TacticalStatusBadgeProvider.for_body_item(_facade.state(), item)",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "set_status_badges(TacticalStatusBadgeProvider.for_unit(unit_state))",
            "func set_status_badges(snapshot: Dictionary)",
            "TacticalStatusBadgeProvider.primary_kind_for_life_state(_life_state)",
            "func _draw_stable_marker()",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_state.gd",
        [
            "const BODY_DROP_OFFSETS := [",
            "func should_body_token_be_visible(",
            "func get_packed_body_items(",
            "_release_bodies_from_incapacitated_carriers(map_definition)",
            "func _release_dragged_bodies_for_carrier(",
            "func _choose_body_drop_cell(",
            "func _body_can_rest_at(",
            "func _place_body_item_on_ground(",
            'body_item.location = TacticalItemLocationState.ground(cell, "Body")',
            '"unit_body_positions"',
            '"unit_awaiting_placement"',
            "still contains a packed body item",
        ],
        failures,
    )
    state_text = require_file("domain/tactical/tactical_state.gd", failures)
    if state_text:
        expected_offsets = [
            "Vector2i(0, -1)",
            "Vector2i(1, -1)",
            "Vector2i(1, 0)",
            "Vector2i(1, 1)",
            "Vector2i(0, 1)",
            "Vector2i(-1, 1)",
            "Vector2i(-1, 0)",
            "Vector2i(-1, -1)",
        ]
        start = state_text.find("const BODY_DROP_OFFSETS := [")
        end = state_text.find("]", start)
        section = state_text[start:end]
        positions = [section.find(token) for token in expected_offsets]
        if any(position < 0 for position in positions) or positions != sorted(positions):
            failures.append("body drop offsets are not in the locked N, NE, E, SE, S, SW, W, NW order")

    require_tokens(
        "application/tactical/tactical_inventory_transfer_handler.gd",
        [
            "Body items use the ordinary spatial fit rule.",
            "if command.target_kind == KIND_BELT and not item.belt_allowed:",
        ],
        failures,
    )
    forbid_tokens(
        "application/tactical/tactical_inventory_transfer_handler.gd",
        [
            "body_belt_forbidden",
            "A body cannot be placed on the Belt.",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_item_instance_state.gd",
        [
            "body_definition.belt_allowed = true",
            "body_definition.backpack_allowed = true",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "view.set_status_badges(TacticalStatusBadgeProvider.for_unit(unit))",
            "_facade.state().should_body_token_be_visible(body_item)",
            "A packed body is a real spatial inventory item and has no ground token.",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_2_body_item_tests.gd",
        [
            "_test_body_status_badge_provider(failures)",
            "_test_carrier_downing_drops_bodies(failures)",
            "Inventory Dying pips must come from the linked character.",
            "A Stable body must retain the Unconscious badge and Stable marker.",
            "A downed carrier must retain no packed body items.",
            "A packed body must be moved onto tactical ground when its carrier falls.",
            "A dragged body must release on its existing valid ground cell.",
            "Carrier downing must not drop ordinary inventory items.",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        [
            'print("Seethe Stage 4.3.2s body status and carrier-downing correction loaded.")',
        ],
        failures,
    )
    require_tokens(
        "README_FIRST.txt",
        [
            "SEETHE GODOT TACTICAL PROTOTYPE — STAGE 4.3.2s",
            "BODY STATUS AND CARRIER-DOWNING CORRECTION",
            "python tests/static/validate_stage_4_3_2s.py",
        ],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.3.2s",
        failures,
        [
            "Body inventory controls use live linked-character badge snapshots.",
            "Ground/dragged/packed token visibility is location-derived.",
            "Incapacitated carriers release packed and dragged bodies deterministically.",
            "Rollback preserves body locations and linked-unit positions.",
        ],
    )


if __name__ == "__main__":
    raise SystemExit(main())
