#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGION_DIR = ROOT / "content/regions/life_starter"

VALID_TERRAIN = {
    "grassland",
    "farmland",
    "lake",
    "marsh",
    "forest",
    "deep_forest",
}
REQUIRED_SETTLEMENTS = {
    "site.settlement.telluria",
    "site.settlement.westmarch",
    "site.settlement.bellmare",
    "site.settlement.crullfeld",
    "site.settlement.barnemouth",
    "site.settlement.solis",
    "site.settlement.torrine",
    "site.settlement.dornwich",
    "site.settlement.laencaster",
    "site.settlement.lullin",
    "site.settlement.oakstead",
    "site.settlement.balerno",
    "site.settlement.dalry",
    "site.settlement.ascot",
}
EXPECTED_FOOTPRINTS = {
    "site.settlement.telluria": {
        (9, 6), (8, 6), (10, 6), (9, 7), (8, 7), (10, 7), (9, 8)
    },
    "site.settlement.westmarch": {(3, 4), (4, 4), (3, 5)},
    "site.settlement.solis": {(16, 3), (16, 4), (17, 4)},
    "site.settlement.oakstead": {(12, 11), (11, 12), (12, 12)},
}
REQUIRED_TELLURIA_DISTRICTS = {
    "site.telluria.wheat_warehouse",
    "site.telluria.lumbermill",
    "site.telluria.textiles_warehouse",
    "site.telluria.craftsman_district",
    "site.telluria.guild_house",
    "site.telluria.noble_housing",
    "site.telluria.east_merchant_quarter",
}
EXPECTED_ROAD_EDGE_COUNT = 304
EXPECTED_BORDER_EDGE_COUNT = 79


