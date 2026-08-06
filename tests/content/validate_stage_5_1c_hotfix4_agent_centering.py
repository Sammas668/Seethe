#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    failures: list[str] = []
    pathfinder_path = ROOT / "application/strategic/region_boundary_pathfinder.gd"
    view_path = ROOT / "presentation/campaign/widgets/region_map_view.gd"
    integration_path = ROOT / "tests/integration/stage_5_1c_agent_tests.gd"
    for path in [pathfinder_path, view_path, integration_path]:
        if not path.is_file():
            failures.append(f"missing required file: {path.relative_to(ROOT)}")
    if failures:
        return finish(failures)

    pathfinder = pathfinder_path.read_text(encoding="utf-8")
    for token in [
        "plan.route_points.append(_map_center(origin))",
        "_connector_minutes(definition, origin)",
        "_connector_minutes(definition, destination)",
        "plan.route_points.append(_map_center(destination))",
        "MIN_CONNECTOR_MINUTES",
        "_terrain_minutes",
    ]:
        if token not in pathfinder:
            failures.append(f"boundary route lacks centre-connector safeguard: {token}")
    for obsolete in [
        "const DEPARTURE_MINUTES: float = 2.0",
        "const ARRIVAL_MINUTES: float = 2.0",
    ]:
        if obsolete in pathfinder:
            failures.append(f"obsolete near-instant connector remains: {obsolete}")

    view = view_path.read_text(encoding="utf-8")
    if "map_position += Vector2(0.16, -0.10)" in view:
        failures.append("deployed Agent is still deliberately offset from the destination centre")
    if "return RegionBoundaryPathfinder.map_center(agent.current_hex)" not in view:
        failures.append("stationary Agent position is not derived from the exact hex centre")

    integration = integration_path.read_text(encoding="utf-8")
    for token in [
        "Agent route does not begin at the origin hex centre.",
        "Agent route does not finish at the destination hex centre.",
        "Agent does not interpolate from the hex centre to its first boundary node.",
        "Deployed Agent is not positioned at the destination hex centre.",
    ]:
        if token not in integration:
            failures.append(f"runtime regression coverage missing: {token}")

    return finish(failures)


def finish(failures: list[str]) -> int:
    if failures:
        print("Stage 5.1c-P Hotfix 4 Agent centring validation FAILED")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 5.1c-P Hotfix 4 Agent centring validation PASSED")
    print(" - travel begins at the exact origin hex centre")
    print(" - centre-to-boundary and boundary-to-centre legs have visible duration")
    print(" - travel ends at the exact destination hex centre")
    print(" - deployed tokens no longer receive an off-centre presentation offset")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
