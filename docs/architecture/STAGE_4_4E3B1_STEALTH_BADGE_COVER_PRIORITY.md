# Stage 4.4e3b1 — Stealth Badge and Cover-Shield Priority Correction

## Purpose

Prevent the destination cover shield from obscuring the per-tile Stealth avoidance percentage restored in Stage 4.4e3b.

This is a presentation-only correction. It does not change pathfinding, cover calculation, Stealth probability, detection resolution, movement commitment or cadence.

## Locked display priority

For each movement-path tile:

1. invalid or interrupted movement warning;
2. Stealth risk badge and percentage, `?`, or `0%` warning;
3. destination cover shield;
4. ordinary path decoration.

A tile must never render both the Stealth risk badge and the movement-ghost cover shield.

## Destination rule

`TacticalBoardView._draw_movement_ghost()` continues to draw the destination ghost and directional-cover field. Before drawing the compact Light/Heavy cover shield, it checks whether the destination has a visible `MovementDetectionTilePreview`.

```gdscript
if (
    not _tile_has_detection_badge(destination)
    and category in [
        TacticalCombatGeometryResult.COVER_LIGHT,
        TacticalCombatGeometryResult.COVER_HEAVY,
    ]
):
    _draw_cover_badge(...)
```

`_tile_has_detection_badge()` uses `MovementDetectionPreview.preview_for_tile()` and `MovementDetectionTilePreview.has_detection_risk()`. It therefore suppresses the shield for:

- a normal Stealth roll percentage;
- unknown observation shown as `?`;
- automatic detection shown as `0%` outside Stealth.

## Preserved behaviour

- The destination ghost remains visible.
- The cyan directional-cover field remains visible.
- The route-wide cover summary remains available through the existing movement presentation.
- Cover shields remain visible on destinations without Stealth-risk information.
- Selected-unit and attack-target cover shields retain their existing contextual rules.
- Empty-tile hover remains presentation-only.
- The clicked route and Stealth preview remain locked until replaced, cancelled or invalidated.

## Performance boundary

The correction performs no new tactical query. It reads the already-built `MovementDetectionPreview` once during dynamic board drawing.

## Acceptance criteria

1. A risky destination displays its Stealth badge and percentage without a cover shield over it.
2. An unknown-risk destination displays `?` without a cover shield.
3. A certain-detection destination displays `0%` without a cover shield.
4. A destination with Light or Heavy Cover and no Stealth risk still displays the cover shield.
5. The movement ghost and directional-cover field remain visible in both cases.
6. No movement, detection, cover or visibility query is added to cursor hover.
