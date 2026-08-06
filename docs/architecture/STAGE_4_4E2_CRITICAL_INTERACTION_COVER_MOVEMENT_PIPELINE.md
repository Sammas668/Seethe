# Stage 4.4e2 — Critical Interaction, Cover and Movement-Pipeline Correction

## Status

Implemented correction patch over Stage 4.4e1.

Stage 4.4e2 addresses the user-visible failures that remained after the cover UI
and movement-animation hotfix:

- edge-based doors and windows were still selected through tile inference;
- token cover icons described the worst visible attacker rather than the quality
  of physical cover at the position;
- movement, facing and attacks could commit and then report failure when later
  perception processing failed;
- planned door crossing could rely on stale closed-door detection geometry;
- persistent explored knowledge was mutated outside `TacticalStateStore`;
- geometry hot paths repeatedly scanned authored arrays.

The patch does not change the locked cover values, movement action economy,
automatic Peek, automatic Lean, body rules, extraction or mission resolution.

---

## 1. Edge-native Interact

Openings and edge structures are authored between two tiles. Presentation now
constructs exact interaction targets from their normalised edges and emits the
feature identity directly:

```text
TacticalBoardView
    highlighted edge bounds
    + screen-space interaction padding
        ↓
interaction_target_clicked(target_kind, target_id)
        ↓
TacticalScreen
        ↓
TacticalInteractionQuery / opening or structure handler
```

The screen no longer guesses the opening from the clicked adjoining tile. This
also keeps right-click free for facing and cancellation.

Relevant ownership:

```text
presentation/tactical/tactical_board_view.gd
    _interaction_target_at_screen_position()
    _distance_to_segment()
    interaction_target_clicked

presentation/tactical/tactical_screen.gd
    _on_board_interaction_target_clicked()
```

---

## 2. Local physical cover versus exact combat cover

Stage 4.4e2 intentionally separates two presentation questions.

### Local physical cover

`TacticalLocalCoverQuery` inspects known nearby geometry and returns:

```text
TacticalLocalCoverResult
    strongest_local_cover
    directional_cover_by_sector
    source_feature_ids
    geometry_revision
    knowledge_revision
```

The selected token and movement ghost use this result:

- low edge barrier: Light Cover / half shield;
- high or full barrier: Heavy Cover / full shield;
- adjacent substantial wall: Heavy Cover / full shield;
- no adjacent cover source: no shield.

The cyan field uses the directional result to explain which attack directions
benefit. This is a cheap presentation query and never supplies combat modifiers.

### Exact combat cover

Attack targeting and resolution continue to use the authoritative five-sample
`TacticalCombatGeometryQuery`:

```text
5 clear samples      No Cover
3–4 clear samples    Light Cover (+2 AC, +1 Reflex)
1–2 clear samples    Heavy Cover (+4 AC, +2 Reflex)
0 clear samples      Total Cover / direct attack blocked
```

This allows the local full shield beside a wall to coexist with an exact exposed
attack from an unprotected direction without corrupting combat rules.

---

## 3. Committed action semantics

`OperationResult` now distinguishes:

```text
REJECTED_BEFORE_COMMIT
COMMITTED
COMMITTED_WITH_WARNING
```

Movement, Sprint, facing and attack handlers now follow:

```text
validate
→ commit primary authoritative action
→ queue perception refresh
→ return committed result
```

They must not perform:

```text
commit action
→ refresh perception
→ return ordinary failure
```

because that invites callers to retry an action that already changed state.

`TacticalDetectionService` owns the queued squad IDs and exposes:

```text
request_current_perception_for_squad()
flush_requested_perception_refreshes()
```

A failed post-commit refresh returns `COMMITTED_WITH_WARNING`; the committed
movement, facing or damage remains valid.

---

## 4. Movement presentation boundary

Stage 4.4e1 already introduced the token animation boundary. Stage 4.4e2 removes
the synchronous perception call from the command handlers so that boundary can
actually begin promptly:

```text
movement validation and path resolution
→ authoritative TacticalChangeSet commit
→ return completed path
→ animate unit and dragged body
→ post-animation visibility/perception/cover/HUD refresh
```

The tactical state remains authoritative immediately. Presentation guards prevent
an animating unit from being snapped to the final tile before its tween completes.

---

## 5. Door and detection safety

A newly opened movement door is now an explicit route boundary:

```text
approach closed door
→ open door and spend operation cost
→ remain on near-side tile
→ refresh visibility, automatic Peek and detection using open geometry
→ issue a new movement command to cross
```

This is deliberately conservative. It prevents a route from being evaluated as
hidden by a closed door and then crossing after that door has opened.

A later candidate-environment implementation may allow safe continuation through
known doors, but it must preserve this detection guarantee.

---

## 6. Authoritative exploration

Visibility builds pending explored tiles as derived output. Persistent mission
knowledge is then committed through a separate `TacticalChangeSet`:

```text
visibility calculation
→ pending explored batches
→ TacticalChangeSet(reason = exploration_updated)
→ TacticalStateStore.commit()
→ knowledge revision and exploration invalidation
```

The visibility service no longer mutates `knowledge_state` directly from its
exploration commit method.

---

## 7. TacticalMapRuntimeIndex

The authored `TacticalMapDefinition` remains the content source. At runtime it
lazily compiles `TacticalMapRuntimeIndex`:

```text
PackedByteArray tile_flags
wall_material_by_tile
barrier_by_edge
opening_by_edge
structure_by_edge
barriers_by_id
openings_by_id
structures_by_id
```

Hot queries now use constant-time tile or normalised-edge lookup instead of
repeated `Array.has()` and full definition scans.

`TacticalEnvironmentState` also maintains an indexed dynamic-difficult set for
damaged and destroyed structures.

---

## 8. Spatial cache revisions

`TacticalState` supplies focused spatial revisions:

```text
occupancy_revision
visibility_blocker_revision
environment geometry_revision
```

`TacticalGeometryCacheService` keys exact geometry on those revisions rather than
`TacticalState.revision`. Inventory rearrangement and unrelated action-budget
changes therefore no longer invalidate every geometry relationship.

---

## 9. TacticalInvalidationFlags

`TacticalChangeSet` now carries `TacticalInvalidationFlags`:

```text
occupancy_changed
visibility_changed
exploration_changed
geometry_changed
environment_visuals_changed
inventory_changed
initiative_changed
token_status_changed
```

`TacticalStateStore` emits `state_changed_with_flags`. Visibility listens to the
typed flags and ignores changes that cannot affect sight or spatial geometry. The
legacy textual reason remains for logs and compatibility.

---

## 10. Runtime and static validation

Added runtime coverage for:

- compiled map lookup parity;
- full shield from adjacent substantial walls;
- explicit committed-result semantics;
- closed-door movement boundaries;
- state-store exploration commits;
- exact edge-native interaction hit testing.

Added `tests/static/validate_stage_4_4e2.py` to verify the correction boundary and
retain the earlier Stage 4.4 validators.

A usable Godot binary was not available in the packaging environment, so the
runtime suite must be executed locally with Godot 4.7.1.
