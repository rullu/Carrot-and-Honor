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
- [~] Complete verification and diff review while leaving this milestone unstaged and uncommitted.

This milestone is implemented but not committed. It introduces no quantities, production, workforce, Food arithmetic, Nodes, scenes or UI.

The next implementation step must be separately authorised and tightly scoped. It must not introduce runtime production prematurely.

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
