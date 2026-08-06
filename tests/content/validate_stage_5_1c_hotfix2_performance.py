#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    failures: list[str] = []
    required = [
        ROOT / "application/performance/runtime_stall_attribution.gd",
        ROOT / "presentation/campaign/widgets/region_map_static_layer.gd",
        ROOT / "presentation/campaign/widgets/region_map_view.gd",
        ROOT / "application/strategic/region_boundary_pathfinder.gd",
        ROOT / "application/campaign/campaign_state_store.gd",
        ROOT / "bootstrap/app/campaign_session.gd",
    ]
    for path in required:
        if not path.is_file():
            failures.append(f"missing Hotfix 2 file: {path.relative_to(ROOT)}")
    if failures:
        return finish(failures)

    session = (ROOT / "bootstrap/app/campaign_session.gd").read_text(encoding="utf-8")
    for token in [
        "CLOCK_AUTOSAVE_REAL_SECONDS: float = 12.0",
        "state_store.commit_runtime(changes)",
        "_clock_state_dirty",
        "_flush_clock_state",
        '"coarse_clock_autosave"',
        '"agent_arrived"',
        '"mission_discovered"',
        'RuntimeStallAttribution.end(&"campaign_clock_update"',
    ]:
        if token not in session:
            failures.append(f"CampaignSession lacks deferred clock/persistence token: {token}")
    if "state_store.commit(changes)" in extract_function(session, "process_strategic_time"):
        failures.append("strategic clock still uses the full persistent commit path")

    store = (ROOT / "application/campaign/campaign_state_store.gd").read_text(encoding="utf-8")
    for token in [
        "func commit_runtime",
        "func persist_current",
        "Deferred campaign state rejected",
        'RuntimeStallAttribution.end(\n\t\t&"campaign_persistence"',
    ]:
        if token not in store:
            failures.append(f"CampaignStateStore lacks deferred-persistence token: {token}")
    runtime_func = extract_function(store, "commit_runtime")
    if "save_campaign" in runtime_func:
        failures.append("commit_runtime unexpectedly writes to the campaign repository")

    view = (ROOT / "presentation/campaign/widgets/region_map_view.gd").read_text(encoding="utf-8")
    for token in [
        "region_map_static_layer.gd",
        "_sync_static_layer_transform",
        "_rebuild_runtime_caches",
        "_site_ids_by_hex_key",
        "_coverage_by_centre_key",
        'RuntimeStallAttribution.end(&"region_dynamic_draw"',
        'RuntimeStallAttribution.end(&"region_hex_hit_test"',
        'RuntimeStallAttribution.end(\n\t\t\t&"agent_route_preview"',
        "show_region_performance",
    ]:
        if token not in view:
            failures.append(f"RegionMapView lacks rendering/hit-test token: {token}")
    hit_func = extract_function(view, "_hex_at_screen_position")
    if "_definition.all_hexes()" in hit_func:
        failures.append("hex hit testing still scans every authored hex")
    if "approximate_col" not in hit_func or "range(approximate_col - 1" not in hit_func:
        failures.append("hex hit testing does not use bounded coordinate candidates")
    input_func = extract_function(view, "_gui_input")
    if "next_hovered_site_id != _hovered_site_id" not in input_func:
        failures.append("mouse motion still redraws when the hovered site has not changed")

    static_layer = (ROOT / "presentation/campaign/widgets/region_map_static_layer.gd").read_text(encoding="utf-8")
    for token in [
        "extends RegionMapView",
        "STATIC_RADIUS",
        "_draw_hex_fills()",
        "_draw_road_edges()",
        "_draw_subregion_borders()",
        "_draw_static_sites()",
        'RuntimeStallAttribution.end(&"region_static_rebuild"',
    ]:
        if token not in static_layer:
            failures.append(f"static map layer lacks token: {token}")

    pathfinder = (ROOT / "application/strategic/region_boundary_pathfinder.gd").read_text(encoding="utf-8")
    for token in [
        "_route_tree_cache_by_key",
        "_route_from_cached_tree",
        "_build_shortest_tree",
        "_heap_push",
        "_heap_pop",
    ]:
        if token not in pathfinder:
            failures.append(f"boundary pathfinder lacks cached-tree token: {token}")
    if "for raw_key: Variant in open.keys()" in pathfinder:
        failures.append("quadratic dictionary scanning remains in the route solver")

    attribution = (ROOT / "application/performance/runtime_stall_attribution.gd").read_text(encoding="utf-8")
    for token in [
        "STALL_THRESHOLD_MS",
        "diagnostic_lines",
        "latest_stall",
        "region_dynamic_draw",
        "campaign_persistence",
    ]:
        if token not in attribution:
            failures.append(f"runtime attribution lacks token: {token}")

    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    if "development/show_region_performance=false" not in project:
        failures.append("region performance overlay is not disabled by default")

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
        print("Stage 5.1c-P Hotfix 2 performance validation FAILED")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 5.1c-P Hotfix 2 performance validation PASSED")
    print(" - strategic clock persistence is deferred to safe boundaries/coarse autosaves")
    print(" - static region content is isolated from dynamic interaction redraws")
    print(" - hex/site hit testing and Agent route previews use cached bounded queries")
    print(" - development runtime stall attribution is available and disabled by default")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
