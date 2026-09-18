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

---

## DEV-012 — Astra terrain import scale and storage

**Date:** 2026-09-07
**Status:** Accepted

Use Terrain3D 1.0.2 for the first Astra terrain integration. Import the 4096 x 2304 float32 playable EXR as 576 regions of 128 x 128 samples, keep Terrain3D's float32 region storage, and retain the project's OpenGL Compatibility renderer.

Use 1 Godot unit = 10 authored metres. The playable footprint is 50,000 x 28,125 units, vertex spacing is 12.20703125 units, and elevation is `R * 256 - 6.4` units. Raster sample `(i, j)` maps to `X = -25000 + i * 12.20703125`, `Z = -14062.5 + j * 12.20703125`. Image top maps to negative Z, image bottom to positive Z, west to negative X and east to positive X.

**Consequence:** Horizontal and vertical proportions remain physically consistent while the near-origin 50,000-unit world avoids the precision cost of the 500,000-metre authoring extent. Every future aligned mask, river and province layer must use the same crop, sample-centre convention, origin and coordinate conversion. The import scene remains an inspection proof and does not author materials, water, decoration or gameplay.

---

## DEV-013 — Astra raster control alignment

**Date:** 2026-09-07
**Status:** Accepted

Crop raster control layers with the same square rows `[896, 3200)` used by the playable heightfield. Keep all channels as linear, byte-exact data and map playable texel `(i, j)` to the existing Terrain3D vertex at `(-25000 + i * 12.20703125, -14062.5 + j * 12.20703125)` in Godot X/Z. Sample the diagnostic mask with nearest texel reads and no mipmaps or colour-space decoding.

The first proof uses only the R channel from Astra's Features RGBA image as authoritative land coverage. A sweep over every boundary sample found `(0, 0)` as the unique alignment optimum; a half-sample cardinal shift increases disagreement from 1,589 of 63,934 boundary samples to approximately 12,000, and a one-sample shift increases it to approximately 23,000. Manifest vector anchors use continuous coordinates and therefore add `0.5` to their exported `x * 1.6 - 0.5` sample values before the raster-grid world conversion.

**Consequence:** Raster layers must share the heightfield's crop, origin, scale and north-up orientation and may not be independently nudged or recentered. The diagnostic scene is QA only and establishes no production material, water, province or gameplay implementation.

---

## DEV-014 - Authoritative Astra province data

**Date:** 2026-09-07
**Status:** Accepted

Generate all 82 production provinces from the hash-verified Azgaar Full JSON instead of hand-authoring province records. Dissolve the source cell topology into closed rings, retain original continuous coordinates beside Godot X/Z coordinates, use the source center cell as the selection point and the Azgaar pole as the label point, and derive adjacency from neighboring source cells.

Convert continuous geometry through Astra's documented sample-centre path: `sample = source * 1.6 - 0.5`, then `world = terrain_origin + (sample + 0.5) * 12.20703125`. This preserves the manifest anchor positions and is equivalent to the approved direct authored-metre mapping at the project's 1:10 scale.

**Consequence:** `data/world_map/astra_provinces.json` is the first authoritative Godot-side province geography layer. It contains data only and does not authorize border rendering, hit testing, selection, labels, ownership colours, UI or simulation changes. Regeneration and validation are owned by `tools/world_map/import_astra_provinces.gd` and `tests/astra_province_data_test.gd`.

---

## DEV-015 - Disposable Astra material-weight preview

**Date:** 2026-09-07
**Status:** Accepted

Create a separate disposable Terrain3D preview for Astra's four-channel material weights. Use the exact 4096 x 2304 crop from square rows `[896, 3200)`, load it directly as linear RGBA8 data, normalize the real channel weights in the shader, and use filtered runtime mipmaps for stable whole-continent viewing. Keep an exact level-zero sample for the material footprint and coastline.

The preview explicitly disables Terrain3D's checker display when activating its shader override. Its sea is an unpolished opaque diagnostic plane just below sea level, avoiding transparent depth interference without changing terrain.

**Consequence:** `scenes/world_map/astra_biome_preview.tscn` is useful for inspecting broad temperate, dry, arid and rock placement, but it is not a final material system. It does not authorize PBR textures, vegetation, placed rocks, shoreline work, provinces, settlements, roads or gameplay.

