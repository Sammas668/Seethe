from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "presentation/campaign/campaign_shell.gd"
text = SHELL.read_text(encoding="utf-8")


def block(start: str, end: str) -> str:
    start_index = text.index(start)
    end_index = text.index(end, start_index)
    return text[start_index:end_index]


tabs = block("func _build_equip_character_tabs", "func _build_equip_secondary_content")
dossier = block("func _build_roster_dossier_identity_panel", "func _build_roster_dossier_combat_panel")
level_up = block("func _build_level_up_content", "func _build_loadout_template_controls")

assert '[2, "LEVEL UP"' not in tabs, "Level Up must not remain a top-level character tab."
assert '[1, "CHARACTER"]' in tabs and '"INJURIES"' not in tabs
assert "tab_index == 1 and _roster_tab_index == 2" in tabs, "Character must remain highlighted in its Level Up subview."
assert "_build_roster_dossier_progression_block(character, template)" in dossier
assert "func _build_roster_dossier_progression_block" in dossier
assert "var xp_bar := ProgressBar.new()" in dossier
assert 'xp_amount.text = "%d / %d XP"' in dossier
assert '"LEVEL UP AVAILABLE"' in dossier and '"VIEW LEVEL %d"' in dossier
assert "_roster_tab_index = 2" in dossier, "The Character-sheet button must open Level Up."
assert 'back.text = "BACK TO CHARACTER"' in level_up
assert "_roster_tab_index = 1" in level_up
assert "var xp_bar := ProgressBar.new()" not in level_up, "XP bar belongs on Character, not duplicated on Level Up."
assert "for trait:" not in text, "Reserved parser token must not be reused as a loop variable."

print("PASS — Level Up is a Character-sheet subview opened by the dossier progression button.")
print("PASS — XP amount and progress bar are displayed on the Character sheet.")
print("PASS — The Level Up view provides a direct return to Character and does not duplicate the XP bar.")
