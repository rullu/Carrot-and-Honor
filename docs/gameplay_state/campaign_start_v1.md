# Campaign start v1

Implemented from the FINAL SEALED September 18 authority, with explicit user implementation authorization. It extends the state foundation at `43a5438cdee9232031be24e7cc1108db38c5ad61` without changing geography, ownership, canonical identity, terrain, Realm relationships or war generation.

## Authority and workspace

**Integration update (September 18):** The original presentation work is now preserved in `1dbe757febcefaf871293c6d30129363223a65e1` and combined with generator commit `c45f8080a9b0cd375c0495371689e8d06e7e48ba` on `main`. The three Political fixture edits below are applied. The branch/overlay account in this section describes the original delivery; do not apply the patch again. See [repository integration](repository_integration_2026-09-18.md) for current combined verification and cleanup.

The Git checkout lacked the newest sealed document and cumulative handover. Both were copied byte-for-byte from `C:/Projects/FCAH_ASTRA_WORKSPACE/07_Astra_Work/NaturalWorld/project/docs/design_authority/`:

- `FCAH_Campaign_Start_Procedural_Cast_Naming_Generator_v1_FINAL_SEALED_2026-09-18.txt`, SHA-256 `22531721a6d7089310dce4c53b657b5b8e66802600b20d28caedb5e230b41ec2`.
- `FCAH_Changelog_2026-09-17 (1).txt`, SHA-256 `8a51dbbbcb2f8fd88ca1d2f59f7e2b51710f4832ae5e2774d7541f84f9cb215e`.

The handover identifies the existing Political/Culture/settlement changes as uncommitted work. Delivery uses branch `campaign-start-v1` in `C:/Projects/fcah_campaign_start_v1`, preserving the original dirty checkout. No Downloads copy or old naming draft supplies data. No design contradiction was found.

Compatibility with that pending presentation work was tested in a temporary copy: Political, Culture, gameplay-scene and canonical-inspection suites all passed. The uncommitted Political test needs three fixture edits for schema 2; the exact tested migration is [political_fixture_schema_v2.patch](political_fixture_schema_v2.patch). When combining that pending work with this branch, run `git apply docs/gameplay_state/political_fixture_schema_v2.patch`. `git apply --check` passed against the original checkout. No presentation behavior or test assertions change. The original checkout remains untouched, and none of its unrelated assets/experiments are included in this commit.

Pre-implementation risks addressed: signed pre-start ticks; integer normalization after JSON parsing; missing/duplicate IDs before indexing; one-sided partner references; dead spouse identity; unrepresented collateral relationships; gender-neutral succession and same-tick heir ties; hidden player-choice/RNG/dictionary-order dependencies; lineage exhaustion; Day-1 constraints leaking into later history; implicit culture-to-religion assumptions; unsupported calendar decisions.

## Public entry points

```gdscript
var result: Dictionary = CampaignBootstrap.new_campaign("opaque seed", 365, "R028")
if result["state"] == null:
    # Surface result["errors"]; never continue with a partial campaign.
    return
var session: CampaignSession = CampaignSession.create(result["state"])["session"]
```

365 is a caller-supplied example, not canon. Production creation requires a nonempty string seed and positive integer year length. Whitespace/Unicode in the seed is preserved. Player Realm selection is applied after generation and does not enter its stream. The result also reports attempt count and rejection diagnostics.

For inspection/testing, `CampaignStartGenerator.generate(seed, days_per_year, version=1, attempt_limit=64)` returns `{cast, errors, attempts, rejections}`. A cast contains only provenance/world binding and typed Realm/Character/Dynasty setup arrays. `generate_attempt()` exposes a raw diagnostic candidate and must not be treated as validated output. `CampaignBootstrap.from_generated(cast, player)` revalidates hard rules and soft sanity before consuming a candidate. The original lower-level `from_world()` remains available for explicit scenarios and tests; its signature now requires `campaign_seed, generator_version, days_per_year` before the optional player argument.

```text
Generator -> CampaignStartValidator (hard + separate soft pass)
          -> CampaignBootstrap.from_world -> CampaignValidator/Codec
          -> CampaignSession
```

The generator does not create Provinces, borders, ownership, diplomatic pairs or wars. The existing bootstrap still copies the fixed world and creates its 903 neutral relationship records. The start adapter copies canonical primary culture and the complete religion record from each sealed fixed Seat. R028 uses P16 while P30 retains its Carthen identity. Seravelle keeps `elected_office` and an empty recognized heir even when its office-holder has children.