---

## DEV-016 - Separate Astra textured-surface art preview

**Date:** 2026-09-08
**Status:** Implemented; first art direction ready for human inspection

The user's full-world terrain-art task explicitly supersedes the old pure-data phase label, static Wonderdraft/six-province restriction and DEV-015's no-textures stop condition for this surface-only work. It does not waive simulation boundaries or approve the wider interaction gate. DEV-012's 10 authored metres per unit remains authoritative, not the old material-proof scale or Astra's 8x QA exaggeration.

Use a separate Terrain3D shader override and scene, preserving the existing vertex kernel and all 576 region files. Normalize the exact aligned R/G/B/A material weights. Reuse eight verified sets with art-directed grading, two photographic scales, offset/rotation variation and distance-faded NormalGL detail. A seeded, aligned presentation context supplies variation and restrained height-derived colour relief, never displacement.

Store sRGB albedo as eight BC1 layers and linear NormalGL RGB/roughness A as eight BC3 layers with full, correctly generated mip chains. Save compressed CPU Image resources behind Texture2DArray descriptors: direct array serialization expanded compression on the tested Compatibility backend. A GPU constant-colour/sample probe verified this runtime's sRGB handling; the controller verifies the actual RenderingServer shader and disables Terrain3D diagnostics.

Keep preview water opaque and simple. Real-time sun shadows are disabled in this surface-only scene; actual terrain normals and bounded relief support carry landform shading. Existing source drainage has angular stretches: numerical source gradients and a normal-isolation render ruled out newly introduced region seams. Only the preview's extra lowland contrast was reduced; no authority was repaired or changed.

**Consequence:** `astra_terrain_art_preview.tscn` is the new human surface-inspection entry point. It is not a final water system, decorated world or shipping performance guarantee. Preserve both earlier QA scenes. Stop after this art direction and its evidence; world detail and gameplay remain separate work.

---

## DEV-017 - Final natural-world presentation

**Date:** 2026-09-08
**Status:** Implemented

The explicit final Astra assignment extends DEV-016's surface-only scope to completed biomes, shores, water, natural detail, fixed lighting and gameplay-view inspection. It supersedes the older decoration stop for this task, while preserving the simulation boundaries and all authoritative geography. It does not authorize settlements, roads, ownership, province rendering, UI systems or gameplay expansion.

Use `astra_natural_world_final.tscn` as the current natural-world entry point, retaining the earlier previews. Reuse the eight existing compressed material sets with stochastic triangular sampling. Derive ecology from the existing environment/material masks. Reconstruct shore distance with the original land/water sign preserved at every source pixel centre. Share river coverage between terrain and water so the heightfield's coarser triangles cannot cut teeth into water edges. Shade connected sea/lake/river water from one distance field to avoid artificial shallow strips across lake mouths and confluences. Keep source water elevations, river routes, terrain samples and all 82 provinces unchanged.

Use original deterministic miniature botanical/outcrop meshes in spatial MultiMesh batches. Their symbolic size is presentation only. Centre the existing Terrain3D clipmaps on inspected ground with a non-rendering focus camera. Use a fixed warm sun and real prop shadows; disable terrain self-shadow casting that produced diagonal acne in this skip-transform material. Terrain normals and height-derived relief remain active. No cloud/fog/blur cover is used.

**Consequence:** Natural-world presentation is ready as the base for the next separately scoped interaction task. GPU screenshots, close river/lake checks, bare-ground inspection, source hashes and placement verification accompany the handoff. The data-to-world mapping remains DEV-012/013/014; visual cutouts and miniature props must not become gameplay geography.

---

## DEV-018 - Natural-world art polish after human review

**Date:** 2026-09-08
**Status:** Implemented

The user's final polish assignment supersedes DEV-017's artistic acceptance. It explicitly permits richer sourced/authored nature, water redesign, regional composition, camera determination, motion and a handful of ancient environmental remnants. It preserves accepted terrain/mountains, climate geography, all 82 provinces and simulation boundaries. It does not authorize civilization, province ownership, roads, armies or gameplay systems.

