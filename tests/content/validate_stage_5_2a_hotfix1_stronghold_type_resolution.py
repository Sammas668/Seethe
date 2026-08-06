#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

required_preloads = {
    "presentation/campaign/campaign_shell.gd": [
        "const StrongholdDefinitionScript = preload",
        "const StrongholdStateScript = preload",
        "const StrongholdPlotDefinitionScript = preload",
        "const StrongholdPlotStateScript = preload",
        "const StrongholdGridViewScript = preload",
        "var _selected_stronghold_coord: Vector2i",
        "var _stronghold_grid_view: StrongholdGridViewScript",
        "var _stronghold_inspector_content: VBoxContainer",
    ],
    "bootstrap/app/campaign_session.gd": [
        "const StrongholdDefinitionRegistryScript = preload",
        "const StrongholdConnectivityServiceScript = preload",
        "const StrongholdDefinitionScript = preload",
        "const StrongholdStateScript = preload",
    ],
    "application/stronghold/stronghold_definition_registry.gd": [
        "const StrongholdDefinitionScript = preload",
        "const StrongholdStateScript = preload",
        "const StartingStrongholdFactoryScript = preload",
    ],
    "presentation/campaign/widgets/stronghold_grid_view.gd": [
        "const StrongholdDefinitionScript = preload",
        "const StrongholdStateScript = preload",
    ],
}

for rel, needles in required_preloads.items():
    text = read(rel)
    for needle in needles:
        assert needle in text, f"{rel}: missing {needle}"
    assert "ScriptScript" not in text, f"{rel}: malformed preload alias"
    assert "DefinitionScriptRegistryScript" not in text, f"{rel}: malformed registry alias"

for rel in [
    "domain/stronghold/stronghold_definition.gd",
    "domain/stronghold/stronghold_plot_state.gd",
    "domain/stronghold/stronghold_state.gd",
    "application/stronghold/stronghold_connectivity_service.gd",
    "application/stronghold/stronghold_definition_registry.gd",
    "infrastructure/content/stronghold/starting_stronghold_factory.gd",
    "presentation/campaign/widgets/stronghold_grid_view.gd",
]:
    text = read(rel)
    assert 'preload("res://' in text, f"{rel}: no explicit stronghold dependency preload"

print("PASS — Stage 5.2a Hotfix 1 resolves new stronghold types through explicit script preloads.")
print("PASS — CampaignShell declares and clears its stronghold presentation references.")
