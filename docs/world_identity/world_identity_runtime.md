# World Identity Runtime

The locked world-identity canon is installed as pure data at
`data/world_identity/world_identity_master_canon.json`. The repository copy is
byte-identical to the accepted implementation input:

- SHA-256: `a05c067bdde05322e2f60372c6e2a75364befef3d13c97e03a3ba81cab08de93`
- schema: 100 provinces, 43 starting realms, 19 currently defined formables

`WorldIdentityCatalogue` loads this file and independently checks it against
both frozen political ownership and the active province-geography ID set. It
does not trust the master file's embedded validation report as proof.

## Runtime ownership

- `src/simulation/world_identity_catalogue.gd` owns loading, validation and
  defensive read queries.
- `data/politics/starting_realm_ownership_v1.json` remains the authority for
  frozen starting political ownership.
- `data/world_map/astra_provinces.json` remains the authority for active
  province IDs and geometry.
- The identity master owns province and realm identity, names, styles,
  religious fields, mixed-identity metadata, formable metadata and
  special-system metadata.

The catalogue validates unique counts and IDs, required fields and types,
province-owner agreement, exact realm footprints, realm summary fields,
formable references, title guardrails, Hasenmark/R028, and Seravelle's unique
`holy_state` type. Queries return defensive copies. No identity field produces
a modifier or gameplay effect in this milestone.

## Headless validation and inspection

Run the targeted test:

```powershell
godot --headless --path . --script res://tests/world_identity_catalogue_test.gd
```

Run the default human-readable inspection (the five canonical province samples
and R008, R028, R030 and R043):

```powershell
godot --headless --path . --script res://tools/world_identity/inspect_world_identity.gd
```

Target one record or print the complete catalogue:

```powershell
godot --headless --path . --script res://tools/world_identity/inspect_world_identity.gd -- --province=30
godot --headless --path . --script res://tools/world_identity/inspect_world_identity.gd -- --realm=R028
godot --headless --path . --script res://tools/world_identity/inspect_world_identity.gd -- --all
```

On the current Windows installation `godot.exe` is a GUI-subsystem executable.
Automated shells that need a trustworthy exit code should wait for that process
explicitly; interactive PowerShell and Godot's own editor remain unaffected.

## Deliberately deferred

This layer stores formables and Central/Eastern special-system metadata but
does not execute it. Modifiers, unrest, diplomacy, conversion, rebellion,
formable execution, Wellspring Summons, Deep Wells emergence, Imperial
restoration and realm auto-promotion/renaming remain outside this milestone.
