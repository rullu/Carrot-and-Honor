# Logic Foundation Pass 1

Historical foundation report. The September 18 [campaign-start milestone](campaign_start_v1.md) supersedes the schema-1 names and missing-production-roster statements below. The original ownership/lifecycle boundaries remain in force.

Implemented against `docs/design_authority/FCAH_Gameplay_State_Architecture_v1_LOCKED.txt` on 2026-09-17. This is the core state and persistence foundation; it does not run the future gameplay simulation.

## Authority and repository reconciliation

Implementation began at `037e339d2cdc65948526c8157c9003c7a3f2d9e5`. Existing uncommitted settlement/prototype work was preserved and is excluded from the foundation milestone commit.

The specified locked document was absent from the Git checkout. The exact named file was found at `C:/Projects/FCAH_ASTRA_WORKSPACE/07_Astra_Work/NaturalWorld/project/docs/design_authority/` and copied byte-for-byte into this repository. Its SHA-256 is `81d431d0457ef4b29c59f0f91c01ec4c669f44f59aa0eed678c172ba1e3a2c3a`. The other working copy was not used as an implementation baseline. No Downloads documents, historical design archives or superseded terrain were imported.

The existing world-identity JSON, frozen ownership and 100-province geography remain authoritative. No identity data was invented, migrated or regenerated. The old debug-only `ProvinceState` was renamed to `PrototypeProvinceMetrics`; its callers received type-only changes. The production `ProvinceState` name now describes the authoritative campaign record. No old campaign saves existed to migrate; prototype metrics are never accepted as campaign saves.

## Ownership and representation

All records are typed GDScript `RefCounted` values. Simulation has no scene, UI, rendering or per-frame dependency.

| Fact | Authoritative record / derivation |
| --- | --- |
| Province geography and immutable heritage | `province_id` references the unchanged world catalogue and geography |
| Current owner, local culture/religion, primary hub, population/development, local Food/manpower | `ProvinceState` |
| Active lifecycle, original/current political identity, style/polity, capital, ruler, recognized heir, legitimacy/succession law, official identity, Carrots/Faith | `RealmState` |
| Personal identity, living/deceased lifecycle, Dynasty, allegiance, personal culture/religion/traits, parent/partner edges | `CharacterState` |
| House identity, historical origin and cadet-parent reference | `DynastyState` |
| One canonical Realm pair, directional attitude facets, agreement references, bilateral memories | `RelationshipState` |
| Character / Dynasty / Realm claims | One containing claimant record, using shared `ClaimRecord` values |
| Active conflict and opposing participants | Minimal `WarState` boundary stub |
| Territory, ruling Dynasty, Dynasty members/extinction, children, resource overviews, current wars | `CampaignQueries`, derived from the owning records |
| Terminal player defeat and retired-ID reservations | Campaign-level state |

The schema intentionally covers the foundation fields. Future local production, buildings, traditions, institutions, conditions and other detailed facets must be introduced with their own typed representation inside the locked owners. There is no generic extension bag to hide those systems in.

Province IDs retain their existing integer representation and are never array positions. Realm, Character, Dynasty, claim and war IDs are opaque case-sensitive strings. Relationship keys serialize a sorted two-ID JSON tuple, avoiding delimiter collisions. Empty strings represent absent optional text references; capital `0` means no capital on an inactive Realm. Positive Province IDs and exact integral quantities must fit the JSON exact-integer range. Inputs are validated before normalization, including claim target categories and duplicate numeric IDs.

Every known Realm pair has one relationship, including inactive historical pairs. All 43 starting Realms yield 903 records. Diplomatic activity is separately derived from active lifecycles and campaign outcome. Attitude channels currently provide independent `trust`, `respect`, `fear` and `grievance` integer slots; their numerical gameplay effects, ranges and balancing remain unauthored. Agreements are stable references only.

## Public API and mutation contract

`CampaignState` is a typed scenario/snapshot registry. Its record constructors and `from_data()` helpers are value-building plumbing, not live mutation APIs. `CampaignCodec.decode_data()` / `decode_json()` validate structure and references before building indexed state. Duplicate IDs are detected before dictionaries could overwrite a record.

`CampaignSession.create(state)` returns `{session, errors}`. The session retains its own independent state. Lookups (`get_province`, `get_realm`, `get_character`, `get_dynasty`, `get_relationship`, `get_war`) and `export_data()` return detached values. Editing a returned record does not edit the campaign. Underscore-prefixed internals are implementation-only, following GDScript conventions.

