# Province Economy Foundation / Campaign-Start Generation v1

## Authority and starting baseline

Implemented under the September 19 user task against clean integrated main `4b1f36eb03a792a15e2705aa8ed8147c3073bd20`. The pre-change baseline passed all 24 direct suites. Both registered worktrees and local/remote branch heads were inspected; there was no pre-existing modified/untracked work in main. A SHA-256 manifest of all 1,386 tracked files and baseline test logs is retained at `C:/Projects/fcah_economy_verification_2026-09-19/`.

Binding design: `docs/design_authority/FCAH_Province_Economy_Production_Discovery_v1_FINAL_SEALED_IMPLEMENTATION_AUTHORITY_2026-09-19.txt`, copied byte-for-byte from Downloads after verifying SHA-256:

`556c38e250deac9fde1dd61831336256875d0470246a96d29fd45c78ffb5b799`

The newest cumulative implementation record was Downloads `FCAH_Changelog_2026-09-18.txt`, SHA-256 `3e31ec75ac0e5b2019f23c7c08689e63fd1b6aed37815ce46120b65207c67a68`. Its internal September 18 seal, final main commit, explicit supersession of the unmerged-branch note and subsequent human approval establish its precedence over the older cumulative records. It is preserved as the unchanged prefix of `FCAH_Changelog_Cumulative_2026-09-19.txt`, with this milestone appended. Repository historical logs and Downloads originals are unchanged. Windows modification times were not used to select authority.

The sealed file governs this economy subsystem; the locked gameplay-state architecture owns entity/lifecycle boundaries; world identity, geography, ownership and the cast authority remain locked. The older Province/Economy reference was not needed to supply an unspecified implementation rule. No older workbook value supplies missing tuning.

## Implemented boundaries

| Component | Responsibility |
| --- | --- |
| `EconomyCatalogue` / `EconomyDefinition` | Typed content identity: 26 opportunities, 32 countryside functions, 37 strategic families; exact 13-type normal Day-1 pool |
| `EconomyConfig` | Strict configuration with explicit versions/status, global weights, hiding, soft penalty/tags, Powerhouse IDs, mandatory starts, suitability bindings and slot capacity |
| `EconomyWorld` | Fixed canonical Province IDs/adjacency and explicit suitable coast/aquatic bindings; no geography mutation or random geography |
| `ProvinceEconomy` | Province-owned opportunities, positive Realm knowledge, countryside instances and strategic instances |
| `EconomyInstance` | Physical identity, lifecycle, source of creation and immutable creation culture/religion/Realm; catalogue decides site versus city placement |
| `EconomyProvenance` | Campaign-level generator/content/config versions, content/config hashes and exact validated configuration snapshot |
| `EconomyGenerator` | Detached deterministic candidate generation, ownership-blind repair and independent RNG domains |
| `EconomySchema` | Permanent strict wire/schema/reference/physical-state validation |
| `EconomyStartValidator` | Day-1 floors, hidden cap, canonical identity, prerequisites, authored starts, exact building roll and random-start restrictions |
| `EconomyLifecycle` | Atomic construction-completion/disruption/recovery primitives through `CampaignSession`; no costs, timers or production effects |

There is no second economy registry, rural slot grid, per-good stockpile, staffing state, output arithmetic, worker allocator, trade scope or discovery event engine. Background access is catalogue classification, not a repeated Province boolean table. Ordinary timber/stone/metalwork never become resource prerequisites for basic civilization. The direct dependency graph excludes the old prototype capability classes.

## Configuration deliberately remains incomplete

`data/economy/campaign_economy_v1.json` has status `incomplete` and explicit null authoring fields. The canonical full-campaign API refuses it with diagnostics. Tests use `tests/support/economy_fixture.gd`, whose status remains `fixture` in generated saves and inspector output. Fixture weights, probabilities, tags, Realm lists, suitability and authored examples are not canon.

Required unresolved inputs:

- all 26 global rarity weights;
- hidden chance in basis points;
- rare-opportunity IDs and soft anti-clustering penalty;
- explicit Powerhouse Realm IDs;
- mandatory countryside and city starts (an explicitly approved empty list is representable);
- suitable coast/aquatic bindings for all 100 Provinces.

The last item is an implementation finding: existing geometry supplies exact IDs, rings and adjacency, but no validated gameplay definition of *suitable* Harbour/Fishery access. The foundation consumes an explicit binding instead of guessing from visuals, legacy labels or an arbitrary shoreline threshold. These bindings are configuration/content facts tied to the world fingerprint, not generated geography. Other fixed physical facts remain in their existing authorities and are not duplicated into Province economy state.

