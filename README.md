# For Carrot and Honour

A 2D medieval-fantasy strategy and province-management game built with Godot 4 and typed GDScript.

## Current phase

**Phase 1A — typed-GDScript and minimal headless smoke-test foundation.**

The repository currently contains:

- a minimal Godot 4 project;
- repository rules for Codex and human contributors;
- technical documentation;
- an intentionally empty modular source layout.
- a typed-GDScript headless smoke test.

There is no gameplay code and no main scene yet.

## Design sources

Implementation must remain aligned with:

1. `Bunny_Kingdom_Design_Bible_v1.8_Architecture.xlsx`
2. `Bunny_Kingdom_Visual_Concept_Bible_v0.7_Consolidated.xlsx`
3. `Bunny_Kingdom_Narrative_Design_Bible.xlsx`

The source workbooks are design authorities. Repository documents translate their relevant decisions into implementation rules.

## Technical foundation

- Engine: Godot 4
- Language: typed GDScript
- Version control: Git
- Simulation: compact data updated on scheduled ticks
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

From PowerShell inside this folder:

```powershell
godot --editor --path .
```

## Running the foundation smoke test

From PowerShell inside this folder:

```powershell
godot --headless --path . --script res://tests/foundation_smoke_test.gd
```

Exit code `0` means the smoke test passed. A non-zero exit code means it failed.

## Running the simulation clock test

From PowerShell inside this folder:

```powershell
godot --headless --path . --script res://tests/simulation_clock_test.gd
```

Exit code `0` means the simulation clock test passed. A non-zero exit code means it failed.

## Running the good definition test

From PowerShell inside this folder:

```powershell
godot --headless --path . --script res://tests/good_definition_test.gd
```

Exit code `0` means the good definition test passed. A non-zero exit code means it failed.

## Current stop condition

Do not begin gameplay features until the workspace verification checklist in `docs/implementation_plan.md` is complete.
