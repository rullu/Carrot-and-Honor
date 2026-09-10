# Astra Province Data Pipeline

## Status and boundary

The first authoritative Godot-side province data layer is complete. It contains all 82 production provinces from the Azgaar Full JSON and does not render borders, labels, selection, ownership colours or UI. It does not modify Terrain3D, terrain assets, masks, rivers, materials or simulation rules.

## Authorities

- Source: `C:\Projects\FCAH_ASTRA_WORKSPACE\02_Azgaar_Master\FCAH_Azgaar_Master_01 Full 2026-08-07-21-09.json`
- Expected source SHA-256: `9c36b97b340c1fb5827b897db4f3798d16b017ce0e9906c26426ff295efaaa90`
- Alignment manifest: `C:\Projects\FCAH_ASTRA_WORKSPACE\08_Final_Terrain\EXPORT_MANIFEST.json`
- Generated Godot data: `data/world_map/astra_provinces.json`

The Full export includes invalid unpaired UTF-16 surrogate escapes in unrelated legacy name-base strings. The importer replaces only those invalid escapes in memory after verifying the complete source-file hash. Province definitions, cells, vertices and their numeric precision are not rewritten before conversion.

## Rebuilding

From PowerShell, run:

```powershell
godot --headless --path C:\Projects\For-Carrot-and-Honour --script res://tools/world_map/import_astra_provinces.gd -- '--source=C:\Projects\FCAH_ASTRA_WORKSPACE\02_Azgaar_Master\FCAH_Azgaar_Master_01 Full 2026-08-07-21-09.json' --manifest=C:\Projects\FCAH_ASTRA_WORKSPACE\08_Final_Terrain\EXPORT_MANIFEST.json --output=res://data/world_map/astra_provinces.json
```

The importer verifies the source hash, map fingerprint, 2560 x 1440 canvas, manifest formulas, leading scalar zero and IDs 1-82. It dissolves province cells by cancelling shared Voronoi edges, stitches the remaining edges into closed rings, classifies holes from source winding, and derives neighbors from cross-province cell adjacency. A second run produces byte-identical JSON; the validated artifact SHA-256 is `884f103f49a68da9116a9dbbd13e3403918c234ed38a8603f222f29390ab3d37`.

## Data contract

Every province record retains:

- integer `id`, `name` and `full_name`;
- closed `rings`, each with full-precision `source_points_xy`, converted `points_xz`, and an `is_hole` flag;
- Azgaar center-cell position as `selection_point_source_xy` and `selection_point_xz`;
- Azgaar pole as `label_point_source_xy` and `label_point_xz`;
- source and Godot X/Z bounding boxes;
- summed Azgaar exported cell area and polygon-derived Godot-unit area;
- sorted neighboring province IDs.

The file contains 82 provinces, 135 closed rings including 12 holes, and 8,081 closed-ring points. Source coordinates are retained alongside converted coordinates so later consumers can audit every point without reconstructing it from rounded display data.

## Coordinate contract

For each continuous Azgaar point `(x, y)`, the importer explicitly applies the established sample-centre path:

```text
sample_x = x * 1.6 - 0.5
sample_y = y * 1.6 - 0.5
X = -25000 + (sample_x + 0.5) * 12.20703125
Z = -14062.5 + (sample_y + 0.5) * 12.20703125
```

This is algebraically `X = (x - 1280) * 19.53125` and `Z = (y - 720) * 19.53125`. North is negative Z, south is positive Z, west is negative X and east is positive X. There is no flip, rotation, independent recentering or geometry nudge.

## Validation

Run:

```powershell
godot --headless --path C:\Projects\For-Carrot-and-Honour --script res://tests/astra_province_data_test.gd
```

The test checks exactly 82 unique IDs, complete ID coverage 1-82, closed geometry, point-by-point source-to-Godot conversion, playable-footprint bounds, stored bounding boxes, positive and reproducible polygon area, sorted valid symmetric neighbors, the fixed orientation and origin, and all eight manifest anchors.

## Exact next recommended step

Add a small pure-data runtime loader/query type for `astra_provinces.json`, with strict schema validation and immutable lookup by province ID. Keep rendering, hit testing, selection, labels, ownership colours and gameplay integration out of that next step.
