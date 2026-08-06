# Stage 4.2.4 — Phase compatibility hotfix

The scalable-map presentation expected the Stage 4.2 three-phase model:

- Player Phase
- Enemy Phase
- World Phase

An incomplete patch chain could leave the older Stage 4.1 `TacticalPhaseState`,
which only exposed `is_enemy_turn()` and treated the World Phase as the enemy
turn. The Stage 4.2.3 screen then called `is_enemy_phase()` on that older object.

This hotfix:

1. restores the authoritative Stage 4.2 `TacticalPhaseState`;
2. includes the complete phase-transition production chain in the patch;
3. uses direct `current_phase` comparisons in presentation and phase transition
   validation, avoiding unnecessary runtime helper-method dependence;
4. clears Godot's local class/import cache during patch application.

No combat, visibility, camera, pathfinding, damage, or AI rule is changed.
