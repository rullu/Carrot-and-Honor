# Astra terrain material inventory

Audit date: 2026-09-07

## Outcome

The prior terrain-material source chain is intact. Eleven 2K source packages were found in Downloads, preserved byte-for-byte in the art workspace, and extracted there into curated map folders. Four sets were used successfully by the previous Godot `final_materials_proof_02`: `Grass001`, `sparse_grass`, `aerial_grass_rock`, and `aerial_rocks_02`.

For the first production Terrain3D texture pass, eight sets are staged under `res://assets/world_map/terrain_materials/`. Only albedo/diffuse, OpenGL normal, and roughness maps were copied. The 24 production files total 354,302,070 bytes (337.89 MiB), and every copy is SHA-256-identical to its curated source.

No terrain, Terrain3D data, shader, mask, biome preview, province data, scene, or simulation file was changed by this audit.

## Source locations and provenance

- Download packages: `C:\Users\beman\Downloads\<archive>.zip`
- Preserved package copies: `C:\Projects\For-Carrot-and-Honour-Art\WorldMap\Experiments\Gaea_WorldMap_01\01_References\Terrain_Materials_01\00_Original_Packages\<archive>.zip`
- Extracted curated 2K maps: `C:\Projects\For-Carrot-and-Honour-Art\WorldMap\Experiments\Gaea_WorldMap_01\01_References\Terrain_Materials_01\02_Selected_2K_Maps\<set>\`
- Previous proof copies: `C:\Projects\For-Carrot-and-Honour-Art\WorldMap\Experiments\Gaea_WorldMap_01\05_Godot_Material_Prototype\assets\materials\final_materials_proof_02\`
- Production copies: `C:\Projects\For-Carrot-and-Honour\assets\world_map\terrain_materials\<set>\`

The art-workspace source record identifies `Grass001` as AmbientCG and the other ten sets as Poly Haven. Its licence review records all eleven as CC0. No network retrieval was performed in this audit.

Before this audit, none of the named texture sets existed in the production project.

## Complete candidate inventory

All selected maps below are 2048 x 2048. Diffuse/albedo, OpenGL normal, roughness, and AO are PNG. Displacement is 16-bit PNG for `Grass001` and EXR for the other sets. `sparse_grass` and `rocky_terrain_02` additionally have a dedicated PNG mask. Every set has all five core map roles; no expected map is missing.

The preserved ZIPs also contain delivery alternates such as NormalDX, packed ARM, PNG displacement alternates, EXR data alternates, previews, MaterialX, and, for AmbientCG, Blender/USD/Terrain3D metadata. Those alternates were inventoried but are intentionally not production copies.

| Set | Exact package | Form found | Curated maps available | ZIP / extracted size | Audit decision |
|---|---|---|---|---:|---|
| `Grass001` | `Grass001_2K-PNG.zip` | Download ZIP, identical archived ZIP, extracted maps, proof 02 copy | Color, NormalGL, Roughness, Displacement, AO (PNG) | 68.86 / 44.18 MiB | Select: clean lush temperate base; technically proven |
| `sparse_grass` | `sparse_grass_2k.zip` | Download ZIP, identical archived ZIP, extracted maps, proof 01/02 copies | Diffuse, NormalGL, Roughness, Displacement, AO, mask | 102.85 / 65.26 MiB | Select: less-uniform temperate variation; technically proven |
| `withered_grass` | `withered_grass_2k.zip` | Download ZIP, identical archived ZIP, extracted maps | Diffuse, NormalGL, Roughness, Displacement, AO | 163.08 / 68.91 MiB | Select: strongest dry-grass read; pale albedo needs restrained blending |
| `aerial_grass_rock` | `aerial_grass_rock_2k.zip` | Download ZIP, identical archived ZIP, extracted maps, proof 01/02 copies | Diffuse, NormalGL, Roughness, Displacement, AO | 139.79 / 66.98 MiB | Select: grass/upland transition; technically proven |
| `rocky_terrain_02` | `rocky_terrain_02_2k.zip` | Download ZIP, identical archived ZIP, extracted maps | Diffuse, NormalGL, Roughness, Displacement, AO, mask | 127.03 / 67.36 MiB | Defer: useful green rocky field, but overlaps the chosen transition and rock pair |
| `aerial_rocks_02` | `aerial_rocks_02_2k.zip` | Download ZIP, identical archived ZIP, extracted maps, proof 01/02 copies | Diffuse, NormalGL, Roughness, Displacement, AO | 54.23 / 21.50 MiB | Select: distinctive large exposed mountain rock; technically proven |
| `rock_05` | `rock_05_2k.zip` | Download ZIP, identical archived ZIP, extracted maps | Diffuse, NormalGL, Roughness, Displacement, AO | 99.13 / 28.17 MiB | Select: warmer, finer dry/bare rock complement |
| `aerial_ground_rock` | `aerial_ground_rock_2k.zip` | Download ZIP, identical archived ZIP, extracted maps | Diffuse, NormalGL, Roughness, Displacement, AO | 171.04 / 65.49 MiB | Defer: credible neutral mixed ground, but less role-distinct than dirt plus rock |
| `dirt_aerial_03` | `dirt_aerial_03_2k.zip` | Download ZIP, identical archived ZIP, extracted maps | Diffuse, NormalGL, Roughness, Displacement, AO | 120.65 / 57.96 MiB | Select: subdued dry soil shared by Mediterranean and arid transitions |
| `sand_03` | `sand_03_2k.zip` | Download ZIP, identical archived ZIP, extracted maps | Diffuse, NormalGL, Roughness, Displacement, AO | 129.76 / 57.49 MiB | Select: low-detail arid/sand base; cool-muted colour should remain subordinate to Astra macro colour |
| `aerial_beach_02` | `aerial_beach_02_2k.zip` | Download ZIP, identical archived ZIP, extracted maps | Diffuse, NormalGL, Roughness, Displacement, AO | 56.46 / 30.81 MiB | Defer: specialized wet/dark shoreline material for the later coast pass |

The 11 Downloads archives and their art-workspace archive copies are byte-identical:

| Archive | SHA-256 |
|---|---|
| `Grass001_2K-PNG.zip` | `d6fd8aad96d39e582f234b4a3d668f5dc9f660fa0cf7b7e7e62f8cfdd623418f` |
| `sparse_grass_2k.zip` | `1d13151d3b5610da5daee9f37e7a58007028d5797447538da35cc113570e64c9` |
| `withered_grass_2k.zip` | `3c99e3e29cb3c65e38ef0cc62b0785af41b5d9e8754ba28c43a6b5fcc8c0951d` |
| `aerial_grass_rock_2k.zip` | `a4a5a77c3c36a8321bdd22b86c75a1182ede0b216aa39f48667befc9dc4e6a2f` |
| `rocky_terrain_02_2k.zip` | `3634cdc8f3c29c9dc5bef53dc3ac28e9eabdcb46a31b3d7b8d0734463cdfa940` |
| `aerial_rocks_02_2k.zip` | `ea0d06d9dc538159062dbbf3e534fefe17a1085687714fde1acd5cce966f3cbb` |
| `rock_05_2k.zip` | `8b62fa913106a8556854e5529aad624cd991ddfd76836853473f71c57c6dcf83` |
| `aerial_ground_rock_2k.zip` | `ceccd3f26167eff0339100a94097d254d755a972855bd679573300a786d92b75` |
| `dirt_aerial_03_2k.zip` | `648cde5c94edb5efcd92e4911031bfcdd103d3263df583c8f7a51654d9ecfe14` |
| `sand_03_2k.zip` | `7865dc8f2e3ac2b5bde486461a6262b84d870357009c243c774373afe9a4e443` |
| `aerial_beach_02_2k.zip` | `afce67f78608f7b03af8b1584088d99a8bb7a125a6b3489a2b6ae97dbec38e1f` |

## Previous proof status

`final_materials_proof_02` exercised exactly these four source sets with diffuse/albedo, NormalGL, and roughness:

- `Grass001`: temperate base
- `sparse_grass`: temperate regional variation
- `aerial_grass_rock`: upland transition
- `aerial_rocks_02`: exposed mountain rock

All 12 proof PNGs were re-hashed during this audit. Each remains byte-for-byte identical to the corresponding file in `02_Selected_2K_Maps`. The previous proof also validated all twelve as 2048 x 2048, used sRGB import for colour and data import for NormalGL/roughness, preserved the OpenGL normal orientation, and deliberately excluded AO and displacement.

The remaining seven sets were curated source candidates, not technically proven production choices. Their presence in `02_Selected_2K_Maps` means their source maps were deliberately extracted and normalized for comparison; it does not mean they were approved in-engine.

## Selected first-pass library and Astra mapping

| Astra authority | Primary | Secondary / transition | Reason |
|---|---|---|---|
| R — temperate/grass | `Grass001` | `sparse_grass` | Proven lush base plus a browner, patchier natural variation |
| G — Mediterranean/dry | `withered_grass` | `dirt_aerial_03` | Dry vegetation plus exposed warm soil; blend by actual G weight |
| B — desert/arid | `sand_03` | `dirt_aerial_03`, with `rock_05` on exposed slopes | Quiet sand/earth combination avoids a single flat desert photograph |
| A — exposed rock | `aerial_rocks_02` | `rock_05` | Proven mountain rock plus warmer dry-rock variation |
| R/A or slope transition | `aerial_grass_rock` | — | Proven mixed grass/stone bridge; do not assign it as a fifth mask channel |

This is an eight-set library: two temperate, two dry-ground candidates (`withered_grass` and shared `dirt_aerial_03`), one sand, two rock, and one transition. The eventual implementation should preserve the continuous Astra RGBA weights and layer these materials within each role; it should not quantize the material mask into hard regions.

No additional source is required before the first textured pass. The weakest area is specialized coast treatment, but `aerial_beach_02` is already available and intentionally deferred. Desert colour may require art-direction through the existing Astra macro signal because `sand_03` is muted rather than strongly golden; that is a tuning issue, not a blocking asset gap.

## Production files and verification

Source for every row is `02_Selected_2K_Maps/<set>/<file>`. Destination is `res://assets/world_map/terrain_materials/<set>/<file>`.

