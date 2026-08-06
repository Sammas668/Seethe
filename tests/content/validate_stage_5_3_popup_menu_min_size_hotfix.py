#!/usr/bin/env python3
"""Static checks for the Stage 5.3 PopupMenu minimum-size hotfix."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
shell_path = ROOT / "presentation/campaign/campaign_shell.gd"
errors: list[str] = []

if not shell_path.is_file():
    errors.append("missing campaign_shell.gd")
    shell = ""
else:
    shell = shell_path.read_text(encoding="utf-8")

for forbidden in [
    "selector.get_popup().custom_minimum_size.x = 320.0",
    "selector.get_popup().custom_minimum_size.x = 340.0",
    "get_popup().custom_minimum_size",
]:
    if forbidden in shell:
        errors.append(f"PopupMenu still uses Control-only property: {forbidden}")

for required in [
    "selector.get_popup().min_size = Vector2i(320, 0)",
    "selector.get_popup().min_size = Vector2i(340, 0)",
]:
    if required not in shell:
        errors.append(f"missing Window minimum-size assignment: {required}")

# Preserve the static closed-control safeguards that prevent long selected names
# from changing the carried-column width.
for required in [
    "selector.fit_to_longest_item = false",
    "selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS",
    "selector_holder.clip_contents = true",
]:
    if required not in shell:
        errors.append(f"missing fixed-column selector safeguard: {required}")

if errors:
    print("Stage 5.3 PopupMenu minimum-size hotfix validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — PopupMenu uses Window.min_size rather than Control.custom_minimum_size.")
print("PASS — loadout and armour popup widths remain readable without resizing the closed column.")