Keep `astra_natural_world_final.tscn` as the installed entry point. Retain all source terrain/material arrays. Use the selected 26-model CC0 Quaternius library, runtime grading and original palms/cypresses/remnants. Compose 16 ecological districts and seven discoveries within source masks. Improve water through lit sky response, source depth/flow, connected mouth reconstruction and narrow bank geometry; keep routes and elevations authoritative. Shore character also responds to source rock, so mountain lakes do not inherit uniform beaches.

Select orthographic 40° with 1,600-unit normal, 800 closest and 3,600 furthest gameplay views after rendered comparison. Full foliage remains available at closest play zoom; card-preserving LODs, merged botanical surfaces, spatial batches and separate overview batches provide headroom. Ordinary leaf triangle collapse was rejected because it damaged canopy silhouettes. Cloud shade is now intentionally perceptible and slow; this replaces DEV-017's no-cloud art choice, without obscuring terrain.

The original installed scene was captured at matching camera poses before replacement. A full file checkpoint, independent data/placement checks, GPU regional/close/bare-ground views, navigation footage and indicative RTX 3060 Laptop measurements accompany this revision. See the current handoff for measured results and exact review paths. The prior art report is retained in the checkpoint. The next work is a separately scoped province interaction/readability task on this natural-world layer.

---

## DEV-019 - Close terrain and natural-world production

**Date:** 2026-09-09
**Status:** Implemented; terrain/natural-world phase complete

The user's final production assignment accepts the current world as permanent foundation and authorizes focused presentation polish and installation. Preserve the actual installed state as a file/hash checkpoint before work. All 82 provinces, 576 region files, authoritative sources, original composition and accepted water/bank geometry remain byte-identical. The current review envelope is orthographic 40 degrees, 800/1600/3600 units; eventual player zoom is not permanently locked.

Add contextual damp/gravel/rock/vegetated margins, 903 supplemental grounded instances at 62 sparse sites and 24 batched obstacle reactions. Derive continuous cyclic river progress from the existing authored polylines. Preserve shallow/deep response and quieter lakes; do not reroute or simulate fluids. Keep the existing CC0 curated rock silhouettes and UVs, with efficient faceting and retained palette. Support mountain mass through restrained source-slope/height material values; keep the actual terrain normal/TBN and vertex paths unchanged. Upward-biased bank-face shading removes a thin alternating dark edge without altering its geometry.

Visual acceptance uses matching in-engine 800/1600/3600 views, a 112-view regional/site sweep, full-resolution detail checks and sampled frames from recorded regional pans and water motion. Rejected rock replacements, mottled flow and actual terrain-normal amplification were removed when renders regressed. Preserve visual openness and existing successful compositions. No third-party assets are added in this pass; new reeds and effects are original project code using the existing library where applicable.

Matched RTX 3060 Laptop / 1600x900 measurements remain approximately 60 FPS normal, 58 closest and 50 farthest; timing is indicative, not GPU-only. Source/placement verification and the province/material regression tests pass. Evidence, the exact installation manifest and checkpoint live with `ASTRA_FINAL_PRODUCTION_HANDOFF.md` in the Astra workspace.

**Consequence:** use `astra_natural_world_final.tscn` as the completed natural-world layer. Terrain work is closed. The next task is gameplay/province interaction, without treating decorative derivatives as authoritative game state. This does not record an interaction-gate Pass or implement civilization systems.

---

## DEV-020 - Substantial atmospheric natural-world finish

**Date:** 2026-09-10
**Status:** Implemented; terrain/natural-world production complete

The user rejected DEV-019 as the final artistic result and explicitly unlocked the visible presentation while preserving the authoritative foundation. Preserve the installed project before experiments, diagnose actual engine renders, and require an immediate matching-camera difference. Keep the same final scene and the 40° / 800–3,600 camera envelope.

Replace the active water shader with an original directional Fourier spectrum, reflected sky/sun response, deeper body color, locally shoaling and breaking crests, source-directed river motion and selected visible obstacle turbulence. Calmer lakes retain depth and shallow-bed variation. Keep source coverage, routes, water elevations and bank geometry. A separate smoothed distance field changes edge appearance only. Damp/gravel/vegetated margins and three selected arid water surroundings use presentation fields.