| Set | Production file | Map | Size | SHA-256 source = copy |
|---|---|---|---:|---|
| `Grass001` | `Grass001_2K-PNG_Color.png` | albedo | 7.23 MiB | `a798a39e2df2ef3f8be2502ff0c9b02f3858547d9ecfe5ec8f722f2fef8a9e5f` |
| `Grass001` | `Grass001_2K-PNG_NormalGL.png` | NormalGL | 23.13 MiB | `5e9096e7b1612bbae8d45f1d5e47458650644873269d7493738f5d22f78a3e9f` |
| `Grass001` | `Grass001_2K-PNG_Roughness.png` | roughness | 2.98 MiB | `072b26aec4575ed77b3351e5dc733fd91af755114fc498966a3206ab3e211d2e` |
| `sparse_grass` | `sparse_grass_diff_2k.png` | albedo | 21.55 MiB | `d24a836c12689f4fda41358251f30ddb865bbad41ccac63bf276b13559d55167` |
| `sparse_grass` | `sparse_grass_nor_gl_2k.png` | NormalGL | 23.21 MiB | `3295cf5ca9db4ed1888d94ebf7e69295c1c6607beeb1e3bd5373c7cd20c9318e` |
| `sparse_grass` | `sparse_grass_rough_2k.png` | roughness | 6.58 MiB | `9f3a47f0705f1c09939c7549194bab8863e2ef74f1eae613cf3307e5bd2e8143` |
| `withered_grass` | `withered_grass_diff_2k.png` | albedo | 22.90 MiB | `ca1600e92cb82ba4c579d54f9b02a36c5fd1d55174c5732c6031ba5885f8323f` |
| `withered_grass` | `withered_grass_nor_gl_2k.png` | NormalGL | 23.46 MiB | `5b4be863674ec322952cc3e0aa2a33980b194ad65d83ff012e348ae4bd38849f` |
| `withered_grass` | `withered_grass_rough_2k.png` | roughness | 10.03 MiB | `a1eb44209deb2d423dc70287fefe836468d95e1bb4b51bf7b3d8f906c9d7a7e4` |
| `dirt_aerial_03` | `dirt_aerial_03_diff_2k.png` | albedo | 21.94 MiB | `b1c7ad01985c1e3a86a19c4832ca3b09c789b7c02cb1978be4f3f27fac3e0760` |
| `dirt_aerial_03` | `dirt_aerial_03_nor_gl_2k.png` | NormalGL | 19.59 MiB | `2f111fb1202b15798dc181c002143f9ccba328c4d54209912d6c69bc2f994cef` |
| `dirt_aerial_03` | `dirt_aerial_03_rough_2k.png` | roughness | 7.67 MiB | `52822a6b66c5e6c3b1a74a2749b894f947e2b8709b6b9f3af352034df66276eb` |
| `sand_03` | `sand_03_diff_2k.png` | albedo | 21.80 MiB | `2331f246bf721a93a7c946ef75289060e86d3d67612ec8a25d81c58e96e66ee8` |
| `sand_03` | `sand_03_nor_gl_2k.png` | NormalGL | 21.24 MiB | `43b8179110e6ac28e230c931216fbdf1923f93f62502df4255c0b68525adf628` |
| `sand_03` | `sand_03_rough_2k.png` | roughness | 6.50 MiB | `21cd98c9317c4ac69a25cd71a69bbc7323180d22964c90b58a61d4d0d670d43e` |
| `aerial_rocks_02` | `aerial_rocks_02_diff_2k.png` | albedo | 8.09 MiB | `6d0319b0ebc97dae5e7ebeb02fe9252bdc78654b46b276907222a12935c07b18` |
| `aerial_rocks_02` | `aerial_rocks_02_nor_gl_2k.png` | NormalGL | 8.39 MiB | `53d4c2cac90801132a99054bd7d6132b230ddf9b12cc20c515caa7da0da6f01a` |
| `aerial_rocks_02` | `aerial_rocks_02_rough_2k.png` | roughness | 2.24 MiB | `2f5f3f21d17a82378f29ea3501b5f5d5bc827493bc309e5f7ab1c0795880fdb2` |
| `rock_05` | `rock_05_diff_2k.png` | albedo | 8.12 MiB | `c55ad6cf0a7e59280d8879b1b58bf110ee6d8ab7a4e61d7b8f5af7621411ef4a` |
| `rock_05` | `rock_05_nor_gl_2k.png` | NormalGL | 7.05 MiB | `220fa102371cd18f18daba694aa067e1f98e68e0d0af3d5d174be9f74d6a7caf` |
| `rock_05` | `rock_05_rough_2k.png` | roughness | 7.24 MiB | `5894a7149f8b9d97da09f775c9dbc4e4b1b0d51db6aa2be2175746203a9bb289` |
| `aerial_grass_rock` | `aerial_grass_rock_diff_2k.png` | albedo | 24.02 MiB | `b88e29903589b8a1a0448e4555f49fb1e0e653c1eae01358ab0666c8180e6e10` |
| `aerial_grass_rock` | `aerial_grass_rock_nor_gl_2k.png` | NormalGL | 24.42 MiB | `e78b6f7012c60d50da2ea295c2351427df415cfa1d5ec865b36859c31da211cc` |
| `aerial_grass_rock` | `aerial_grass_rock_rough_2k.png` | roughness | 8.50 MiB | `3621b27444955dc877f0bf5eea58a70d911d6a17f9dc104137b00b2079a6eabe` |

Verification result: 24 files expected, 24 files present, 0 SHA-256 mismatches.

AO was not copied because the first pass has no concrete AO-compositing requirement and baked AO can fight terrain lighting. Displacement/height was not copied because the current task does not authorize height blending, parallax, or vertex displacement; importing it now would add roughly another large data layer without an agreed use. Both remain available in the immutable curated source.

## Exact next implementation step

Build an isolated Terrain3D material prototype that imports these 24 files with colour/data semantics and mipmaps verified, packs them only as required by Terrain3D, and blends them from the existing Astra RGBA material weights while preserving the validated terrain, crop, orientation, renderer, and coordinate mapping. Start with the four primary roles, add the secondary variations and `aerial_grass_rock` transition only after the primary alignment is visually proven, and retain the established physical/metre scale correction from `final_materials_proof_02`.
