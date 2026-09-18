# Code Map

The project contains verified pure-data foundations, a narrow province-interaction gameplay wrapper and directly executable headless tests. `project.godot` still has no configured main scene.

## Campaign state foundation (DEV-026)

- `src/simulation/province_state.gd` owns current Province ownership, local identity and local resource state; its immutable Province ID references the unchanged geography/heritage catalogue.
- `src/simulation/campaign/realm_state.gd`, `character_state.gd`, `dynasty_state.gd` and `relationship_state.gd` are the other four typed authoritative records. They contain no competing derived territory, membership, ruling-Dynasty or war fields.
- `claim_record.gd` is a shared value schema with one containing claimant. `historical_memory.gd` is a perspective-specific narrative record. `war_state.gd` is only a conflict identity/participant/activity boundary stub.
- `campaign_state.gd` indexes typed records by stable ID and retains retired-ID reservations and campaign outcome. `campaign_queries.gd` derives territory, family children, Dynasty members/extinction, ruling Dynasty, resources and wars; its caches are disposable.
- `campaign_session.gd` is the live publication boundary, exposes detached reads and commits only validated candidates. `realm_lifecycle.gd` handles capture/restoration/rebels/formables/succession; `character_lifecycle.gd` handles family writes and death with explicit successors.
- `state_schema.gd` validates wire types and exact field sets; `campaign_validator.gd` checks the complete reference graph. `campaign_codec.gd` validates versioned JSON, verifies disk readback and atomically replaces saves.
- `campaign_world_binding.gd` fingerprints the existing world authorities and checks identity/retired-ID preservation. `campaign_bootstrap.gd` initializes canonical ownership/local identity from those existing files, requiring explicit scenario ruler/capital/House records.
- `tests/campaign_architecture_test.gd`, `campaign_lifecycle_test.gd`, `campaign_save_load_test.gd` and `campaign_world_bootstrap_test.gd` cover the locked acceptance conditions. `tests/support/` contains the explicit synthetic scenario and assertion harness.
- `tools/testing/run_headless_tests.ps1` runs direct Godot tests with process waits, timeouts, fresh logs, PASS markers and parse/script-error detection. Godot `.gd.uid` sidecars belong to their adjacent sources.
- `docs/gameplay_state/logic_foundation_pass1.md` owns the API contract, implementation decisions, verification and deferred scope. `docs/design_authority/` contains the exact locked specification.

## World identity

- `data/world_identity/world_identity_master_canon.json` is the byte-identical locked implementation-facing identity authority for 100 provinces, 43 starting realms, formables, title rules and special-system metadata.
- `src/simulation/world_identity_catalogue.gd` loads that data and validates it independently against frozen ownership and active geography before exposing defensive queries.
- `tools/world_identity/inspect_world_identity.gd` is the dedicated developer inspection path; it adds no player-facing UI or gameplay behaviour.
- `tests/world_identity_catalogue_test.gd` verifies counts, ownership/footprints, required samples, UTF-8, mixed identity, formables, special metadata and loud rejection paths.
- `docs/world_identity/world_identity_runtime.md` records provenance, commands, validation and scope boundaries.

## Gameplay 001

