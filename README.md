# For Carrot and Honour

For Carrot and Honour is a real-time, pausable medieval-fantasy strategy game about ruling a bunny kingdom across one fixed, handcrafted continent. The interactive world map is intended to be the primary playing field, with province management available through panels. The project is built with Godot 4 and typed GDScript.

## Current phase

**Stage 1.5 — world-map visual feasibility.**

Stage 1 simulation and content-model foundations are complete. Further simulation expansion is paused until the world-map proof passes.

The repository now reserves empty workspace paths for future world-map assets, data, scenes and presentation code. Stage 1.5 visual direction is locked in the [world-map visual brief](docs/world_map/world_map_visual_brief.md), but no map implementation or artwork exists. The next activity is reference gathering and asset/pipeline research; full-continent work and further simulation expansion remain blocked until the proof passes.

## Implemented foundation

The repository currently contains:

- a minimal Godot 4 project with no main gameplay scene;
- binding repository rules and technical documentation;
- a deterministic pure-data simulation clock;
- clock state round-trip support;
- validated good and building definitions;
- a prototype capability catalogue;
- an immutable `ProvinceCapabilityState`;
- direct typed-GDScript headless tests.

There is no runtime gameplay yet.

## Active world-map gate

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
```

Exit code `0` means a test passed. A non-zero exit code means it failed.

## Current stop condition

Further simulation features—including Population, workforce, Food arithmetic, construction, routes and detailed province scenes—must not begin until the six-province world-map feasibility gate passes.