The sealed prototype capacity is supplied as **10**; 8/10/12 are tested. There is no permanent eight-slot or ten-slot architectural rule. Configuration must accommodate the sealed max-three starting buildings. The count tables and 4% site roll are version-1 generator tuning, not lore. Changing generation logic or sealed tuning requires a relevant generator/domain/config version bump. Integer weights accept 0..1,000,000 with at least three positive entries; this technical bound keeps unbiased draws within the existing 32-bit sampler. Hiding accepts 0..10,000 basis points; a soft penalty must be below 10,000.

Authored records have an exact schema: Province ID, mechanical type ID, optional local opportunity/site alternatives and a coastal requirement. Normal content prerequisites are still enforced. Source-sensitive specialist starts also require their local source; no imported-goods shortcut is added. An authored exploitation site needs a real generated source. If absent, the candidate fails explicitly; the generator neither creates a convenient resource nor retries until authoring happens to fit. Non-resource rural content is outside this catalogue and cannot suppress its site roll. Seravelle has no default Cathedral exception.

## Public APIs and migration

```gdscript
# Complete explicit EconomyConfig, labelled fixture or approved content:
var result: Dictionary = CampaignBootstrap.new_campaign(seed, days_per_year, player_id, config)
if result["state"] == null:
    # Report result["errors"]; no candidate was published.
    return
var session: CampaignSession = CampaignSession.create(result["state"])["session"]
```

- `new_campaign(seed, days_per_year, player_id = "", economy_config = null)` creates cast plus economy. With no config it loads the incomplete canonical template and refuses generation. Player selection does not enter economy streams.
- `new_cast_campaign(seed, days_per_year, player_id = "")` preserves the prior cast-only behavior explicitly. `from_generated()` and `from_world()` remain lower-level scenario/cast boundaries. Their null economy means **uninitialized**, not zero resources.
- `EconomyGenerator.generate(cast_state, config)` validates input, builds a detached candidate, validates the complete start and returns `{state, errors, raw_opportunity_counts}`. The raw counts are diagnostic only; repairs may legitimately increase them. Failure returns no partial state. Already-initialized economy cannot be regenerated.
- `CampaignSession.transition_economy_instance(province_id, instance_id, next_state)` validates transitions before publication. Supported lifecycle: under construction -> active -> disrupted -> recovering -> active; recovering can be disrupted again. There is no manual suspension or deletion shortcut. Establishment, costs and timing remain later systems.

**Save schema 3** adds nullable `ProvinceState.economy` and `CampaignState.economy_generation`. All nested records/configuration have exact validated fields; unknown/missing fields, bad types, duplicate IDs/functions, unknown content, invalid Realm references, invalid provenance and mixed initialized/uninitialized worlds fail before typed reconstruction/publication.

Normal loading does not silently accept schema 2. `CampaignCodec.migrate_v2(parsed_data)` is the explicit migration: validate the old exact shape, retain its cast/state, add null economy, then validate schema 3. It never generates resources or buildings. Callers can inspect and explicitly save the migrated result through the existing atomic codec. A migrated historical campaign does not retroactively acquire a Day-1 economy through load.

Cast generator version remains **1**, with its unchanged golden digest. Economy generator/content versions begin at **1**; the four domain versions and config version are persisted independently. Content/config fingerprints are checked on load. Actual accepted state is serialized; neither validation nor load invokes generation.

## Deterministic generation decisions

The existing SHA-256 counter sampler is reused without changing cast code. Separate keys include opaque campaign seed, canonical world fingerprint, economy generator version, domain, domain version, purpose and Province ID. Domains are opportunities, hiding, sites and buildings. Count, type, traversal, repair and identity purposes are also separated. Full configuration is fingerprinted in provenance, **not** mixed into every random stream, which would couple unrelated tuning changes.

