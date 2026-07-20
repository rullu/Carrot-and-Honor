# Code Map

The project contains verified pure-data foundation types and directly executable headless tests. There is no runtime gameplay or main scene.

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

Pure-data definition for one ordinary-good capability. Its authoritative fields are stable ID, display name, province-local scope, availability kind, optional provider-building ID and ordered prerequisite-good IDs. It validates exact input fields and returns defensive prerequisite-array copies.

### `src/simulation/good_definition.gd.uid`

Godot-generated UID sidecar belonging to `good_definition.gd`.

### `src/simulation/building_definition.gd`

Pure-data definition for one building. Its authoritative fields are stable ID, display name and placement kind. It owns no production, construction or operating state.

### `src/simulation/building_definition.gd.uid`

Godot-generated UID sidecar belonging to `building_definition.gd`.

### `src/simulation/prototype_content_catalogue.gd`

Tightly scoped pure-data catalogue for the fixed bread-capability slice. It validates nulls, duplicate IDs, provider and prerequisite references, and direct or indirect dependency cycles. It exposes deterministic lookups without exposing its dictionaries or owning quantities, inventories, storage, recipes or production ticks.

### `src/simulation/prototype_content_catalogue.gd.uid`

Godot-generated UID sidecar belonging to `prototype_content_catalogue.gd`.

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
