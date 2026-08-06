#!/usr/bin/env python3
"""Static checks for the Stage 5.3 storage-drop type-resolution hotfix."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
shell_path = ROOT / "presentation/campaign/campaign_shell.gd"
widget_path = ROOT / "presentation/campaign/widgets/strategic_storage_drop_panel.gd"
errors: list[str] = []

if not shell_path.is_file():
    errors.append("missing campaign_shell.gd")
    shell = ""
else:
    shell = shell_path.read_text(encoding="utf-8")

if not widget_path.is_file():
    errors.append("missing strategic_storage_drop_panel.gd")
    widget = ""
else:
    widget = widget_path.read_text(encoding="utf-8")

required_shell = [
    'const StrategicStorageDropPanelScript = preload("res://presentation/campaign/widgets/strategic_storage_drop_panel.gd")',
    "var panel = StrategicStorageDropPanelScript.new()",
    "panel.item_drop_requested.connect",
]
for token in required_shell:
    if token not in shell:
        errors.append(f"missing hotfix token: {token}")

for forbidden in [
    "var panel: StrategicStorageDropPanel = StrategicStorageDropPanelScript.new()",
    "var panel: StrategicStorageDropPanel",
]:
    if forbidden in shell:
        errors.append(f"global class annotation still present: {forbidden}")

for token in [
    "class_name StrategicStorageDropPanel",
    "signal item_drop_requested(item_id: StringName)",
    "func _can_drop_data",
    "func _drop_data",
]:
    if token not in widget:
        errors.append(f"storage drop widget contract missing: {token}")

if errors:
    print("Stage 5.3 storage-drop type-resolution hotfix validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — CampaignShell constructs the preloaded storage-drop widget without relying on global class-name resolution.")
print("PASS — Available Equipment retains the full-panel storage-drop signal contract.")
