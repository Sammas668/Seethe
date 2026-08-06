#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


data = json.loads((ROOT / "content/stronghold/starting_ruin/starting_ruin.json").read_text())
assert data["id"] == "stronghold.fifth_god.starting_ruin"
assert data["layout_version"] == 3
assert data["width"] == 7 and data["height"] == 7
assert data["primary_heart_coord"] == [3, 3]
assert data["primary_access_coord"] == [2, 5]
plots = data["plots"]
assert len(plots) == 49
by_coord = {tuple(p["coord"]): p for p in plots}
assert len(by_coord) == 49
assert sum(p["state"] == "fixed_heart" for p in plots) == 1
assert sum(p["state"] == "occupied" for p in plots) == 4
assert sum(p["state"] == "available" for p in plots) == 44
assert not any(p["state"] in {"fixed_entrance", "sealed", "ruined", "permanent_block"} for p in plots)
assert by_coord[(3, 3)]["fixed_facility_id"] == "facility.fifth_god_heart"
stables_coords = {(2, 5), (3, 5), (2, 6), (3, 6)}
assert {coord for coord, p in by_coord.items() if p.get("fixed_facility_id") == "facility.stables"} == stables_coords

presentations = {p["id"]: p for p in data["facility_presentations"]}
assert "facility.stronghold_entrance" not in presentations
assert presentations["facility.fifth_god_heart"]["expected_footprint"] == [1, 1]
assert presentations["facility.stables"]["expected_footprint"] == [2, 2]

facilities = {f["id"]: f for f in data["facilities"]}
assert facilities["facility.fifth_god_heart"]["demolishable"] is False
assert facilities["facility.stables"]["demolishable"] is False
assert facilities["facility.stables"]["buildable"] is False
assert facilities["facility.reaver_warcamp"]["footprint"] == [2, 2]
assert {f["id"] for f in data["facilities"] if f["buildable"]} == {
    "facility.storehouse",
    "facility.muster_hall",
    "facility.recovery_chamber",
    "facility.prison",
    "facility.workshop",
    "facility.reaver_warcamp",
    "facility.living_quarters",
}

for art in data["available_plot_art_paths"]:
    assert (ROOT / art.removeprefix("res://")).is_file(), art
assert len(data["available_plot_art_paths"]) >= 3

accessible = set(by_coord)

def flood(start):
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for nxt in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if nxt in accessible and nxt not in seen:
                seen.add(nxt); q.append(nxt)
    return seen

assert flood((3, 3)) == accessible
assert flood((2, 5)) == accessible

for rel, cls in [
    ("domain/stronghold/stronghold_facility_definition.gd", "StrongholdFacilityDefinition"),
    ("domain/stronghold/stronghold_facility_state.gd", "StrongholdFacilityState"),
    ("domain/stronghold/stronghold_prototype_rules.gd", "StrongholdPrototypeRules"),
    ("application/stronghold/stronghold_construction_service.gd", "StrongholdConstructionService"),
]:
    assert f"class_name {cls}" in read(rel)

print("PASS — the Stage 5.2 stronghold is a data-driven 7×7 open construction grid.")
print("PASS — the 1×1 Heart is at the true centre and the 2×2 Stables replace the fixed entrance.")
print("PASS — all remaining 44 plots are immediately available and use authored illustrated-room assets.")
