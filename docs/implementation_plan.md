# Implementation Plan

## Status key

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked

## Phase 0 — Development workspace

Goal: establish a safe, understandable repository before gameplay work.

- [x] Confirm Godot 4.7.1 launches.
- [x] Confirm `godot` is available from PowerShell.
- [x] Install and configure Git.
- [x] Install and authenticate Codex CLI.
- [x] Place this scaffold in the final local project folder.
- [x] Initialise a Git repository with branch `main`.
- [x] Confirm all required files exist.
- [x] Open the empty project in Godot.
- [x] Confirm Godot reports no project parse errors.
- [x] Confirm `git status` shows only expected initial files.
- [x] Create the initial Git commit.
- [x] Mark the workspace gate complete in this file.

### Workspace gate

**Status: COMPLETE.** No gameplay work is authorised in this setup chat; a separate explicit implementation task is required.

## Phase 1 — Foundation tests

Phase 1A was the original authorised foundation boundary. Phase 1B was subsequently authorised as a separate pure-data milestone.

### Phase 1A — Typed-GDScript and minimal headless smoke-test foundation

- [x] Add and verify a directly executable typed-GDScript headless smoke test.
- [x] Add and verify a minimal deterministic simulation clock with explicit daily ticks and configurable uniform month length.
- [x] Add and verify strict pure-data simulation-clock state export and deterministic restoration.
- [x] Add and verify one strictly validated pure-data good definition.
- [x] Add and verify one strictly validated pure-data building definition.

Expected proof targets:

- typed GDScript conventions;
- data-defined content loading and validation;
- central clock and scheduled ticks;
- save/load foundation;
- a minimal temporary diagnostic UI;
- deterministic simulation verification;
- a synthetic performance benchmark.

No province gameplay should be built before these foundations are reviewed.

### Phase 1B — Pure-data capability-content foundation

- [x] Expand strict good definitions with capability scope, availability, providers and ordered prerequisites.
- [x] Expand strict building definitions with placement kinds.
- [x] Add and verify the fixed Timber/Firewood and Farm/Grain/Mill/Flour/Bakery/Bread catalogue.
- [x] Reject duplicate IDs, missing references and direct or indirect prerequisite cycles deterministically.
- [x] Verify defensive collection copying and deterministic stable-ID lookup.
- [x] Complete implementation, verification and diff review, then commit and push baseline `b4dc7b4485d86af37fddb56e1005032c9b58d4ca`.

This milestone is complete and committed at pushed baseline `b4dc7b4485d86af37fddb56e1005032c9b58d4ca`. It contains no quantities, inventories, storage, recipes, production ticks or prototype Woodcutter. Carrots, Food and Population remain separate future numerical systems.

### Phase 1C — Pure-data province capability state

- [x] Store a validated, sorted defensive copy of present building IDs.
- [x] Derive available and blocked goods in authoritative catalogue order.
- [x] Report direct missing-provider and missing-prerequisite causes.
- [x] Verify deterministic results, strict invalid-input rejection and collection independence.
- [x] Complete verification, diff review, commit and push.

This milestone is implemented and committed. It introduces no quantities, production, workforce, Food arithmetic, Nodes, scenes or UI.

The next implementation step must be separately authorised and tightly scoped. It must not introduce runtime production prematurely.

## Stage 1.5 — World-map visual feasibility

**Status: ACTIVE.** The verified repository baseline before the Godot integration proof is `92d0ce544bef1671e560b3efeb35f51697a6aa72`.

- [x] Establish the controlled empty repository workspace and external editable-source boundary.
- [x] Record the locked visual, interaction, proof-content and acceptance direction in [`docs/world_map/world_map_visual_brief.md`](world_map/world_map_visual_brief.md).
- [ ] Gather references and research suitable assets and the planned pipeline.
- [~] Implement the disposable Godot terrain integration proof with native terrain display, bounded camera panning and restrained zoom. Headless integration verification is complete; manual visual and control verification remains required.
- [x] Import the completed Astra playable production heightfield through Terrain3D at full 4096 x 2304 float32 precision, preserve north-up alignment and physical proportions, and verify the minimal Godot inspection scene against Astra QA.
- [x] Crop Astra Features RGBA to exact rows `[896, 3200)`, preserve its linear RGBA8 samples, and prove the R-channel land boundary shares the Terrain3D crop, origin, orientation and sample grid with no one-sample offset.
- [x] Generate and validate the authoritative pure-data layer for all 82 Azgaar provinces, including precise closed boundary rings, selection and label points, bounds, areas and neighboring province IDs in the established Godot X/Z frame.
- [x] Repair the disposable Astra biome preview and validate a smoothly blended four-channel material-mask colour view without changing terrain data or beginning PBR production.
- [x] Build and visually iterate a separate full-world textured terrain-art preview from the verified staged library; preserve all terrain, masks, province data and existing QA scenes. Validate actual GPU material activation, required regional views, controls, resource hashes and regression tests. See `world_map/astra_terrain_art.md`.
- [x] Complete the final natural-world presentation: stochastic surface sampling, cold/dry/arid differentiation, reconstructed shore and river boundaries, elevated inland water, sparse ecological miniature props, fixed lighting, gameplay-distance presets and validated renders. See `world_map/astra_natural_world.md` and DEV-017.
- [x] Perform the human-review natural-world polish pass: curated ecological silhouettes, authored districts/discoveries, lit connected water, varied coast/rock shores, camera-envelope study, matching captures and measured development-machine performance. See DEV-018 and the updated natural-world handoff.
- [x] Complete the final terrain/environment production pass on the accepted foundation: contextual shore finish, selective water-side detail and reactions, small-water compositions, crisp retained-source rocks, mountain readability, local anomaly sweep, matched gameplay-distance renders, motion-frame review and preservation/performance verification. Preserve the accepted checkpoint and install the reviewed package. See DEV-019; its artistic acceptance was superseded by the subsequent atmospheric assignment.
- [x] Complete the substantial atmospheric beauty rework on the preserved foundation: living ocean, varied coasts, source-directed river currents and selected reactions, actual moving cloud volumes and shadows, cohesive lighting/material/foliage response, bounded composition, matching before/after review, regional motion and installed preservation checks. See DEV-020. **Terrain / natural-world phase closed; gameplay is next.**
- [ ] Begin the controlled six-province production proof in a separately authorised task.

