#!/usr/bin/env python3
"""Validate Stage 5.4A7: no live Shop input is removed during its input callback."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
shell = (ROOT / "presentation/campaign/campaign_shell.gd").read_text(encoding="utf-8")
errors: list[str] = []

required = (
    'var quantity_controls := HBoxContainer.new()',
    'var quantity_decrease := Button.new()',
    'var quantity_edit := LineEdit.new()',
    'var quantity_increase := Button.new()',
    'call_deferred("_show_screen", SCREEN_SHOP)',
)
for token in required:
    if token not in shell:
        errors.append(f"Missing Stage 5.4A7 token: {token}")

if 'SpinBox.new()' in shell:
    errors.append("A SpinBox remains in production UI code and can restart its internal Timer after removal.")

shop_toolbar = shell.split('func _build_shop_toolbar', 1)[1].split('func _on_shop_search_text_changed', 1)[0]
if '\t\t\t_show_screen(SCREEN_SHOP)' in shop_toolbar:
    errors.append("Shop toolbar still performs a synchronous self-rebuild from a button callback.")

shop_row = shell.split('func _build_shop_entry_row', 1)[1].split('func _build_shop_details', 1)[0]
if '\t\t_show_screen(SCREEN_SHOP)' in shop_row:
    errors.append("Shop entry selection still performs a synchronous self-rebuild.")

if errors:
    print("Stage 5.4A7 validation FAILED:")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("Stage 5.4A7 Shop quantity-control lifecycle validation PASSED.")