- `scenes/gameplay/world_gameplay.tscn` instances the locked NaturalWorld as the gameplay entry point.
- `src/gameplay/province_geography.gd` loads authoritative geometry and performs bounds-filtered point-in-polygon lookup with multipart support. Corrected political geography contains no inland-water holes.
- `src/gameplay/province_interaction.gd` owns cursor-to-terrain lookup, hover and selection.
- `src/gameplay/world_gameplay.gd` coordinates geography, canonical identity, isolated prototype metrics, presentation and UI. Its inspection record never sources names or ownership from geography or prototype state. Without an authored scenario, it seeds current `ProvinceState` owners and local cultures once from validated canonical Province identity; an injected `CampaignSession` supersedes those records and supplies later state revisions. P/C select exclusive Normal, Political and Culture modes.
- `src/simulation/prototype_province_metrics.gd` and `prototype_world_state.gd` own only temporary Population, Food, Carrots and Development display metrics. They own no political realm IDs or identity and are never serialized as campaign state.
- `src/presentation/world_map/province_presentation.gd` renders presentation-only province borders from interaction IDs.
- `src/presentation/world_map/political_realm_palette.gd` assigns 30 curated debug pigments to Realm IDs using the current geographic adjacency graph, then improves neighboring contrast without changing canonical identity. `political_map_presentation.gd` binds those colors to a Province ID mask and a gameplay-only variant of the existing terrain shader. Normal mode restores the original shader and ribbon palette.
- `src/presentation/world_map/political_realm_labels.gd` reads current Province owners and authoritative Realm/formable display identity to maintain one Political-only screen label per current Realm. It chooses an owned Province interior anchor, projects through the existing camera, and handles close-view visibility, overview spacing and the gameplay panel's screen rectangle; it owns no authoritative identity or territory state.
- `src/presentation/world_map/culture_region_labels.gd` groups current Province cultures by the accepted neighbor graph and labels each connected region from a Province interior anchor. Culture mode uses a separate `PoliticalMapPresentation` instance for the same accepted Province mask, shader seam and 30-color adjacency optimizer; the Political instance and accepted border renderer are unchanged.
- `tools/world_map/build_political_province_mask.gd` deterministically rasterizes the accepted Province rings into `assets/world_map/political/province_id_mask.png`; the pixels contain Province IDs only. `capture_political_map_mode.gd` captures close/default/far gameplay comparisons and a whole-world overview. `tests/political_map_mode_test.gd` checks current-owner mapping, 43 Realm colors, adjacency, and all 100 mask anchors.
- `tools/world_map/capture_political_realm_labels.gd` captures the running Political labels at close/default/far/continent zoom and checks 43 overview names, no text overlap and complete Normal-mode removal. The Political test also checks label names and anchors after live ownership/identity changes.
- `tools/world_map/capture_culture_map_mode.gd` captures close/default/far/continent Culture views plus P/C restoration. `tests/culture_map_mode_test.gd` checks all 100 current Province cultures, 18 distinct colors, connected region placement and stale-label removal after a culture change.
- `scenes/gameplay/settlement_prototype_test.tscn` and `src/presentation/world_map/settlement_prototype_test.gd` own the removable settlement representation comparison. They add no simulation state or collision and use Terrain3D only to ground the two test anchors and procedural blockout.
- `src/ui/province_debug_panel.gd` displays canonical province/realm identity, geographic facts and explicitly non-canonical prototype metrics.
- The `gameplay_identity_integration` test drives the actual gameplay controller and panel path across all 100 provinces so geography source names and mock realms cannot become visible again.
- The `province_geography_query`, `province_realm_state`, `world_gameplay_scene` and `astra_province_coverage` tests verify lookup, metric isolation, scene composition, preservation locks and complete accepted-land coverage.

## Root

### `project.godot`

Godot project configuration. It enables Terrain3D 1.0.2 and retains the OpenGL Compatibility renderer. There is currently no main scene.

### `AGENTS.md`

Binding development rules.

## `docs/world_map/`

Stage 1.5 workspace and visual-direction documentation.

### `docs/world_map/world_map_visual_brief.md`

Detailed authority for planned Stage 1.5 world-map visuals, interactions, proof content and acceptance criteria. It documents intended behaviour only and does not represent implemented map code, assets or runtime data.

### `docs/world_map/astra_province_data.md`

Authority for the corrected non-contiguous province-ID schema, correction manifest, reproducible import command, exact coordinate contract and coverage validation.

### `docs/world_map/settlement_representation_prototype.md`

Records the supplied 2D and 3D-reference assets, comparison controls, exact province anchors, scale choices, capture workflow and provisional visual findings. It is QA documentation and does not establish a settlement system or final art direction.

### `docs/world_map/astra_biome_preview.md`

Documents the disposable material-weight preview, crop authority, controls, GPU evidence, technical trust boundary and visual limitations.

## `src/simulation/`

Authoritative game state and deterministic rules.

Expected future domains may include:

- clock and tick scheduling;
- goods and inventories;
- buildings and production;
- labour allocation;
- population and needs;
- prices and local markets;
- construction;
- narrative eligibility and event history;
- saving and loading.

### `src/simulation/simulation_clock.gd`

Pure-data deterministic clock state. It advances only through explicit daily ticks, uses a required configured month length to prove month rollover without defining a final game calendar, and exports or strictly restores all authoritative fields through independent dictionaries and clock instances.

### `src/simulation/simulation_clock.gd.uid`

