#!/usr/bin/env python3
"""Run Stage 4.7 Hotfix 5f10 static checks and optional Godot runtime tests."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str], label: str) -> bool:
    print(f"\n== {label} ==")
    completed = subprocess.run(command, cwd=ROOT, check=False)
    if completed.returncode != 0:
        print(f"{label}: FAIL ({completed.returncode})")
        return False
    print(f"{label}: PASS")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--skip-runtime", action="store_true")
    args = parser.parse_args()

    ok = True
    checks = [
        ([sys.executable, "tests/architecture/validate_stage_4_5g_architecture.py", "--project", "."], "Stage 4.5g architecture"),
        ([sys.executable, "tests/content/validate_stage_4_6_missions.py", "--project", "."], "Stage 4.6 authored mission"),
        ([sys.executable, "tests/content/validate_stage_4_7_character_content.py", "--project", "."], "Stage 4.7 character content"),
        ([sys.executable, "tests/content/validate_stage_4_7_sheet_conformance.py", "--project", "."], "Stage 4.7 sheet conformance"),
        ([sys.executable, "tests/content/validate_default_loadout_legality.py", "--project", "."], "Registered default-loadout legality"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5_marauder_mechanics.py", "--project", "."], "Stage 4.7 Hotfix 5 Marauder mechanics"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5a_raiders_sack_ui.py", "--project", "."], "Stage 4.7 Hotfix 5a Raider's Sack UI"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5b_raiders_sack_migration.py", "--project", "."], "Stage 4.7 Hotfix 5b Raider's Sack migration"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5c_raiders_sack_body_grid.py"], "Stage 4.7 Hotfix 5c Raider's Sack body grid"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5d_offscreen_enemy_turn.py", "--project", "."], "Stage 4.7 Hotfix 5d off-screen enemy turn"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5e_enemy_turn_responsiveness.py", "--project", "."], "Stage 4.7 Hotfix 5e enemy-turn responsiveness"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5e2_reaction_reconciliation.py", "--project", "."], "Stage 4.7 Hotfix 5e2 Reaction reconciliation"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5e3_enemy_cadence.py", "--project", "."], "Stage 4.7 Hotfix 5e3 enemy cadence"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f_enemy_movement_pipeline.py", "--project", "."], "Stage 4.7 Hotfix 5f enemy movement pipeline"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f1_adaptive_enemy_planning.py", "--project", "."], "Stage 4.7 Hotfix 5f1 adaptive enemy planning"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f2_end_phase_first_action_latency.py", "--project", "."], "Stage 4.7 Hotfix 5f2 end-phase latency"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f3_rapid_enemy_cadence.py", "--project", "."], "Stage 4.7 Hotfix 5f3 rapid enemy cadence"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f4_contact_transition_latency.py", "--project", "."], "Stage 4.7 Hotfix 5f4 contact transition latency"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f5_seamless_handoff.py", "--project", "."], "Stage 4.7 Hotfix 5f5 seamless player-enemy handoff"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f6_continuous_enemy_pipeline.py", "--project", "."], "Stage 4.7 Hotfix 5f6 continuous enemy pipeline"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f7_first_enemy_gate.py", "--project", "."], "Stage 4.7 Hotfix 5f7 first-enemy activation gate"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f8_targeted_melee_stall.py", "--project", "."], "Stage 4.7 Hotfix 5f8 targeted melee and stall attribution"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f9_cadence_polish.py", "--project", "."], "Stage 4.7 Hotfix 5f9 smooth enemy cadence"),
        ([sys.executable, "tests/content/validate_stage_4_7_hotfix_5f10_hidden_auto_pass.py", "--project", "."], "Stage 4.7 Hotfix 5f10 hidden auto-pass consolidation"),
    ]
    for command, label in checks:
        ok = run(command, label) and ok

    if args.skip_runtime:
        print("\nGodot runtime checks: NOT RUN (--skip-runtime).")
    elif args.godot is None:
        print("\nGodot runtime checks: NOT RUN (no --godot executable supplied).")
        ok = False
    elif not args.godot.is_file():
        print(f"\nGodot runtime checks: NOT RUN ({args.godot} is not a file).")
        ok = False
    else:
        command = [
            str(args.godot), "--headless", "--path", str(ROOT),
            "--script", "res://tests/integration/run_stage_4_7_hotfix_5f10_tests.gd",
        ]
        ok = run(command, "Stage 4.7 Hotfix 5f10 Godot runtime") and ok

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