The Astra terrain, first control-mask alignment proof and province data pipeline establish reliable aligned full-continent data paths, but they do not establish permanent world-map architecture or satisfy the Stage 1.5 Pass gate. The accepted natural-world foundation and DEV-020 atmospheric finish are complete in the dedicated final scene; no further terrain work is scheduled. Province rendering and selection and the wider interaction proof remain unimplemented.

September 2026 scope reconciliation: the explicit full-world Astra tasks supersede the old static/six-province restriction only for their authorized data, QA and surface-art work. DEV-016 originally delivered a first textured surface preview without an interaction-gate Pass. The later explicit final-natural-world task supersedes that surface-only stop: natural decoration and water are now included. Gameplay and interaction work still require their own task.

The later six-province proof must be reviewed for:

- fixed authored geography and readable static illustrated terrain;
- camera movement and zoom;
- province polygons and selection;
- normal terrain mode and political mode.

Full-continent work and further simulation expansion remain blocked until the six-province proof receives a **Pass** decision. Detailed province close-up scenes remain deferred beyond the prototype.

## Gameplay 001 — Province Interaction Gate

**Status: COMPLETE; visually accepted.**

- [x] Instance the locked NaturalWorld in a separate gameplay wrapper.
- [x] Load and query the authoritative active province polygons without runtime regeneration.
- [x] Add permanent border presentation, hover feedback and persistent selection.
- [x] Keep ProvinceState and RealmState independent, including one- and multi-province realm fixtures.
- [x] Preserve camera behaviour and block UI click-through.
- [x] Pass the complete 13-test direct suite and human interaction review.

Visual review found authoritative coverage, inland-hole and small-shape problems.

## World Identity Integration

**Status: COMPLETE.**

- [x] Install the locked master JSON byte-for-byte in a canonical data location.
- [x] Add a centralized pure-data Godot catalogue with defensive province, realm, formable and special-system queries.
- [x] Validate 100 unique provinces and 43 unique starting realms against active geography and frozen political ownership.
- [x] Validate exact starting owners, realm footprints, realm identity summaries and all explicit formable references.
- [x] Preserve Province 30 Hasenmark/R028 mixed identity and R008 `holy_state` with its ceremonial title deferred.
- [x] Add direct headless inspection plus targeted rejection, UTF-8 and special-case tests.
- [x] Keep all modifiers, conversion, unrest, diplomacy, rebellion, formation and special-system execution deferred.

This milestone changes no terrain, NaturalWorld, topology, border geometry or
frozen ownership data. See `docs/world_identity/world_identity_runtime.md` and
DEV-024.

## Gameplay Canonical Identity Binding Repair

**Status: COMPLETE.**

- [x] Replace geography-source province names in the debug panel with canonical identity names.
- [x] Replace mock `RealmState` display/ownership with catalogue realm identity and frozen owner IDs.
- [x] Remove fake political IDs and fake realms from `PrototypeWorldState`.
- [x] Keep Population, Food, Carrots and Development isolated and visibly labelled as non-canonical prototype metrics.
- [x] Validate the actual gameplay controller and panel path across all 100 provinces and all 43 starting owners.
- [x] Preserve the settlement prototype and all locked terrain, NaturalWorld, topology, borders and ownership data.

DEV-025 records the corrected authority path.

## Province Geography Correction Pass

**Status: COMPLETE; manually accepted.**

- [x] Add a version-controlled correction manifest over the immutable Azgaar source.
- [x] Assign all meaningful playable land without changing terrain or coastline.
- [x] Fill the 11 audited enclosed lakes and the province 22 land defect politically; also fill three lakes newly enclosed by corrected eastern/northern territory.
- [x] Retire IDs 8, 31, 57, 63, 68, 81 and 82 through stable-ID merges; preserve IDs 83-89 and add accepted IDs 90-107 above the historical maximum.
- [x] Reassign unrelated fragments of provinces 32, 38, 39 and 49 while retaining legitimate islands and coastal components.
- [x] Recalculate rings, bounds, area, neighbors and corrected anchors deterministically.
- [x] Add accepted-mask coverage validation and full-map QA images.
- [x] Add and validate the dual-sided medieval political border ribbon without changing authoritative geometry.
- [x] Complete human scalpel review of the corrected strategic shapes and political borders.

## Phase 2 — One-province greybox

Not authorised yet.

Expected proof targets:

- fixed three-quarter Hill-Fort composition;
- panning and cursor-focused zoom;
- stable site anchors and clickable areas;
- replaceable placeholder art;
- clear separation between scene representation and simulation data.

## Phase 3 — First playable economic loop

Not authorised yet.

Expected order:

1. grain;
2. flour;
3. fuel;
4. bakery construction;
5. bread production;
6. stocks, labour and shortage feedback;
7. a short relevant notice and chronicle entry;
8. save and reload the resulting state.

Stop adding scope until this loop is understandable and playable.

## Change rule

Only one plan item should be actively implemented at a time unless the items are inseparable parts of the same verification step.