1. Each Province independently rolls the sealed 20/45/30/5 count table. Province traversal for type selection is deterministically shuffled. Distinct types are selected by global weights only.
2. Tagged opportunities receive a multiplicative configured penalty for already-selected adjacent occurrences. Positive weights retain at least weight one, so nearby rare pairs remain possible. There is no geographic rarity modifier or hard distance exclusion.
3. World-floor repair prefers an available position, avoids nearby tagged occurrences where possible, and otherwise replaces a common/nonessential unprotected type. Deterministic shuffled order breaks ties. It preserves other floors, authored site sources that exist, max three and uniqueness. Impossible repair fails.
4. All generated opportunities initially belong to their owner's positive knowledge. Authored exploitation sources are excluded from hidden eligibility. Hiding rolls once per nonempty Province, then selects equally among eligible types while preserving visible floors. At most one Day-1 opportunity becomes owner-unknown.
5. Authored sites are validated/created and suppress only resource-site RNG. Otherwise an independent 4% roll chooses an eligible source family equally, then a function within that family equally. Fertile Land gets one family ticket, not six. No family means no site and no compensation.
6. Strategic count rolls Normal or configured Powerhouse odds, with no capital bonus. Mandatory starts consume the rolled maximum up to three. Remaining types are drawn equally without replacement from the filtered 13-type pool. Insufficient content fails. Coast is sufficient for ordinary Harbour; Mill needs visible local grain basis. Sites and buildings start active/base, without any claim of staffing or output.

Physical instance IDs are opaque hashes from a separate identity purpose using seed/world/domain/version/Province/counter, never display names or culture. Building origin identity is the persisted tuple of mechanical type, creation culture, full religion record and origin Realm. It does not reskin on conquest or subsequent identity change; no new art/name grammar is invented.

The `EconomyWorld` cache holds only disposable fixed ID/neighbor/starting-identity metadata. Callers receive copies. Permanent campaign validation still verifies actual world fingerprints on load/publication; the cache neither owns gameplay truth nor bypasses that gate.

## Knowledge and later gameplay

Positive opportunity knowledge is an array of persistent Realm references on the Province-owned opportunity. Owner visibility is derived by membership. No global `known` flag is used. The eventual negative-survey records, ever-discovered passive bonus and survey commitments remain deferred; this foundation does not implement that runtime.

Existing capture/restoration/rebel land grants preserve physical records and reveal each physical site's source to the actual new owner. Existing knowledge remains with former Realms; undeveloped knowledge is not copied to the conqueror. Sites retain disruption/recovery state. Buildings retain origin variants. Later culture/religion change does not rewrite the creation tuple.

Day-1 rules remain separate: permanent validation permits later buildings up to configured strategic capacity, historical identity changes and multiple owner-unknown opportunities after conquest. It does not impose starting floor/count/random-pool rules on campaign history. Physical sites must retain a valid source and make it owner-known; ordinary lifecycle transitions never remove opportunities.

## Legacy audit

`GoodDefinition` hard-codes Province-local capability scope, `BuildingDefinition` supplies old placement categories, `PrototypeContentCatalogue` contains a rural Mill and the five-good bread proof, and `ProvinceCapabilityState` derives capability availability from those assumptions. These remain historical proof APIs and their regressions continue to pass. They are not reused as campaign economy authority: doing so would introduce deferred finished-good scope, rural Mill and implicit production rules. The useful existing primitives are instead `StateSchema`, campaign typed records/codec/session, fixed-world binding and the deterministic counter sampler.

The new catalogue/transcription checks explicitly exclude Stone, ordinary wood, Fish, animal products and deferred/overseas goods from the tracked opportunity pool; retain Fishery; place Mill in the city; preserve separate Barracks/Archery Grounds/Stables; and treat slash labels as single mechanical families. No old labour allocator, universal import prerequisite, hidden craft knowledge, rural capacity or per-Realm Imperial building quota enters the implementation.

## Verification and developer commands

```powershell
node tools/economy/check_economy_content.js
node tools/campaign/build_campaign_start_data.js --check
powershell -NoProfile -ExecutionPolicy Bypass -File tools/testing/run_headless_tests.ps1 -TimeoutSeconds 1200
godot --headless --editor --path . --import --log-file .godot/economy_import.log

# Focused test writes this explicitly labelled fixture configuration:
godot --headless --path . --script res://tools/economy/inspect_economy.gd -- --seed=economy-inspection --days-per-year=365 --config=res://.godot/test_logs/economy_fixture.json --save=res://.godot/economy_inspection.json

# Existing cast-only developer workflow remains explicit:
godot --headless --path . --script res://tools/campaign/inspect_campaign_start.gd -- --cast-only --seed=example --days-per-year=365 --player=R028
```

Focused coverage includes configuration/schema rejection, complete replay, independent domains, player/cast/geography/Powerhouse/capital isolation, 8/10/12 capacity, all-full repair, zero-weight essential repair under 100% hiding, authored source visibility/suppression, max-three mandatory buildings, absent-source failure, family-first statistical sampling, strict file/JSON round trips, explicit migration, atomic failure, conquest/damage/variant persistence and later-state permissiveness.

