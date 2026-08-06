#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "presentation/campaign/campaign_shell.gd"
text = SHELL.read_text(encoding="utf-8")

required = [
    "Vector2(-180, -72)",
    "Vector2(360, 56)",
    "var content := VBoxContainer.new()",
    "Vector2(336, 31)",
    "HORIZONTAL_ALIGNMENT_CENTER",
    "Vector2(320, 10)",
    '"REGIONAL RETALIATION\\n%d / %d"',
    '"REGIONAL RETALIATION\\n%d → %d / %d"',
    '"REGIONAL RAID INCOMING\\n%d / %d"',
]
for token in required:
    assert token in text, f"Missing retaliation layout token: {token}"

for forbidden in [
    "var content := HBoxContainer.new()",
    "Vector2(390, 36)",
    "Vector2(156, 10)",
]:
    assert forbidden not in text, f"Obsolete side-by-side retaliation layout remains: {forbidden}"

print("Stage 5.1d Hotfix 3 retaliation value-above-bar validation passed.")
