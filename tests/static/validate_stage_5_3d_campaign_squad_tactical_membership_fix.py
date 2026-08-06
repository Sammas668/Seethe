from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

session = (ROOT / "application/tactical/tactical_session.gd").read_text()
facade = (ROOT / "application/tactical/facades/tactical_screen_facade.gd").read_text()
detection = (ROOT / "application/tactical/awareness/tactical_detection_service.gd").read_text()

assert "state.get_squads_for_team(\n\t\t&\"player\"\n\t)" in session
assert "unit.squad_id = primary_squad.squad_id" in session
assert "unit.squad_id = squad.squad_id" not in session[session.index("func _ensure_player_perception_squad"):session.index("func _on_session_state_changed")]
assert "state().get_squads_for_team(&\"player\")" in facade
assert "observer_squad_state.team_id != &\"player\"" in detection

print("Stage 5.3D campaign squad tactical membership fix validator passed.")
