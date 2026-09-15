# For Carrot and Honour

For Carrot and Honour is a real-time, pausable medieval-fantasy strategy game about ruling a bunny kingdom across one fixed, handcrafted continent. The interactive world map is intended to be the primary playing field, with province management available through panels. The project is built with Godot 4 and typed GDScript.

## Current gameplay scene

Open **[`scenes/gameplay/world_gameplay.tscn`](scenes/gameplay/world_gameplay.tscn)** and press **F6**. Gameplay 001 instances the completed NaturalWorld, provides geographic hover and persistent click selection for all 100 active provinces, and displays separate prototype province and realm state in a plain debug panel. Left click selects, Escape clears selection, WASD or middle drag pans, and the wheel zooms.

The corrected geography is generated from the immutable Azgaar source plus `data/world_map/astra_province_corrections.json`. Seven IDs are retired without reuse; the accepted targeted topology adds IDs 90-107 and reserves 108 as the next fresh ID. The 100-province topology and dual-sided political border presentation are manually accepted.

## Current natural-world inspection scene

Open **[`scenes/world_map/astra_natural_world_final.tscn`](scenes/world_map/astra_natural_world_final.tscn)** in Godot 4.7.1 and press **F6**. The atmospheric finish replaces the water rendering with animated ocean waves, reflected light, shoaling crests and selected obstacle foam. Sparse visible cloud volumes cast matching moving shadows. Reworked sunlight, canopy response, ground materials and mountain shading give the same accepted world a more cohesive presentation. Default camera: **40° / 1,600 units**, current gameplay envelope **800–3,600**; eventual player zoom limits remain open.

WASD/middle drag pan; wheel zooms; Home resets; 1–9 visit regions; 0 cycles discoveries; V toggles top-down; F frames the continent; P hides natural props; H hides inspection controls. The scene initializes its materials and batches at runtime.

See [`docs/world_map/astra_natural_world.md`](docs/world_map/astra_natural_world.md) for provenance, review and implementation boundaries. DEV-020 supersedes the previous conservative artistic handoff. All **576 terrain regions, authoritative heights, masks and river routes** remain intact; province geography was corrected later through DEV-022 without changing the world. The concise handoff is `C:\Projects\FCAH_ASTRA_WORKSPACE\ASTRA_FINAL_BEAUTY_HANDOFF.md`; the recoverable prior project is in `06_Astra_Checkpoints/Natural_Beauty_2026-09-09/` in that workspace.

## Current phase

**Terrain / natural-world production: COMPLETE. Gameplay 001: COMPLETE. Corrected 100-province geography and political borders: ACCEPTED.**

Stage 1 simulation and content-model foundations are complete. Further simulation expansion is paused until the world-map proof passes.

The repository now includes a minimal full-continent terrain import test built from the completed Astra handoff. It loads the 4096 x 2304 float32 playable crop through Terrain3D 1.0.2 with the exact north-up alignment and documented physical proportions. This historical scene proves terrain loading only. The current natural-world scene above adds presentation while settlements, roads and gameplay remain deferred.

The matching Astra Features RGBA image now has an exact 4096 x 2304 playable crop. A dedicated QA scene reads that crop as raw linear RGBA8 data and overlays only its authoritative R-channel land coverage on the unchanged Terrain3D baseline. Numerical offset testing and GPU renders verify that the two sample grids coincide.

The authoritative province data layer is reproducible. A correction manifest assigns previous gaps and inland water, retires absorbed tiny IDs, repairs fragmentation and adds coherent eastern wilderness provinces before the typed-GDScript importer emits full-precision rings, anchors, bounds, areas and neighbors. See [`docs/world_map/astra_province_data.md`](docs/world_map/astra_province_data.md).

The disposable [`astra_biome_preview.tscn`](scenes/world_map/astra_biome_preview.tscn) now provides the first useful Terrain3D material-weight view. It blends Astra's temperate, Mediterranean/dry, desert/arid and exposed-rock channels through diagnostic colours without changing terrain data or beginning production PBR work.

## Implemented foundation

The preserved first-pass [`astra_terrain_art_preview.tscn`](scenes/world_map/astra_terrain_art_preview.tscn) now renders the complete Astra world with eight existing 2K surface sets, continuous geographic weights, photographic detail at two scales and restrained relief support. It preserves the terrain, alignment and diagnostic scenes. See [`docs/world_map/astra_terrain_art.md`](docs/world_map/astra_terrain_art.md) for that earlier surface baseline, reproducible resources and limitations.

The repository currently contains:

- a Godot 4 project with no configured project main scene and a directly launchable Gameplay 001 wrapper;
- binding repository rules and technical documentation;
- a deterministic pure-data simulation clock;
- clock state round-trip support;
- validated good and building definitions;
- a prototype capability catalogue;
- an immutable `ProvinceCapabilityState`;
- authoritative generated data for 100 active production provinces using non-contiguous stable IDs;
- a directly launchable Astra terrain import test scene;
- a directly launchable Astra land-mask alignment inspection scene;
- a directly launchable Astra material-weight biome preview scene;
- direct typed-GDScript headless tests.

