# Stage 5.2a Update 1 — 7×7 Ruin and Unified Facility Footprints

## Purpose

Preserve the existing stronghold-management screen while improving the base grid in the two areas approved after the Stage 5.2a prototype:

1. the starting Fifth-God ruin is now an authored 7×7 room-scale grid;
2. every facility is presented as one illustrated object spanning its complete footprint.

The update does not introduce construction, facility actions, workers, furniture placement or base-defence generation.

## Presentation boundary

The plot grid remains authoritative for occupancy, connectivity, save data and future tactical-module assembly. Presentation groups every plot with the same facility-instance ID into one rectangular `FacilityFootprintView` drawn by `StrongholdGridView`.

The 2×2 Heart therefore retains four authoritative plot records but has:

- one artwork surface;
- one exterior frame;
- one label;
- one hover target;
- one selection target;
- one condition overlay;
- no visible internal seams or internal connector marks.

Clicking any Heart coordinate canonicalises selection to the facility origin at `(2, 2)`.

## Data changes

`StrongholdDefinition` now includes:

- `layout_version`;
- data-driven facility presentation definitions;
- validation that fixed multi-plot facilities form one rectangular footprint.

`StrongholdState` now includes:

- `definition_layout_version`;
- `plots_for_facility()`;
- `facility_origin()`;
- `facility_footprint()`;
- `canonical_coord()`.

The layout version permits the pre-construction 6×6 prototype to migrate safely. Because Stage 5.2c construction is not yet live, a mismatched stronghold layout is replaced atomically with the new authored 7×7 starting state.

## Starting ruin

The first authored layout is:

```text
###G###
#SAAAS#
RAHHAAR
#AHHAS#
RAAAAAR
#SARAS#
##R#R##
```

Legend:

- `H` — fixed Heart;
- `G` — fixed entrance;
- `A` — available;
- `R` — ruined;
- `S` — sealed;
- `#` — permanent block.

All accessible plots remain orthogonally connected to both the entrance and Heart.

## Facility art contract

Each presentation definition provides:

- facility ID;
- display name and description;
- strategic-screen art path;
- fallback symbol;
- accent colour;
- expected footprint.

The update supplies initial top-down illustrated SVG room art for:

- Fifth-God Heart;
- Broken Gatehouse;
- Storehouse;
- Muster Hall;
- Recovery Chamber;
- Prison;
- Workshop;
- Reaver Warcamp Foundation.

Only the fixed Heart and entrance currently appear in campaign state. The remaining art assets prepare Stage 5.2b without adding those facilities early.

## Drawing order

`StrongholdGridView` draws:

1. external connectivity lines;
2. non-facility plot cells;
3. one grouped facility surface per facility instance;
4. whole-facility condition, label, hover and selection treatments;
5. selected or hovered external connection points.

Connectors between two plots owned by the same facility are suppressed in presentation.

## Interaction rules

- Empty, sealed, ruined and blocked plots remain individually selectable.
- Any occupied facility coordinate selects the shared facility origin.
- Crossing an internal cell boundary does not change hover identity or flicker selection.
- The inspector shows the facility name, complete footprint, origin and shared description.
- The existing stronghold screen layout and navigation are unchanged.

## Save compatibility

Campaign save version remains 9. `StrongholdState.definition_layout_version` is backward-compatible: older saves deserialize as version `0`, then `StrongholdDefinitionRegistry` rebuilds the Stage 5.2a pre-construction ruin at layout version `2`.

## Non-goals

This update deliberately does not add:

- construction commands or placement confirmation;
- animated workers or residents;
- facility event pips;
- persistent scars or trophies;
- campaign-reactive Heart animation;
- facility sound layers;
- defence-memory overlays;
- adjacency bonuses;
- free-placement furniture.
