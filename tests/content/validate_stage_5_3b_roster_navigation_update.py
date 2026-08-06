from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "presentation/campaign/campaign_shell.gd"
text = SHELL.read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    start_index = text.index(start)
    end_index = text.index(end, start_index)
    return text[start_index:end_index]


tabs = block("func _build_equip_character_tabs", "func _build_equip_secondary_content")
secondary = block("func _build_equip_secondary_content", "func _build_roster_character_dossier")
equip_view = block("func _build_roster_equip_view", "func _build_xenonauts_loadout_composition")
mode_bar = block("func _build_roster_mode_bar", "func _resolved_roster_character")

assert '[0, "LOADOUT"]' in tabs
assert '[1, "CHARACTER"]' in tabs
assert '"INJURIES"' not in tabs, "Injuries must not remain a permanent roster subview."
assert "_roster_tab_index == 3" not in secondary, "The removed Injuries subview must not remain routable."
assert "_build_roster_dossier_condition_panel(campaign, character, template)" in text, "Injuries still need a Character-sheet condition summary."

for token in [
    "EQUIP_SUBVIEW_BAR_LEFT",
    "EQUIP_SUBVIEW_BAR_TOP",
    "EQUIP_SUBVIEW_BAR_RIGHT",
    "EQUIP_SUBVIEW_BAR_BOTTOM",
]:
    assert token in equip_view, f"Roster subview bar must use fixed anchor {token}."

for token in [
    "EQUIP_MODE_BAR_LEFT",
    "EQUIP_MODE_BAR_TOP",
    "EQUIP_MODE_BAR_RIGHT",
    "EQUIP_MODE_BAR_BOTTOM",
]:
    assert token in equip_view, f"Roster mode bar must use fixed anchor {token}."

assert "var entering_equip: bool" in mode_bar, "Re-clicking Equip Troops must not reset Character to Loadout."
assert "and _roster_mode != ROSTER_MODE_EQUIP" in mode_bar
assert "for trait:" not in text, "Reserved parser token must not be reused as a loop variable."

print("PASS — Roster subviews are reduced to Loadout and Character.")
print("PASS — Loadout and Character are fixed in the centred top subview bar.")
print("PASS — Manage Roster, Equip Troops and Memorial use one fixed mode-bar position.")
print("PASS — Injury information remains available through roster status and Current Condition.")