Use three original finite cloud volumes in sparse slow-moving compositions. Project those same shapes along the actual sunlight direction for corresponding terrain, prop and water shade. Cloud opacity reduces at close zoom to preserve local readability. Clamp proxy clip depth so close-camera entry cannot slice clouds into flat shapes. This changes neither the camera projection nor the cloud's sampled world volume.

Reorient the fixed sun to (-52°, -145°, 0°), use cool ambient fill and restrained distance haze, and improve canopy value response and ground/rock material hierarchy. Source-slope shading strengthens major ranges; reduced fine normal response avoids dark speckles. The Terrain3D vertex kernel remains identical. Existing vegetation compositions are preserved. Remove 178 isolated stones, broaden/bury existing rock silhouettes and compose 29 selected coastal rocks with source-bed anchors; total composed instances are 38,468.

Reject rectangular cloud wisps, repetitive sine-wave water, oversized highlights, regular stone rows, inverted steep-shore blends and excessive mountain normal contrast. Forward+ contact-shading experiments reduced wooded views to roughly 33–40 FPS and weakened the canopy rendering; retain Compatibility. The accepted candidate remains around 64/60/53 FPS at normal/close/far on the RTX 3060 Laptop at 1600×900, with indicative frame-present measurements. The installed handoff records final measurements.

Evidence includes fresh pre-change matching captures, a 108-view regional/site sweep, full-resolution inspections, sampled in-engine motion frames, final installed renders, regression tests and hash verification. All 82 provinces, 576 regions, 12 export authorities, source heights/masks/routes and original vegetation compositions remain intact. New assets are original procedural project resources; existing CC0 provenance remains. The prior complete project is recoverable from `Natural_Beauty_2026-09-09`.

**Consequence:** build the next separately scoped gameplay/province interaction task on `astra_natural_world_final.tscn`. The natural-world phase is complete. Decorative fields, clouds, foam and miniature props do not own geography or simulation. This does not establish an interaction-gate Pass.

---

## DEV-021 - Province Interaction Gate

**Date:** 2026-09-10
**Status:** Implemented and visually accepted

Gameplay 001 uses a separate `world_gameplay.tscn` wrapper that instances the locked NaturalWorld. Cursor rays query Terrain3D for world X/Z, then use bounds-filtered polygon tests against the unchanged 82-province JSON. Province presentation consumes IDs from interaction and renders independent terrain-following border ribbons.

Geographic `ProvinceState` references a separate `RealmState` through `realm_id`; it does not replace `ProvinceCapabilityState` and does not equate a province with a realm. Fixed fixtures prove one- and multi-province realms without simulation, politics or realm formation.

**Consequence:** hover, persistent selection and plain province/realm inspection are available while terrain, camera and province geography remain unchanged. Human review found coverage gaps, inland water holes and potentially impractical province shapes. Those data defects require a separate geography correction pass.

---

## DEV-022 - Correct province geography through a non-destructive manifest

**Date:** 2026-09-10
**Status:** Accepted

Keep the Azgaar Full JSON immutable. Store reviewed changes in `astra_province_corrections.json`, then require the importer to apply that manifest before dissolving cells into runtime rings. Province IDs are stable opaque identifiers: merge 31 into 28, 63 into 62, 68 into 67, 81 into 65 and 82 into 56; retire the absorbed IDs permanently. Allocate provisional IDs 83-89 for coherent northern and eastern wilderness/desert divisions rather than stretching distant existing provinces across the 42.75383% coverage gap.

The accepted topology review additionally merges 8 into 9 and 57 into 56, divides the reviewed oversized and awkward regions through fresh IDs 90-107, and reserves 108 as the next new ID. The resulting authoritative layer contains exactly 100 active provinces and seven permanently retired IDs.

Assign the western unowned cells by deterministic graph distance to adjacent provinces 37, 54, 70 and 73, and assign the western Miland-source area to adjacent 37. Repair unrelated fragments by transferring one component of 38 to 41, two components of 39 to 32 and 21, three components of 49 to 76, and one component of 32 to 64. Retain multipart components where they are physical islands, coastal islets or coast-separated possessions.

