#!/usr/bin/env python3
import sys
from validation_common import *


def main() -> int:
    failures: list[str] = []
    require_tokens("domain/characters/resolution/character_resolver.gd", [
        "class_name CharacterResolver", "func resolve(",
        "RESOLVED_CHARACTER_SNAPSHOT_SCRIPT", "RESOLVED_STAT_SCRIPT",
        "stat.configure(stat_id, display_name)",
    ], failures)
    require_tokens("application/characters/character_resolution_service.gd", [
        "CHARACTER_RESOLVER_SCRIPT", "var _resolver: RefCounted",
        'resolver: RefCounted = null', '_resolver.call(', '"resolve"',
        "-> ResolvedCharacterSnapshot",
    ], failures)
    forbid_tokens("application/characters/character_resolution_service.gd", [
        "var _resolver: CharacterResolver", "CharacterResolver.new()",
        "resolver: CharacterResolver",
    ], failures)
    validate_tab_indentation(failures)
    return finish(
        "Stage 3.12.1",
        failures,
        ["The resolver is an explicit script dependency without fragile global-class type lookup."],
    )


if __name__ == "__main__":
    sys.exit(main())