Godot-generated UID sidecar belonging to `simulation_clock.gd`.

### `src/simulation/good_definition.gd`

Pure-data definition for one ordinary-good capability. Its authoritative fields are stable ID, display name, province-local scope, availability kind, optional provider-building ID and ordered prerequisite-good IDs. It validates exact input fields and returns defensive prerequisite-array copies.

### `src/simulation/good_definition.gd.uid`

Godot-generated UID sidecar belonging to `good_definition.gd`.

### `src/simulation/building_definition.gd`

Pure-data definition for one building. Its authoritative fields are stable ID, display name and placement kind. It owns no production, construction or operating state.

### `src/simulation/building_definition.gd.uid`

Godot-generated UID sidecar belonging to `building_definition.gd`.

### `src/simulation/prototype_content_catalogue.gd`

Tightly scoped pure-data catalogue for the fixed bread-capability slice. It validates nulls, duplicate IDs, provider and prerequisite references, and direct or indirect dependency cycles. Validated definition input order is deliberate authoritative content order; the catalogue exposes deterministic lookups and a defensively copied ordered good-ID list.

### `src/simulation/prototype_content_catalogue.gd.uid`

Godot-generated UID sidecar belonging to `prototype_content_catalogue.gd`.

### `src/simulation/province_capability_state.gd`

Immutable pure-data province snapshot. It owns sorted copied present-building IDs, derives available and blocked goods in authoritative catalogue order, and exposes direct missing-provider and missing-prerequisite queries through defensive collection copies.

### `src/simulation/province_capability_state.gd.uid`

Godot-generated UID sidecar belonging to `province_capability_state.gd`.

## `src/presentation/`

Visual representation of the active province and other visible state.

Expected future responsibilities may include:

- province scene binding;
- building state visuals;
- camera behaviour;
- ambient bunny routes;
- non-authoritative carts and activity;
- animation and visual transitions.

Presentation includes the original Stage 1.5 integration proof and the subsequent Astra terrain, diagnostic and natural-world scenes. Simulation remains independent.

### `src/presentation/world_map/`

Reserved for presentation-only world-map controllers and helpers.

### `src/presentation/world_map/world_map_camera_controller.gd`

Typed camera controller used only by the disposable Stage 1.5 integration proof. It owns keyboard, middle-drag, screen-edge and wheel input; cursor-focused uniform zoom; viewport-responsive cover zoom; and terrain-bound camera clamping. It has no simulation, province, UI or gameplay dependency and does not establish the permanent world-map controller architecture.

### `src/presentation/world_map/astra_terrain_import_test.gd`

Runtime and validation controller for the minimal Astra terrain scene. It binds the fixed inspection camera to Terrain3D and can verify source hash, dimensions, region count, scale, orientation samples and validation screenshots when launched with a validation output argument.

### `src/presentation/world_map/astra_terrain_import_test.gd.uid`

Godot-generated UID sidecar belonging to `astra_terrain_import_test.gd`.

### `src/presentation/world_map/astra_land_mask_alignment_inspection.gd`

Runtime controller for the Astra land-mask QA scene. It loads the project-local playable crop directly as RGBA8, creates a non-colour `ImageTexture` with no mipmaps, binds it to the diagnostic Terrain3D shader, provides inspection camera controls and validates dimensions, hash, terrain settings and all eight manifest-anchor conversions.

### `src/presentation/world_map/astra_land_mask_alignment.gdshader`

Terrain3D diagnostic shader derived from Terrain3D's minimum shader. It maps world X/Z to the shared raster sample grid, reads only the Features R channel with nearest texel fetches, and shows the mask boundary and height/sea disagreements in high-contrast QA colours.

### `src/presentation/world_map/astra_biome_preview.gd`

Controller for the disposable material-weight preview. It loads the exact playable RGBA crop as linear data, creates filtered runtime mipmaps, owns inspection controls, explicitly activates the custom Terrain3D shader and captures four validation views.

### `src/presentation/world_map/astra_biome_preview.gdshader`

Terrain3D preview shader that normalizes and blends Astra's R/G/B/A material weights into temperate, Mediterranean/dry, desert/arid and exposed-rock diagnostic colours using the validated world-to-sample mapping.

The `.gd.uid` and `.gdshader.uid` files beside the controller and shader are their Godot-generated UID sidecars.