Politically assign all eleven audited enclosed lakes and the land defect inside 22. The corrected northern/eastern coverage encloses three additional source lakes, which are assigned to 83, 84 and 87. This changes province lookup only; terrain, lakes, rivers, water rendering and NaturalWorld remain unchanged.

Require deterministic validation against the accepted 4096 x 2304 land mask and immutable source cells. Active provinces must contain land; meaningful and raw playable-land gaps, positive-area overlaps, political holes, external-ocean assignment, invalid anchors, asymmetric neighbors and retired-ID ownership must all be zero.

Render shared internal land borders as a presentation-only dual-sided political ribbon. Each half-band uses its owning province's deterministic prototype color, meets the other half at the authoritative center seam, fades inward and receives restrained pigment texture. Coastlines remain suppressed, hover and selection remain visual no-ops, and a palette-texture interface permits later realm colors without rebuilding geometry. The earlier subtle single-line treatment remains available behind a fallback constant.

**Consequence:** the runtime geography has 100 active, non-contiguous IDs and 25 provisional names. Province/realm separation is unchanged. Terrain, NaturalWorld, water, camera behavior, authoritative polygons and picking geometry are unchanged. Human review accepted both the topology and political-border presentation on 2026-09-12.

---

## DEV-023 - Reversible settlement representation comparison

**Date:** 2026-09-10
**Status:** Implemented; awaiting human visual review

Compare the exact supplied transparent `Testhome2d.png` with a crude Godot primitive blockout based on the supplied `testhome3d.png` sketch. Instance a removable presentation-only test under Gameplay 001, use shared terrain-grounded anchors in provinces 67 and 54, and expose F1/F2/F3/F4 modes for 2D, 3D, both and none. Keep the 2D image unchanged and build the 3D proxy from neutral primitives with no collisions, state or gameplay authority.

Use a roughly 94-unit 2D image width and 110 by 95-unit 3D town core so the comparison tests the same medium-settlement footprint class. Capture each method at the existing 40-degree camera pitch and zooms 800, 1200, 1600, 2000, 2400 and 3200. Terrain heights are queried only to ground the prototype; the NaturalWorld, camera, province geography and simulation remain unchanged.

**Consequence:** this is a scale and readability review artifact. It does not choose the final representation, establish a settlement system, add city content or authorize economy gameplay. Remove the instanced test scene and its two integration lines when the comparison is no longer needed.

---

## DEV-024 - Validated world-identity catalogue

**Date:** 2026-09-16
**Status:** Implemented

Install the locked world-identity master JSON byte-for-byte under
`data/world_identity/` and load it through a focused pure-data catalogue in the
simulation layer. Validate the identity data independently against both the
frozen starting ownership file and active province-geography IDs rather than
trusting embedded PASS metadata.

Keep identity definitions separate from mutable province/realm state and from
geography. Preserve optional/null religious fields, mixed-identity metadata,
formables, regional title rules and special-system metadata as data. Expose a
dedicated headless inspection command instead of adding player-facing UI for
this data-only milestone.

**Consequence:** Godot can query and inspect all 100 province identities and 43
starting realms with strict duplicate, missing-field, ownership, footprint,
summary and reference validation. Province 30 remains Western Carthen/Crowned
Communion inside R028, and R008 remains the unique `holy_state`. No modifiers,
formation behaviour, unrest, diplomacy, conversion, rebellions or special
systems are implemented.

---

## DEV-025 - Gameplay inspection binds canonical identity

**Date:** 2026-09-16
**Status:** Implemented

Treat geography, identity, political ownership and realm identity as separate
runtime responsibilities. `WorldGameplay` loads the validated
`WorldIdentityCatalogue` and builds selected-province inspection records from
geography facts, canonical province identity, canonical frozen starting realm,
and separately isolated prototype metrics.

Remove the old Free Province League, Hasenreich and Bunnyhausen political
fixtures from `PrototypeWorldState` and remove its fake realm IDs from
`ProvinceState`. The remaining Population, Food, Carrots and Development
values are explicitly temporary and displayed under `Prototype Metrics (not
canon)`.

**Consequence:** the player-visible debug panel cannot use Azgaar/proposal names
or mock realm identity. A gameplay integration test exercises all 100 active
provinces and 43 starting owners through the same controller/formatter path,
plus actual scene selection for Meyru and Keldren. No terrain, NaturalWorld,
topology, borders, frozen ownership, settlement visuals or gameplay systems are
changed.

