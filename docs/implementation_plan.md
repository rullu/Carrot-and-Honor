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

Only Phase 1A is authorised. The remaining foundation work is not authorised yet.

### Phase 1A — Typed-GDScript and minimal headless smoke-test foundation

- [x] Add and verify a directly executable typed-GDScript headless smoke test.

Expected proof targets:

- typed GDScript conventions;
- data-defined content loading and validation;
- central clock and scheduled ticks;
- save/load foundation;
- a minimal temporary diagnostic UI;
- deterministic simulation verification;
- a synthetic performance benchmark.

No province gameplay should be built before these foundations are reviewed.

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
