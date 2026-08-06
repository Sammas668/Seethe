#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    failures: list[str] = []
    plan = (ROOT / "domain/strategic/agent_travel_plan.gd").read_text(encoding="utf-8")
    view = (ROOT / "presentation/campaign/widgets/region_map_view.gd").read_text(encoding="utf-8")
    shell = (ROOT / "presentation/campaign/campaign_shell.gd").read_text(encoding="utf-8")
    session = (ROOT / "bootstrap/app/campaign_session.gd").read_text(encoding="utf-8")
    runtime = (ROOT / "tests/integration/stage_5_1c_agent_tests.gd").read_text(encoding="utf-8")

    for token in [
        "func progress_at_time(campaign_time: float)",
        "func map_position_at_time(campaign_time: float)",
        "func direction_at_time(campaign_time: float)",
        "return map_position_at_time(float(campaign_tick))",
        "return direction_at_time(float(campaign_tick))",
    ]:
        if token not in plan:
            failures.append(f"AgentTravelPlan lacks smooth interpolation token: {token}")

    for token in [
        "var _visual_campaign_tick: float",
        "var _strategic_speed: int",
        "var _agent_walk_phase: float",
        "func set_strategic_speed(speed: int)",
        "_visual_campaign_tick += delta * float(_strategic_speed)",
        "map_position_at_time(_visual_campaign_tick)",
        "direction_at_time(_visual_campaign_tick)",
        "queue_redraw()",
    ]:
        if token not in view:
            failures.append(f"RegionMapView lacks smooth movement token: {token}")

    if "_campaign.campaign_tick)" in view and "map_position_at_tick(_campaign.campaign_tick)" in view:
        failures.append("RegionMapView still positions the Agent from whole campaign ticks")
    if "_redraw_accumulator < 0.10" not in view:
        failures.append("Non-Agent overlay throttling was unexpectedly removed")
    if not (
        "agent_travelling and _strategic_speed > StrategicClockService.SPEED_PAUSED" in view
        or "(agent_travelling or squad_travelling) and _strategic_speed > StrategicClockService.SPEED_PAUSED" in view
    ):
        failures.append("Smooth redraw is not restricted to advancing strategic travellers")

    for token in [
        "func strategic_speed() -> int",
        "_campaign_session.strategic_speed()",
        "_region_map_view.set_strategic_speed",
    ]:
        source = session if token.startswith("func strategic_speed") else shell
        if token not in source:
            failures.append(f"Campaign clock presentation bridge lacks token: {token}")

    if "smooth fractional-time interpolation" not in runtime:
        failures.append("Runtime Agent tests do not verify fractional-time interpolation")

    if failures:
        print("Stage 5.1c-P Hotfix 6 smooth movement validation FAILED")
        for failure in failures:
            print(" -", failure)
        return 1
    print("Stage 5.1c-P Hotfix 6 smooth movement validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
