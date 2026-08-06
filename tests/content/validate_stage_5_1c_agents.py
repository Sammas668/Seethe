#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
from collections import defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGION = ROOT / "content/regions/life_starter"


def main() -> int:
    failures: list[str] = []
    required = [
        ROOT / "domain/strategic/agent_state.gd",
        ROOT / "domain/strategic/agent_travel_plan.gd",
        ROOT / "domain/strategic/agent_discovery_candidate.gd",
        ROOT / "application/strategic/agent_service.gd",
        ROOT / "application/strategic/region_boundary_pathfinder.gd",
        ROOT / "domain/campaign/campaign_state.gd",
        ROOT / "bootstrap/app/campaign_session.gd",
        ROOT / "presentation/campaign/campaign_shell.gd",
        ROOT / "presentation/campaign/widgets/region_map_view.gd",
        ROOT / "presentation/campaign/icons/agent_ready.svg",
        ROOT / "presentation/campaign/icons/agent_deployed.svg",
        ROOT / "presentation/campaign/icons/agent_travelling.svg",
        ROOT / "presentation/campaign/icons/agent_preview.svg",
        ROOT / "presentation/campaign/icons/agent_blocked.svg",
    ]
    for path in required:
        if not path.is_file():
            failures.append(f"missing Stage 5.1c polish file: {path.relative_to(ROOT)}")
    if failures:
        return finish(failures)

    state = (ROOT / "domain/campaign/campaign_state.gd").read_text(encoding="utf-8")
    for token in [
        "CURRENT_SAVE_VERSION: int =",
        "var agents_by_id",
        'base["agents"]',
        'data.get("agents"',
        "agent.validate_state()",
    ]:
        if token not in state:
            failures.append(f"CampaignState lacks Agent persistence token: {token}")

    new_campaign = (ROOT / "application/campaign/new_campaign_service.gd").read_text(encoding="utf-8")
    if "_add_starting_agent(campaign)" not in new_campaign:
        failures.append("New Campaign does not create the starting Agent")
    if "ActiveMissionState.new()" in new_campaign:
        failures.append("New Campaign still creates the Farm Raid before Agent discovery")

    agent_state = (ROOT / "domain/strategic/agent_state.gd").read_text(encoding="utf-8")
    for token in [
        "pending_discovery_event_id",
        "last_resolved_arrival_plan_id",
        "last_resolved_discovery_event_id",
        "discovery_attempt_sequence",
        "discovery_seed",
    ]:
        if token not in agent_state:
            failures.append(f"AgentState lacks exact-once token: {token}")

    travel_plan = (ROOT / "domain/strategic/agent_travel_plan.gd").read_text(encoding="utf-8")
    for token in [
        "direction_at_tick",
        "map_position_at_tick",
        "direction_at_time",
        "map_position_at_time",
        "progress_at_time",
        "discovery_seed",
        "cumulative_minutes",
    ]:
        if token not in travel_plan:
            failures.append(f"AgentTravelPlan lacks polish token: {token}")

    candidate = (ROOT / "domain/strategic/agent_discovery_candidate.gd").read_text(encoding="utf-8")
    for token in [
        "class_name AgentDiscoveryCandidate",
        "mission_definition_id",
        "eligibility_priority",
        "exclusion_reasons",
        "is_eligible",
    ]:
        if token not in candidate:
            failures.append(f"Agent discovery candidate lacks token: {token}")

    agent_service = (ROOT / "application/strategic/agent_service.gd").read_text(encoding="utf-8")
    for token in [
        "MIN_DISCOVERY_DELAY_MINUTES",
        "MAX_DISCOVERY_DELAY_MINUTES",
        "MAX_ACTIVE_AGENT_MISSIONS",
        "RegionBoundaryPathfinder.build_plan",
        "STATUS_TRAVELLING",
        "STATUS_DEPLOYED",
        "pending_discovery_event_id",
        "eligible_discovery_candidates",
        "AgentDiscoveryCandidate.new()",
        "mission.site_id = candidate.site_id",
        "_schedule_discovery",
        "_deployment_seed",
    ]:
        if token not in agent_service:
            failures.append(f"AgentService lacks required behaviour token: {token}")

    shell = (ROOT / "presentation/campaign/campaign_shell.gd").read_text(encoding="utf-8")
    shell_lower = shell.lower()
    if ".icon_max_width =" in shell:
        failures.append(
            "Button icon_max_width was assigned as an object property; "
            "it must be a theme constant override"
        )
    if 'add_theme_constant_override("icon_max_width", 34)' not in shell:
        failures.append("Agent button does not apply icon_max_width as a theme constant")
    forbidden_visible_timing = [
        "next report",
        "arrival time",
        "establishment time",
        "mission probability",
        "discovery progress",
    ]
    for phrase in forbidden_visible_timing:
        if phrase in shell_lower:
            failures.append(f"campaign UI exposes forbidden Agent timing text: {phrase}")

    session = (ROOT / "bootstrap/app/campaign_session.gd").read_text(encoding="utf-8")
    for token in [
        "signal agent_mission_discovered",
        "preview_agent_route",
        "dispatch_agent",
        "agent_service.advance_candidate",
        "pause_clock()",
    ]:
        if token not in session:
            failures.append(f"CampaignSession lacks Agent integration token: {token}")

    for token in [
        '_agent_button.text = "AGENT"',
        "_on_agent_button_pressed",
        "set_agent_preview_mode",
        "agent_destination_confirmed",
        "_on_agent_mission_discovered",
        "focus_site(mission.site_id, true)",
        "AGENT_BUTTON_READY_AT_STRONGHOLD",
        "AGENT_BUTTON_DEPLOYED",
        "AGENT_BUTTON_TRAVELLING",
        "AGENT_BUTTON_PREVIEW_ACTIVE",
        "AGENT_BUTTON_BLOCKED_BY_MODAL",
        "AGENT_ICON_READY",
        "AGENT_ICON_DEPLOYED",
        "AGENT_ICON_TRAVELLING",
        "AGENT_ICON_PREVIEW",
        "AGENT_ICON_BLOCKED",
        "_apply_agent_button_state",
        "Unavailable while the mission report is open",
        'title.text = "NEW OPPORTUNITY"',
    ]:
        if token not in shell:
            failures.append(f"campaign shell lacks Agent polish token: {token}")
    for forbidden in ["AgentPanel", "agent_panel", "LOCAL ACTIONS", "NEXT REPORT"]:
        if forbidden in shell:
            failures.append(f"unnecessary Agent management UI remains: {forbidden}")

    view = (ROOT / "presentation/campaign/widgets/region_map_view.gd").read_text(encoding="utf-8")
    for token in [
        "signal agent_destination_confirmed",
        "_agent_preview_mode",
        "_update_agent_preview",
        "_draw_agent_destination_preview",
        "_agent_preview_invalid_reason",
        "_draw_agent_route",
        "_draw_agent_token",
        "direction_at_time",
        "map_position_at_time",
        "_visual_campaign_tick",
        "set_strategic_speed",
        "_draw_agent_coverage",
        "mark_mission_new",
        "acknowledge_mission_at_site",
        "_focus_map_unit",
        "MOUSE_BUTTON_RIGHT",
        "Geometry2D.is_point_in_polygon",
        "show_agent_debug",
    ]:
        if token not in view:
            failures.append(f"RegionMapView lacks Agent preview/polish token: {token}")

    if "map_position += Vector2(0.16, -0.10)" in view:
        failures.append("Deployed Agent still uses an off-centre presentation offset")

    pathfinder = (ROOT / "application/strategic/region_boundary_pathfinder.gd").read_text(encoding="utf-8")
    for token in [
        "hex_corners",
        "_segment_key",
        "PRIMARY_ROAD",
        "LOCAL_ROAD",
        "FOREST_TRACK",
        "RegionTerrainType.LAKE",
        "_graph_cache_by_key",
        "debug_navigation_segments",
        "route_points.append",
        "MIN_CONNECTOR_MINUTES",
        "_connector_minutes(definition, origin)",
        "_connector_minutes(definition, destination)",
        "_terrain_minutes",
    ]:
        if token not in pathfinder:
            failures.append(f"boundary pathfinder lacks token: {token}")

    project_settings = (ROOT / "project.godot").read_text(encoding="utf-8")
    if "development/show_agent_debug=false" not in project_settings:
        failures.append("Agent debug overlay is not disabled by default")

    metadata = json.loads((REGION / "life_starter_region.json").read_text(encoding="utf-8"))
    sites = json.loads((REGION / "life_starter_region_sites.json").read_text(encoding="utf-8"))["sites"]
    site_by_id = {site["id"]: site for site in sites}
    stronghold_id = metadata.get("fifth_god_ruin_site_id")
    if stronghold_id not in site_by_id:
        failures.append("production region has no authored Fifth-God stronghold for Agent departure")
    if "site.farm.starter_storehouse" not in site_by_id:
        failures.append("production region has no starter farm for Agent discovery")

    with (REGION / "life_starter_region_hexes.csv").open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    terrain = {(int(r["offset_col"]), int(r["offset_row"])): r["terrain"] for r in rows}
    if stronghold_id in site_by_id:
        coord = tuple(site_by_id[stronghold_id]["coord"])
        if terrain.get(coord) != "deep_forest":
            failures.append("Agent departure stronghold is not in deep forest")
    if not boundary_graph_connected(rows):
        failures.append("playable land boundary graph is disconnected; Agent routes cannot span the region")

    return finish(failures)