Explicit commands are `capture`, `restore`, `create_rebel`, `form`, `succeed`, `set_parents`, `link_partners`, `mark_deceased`, `set_allegiance`, `set_local_resources`, `set_attitude`, `add_claim`, `record_memory`, `register_war` and `end_war`. Commands return `{ok, errors, revision}`; rebel creation also returns `realm_id` on success. They are state primitives for future scheduled systems, not eligibility rules, AI or gameplay command handlers.

Each command copies the committed state, applies all proposed changes, validates the complete graph and normalizes numeric wire values, then publishes once. Failure preserves every prior record and the revision number. There is no signal, callback or asynchronous step exposing a half-applied candidate. This full-snapshot approach is deliberate for the current small world. Later optimization must preserve the publication contract.

`queries()` returns a consistent detached view of one committed revision. Obtain a new view after a successful command. Territory, Dynasty-member and child indexes can be cleared or rebuilt without changing truth. They are not serialized. Returned collections are defensive copies. Food/manpower are province-local; overview values cannot be spent as Realm wallets.

## Lifecycle choices within the locked architecture

- Capture immediately changes the Province owner. Surviving donors keep their capital if still owned; otherwise a deterministic sorted-ID tie-break selects a remaining Province. This is a neutral fallback, not capital-quality gameplay. Empty NPC Realms become inactive with capital/ruler/heir cleared, while retaining all identity, wallet, history and relationship records.
- Losing the player's last Province also sets `game_over`. The resulting inactive political record satisfies the capital/ruler invariants and can be saved. Further commands are rejected; restoration does not silently restart a defeated campaign.
- Restoration takes an existing inactive Realm ID, explicit land/capital/ruler/legitimacy, transfers all land in one transaction and repairs affected donors. Old history and relationships remain. Treaty/attitude recalculation belongs to a later diplomacy pass.
- New rebels receive fresh `realm_rebel_N` IDs, checking both retained records and retired reservations. The suffix is an allocation mechanism, never an assumption about existing IDs. The caller cannot impersonate an old Realm; failed transactions consume no identity. All diplomatic pairs are initialized.
- Formables change current political identity on the same Realm. Style changes only when explicitly supplied. Ruler, resources, original identity, local Province identity, history and relationships remain continuous. Formation eligibility is deferred.
- Succession replaces only the ruler/legitimacy/heir role fields on the Realm. It neither copies nor rewrites Character facts. Ruling Dynasty is always queried through the current ruler. Heir allegiance may be foreign or absent; the recognized-heir role is not inferred from allegiance.
- Death requires explicit simultaneous successors for every Realm currently ruled by that Character. It clears recognized-heir references to the deceased and retains the Character, claims and family history. Personal unions are representable; no unapproved single-rulership restriction was added. No resurrection or record-deletion API is provided.
- Parents are the only stored parent/child authority. Children are derived. Parent cycles, missing/self/duplicate parents and cadet-Dynasty cycles are rejected. Partner link/unlink writes both sides in one transaction and reciprocity is validated. Historical family edges survive death.
- Claims share a schema but have exactly one containing owner. Global duplicate claim IDs, retired IDs and invalid targets/provenance are rejected. Separate rights from one historical basis use different IDs and optional related-claim provenance. Relationships cannot own claims.
- Every memory belongs to one of the five perspectives. Shared event IDs are optional narrative references, not a new global EventState. No query or transition interprets a memory as current ownership, rulership or war truth.

## Canonical world setup

`CampaignBootstrap.from_world(realm_setups, character_setups, dynasty_setups, player_realm_id)` loads the existing validated catalogue. It copies frozen starting ownership into initial `ProvinceState.owner_realm_id`, creates local campaign identity from the canonical starting identity, and binds original/current starting Realm identity/style/type. Starting ownership thereafter remains a starting definition; current territory comes only from ProvinceState.

The caller must supply the missing capital/ruler/House scenario data and initial official Realm identity. Production canon currently has no authored starting character/capital roster. The adapter rejects incomplete setups rather than inventing one. Initial numeric fields default to zero as unbalanced foundation storage; no debug fixture economy is promoted into canon. Primary hub IDs identify one abstract hub per Province without selecting names, models, settlement size or placement.

The canonical-world test explicitly supplies synthetic role records for verification. Gameplay 001 continues displaying the established canonical starting inspection and labelled prototype metrics. Attaching a playable campaign and authoring its initial roles is a future integration/content task.

