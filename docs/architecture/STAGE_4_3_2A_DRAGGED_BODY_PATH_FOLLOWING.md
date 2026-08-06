# Stage 4.3.2a — Dragged-Body Path-Following Hotfix

## Defect

Stage 4.3.2 represented a dragged body as a real body item in a Hand with `transport_mode == &"dragging"`. The movement transaction moved the carrier directly from the route origin to the committed destination. The body update then reused only the carrier's original tile.

That happened to be correct for a one-tile route, because the body should finish in the carrier's former tile. It was incorrect for longer routes: the body remained at the route origin rather than following behind the carrier.

## Authoritative rule

For any committed route:

```text
carrier path: A → B → C → D
carrier final tile: D
dragged body final tile: C
```

The body always occupies the penultimate tile of the **actually committed path**, including paths shortened by detection or another movement interruption.

A route containing only the origin performs no body movement. A one-step route `[A, B]` leaves the body at `A`.

## Shared state operations

`TacticalState` owns shared helpers for all movement handlers:

```gdscript
func dragged_body_cell_snapshot(unit_id: StringName) -> Dictionary
func move_dragged_bodies_to_cell(unit_id: StringName, cell: Vector2i) -> bool
func restore_dragged_body_cells(snapshot: Dictionary) -> void
```

The snapshot is keyed by body item ID so rollback restores each dragged body to its exact earlier ground cell. This supports two occupied Hand slots without assuming that both bodies began on the same tile.

Moving a dragged body updates both:

- the body item's `location.map_position`;
- the linked fallen unit's `grid_position`.

The body and standing-occupancy indexes are rebuilt after the update.

## Transaction sequence

```text
calculate complete legal route
→ resolve any path interruption
→ derive committed destination
→ derive penultimate dragged-body cell
→ snapshot current dragged-body cells
→ stage carrier movement and body following together
→ stage movement cost
→ commit once
```

If any later staged operation fails:

```text
restore carrier origin and facing
→ restore every dragged body from its item-ID snapshot
→ rebuild spatial indexes
```

The body cannot remain partially advanced after a failed transaction.

## Movement coverage

The correction is applied consistently to:

- ordinary player movement;
- Sprint movement;
- enemy-AI movement.

No movement handler maintains a separate interpretation of where a dragged body finishes.

## Presentation

Before the player movement command commits, `TacticalScreen` records the visible ground cell of each dragged body. After the committed path returns, the carrier animates through the full path and each body animates through:

```text
original body cell
→ carrier path origin
→ every carrier path tile except the final destination
```

Duplicate consecutive cells are removed. The effect is fire-and-forget presentation and does not delay input, initiative or AI.

## Acceptance criteria

1. A one-tile move leaves the body in the carrier's original tile.
2. A multi-tile move places the body in the committed path's penultimate tile.
3. The linked fallen character's position matches the body item.
4. An interrupted route uses the penultimate tile of the shortened committed path.
5. Transaction rollback restores the exact earlier cell for every dragged body.
6. Ordinary movement, Sprint and AI movement use the same rule.
7. Player presentation shows the body following one tile behind rather than remaining at the origin.
