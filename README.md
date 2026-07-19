# For Carrot and Honour

A 2D medieval-fantasy strategy and province-management game built with Godot 4 and typed GDScript.

## Current phase

**Development workspace establishment only.**

The repository currently contains:

- an empty Godot 4 project;
- repository rules for Codex and human contributors;
- technical documentation;
- an intentionally empty modular source layout.

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

## Current stop condition

Do not begin gameplay features until the workspace verification checklist in `docs/implementation_plan.md` is complete.