---

## DEV-026 - Locked gameplay-state foundation and atomic publication

**Date:** 2026-09-17
**Status:** Implemented and verified

Implement the five core state boundaries from `design_authority/FCAH_Gameplay_State_Architecture_v1_LOCKED.txt`. The file was missing from the Git checkout but present under the exact requested name in the NaturalWorld working copy. Install that file byte-for-byte; its SHA-256 and source path are recorded in `gameplay_state/logic_foundation_pass1.md`. Keep implemented world identity and frozen geography/ownership authoritative. The current user task supersedes older simulation gates only for this foundation pass.

Rename the existing debug-only Province record to `PrototypeProvinceMetrics`; preserve its display behavior through type-only caller changes. Authoritative Province state now owns current owner/local identity/local Food and manpower. Realm owns capital/ruler/heir, official identity and Carrots/Faith. Character owns Dynasty/allegiance/family data. Dynasty membership/extinction and current ruling Dynasty are derived. One canonical JSON-tuple key identifies each persistent Relationship; all 43 starting Realms produce 903 pairs. No caches enter the save.

Use small typed records, a registry, focused lifecycle services, derived queries and a session publication boundary. Commands build a detached candidate, validate the whole reference graph, normalize integer wire values and publish once. Failed commands preserve state/revision. Reads are defensive snapshots; callers obtain a new query view after a command. Full copying is acceptable for this first 100-province foundation and avoids half-updated cross-object lifecycles.

Capital relocation uses sorted IDs as a deterministic fallback. Last-province NPC loss clears current political roles and retains identity/history; player loss additionally ends the campaign. Restoration reuses the retained Realm; rebels allocate fresh IDs excluding retained and retired identities. Formables preserve continuity. Succession changes Realm role fields only, and multi-Realm ruler death requires every successor explicitly in the same transaction. Parent links are canonical, children derived, partner writes reciprocal, and ancestry/cadet cycles invalid. Claims have one containing claimant and globally unique IDs. Perspective histories never drive current-state queries. WarState owns conflict activity; no Relationship war flag exists.

Canonical initialization requires explicit scenario ruler/House/capital/official-identity setup because no authored starting roster exists. The adapter copies frozen owners/local identity and validates a hash binding to the unchanged world authorities. Synthetic test roles are not installed as canon. Gameplay 001 keeps its current inspection workflow. Trade, expeditions, conditional crisis/rebellion/siege and military objects retain their documented future boundaries without catch-all placeholders.

Save schema 1 rejects unknown/missing fields, duplicate/retired IDs, invalid references and unsupported versions/world bindings. Validation precedes normalization: Godot JSON float parsing initially broke exact round trips and retired-ID membership; the fixed load/publication boundary normalizes only validated integers. Additional tests prevent claim target coercion, record/key mismatch, cyclic genealogy, duplicate claimant rights and stale roles. Disk save uses verified sibling-write/readback followed by rename; interrupted pending files are preserved.

World fingerprints normalize CRLF/LF in memory so identical content remains save-compatible across Git checkout platforms. The locked specification has an explicit LF attribute preserving its recorded source fingerprint; protected world data is unchanged.

**Verification:** All 20 direct suites pass, including four new campaign suites with 617 checks; JSON and actual file replacement round trips pass with inactive/deceased/extinct entities. The canonical fixture verifies 100 Provinces, 43 Realms, 903 pairs and all frozen owners. All 1,037 protected file hashes match task start. Existing user settlement edits are preserved and excluded from the milestone commit. Exact coverage and API limitations are in the pass report; economy/war/succession/diplomacy and other full subsystem simulation remain deferred.

---

## DEV-027 - Gameplay Political Map Mode v0.1

**Date:** 2026-09-17
**Status:** Implemented and verified

Use `ProvinceState.owner_realm_id` as the current political-color input. Gameplay 001 seeds initial ProvinceState ownership from validated frozen canon because the authored scenario roster needed for a full campaign session is not yet present; a supplied `CampaignSession` replaces that inspection source and its revision drives later presentation refreshes. Realm pigment assignment lives only in presentation: 30 curated colors are distributed deterministically using current geographic Realm adjacency and a local contrast optimization. No political color is written to canonical identity or save state.