def boundary_graph_connected(rows: list[dict[str, str]]) -> bool:
    playable = {
        (int(row["offset_col"]), int(row["offset_row"])): row["terrain"]
        for row in rows
        if row["playable"].lower() == "true"
    }
    sqrt3 = math.sqrt(3.0)

    def center(c: tuple[int, int]) -> tuple[float, float]:
        col, row = c
        return 1.5 * col, (row + (0.5 if col % 2 == 0 else 0.0)) * sqrt3

    def key(point: tuple[float, float]) -> tuple[int, int]:
        return round(point[0] * 100000), round(point[1] * 100000)

    segments: dict[tuple, list[str]] = defaultdict(list)
    for coord, terrain in playable.items():
        cx, cy = center(coord)
        corners = [
            (cx + math.cos(math.radians(i * 60)), cy + math.sin(math.radians(i * 60)))
            for i in range(6)
        ]
        for i in range(6):
            a, b = key(corners[i]), key(corners[(i + 1) % 6])
            segment = tuple(sorted((a, b)))
            segments[segment].append(terrain)
    graph: dict[tuple[int, int], set[tuple[int, int]]] = defaultdict(set)
    for (a, b), terrains in segments.items():
        if len(terrains) < 2 or all(t == "lake" for t in terrains):
            continue
        graph[a].add(b)
        graph[b].add(a)
    if not graph:
        return False
    start = next(iter(graph))
    seen = {start}
    queue = deque([start])
    while queue:
        current = queue.popleft()
        for nxt in graph[current]:
            if nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)
    return len(seen) == len(graph)


def finish(failures: list[str]) -> int:
    if failures:
        print("Stage 5.1c Agent validation FAILED:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 5.1c Agent polish validation PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
