#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    required = [
        "STAGE_4_3_2_BODY_ITEMS_MEDICAL_RESTRAINT_RELEASE_NOTES.txt",
        "docs/architecture/STAGE_4_3_2_BODY_ITEMS_MEDICAL_RESTRAINT.md",
        "tests/tactical/stage_4_3_2_body_item_tests.gd",
        "tests/tactical/run_stage_4_3_2_tests.gd",
        "application/tactical/body/tactical_body_action_handler.gd",
        "content/items/minor_healing_potion.tres",
    ]
    for path in required:
        require_file(path, failures)

    require_tokens(
        "domain/tactical/tactical_unit_state.gd",
        [
            "var body_item_id: StringName",
            "var restrained",
            "var captive",
            "func has_fallen_body_state()",
            "func requires_body_item()",
            "func blocks_standing_space()",
            "Exactly 0 HP remains Disabled",
            "func body_inventory_footprint()",
            "return Vector2i(4, 4)",
            "func apply_restraint(",
            "func remove_restraint()",
            "func finish_off()",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_item_instance_state.gd",
        [
            "const INSTANCE_KIND_BODY",
            "var linked_unit_id",
            "var footprint_override",
            "func is_body()",
            "static func create_body(",
            "body_definition.belt_allowed = true",
            "body_definition.backpack_allowed = true",
            'result.display_name_override = "%s\'s Body"',
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_item_location_state.gd",
        [
            "const LOCATION_BODY_ATTACHMENT",
            "const CONTAINER_RESTRAINT",
            "var transport_mode",
            "static func dragged_body(",
            'result.transport_mode = &"dragging"',
            "static func body_attachment(",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_state.gd",
        [
            "var body_unit_ids_by_cell",
            "func body_item_for_unit(",
            "func body_ground_cell(",
            "func dragged_body_cell_snapshot(",
            "func move_dragged_bodies_to_cell(",
            "func restore_dragged_body_cells(",
            "func has_ground_body_at(",
            "func effective_item_weight(",
            "body_unit.body_weight_lb",
            "func item_counts_as_carried_by(",
            "func maximum_drag_weight(",
            "func synchronise_body_items(",
            "func body_item_representation_snapshot()",
            "func restore_body_item_representation(",
            "Dragging %s",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/transactions/tactical_change_set.gd",
        [
            "body_item_representation_snapshot",
            "state.synchronise_body_items(map_definition)",
            "restore_body_item_representation",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/tactical_inventory_transfer_handler.gd",
        [
            "and not item.is_body()",
            "Body items use the ordinary spatial fit rule.",
            "TacticalItemLocationState.dragged_body(",
            "state.effective_item_weight(item)",
            "state.maximum_drag_weight(unit)",
            'return "Carry %s"',
            'return "Drag %s"',
        ],
        failures,
    )
    require_tokens(
        "application/tactical/body/tactical_body_action_handler.gd",
        [
            'const ACTION_LOOT: StringName = &"loot_equipment"',
            'const ACTION_FIRST_AID: StringName = &"administer_first_aid"',
            'const ACTION_FINISH_OFF: StringName = &"finish_off"',
            'const ACTION_UNTIE: StringName = &"untie"',
            "func apply_item_to_body(",
            "item.definition.permits_first_aid",
            "item.definition.permits_administered_healing",
            "return restrain(",
            "func search_body(",
            "func restrain(",
            "func untie(",
            "TacticalItemLocationState.body_attachment",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/life/tactical_life_state_handler.gd",
        [
            "medical_item_id: StringName = &\"\"",
            "medical_item.definition.first_aid_bonus",
            "first_aid_uses_consumed",
            "func administer_healing_item(",
            "permits_administered_healing",
            "healing_amount",
        ],
        failures,
    )
    require_tokens(
        "domain/inventory/definitions/item_definition.gd",
        [
            "@export var permits_first_aid",
            "@export var first_aid_bonus",
            "@export var first_aid_uses_consumed",
            "@export var permits_administered_healing",
            "@export var healing_amount",
            "@export var is_restraint",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/unit_management_window.gd",
        [
            '_body_context_menu.add_item("Loot Equipment", BODY_MENU_LOOT)',
            '_body_context_menu.add_item("Administer First Aid", BODY_MENU_FIRST_AID)',
            '_body_context_menu.add_item("Finish Off", BODY_MENU_FINISH_OFF)',
            '_body_context_menu.add_item("Untie", BODY_MENU_UNTIE)',
            '"Search — drop all to floor"',
            "func _on_item_dropped_onto(",
            "_facade.apply_item_to_body(",
        ],
        failures,
    )
    ui_text = require_file("presentation/tactical/unit_management_window.gd", failures)
    if ui_text:
        start = ui_text.find("func _initialize_body_interaction_ui()")
        end = ui_text.find("\n\nfunc ", start + 1)
        section = ui_text[start:end if end >= 0 else None]
        menu_lines = [line.strip() for line in section.splitlines() if "_body_context_menu.add_item" in line]
        expected = [
            '_body_context_menu.add_item("Loot Equipment", BODY_MENU_LOOT)',
            '_body_context_menu.add_item("Administer First Aid", BODY_MENU_FIRST_AID)',
            '_body_context_menu.add_item("Finish Off", BODY_MENU_FINISH_OFF)',
            '_body_context_menu.add_item("Untie", BODY_MENU_UNTIE)',
        ]
        if menu_lines != expected:
            failures.append("body right-click menu is not the exact locked four-action order")

    require_tokens(
        "presentation/tactical/spatial_inventory_item_control.gd",
        [
            'if instance_kind != &"body"',
            "signal item_dropped_onto(",
        ],
        failures,
    )
    require_tokens(
        "domain/tactical/tactical_navigation_snapshot.gd",
        [
            "has_ground_body_at(cell)",
            "func mover_is_dragging_body()",
            "if mover_is_dragging_body():",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/tactical_command_handler.gd",
        [
            "dragged_body_cell_snapshot(unit.unit_id)",
            "committed_path_result.path.size() - 2",
            "move_dragged_bodies_to_cell(",
            "restore_dragged_body_cells(",
        ],
        failures,
    )
    require_tokens(
        "application/tactical/sprint_move_handler.gd",
        [
            "dragged_body_cell_snapshot(unit.unit_id)",
            "committed_path_result.path.size() - 2",
            "move_dragged_bodies_to_cell(",
            "restore_dragged_body_cells(",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        [
            "body_item_for_unit(unit.unit_id)",
            "body_ground_cell(body_item)",
            "A packed body is a real spatial inventory item and has no ground token.",
            "func _dragged_body_visual_cells(",
            "func _animate_dragged_body_paths(",
        ],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_unit_view.gd",
        [
            "restrained",
            "DAMAGE_REACTION_DURATION: float = 0.8",
            "func play_damage_reaction() -> void:",
        ],
        failures,
    )
    require_tokens(
        "content/items/bandage.tres",
        ["permits_first_aid = true", "first_aid_bonus = 2"],
        failures,
    )
    require_tokens(
        "content/items/rope.tres",
        ["is_restraint = true"],
        failures,
    )
    require_tokens(
        "content/items/minor_healing_potion.tres",
        ["permits_administered_healing = true", "healing_amount = 5"],
        failures,
    )
    require_tokens(
        "application/tactical/ai/enemy_turn_handler.gd",
        [
            "configure_body_actions",
            "_try_untie_adjacent_ally",
            "dragged_body_cell_snapshot(unit.unit_id)",
            "path.path[path.path.size() - 2]",
            "move_dragged_bodies_to_cell(",
            "restore_dragged_body_cells(",
        ],
        failures,
    )
    require_tokens(
        "tests/tactical/stage_4_3_2_body_item_tests.gd",
        [
            "A Disabled character must not create a body item.",
            "A Medium body must consume a real 4×4 Backpack footprint.",
            "Dragging a medical item onto a Dying body must perform First Aid.",
            "Search must preserve each item instance and move it to the body tile.",
            "An adjacent enemy ally must be able to use the same Untie action.",
            "After a multi-tile move, the dragged body must finish in the carrier's penultimate path tile.",
        ],
        failures,
    )
    require_tokens(
        "bootstrap/boot/boot.gd",
        ["Seethe Stage 4.3.2 body items, medical interaction and restraint loaded."],
        failures,
    )

    validate_unique_class_names(failures)
    validate_resource_references(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 4.3.2",
        failures,
        [
            "Fallen characters now use one real non-blocking body item.",
            "Backpack and Hand locations authoritatively mean carrying and dragging.",
            "Medical items, potions and rope use direct item-on-body drag interaction.",
            "Loot, Search, Finish Off and faction-neutral Untie use atomic handlers.",
        ],
    )


if __name__ == "__main__":
    sys.exit(main())
