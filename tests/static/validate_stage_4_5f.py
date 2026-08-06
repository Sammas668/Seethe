#!/usr/bin/env python3
"""Static acceptance checks for Seethe Stage 4.5f."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRODUCTION_ROOTS = [ROOT / "application", ROOT / "domain", ROOT / "presentation", ROOT / "bootstrap"]

REQUIRED = [
    "application/tactical/movement/tactical_movement_resolution_coordinator.gd",
    "domain/tactical/reactions/pending_movement_reaction_state.gd",
    "docs/architecture/STAGE_4_5F_AUTHORITATIVE_INTERRUPTED_MOVEMENT.md",
    "tests/tactical/stage_4_5f_authoritative_interrupted_movement_tests.gd",
    "tests/tactical/run_stage_4_5f_tests.gd",
    "STAGE_4_5F_AUTHORITATIVE_INTERRUPTED_MOVEMENT_RELEASE_NOTES.txt",
]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def require_token(failures: list[str], rel: str, token: str, message: str) -> None:
    if token not in read(rel):
        failures.append(f"{message} ({rel})")


def literal_change_reasons() -> set[str]:
    pattern = re.compile(r"TacticalChangeSet\.new\(\s*&\"([^\"]+)\"")
    reasons: set[str] = set()
    for folder in PRODUCTION_ROOTS:
        for path in folder.rglob("*.gd"):
            text = path.read_text(encoding="utf-8")
            reasons.update(pattern.findall(text))
    return reasons


def main() -> int:
    stage_45g_validator = ROOT / "tests/architecture/validate_stage_4_5g_architecture.py"
    if (ROOT / "domain/tactical/invalidation/tactical_invalidation_contract.gd").is_file() and stage_45g_validator.is_file():
        print("Stage 4.5f baseline checks are superseded by the Stage 4.5g architecture validator.")
        completed = subprocess.run([sys.executable, str(stage_45g_validator)], cwd=ROOT, check=False)
        return completed.returncode

    failures: list[str] = []
    for rel in REQUIRED:
        if not (ROOT / rel).is_file():
            failures.append(f"Missing required Stage 4.5f file: {rel}")

    require_token(failures, "domain/tactical/tactical_state.gd", "pending_movement_reaction", "Pending movement is not authoritative TacticalState")
    require_token(failures, "application/tactical/tactical_state_store.gd", "pending_tactical_decision", "State store does not gate unrelated commands")
    require_token(failures, "application/tactical/tactical_state_store.gd", "commit_after_notifications", "Derived post-notification commit queue is missing")
    require_token(failures, "application/tactical/visibility/tactical_visibility_service.gd", "commit_after_notifications", "Exploration still bypasses the deferred commit API")
    require_token(failures, "application/tactical/transactions/tactical_change_set.gd", '"occupancy_revision"', "Rollback does not snapshot occupancy revision")
    require_token(failures, "application/tactical/transactions/tactical_change_set.gd", '"visibility_blocker_revision"', "Rollback does not snapshot visibility-blocker revision")
    require_token(failures, "application/tactical/transactions/tactical_change_set.gd", '"knowledge_revision"', "Rollback does not snapshot knowledge revision")
    require_token(failures, "application/tactical/transactions/tactical_change_set.gd", '"environment_geometry_revision"', "Rollback does not snapshot geometry revision")
    require_token(failures, "core/results/operation_result.gd", "STATUS_PENDING", "OperationResult pending state is missing")
    require_token(failures, "core/results/operation_result.gd", "STATUS_DEFERRED", "OperationResult deferred state is missing")
    require_token(failures, "domain/tactical/tactical_invalidation_flags.gd", "return TacticalInvalidationFlags.full_refresh()", "Unknown invalidation reasons do not fail safely")
    require_token(failures, "bootstrap/boot/boot.gd", "Stage 4.5f authoritative interrupted movement", "Boot marker is stale")

    service = read("application/tactical/reactions/tactical_reaction_service.gd")
    for legacy in ("var _pending_decision", "var _pending_candidate", "var _declined_candidate_keys"):
        if legacy in service:
            failures.append(f"Reaction service still owns legacy authoritative field: {legacy}")
    enemy = read("application/tactical/ai/enemy_turn_handler.gd")
    if "var _pending_reaction_context" in enemy:
        failures.append("EnemyTurnHandler still owns the interrupted movement context")

    retired_calls: list[str] = []
    for folder in PRODUCTION_ROOTS:
        for path in folder.rglob("*.gd"):
            text = path.read_text(encoding="utf-8")
            if "resolve_ai_reactions_along_path(" in text and path.name != "tactical_reaction_service.gd":
                retired_calls.append(str(path.relative_to(ROOT)))
    if retired_calls:
        failures.append("Retired speculative reaction API is still called by: " + ", ".join(retired_calls))

    invalidation_text = read("domain/tactical/tactical_invalidation_flags.gd")
    missing_policies = sorted(reason for reason in literal_change_reasons() if f'&"{reason}"' not in invalidation_text)
    if missing_policies:
        failures.append("Literal production change reasons lack an invalidation policy: " + ", ".join(missing_policies))

    if failures:
        print("Stage 4.5f static validation failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print("Stage 4.5f static validation passed.")
    print(f"Validated {len(literal_change_reasons())} literal production TacticalChangeSet reasons.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
