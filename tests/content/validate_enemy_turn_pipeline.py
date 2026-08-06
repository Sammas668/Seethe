#!/usr/bin/env python3
"""Validate the current consolidated enemy-turn pipeline.

This replaces the former Hotfix 5d–5f10 token chain. Historical changes remain
available through Git history; current validation checks the final architecture.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    path = ROOT / rel
    assert path.is_file(), f"Missing {rel}"
    return path.read_text(encoding="utf-8")


handler = read("application/tactical/ai/enemy_turn_handler.gd")
planner = read("application/tactical/ai/enemy_action_planner.gd")
instrumentation = read("application/tactical/ai/enemy_turn_instrumentation.gd")
screen = read("presentation/tactical/tactical_screen.gd")
facade = read("application/tactical/facades/tactical_screen_facade.gd")
stall = read("application/performance/runtime_stall_attribution.gd")

# Intentional pipeline boundaries.
for token in (
    "EnemyActivationPlanningJob",
    "resolve_next_enemy_activation",
    "has_pending_enemy_planning",
    "commit_ready_enemy_activation",
    "record_enemy_planning_frame_yield",
    "warmup_next_ai_handoff",
    "prepare_ai_activation_handoff",
    "_try_execute_hidden_auto_pass_batch",
    "_execute_standard_combat",
    "_finish_activation",
):
    assert token in handler, f"EnemyTurnHandler is missing {token}"

# Targeted melee planning remains the fix for the former universal-field stall.
for token in (
    "targeted_melee_search",
    "targeted_melee_attack_searches",
    "targeted_melee_approach_searches",
    "reachable_field_builds",
    "planning_stage",
):
    assert token in planner or token in handler, f"Targeted planning metric missing: {token}"

# Profiling state is owned by a dedicated class rather than gameplay control flow.
for token in (
    "class_name EnemyTurnInstrumentation",
    "func begin_activation",
    "func snapshot",
    "func record_presentation_timing",
    "func record_activation_elapsed",
    "SLOW_ACTIVATION_HISTORY_LIMIT",
):
    assert token in instrumentation, f"Enemy instrumentation is missing {token}"
for legacy_field in (
    "var _activation_timing_samples",
    "var _activation_total_usec",
    "var _activation_max_usec",
    "var _last_activation_timing",
    "var _slow_activation_history",
):
    assert legacy_field not in handler, f"Telemetry field still lives in EnemyTurnHandler: {legacy_field}"
assert "ENEMY_TURN_INSTRUMENTATION_SCRIPT" in handler
assert 'snapshot["activation_timing"] = _instrumentation.snapshot()' in handler

# Presentation cadence and frame budgeting remain separated from simulation.
for token in (
    "ENEMY_PHASE_SIMULATION_FRAME_BUDGET_USEC",
    "ENEMY_HANDOFF_IDLE_WARMUP_BUDGET_USEC",
    "ENEMY_CHAIN_WARMUP_BUDGET_USEC",
    "func _await_presentation_cadence",
    "func _step_idle_enemy_handoff_warmup",
    "_hidden_auto_pass_refreshes_avoided",
    "record_last_ai_presentation_timing",
):
    assert token in screen or token in facade, f"Enemy presentation pipeline is missing {token}"

# Remaining stalls still identify their exact stage.
assert "class_name RuntimeStallAttribution" in stall
assert "ENEMY_STALL_THRESHOLDS_USEC" in screen
assert "_enemy_stall_history" in screen

print("PASS — consolidated enemy-turn planning, cadence, hidden auto-pass and instrumentation are integrated.")
