#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validation_common import (
    ROOT,
    finish,
    forbid_tokens,
    require_file,
    require_tokens,
    validate_balanced_delimiters,
    validate_resource_references,
    validate_tab_indentation,
    validate_unique_class_names,
)


def main() -> int:
    failures: list[str] = []

    required_files = [
        "bootstrap/app/game_app.gd",
        "bootstrap/app/campaign_session.gd",
        "application/campaign/new_campaign_service.gd",
        "application/missions/campaign_mission_coordinator.gd",
        "application/strategic/strategic_clock_service.gd",
        "domain/campaign/campaign_status.gd",
        "domain/campaign/campaign_resource_balances.gd",
        "domain/missions/active_mission_state.gd",
        "presentation/campaign/main_menu.gd",
        "presentation/campaign/main_menu.tscn",
        "presentation/campaign/campaign_shell.gd",
        "presentation/campaign/campaign_shell.tscn",
        "presentation/campaign/widgets/region_map_view.gd",
    ]
    for path in required_files:
        require_file(path, failures)

    require_tokens(
        "bootstrap/boot/boot.gd",
        ["extends GameApp"],
        failures,
    )
    forbid_tokens(
        "bootstrap/boot/boot.gd",
        ["DebugMissionSelector", "debug_mission_selector.tscn"],
        failures,
    )
    require_tokens(
        "bootstrap/app/campaign_session.gd",
        [
            "var state_store: CampaignStateStore",
            "var mission_coordinator: CampaignMissionCoordinator",
            "create_new_campaign",
            "load_campaign",
            "restore_safe_checkpoint",
            "commit_tactical_envelope",
        ],
        failures,
    )
    require_tokens(
        "domain/campaign/campaign_state.gd",
        [
            "campaign_id",
            "campaign_seed",
            "campaign_tick",
            "protagonist_character_id",
            "current_region_id",
            "resources",
            "active_missions_by_id",
            "next_mission_sequence",
            "latest_committed_result_id",
        ],
        failures,
    )
    require_tokens(
        "domain/missions/active_mission_state.gd",
        [
            "mission_instance_id",
            "mission_definition_id",
            "registered_setup_dictionary",
            "setup_hash",
            "mission_seed",
            "source_campaign_revision",
        ],
        failures,
    )
    require_tokens(
        "domain/missions/mission_setup_snapshot.gd",
        ["var _mission_seed", '"mission_seed": mission_seed', "verify_integrity"],
        failures,
    )
    require_tokens(
        "infrastructure/persistence/json_campaign_repository.gd",
        [
            "SAVE_ENVELOPE_SCHEMA_VERSION",
            "save_safe_checkpoint",
            "load_safe_checkpoint",
            "safe_checkpoint_backup_path",
            "unsupported campaign version",
        ],
        failures,
    )
    require_tokens(
        "application/missions/campaign_mission_coordinator.gd",
        [
            "post_registration_revision",
            "save_safe_checkpoint",
            "build_registered_setup",
            "restart_registered_mission",
            "commit_tactical_envelope",
            "already_applied",
        ],
        failures,
    )
    require_tokens(
        "presentation/campaign/campaign_shell.gd",
        [
            "SCREEN_REGION",
            "SCREEN_STRONGHOLD",
            "SCREEN_ROSTER",
            "SCREEN_EQUIPMENT",
            "SCREEN_BRIEFING",
            "SCREEN_SUMMARY",
            "SCREEN_DEFEAT",
            "_workspace.offset_top = 122",
            "RegionMapView.new",
            "PLAN ROUTE",
            "SEND SQUAD",
            "CONTINUE TO REGION MAP",
            "RELOAD LAST SAFE STATE",
        ],
        failures,
    )
    shell = require_file("presentation/campaign/campaign_shell.gd", failures)
    for forbidden in ["BOTTOM STATUS", "bottom_status_strip", "persistent_left_navigation"]:
        if forbidden in shell:
            failures.append(f"campaign shell contains forbidden permanent workspace chrome: {forbidden}")
    for hidden_stage_button in ["RESEARCH", "PRODUCTION", "MARKET", "CAPTIVES"]:
        if f'button.text = "{hidden_stage_button}"' in shell:
            failures.append(f"campaign shell exposes unfinished navigation: {hidden_stage_button}")

    tactical_forbidden = [
        "CampaignStateStore",
        "CampaignRepository",
        "JsonCampaignRepository",
        "CampaignResultCommitService",
        "CampaignState",
    ]
    for base in [ROOT / "application/tactical", ROOT / "presentation/tactical"]:
        for path in base.rglob("*.gd"):
            text = path.read_text(encoding="utf-8", errors="ignore")
            for token in tactical_forbidden:
                if token in text:
                    failures.append(
                        f"{path.relative_to(ROOT)} retains forbidden live campaign dependency: {token}"
                    )

    require_tokens(
        "application/tactical/extraction/resolve_tactical_mission_handler.gd",
        ["_pending_envelope", "pending_commit_envelope", "campaign commitment is pending"],
        failures,
    )
    forbid_tokens(
        "application/tactical/tactical_session.gd",
        ["var campaign_store", "campaign_store_value"],
        failures,
    )
    require_tokens(
        "presentation/tactical/tactical_screen.gd",
        ["signal mission_result_ready", "_emit_mission_result_ready"],
        failures,
    )

    validate_resource_references(failures)
    validate_unique_class_names(failures)
    validate_tab_indentation(failures)
    validate_balanced_delimiters(failures)

    return finish(
        "Stage 5.0 Campaign Shell",
        failures,
        [
            "production boot enters Main Menu rather than the debug selector",
            "one CampaignSession owns campaign persistence and mission coordination",
            "top-only shell reserves the remaining screen for the workspace",
            "tactical code returns an immutable result envelope without a live campaign reference",
        ],
    )


if __name__ == "__main__":
    raise SystemExit(main())
