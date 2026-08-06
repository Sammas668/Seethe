# Stage 4.3.2s — Body-Item Status Overlays and Carrier-Downing Correction

## Purpose

Stage 4.3.2 established fallen characters as one real body item linked to the
original tactical character. Stage 4.3.2s completes two missing behaviours:

1. every inventory rendering of a body shows the linked character's live status;
2. an incapacitated carrier cannot retain another character's body in packed
   storage.

No HP, Dying, Stable, restraint or death state is copied onto the body item.
`TacticalUnitState` remains authoritative and the body item retains only its
`linked_unit_id` and physical item location.

## Shared status source

`TacticalStatusBadgeProvider` is the shared presentation query used by both the
tactical token and inventory body controls. It derives:

- primary life-state badge: Dying, Unconscious or Dead;
- Dying success and failure pips;
- the Stable marker;
- the secondary Restrained marker.

`TacticalBodyStatusOverlay` renders that snapshot over a body item. The overlay
uses the existing status SVGs and matching colours, ignores all mouse input and
therefore cannot interfere with selection, right-click, dragging or dropping.

Body overlays are rendered in:

- Items in Reach;
- Backpack;
- Belt when a sufficiently small body legally fits;
- Primary and Secondary Hand slots;
- body-item drag previews.

The display name remains `Character Name's Body`; status text is not appended.
An open inventory is rebuilt from committed tactical state on `state_changed`,
so First Aid, healing, Dying checks, restraint, Untie and death update body
badges without closing the window.

## Authoritative map-token visibility

`TacticalState.should_body_token_be_visible()` centralises the rule:

```text
tactical ground                 -> visible
Hand with transport_mode=dragging -> visible
Backpack or Belt                -> hidden
other non-ground locations      -> hidden
```

The inventory UI never hides or shows a tactical token directly. Item transfer
commits first; tactical presentation then reads the body's authoritative
location.

The Belt no longer has a body-specific prohibition. Ordinary spatial fit remains
authoritative: the current 4x3 Medium body cannot fit the current Belt, but a
future smaller body may legally fit and is then treated as packed.

## Incapacitated-carrier release

During `TacticalChangeSet.execute()`, life-state mutations apply first and
`TacticalState.synchronise_body_items()` reconciles all body representation
before validators and invariants run.

For each Dying, unconscious or Dead carrier, synchronisation:

1. releases every body being dragged in a Hand;
2. finds every body item in the carrier's packed inventory;
3. places packed bodies onto deterministic legal ground cells;
4. creates or updates the carrier's own linked body item;
5. rebuilds ground-item and standing-occupancy indexes.

Ordinary equipment remains in the carrier's inventory.

### Dragged bodies

A Hand body already exists on tactical ground. It is converted to an ordinary
ground location while preserving its current dragged cell. Only if that cell is
invalid does it use the adjacent-body resolver.

### Packed bodies

Packed bodies are sorted by stable item ID. Candidate cells use this order:

```text
north, north-east, east, south-east,
south, south-west, west, north-west
```

A candidate must be inside the map and free of blocking terrain for the linked
body's tactical footprint. Standing units, normal ground items and other bodies
do not invalidate the cell because bodies are low-profile, non-blocking ground
objects.

Distinct unused legal cells are preferred. If all legal neighbours are already
used, bodies may share a legal cell. If no adjacent cell is legal, the carrier's
own tile is the deterministic no-loss fallback.

Every ground placement updates both:

- the body item's `location.map_position`;
- the linked fallen character's `grid_position`.

## Atomicity and rollback

The body-representation snapshot now includes:

- every body item's exact location;
- every unit's linked body-item ID;
- every unit's grid position;
- every unit's awaiting-placement state.

If any validator or invariant rejects the transaction, rollback restores these
values before body synchronisation runs again. A carried body therefore cannot
be partially dropped by a failed damage transaction.

A downed-unit invariant rejects any completed state in which that unit still
contains a packed body item. This also corrects loaded or migrated states when a
new `TacticalSession` synchronises body representation.

## Non-blocking presentation order

```text
attack/effect resolves
-> HP and life state stage
-> packed bodies drop and dragged bodies release
-> carrier body activates
-> transaction commits
-> spatial indexes rebuild
-> log and state events publish
-> body token visibility and inventory badges refresh
-> hit reaction starts independently
-> turn continues
```

No status overlay, token refresh or carried-body release awaits a tween or locks
input, initiative or AI.

## Acceptance coverage

The Stage 4.3.2 runtime suite now checks that:

- Dying pips and restraint derive from the linked unit;
- Stable bodies retain the Unconscious badge plus Stable marker;
- a downed carrier retains no packed body items;
- packed bodies return to tactical ground and become visible;
- a dragged body releases on its existing valid cell;
- ordinary equipment remains packed;
- the carrier's own body is still created.

Stage 4.3.2s static validation additionally verifies the shared provider,
overlay input behaviour, inventory integration, location-derived visibility,
deterministic placement, rollback fields and release documentation.
