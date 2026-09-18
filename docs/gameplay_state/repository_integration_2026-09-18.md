# Repository integration — September 18, 2026

## Result and history

Main combines the accepted Political/Culture inspection modes and settlement prototype with the completed campaign-start v1 implementation. This is repository integration, not a redesign. The generator, schema 2, world authority and accepted presentation runtime are preserved.

| History | Exact commit |
| --- | --- |
| Starting main and origin/main | `43a5438cdee9232031be24e7cc1108db38c5ad61` |
| Accepted presentation working-tree snapshot | `1dbe757febcefaf871293c6d30129363223a65e1` |
| Campaign-start source branch | `c45f8080a9b0cd375c0495371689e8d06e7e48ba` |
| Verified two-parent integration merge | `a4a49034c315d1d34e820ffffda03d825997d414` |

The merge retains both source parents. This completion entry is a documentation-only follow-up to that verified merge; the tested runtime and assets are unchanged. `campaign-start-v1` remains available locally/remotely at its original commit, with its clean worktree at `C:/Projects/fcah_campaign_start_v1`. Main remains in `C:/Projects/For-Carrot-and-Honour`. Push uses the ordinary fast-forward update of origin/main; no force push or branch deletion.

## Starting inventory and preservation

The two worktrees were the only registered worktrees. Branches and actual remote heads matched the expected commits above. The campaign worktree was clean; main had eight modified tracked files and 602 untracked files reported by Git. There were no staged changes.

Modified tracked files:

- `README.md`, `docs/code_map.md`, `docs/decision_log.md`, `docs/implementation_plan.md`, `docs/project_index.md`;
- `scenes/gameplay/world_gameplay.tscn`, `src/gameplay/world_gameplay.gd`, `tests/world_gameplay_scene_test.gd`.

Accepted untracked work: 112 files comprising nine assets/imports, 78 map documentation/QA files, one settlement scene, ten presentation scripts/UIDs, four test files/UIDs and ten map tools/UIDs. Together with the eight modified files these form the unaltered presentation snapshot. The [verification inventory](repository_integration_2026-09-18_verification.json) lists all 120 paths and original SHA-256 values.

Provenance was established from the actual source/diffs, DEV-023 and DEV-027..029, map-mode reports, settlement asset references and the September 17 sealed handover. That handover explicitly accepts the Political/Culture internal tools and the current `the_victim.png` settlement prototype. The older comparison assets and QA remain part of that accepted work and are preserved.

The remaining 490 Git-visible untracked files were the isolated `experiments/world_map_terrain_3d_proof/` tree (489) and `for_carrot_and_honour_godot_terrain_proof_01.zip`. The experiment's own README/summary identifies it as a separate, non-production terrain feasibility proof. Neither is included in main. They were moved without deletion to:

`C:/Projects/fcah_integration_recovery_2026-09-18/excluded/`

All **935 files / 731,046,632 bytes**, including ignored experiment caches, were hashed before and after the move. The recovery root also holds byte-exact backups of the 120 accepted files, the initial tracked diff/status/untracked inventory, the archive manifest and the 1,210-file original tracked baseline manifest. No dirty-file provenance remained ambiguous.

## Merge and integration decisions

1. Verify the original presentation snapshot with all 22 existing suites, then commit it separately before merging.
2. Merge the campaign-start branch with `--no-ff --no-commit`, retaining logical history.
3. Resolve only two textual conflicts: README's suite command/count and adjacent milestone sections in `implementation_plan.md`. Preserve all presentation sections and the campaign-start section. Automatically merged documentation was inspected as well.
4. Reproduce the delivered Political fixture patch: `house_name` to `lineage_name`, character `display_name` to `given_name`, and explicit `"political-fixture", 1, 365` bootstrap provenance/configuration before `"R028"`. No assertions change. The patch remains as historical delivery evidence and must not be applied again.
5. Update current documentation to acknowledge generated roster availability while retaining Gameplay 001's existing inspection/session-binding workflow. Record the accepted 2D/2.5D settlement direction and current scale above the historical comparison notes.
6. Include 27 Godot import sidecars newly produced for the accepted Province mask and Political/Culture QA images. Two incidental imports for old `docs/politics/` reference images are moved into the recovery folder; those reference files are unchanged.

