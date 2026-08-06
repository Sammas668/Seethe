#!/usr/bin/env python3
"""Static contract for the Paint-style contextual Region Authoring UI."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise SystemExit(f"FAIL: {message}")


def forbid(text: str, needle: str, message: str) -> None:
    if needle in text:
        raise SystemExit(f"FAIL: {message}")


def main() -> int:
    screen = (ROOT / "tools/region_authoring/region_authoring_screen.gd").read_text(encoding="utf-8")
    map_view = (ROOT / "tools/region_authoring/authoring_region_map_view.gd").read_text(encoding="utf-8")

    require(screen, "func _build_tool_ribbon()", "The broad top tool ribbon is missing.")
    require(screen, "func _build_context_panel()", "The contextual left panel is missing.")
    require(screen, "func _rebuild_context_panel()", "The left panel does not rebuild for the selected top tool.")
    for label in ("SELECT", "TERRAIN", "ROADS", "BORDERS", "TOWNS", "DISTRICTS", "SITES", "LABELS", "ERASER"):
        require(screen, f'"{label}"', f"Top ribbon tool {label} is missing.")
    forbid(screen, "var _tool_option: OptionButton", "The obsolete duplicate tool dropdown remains.")
    forbid(screen, "func _refresh_tool_palette()", "The obsolete permanent palette system remains.")

    for context in (
        "_build_terrain_context",
        "_build_roads_context",
        "_build_borders_context",
        "_build_towns_context",
        "_build_districts_context",
        "_build_sites_context",
        "_build_labels_context",
        "_build_eraser_context",
    ):
        require(screen, f"func {context}()", f"Contextual panel builder {context} is missing.")

    require(screen, 'panel.custom_minimum_size = Vector2(204, 0)', "The contextual left panel is not compact.")
    require(screen, 'validation_title.text = "VALIDATION"', "Validation is not retained in the right properties panel.")
    require(screen, '_section_label("LAYERS")', "Layer controls are not retained in the right properties panel.")
    require(screen, '_inspector_title.text = "PROPERTIES', "The right panel is not presented as properties.")

    require(screen, "func _build_file_menu() -> MenuButton", "The compact File menu is missing.")
    require(screen, "func _build_export_menu() -> MenuButton", "The compact Export menu is missing.")
    require(screen, 'panel.custom_minimum_size = Vector2(380, 0)', "The right properties panel is not wide enough.")
    require(screen, 'scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED', "The right panel can still collapse into a horizontal sliver.")
    require(screen, 'layer_grid.columns = 1', "The right-panel layer controls are still compressed into two columns.")
    require(screen, '_map_view.custom_minimum_size = Vector2(400, 360)', "The map does not yield enough width for the right panel at 1280 pixels.")
    forbid(screen, '_toolbar_button("NEW"', "The oversized command bar still exposes every file action separately.")
    forbid(screen, '_toolbar_button("EXPORT DATA"', "The oversized command bar still exposes every export action separately.")

    forbid(screen, '"Reference"', "The removed reference layer remains in the Layers panel.")
    forbid(screen, "REFERENCE OVERLAY", "The removed reference overlay controls remain in the right panel.")
    require(screen, 'content.add_child(_section_label("SAVE"))', "The right panel does not expose the simplified save section.")
    require(screen, 'SAVE PROJECT', "The explicit Save Project action is missing.")
    require(screen, 'SAVE FOLDER', "The save-folder shortcut is missing.")

    require(map_view, "var primary_remove_mode: bool", "Contextual Draw/Remove modes are not supported.")
    require(map_view, "var settlement_operation: StringName", "Contextual town operations are not supported.")
    require(map_view, "var district_operation: StringName", "Contextual district operations are not supported.")
    require(map_view, "match settlement_operation:", "Town operation state is not consumed by the canvas.")
    require(map_view, 'district_operation == &"clear"', "District Clear mode is not consumed by the canvas.")

    require(screen, "RoadStylePreview.new()", "The Roads panel does not show visual road-style previews.")
    require(screen, '"Primary Road"', "Primary Road is missing from the contextual Roads palette.")
    require(screen, '"Local Road"', "Local Road is missing from the contextual Roads palette.")
    require(screen, '"Forest Track"', "Forest Track is missing from the contextual Roads palette.")
    forbid(screen, '"Hidden Routes"', "The removed Hidden Routes layer remains in the editor.")
    forbid(screen, "SHOW ADVANCED ROUTES", "The removed advanced route authoring UI remains.")
    forbid(map_view, "TOOL_STRATEGIC_ROUTE", "The removed strategic-route tool remains in the canvas.")

    print("PASS: responsive Paint-style authoring layout and contextual options validated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
