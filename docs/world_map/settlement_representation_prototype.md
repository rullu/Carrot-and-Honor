# Settlement Representation Prototype

## Purpose and boundary

This removable test compares a supplied 2D settlement image with a crude 3D Godot blockout in the real Gameplay 001 wrapper. It exists only to judge strategic-map scale, readability and zoom behavior. It adds no settlement state, economy, realm rules, names, collisions or final art.

Open `scenes/gameplay/world_gameplay.tscn` and run the current scene. The locked NaturalWorld remains an instance of `astra_natural_world_final.tscn`.

## Supplied references

The project copies are byte-identical to the user's Downloads sources:

- `assets/prototypes/settlement/testhome_2d.png`: the actual transparent 2D representation; SHA-256 `36fc0a6bf0a839efc2714f98aa56c84c2e8989cbdf3cd40ab11f7f05baa61bf5`.
- `assets/prototypes/settlement/testhome_3d_reference.png`: layout reference only; SHA-256 `9f628f554874efeff1059492f5e67dd79a6047d98b4202963fc4c26f81315d5f`.

The 2D PNG is a billboarded `Sprite3D` with its original alpha, lossless texture import, alpha-border repair, mipmaps and anisotropic filtering. It casts no shadow and contains no collision. The 3D reference PNG is never shown in the game.

## Placement and scale

Both representations use the same per-province anchor:

| Province | Godot X/Z | Terrain height at anchor | Approximate border clearance |
| --- | --- | ---: | ---: |
| 67 | `(-13903.80859375, 6909.1796875)` | 3.32 | 245 units |
| 54 | `(-16223.14453125, 3771.97265625)` | 6.08 | 776 units |

The points were chosen from current province polygons and accepted land coverage, then checked for low local slope, border clearance and nearby NaturalWorld props. Runtime configuration verifies that each point still resolves to its intended province and has a valid Terrain3D height. Individual 3D pieces sample Terrain3D at their own X/Z offset so they follow the existing surface without modifying it.

The 1254-pixel 2D image uses `0.075` world units per pixel, for a 94.05-unit image width. Its visual centre is raised 38 units so its transparent isometric art meets the ground from the fixed camera. The 3D core is about 110 by 95 units before three narrow road exits. It contains an octagonal wall, keep, chapel and spire, market and well, fourteen houses and three exits built from simple meshes.

## Controls

- `F1`: 2D only, the default.
- `F2`: 3D only.
- `F3`: both at the shared anchors.
- `F4`: hide both.

The test overlay ignores mouse input. Province hover, selection and camera controls continue to use their existing paths.

## QA captures and provisional findings

`tools/world_map/capture_settlement_prototype.gd` loads the actual Gameplay 001 scene and captures provinces 67 and 54 in both modes at zoom 800, 1200, 1600, 2000, 2400 and 3200. Evidence is under `docs/world_map/qa/settlement_prototype/`; `settlement_prototype_capture_report.json` records every camera pose and filename.

The 2D representation is crisp and clearly identifiable at 800 and 1600. At 2000-2400 it remains a readable strategic marker, and at 3200 it retains a settlement silhouette while individual detail is naturally lost. The crude 3D proxy has a comparable footprint at 800 and remains recognizable around 1600, but its landmark detail drops faster and it becomes a small colored cluster beyond 2000. Neither approach overwhelms province 67; province 54 accommodates both comfortably.

These observations are evidence for human review, not a final choice between 2D and 3D.