## State and time

Schema 2 replaces Character `display_name` with `given_name`, and Dynasty `house_name` with `lineage_name`. It adds Character `sex`/signed `birth_tick`, Dynasty `lineage_style`, and campaign `campaign_seed`/`generator_version`/`days_per_year`. Strict serialization rejects missing, unknown, mistyped and obsolete fields. Schema 1 is rejected; there are no production saves requiring migration.

`CharacterState.age_years(current_tick, days_per_year)` uses exact integer division. A living character's current tick comes from `SimulationClock.get_elapsed_daily_ticks()`. Campaign start is tick 0. The clock's existing independently exportable state remains authoritative for elapsed time; this milestone adds no duplicate campaign clock or month/year calendar. Callers continuing time after restoration must restore their clock as before. Deceased birth ticks are retained; an age calculated at current tick is not an age at death.

The generator accepts year lengths 1..16,777,216, a conservative technical bound keeping all birthday sampling inside its unbiased 32-bit draw range. This is not a lore/calendar bound. Save schema integers retain the existing exact JSON integer envelope. No age, children list, marital-status flag, lineage-parent flag or ruling-Dynasty cache is serialized.

## Determinism and tuning decisions

The SHA-256 counter stream hashes a canonical JSON tuple of the opaque seed, version, existing world fingerprint, configured year length, sorted naming/Seat data and attempt index. It uses rejection sampling to avoid modulo bias. Generated IDs use a separate counter/hash domain with 128-bit opaque suffixes, independent of mutable identity labels. Realm iteration is sorted; table order is the sealed source order. The golden full-cast hash in the focused test detects accidental changes across processes/engine upgrades. Any generation-affecting logic, table, ordering or tuning change requires a generator-version bump.

The exact sealed ruler age bands (10/32/45/13), male/female roll (80/20), marital weights (35/55/9/1), conditional children (42/26/18/9/4/1), siblings (35%), living parent (20%) and collateral branch (5%) are implemented. For rulers below 25, marital weights are 43/55/2/0; this reduces early widowhood and excludes early remarriage. These are versioned tuning choices, not immutable lore or per-world quotas.

Spouse ages are uniformly within ruler age ±8, clipped to 18..85. Canonical footprint identity pairs are deduplicated, with weight 5 for ruler culture and 1 otherwise. Religion always travels with its explicit canonical record. Children choose a recorded spouse parent, have exact tick gaps of at least 16 years from both parents, and inherit the reigning ruler's lineage and personal identity irrespective of sex. Birth ticks are sampled across the feasible interval, so repeated birthdays are legal. Oldest means earliest birth tick; exact ties use the smallest opaque Character ID. No ruler children are deceased. Unmarried rulers have no spouse record and no children.

Optional relatives are deliberately bounded: at most one sibling, one known lineage parent and one aunt/uncle with one cousin. Parent sex is unbiased. A living-parent roll only succeeds when the ruler's age permits a living parent at or below 85. A deceased known parent is otherwise emitted only when required to connect siblings/collateral family. The collateral branch requires one deceased grandparent to encode the actual aunt/uncle relationship; grandparents have no independent roll. Unknown second-parent links make no assertion of illegitimacy and avoid decorative dead genealogy. Ruler children always have both actual, partnered parents. This v1 implementation uses the permitted single known lineage parent; unrelated second-parent lineages remain a future optional extension.

Widows have one actual deceased spouse even when childless. Remarried rulers have one deceased and one living spouse, with reciprocal historical edges and separate birth lineages. At start all generated relatives retain the ruler's Realm affiliation, and every character connects to its Realm ruler through actual family links.

## Naming and validation

`data/campaign/campaign_start_v1.json` is transcribed from the sealed authority by the Node developer tool. It contains 230 regional given-name entries (repeats across pools are intentional), all 194 expanded lineage entries and all 43 Seat mappings. The tool checks table counts, duplicates and affinity tags; `--check` performs an exact comparison without writing. No names are synthesized.

Ordinary affinity weights are Primary 5 / Shared 3 / Rare 1. Given-name selection uses the global unisex soft overlay on 8% of draws. Natural soft names have weight 3 and conspicuous names weight 1. Overlay strings are excluded from ordinary regional sampling, preventing double counting. Repeated given names are legal. Unrelated lineage names are reserved globally per attempt, with weighted selection without replacement. Exhaustion rejects the attempt; no suffixes, relaxed rules or cross-Realm lineage reuse are introduced.

