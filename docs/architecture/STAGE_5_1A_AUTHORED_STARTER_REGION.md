# Stage 5.1a — Authored Starter Region

## Corrected completion gate

The campaign displays a data-driven reconstruction of the original 20-by-15
Life-realm region, including all fourteen settlements, corrected multi-hex city
footprints, the original yellow road-edge network, the original red
subregional-border network, lakes, marshes, forest, deep forest, a fixed
Fifth-God stronghold and a separate ancient forest ruin. The Farm Raid remains
anchored to a real regional site.

## Static content boundary

The authored map is static content and is not copied into every campaign save.
`CampaignState` stores only `current_region_id`; mission instances reference a
`site_id`. `RegionDefinitionRegistry` resolves those identities into the static
`RegionMapDefinition`.

```text
CampaignState.current_region_id
→ RegionDefinitionRegistry
→ RegionMapDefinition
   ├── 300 RegionHexDefinition records
   ├── 39 RegionSiteDefinition records
   ├── 145 public road-edge records
   ├── 54 subregion-border edge records
   └── 4 hidden stronghold approach routes
```

Legacy Stage 5.0 IDs remain aliases:

- `region.life.verdant_march` → `region.life.starter`
- `site.life.southroad_farm` → `site.farm.starter_storehouse`
- `site.fifth_god.ruin` → `site.fifth_god_ruin`

## Correct source-map interpretation

The source map uses two independent edge overlays:

- yellow edge segments are public roads;
- red edge segments are subregional borders.

Neither is represented by a centre-to-centre generated path. The two
transcriptions live in separate content files:

- `life_starter_region_road_edges.json`;
- `life_starter_region_border_edges.json`.

Each record identifies an authored hex edge by owner coordinate and edge index.
This preserves dead ends, boundary exits, junctions and segments that share a
hex without inventing additional connections.

The hidden approach routes to the stronghold remain strategic route data, but
all are `visible_by_default = false` and use `hidden_track`. They are not public
roads and are not drawn on the Region Map.

## Terrain transcription

`life_starter_region_hexes.csv` remains the human-readable 20×15 terrain
transcription. The six terrain categories are:

- grassland;
- farmland;
- lake;
- marsh;
- forest;
- deep forest.

`RegionMapView` now gives every category a distinct terrain treatment rather
than relying on fill colour alone: meadow grass and flowers, crop rows, water
waves, reeds and pools, open forest canopies and dense overlapping deep forest.

## Settlements and footprints

The fourteen permanent settlement identities remain unchanged. The corrected
multi-hex footprints are:

- Telluria — seven occupied district hexes;
- Westmarch — four occupied hexes;
- Solis — three occupied hexes;
- Oakstead — three occupied hexes.

Each occupied hex has its own district site and building marker. The parent
settlement provides the shared label and inspection identity. The remaining
settlements use one authored hex each.

Telluria contains:

- Wheat Warehouse;
- Lumbermill;
- Textiles Warehouse;
- Craftsman’s District;
- Guild House;
- Noble Housing;
- East Merchant Quarter.

The final entry represents the seventh occupied city hex visible in the source
layout without changing the six original category names.

## Two forest ruins

The original black ruin marker is preserved as:

- `site.wilderness.deep_forest_ruins` — Ancient Forest Ruin at 17,12.

The player’s separate concealed base is:

- `site.fifth_god_ruin` — Fifth-God stronghold at 18,13.

Both are deep-forest sites with separate identities and markers. No visible
public road edge touches the Fifth-God stronghold.

## Stronghold approaches

Four unmarked authored routes still reach the stronghold for later strategic
systems:

- Lullin Woodpath;
- Oakstead Track;
- Ascot Track;
- Laencaster Purge Route.

These paths support future travel, raid origins and tactical entry directions,
but they remain hidden from the public road presentation.

## Presentation

`RegionMapView` renders in this order:

1. terrain fills;
2. terrain-specific symbols;
3. normal hex outlines;
4. multi-hex settlement pads;
5. yellow public road edges;
6. red subregional border edges;
7. district, settlement, mission and ruin markers;
8. settlement and strategic-site labels.

The Stage 5.0 top-only shell remains unchanged. The map keeps the complete
remaining workspace and contextual information still overlays rather than
resizing it.

## Scope boundary

Stage 5.1a still introduces no Agent, discovery-radius, mission-expiry, travel,
Notoriety, enemy-operation, trading or settlement-simulation state. It provides
the corrected static geography those later systems will use.