## `src/ui/`

Player-facing Controls and input coordination.

Expected future responsibilities may include:

- persistent HUD;
- time controls;
- operational building panels;
- goods overview;
- alerts;
- parchment notices;
- chronicle;
- construction browser.

No UI module exists yet.

## `data/`

Data-driven definitions and test fixtures.

No runtime data exists yet.

### `data/world_map/`

Owns stable generated province and future map-related runtime data.

### `data/world_map/astra_provinces.json`

Generated authoritative data for 100 active production provinces. Each record retains precise Azgaar and converted Godot X/Z boundary rings, selection and label points, bounds, source and derived area, and sorted neighbor IDs. It contains no realm ownership or simulation state.

### `data/world_map/astra_province_corrections.json`

Version-controlled correction authority over the immutable Azgaar source. It records stable merges and retired IDs, explicit cell assignments, inland-water ownership, new province definitions, anchor corrections and reserved future operation types.

### `data/world_map/astra_province_coverage_report.json`

Generated validation evidence tied by hash to the runtime geography, correction manifest, immutable source and accepted land mask.

### `tools/world_map/build_astra_province_corrections.py`

Deterministically translates the approved high-level merge, gap, island and fragmentation decisions into explicit correction-manifest cell assignments. It reads but never changes the immutable Azgaar source.

### `tools/world_map/import_astra_provinces.gd`

Applies the correction manifest to immutable source cells, dissolves corrected cells into runtime rings, and recalculates areas, bounds, neighbors and anchors.

### `tools/world_map/validate_astra_province_geography.py`

Checks source-cell ownership, accepted-mask coverage, political holes, anchors, symmetric neighbors, retired IDs, external ocean and positive-area overlaps. It emits the coverage report and both QA maps.

## `scenes/`

Godot scenes.

The repository contains one dedicated disposable world-map integration proof scene. There is still no main gameplay scene.

### `scenes/world_map/`

Reserved for Godot world-map scenes.

### `scenes/world_map/world_map_integration_proof.tscn`

Disposable Stage 1.5 integration scene containing only the native-scale terrain sprite and its presentation camera. It is directly launchable for manual verification, is not assigned as the project main scene and has no simulation or UI dependency.

### `scenes/world_map/astra_terrain_import_test.tscn`

Minimal full-continent 3D inspection scene containing the Terrain3D heightfield, fixed orthographic camera, neutral environment and a flat sea-level reference plane. It is not the project main scene and contains no gameplay or decoration.

### `scenes/world_map/astra_land_mask_alignment_inspection.tscn`

Directly runnable mask-alignment QA scene. It reuses the unchanged Terrain3D data directory and scale, adds the diagnostic shader and exact sea-level reference, and exposes combined, terrain-only and mask-only views. It is not the project main scene.

### `scenes/world_map/astra_biome_preview.tscn`

Disposable material-colour inspection scene. It reuses the unchanged 576 Terrain3D regions, fixed scale and orientation, adds a simple sea plane and dedicated preview controller, and is not the project main scene.

## `assets/`

Replaceable visual, audio and font assets.

The repository contains one approved game-ready terrain export for the disposable Stage 1.5 integration proof.

### `assets/world_map/base/`

Reserved for approved game-ready static terrain exports.

### `assets/world_map/base/stage_1_5_six_province_map_01_terrain_base_candidate_01.png`

Unmodified 1920 x 1080 PNG terrain export displayed by the disposable Stage 1.5 integration proof. It owns no runtime state or behaviour.

### `assets/world_map/astra/source/`

Contains the unchanged project-local Astra height, Features and material authorities plus byte-exact playable crops. `FCAH_Materials_Playable_4096x2304_RGBA.png` is exact square rows `[896, 3200)` and preserves all four material-weight channels.

### `assets/world_map/astra/terrain_data/`

Contains 576 Terrain3D region resources imported from the playable EXR with float32 height storage, 128 x 128 samples per region, and no material or control-map authoring.

## `addons/terrain_3d/`

Unmodified Terrain3D 1.0.2 stable plugin from TokisanGames. It supplies region-based terrain storage and runtime LOD rendering.

## `tools/world_map/`

Development-only terrain import tooling.

### `tools/world_map/import_astra_terrain.gd`

