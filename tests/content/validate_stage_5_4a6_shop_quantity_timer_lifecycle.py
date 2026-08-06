#!/usr/bin/env python3
"""Validate Stage 5.4A6/A7: quantity changes do not rebuild their live controls."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
shell_path = ROOT / "presentation/campaign/campaign_shell.gd"
shell = shell_path.read_text(encoding="utf-8", errors="replace")
errors: list[str] = []


def require(token: str, label: str) -> None:
    if token not in shell:
        errors.append(f"Missing {label}: {token}")


require("func _refresh_shop_transaction_preview(", "in-place preview helper")
require("var preview_column := VBoxContainer.new()", "persistent preview container")
require("action.disabled = not preview.success", "live action availability update")
require("action.tooltip_text = preview.message", "live action explanation update")
require("preview_column.remove_child(child)", "preview-only child replacement")
require("var apply_quantity := func(next_value: int) -> void:", "in-place quantity updater")
require("quantity_decrease.pressed.connect", "decrease control")
require("quantity_increase.pressed.connect", "increase control")
require("quantity_edit.text_submitted.connect", "typed quantity submission")

shop_details = shell.split("func _build_shop_details", 1)[1].split(
    "func _shop_selected_entry", 1
)[0]
if "SpinBox.new()" in shop_details:
    errors.append("Shop quantity still uses SpinBox and its internal repeat Timer.")
if "_show_screen(SCREEN_SHOP)" in shop_details:
    errors.append("Shop quantity details still synchronously rebuild the Shop screen.")
if shop_details.count("_refresh_shop_transaction_preview(") < 2:
    errors.append(
        "The Shop details screen must initialise the preview and refresh it after quantity changes."
    )

if errors:
    print("Stage 5.4A6/A7 Shop quantity timer-lifecycle validation FAILED:")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("Stage 5.4A6/A7 Shop quantity timer-lifecycle validation PASSED.")
