# Project Index

This file explains where project truth lives and which document owns which type of information.

## External design authorities

### Master Bible v1.4

Current consolidated high-level authority for game direction, prototype scope and locked gameplay rules.

### Goods Design Workbook v1.3

Detailed specialist annex for ordinary-good capability and access relationships.

### Gameplay Direction Change Register v0.1

Historical reconciliation record. It does not supersede the reconciled authorities.

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

1. Master Bible v1.4 controls consolidated high-level design.
2. Goods Design Workbook v1.3 controls detailed goods questions within that direction.
3. Repository documentation and tests control implemented reality.
4. The change register supplies history rather than current authority.
5. Any unresolved conflict must be logged before coding continues.

## Current phase boundary

The pushed capability-catalogue baseline is `b4dc7b4485d86af37fddb56e1005032c9b58d4ca`. The current authorised implementation is the pure-data province-capability milestone. Runtime production and broader gameplay remain unauthorised.