Reproducible one-shot importer for the project-local Astra playable EXR. It verifies the source hash and dimensions, imports the documented scale into 576 float32 regions, and refuses to overwrite an existing terrain-data directory.

### `tools/world_map/import_astra_terrain.gd.uid`

Godot-generated UID sidecar belonging to `import_astra_terrain.gd`.

### `tools/world_map/import_astra_provinces.gd`

Reproducible typed-GDScript converter for the authoritative Azgaar Full JSON. It verifies source and manifest fingerprints, derives closed province rings and adjacency from cell topology, preserves source precision, applies the established sample-centre conversion, validates all eight manifest anchors and writes `data/world_map/astra_provinces.json`.

### `tools/world_map/import_astra_provinces.gd.uid`

Godot-generated UID sidecar belonging to `import_astra_provinces.gd`.

### `tools/world_map/crop_astra_material_mask.gd`

Reproducible one-shot cropper for the project-local full Astra material mask. It verifies source hash, dimensions and RGBA8 format, writes exact rows `[896, 3200)`, and validates byte-exact PNG readback.

### `tools/world_map/crop_astra_material_mask.gd.uid`

Godot-generated UID sidecar belonging to `crop_astra_material_mask.gd`.

### `assets/world_map/settlements/`

Reserved for approved game-ready settlement markers. It is empty apart from `.gitkeep`; no settlement asset exists.

### `assets/world_map/effects/`

Reserved for approved game-ready map-effect resources. It is empty apart from `.gitkeep`; no map-effect asset exists.

## `tests/`

Deterministic verification for simulation and data validation.

### `tests/foundation_smoke_test.gd`

Directly executable `SceneTree` smoke test that verifies typed GDScript can run headlessly and report success or failure through the process exit code.

### `tests/foundation_smoke_test.gd.uid`

Godot-generated UID sidecar belonging to `foundation_smoke_test.gd`

### `tests/simulation_clock_test.gd`

Directly executable `SceneTree` test that verifies normal daily progression, configured month-boundary progression, deterministic repetition, strict state validation and an independent save/load-style round trip for the pure-data simulation clock.

### `tests/simulation_clock_test.gd.uid`

Godot-generated UID sidecar belonging to `simulation_clock_test.gd`.

### `tests/good_definition_test.gd`

Directly executable `SceneTree` test that verifies every authoritative good field, exact-field and type validation, stable-ID structure and dictionary use, provider/prerequisite rules, and collection-copying and instance independence.

### `tests/good_definition_test.gd.uid`

Godot-generated UID sidecar belonging to `good_definition_test.gd`.

### `tests/building_definition_test.gd`

Directly executable `SceneTree` test that verifies every authoritative building field, placement validation, exact-field and type validation, stable-ID structure and dictionary use.

### `tests/building_definition_test.gd.uid`

Godot-generated UID sidecar belonging to `building_definition_test.gd`.

### `tests/prototype_content_catalogue_test.gd`

Directly executable `SceneTree` test that verifies exact fixed content, deterministic lookup, referential rejection, dependency-cycle rejection, defensive prerequisite copying and the capability chain without production execution.

### `tests/prototype_content_catalogue_test.gd.uid`

Godot-generated UID sidecar belonging to `prototype_content_catalogue_test.gd`.

### `tests/province_capability_state_test.gd`

Directly executable `SceneTree` test that verifies province capability outcomes, direct blocker semantics, deterministic order, validation, stable-ID keys and defensive collection ownership.

### `tests/province_capability_state_test.gd.uid`

Godot-generated UID sidecar belonging to `province_capability_state_test.gd`.

### `tests/world_map_integration_proof_test.gd`

Directly executable `SceneTree` integration test for the disposable Stage 1.5 proof. It verifies terrain dimensions, scene structure, native terrain transform, camera placement and controller attachment, required input actions, and the absence of simulation dependencies.

### `tests/astra_province_data_test.gd`

Directly executable province-data validation. It verifies the exact 100 active stable IDs and seven retired IDs, geometry closure and footprint bounds, point-by-point coordinate conversion, bounding boxes, derived areas, symmetric neighbors, fixed orientation, no political holes and all eight historical alignment anchors.

### `tests/astra_province_coverage_test.gd`

Checks that the generated coverage report matches current file hashes and the accepted land-mask/source authorities, with zero meaningful gaps, overlaps, political holes, external-ocean assignments or retired source-cell ownership.

