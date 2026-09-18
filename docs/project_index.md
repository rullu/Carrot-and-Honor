# Project Index

This file explains where project truth lives and which document owns which type of information.

## Locked gameplay-state authority

[`design_authority/FCAH_Gameplay_State_Architecture_v1_LOCKED.txt`](design_authority/FCAH_Gameplay_State_Architecture_v1_LOCKED.txt) is the primary authority for the five core state objects, sources of truth, references, lifecycles and save identity. Its September 17 combined audit supersedes older state-ownership descriptions. Other `design_authority/` documents may supply context; `design_reference/` is non-authoritative context, and `design_archive/` is historical material.

[`gameplay_state/logic_foundation_pass1.md`](gameplay_state/logic_foundation_pass1.md) records implementation/API ownership, verification, provenance and future subsystem boundaries. The existing `data/world_identity/world_identity_master_canon.json` remains the immutable implemented world-identity authority.

## External design authorities

### Master Bible v1.6

Current consolidated high-level authority for game direction, prototype scope and locked gameplay rules.

### Goods Design Workbook v1.3

Detailed specialist annex for ordinary-good capability and access relationships.

### Gameplay Direction Change Register v0.1

Historical reconciliation record. It does not supersede the reconciled authorities.

## Repository authorities

### `README.md`

Quick orientation, tool choices, current phase and opening instructions.

### `AGENTS.md`

Binding implementation, naming, architecture, review and documentation rules.

### `docs/project_index.md`

Document ownership and source hierarchy.

### `docs/code_map.md`

Source folders, module ownership and permitted dependencies.

### `docs/implementation_plan.md`

Ordered implementation stages, gates and current status.

### `docs/decision_log.md`

Repository-level technical decisions and their consequences.

### [`docs/world_map/world_map_visual_brief.md`](world_map/world_map_visual_brief.md)

Detailed authority for locked Stage 1.5 world-map visual, interaction, proof-content and acceptance decisions. It defines planned behaviour, not implemented map functionality.

### [`docs/world_map/astra_biome_preview.md`](world_map/astra_biome_preview.md)

Records the disposable Astra material-weight preview, reproducible crop, inspection controls, validation evidence and remaining visual limitations.

### [`docs/world_map/astra_terrain_art.md`](world_map/astra_terrain_art.md)

Owns the standalone textured-surface preview entry point, controls, resource rebuilding and validation commands. The concise art-direction/QA decision report lives at `C:\Projects\FCAH_ASTRA_WORKSPACE\ASTRA_TERRAIN_ART_REPORT.md`.

### `docs/world_map/astra_natural_world.md`

Owns the final natural-world scene, inspection controls, presentation data semantics, provenance, rebuilding and verification. Supersedes the first textured preview as the current art entry point. Current final handoff: `C:\Projects\FCAH_ASTRA_WORKSPACE\ASTRA_FINAL_BEAUTY_HANDOFF.md`. `ASTRA_NATURAL_WORLD_REPORT.md` remains the September 8 historical report.

### [`docs/world_map/settlement_representation_prototype.md`](world_map/settlement_representation_prototype.md)

Owns the temporary 2D-versus-3D settlement scale/readability test, its exact source-asset hashes, controls, placements and generated QA captures. It records review evidence only and is not settlement-system or art authority.

### [`docs/world_map/political_map_mode_v0_1.md`](world_map/political_map_mode_v0_1.md)

Owns the implemented Gameplay 001 normal/political toggle, current-ownership presentation path, Province ID mask derivative, palette assignment, Realm-name labels, and visual verification. Political pigments and labels are presentation data only.

### [`docs/world_map/culture_map_mode_v0_1.md`](world_map/culture_map_mode_v0_1.md)

Owns the Gameplay 001 Culture inspection mode, authoritative Province culture read path, connected-region labels, exclusive P/C transitions and visual verification. Culture colors and labels are presentation data only.

