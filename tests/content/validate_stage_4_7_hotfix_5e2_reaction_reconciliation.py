#!/usr/bin/env python3
"""Static regression checks for Stage 4.7 Hotfix 5e2."""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT_DEFAULT = Path(__file__).resolve().parents[2]


def extract_function(text: str, signature: str) -> str:
    start = text.find(signature)
    if start < 0:
        return ""
    end = text.find("\n\nfunc ", start + len(signature))
    return text[start : end if end >= 0 else None]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=ROOT_DEFAULT)
    args = parser.parse_args()
    root = args.project.resolve()
    screen_path = root / "presentation/tactical/tactical_screen.gd"
    if not screen_path.is_file():
        print(f"Missing {screen_path.relative_to(root)}")
        return 1

    text = screen_path.read_text(encoding="utf-8")
    waiter = extract_function(
        text,
        "func _flush_post_attack_reconciliation_after_frame() -> void:",
    )
    flush = extract_function(
        text,
        "func _flush_post_attack_reconciliation() -> void:",
    )
    errors: list[str] = []

    required_waiter_tokens = [
        "await get_tree().process_frame",
        "while (",
        "_movement_commit_in_progress or _movement_animation_active",
        "and is_inside_tree()",
        "if not is_inside_tree():",
        "_flush_post_attack_reconciliation()",
    ]
    for token in required_waiter_tokens:
        if token not in waiter:
            errors.append(f"post-attack waiter missing: {token}")

    forbidden = 'call_deferred("_flush_post_attack_reconciliation")'
    if forbidden in waiter or forbidden in flush:
        errors.append(
            "post-attack reconciliation must not self-defer while movement is active"
        )
    if "if _movement_commit_in_progress or _movement_animation_active:" not in flush:
        errors.append("post-attack flush is missing its defensive movement guard")
    if "\t\treturn" not in flush:
        errors.append("post-attack flush guard must return without retrying in the same idle cycle")

    if errors:
        print("Stage 4.7 Hotfix 5e2 Reaction reconciliation validation FAILED:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Stage 4.7 Hotfix 5e2 Reaction reconciliation validation PASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
