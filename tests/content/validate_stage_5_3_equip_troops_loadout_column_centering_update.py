#!/usr/bin/env python3
"""Static acceptance checks for the Stage 5.3 Equip Troops Loadout Column Centering Update."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errors: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"missing required file: {rel}")
        return ""
    return path.read_text(encoding="utf-8")


shell = read("presentation/campaign/campaign_shell.gd")

values: dict[str, float] = {}
for name in [
    "EQUIP_CHARACTER_LEFT",
    "EQUIP_CHARACTER_RIGHT",
    "EQUIP_CARRIED_LEFT",
    "EQUIP_CARRIED_RIGHT",
    "EQUIP_AVAILABLE_LEFT",
    "EQUIP_AVAILABLE_RIGHT",
]:
    match = re.search(rf"const {name}: float = ([0-9.]+)", shell)
    if match is None:
        errors.append(f"missing layout constant: {name}")
    else:
        values[name] = float(match.group(1))

expected = {
    "EQUIP_CARRIED_LEFT": 0.548,
    "EQUIP_CARRIED_RIGHT": 0.708,
    "EQUIP_AVAILABLE_LEFT": 0.750,
}
for name, wanted in expected.items():
    actual = values.get(name)
    if actual is not None and abs(actual - wanted) > 0.0001:
        errors.append(f"{name} expected {wanted:.3f}, got {actual:.3f}")

carried_width = values.get("EQUIP_CARRIED_RIGHT", 0.0) - values.get("EQUIP_CARRIED_LEFT", 0.0)
if abs(carried_width - 0.160) > 0.0001:
    errors.append(f"loadout column width changed: expected 0.160, got {carried_width:.3f}")

shift_match = re.search(r"const EQUIP_CARRIED_SHIFT_X: float = (-?[0-9.]+)", shell)
if shift_match is None:
    errors.append("missing EQUIP_CARRIED_SHIFT_X")
elif abs(float(shift_match.group(1)) - (-24.0)) > 0.001:
    errors.append("loadout column must be shifted exactly 24 px farther left")

if values.get("EQUIP_CARRIED_RIGHT", 1.0) >= values.get("EQUIP_AVAILABLE_LEFT", 0.0):
    errors.append("loadout column overlaps Available Equipment")

composition_start = shell.find("func _build_xenonauts_loadout_composition(")
composition_end = shell.find("func _place_equip_region(", composition_start)
composition = shell[composition_start:composition_end]
for token in [
    "figure.z_index = 0",
    "carried.z_index = 2",
    "available.z_index = 3",
    "EQUIP_CARRIED_LEFT",
    "EQUIP_CARRIED_RIGHT",
]:
    if token not in composition:
        errors.append(f"composition missing centred-column safeguard: {token}")

figure_start = shell.find("func _build_equip_character_figure(")
figure_end = shell.find("func _build_equip_carried_panel(", figure_start)
figure = shell[figure_start:figure_end]
if "root.mouse_filter = Control.MOUSE_FILTER_IGNORE" not in figure:
    errors.append("portrait region can intercept input beneath the visually centred loadout column")

for token in [
    "Its width remains unchanged; only its horizontal position shifts left.",
    "selector.fit_to_longest_item = false",
    "selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS",
]:
    if token not in shell:
        errors.append(f"missing layout-width safeguard: {token}")

if errors:
    print("Stage 5.3 Equip Troops Loadout Column Centering validation FAILED")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("PASS — the complete loadout column shifted left without changing width.")
print("PASS — the bounded column preserves its width and applies the later 24 px left shift.")
print("PASS — Available Equipment remains separate and unobstructed.")
print("PASS — portrait input does not block the repositioned loadout controls.")
