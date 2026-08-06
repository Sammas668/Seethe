from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "presentation/campaign/campaign_shell.gd"
text = SHELL.read_text(encoding="utf-8")
failures = []

required_tokens = [
    "func _build_roster_static_canvas(root: Control) -> Control:",
    "const ROSTER_CONTENT_LEFT: float = 0.055",
    "const ROSTER_CONTENT_TOP: float = EQUIP_CONTENT_TOP",
    "const ROSTER_CONTENT_RIGHT: float = 0.945",
    "const ROSTER_CONTENT_BOTTOM: float = EQUIP_CONTENT_BOTTOM",
]
for token in required_tokens:
    if token not in text:
        failures.append(f"missing token: {token}")

for function_name in [
    "_build_roster_manage_view",
    "_build_roster_equip_view",
    "_build_roster_memorial_view",
]:
    match = re.search(
        rf"func {re.escape(function_name)}\([\s\S]*?(?=\nfunc |\Z)", text
    )
    if not match:
        failures.append(f"missing function: {function_name}")
        continue
    body = match.group(0)
    if "var canvas := _build_roster_static_canvas(root)" not in body:
        failures.append(f"{function_name} does not use the shared static canvas")
    if "_build_roster_mode_bar()" not in body:
        failures.append(f"{function_name} does not render the shared roster mode bar")
    for anchor in [
        "EQUIP_MODE_BAR_LEFT",
        "EQUIP_MODE_BAR_TOP",
        "EQUIP_MODE_BAR_RIGHT",
        "EQUIP_MODE_BAR_BOTTOM",
    ]:
        if anchor not in body:
            failures.append(f"{function_name} does not use {anchor}")

if "column.add_child(_build_roster_mode_bar())" in text:
    failures.append("a roster mode still places the mode bar in flowing VBox content")

if failures:
    print("Stage 5.3b static roster-mode layout validation FAILED")
    for failure in failures:
        print(f" - {failure}")
    raise SystemExit(1)

print("PASS — Manage Roster, Equip Troops and Memorial share one static canvas and one fixed mode-bar position.")
