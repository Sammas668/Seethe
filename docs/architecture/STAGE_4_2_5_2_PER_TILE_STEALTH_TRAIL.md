# Stage 4.2.5.2 — Per-Tile Stealth Trail and Interruption

## Player-facing contract

Movement colours continue to show reach and remaining turn capacity. Stealth information is overlaid only on tiles that require a visual detection check.

Each risky path tile displays:

- the shared hooded-Stealth icon;
- that tile's chance to avoid detection;
- `?` when the relevant observer is not legitimately known to the player;
- `0%` with a slash when the unit is moving through perception outside Stealth.

The preview is produced by `TacticalDetectionService.preview_for_path()` and is read-only. The command handler recalculates all detection exposure when movement is committed.

## Resolution contract

For every risky tile entered in path order:

1. collect all eligible observers perceiving that tile;
2. roll one d20 for the moving unit when Stealth is active;
3. add the unit's Stealth modifier;
4. compare the same total against every observer's Detection DC;
5. continue automatically if every comparison passes;
6. stop after entering the tile if any comparison fails.

The movement command then commits a path truncated to the first failed tile. Ordinary movement spends only the recalculated cost of that committed path. Sprint retains its Full Action cost.

## State boundaries

`MovementDetectionPreview` owns aggregate path information and an ordered array of `MovementDetectionTilePreview` records.

`TacticalDetectionResolution` owns an ordered array of `TacticalDetectionTileCheck` records and the first interruption index.

Presentation never rolls dice or changes awareness. Command handlers never infer outcomes from the preview.

## Roll-log contract

Every resolved tile check publishes a structured roll event containing:

- raw d20 result;
- Stealth modifier;
- final total;
- observer Detection DC;
- natural d20 result required to meet that DC;
- pass or fail outcome.

Where several observers perceive the same tile, the event contains one comparison record per observer but repeats the same shared d20 result.

## Non-goals

This stage does not add hearing, noise propagation, suspicion states, suspected-position markers, modal alert presentation, or sophisticated search planning beyond the existing Last Seen Position behaviour.
