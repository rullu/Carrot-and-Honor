# AGENTS.md

This file contains binding rules for all coding agents and contributors working on **For Carrot and Honour**.

## 1. Current authority and scope

Read these files before changing code:

1. `README.md`
2. `docs/project_index.md`
3. `docs/code_map.md`
4. `docs/implementation_plan.md`
5. `docs/decision_log.md`

Current phase: **Campaign-Start Procedural Cast + Naming + Generator v1** on the accepted 100-province geography, 43 starting Realms and implemented world identity. Terrain and NaturalWorld are locked.

Design and implementation authority:

- `docs/design_authority/FCAH_Campaign_Start_Procedural_Cast_Naming_Generator_v1_FINAL_SEALED_2026-09-18.txt` governs campaign-start generation, naming, tuning and the narrow schema-v2 delta. Its implementation was explicitly authorized on September 18. Keep Day-1 validation separate from permanent campaign invariants; generation-affecting changes require a generator version bump.
- `docs/design_authority/FCAH_Gameplay_State_Architecture_v1_LOCKED.txt` is the primary authority for current gameplay-state ownership, references and lifecycle boundaries. Read it before changing campaign state. `docs/design_reference/` is context and `docs/design_archive/` is superseded history.
- Master Bible v1.4 is the consolidated high-level design authority.
- Goods Design Workbook v1.3 is the detailed specialist annex.
- Gameplay Direction Change Register v0.1 is reconciliation history.
- Repository documentation and tests remain authoritative for implemented reality.

Do not expand beyond the explicitly authorised gameplay milestone or create a project main scene without a separate task.

## 2. Language and Godot rules

- Use Godot 4 and typed GDScript.
- Type function parameters, return values, variables and collections where practical.
- Treat warnings as problems to understand, not noise to suppress.
- Prefer composition and small focused classes over deep inheritance.
- Do not introduce C#, C++, GDExtension or threading without a measured, documented need.

## 3. Naming

- Files and folders: `snake_case`
- Functions and variables: `snake_case`
- Constants: `UPPER_SNAKE_CASE`
- Classes and named resources: `PascalCase`
- Signals: past-tense or event-style `snake_case`, such as `day_advanced`
- Data IDs: stable lowercase identifiers such as `good_grain` or `building_bakery`

Names must describe responsibility clearly. Avoid vague files such as `manager.gd`, `utils.gd`, `stuff.gd` or `helpers.gd` unless their domain is explicit.

## 4. Architectural boundaries

The codebase has three primary layers:

### Simulation

Location: `src/simulation/`

Owns authoritative game state and rules.

Simulation code:

- must use compact data rather than one Node per simulated citizen, good, shipment or business;
- must update through scheduled ticks;
- must not depend on scenes, sprites, Controls, animations or UI state;
- must expose clear state changes for other layers to observe.

### Presentation

Location: `src/presentation/`

Owns visual representation of simulation state.

Presentation code:

- may read simulation state through defined interfaces;
- may animate, interpolate and display non-authoritative ambient activity;
- must never become the source of economic truth;
- must not alter simulation data directly through hidden side effects.

### UI

Location: `src/ui/`

Owns player input, panels, HUD and readable feedback.

UI code:

- requests actions through explicit simulation-facing interfaces;
- reads view-ready state;
- must not contain economic formulas or duplicate simulation rules;
- must not search the SceneTree repeatedly to discover core state.

Dependency direction:

```text
UI ---------> Simulation interfaces
Presentation -> Simulation read interfaces
Simulation -X-> UI or Presentation
```

## 5. Simulation timing

- Do not run world simulation in `_process()` or `_physics_process()`.
- A central game clock will schedule domain ticks.
- Prototype economic rules will use explicit ticks.
- Future world rules may use daily, monthly, seasonal and yearly schedules.
- Visual animation may run every frame, but it must remain non-authoritative.

## 6. Data-driven content

Ordinary goods represent province-local capability and access, not universal numerical inventories. Carrots, Food and Population are separate future numerical systems, not ordinary goods.

Code uses underscore stable IDs such as `good_grain` and `building_bakery`; dotted design notation is not used in code.

In the prototype capability foundation, Timber enables automatic local Firewood. There is no prototype Woodcutter.

Province capability state owns a validated set of present building IDs and derives available goods plus direct blockers in authoritative catalogue order. It does not own quantities or production execution.

Every definition must have a stable ID.

Do not use display names as identifiers.

Validation must fail clearly when:

- an ID is duplicated;
- a referenced ID does not exist;
- required data is missing;
- a value violates a declared rule.

## 7. File responsibility

Each file should have one clear reason to change.

Split a file when it starts owning unrelated responsibilities. Do not split files merely to chase tiny line counts.

Avoid:

- global mutable state without explicit ownership;
- circular dependencies;
- giant controllers containing every rule;
- duplicated formulas;
- broad rewrites unrelated to the requested task;
- speculative abstractions with no current caller.

## 8. Changes and review

For every task:

1. State which files will change and why.
2. Make the smallest coherent change.
3. Run the relevant verification.
4. Review the diff.
5. Update documentation when architecture, ownership, public interfaces or decisions change.
6. Do not silently broaden scope.

Do not overwrite user work merely because another structure looks cleaner.

## 9. Comments and explanation

Comments should explain intent, invariants or non-obvious trade-offs.

Do not narrate obvious syntax.

Code should remain readable to a beginner inspecting it gradually.

## 10. Testing and debugging

New simulation rules require tests or deterministic verification before they are trusted.

Prefer tests against pure data and services.

Random behaviour must support a controlled seed for reproducible tests.

Do not “fix” failing tests by weakening them without explaining the underlying change.

## 11. Documentation duties

Update:

- `docs/code_map.md` when file ownership or dependency direction changes;
- `docs/implementation_plan.md` when a step starts, completes or changes;
- `docs/decision_log.md` when a technical choice affects future work;
- `README.md` when setup or entry instructions change.

The repository—not chat history—is the source of truth for implemented behaviour.
