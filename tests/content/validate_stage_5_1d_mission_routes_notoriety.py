#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def require(path: str, tokens: list[str], failures: list[str]) -> str:
    target = ROOT / path
    if not target.is_file():
        failures.append(f"missing {path}")
        return ""
    text = target.read_text(encoding="utf-8")
    for token in tokens:
        if token not in text:
            failures.append(f"{path} missing token: {token}")
    return text


def main() -> int:
    failures: list[str] = []
    require("domain/missions/active_mission_state.gd", [
        "STATUS_EN_ROUTE", "expiry_tick", "expiry_suspended_tick",
        "remaining_availability_at_dispatch", "func can_expire",
    ], failures)
    require("application/strategic/mission_lifecycle_service.gd", [
        "DEFAULT_MINIMUM_AVAILABILITY_MINUTES", "advance_candidate",
        "STATUS_EXPIRED", "resolved_strategic_event_ids",
    ], failures)
    require("application/strategic/squad_visibility_service.gd", [
        "CharacterVisibilitySnapshot", "SquadVisibilitySnapshot",
        '"Visible armour"', '"Conspicuous weapon"', "travel_multiplier",
    ], failures)
    require("application/strategic/squad_route_planning_service.gd", [
        "MAXIMUM_DETOUR_MULTIPLIER", "waypoints", "repeated_segment",
        "RegionBoundaryPathfinder.build_plan",
    ], failures)
    require("application/strategic/travel_notoriety_service.gd", [
        "CATEGORY_DEEP_WILDERNESS", "CATEGORY_OPEN_FARMLAND",
        "CATEGORY_PRIMARY_ROAD", "CATEGORY_OCCUPIED_VILLAGE",
        "CATEGORY_REGIONAL_CAPITAL_DISTRICT", "build_exposure_entries",
    ], failures)
    require("application/strategic/squad_travel_service.gd", [
        "TravelNotorietyReport", "completion_tick", "STATUS_IN_TACTICAL",
        "create_if_threshold_crossed",
    ], failures)
    require("application/strategic/regional_retaliation_service.gd", [
        "DEFAULT_RAID_THRESHOLD: int = 150", "active_raid",
        "create_if_threshold_crossed", "_highest_subregion",
    ], failures)
    require("domain/campaign/campaign_state.gd", [
        "CURRENT_SAVE_VERSION: int =", "subregion_notoriety_by_region",
        "squad_travel_operations_by_id", "raid_operations_by_id",
        "resolved_strategic_event_ids",
    ], failures)
    require("application/missions/campaign_mission_coordinator.gd", [
        "register_squad_for_travel", "STATUS_EN_ROUTE",
        "expiry_suspended_tick", "save_safe_checkpoint",
        "SquadTravelOperationState.new()",
    ], failures)
    shell = require("presentation/campaign/campaign_shell.gd", [
        "PLAN ROUTE", "SEND SQUAD", "SQUAD VISIBILITY",
        "INDIVIDUAL VISIBILITY", "REGIONAL RETALIATION",
        "_route_planning_active", "_build_regional_retaliation_bar",
        "Strategic time and mission expiry remain paused",
        "if _route_planning_active:", "mission.is_available()",
    ], failures)
    for forbidden in ["hidden threat", "discovery percentage", "mission probability"]:
        if forbidden in shell.lower():
            failures.append(f"campaign shell exposes forbidden concept: {forbidden}")
    for compact_token in [
        "Vector2(360, 56)",
        "Vector2(-180, -72)",
        "Vector2(320, 10)",
        "var content := VBoxContainer.new()",
        '"REGIONAL RETALIATION\\n%d / %d"',
    ]:
        if compact_token not in shell:
            failures.append(f"campaign shell missing compact retaliation HUD token: {compact_token}")
    if "_retaliation_breakdown_label" in shell:
        failures.append("campaign shell still permanently renders local subregion Notoriety breakdown")
    require("presentation/campaign/widgets/region_map_view.gd", [
        "signal squad_waypoint_added", "set_squad_route_mode",
        "_draw_squad_route", "_draw_squad_token",
        "SquadTravelOperationState.STATUS_TRAVELLING",
        "elif _squad_route_mode:", "_update_squad_route_preview",
        "squad_waypoint_added.emit", "squad_waypoint_removed.emit",
    ], failures)
    require("bootstrap/app/campaign_session.gd", [
        "mission_lifecycle_service.advance_candidate",
        "squad_travel_service.advance_candidate", "dispatch_squad",
        "signal squad_arrived", "signal mission_expired",
        "signal travel_notoriety_applied", "signal raid_operation_created",
    ], failures)
    require("tests/integration/stage_5_1d_mission_routes_notoriety_tests.gd", [
        "mission.can_expire()", "preview_squad_operation", "dispatch_squad",
        "RegionalRetaliationService.new()", "duplicate active raid",
    ], failures)
    require("tests/integration/run_stage_5_1d_tests.gd", [
        "Stage51dMissionRoutesNotorietyTests.run()",
        "Stage51cAgentTests.run()",
    ], failures)
    if failures:
        print("Stage 5.1d mission route and Notoriety validation FAILED")
        for failure in failures:
            print(" -", failure)
        return 1
    print("Stage 5.1d mission route and Notoriety validation PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
