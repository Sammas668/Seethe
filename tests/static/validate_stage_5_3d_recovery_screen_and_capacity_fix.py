from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")

app = read("bootstrap/app/game_app.gd")
session = read("bootstrap/app/campaign_session.gd")
recovery = read("application/missions/mission_recovery_selection_service.gd")
shell = read("presentation/campaign/campaign_shell.gd")

assert "_retire_tactical_presentation_for_recovery()" in app
assert 'get_node_or_null("HUD") as CanvasLayer' in app
assert "_free_tactical_screen()" in app
assert app.index("_retire_tactical_presentation_for_recovery()") < app.index("save_pending_mission_recovery(envelope)")
assert app.index("_free_tactical_screen()", app.index("func _on_mission_result_ready")) < app.index("show_mission_recovery", app.index("func _on_mission_result_ready"))

assert "_squad_operation_for_mission" in session
assert "envelope.result.mission_id" in session
assert "envelope.setup.transport_asset_id()" in session
assert "_transport_snapshot_for_operation(operation)" in session

assert "envelope.setup" in recovery
assert "setup.items_for_character" in recovery
assert 'stat_value(&"maximum_weight_lb", 0)' in recovery
assert "personal_remaining_carry_capacity_lb" in recovery
assert "template.maximum_weight_lb" in recovery

assert 'backdrop.color = Color("080b0d")' in shell
assert "backdrop.mouse_filter = Control.MOUSE_FILTER_STOP" in shell
assert "footer_surface.z_index = 20" in shell

print("PASS — tactical HUD is retired before the strategic Recovery screen is shown.")
print("PASS — Recovery uses the exact mission operation, immutable loadout and remaining maximum carrying capacity.")
print("PASS — the Recovery workspace has an opaque input-blocking background.")
