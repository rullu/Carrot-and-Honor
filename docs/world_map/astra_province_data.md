# Astra Province Data Pipeline

## Status and boundary

The accepted corrected province layer is authoritative and has completed final human visual review. It contains 100 active provinces with stable, non-contiguous IDs. Province geography remains independent of Realm ownership. The pipeline does not modify Terrain3D, heightmaps, masks, rivers, lakes, coastline, NaturalWorld or camera behaviour.

## Authorities

- Source: `C:\Projects\FCAH_ASTRA_WORKSPACE\02_Azgaar_Master\FCAH_Azgaar_Master_01 Full 2026-08-07-21-09.json`
- Expected source SHA-256: `9c36b97b340c1fb5827b897db4f3798d16b017ce0e9906c26426ff295efaaa90`
- Alignment manifest: `C:\Projects\FCAH_ASTRA_WORKSPACE\08_Final_Terrain\EXPORT_MANIFEST.json`
- Accepted land mask: `C:\Projects\FCAH_ASTRA_WORKSPACE\08_Final_Terrain\Data\FCAH_Features_RGBA.png`
- Correction authority: `data/world_map/astra_province_corrections.json`
- Generated Godot data: `data/world_map/astra_provinces.json`
- Generated coverage evidence: `data/world_map/astra_province_coverage_report.json`

The Azgaar export remains untouched. `build_astra_province_corrections.py` turns approved high-level decisions into explicit cell assignments. The Full export includes invalid unpaired UTF-16 surrogate escapes in unrelated legacy name-base strings; the importer replaces only those invalid escapes in memory after verifying the complete source-file hash.

## Stable ID policy

IDs are opaque identifiers, not array positions or counts. IDs 8, 31, 57, 63, 68, 81 and 82 are permanently retired. IDs 83-107 were allocated above the historical maximum, including the accepted targeted topology IDs 90-107. The active count is 100 and the next permitted new ID is 108. Retired IDs must never be reused or appear in active records, neighbors, source-cell ownership or prototype state.

## Rebuilding

From PowerShell, first build the correction manifest:

```powershell
C:\Projects\FCAH_ASTRA_WORKSPACE\07_Astra_Work\.venv\Scripts\python.exe tools/world_map/build_astra_province_corrections.py --source "C:\Projects\FCAH_ASTRA_WORKSPACE\02_Azgaar_Master\FCAH_Azgaar_Master_01 Full 2026-08-07-21-09.json" --output data/world_map/astra_province_corrections.json
```

Then generate runtime geography:

```powershell
godot --headless --path . --script res://tools/world_map/import_astra_provinces.gd -- --source="C:\Projects\FCAH_ASTRA_WORKSPACE\02_Azgaar_Master\FCAH_Azgaar_Master_01 Full 2026-08-07-21-09.json" --manifest="C:\Projects\FCAH_ASTRA_WORKSPACE\08_Final_Terrain\EXPORT_MANIFEST.json" --corrections=res://data/world_map/astra_province_corrections.json --output=res://data/world_map/astra_provinces.json
```

The importer verifies all source fingerprints, applies merges, explicit cell reassignments and inland-water ownership, dissolves cells by cancelling shared Voronoi edges, stitches closed rings, and recalculates bounds, areas, neighbors and anchors. Repeated builder/importer runs must produce byte-identical files.

## Data contract

Every province record retains:

- integer `id`, `name` and `full_name`;
- closed `rings`, each with full-precision `source_points_xy`, converted `points_xz`, and an `is_hole` flag;
- Azgaar center-cell position as `selection_point_source_xy` and `selection_point_xz`;
- Azgaar pole as `label_point_source_xy` and `label_point_xz`;
- source and Godot X/Z bounding boxes;
- summed Azgaar exported cell area and polygon-derived Godot-unit area;
- sorted neighboring province IDs.

The file contains 100 active provinces and no political holes. Runtime metadata records the correction-manifest hash, exact active and retired ID sets and historical maximum. Source coordinates remain alongside converted coordinates so later consumers can audit every point without reconstructing it from rounded display data.

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
godot --headless --path C:\Projects\For-Carrot-and-Honour --script res://tests/astra_province_coverage_test.gd
godot --headless --path C:\Projects\For-Carrot-and-Honour --script res://tests/province_geography_query_test.gd
```

The tests check the exact stable active/retired ID sets, closed geometry, point-by-point conversion, bounds, area, symmetric neighbors, valid anchors, all politically filled inland lakes and current coverage-report hashes.

Run `validate_astra_province_geography.py` with the authorities above to regenerate `astra_province_coverage_report.json` and the two QA maps under `docs/world_map/qa/`. It checks source-cell ownership, accepted-mask coverage, positive-area overlap, political holes, external sea assignment, anchors, neighbors and retired IDs. The current result is zero raw and meaningful unassigned playable-land pixels, zero overlap pairs and zero political holes.

## Exact next recommended step

The project owner completed human scalpel review of the corrected province shapes, numbered QA overview and dual-sided political borders on 2026-09-12. This accepted layer is the authoritative 100-province baseline.
