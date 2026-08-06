#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
BOARD = ROOT / "presentation/tactical/tactical_board_view.gd"
TEST = ROOT / "tests/tactical/stage_4_4e2_critical_interaction_cover_movement_tests.gd"


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def main() -> int:
    board = BOARD.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")

    signature = re.search(
        r"func update_presentation\((.*?)\n\) -> void:",
        board,
        flags=re.S,
    )
    if signature is None:
        fail("TacticalBoardView.update_presentation() signature was not found.")
    parameters = signature.group(1)
    required_order = [
        "detection_preview: MovementDetectionPreview",
        "reaction_preview: MovementReactionPreview",
        "facing_preview_direction: Vector2i",
    ]
    positions = [parameters.find(token) for token in required_order]
    if any(position < 0 for position in positions) or positions != sorted(positions):
        fail("Detection, reaction and facing preview parameters are missing or out of order.")

    call = re.search(
        r"board\.update_presentation\((.*?)\n\t\)",
        test,
        flags=re.S,
    )
    if call is None:
        fail("Critical interaction test update_presentation() call was not found.")
    call_text = call.group(1)
    expected = "null, # detection_preview\n\t\tnull, # reaction_preview\n\t\tVector2i.ZERO"
    if expected not in call_text:
        fail("Critical interaction test does not supply the reaction preview placeholder before facing.")

    print("PASS: Stage 5.1c-P Hotfix 5 tactical test signature compatibility.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
