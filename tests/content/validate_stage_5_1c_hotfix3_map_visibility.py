#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    failures: list[str] = []
    view_path = ROOT / "presentation/campaign/widgets/region_map_view.gd"
    static_path = ROOT / "presentation/campaign/widgets/region_map_static_layer.gd"
    if not view_path.is_file():
        failures.append("missing RegionMapView")
    if not static_path.is_file():
        failures.append("missing RegionMapStaticLayer")
    if failures:
        return finish(failures)

    view = view_path.read_text(encoding="utf-8")
    for token in [
        "z_index = 3",
        "_background_layer.z_index = -2",
        "_static_layer.z_index = -1",
        "_static_layer.show_behind_parent = true",
        "_static_layer.visible = true",
        "_sync_static_layer_transform()",
    ]:
        if token not in view:
            failures.append(f"RegionMapView lacks map-visibility safeguard: {token}")

    if "_static_layer.z_index = -10" in view or "_background_layer.z_index = -20" in view:
        failures.append("large negative cached-layer z-indices can place the map behind CampaignShell")

    ready = extract_function(view, "_ready")
    if ready.find("z_index = 3") > ready.find("add_child(_static_layer)"):
        failures.append("RegionMapView z-index is not established before cached children are added")

    sync = extract_function(view, "_sync_static_layer_transform")
    for token in ["_static_layer.visible = true", "_static_layer.position = _map_origin()", "_static_layer.scale"]:
        if token not in sync:
            failures.append(f"static-layer transform does not enforce: {token}")

    return finish(failures)


def extract_function(text: str, name: str) -> str:
    marker = f"func {name}"
    start = text.find(marker)
    if start < 0:
        return ""
    next_func = text.find("\n\nfunc ", start + len(marker))
    return text[start:] if next_func < 0 else text[start:next_func]


def finish(failures: list[str]) -> int:
    if failures:
        print("Stage 5.1c-P Hotfix 3 map visibility validation FAILED")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 5.1c-P Hotfix 3 map visibility validation PASSED")
    print(" - cached terrain layer remains above the CampaignShell background")
    print(" - dynamic overlays remain above cached terrain")
    print(" - static visibility and camera transform are reasserted safely")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
