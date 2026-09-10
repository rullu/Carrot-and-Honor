# Astra textured terrain-art preview

First surface-art direction, 2026-09-08. Terrain/geography, 576 region resources, source masks, provinces, simulation and previous QA scenes are unchanged. This is a separate human-inspection scene, not the main gameplay scene.

## Open and run

Open `res://scenes/world_map/astra_terrain_art_preview.tscn` in Godot 4.7.1 and press **F6 / Run Current Scene**. The material bindings initialize at runtime; judge the running scene, not the editor's idle viewport.

```powershell
& 'C:\Tools\Godot\CToolsGodotGodot_4.7.1\godot.exe' --path 'C:\Projects\For-Carrot-and-Honour' --scene res://scenes/world_map/astra_terrain_art_preview.tscn
```

WASD/arrows pan; mouse wheel zooms; V toggles top-down/oblique; F frames the complete world; H hides the inspection instructions. No province/gameplay input is present.

## Surface architecture

The existing Terrain3D vertex kernel and physical height range are retained. Only presentation resources change: scene-owned light/sea/camera, a custom surface shader and runtime-loaded textures. The controller clears Terrain3D diagnostics, binds the material and verifies the actual RenderingServer shader, not just a serialized override flag.

The exact playable material PNG is loaded as raw RGBA data with linear mipmaps. Its unfiltered level-zero sample defines the existing footprint; filtered normalized weights define the surface. Alpha means exposed rock, never transparency. There is no runtime crop offset or manual alignment adjustment.

| Astra channel | Chosen surface roles |
|---|---|
| R temperate | Grass001, sparse_grass, a small dirt share, aerial_grass_rock foothill transition |
| G Mediterranean/dry | withered_grass, sparse_grass, dirt_aerial_03 |
| B arid | sand_03, dirt_aerial_03, rock_05; slope and broad variation change their proportions |
| A exposed rock | aerial_rocks_02, warmer rock_05; restrained slope support supplements the mask |

All eight staged sets were inspected. Their original albedos were not accepted unchanged: pale dry grass is moderated, yellow/mossy rock is neutralized, and high-contrast photographic rock structure is subordinated to the actual ridges. No additional assets were downloaded or copied from the deferred library.

Two photographic scales use world-space X/Z with offset/rotation blending: meso tiles span 1.7–4.2 km of authored distance; deliberately enlarged close-detail motifs span 10–50 m. These are art-directed texture widths, not altered world scale. Derivative-based fades remove unresolvable detail and normal shimmer at strategic distance. Mixed sparse-ground close-ups remain deliberately soft, not a ground-level photorealism target.

`surface_context_rgba.png` is an aligned, reproducible presentation helper: R macro variety, G meso variety, B bounded signed relief, A local shelter. Relief comes from the existing float height crop; it only influences surface colour. It neither displaces vertices nor replaces the primary geographic mask. Extra lowland drainage contrast is restrained. The optional environment mask is not used.

## Texture handling and rebuilding

Original 2K PNGs stay untouched. BC1 albedo layers contain sRGB colour; shader sampling/linear grading/output encoding follows the tested Compatibility path. Mips average colour in linear light. BC3 layers contain linear NormalGL RGB and roughness A; mip normals are averaged as signed vectors then renormalized. No NormalDX inversion, AO multiplication, displacement, height blend or parallax is used. Anisotropic mip filtering is enabled; far roughness uses each source's smallest mip.

Derived packs are intentionally lossy GPU resources: 16-bit normal/roughness inputs are quantized to 8-bit before BC compression. Original high-precision PNGs are retained unchanged.

Derived resources total about 72 MiB on disk, including approximately 64 MiB of BC texture payloads. The runtime loads these arrays, not all 24 original PNG textures.

Rebuild only when sources or packing change. Python needs NumPy, SciPy, Pillow and OpenEXR (already available in the Astra workspace virtual environment). From the project directory:

```powershell
$terrainArtStage = 'C:\Projects\FCAH_ASTRA_WORKSPACE\07_Astra_Work\TerrainArt\packed'
& 'C:\Projects\FCAH_ASTRA_WORKSPACE\07_Astra_Work\.venv\Scripts\python.exe' tools/world_map/prepare_astra_art_support.py --output $terrainArtStage
Copy-Item -LiteralPath "$terrainArtStage\surface_context_rgba.png", "$terrainArtStage\texture_manifest.json" -Destination 'assets\world_map\terrain_materials\art_preview'
& 'C:\Tools\Godot\CToolsGodotGodot_4.7.1\godot.exe' --path . --script res://tools/world_map/build_astra_art_arrays.gd -- "--source-dir=$terrainArtStage"
```

Run the array builder with a normal GPU display, not `--headless`. It preserves compressed CPU Image resources behind Texture2DArray descriptors and verifies their payloads and loaded formats. Intermediate PNG/raw-mip files remain outside production.

## Validation and handoff

```powershell
godot --headless --path . --script res://tests/astra_terrain_art_assets_test.gd
godot --path . --scene res://scenes/world_map/astra_terrain_art_preview.tscn -- --validation-output=C:\Projects\FCAH_ASTRA_WORKSPACE\08_Final_Terrain\QA\Godot_Textured_Terrain_Validation\final
```

GPU validation captures eight views and records region count, physical heights, mask hash, active shader hash, compression, controls, renderer, frame-present timing and video memory. Optional `--motion-check` adds six zoom/pan views; `--benchmark` disables vsync only during the QA run. Optional `--view=east_desert` limits capture to one named preset. Do not capture headlessly: this Compatibility setup needs a normal GPU window for post-draw capture.

Full evidence and the ten handoff answers: `C:\Projects\FCAH_ASTRA_WORKSPACE\ASTRA_TERRAIN_ART_REPORT.md`. Final screenshots: `C:\Projects\FCAH_ASTRA_WORKSPACE\08_Final_Terrain\QA\Godot_Textured_Terrain_Validation\final`.

Known limitations: soft broad lowland variation and some softened mixed-ground microdetail; angular source drainage without its eventual water treatment; raster-stepped coastlines and a plain sea. Sun shadows are disabled in this isolated surface scene, so later objects need a separately coordinated shadow setup. No technical terrain-surface blocker remains for a later world-detail prototype after human acceptance of this first direction; that later work is not implemented or authorized by this document.
