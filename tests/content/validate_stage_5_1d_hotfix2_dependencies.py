from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
required = [
    "domain/strategic/squad_route_plan.gd",
    "domain/strategic/squad_visibility_snapshot.gd",
    "domain/strategic/character_visibility_snapshot.gd",
    "domain/strategic/travel_exposure_entry.gd",
    "domain/strategic/squad_travel_operation_state.gd",
    "domain/strategic/subregion_notoriety_state.gd",
    "domain/strategic/raid_operation_state.gd",
    "application/strategic/squad_route_planning_service.gd",
    "application/strategic/squad_visibility_service.gd",
    "application/strategic/squad_travel_service.gd",
    "application/strategic/travel_notoriety_service.gd",
    "application/strategic/subregion_notoriety_service.gd",
    "application/strategic/regional_retaliation_service.gd",
    "application/strategic/mission_lifecycle_service.gd",
]
missing = [path for path in required if not (ROOT / path).is_file()]
assert not missing, f"Missing Stage 5.1d dependencies: {missing}"
route_text = (ROOT / "domain/strategic/squad_route_plan.gd").read_text(encoding="utf-8")
assert "class_name SquadRoutePlan" in route_text
shell_text = (ROOT / "presentation/campaign/campaign_shell.gd").read_text(encoding="utf-8")
assert "var _route_plan: SquadRoutePlan" in shell_text
for token in [
    "Vector2(360, 56)",
    "Vector2(-180, -72)",
    "Vector2(320, 10)",
    "var content := VBoxContainer.new()",
    '"REGIONAL RETALIATION\\n%d / %d"',
]:
    assert token in shell_text, f"Updated compact retaliation HUD token is not present: {token}"
print("Stage 5.1d Hotfix 2 dependency validation passed.")
