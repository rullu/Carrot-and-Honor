# For Carrot and Honour

## Integrated development baseline

`main` now combines the accepted Political/Culture inspection modes and settlement prototype with campaign-start v1. See [repository integration](docs/gameplay_state/repository_integration_2026-09-18.md) for provenance, preserved working files, merge decisions and verification. Gameplay 001 retains its inspection workflow; a campaign-selection UI remains deferred.

## Campaign start v1

`CampaignBootstrap.new_campaign(seed, days_per_year, player_realm_id)` now generates and validates the complete canonical 43-Realm cast before creating campaign state. Seed and year length are explicit inputs; player selection does not affect the cast. Schema 2 persists the generated records, signed birth ticks and generation provenance. Loading never regenerates families.

See [`docs/gameplay_state/campaign_start_v1.md`](docs/gameplay_state/campaign_start_v1.md) for API, decisions, deterministic stress evidence and the sealed authority. Run the complete suite with `powershell -NoProfile -ExecutionPolicy Bypass -File tools/testing/run_headless_tests.ps1 -TimeoutSeconds 600`; it includes a 1,000-seed stress test. Validate the name-table transcription with `node tools/campaign/build_campaign_start_data.js --check`.

Inspect a real generated campaign without adding a player-facing reroll or changing Gameplay 001:

```powershell
godot --headless --path . --script res://tools/campaign/inspect_campaign_start.gd -- --seed=example --days-per-year=365 --player=R028
```

Here 365 is an example configuration, not a canonical calendar. Add `--save=res://.godot/example_campaign.json` to verify and save the complete campaign.

## Logic Foundation Pass 1

The five core campaign states, stable registries, derived queries, atomic lifecycle commands, strict validation and versioned JSON save/load are implemented. Read [`docs/gameplay_state/logic_foundation_pass1.md`](docs/gameplay_state/logic_foundation_pass1.md) for the API, acceptance evidence and remaining subsystem boundaries. The [locked state architecture](docs/design_authority/FCAH_Gameplay_State_Architecture_v1_LOCKED.txt) controls this work.

Campaign-start v1 supplies the ruler/family/lineage roster and sealed fixed Seats to the existing canonical-world adapter. The adapter preserves all 100 Provinces and 43 starting Realms. Gameplay 001 remains an inspection scene with separately labelled prototype metrics, named `PrototypeProvinceMetrics`.

After Godot has scanned/imported the project, run the full 24-test suite using the command above. The runner resolves `godot` from PATH, waits for the process, requires a PASS marker and checks script errors; logs stay in `.godot/test_logs/`.

For Carrot and Honour is a real-time, pausable medieval-fantasy strategy game about ruling a bunny kingdom across one fixed, handcrafted continent. The interactive world map is intended to be the primary playing field, with province management available through panels. The project is built with Godot 4 and typed GDScript.

## Current gameplay scene

Open **[`scenes/gameplay/world_gameplay.tscn`](scenes/gameplay/world_gameplay.tscn)** and press **F6**. Gameplay 001 instances the completed NaturalWorld, provides geographic hover and persistent click selection for all 100 active provinces, and displays canonical province identity plus frozen starting-realm identity in a plain debug panel. Population, Food, Carrots and Development remain clearly labelled non-canonical prototype metrics. Left click selects, Escape clears selection, WASD or middle drag pans, and the wheel zooms.

The accepted 2D/2.5D settlement prototype remains in provinces 67 and 54, using `the_victim.png` at its accepted scale. Press **F1** for this 2D asset, **F2** for the retained procedural 3D comparison, **F3** for both, or **F4** to hide both. See [`docs/world_map/settlement_representation_prototype.md`](docs/world_map/settlement_representation_prototype.md) for anchors, scale and historical QA captures.

Press **P** in Gameplay 001 to toggle its Political Map Mode v0.1. It tints the existing terrain by each Province's current `ProvinceState.owner_realm_id` and shows one zoom-aware name per current Realm. The accepted borders, NaturalWorld detail and camera controls remain intact. Press **P** again for the original normal presentation. See [`docs/world_map/political_map_mode_v0_1.md`](docs/world_map/political_map_mode_v0_1.md) for the presentation boundary and visual captures.

Press **C** to toggle Culture Map Mode v0.1. It colors Provinces by current `ProvinceState.local_culture` and labels connected cultural regions; P and C switch directly between the exclusive modes. The standalone inspection scene seeds culture from canonical starting Province identity, and a bound campaign supplies current Province state. See [`docs/world_map/culture_map_mode_v0_1.md`](docs/world_map/culture_map_mode_v0_1.md) for the data boundary and captures.

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
godot --headless --path . --script res://tests/political_map_mode_test.gd
godot --headless --path . --script res://tests/culture_map_mode_test.gd
godot --headless --path . --script res://tests/world_identity_catalogue_test.gd
godot --headless --path . --script res://tests/gameplay_identity_integration_test.gd
```

Exit code `0` means a test passed. A non-zero exit code means it failed.

The locked world-identity layer can also be inspected without player-facing UI:

```powershell
godot --headless --path . --script res://tools/world_identity/inspect_world_identity.gd
```

Pass `-- --province=30`, `-- --realm=R028` or `-- --all` for targeted or full
catalogue output. See [`docs/world_identity/world_identity_runtime.md`](docs/world_identity/world_identity_runtime.md).

## Current stop condition

The separately authorized Logic Foundation Pass 1 supersedes the historical six-province gate for core campaign state, lifecycle primitives and persistence only. Economy, succession rules, combat, AI and the other deferred simulations still require their own subsystem passes.