Runtime gameplay remains limited to the Province Interaction Gate.

## Inspecting the Astra terrain import

Open `scenes/world_map/astra_land_mask_alignment_inspection.tscn` and run the current scene. Use WASD or the arrow keys to pan, the mouse wheel to zoom, `V` to switch top-down and oblique views, and `F` to frame the full map. Press `1` for the combined mismatch view, `2` for neutral Terrain3D relief, or `3` for the R-channel mask view. The translucent plane is an exact zero-height reference only; this QA scene adds no material or water treatment.

For the material-weight preview, open `scenes/world_map/astra_biome_preview.tscn` and run the current scene. It uses the same pan, zoom, `V` and `F` controls. See [`docs/world_map/astra_biome_preview.md`](docs/world_map/astra_biome_preview.md) for evidence and limitations.

## Historical world-map gate and current scoped exception

The original static six-province gate below predates the validated full-continent Astra/Terrain3D work. The explicit September 2026 tasks authorize full-world terrain import, data, alignment and terrain-surface previews independently of that gate. They do not constitute approval for province rendering or simulation/gameplay expansion. `AGENTS.md`'s pure-data phase label is similarly stale for this presentation work; its architecture and preservation rules still apply.

The planned production pipeline is **Azgaar → Wonderdraft → Godot**. The first proof will cover approximately six provinces and is intended to demonstrate camera pan and zoom, province polygons, province selection, and normal and political map modes on a static illustrated terrain map with fixed authored geography.

Full-continent production must not begin before the proof receives a **Pass** decision in the Pass / Revise / Replace review. Detailed province close-ups are deferred beyond the prototype.

## Design authority

1. Master Bible v1.6 — consolidated high-level authority.
2. MAP_00_Workflow — active world-map production gate.
3. Goods Design Workbook v1.3 — detailed specialist authority for goods, Carrots, Food, Population, workforce, balancing and prototype scope.
4. Gameplay Direction Change Register v0.1 — reconciliation history.
5. Repository documentation, source and tests — authoritative for implemented reality.

## Implemented economic foundation

Ordinary goods are province-local capabilities rather than universal inventories. Timber enables Firewood; Farm provides Grain; Mill requires Grain and provides Flour; Bakery requires Flour and Firewood and provides Bread. Carrots, Food and Population remain separate systems, and there is no prototype Woodcutter.

This foundation contains no quantity inventories, storage, recipes or production ticks. Code uses underscore stable IDs.

Verified pushed baseline: `9c06a022f91c6bbd86d99e8733c04b071ab6c264`.

## Technical foundation

- Engine: Godot 4
- Language: typed GDScript
- Version control: Git
- Simulation: compact data updated only through scheduled ticks
- Architecture: strict separation of simulation, presentation and UI
- Content: data-driven definitions using stable IDs
- Performance: measure first; optimise only proven bottlenecks

## Repository map

See:

- `AGENTS.md` for binding development rules
- `docs/project_index.md` for documentation ownership
- `docs/code_map.md` for source ownership and dependency direction
- `docs/implementation_plan.md` for staged work
- `docs/decision_log.md` for technical decisions
- [`docs/world_map/world_map_workspace.md`](docs/world_map/world_map_workspace.md) for the Stage 1.5 workspace boundary
- [`docs/world_map/world_map_visual_brief.md`](docs/world_map/world_map_visual_brief.md) for locked Stage 1.5 visual and interaction direction

## Opening the project

```powershell
godot --editor --path .
```

## Running direct tests

```powershell
godot --headless --path . --script res://tests/foundation_smoke_test.gd
godot --headless --path . --script res://tests/simulation_clock_test.gd
godot --headless --path . --script res://tests/good_definition_test.gd
godot --headless --path . --script res://tests/building_definition_test.gd
godot --headless --path . --script res://tests/prototype_content_catalogue_test.gd
godot --headless --path . --script res://tests/province_capability_state_test.gd
godot --headless --path . --script res://tests/world_map_integration_proof_test.gd
godot --headless --path . --script res://tests/astra_province_data_test.gd
godot --headless --path . --script res://tests/astra_province_coverage_test.gd
godot --headless --path . --script res://tests/astra_biome_preview_test.gd
godot --headless --path . --script res://tests/astra_terrain_art_assets_test.gd
godot --headless --path . --script res://tests/province_geography_query_test.gd
godot --headless --path . --script res://tests/province_realm_state_test.gd
godot --headless --path . --script res://tests/world_gameplay_scene_test.gd
godot --headless --path . --script res://tests/world_identity_catalogue_test.gd
```

Exit code `0` means a test passed. A non-zero exit code means it failed.

The locked world-identity layer can also be inspected without player-facing UI:

```powershell
godot --headless --path . --script res://tools/world_identity/inspect_world_identity.gd
```

Pass `-- --province=30`, `-- --realm=R028` or `-- --all` for targeted or full
catalogue output. See [`docs/world_identity/world_identity_runtime.md`](docs/world_identity/world_identity_runtime.md).

## Current stop condition

Further simulation features—including Population, workforce, Food arithmetic, construction, routes and detailed province scenes—must not begin until the six-province world-map feasibility gate passes.
