#!/usr/bin/env python3
"""Static contract validation for the Stage 5.1a Region Authoring Tool."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def require_file(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        fail(f"Missing required file: {relative}")
    return path.read_text(encoding="utf-8")


def require(text: str, needle: str, description: str) -> None:
    if needle not in text:
        fail(description)


def forbid(text: str, needle: str, description: str) -> None:
    if needle in text:
        fail(description)


def main() -> int:
    screen = require_file("tools/region_authoring/region_authoring_screen.gd")
    map_view = require_file("tools/region_authoring/authoring_region_map_view.gd")
    document = require_file("tools/region_authoring/region_authoring_document.gd")
    serializer = require_file("tools/region_authoring/region_authoring_serializer.gd")
    exporter = require_file("tools/region_authoring/region_export_service.gd")
    validation = require_file("tools/region_authoring/region_validation_service.gd")
    symbols = require_file("domain/regions/region_symbol_catalogue.gd")
    menu = require_file("presentation/campaign/main_menu.gd")
    app = require_file("bootstrap/app/game_app.gd")
    project = require_file("project.godot")
    renderer = require_file("presentation/campaign/widgets/region_map_view.gd")
    require_file("tools/region_authoring/region_authoring_screen.tscn")
    require(project, "development/enable_region_authoring=true", "Region authoring is not gated by the development project setting.")
    require(menu, "region_authoring_requested", "Main menu does not expose the development-only authoring request.")
    require(app, "REGION_AUTHORING_SCENE", "GameApp does not compose the authoring screen.")

    terrain_types = require_file("domain/regions/region_terrain_type.gd")
    require(screen, "RegionTerrainType.ALL", "The Terrain palette is not populated from the authoritative terrain catalogue.")
    for terrain in ("GRASSLAND", "FARMLAND", "LAKE", "MARSH", "FOREST", "DEEP_FOREST"):
        require(terrain_types, terrain, f"Terrain authoring is missing {terrain}.")

    require(map_view, "_apply_edge(position, true", "Road editing is not edge-based.")
    require(map_view, "_apply_edge(position, false", "Border editing is not edge-based and separate from roads.")
    require(document, "road_edges_by_id if is_road else region.border_edges_by_id", "Road and border collections are not independent.")
    require(map_view, "_road_would_touch_stronghold", "The public-road stronghold safeguard is missing.")
    require(validation, "A public road touches the concealed Fifth-God stronghold", "Stronghold public-road validation is missing.")

    require(document, "toggle_settlement_footprint", "Multi-hex settlement footprint editing is missing.")
    require(document, "assign_district", "Per-hex district assignment is missing.")
    for symbol in (
        "WHEAT_WAREHOUSE",
        "LUMBERMILL",
        "TEXTILES_WAREHOUSE",
        "CRAFTSMANS_DISTRICT",
        "GUILD_HOUSE",
        "NOBLE_HOUSING",
    ):
        require(symbols, symbol, f"The exact source-key district symbol {symbol} is missing.")
        require(renderer, f"RegionSymbolCatalogue.{symbol}", f"The campaign renderer does not use {symbol} deterministically.")

    forbid(screen, "REFERENCE OVERLAY", "The removed reference overlay remains in the editor UI.")
    forbid(screen, "_texture_from_path", "The removed reference-image loader remains in the editor.")
    forbid(document, "reference_overlay", "Reference overlay state remains in the authoring document format.")
    forbid(renderer, "_draw_reference_overlay", "The campaign renderer still contains the removed reference layer.")

    require(screen, "UNDO", "Undo is missing from the authoring toolbar.")
    require(screen, "REDO", "Redo is missing from the authoring toolbar.")
    require(serializer, "DEFAULT_AUTOSAVE_PATH", "Authoring recovery-copy support is missing.")
    require(serializer, "save_working_document", "The explicit working-document save flow is missing.")
    require(serializer, "preferred_working_path", "The editor does not remember the last working document.")
    require(serializer, "recovery_path_for", "Recovery copies are not tied to the current working file.")
    require(serializer, "authoring_save_verify_failed", "Authoring saves are not verified before replacement.")
    require(screen, "_load_saved_working_document", "The saved working document is not loaded automatically.")
    require(screen, "RegionAuthoringSerializer.document_exists(_working_path)", "Startup does not prefer the existing working document.")
    require(screen, "if _dirty and not _save_working()", "Close/open operations do not protect unsaved edits.")
    require(screen, "OPEN SAVE FOLDER", "The save location is not directly accessible from the editor.")
    require(screen, "RECOVERY SAVED", "Recovery-copy status is not visible to the developer.")

    require(validation, "_validate_settlements", "Settlement validation is missing.")
    require(validation, "_validate_sites", "Site validation is missing.")
    require(validation, "_validate_edges", "Edge validation is missing.")
    require(screen, "_on_validation_item_activated", "Validation messages are not clickable.")

    require(exporter, "ZIPPacker", "Data-only ZIP export is missing.")
    require(exporter, "rendered_preview.png", "Export bundles do not contain a rendered preview.")
    require(exporter, "validation_report.txt", "Export bundles do not contain a validation report.")
    require(exporter, "checksums.txt", "Export bundles do not contain checksums.")
    require(exporter, "manifest.json", "Export bundles do not contain a format manifest.")

    forbid(document, "create_strategic_route", "Removed hidden strategic route authoring remains in the document.")
    forbid(map_view, "TOOL_STRATEGIC_ROUTE", "Removed strategic-route canvas tool remains.")
    require(map_view, "TOOL_SUBREGION", "The subregion paint tool is missing.")
    require(renderer, "_build_edge_paths", "Roads and borders are not assembled into continuous paths.")
    require(renderer, "_draw_round_path", "Continuous paths do not use smooth joined rendering.")
    require(renderer, "func _draw_road_pass", "Road rendering is not batched into shared material passes.")
    require(renderer, 'for pass_id: StringName in [&"underlay", &"surface", &"detail"]', "Road underlays can still clip surfaces at shared endpoints.")
    require(renderer, "_draw_road_path_pass", "Road material-pass rendering helper is missing.")
    require(renderer, "_shared_border_shift", "Road-border shared edges are not offset for readability.")
    require(renderer, "RegionRoadType.PRIMARY_ROAD", "Primary-road rendering is missing.")
    require(renderer, "RegionRoadType.LOCAL_ROAD", "Local-road rendering is missing.")
    require(renderer, "RegionRoadType.FOREST_TRACK", "Forest-track rendering is missing.")

    tool_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / "tools/region_authoring").glob("*.gd")
    )
    for forbidden in ("CampaignStateStore", "CampaignRepository", "StrategicClockService"):
        forbid(tool_sources, forbidden, f"The authoring tool improperly depends on live campaign state: {forbidden}.")

    print("PASS: Stage 5.1a Region Authoring Tool static contract validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