Keep the accepted border mesh and NaturalWorld source untouched. A derived, single-channel Province ID raster selects the color in a gameplay-only variant of the existing terrain shader. Blend at 38%; restore the original shader and border palette exactly in Normal mode. The gameplay wrapper captures P before NaturalWorld's standalone props shortcut. This leaves a two-mode seam for future presentation views without creating a generic map-mode system.

**Verification:** The Gameplay 001 scene launched, P toggled both ways without changing natural-prop visibility, visual captures were reviewed at 800/1600/3600 and continent QA zoom, and all 21 direct tests passed. The weakest adjacent Realm color pair measures 0.0187 squared OKLab distance. `docs/world_map/political_map_mode_v0_1.md` records the mask build, shader seam and captures.

---

## DEV-028 - Political Realm-name labels

**Date:** 2026-09-17
**Status:** Implemented and verified

Add a presentation-only CanvasLayer to the existing Political mode. Name text comes from the current Realm's canonical display identity, including a live formable identity where present. Current `ProvinceState.owner_realm_id` groups Provinces into Realms; an owned Province interior point nearest the territory's area-weighted center supplies each anchor. Session revision refreshes both ownership grouping and labels. A Realm with no currently owned Province has no label.

Project anchors through the unchanged camera. At close gameplay zoom, the Realm under the camera center retains a label if its fixed anchor is offscreen. At continent zoom, full names wrap and move by small screen-space offsets to avoid text overlap; labels also avoid the existing gameplay inspection panel. Gameplay text uses light lettering and overview text uses dark lettering for terrain contrast. P disables the entire label layer in Normal mode. This adds no Province names, identity data, camera changes, gameplay state, or terrain/border edits. A generated Realm without an authored political identity currently falls back to its stable Realm ID because no canonical display name exists for it yet.

**Verification:** Running Gameplay 001 captures at zoom 800, 1600, 3600 and 30000 show names and accepted underlying map presentation. All 43 starting Realms are on-screen at overview with zero label-rectangle overlaps; P restores Normal and hides the layer. Focused tests cover authoritative names, single labels, live capture/formation and territorial anchors; all 21 direct suites pass.

---

## DEV-029 - Gameplay Culture Map Mode v0.1

**Date:** 2026-09-17
**Status:** Implemented and verified

Read culture from current `ProvinceState.local_culture`, never from Realm ownership or Realm primary culture. Canonical campaign bootstrap already seeds the field from the validated Province identity. Gameplay 001's standalone inspection records now seed that same field from canonical identity because no authored ruler/House/capital scenario exists; a bound campaign supplies current Province snapshots and revision refreshes. This adds no culture conversion or competing mutable culture table.

Use C, which has no gameplay/NaturalWorld conflict, for an exclusive Normal/Political/Culture mode seam. Culture uses its own instance of the accepted Province-mask tint presenter and 30-color adjacency assignment; the accepted Political presenter, palette code, shader strength and Realm labels remain unchanged. Culture keeps the Normal Province ribbon palette rather than carrying Realm colors across modes. The 18 starting cultures receive 18 distinct pigments, with current culture alone selecting each Province's texture entry.

Connected components in the accepted Province neighbor graph supply Culture-region labels. The 100 starting Provinces form 28 components; each label uses a component-owned Province interior anchor, so scattered cultures are named in each actual region. Text scales with the unchanged camera and avoids the existing inspection panel. Culture labels hide completely outside Culture mode.

**Verification:** Gameplay 001 launched; captures at zoom 800, 1600, 3600 and 30000 show terrain and borders under Culture tint. All 28 region labels are on-screen at overview without text/panel overlap. P/C transitions preserve natural props, restore Political Realm colors/names, and restore Normal's original shader and border palette. The culture test verifies current/canonical reads, exact color identity, 18 distinct colors, neighboring contrast and connected labels; all 22 direct suites pass. The nearest neighboring colors have 0.0237 squared OKLab distance before terrain blending. `docs/world_map/culture_map_mode_v0_1.md` records the authority limit and captures.
