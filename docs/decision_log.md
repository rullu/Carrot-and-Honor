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