### `tests/astra_province_data_test.gd.uid`

Godot-generated UID sidecar belonging to `astra_province_data_test.gd`.

### `tests/astra_biome_preview_test.gd`

Directly executable validation for the material-mask crop, representative channel values, shader invariants, scene ownership, OpenGL Compatibility and unchanged 576-region Terrain3D configuration.

### `tests/astra_biome_preview_test.gd.uid`

Godot-generated UID sidecar belonging to `astra_biome_preview_test.gd`.

## Dependency rule

```text
data definitions
      |
      v
simulation <---- UI requests
      ^
      |
presentation reads
```

Simulation must never import UI or presentation code.

UI and presentation may share read-only view models later, but they must not become alternate owners of simulation state.

## Astra terrain-art preview ownership

- `scenes/world_map/astra_terrain_art_preview.tscn`: standalone surface-art inspection scene; references the existing Terrain3D data without saving or changing it. Owns only preview lighting, a plain sea reference and an inspection camera.
- `src/presentation/world_map/astra_terrain_art.gd`: runtime material activation, raw data-mask loading, camera controls and GPU capture/contract validation. No simulation dependency.
- `src/presentation/world_map/astra_terrain_art.gdshader`: unchanged Terrain3D vertex kernel plus continuous material blending, photographic meso/micro detail, colour grading and restrained surface normals/relief.
- `tools/world_map/prepare_astra_art_support.py`: offline, deterministic presentation-only mip packing and context generation from read-only verified textures and height samples.
- `tools/world_map/build_astra_art_arrays.gd`: builds verified BC1/BC3 Image resources and Texture2DArray descriptors; run with normal GPU rendering, not headless.
- `assets/world_map/terrain_materials/art_preview/`: derived context, source/hash manifest, two array descriptors and sixteen compressed image layers. Not terrain or mask authority.
- `tests/astra_terrain_art_assets_test.gd`: validates source hashes, compressed mip payloads, context identity and unchanged terrain vertex code. Rendering is separately validated in the normal GPU scene.
- `.uid` sidecars beside the new Godot scripts/shader are engine-generated identifiers.

Inspection instructions and rebuilding belong to `docs/world_map/astra_terrain_art.md`; art decisions and QA evidence belong to `C:\Projects\FCAH_ASTRA_WORKSPACE\ASTRA_TERRAIN_ART_REPORT.md`.

## Updating this map

Add every new source file here when it introduces a new responsibility, public interface or cross-module dependency.

## Final Astra natural world

`scenes/world_map/astra_natural_world_final.tscn` is the current natural-world art inspection entry point. `src/presentation/world_map/astra_natural_world.gd` owns runtime bindings, camera presets and GPU review. `astra_natural_terrain.gdshader` owns surface materials and shared land/water boundaries. `astra_beauty_water.gdshader` now owns sea/inland water appearance; `astra_natural_water.gdshader` is the retained historical implementation. `astra_natural_props.gd` and its shader own deterministic miniature botanical/outcrop meshes and spatial MultiMesh batches.

`assets/world_map/astra/natural_world/` contains presentation-only shore/ecology/hydrology fields, water vertices, placements and a hash manifest. `tools/world_map/prepare_astra_natural_world.py` derives those assets from verified sources; `verify_astra_natural_world.py` checks preservation and geometry placement. `docs/world_map/astra_natural_world.md` owns current inspection and rebuild instructions. No presentation derivative replaces authoritative terrain, Features, provinces or simulation.

## Astra natural-world polish (DEV-018)

The existing final scene/controller remain the entry point. `astra_botanical.gdshader` shades the curated source library, palette, alpha-card antialiasing and wind; `astra_natural_banks.gdshader` shades narrow ground/water bank faces. `astra_natural_props.gd` now normalizes curated meshes, merges botanical surfaces, retains alpha cards through LODs and builds spatial gameplay/separate continent MultiMeshes.

`tools/world_map/compose_astra_nature.py` authors ecological districts, groves and discoveries. `astra_bank_geometry.py` reconstructs bank faces. Both extend `prepare_astra_natural_world.py`; none owns authoritative geography. `capture_astra_art_review.gd` and `astra_natural_review_views.json` provide reproducible matching-camera GPU review; `capture_astra_nature_motion.gd` records engine motion and navigation. The verifier also checks source-library hashes and bank geometry.

