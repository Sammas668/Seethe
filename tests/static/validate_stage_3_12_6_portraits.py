#!/usr/bin/env python3
import sys
from validation_common import *

def main() -> int:
    failures: list[str] = []
    require_tokens("domain/characters/definitions/character_template_definition.gd", ["portrait_id: StringName"], failures)
    require_tokens("domain/characters/state/persistent_character_state.gd", [
        "portrait_override_id: StringName", "effective_portrait_id", "set_portrait_override_id",
        '"portrait_override_id"', "_migrate_legacy_portrait_path",
    ], failures)
    require_tokens("domain/characters/resolution/resolved_character_snapshot.gd", ["portrait_id: StringName"], failures)
    require_tokens("domain/characters/resolution/character_resolver.gd", ["character.effective_portrait_id(template)"], failures)
    require_tokens("presentation/assets/portrait_asset_resolver.gd", [
        "class_name PortraitAssetResolver", '&"portrait.hakon_rusk"', "func resolve(",
    ], failures)
    require_tokens("bootstrap/debug/tactical_sandbox_factory.gd", [
        "HAKON_PORTRAIT_ID", "set_portrait_override_id",
    ], failures)
    for path in [
        "domain/characters/definitions/character_template_definition.gd",
        "domain/characters/resolution/resolved_character_snapshot.gd",
        "bootstrap/debug/tactical_sandbox_factory.gd",
    ]:
        forbid_tokens(path, ["portrait_path", "portrait_override_path"], failures)
    return finish("Stage 3.12.6 portraits", failures, ["Saves persist stable portrait IDs, not resource paths."])

if __name__ == "__main__":
    sys.exit(main())
