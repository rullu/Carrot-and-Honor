# Project Index

This file explains where project truth lives and which document owns which type of information.

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

## Source hierarchy

When sources disagree:

1. Master Bible v1.6 controls consolidated high-level design.
2. Goods Design Workbook v1.3 controls detailed goods questions within that direction.
3. Repository documentation and tests control implemented reality.
4. The change register supplies history rather than current authority.
5. Any unresolved conflict must be logged before coding continues.

## Current phase boundary

Gameplay 001 now instances the locked NaturalWorld and adds province lookup, hover, selection, permanent-border presentation, separate province/realm prototype state and a debug panel. DEV-021 records this narrow interaction gate. Visual testing accepted the interaction architecture while exposing defects in the authoritative geography; correction remains a separate task.

Stage 1 foundation work is implemented. The explicit September 2026 Astra tasks have delivered full-continent Terrain3D data, aligned mask QA, all 82 provinces as data, a diagnostic biome preview and a separate textured surface preview. The older static-map brief and six-province restriction do not describe this authorized terrain work; DEV-016 records that scoped reconciliation. The subsequent final-natural-world assignment explicitly authorizes natural decoration, water, lighting and surface completion; DEV-017 records this extension. Province rendering, gameplay expansion and interaction-gate Pass remain separate.

September 8 art-polish revision: DEV-018 supersedes the first natural-world art handoff. The same final scene now uses the curated botanical library, composed districts/discoveries, lit connected water and a selected 40° / 800–3,600 gameplay camera. Current evidence lives in `08_Final_Terrain/QA/Natural_World_Polish/`, with an HTML review, matched before/after views, motion and preservation/performance records. Earlier `Godot_Natural_World/final` images remain historical.

September 9 final production revision: DEV-019 closes terrain/natural-world work on the accepted foundation. Contextual shoreline finish, selective waterside detail and water reactions, route-following river motion, retained-source rock faceting and mountain material shading are presentation only. Evidence is in `08_Final_Terrain/QA/Natural_Production/`; the accepted checkpoint is `06_Astra_Checkpoints/Natural_Production_2026-09-09/`. Gameplay is the next separately scoped assignment.

September 10 atmospheric finish: DEV-020 supersedes DEV-019's artistic acceptance. The installed final scene uses original Fourier ocean waves, contextual surf and obstacle reactions, actual cloud volumes with projected shadows, new sunlight and canopy/material response, restrained ridge relief and bounded shore composition. Current comparisons, 108 regional views, water/cloud motion and installed validation are under `08_Final_Terrain/QA/Natural_Beauty/`. The full pre-beauty checkpoint is `06_Astra_Checkpoints/Natural_Beauty_2026-09-09/`. Terrain/natural-world production is complete; the next separately scoped task is gameplay.
