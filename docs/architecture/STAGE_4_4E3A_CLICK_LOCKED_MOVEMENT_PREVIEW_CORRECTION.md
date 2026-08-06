# Stage 4.4e3a — Click-Locked Movement Preview Correction

## Problem

Stage 4.4e3 correctly reduced post-movement visibility work, but the presentation screen still called destination pathfinding whenever the cursor entered an empty tile. That contradicted the agreed movement input contract and created continuous path replacement while the mouse moved.

The visual path and the actual `_planned_destination` could also diverge: the locked destination remained authoritative while hover temporarily replaced `_preview_result`, `_cover_preview` and the directional cover field.

## Authoritative input contract

```text
Hover an empty tile
→ draw the ordinary hover highlight only
→ perform no pathfinding

First left-click on a legal destination
→ calculate one TacticalDestinationPreview
→ store MOVE_PREVIEW and the clicked destination
→ display the locked path
→ do not move

Move the cursor
→ preserve the clicked destination and preview
→ do not calculate another movement path

Second left-click on the same destination
→ execute movement

Left-click another legal empty tile
→ calculate and lock the replacement preview
→ do not move

Right-click
→ clear the locked preview
```

## Presentation ownership

`TacticalScreen._on_board_tile_hovered()` now owns only transient hover presentation. It may refresh First Aid or attack cursor context, but it cannot call movement preview or destination geometry queries.

`TacticalScreen._begin_or_update_move_preview()` is the only ordinary player-input path that creates a destination movement preview. It is entered by a left-click.

`TacticalScreen._refresh_path_preview()` may recalculate only an existing clicked destination after a genuine tactical-state invalidation. When no `MOVE_PREVIEW` intent exists, it clears stale destination visuals and returns.

## HUD and board refresh boundary

The board still redraws once when the hovered tile changes so the cheap tile highlight remains responsive. The full HUD refresh occurs only when an attack-hover context begins, ends or changes target. Empty-tile hover does not refresh the HUD.

## Non-regression boundary

This patch does not revert or alter:

- Stage 4.4e3 per-unit visibility contributions;
- targeted post-movement visibility release;
- one-frame movement handoff;
- movement animation;
- automatic Peek or Lean rules;
- attack hover previews;
- Interact or facing controls;
- movement legality, cost or commitment rules.
