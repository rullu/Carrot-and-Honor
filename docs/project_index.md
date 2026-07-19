# Project Index

This file explains where project truth lives and which document owns which type of information.

## External design authorities

### Main Design Bible v1.8

Owns game-system decisions, prototype scope, architecture direction, staged development and locked gameplay rules.

### Visual Concept Bible v0.7

Owns prototype visual language, Hill-Fort spatial structure, placeholder policy, camera direction, visual progression and presentation readiness.

### Narrative Design Bible

Owns narrative tiers, data fields, event relevance, pacing, writing rules, prototype rumours and future expansion requirements.

## Repository authorities

### `README.md`

Quick orientation, tool choices, current phase and opening instructions.

### `AGENTS.md`

Binding implementation, naming, architecture, review and documentation rules.

### `docs/project_index.md`

Document ownership and source hierarchy.

### `docs/code_map.md`

Source folders, module ownership and permitted dependencies.

### `docs/implementation_plan.md`

Ordered implementation stages, gates and current status.

### `docs/decision_log.md`

Repository-level technical decisions and their consequences.

## Source hierarchy

When sources disagree:

1. The newest explicit locked decision in the relevant design bible wins.
2. A repository decision may refine implementation without changing game design.
3. Repository documents must not silently contradict the design bibles.
4. Any unresolved conflict must be logged before coding continues.

## Current phase boundary

Only workspace creation and verification are authorised.

The next phase may be planned, but gameplay code remains forbidden until the workspace gate is marked complete.