### [`docs/world_identity/world_identity_runtime.md`](world_identity/world_identity_runtime.md)

Owns the implementation-facing world-identity runtime contract, source fingerprint, authority boundaries, inspection commands, validation coverage and deliberately deferred gameplay behaviour.

## Source hierarchy

When sources disagree:

1. Master Bible v1.6 controls consolidated high-level design.
2. Goods Design Workbook v1.3 controls detailed goods questions within that direction.
3. Repository documentation and tests control implemented reality.
4. The change register supplies history rather than current authority.
5. Any unresolved conflict must be logged before coding continues.

## Current phase boundary

The locked world-identity master is now installed as a pure-data runtime layer.
It validates 100 province identities and 43 starting realms against the frozen
political ownership and active geography without deriving identity from legacy
planning metadata or applying gameplay effects. DEV-024 records the boundary.

Gameplay 001 now instances the locked NaturalWorld and adds province lookup, hover, selection, permanent-border presentation and a debug panel. The panel binds canonical identity and frozen starting realms through `WorldIdentityCatalogue`; only its explicitly labelled numeric metrics remain synthetic. DEV-025 supersedes DEV-021's old mock province/realm display path. Visual testing accepted the interaction architecture while exposing defects in the authoritative geography; DEV-022 addresses them through the separately approved correction pass.

The corrected 100-province topology and dual-sided political border presentation are manually accepted. `data/world_map/astra_province_corrections.json` is the version-controlled correction authority over the immutable Azgaar export; the runtime JSON and coverage report are deterministic derivatives. DEV-022 records stable/retired ID policy, complete playable-land coverage and inland-water ownership.

A separately authorised settlement representation prototype is also present for review in the real Gameplay 001 wrapper. It compares the exact supplied 2D image with a Godot primitive blockout at matching anchors in provinces 67 and 54, without adding settlement state or changing the locked world.

Stage 1 foundation work is implemented. The explicit September 2026 Astra tasks delivered full-continent Terrain3D data, aligned mask QA, the initial 82-province data layer, a diagnostic biome preview and a separate textured surface preview; the authoritative corrected layer now contains 100 active provinces. The older static-map brief and six-province restriction do not describe this authorized terrain work; DEV-016 records that scoped reconciliation. The subsequent final-natural-world assignment explicitly authorizes natural decoration, water, lighting and surface completion; DEV-017 records this extension. Province rendering, gameplay expansion and interaction-gate Pass remain separate.

September 8 art-polish revision: DEV-018 supersedes the first natural-world art handoff. The same final scene now uses the curated botanical library, composed districts/discoveries, lit connected water and a selected 40° / 800–3,600 gameplay camera. Current evidence lives in `08_Final_Terrain/QA/Natural_World_Polish/`, with an HTML review, matched before/after views, motion and preservation/performance records. Earlier `Godot_Natural_World/final` images remain historical.

September 9 final production revision: DEV-019 closes terrain/natural-world work on the accepted foundation. Contextual shoreline finish, selective waterside detail and water reactions, route-following river motion, retained-source rock faceting and mountain material shading are presentation only. Evidence is in `08_Final_Terrain/QA/Natural_Production/`; the accepted checkpoint is `06_Astra_Checkpoints/Natural_Production_2026-09-09/`. Gameplay is the next separately scoped assignment.

September 10 atmospheric finish: DEV-020 supersedes DEV-019's artistic acceptance. The installed final scene uses original Fourier ocean waves, contextual surf and obstacle reactions, actual cloud volumes with projected shadows, new sunlight and canopy/material response, restrained ridge relief and bounded shore composition. Current comparisons, 108 regional views, water/cloud motion and installed validation are under `08_Final_Terrain/QA/Natural_Beauty/`. The full pre-beauty checkpoint is `06_Astra_Checkpoints/Natural_Beauty_2026-09-09/`. Terrain/natural-world production is complete; the next separately scoped task is gameplay.
