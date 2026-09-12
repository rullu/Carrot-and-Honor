# Astra atmospheric natural world — 10 September 2026

Open **`res://scenes/world_map/astra_natural_world_final.tscn`** in Godot **4.7.1** and press **F6**. Review the running scene: materials, water, clouds and botanical batches initialize at runtime. The panel identifies the **ATMOSPHERIC NATURAL WORLD** revision.

```powershell
& 'C:\Tools\Godot\CToolsGodotGodot_4.7.1\godot.exe' --path 'C:\Projects\For-Carrot-and-Honour' --scene res://scenes/world_map/astra_natural_world_final.tscn
```

The terrain/natural-world phase is complete under DEV-020. The next task is gameplay. This atmospheric finish supersedes DEV-019's conservative artistic handoff while retaining the accepted foundation. The concise handoff is `C:\Projects\FCAH_ASTRA_WORKSPACE\ASTRA_FINAL_BEAUTY_HANDOFF.md`. Current evidence is in `08_Final_Terrain/QA/Natural_Beauty/` in that workspace; the complete previous project and its SHA-256 inventory are in `06_Astra_Checkpoints/Natural_Beauty_2026-09-09/`. Previous reports remain historical.

## Visible result

The active water implementation has been replaced. An original directional Fourier spectrum supplies traveling ocean wave structure, reflected sky/sun light and changing highlights. Darker offshore water meets variable translucent-looking shallows and broken, locally exposed surf. Selected submerged rocks produce visible bow foam and eddies. River surface gradients and light travel along the unchanged authored routes; lake motion is calmer. The existing source bed depth, standing-water levels and connected water coverage remain the geometry authority.

Shore appearance uses a separately smoothed distance field plus damp, gravel, vegetation and rock context. This removes the repeated pale outline from unsuitable river/rock edges while retaining sandy coasts. Three selected arid water surroundings receive irregular wet/green ground and stone context, using the existing sparse vegetation. The best prior waterside compositions remain. Rock transforms broaden and bury selected source silhouettes, 178 isolated stones are omitted, and 29 bed-anchored coastal rocks form six local compositions. There are **38,468** composed instances; existing vegetation positions remain unchanged.

Actual visible clouds use three original finite density volumes with lit tops and cooler undersides. Sparse cloud groups move at 3 / 1.2 world units per second above the map. Their corresponding sunlight projection shades terrain, vegetation, rocks and water. Close-view opacity keeps small features readable. Proxy clip-depth handling prevents clouds being sliced by the closest camera's near plane.

The fixed sun is **(-52°, -145°, 0°)**, with warm direct light and cool ambient fill. Improved canopy value response avoids inky woodland masses. Ground materials provide clearer meadow/forest/rock hierarchy; source-slope shading gives major ranges stronger mass and ridge relief. Fine mountain normal strength is reduced to prevent dark flecks. Very light distance haze supports depth; there is no grading overlay, bloom or motion blur. Terrain self-shadow casting remains disabled because the accepted Terrain3D skip-transform path produces acne; physical height-derived normals and prop shadows remain active.

## Camera and controls

Use an orthographic camera, north toward screen top, **40° below horizontal**, vertical size **1,600 default / 800 closest / 3,600 farthest**. Eventual player zoom limits remain open. This is the strategic camera envelope, not a character-scale environment. Extreme development zooms are separate.

| Control | Action |
| --- | --- |
| WASD/arrows or middle drag | Pan |
| Wheel | Gameplay zoom |
| Shift + wheel | Development range |
| Home | Restore western default and gameplay limits |
| F / V | Frame continent / switch top-down |
| 1–9 / 0 | Regions / seven existing discoveries |
| P / H | Toggle natural props / inspection controls |

This controller is an inspection helper. Province selection, ownership, roads, settlements, armies and gameplay UI remain unimplemented.

## Preservation boundary

All **576 Terrain3D regions and 12 authoritative exports** are hash-verified. Heights/topology, material and Features masks, strategic river routes, water/bank vertices, original vegetation composition, continent crop, orientation and scale are unchanged. The Terrain3D vertex kernel is byte-identical to the checkpoint. The later DEV-022 province correction changes political geography data only and is validated separately. Origin X/Z `(-25000,-14062.5)`, spacing `12.20703125`, north `-Z`, one unit = ten authored metres, height range `-6 .. 216.9871`.

