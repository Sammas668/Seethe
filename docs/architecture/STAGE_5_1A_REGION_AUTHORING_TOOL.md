# Stage 5.1a Hotfix — Region Authoring Tool

## Boundary

The authoring tool is a development-only static-content workflow. It loads a
`RegionMapDefinition` into a mutable `RegionAuthoringDocument`, validates it and
exports a fresh runtime definition. It never receives `CampaignState`, a
campaign repository or the strategic clock.

```text
RegionMapDefinition
    ↓ import
RegionAuthoringDocument
    ↓ validate
RegionExportService
    ↓
RegionMapDefinition runtime files
    ↓
Campaign RegionMapView
```

The former image-reference overlay was removed. The authoring canvas and
campaign view now render only authoritative region data.

## Shared contracts

The editor and campaign share:

- `RegionHexCoord` coordinate conversion;
- `RegionTerrainType` terrain IDs;
- `RegionMapEdgeDefinition` road/border edges;
- `RegionSymbolCatalogue` deterministic symbols;
- `RegionMapView` rendering and labels.

Editor-only state is limited to camera and working metadata. It is omitted from
runtime exports.

## Data separation

- `road_edges_by_id`: public travel and visible road edges.
- `border_edges_by_id`: subregional boundary edges.
- `routes_by_id`: hidden or scripted strategic paths.
- settlement footprints: occupied city hexes.
- district sites: one deterministic symbol per authored city hex.

None of these collections is inferred from another.

## Persistence

The editor maintains one explicit working document path. On startup it restores
the last path from `user://region_authoring/editor_state.json` and loads that
working file when present.

Manual save flow:

```text
serialize candidate
→ write temporary file
→ parse and verify temporary file
→ rotate previous working file to backup
→ atomically replace working file
→ parse and verify final file
→ remove stale recovery copy
```

Recovery flow:

```text
edit becomes dirty
→ delayed recovery write tied to active working path
→ startup compares recovery and working timestamps
→ developer chooses recovery or saved working file
```

Closing the editor attempts a main working-file save. A persistence failure
blocks the close request, preventing silent loss.

Authoring files remain completely separate from campaign saves and production
runtime content.

## Responsive editor layout

The editor targets the project's 1280 × 720 reference window. Persistent panels
must remain visible without making the root control wider than the viewport.

- The command bar uses compact `FILE` and `EXPORT` menus.
- The left contextual tool panel has a 204-pixel minimum width.
- The map canvas may shrink to 400 pixels before side panels are clipped.
- The right Properties panel has a 380-pixel minimum width.
- The Properties scroll view disables horizontal scrolling and uses one-column
  layer controls.

The map canvas absorbs ordinary width changes; the contextual and Properties
panels remain readable and inside the window.
