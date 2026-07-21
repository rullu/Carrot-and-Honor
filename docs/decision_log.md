# Technical Decision Log

Repository-level technical decisions are recorded here. Game-design decisions remain in the design bibles.

---

## DEV-001 — Godot 4 with typed GDScript

**Date:** 2026-07-19  
**Status:** Accepted

Use Godot 4 and typed GDScript for the project foundation.

**Reason:** The prototype is a 2D strategy simulation whose primary challenge is clean data architecture and controlled update frequency, not massive real-time physics.

**Consequence:** Language escalation requires measured evidence and a new logged decision.

---

## DEV-002 — Three-layer architecture

**Date:** 2026-07-19  
**Status:** Accepted

Separate authoritative simulation, visual presentation and UI.

**Reason:** This prevents scene objects and panels from becoming hidden owners of game rules.

**Consequence:** Simulation cannot depend on presentation or UI modules.

---

## DEV-003 — Scheduled simulation ticks

**Date:** 2026-07-19  
**Status:** Accepted

World and economic simulation will run through a central clock and explicit scheduled ticks rather than frame callbacks.

**Reason:** Strategy-state changes do not need to be recalculated every rendered frame.

**Consequence:** `_process()` and `_physics_process()` are reserved for presentation and input needs, not authoritative world simulation.

---

## DEV-004 — Compact data instead of one Node per entity

**Date:** 2026-07-19  
**Status:** Accepted

Goods, buildings, workers, populations and future world entities are represented as compact records and services.

**Reason:** Invisible simulation entities do not need SceneTree overhead.

**Consequence:** Ambient bunnies, carts and similar visuals are non-authoritative representations.

---

## DEV-005 — Data-driven definitions with stable IDs

**Date:** 2026-07-19  
**Status:** Accepted

Content definitions use stable machine IDs that are separate from display text.

**Reason:** Data must remain editable, testable, localisable and safe to reference.

**Consequence:** Duplicate and missing references must fail validation clearly.

---

## DEV-006 — Repository documentation is implementation truth

**Date:** 2026-07-19  
**Status:** Accepted

`AGENTS.md` and the documents under `docs/` record implementation rules, ownership and decisions.

**Reason:** Browser and Codex conversations are temporary working contexts and must not be the only record.

**Consequence:** Relevant documentation changes are part of completing a code task.

---

## DEV-007 — Placeholder-first presentation

**Date:** 2026-07-19  
**Status:** Accepted

Foundation tests and the province greybox use replaceable placeholder presentation.

**Reason:** The next useful evidence must come from a running project; final visual assets are not required for architecture verification.

**Consequence:** No foundational code may depend on exact sprite dimensions, final character anatomy or polished UI decoration.

---

## DEV-008 — No gameplay before workspace verification

**Date:** 2026-07-19  
**Status:** Accepted

The repository may not begin gameplay implementation until Phase 0 in `implementation_plan.md` is complete.

**Reason:** Tooling, version control, documentation and project loading must be trusted first.

**Consequence:** The first commit contains only workspace and documentation scaffolding.

---

## DEV-009 — Ordinary goods use capability semantics

**Date:** 2026-07-20
**Status:** Accepted

Master Bible v1.4 is the consolidated high-level authority. Goods Design Workbook v1.3 is the detailed specialist annex, and Gameplay Direction Change Register v0.1 is reconciliation history.

Ordinary goods represent province-local capability and access rather than universal numerical inventory. Carrots, Food and Population are separate systems. Code retains underscore stable IDs such as `good_grain` and `building_bakery`.

**Consequence:** Timber enables automatic local Firewood without a prototype Woodcutter. The bread-capability foundation represents provider and prerequisite relationships without quantity fields, inventory, storage, recipe objects or production ticks.

---

## DEV-010 — Province capabilities are immutable evaluated snapshots

**Date:** 2026-07-20
**Status:** Accepted

A province capability state owns copied, validated present-building IDs and derives goods in deliberate catalogue content order. Duplicate and unknown building IDs invalidate creation.

Blocked goods report direct missing providers and direct missing prerequisites in declared order rather than flattened transitive causes.

**Consequence:** Province capability queries remain deterministic and pure data. This milestone adds no quantities, production execution, workforce, Food arithmetic, Nodes, scenes or UI.

---

## DEV-011 — Stage 1.5 world-map visual direction

**Date:** 2026-07-21
**Status:** Accepted

Use a fixed, serious three-quarter world-map presentation. Terrain, political and diplomatic views are treatments of the same geography. Validate the direction through a six-province near-final-quality proof using a scalable, coherent commercial-asset pipeline.

**Consequence:** The proof is judged through a Pass / Revise / Replace gate. Full-continent production and further simulation expansion remain blocked until **Pass**; the detailed requirements live in [`docs/world_map/world_map_visual_brief.md`](world_map/world_map_visual_brief.md).