The first automated conflict-resolution command was rejected by automatic approval review because its README handling appeared capable of discarding accepted documentation. It did not run. The exact conflict blocks were instead resolved with explicit reviewed edits preserving all presentation content. No user approval or design change was required.

Git's normal text normalization is retained; byte-exact originals are in the backup. An initial staging check exposed CRLF text staged without normalization; it was corrected before the snapshot commit without editing working-file contents. Existing campaign-branch LF attributes preserve the locked world hashes. No new world attributes or content changes are introduced by integration.

## Verification

Run from the main checkout after Godot's import scan:

```powershell
node tools/campaign/build_campaign_start_data.js --check
powershell -NoProfile -ExecutionPolicy Bypass -File tools/testing/run_headless_tests.ps1 -TimeoutSeconds 600
godot --headless --editor --path . --import --log-file .godot/integration_editor.log
godot --headless --path . --script res://tools/campaign/inspect_campaign_start.gd -- --seed=example --days-per-year=365 --player=R028 --save=res://.godot/integration_example_campaign.json
git diff --check
git lfs fsck
```

Results:

- **24/24 direct suites PASS**; exact suite names and log hashes are in the verification JSON. Political, Culture, world-gameplay-scene and gameplay-identity compatibility all pass in the actual merged checkout.
- **308 focused campaign-start checks PASS**, including schema rejection, strict JSON/bootstrap/session round trips, player-selection independence, permanent-versus-Day-1 validation and bounded hard/soft retry failures.
- **1,000 stress seeds / 393,729 checks PASS**, years 1/360/365/400; 1,000 unique casts, 144,416 Characters, 70,990 Dynasties. Attempt histogram remains **979 first / 20 second / 1 third**. No failures, pool exhaustion or nondeterminism. Peak lineage use remains Western 24, Mediterranean 19, Northern 9, Central 18, Kharven 7, Eastern 15.
- Golden digest unchanged: `7b025d69d906c30e3c427cd45df3108584a5f46f5cafbe912437ae62cb14317c`. Real soft retry seed `retry-21` still succeeds on attempt 2.
- Naming transcription PASS: **230 given-name entries / 194 lineage entries / all affinities / 43 Seats** match the sealed authority.
- Production bootstrap/atomic save PASS: `example`, 365 days/year, player R028 produces **148 Characters / 73 lineages / 903 pairs**. The codec verifies saved-state readback before replacement. Existing save/load and world-bootstrap suites also pass.
- Godot 4.7.1 editor/import exits 0 with no parser/script errors. The sole warning is the pre-existing Terrain3D `instance_reset_physics_interpolation()` deprecation, also present in the unchanged biome suite. No new warnings.
- Git LFS integrity and diff whitespace checks PASS.

## Complete-diff and preservation review

The combined changes were compared against both parents and the starting baseline. Simulation code, campaign naming data, generator tests and tools are identical to `c45f808`; presentation source/scenes/assets/map tools and existing presentation assertions are identical to `1dbe757`, except for the documented three-line Political fixture migration and new import sidecars. Documentation changes retain both histories and reconcile current status.

Of the 1,210 initially unchanged tracked files, exactly 13 change through the already accepted campaign commit; the other **1,197 remain byte-identical**. These include all locked terrain, NaturalWorld, province geometry, correction manifest, ownership and world-identity data. Of 120 accepted dirty files, 111 remain byte-identical; the remaining nine are eight documentation files and the migrated Political fixture. No accepted runtime or artwork is silently altered. The external excluded archive also remains hash-identical.

## Deferred work

No new gameplay or visual polishing is included. The accepted inspection tools retain their known label/legend limitations. Production settlement artwork, Faith view, player-facing campaign selection and the generator milestone's deferred gameplay systems remain separate tasks. Historical sealed design and changelog files remain unchanged.