Economy stress uses `economy-v1-stress/0..999`, rotating capacity 8/10/12 and fixture hiding 0/2700/10000 basis points. It replays every complete economy, checks every Province independently and samples full-state JSON/domain changes every 25 seeds. A fixed valid cast is reused as a fixture to isolate economy variation; the separate cast stress suite still generates/replays 1,000 complete casts. Frequency checks have broad statistical tolerances and do not force generated quotas.

Economy golden digest: `5aba598b8eab515bf1986e9d5556398ddd5dfc2b4ef6152e3728104273a639a2` for the explicit focused fixture. Cast golden digest remains `7b025d69d906c30e3c427cd45df3108584a5f46f5cafbe912437ae62cb14317c`.

## Final verification (2026-09-20)

All **26/26 direct repository suites pass**, including Political, Culture, world-gameplay-scene, gameplay-identity, bootstrap, save/load and all historical capability proofs. Machine-readable results and log hashes are in [province_economy_v1_verification.json](province_economy_v1_verification.json). Raw baseline/final logs remain in the external verification directory named above.

| Check | Result |
| --- | --- |
| Focused economy | 347 checks; golden digest stable |
| Economy stress | 1,000 distinct worlds, every world replayed; 877,128 checks; 731,632 ms |
| Raw opportunity counts 0/1/2/3 | 20,050 / 44,988 / 29,930 / 5,032 across 100,000 Provinces |
| Normal building counts 0/1/2/3 | 38,145 / 37,928 / 14,222 / 4,705 across 95,000 Provinces |
| Powerhouse building counts 0/1/2/3 | 1,023 / 2,021 / 1,444 / 512 across 5,000 Provinces |
| Site rolls / actual eligible sites | 3,968 successful 4% rolls / 3,159 sites; no compensation for ineligible rolls |
| Hidden opportunities | 33,457 across the mixed hiding fixtures |
| Minimum essential counts | Fertile Land true 5 / visible 4; Iron true 2 / visible 1 |
| Existing cast focused/stress | 308 focused; 393,729 checks across 1,000 distinct casts; original golden unchanged |
| Cast retry distribution | 979 first attempts, 20 second attempts, 1 third attempt; unchanged |
| Strict existing save/load | 90 checks, plus economy JSON/file/migration/conquest round trips |
| Economy transcription | Exact 26 opportunities, 32 sites, 37 strategic families and 13 Day-1 types |
| Naming transcription | Exact 230 given names, 194 lineages and 43 Seats |
| Full bootstrap/atomic-save inspection | Explicit fixture; 100 Provinces, 86 buildings, 3 sites; schema 3 |
| Editor/import | Exit 0, no parser/script errors; only pre-existing Terrain3D `instance_reset_physics_interpolation()` deprecation |
| Diff/preservation | `git diff --check` passes; 1,367 of 1,386 pre-existing tracked files byte-identical; remaining 19 are the reviewed integration/code/test/docs edits |

Implementation/retest findings: strict JSON handling required validated integer normalization consistent with the existing codec; typed parsing was checked through Godot runs. The existing save test's old assertion that schema 3 was unsupported was migrated to reject schema 2 and the next future version, preserving strictness. Review strengthened exact building-count validation, protected authored site sources during floor replacement and cached disposable fixed-world metadata to avoid repeated geometry parsing in stress runs. Final focused and full stress results above include these fixes; no hard rule or assertion was weakened. The preliminary stress run was deliberately stopped at 200 seeds for those fixes and replaced by the complete clean 1,000-seed run.

All locked terrain/NaturalWorld, geography, ownership, Seats, canonical identity, presentation and cast source/data remain byte-identical. There was no pre-existing dirty work to relocate. Two incidental editor-generated import sidecars for old political reference images were hash-checked and preserved outside the repository; no unrelated material is committed. Downloads originals and the copied sealed authority still match their supplied/recorded hashes; the historical cumulative-log prefix remains byte-exact.

Delivery follows normal main history without rebase or force push. The implementation commit's exact identity is recorded in the completion entry after committing; the final documentation commit is identified by Git history. `campaign-start-v1` remains at `c45f8080a9b0cd375c0495371689e8d06e7e48ba` locally, remotely and in its clean reference worktree.

## Deferred boundary

Canonical tuning/start authoring/suitability bindings must be approved before a production full-economy campaign can be created. Final slot count, Seravelle's possible Cathedral, construction costs/timers, discovery runtime, per-good scope/production, workforce, trade, AI, institutions/traditions, building/military effects and presentation remain deferred. This is the sealed foundation milestone; no post-implementation advisory redesign is included.
