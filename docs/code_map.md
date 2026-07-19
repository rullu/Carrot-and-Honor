# Code Map

The project contains only its workspace scaffold and foundation smoke test. This map establishes ownership before implementation begins.

## Root

### `project.godot`

Godot project configuration. There is currently no main scene.

### `AGENTS.md`

Binding development rules.

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

Pure-data definition for one good. It strictly validates a stable `StringName` ID and display name from an independent input dictionary without owning a loader, registry or economic state.

### `src/simulation/good_definition.gd.uid`

Godot-generated UID sidecar belonging to `good_definition.gd`.

## `src/presentation/`

Visual representation of the active province and other visible state.

Expected future responsibilities may include:

- province scene binding;
- building state visuals;
- camera behaviour;
- ambient bunny routes;
- non-authoritative carts and activity;
- animation and visual transitions.

No presentation module exists yet.

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

## `scenes/`

Godot scenes.

No scenes exist yet.

## `assets/`

Replaceable visual, audio and font assets.

No project assets exist yet.

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

Directly executable `SceneTree` test that verifies valid grain-definition construction, stable-ID lookup, instance independence and strict malformed-data rejection.

### `tests/good_definition_test.gd.uid`

Godot-generated UID sidecar belonging to `good_definition_test.gd`.

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

## Updating this map

Add every new source file here when it introduces a new responsibility, public interface or cross-module dependency.
