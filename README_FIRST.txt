SEETHE — STAGE 4.7 HOTFIX 5e
ENEMY-TURN RESPONSIVENESS AND CADENCE PASS

This project contains the Seethe tactical build through Stage 4.7 Hotfix 5e.
It is authored for Godot 4.7.1.

WHAT HOTFIX 5e CHANGES
- Builds one bounded reachable movement field per AI activation instead of launching repeated A* searches for candidate destinations.
- Stores cheapest costs and predecessors, scores destinations, then reconstructs only the selected route.
- Replaces the shared pathfinder's linear open-set scan with a deterministic binary min-heap.
- Carries the selected AI route into authoritative movement commit and revalidates it without a second full path search.
- Resolves side-based Enemy Phase one complete actor at a time through resolve_next_enemy_activation().
- Batches cheap hidden actors while yielding at safe activation boundaries after an 8 ms simulation budget.
- Applies the same safe frame budget between consecutive initiative AI actors.
- Makes activation pulses non-blocking and removes separate phase, actor-handoff and move-to-attack dead-air timers.
- Accelerates long visible enemy routes while keeping short movement readable; ordinary AI movement is capped at 0.50 seconds.
- Retains normal presentation for reveals, alerts, interruptions, visible consequences and player Reaction decisions.
- Adds detailed per-stage simulation diagnostics and a retained history of the twelve slowest activations, including presentation time.

AUTHORITY PRESERVED
Movement legality, diagonal parity, movement cost, action spending, detection, Reactions, attack resolution, final positions and hidden-information redaction are unchanged. Frame yielding occurs only between complete authoritative activations.

RUN THE PROJECT
1. Import project.godot into Godot 4.7.1.
2. Run the project.
3. Launch an authored mission from the mission selector.
4. Test both side-based Enemy Phase and individual initiative combat with visible and hidden enemies.

RUN VALIDATION
Static checks:
  python tools/testing/run_stage_4_7_validation.py --skip-runtime

Complete validation with a local Godot executable:
  python tools/testing/run_stage_4_7_validation.py --godot "/path/to/Godot_v4.7.1"

Direct Hotfix 5e runtime suite:
  Godot_v4.7.1 --headless --path . --script res://tests/integration/run_stage_4_7_hotfix_5e_tests.gd

READ NEXT
- docs/architecture/STAGE_4_7_HOTFIX_5E_ENEMY_TURN_RESPONSIVENESS_AND_CADENCE.md
- STAGE_4_7_HOTFIX_5E_RELEASE_NOTES.txt
- STAGE_4_7_HOTFIX_5E_VALIDATION_RESULTS.txt
- STAGE_4_7_HOTFIX_5E_PATCH_README.txt

KNOWN VALIDATION LIMIT
The release environment did not contain a usable Godot executable. All static suites, package checks and patch-reproduction checks were run. The included Godot runtime suite still needs to be executed locally before treating Hotfix 5e as runtime-locked.
