SEETHE — STAGE 5.2a UPDATE 1
7×7 RUIN AND UNIFIED FACILITY FOOTPRINTS

This project contains Seethe through Stage 5.2a Update 1 and targets Godot 4.7.1.

WHAT CHANGED
- The starting stronghold is now an authored 7×7 grid.
- The Dungeon/Fifth-God Heart is one continuous 2×2 illustrated facility.
- All future multi-square facilities use the same merged-footprint presentation.
- Hover, selection, labels, condition overlays and external connectors operate on the whole facility.
- Initial strategic-screen SVG art is included for the Heart, gate and first Stage 5.2b facilities.

RUN
1. Import project.godot into Godot 4.7.1.
2. Start or load a campaign.
3. Open RUIN from the campaign shell.

VALIDATE
Static:
  python tools/testing/run_stage_5_2a_validation.py

Runtime:
  Godot_v4.7.1-stable --headless --path . --script res://tests/integration/run_stage_5_2a_update_1_tests.gd

READ NEXT
- docs/architecture/STAGE_5_2A_UPDATE_1_UNIFIED_FACILITY_FOOTPRINTS.md
- STAGE_5_2A_UPDATE_1_RELEASE_NOTES.txt
- STAGE_5_2A_UPDATE_1_VALIDATION_RESULTS.txt