def axial(col: int, row: int) -> tuple[int, int]:
    return col, row - ((col + (col & 1)) // 2)


def adjacent(a: tuple[int, int], b: tuple[int, int]) -> bool:
    aq, ar = axial(*a)
    bq, br = axial(*b)
    ac = (aq, -aq - ar, ar)
    bc = (bq, -bq - br, br)
    return max(abs(ac[i] - bc[i]) for i in range(3)) == 1


def physical_edge_key(entry: dict) -> tuple:
    coord = tuple(entry["coord"])
    neighbour = entry.get("neighbour_coord")
    if neighbour:
        return tuple(sorted((coord, tuple(neighbour))))
    return coord + (int(entry["edge_index"]),)


def main() -> int:
    failures: list[str] = []
    required_files = [
        REGION_DIR / "life_starter_region.json",
        REGION_DIR / "life_starter_region_hexes.csv",
        REGION_DIR / "life_starter_region_sites.json",
        REGION_DIR / "life_starter_region_road_edges.json",
        REGION_DIR / "life_starter_region_border_edges.json",
        ROOT / "domain/regions/region_map_definition.gd",
        ROOT / "domain/regions/region_map_edge_definition.gd",
        ROOT / "application/regions/region_definition_registry.gd",
        ROOT / "infrastructure/content/regions/life_starter_region_factory.gd",
    ]
    for path in required_files:
        if not path.is_file():
            failures.append(f"missing required corrected Stage 5.1a file: {path.relative_to(ROOT)}")
    if failures:
        return finish(failures)

    metadata = json.loads((REGION_DIR / "life_starter_region.json").read_text(encoding="utf-8"))
    sites_data = json.loads((REGION_DIR / "life_starter_region_sites.json").read_text(encoding="utf-8"))
    road_data = json.loads((REGION_DIR / "life_starter_region_road_edges.json").read_text(encoding="utf-8"))
    border_data = json.loads((REGION_DIR / "life_starter_region_border_edges.json").read_text(encoding="utf-8"))
    with (REGION_DIR / "life_starter_region_hexes.csv").open(encoding="utf-8", newline="") as handle:
        hex_rows = list(csv.DictReader(handle))

    if metadata.get("id") != "region.life.starter":
        failures.append("starter region does not use region.life.starter")
    if (metadata.get("width"), metadata.get("height")) != (20, 15):
        failures.append("starter region is not 20 hexes wide by 15 high")
    if len(hex_rows) != 300:
        failures.append(f"hex transcription contains {len(hex_rows)} rows instead of 300")

    seen_coords: set[tuple[int, int]] = set()
    terrain_by_coord: dict[tuple[int, int], str] = {}
    valid_subregions = {entry["id"] for entry in metadata.get("subregions", [])}
    for row in hex_rows:
        coord = (int(row["offset_col"]), int(row["offset_row"]))
        if coord in seen_coords:
            failures.append(f"duplicate hex coordinate {coord}")
        seen_coords.add(coord)
        if not (0 <= coord[0] < 20 and 0 <= coord[1] < 15):
            failures.append(f"hex coordinate outside authored map: {coord}")
        if row["terrain"] not in VALID_TERRAIN:
            failures.append(f"hex {coord} has invalid terrain {row['terrain']}")
        if row["subregion"] not in valid_subregions:
            failures.append(f"hex {coord} has unknown subregion {row['subregion']}")
        if row["playable"].lower() != "true":
            failures.append(f"authored starter hex {coord} is not playable")
        terrain_by_coord[coord] = row["terrain"]

    sites = sites_data.get("sites", [])
    site_ids = [entry.get("id", "") for entry in sites]
    if len(site_ids) != len(set(site_ids)):
        failures.append("region site IDs are not unique")
    site_by_id = {entry["id"]: entry for entry in sites}
    settlements = {entry["id"] for entry in sites if entry.get("site_type") == "settlement"}
    if settlements != REQUIRED_SETTLEMENTS:
        failures.append(
            "settlement catalogue does not contain exactly the fourteen authored settlements: "
            f"missing={sorted(REQUIRED_SETTLEMENTS - settlements)}, extra={sorted(settlements - REQUIRED_SETTLEMENTS)}"
        )
    if not REQUIRED_TELLURIA_DISTRICTS.issubset(site_by_id):
        failures.append(
            f"Telluria district sub-sites missing: {sorted(REQUIRED_TELLURIA_DISTRICTS - set(site_by_id))}"
        )
    if metadata.get("main_settlement_site_id") != "site.settlement.telluria":
        failures.append("Telluria is not the main settlement")

    for site_id, site in site_by_id.items():
        coord = tuple(site.get("coord", []))
        if len(coord) != 2 or coord not in terrain_by_coord:
            failures.append(f"site {site_id} is not on a valid playable hex")
        footprint = {tuple(value) for value in site.get("footprint", [])}
        for footprint_coord in footprint:
            if footprint_coord not in terrain_by_coord:
                failures.append(f"site {site_id} has invalid footprint hex {footprint_coord}")
        if site.get("subregion_id") not in valid_subregions:
            failures.append(f"site {site_id} references an invalid subregion")
        parent = site.get("parent_settlement_id", "")
        if parent and parent not in site_by_id:
            failures.append(f"site {site_id} references missing parent {parent}")

    for settlement_id, expected in EXPECTED_FOOTPRINTS.items():
        actual = {tuple(value) for value in site_by_id[settlement_id].get("footprint", [])}
        if actual != expected:
            failures.append(
                f"{settlement_id} footprint differs from the reference: expected={sorted(expected)}, actual={sorted(actual)}"
            )

    ruin_id = metadata.get("fifth_god_ruin_site_id")
    stronghold = site_by_id.get(ruin_id)
    ancient_ruin = site_by_id.get("site.wilderness.deep_forest_ruins")
    if not stronghold:
        failures.append("Fifth-God stronghold is missing")
    if not ancient_ruin or ancient_ruin.get("site_type") != "ruin":
        failures.append("the separate ancient forest ruin is missing")
    if stronghold and ancient_ruin:
        stronghold_coord = tuple(stronghold["coord"])
        ancient_coord = tuple(ancient_ruin["coord"])
        if stronghold_coord == ancient_coord:
            failures.append("the Fifth-God stronghold and ancient forest ruin share a coordinate")
        if terrain_by_coord.get(stronghold_coord) != "deep_forest":
            failures.append("Fifth-God stronghold is not fixed inside deep forest")
        if terrain_by_coord.get(ancient_coord) != "deep_forest":
            failures.append("ancient forest ruin is not inside deep forest")

    road_edges = road_data.get("road_edges", [])
    border_edges = border_data.get("border_edges", [])
    if len(road_edges) != EXPECTED_ROAD_EDGE_COUNT:
        failures.append(
            f"public road transcription has {len(road_edges)} segments; expected {EXPECTED_ROAD_EDGE_COUNT}"
        )
    if len(border_edges) != EXPECTED_BORDER_EDGE_COUNT:
        failures.append(
            f"subregional border transcription has {len(border_edges)} segments; expected {EXPECTED_BORDER_EDGE_COUNT}"
        )
    for name, entries in (("road", road_edges), ("border", border_edges)):
        ids = [entry.get("id", "") for entry in entries]
        if len(ids) != len(set(ids)):
            failures.append(f"{name} edge IDs are not unique")
        keys = [physical_edge_key(entry) for entry in entries]
        if len(keys) != len(set(keys)):
            failures.append(f"{name} edge transcription contains duplicate physical segments")
        for entry in entries:
            coord = tuple(entry.get("coord", []))
            edge_index = int(entry.get("edge_index", -1))
            if coord not in terrain_by_coord:
                failures.append(f"{name} edge {entry.get('id')} starts outside the map")
            if edge_index not in range(6):
                failures.append(f"{name} edge {entry.get('id')} has invalid edge index {edge_index}")
            neighbour = entry.get("neighbour_coord")
            if neighbour and (tuple(neighbour) not in terrain_by_coord or not adjacent(coord, tuple(neighbour))):
                failures.append(f"{name} edge {entry.get('id')} has an invalid neighbour")

    if stronghold:
        stronghold_coord = tuple(stronghold["coord"])
        for edge in road_edges:
            coords = {tuple(edge["coord"])}
            if edge.get("neighbour_coord"):
                coords.add(tuple(edge["neighbour_coord"]))
            if stronghold_coord in coords:
                failures.append("a visible public road is connected to the Fifth-God stronghold")
                break

    if "stronghold_approach_route_ids" in metadata:
        failures.append("removed hidden stronghold approach metadata remains")
    if (REGION_DIR / "life_starter_region_routes.json").exists():
        failures.append("removed hidden route data file remains")
    for site in sites:
        if "route_connection_ids" in site:
            failures.append(f"site {site.get('id')} still stores removed route connections")
        if "STRONGHOLD_APPROACH" in site.get("tags", []):
            failures.append(f"site {site.get('id')} still carries a hidden-route tag")

    valid_road_classes = {"primary_road", "local_road", "forest_track"}
    for edge in road_edges:
        if edge.get("road_class") not in valid_road_classes:
            failures.append(f"road edge {edge.get('id')} has invalid road class {edge.get('road_class')}")

    starter_farm = site_by_id.get("site.farm.starter_storehouse")
    if not starter_farm or "mission_definition.life.farm_storehouse_raid_01" not in starter_farm.get("mission_definition_ids", []):
        failures.append("Farm Raid is not anchored to the authored starter storehouse")

    campaign_service = (ROOT / "application/campaign/new_campaign_service.gd").read_text(encoding="utf-8")
    agent_service = (ROOT / "application/strategic/agent_service.gd").read_text(encoding="utf-8")
    if '&"region.life.starter"' not in campaign_service:
        failures.append("new campaigns do not reference the authored starter region by ID")
    if '&"site.farm.starter_storehouse"' not in agent_service:
        failures.append("Agent discovery does not anchor the Farm Raid to its authored site")

    shell = (ROOT / "presentation/campaign/campaign_shell.gd").read_text(encoding="utf-8")
    view = (ROOT / "presentation/campaign/widgets/region_map_view.gd").read_text(encoding="utf-8")
    factory = (ROOT / "infrastructure/content/regions/life_starter_region_factory.gd").read_text(encoding="utf-8")
    for token in ["current_region_definition", "_region_map_view.configure", "selection_cleared"]:
        if token not in shell:
            failures.append(f"campaign shell lacks authored-region integration token: {token}")
    for token in [
        "_draw_hex_fills",
        "_draw_terrain_symbols",
        "_draw_road_edges",
        "_draw_subregion_borders",
        "_build_edge_paths",
        "_draw_round_path",
        "_shared_border_shift",
        "_draw_settlement_footprint_pads",
        "_draw_ruin_marker",
    ]:
        if token not in view:
            failures.append(f"RegionMapView lacks corrected rendering token: {token}")
    for token in ["REGION_ROAD_EDGES_PATH", "REGION_BORDER_EDGES_PATH", "_load_map_edges"]:
        if token not in factory:
            failures.append(f"LifeStarterRegionFactory lacks corrected edge-data loading token: {token}")
    if "_draw_routes" in view or "_draw_strategic_routes" in view:
        failures.append("RegionMapView still draws removed route paths")
    if "REGION_ROUTES_PATH" in factory or "_load_routes" in factory:
        failures.append("LifeStarterRegionFactory still loads removed hidden route data")

    forbidden_state = ["agent", "notoriety", "mission_expiry"]
    region_domain = "\n".join(
        path.read_text(encoding="utf-8", errors="ignore").lower()
        for path in (ROOT / "domain/regions").glob("*.gd")
    )
    for token in forbidden_state:
        if token in region_domain:
            failures.append(f"Stage 5.1a region domain introduces later-stage state: {token}")

    return finish(failures)


def finish(failures: list[str]) -> int:
    if failures:
        print("Stage 5.1a reference-correction validation FAILED:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 5.1a reference-correction validation PASSED.")
    print(" - edge-authored roads and borders remain separate and render as continuous paths")
    print(" - hidden strategic routes are removed; the stronghold remains off-road")
    print(" - Telluria, Westmarch, Solis and Oakstead use corrected multi-hex footprints")
    print(" - terrain, district and ruin rendering use the corrected map contracts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
