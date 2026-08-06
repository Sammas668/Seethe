from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "presentation/campaign/campaign_shell.gd"
text = SHELL.read_text(encoding="utf-8")

required = [
    'func _build_summary_screen() -> void:',
    'var scroll := ScrollContainer.new()',
    'var footer := HBoxContainer.new()',
    'footer.add_child(continue_button)',
    'func _summary_new_loot_entries(result: MissionResult) -> Array[Dictionary]:',
    'result.item_outcomes_by_id.keys()',
    'MISSION_OUTBOUND_ORIGIN_ITEM_ID_KEY',
    'NEW LOOT RECOVERED',
    'Returned squad equipment is reconciled automatically and is not listed as recovered loot.',
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Missing withdrawal summary fix markers: {missing}")

summary_start = text.index('func _build_summary_screen() -> void:')
summary_end = text.index('func _continue_from_summary() -> void:', summary_start)
summary = text[summary_start:summary_end]
scroll_pos = summary.index('var scroll := ScrollContainer.new()')
footer_pos = summary.index('var footer := HBoxContainer.new()')
continue_pos = summary.index('var continue_button := Button.new()')
if not (scroll_pos < footer_pos < continue_pos):
    raise SystemExit('Summary footer is not authored after the scrollable report body.')
if 'root.add_child(footer)' not in summary:
    raise SystemExit('Summary footer is not attached directly to the full-screen root.')
if 'scroll.add_child(continue_button)' in summary or 'columns.add_child(continue_button)' in summary:
    raise SystemExit('Continue button is still inside the scrolling report body.')

print('Stage 5.3D withdrawal summary screen validation passed.')