Presentation styles are Western/Central house, Mediterranean family, Northern lineage, Kharven clan, and Eastern ruling dynasty/supporting house. Name text is never used as an entity ID. Territorial names and public titles are not added to given names or used to infer identity.

Hard validation checks exact canonical setup, distinct adult living rulers, identity handoff, age bounds/gaps, family references/ancestry, reciprocal partners, spouse states, actual legitimate ruler children, correct oldest-child heirs, Seravelle, opaque IDs, regional names/styles, unique unrelated lineages, no cadet parents, family affiliation/connectivity and neutral deferred fields. It reuses the permanent family graph validation and validates exact record schemas before accessing references. The complete permanent validator runs after bootstrap as well.

Soft sanity separately rejects only the sealed broad pathologies: male rulers outside 25..40; young >10; old >12; childless outside 18..34; large families >8; remarried >3. It reads existing facts, with no stability score or quotas. Retries reset the entire candidate/lineage reservation set, follow deterministic attempt indices, and stop after at most 64 attempts. Failure returns no cast and explicit reasons. Permanent validation adds only schema requirements and the two-actual-parent structural limit; it still permits foreign marriages, personal unions, child succession, later identity changes and cadet branches.

## Verification

Commands after Godot's normal project scan:

```powershell
node tools/campaign/build_campaign_start_data.js --check
powershell -NoProfile -ExecutionPolicy Bypass -File tools/testing/run_headless_tests.ps1 -TimeoutSeconds 600
godot --headless --path . --script res://tools/campaign/inspect_campaign_start.gd -- --seed=example --days-per-year=365 --player=R028 --save=res://.godot/example_campaign.json
```

The stress suite uses seeds `sealed-v1-stress/0` through `/999`, rotating year lengths 1, 360, 365 and 400. It repeats every accepted candidate, replays the complete retry sequence every tenth seed, and performs canonical bootstrap/strict JSON round trips every 101st seed. Independent checks verify oldest-child inheritance, exact age gaps, reciprocal affiliation, bloodline and uniqueness. A separate real soft-failure seed (`retry-21`) proves bounded failure and successful retry; deliberately exhausted pools prove bounded hard failure.

Initial stress result: all 1,000 worlds accepted, 1,000 unique full-cast hashes, 393,729 assertions, 144,416 characters and 70,990 lineages. Attempt histogram: 979 first-attempt worlds, 20 second-attempt worlds, one third-attempt world. Maximum lineage usage: Western 24/38, Mediterranean 19/34, Northern 9/25, Central 18/38, Kharven 7/25, Eastern 15/34. No pool exhaustion or nondeterminism. There were 3,849 deceased spouses, 7,939 female recognized heirs, 26,378 empty hereditary-heir roles and 41,970 repeated given-name occurrences. Observed male count ranged 25..40 and childless count 18..34, demonstrating varied accepted worlds.

Final verification: **22/22 direct suites pass**, including **308 focused campaign-start checks** and **393,729 stress checks**. The four additional compatibility runs above pass with the pending presentation overlay. The developer inspection command creates and atomically saves an example 148-character/73-lineage campaign. All naming tables match the sealed source. Final editor import and warnings-as-errors parse checks of the new tests/tool are clean. The unchanged Terrain3D biome test emits its existing `instance_reset_physics_interpolation()` deprecation warning; milestone scripts add no warnings. Machine-readable evidence is in [campaign_start_v1_verification.json](campaign_start_v1_verification.json).

Fresh Windows worktree testing exposed a pre-existing checkout issue: Git converted the two geographically hashed JSON authorities and the hash-locked NaturalWorld scene/controller to CRLF, making existing preservation regressions reject their byte hashes. Their accepted source bytes were restored unchanged, and LF attributes now preserve those existing checksums on future checkouts. Neither locked content nor the preservation tests were changed. Sandbox-only Godot certificate/settings errors are avoided by the final verification run with normal Windows access.

## Deferred boundaries

No final calendar/month names, death tick, age at death, bastardy/adoption/disputed parentage, regency, collateral succession, election mechanics, political stability, traits/abilities, claims, generated history, economy, patronymic grammar, epithets or regnal-number UI are introduced. Gameplay 001's presentation remains outside this milestone. The production API produces a valid campaign/session; a player-facing campaign-selection flow belongs to a later UI task.
