# Code Map

The project contains verified pure-data foundation types and directly executable headless tests. There is no runtime gameplay or main scene.

## Root

### `project.godot`

Godot project configuration. There is currently no main scene.

### `AGENTS.md`

Binding development rules.

## `docs/world_map/`

Stage 1.5 workspace and visual-direction documentation.

### `docs/world_map/world_map_visual_brief.md`

Detailed authority for planned Stage 1.5 world-map visuals, interactions, proof content and acceptance criteria. It documents intended behaviour only and does not represent implemented map code, assets or runtime data.

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

The only presentation module is a disposable Stage 1.5 terrain integration proof. It establishes no permanent world-map architecture.

### `src/presentation/world_map/`

Reserved for presentation-only world-map controllers and helpers.

### `src/presentation/world_map/world_map_camera_controller.gd`

Typed camera controller used only by the disposable Stage 1.5 integration proof. It owns keyboard, middle-drag, screen-edge and wheel input; cursor-focused uniform zoom; viewport-responsive cover zoom; and terrain-bound camera clamping. It has no simulation, province, UI or gameplay dependency and does not establish the permanent world-map controller architecture.

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

Reserved for future stable province, settlement and map-related runtime data. It is empty apart from `.gitkeep`; no world-map data exists.

## `scenes/`

Godot scenes.

The repository contains one dedicated disposable world-map integration proof scene. There is still no main gameplay scene.

### `scenes/world_map/`

Reserved for Godot world-map scenes.

### `scenes/world_map/world_map_integration_proof.tscn`

Disposable Stage 1.5 integration scene containing only the native-scale terrain sprite and its presentation camera. It is directly launchable for manual verification, is not assigned as the project main scene and has no simulation or UI dependency.

## `assets/`

Replaceable visual, audio and font assets.

The repository contains one approved game-ready terrain export for the disposable Stage 1.5 integration proof.

### `assets/world_map/base/`

Reserved for approved game-ready static terrain exports.

### `assets/world_map/base/stage_1_5_six_province_map_01_terrain_base_candidate_01.png`

Unmodified 1920 x 1080 PNG terrain export displayed by the disposable Stage 1.5 integration proof. It owns no runtime state or behaviour.

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