The save binds SHA-256 fingerprints of the existing world identity, frozen ownership, geography and correction manifest. Fingerprinting normalizes CRLF to LF in memory so Windows/Linux Git checkouts do not invalidate the same world; source files remain untouched. Load rejects incompatible authorities, missing canonical Provinces/Realms, reassigned original identity and lost geographic retirement reservations. Unbound synthetic scenarios use an empty fingerprint only for explicitly constructed scenarios/tests; `from_world` always binds the real world. The copied locked specification has an explicit LF Git attribute to preserve its recorded source hash on checkout.

## Save/load and validation

Schema version 1 persists authoritative records and references in deterministic ID order. Cache contents and presentation fixtures are absent. Unknown fields, missing fields, unsupported versions, duplicate IDs/pairs, unresolved references, cyclic graphs, invalid lifecycle roles and duplicate claim owners are rejected. A changed schema/world requires an explicit migration; no silent repair or renumbering occurs.

Godot JSON parses numbers as floats. The codec first checks exact integral values and category-specific types, then normalizes numeric fields, claim Province targets, retired Province IDs and attitude values to integers. A string containing digits is not accepted as a geographic claim target. Integral values supplied directly to live commands are normalized at publication too, so accepted state remains saveable.

`CampaignCodec.decode_json()` / `load_file()` return `{state, errors}` and never partially mutate a live session. `CampaignSession.save_file(path)` writes a sibling `.pending`, flushes it, loads and validates it, compares the full authoritative payload, and renames it over the destination. The old save remains if writing, readback or rename fails. An existing pending file is preserved for inspection. This guards incomplete writes; no claim is made about operating-system power-loss durability beyond the filesystem rename.

## Acceptance evidence

The Windows runner executes all 20 direct test suites: the 16 existing suites plus four new campaign suites. It uses fresh writable project logs, actual process waits, exit codes, PASS markers, script-error detection and per-process timeouts. Run Godot's editor scan first on a fresh checkout so global classes and imported resources are available.

```powershell
godot --headless --editor --path . --log-file .godot/editor_import.log --quit
powershell -NoProfile -ExecutionPolicy Bypass -File tools/testing/run_headless_tests.ps1
```

| Suite | Focus |
| --- | --- |
| `campaign_architecture_test.gd` | Sparse IDs; defensive reads; disposable caches; territory/resources; distinct allegiance/heir roles; family graph; claimant levels; directional relationships; perspective memories; WarState authority |
| `campaign_lifecycle_test.gd` | Atomic rejection; capital capture/relocation; NPC extinction; restoration; fresh rebels; formable continuity; succession; multi-Realm ruler death; terminal player defeat |
| `campaign_save_load_test.gd` | Exact JSON and filesystem round trips; historical entities/family/claims/war; numeric normalization; retired IDs; unknown/duplicate/malformed fields and references; interrupted write protection |
| `campaign_world_bootstrap_test.gd` | All 100 canonical Provinces, 43 Realms, 903 pairs; frozen starting ownership; mixed local identity; retired geography; explicit scenario requirements; world fingerprint; complete round trip |

The regression suites cover the existing capability/clock foundations, geography/coverage, world identity, Gameplay 001 inspection/scene composition and terrain assets. No rendering behavior changed, so this milestone does not add a new visual direction review.

## Protected work and recovery

Pre-task backups of the existing modified files, their binary Git diff and hashes for 1,037 tracked protected asset/data/scene/presentation/addon files were recorded at `C:/Projects/fcah_logic_pass1_recovery/`. The final comparison verifies those protected bytes against task start. Original settlement work remains in the working tree, outside the milestone commit. No terrain, topology, ownership, world-identity, settlement asset or camera change is required by this pass.

If resuming interrupted work, inspect `git status`, this document, DEV-026 and `.godot/test_logs/`; keep the initial settlement diff separate. The next subsystem should consume the session/query interfaces and add only its own locked state categories.

## Deliberately deferred

No economy production/consumption, resource balancing, war eligibility/resolution, military movement, battles, succession selection, diplomacy AI/reaction propagation, religion conversion, construction, trade, rebellions, expeditions, parchment events or AI personalities are implemented. The minimal war registry proves the authority boundary only; an inactive participant does not automatically end a WarState before war rules exist.

Trade routes and expeditions must become separate typed registries; military/Marshal/Army/Formation location must remain in the military subsystem. Treasury crises belong to their dedicated conditional state, and Rebellion/Siege state remains Province-local. No speculative placeholder buckets or duplicated flags were added. Institutions, traditions, strategic buildings and detailed Province/Realm facets remain inside their locked owner boundaries when those passes are authorized.
