#!/usr/bin/env python3
"""Static contract checks for Stage 4.7 Hotfix 5d."""
from pathlib import Path
import argparse
import sys

ROOT_DEFAULT = Path(__file__).resolve().parents[2]


def require(text: str, needle: str, label: str, errors: list[str]) -> None:
    if needle not in text:
        errors.append(f"{label} missing: {needle}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=ROOT_DEFAULT)
    args = parser.parse_args()
    root = args.project.resolve()

    screen_path = root / "presentation/tactical/tactical_screen.gd"
    handler_path = root / "application/tactical/ai/enemy_turn_handler.gd"
    log_path = root / "presentation/tactical/combat_log/tactical_combat_log.gd"
    attack_path = root / "application/tactical/combat/attack_handler.gd"
    errors: list[str] = []
    for path in (screen_path, handler_path, log_path, attack_path):
        if not path.exists():
            errors.append(f"Missing {path.relative_to(root)}")
    if errors:
        for error in errors:
            print(f"- {error}")
        return 1

    screen = screen_path.read_text(encoding="utf-8")
    handler = handler_path.read_text(encoding="utf-8")
    combat_log = log_path.read_text(encoding="utf-8")
    attack_handler = attack_path.read_text(encoding="utf-8")

    for needle in [
        "enum TacticalPresentationVisibility",
        "func _ai_movement_event_visibility(event: Dictionary) -> int:",
        "func _observable_ai_path_segment(path: Array[Vector2i]) -> Array[Vector2i]:",
        "func _ai_movement_batch_is_completely_unobserved(",
        "func _complete_unobserved_ai_movement_batch(",
        "end_visibility_recalculation_deferral_for_units(",
        "_unobserved_ai_movement_batches_completed_immediately",
        "_unobserved_ai_activation_handoffs_skipped",
        "_unobserved_enemy_phase_handoffs_skipped",
        "if acting_handoff_observable:",
        "and _unit_handoff_is_observable(next_after_ai)",
        "ROUND %d · INITIATIVE · ENEMY ACTIVITY",
        "Unknown enemy",
        'snapshot["offscreen_enemy_presentation"]',
    ]:
        require(screen, needle, "presentation/tactical/tactical_screen.gd", errors)

    for needle in [
        "_activation_timing_samples",
        'snapshot["activation_timing"]',
        "func _record_activation_timing(",
        "Unknown enemy",
        '"visibility": _event_visibility_for_unit(unit)',
        "_visibility_service.has_method(\"is_unit_visible_to_team\")",
    ]:
        require(handler, needle, "application/tactical/ai/enemy_turn_handler.gd", errors)


    if not (
        "var activation_started_usec: int = Time.get_ticks_usec()" in handler
        or (
            "_pending_activation_simulation_usec" in handler
            and "func _record_activation_timing_elapsed(" in handler
        )
    ):
        errors.append(
            "application/tactical/ai/enemy_turn_handler.gd missing activation timing capture."
        )

    require(
        combat_log,
        'if StringName(event.get("visibility", &"player")) != &"player":',
        "presentation/tactical/combat_log/tactical_combat_log.gd",
        errors,
    )

    for needle in [
        "var _visibility_service: RefCounted",
        "func _unit_is_player_observable(unit: TacticalUnitState) -> bool:",
        "An unseen attacker attacks %s — %s.",
        '"visibility": event_visibility',
        "func _redacted_unseen_attack_details(",
        "roll_records = []",
    ]:
        require(
            attack_handler,
            needle,
            "application/tactical/combat/attack_handler.gd",
            errors,
        )

    fast_start = screen.find("func _complete_unobserved_ai_movement_batch(")
    fast_end = screen.find("\n\nfunc ", fast_start + 1)
    fast_body = screen[fast_start:fast_end if fast_end != -1 else len(screen)]
    if "await " in fast_body or "create_timer" in fast_body:
        errors.append("Unobserved movement fast path must contain no await or timer.")

    phase_marker = "if _enemy_phase_had_observable_activity:\n\t\tawait _await_presentation_cadence"
    require(screen, phase_marker, "guarded enemy phase handoff", errors)

    if errors:
        print("Stage 4.7 Hotfix 5d off-screen enemy-turn validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5d off-screen enemy-turn validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