`assets/world_map/nature_library/quaternius/` contains the selected CC0 models, dependencies, license and hashes. New natural-world derivatives are `landscape_character_rgba.png`, `water_optics_rgba.png`, `bank_vertices.bin` and `natural_districts.json`; the established manifest and placement/field assets are regenerated by the same pipeline. No new simulation or gameplay interface is introduced.

## Final natural-world production (DEV-019)

- `tools/world_map/prepare_astra_production_polish.py` reads the frozen accepted derivatives and twelve hash-verified authorities. It writes only supplemental shoreline finish, route-progress and grounded-detail assets; it never regenerates the accepted world.
- `assets/world_map/astra/natural_world/shore_finish_rgba.png`, `river_motion_rgba.png`, `shore_details.json` and `production_polish_manifest.json` are the additive presentation package. Original placements, masks and water/bank vertices stay unchanged.
- `src/presentation/world_map/astra_rock_geometry.gd` preserves curated source silhouettes/UVs while deriving efficient faceted normals. `astra_rock_surface.gdshader` owns the existing warm/cool rock palette, roughness and restrained foot shading.
- `src/presentation/world_map/astra_water_reactions.gd` batches selected source-water-anchored obstacle quads; its `.gdshader` owns clipped intermittent disturbance. This introduces no fluid simulation.
- `astra_natural_props.gd` appends supplemental instances in memory and adds original reed geometry to existing spatial batches. `astra_natural_world.gd` binds the additive fields and reaction batch. The terrain/water/bank shaders own contextual material finish, retained-normal mountain value support, directional current and stable bank-face shading.
- `tools/world_map/verify_astra_production_polish.py` checks checkpoint authority hashes, unchanged original presentation assets, supplemental anchors, reaction placement and the identical Terrain3D vertex kernel.
- `tools/world_map/astra_production_review_views.json` holds 112 fixed review cameras; `capture_astra_art_review.gd` captures them. `capture_astra_production_motion.gd` and `astra_production_motion_shots.json` record 21 regional pans at the current gameplay distances. Generated UID sidecars belong to their adjacent Godot source files.

No new simulation, province-data, input or gameplay interface is introduced.

## Atmospheric natural-world finish (DEV-020)

- `astra_beauty_water.gdshader` owns spectral surface gradients, reflected light, absorption, lake/river separation, shoaling surf and submerged gravel response. `astra_water_spectrum.gd` loads the original compressed 512×512×64 wave resource once and shares its 3D texture between sea/inland materials.
- `astra_clouds.gd` owns finite cloud volumes, sparse placements and shared motion time. `astra_cloud_volume.gdshader` ray samples those volumes; `astra_atmosphere.gdshaderinc` samples their projected sunlight shadow. The controller creates the atmosphere node; `project.godot` declares its two shader globals.
- `prepare_astra_clouds.py` builds three original cumulus volumes and their matching sunlight projection. `prepare_astra_ocean.py` evaluates the deterministic Fourier spectrum offline. These resources live under `natural_world/atmosphere/` and have no simulation dependency.
- `prepare_astra_beauty_context.py` verifies source hashes and reads the checkpoint to derive shore appearance, oasis moisture and bounded rock overrides/additions. `beauty_composition.json` is applied in memory by the existing prop builder; `water_edge_style.exr` never supplies authoritative water coverage.
- `astra_water_reactions.gd` now creates a sparse, individually culled set of shared-mesh obstacle planes. Its shader provides visible bow/eddy disturbance clipped to original water coverage. No fluid simulation or river routing is introduced.
- Existing terrain, botanical, rock, bank and procedural-prop shaders receive the same moving cloud shade and coherent lighting/material treatment. The Terrain3D vertex kernel remains unchanged.
- `beauty_manifest.json` owns current resource hashes and original-work provenance. `production_polish_manifest.json` keeps the previous detail inventory and explicitly records replacement of its shore-finish field.
- `verify_astra_beauty.py` checks the checkpoint, all export authorities, province/region counts, the identical vertex kernel, untouched vegetation and new rock/reaction anchors. `astra_beauty_review_views.json` contains 108 gameplay cameras. `astra_beauty_motion_shots.json` contains the focused water/cloud motion shots; the existing production motion file retains the 21-region tour. Godot UID/import sidecars belong to their adjacent resources.
