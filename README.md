# For Carrot and Honour

A 2D medieval-fantasy strategy and province-management game built with Godot 4 and typed GDScript.

## Current phase

**Pure-data province capability foundations.**

The repository currently contains:

- a minimal Godot 4 project with no main scene;
- binding repository rules and technical documentation;
- a deterministic pure-data simulation clock;
- strictly validated good and building definitions;
- a tightly scoped bread-capability catalogue;
- an immutable province capability snapshot with direct blocker queries;
- directly executable typed-GDScript headless tests.

There is no runtime gameplay yet.

## Design sources

1. Master Bible v1.4 is the consolidated high-level authority.
2. Goods Design Workbook v1.3 is the detailed specialist annex.
3. Gameplay Direction Change Register v0.1 is reconciliation history.
4. Repository documentation and tests are authoritative for implemented reality.

Ordinary goods are province-local capabilities rather than universal inventories. Timber enables automatic Firewood; Farm provides Grain; Mill requires Grain and provides Flour; Bakery requires Flour and Firewood and provides Bread. There is no prototype Woodcutter. Carrots, Food and Population remain separate future systems.

This foundation contains no quantities, inventories, storage, recipes or production ticks. Code uses underscore stable IDs.

Verified pushed baseline: `b4dc7b4485d86af37fddb56e1005032c9b58d4ca`.

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

Do not begin runtime production or other gameplay features without a separate explicitly authorised milestone.