| Resource | Ownership |
| --- | --- |
| `shore_distance.exr`, `water_features_rgba.png`, `water_optics_rgba.png` | Frozen accepted coverage, source depth and flow tangent |
| `inland_water_vertices.bin`, `bank_vertices.bin` | Frozen source-water surface and narrow closure geometry |
| `surface_context_rgba.png`, `ecology_rgba.png`, `landscape_character_rgba.png` | Frozen relief/ecology/character derivatives inside source biome identity |
| `natural_instances.json`, `natural_districts.json` | Frozen accepted placements, districts and discoveries |
| `river_motion_rgba.png`, `shore_details.json` | Retained route-progress field and previous sparse waterside details |
| `shore_finish_rgba.png` | Current presentation-only damp/gravel/vegetation/rock context |
| `water_edge_style.exr` | Smoothed appearance distance; never used to cut new geography |
| `beauty_composition.json` | Rock omissions, proportions, burial, 29 additions and associated reactions |
| `atmosphere/` | Original wave spectrum, finite cloud densities, placements and corresponding shadow texture |
| `beauty_manifest.json` | Current resource hashes and provenance |

Source river paths and some small lake contours are deliberately angular. Their geometry is preserved; material transitions and local composition improve how they read. Decorative cutouts, props and atmosphere must never become gameplay geography.

## Assets and performance

No new third-party game assets were added. The cloud volumes, spectrum, shadows, shader work and bounded composition are original project resources. The official [Knights of Honor II gallery](https://knightsofhonor2.thqnordic.com/) was studied as a readability/water reference outside the project; none of its artwork is included.

The selected **26-model Quaternius CC0 library** retains its author license and per-file hashes in `assets/world_map/nature_library/quaternius/`. Existing AmbientCG/Poly Haven terrain sources retain their records in [terrain_material_inventory.md](terrain_material_inventory.md). Source models, textures and terrain arrays remain unchanged.

Compatibility rendering, 4× MSAA, card-preserving botanical LODs and spatial MultiMeshes remain. The wave resource occupies about 64 MiB on the GPU; cloud resources are shared across sparse instances. The candidate measured about **64 FPS normal / 60 closest / 53 farthest** at 1600×900 on the RTX 3060 Laptop, compared with about 60/58/50 in the fresh baseline. Final installed measurements and p95 timings are in the handoff. These are frame-present measurements with vsync off, not GPU-only timings or a shipping specification. Engine-reported video memory increased by about 117 MiB. No display refresh or frame-pacing behavior was changed.

Forward+ contact-shading prototypes were rejected for worse canopy rendering and approximately 33–40 FPS in wooded views. Repetitive sine waves, rectangular cloud wisps, regular rock rows, inverted steep-coast blends and excessive fine mountain shading were also rejected during rendered iteration.

## Review and rebuild

Review includes 108 regional/site cameras in the 800–3,600 envelope, matching pre-change comparisons, all major-region pans and focused water/cloud motion. Visual inspection uses actual engine stills and sampled motion frames. The recordings remain available for direct playback. The installed contract verifies source hashes, material arrays, active shader and navigation controls; province/material regression tests also pass.

Normal installation uses the reviewed resources. **Do not rerun the historical accepted-world or DEV-019 generators during gameplay work.** They are retained for reproducibility and would replace current presentation derivatives. The new standalone builders are `prepare_astra_clouds.py`, `prepare_astra_ocean.py` and `prepare_astra_beauty_context.py`. The context builder requires the pre-beauty checkpoint and checks source hashes before writing its three presentation outputs. Reimport resources in Godot after a deliberate rebuild; do not reimport authoritative terrain or province data.

```powershell
& 'C:\Projects\FCAH_ASTRA_WORKSPACE\07_Astra_Work\.venv\Scripts\python.exe' tools/world_map/verify_astra_beauty.py --workspace C:/Projects/FCAH_ASTRA_WORKSPACE --project C:/Projects/For-Carrot-and-Honour --output C:/Projects/FCAH_ASTRA_WORKSPACE/08_Final_Terrain/QA/Natural_Beauty/recheck_preservation.json
& 'C:\Tools\Godot\CToolsGodotGodot_4.7.1\godot.exe' --path . --script res://tools/world_map/capture_astra_art_review.gd --resolution 1600x900 -- --out=C:/Projects/FCAH_ASTRA_WORKSPACE/08_Final_Terrain/QA/Natural_Beauty/recheck --views=res://tools/world_map/astra_beauty_review_views.json
```

Run the final scene with `-- --validation-output=<directory> --benchmark --view=west_temperate` for terrain/material/input checks. Use `capture_astra_production_motion.gd` with `--fixed-fps 30` and `-- --out=<frames directory> --views=res://tools/world_map/astra_beauty_motion_shots.json` for focused motion, or `astra_production_motion_shots.json` for the 21-region tour. Video encoding is a QA-only dependency.

Water and clouds are efficient authored presentation effects, not physical fluids or dynamic weather. Their finite variations and loops are appropriate to the strategic camera. The next work is gameplay/province interaction on this preserved foundation; no additional terrain pass is scheduled.
