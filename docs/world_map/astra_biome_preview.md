# Astra Material-Weight Biome Preview

## Status and scope

The first useful Terrain3D material-colour preview is complete. It is a disposable visual inspection scene only. It does not alter the validated Terrain3D regions, the authoritative land-mask QA, province data, simulation or gameplay.

Open:

`res://scenes/world_map/astra_biome_preview.tscn`

Run it with **Run Current Scene** in Godot, or from PowerShell:

```powershell
godot --path C:\Projects\For-Carrot-and-Honour --scene res://scenes/world_map/astra_biome_preview.tscn
```

Controls:

- WASD or arrow keys: pan.
- Mouse wheel: zoom.
- `V`: switch between top-down and oblique inspection views.
- `F`: frame the whole map.

## Material source and crop

The unchanged project-local authority copy is:

`assets/world_map/astra/source/FCAH_Materials_RGBA.png`

- Full source: 4096 x 4096 RGBA8.
- Full source SHA-256: `7add3a96942e23a05957d4cbb37742eec868795765b4f8830c03ede41779a899`.
- Playable crop: exact rows `[896, 3200)`, all columns, 4096 x 2304 RGBA8.
- Playable crop path: `assets/world_map/astra/source/FCAH_Materials_Playable_4096x2304_RGBA.png`.
- Playable crop SHA-256: `261d787da02387142a02f83e11ef253e1a01bb6aaf91dba7b7edc0f960f75e68`.

Run `tools/world_map/crop_astra_material_mask.gd` headlessly to reproduce the crop. The tool verifies the full-source hash, dimensions and format, then compares the saved crop byte-for-byte with the in-memory crop.

The scene loads the PNG directly as raw RGBA8, generates linear mipmaps in memory and creates an `ImageTexture`. The shader has no `source_color` hint, so the four data channels are not treated as sRGB colour. The stored PNG remains unmipmapped and unchanged.

## Preview treatment

The shader interprets and normalizes the actual channel weights:

- R: muted temperate green;
- G: warm Mediterranean ochre/olive;
- B: sandy desert tan;
- A: neutral exposed-rock grey.

It uses the exact playable material sample to determine the footprint and filtered mip sampling for smooth channel blending. This avoids reducing the data to hard four-colour regions while keeping the coastline anchored to the source grid.

The preview retains the validated Terrain3D contract: 576 regions, region size 128, vertex spacing 12.20703125, terrain origin `(-25000, -14062.5)`, north at negative Z, and no flip, stretch, rotation, offset or recentering. The sea is a single opaque diagnostic plane 0.05 Godot units below authored sea level; it has no water effects.

## Validation evidence

GPU validation output is stored in:

`C:\Projects\FCAH_ASTRA_WORKSPACE\08_Final_Terrain\QA\Godot_Material_Preview_Validation`

- `astra_biome_whole_top_down.png`;
- `astra_biome_whole_oblique.png`;
- `astra_biome_northeast_mountain.png`;
- `astra_biome_east_desert.png`;
- `astra_biome_preview_validation_result.txt`.

Visual inspection confirms no horizontal striping, UV or crop offset, flip or stretching. The west reads broadly temperate, the south and southwest transition through Mediterranean/dry colours, the east reads broadly arid, exposed rock follows the intended mountain systems, and the coastline retains the validated framing.

`tests/astra_biome_preview_test.gd` independently verifies the exact crop payload, fixed hashes, representative channel values in the west, south, east and northeast, shader mapping constants, normalized blending, OpenGL Compatibility, scene ownership and all 576 Terrain3D regions.

## Limitations

This is a diagnostic colour preview, not final terrain art. It has flat channel colours, restrained lighting, generated mipmaps, no texture scale or surface detail, no normal or roughness maps, no altitude overlays such as snow, no shoreline treatment, and no polished water. It intentionally contains no vegetation, placed rocks, borders, labels, settlements, roads or gameplay.

The material-mask preview is technically trustworthy for channel interpretation, relative weights, crop, orientation and Terrain3D alignment. It is not a quality target for final PBR materials.
