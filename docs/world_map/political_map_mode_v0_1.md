# Political Map Mode v0.1

**September 18 integration:** This accepted internal inspection mode is now combined with campaign-start v1 on `main`. The schema-2 Political fixture migration is applied; presentation behavior is unchanged. The historical roster limitation below is resolved by `CampaignBootstrap.new_campaign()`. Gameplay 001 still opens as an inspection scene and accepts sessions through its existing binding interface. Combined results are in [repository integration](../gameplay_state/repository_integration_2026-09-18.md).

Gameplay 001 opens in its unchanged Normal mode. Press **P** to tint the existing Terrain3D surface by current Realm ownership, and **P** again to restore Normal. The key is handled by the gameplay wrapper before NaturalWorld's standalone P shortcut, so toggling modes does not hide natural props. The camera, settlement test, water, vegetation, rocks, geometry, picking and accepted dual-sided border mesh are unchanged.

Current ownership is read from `ProvinceState.owner_realm_id`. The inspection scene does not yet have the authored ruler, House and capital scenario records needed for a valid full `CampaignSession`, so it seeds 100 current ProvinceState records once from validated frozen starting ownership. `WorldGameplay.bind_campaign_session()` replaces that inspection source when a live campaign is supplied; while Political mode is open, it refreshes on session revision changes. The catalogue remains the frozen starting definition, not a second current-owner table.

`political_realm_palette.gd` uses a curated 30-color muted/heraldic palette. It builds Realm adjacency from the accepted Province neighbor graph and current owners, assigns colors deterministically, then swaps assignments to improve the weakest neighboring contrasts while retaining all 30 pigments. Every Province of a Realm samples the same palette color. The colors are debug presentation only and never enter world identity, `RealmState`, or saves.

`province_id_mask.png` is a 4096×2304 single-channel derivative of the accepted Province rings; a pixel stores the Province ID only. Regenerate it after an authorized geography change with:

```powershell
godot --headless --path . --log-file .godot/political_mask_build.log --script res://tools/world_map/build_political_province_mask.gd
```

The gameplay-only terrain shader variant samples that mask and a per-Province color texture, then blends color into NaturalWorld's calculated ground color at **38%**. Terrain relief and photographic variation remain underneath; separate water, vegetation, settlements, cloud and border renderers remain intact. The original terrain shader and original border palette are restored in Normal mode. The variant is built from the existing shader's final-color seam and fails configuration if that seam changes; this is the maintenance check when NaturalWorld's shader is next edited. The v0.1 mask stores IDs 1–255; a future geography with higher IDs needs a wider ID encoding.

Visual QA captures are in [`qa/political_map_mode/`](qa/political_map_mode/): normal/political pairs at gameplay zoom **800**, **1600** and **3600**, mountain and settlement comparison pairs, plus a continent overview for color-distribution inspection. Rivers, coastline, trees, mountain relief and settlement representation remain readable; the existing ribbons remain visible over the tint. The overview zoom is for QA and does not change gameplay camera limits. The capture command is:

```powershell
godot --path . --log-file .godot/political_capture.log --script res://tools/world_map/capture_political_map_mode.gd
```

`tests/political_map_mode_test.gd` verifies all 100 current-owner reads, all 43 starting Realm colors, 30 distinct assigned pigments, exact shared color within each Realm, deterministic assignment, neighboring contrast, a committed campaign capture changing the displayed owner, and all 100 mask selection anchors. The observed minimum neighboring OKLab distance squared is **0.0187**. The complete direct suite passes **21/21**. The running scene capture also verifies actual P input, intact natural-prop visibility and Normal restoration.

## Realm-name labels

Political mode also has one plain screen-space name per currently landed Realm. `political_realm_labels.gd` groups current `ProvinceState.owner_realm_id` values, reads the Realm's current canonical display identity (including live formable identity), and places each name at an owned Province interior point near the Realm's weighted territory center. It rebuilds on campaign revision, so captures and formations update the displayed name and placement. A Realm that loses all land loses its label. A newly generated Realm with no authored identity can only display its stable ID until canonical naming exists.

The existing camera projects these anchors. Labels use modest zoom-dependent font sizes; when a large Realm fills a close view but its fixed anchor is offscreen, its name appears at the camera center over that Realm. Continent names wrap and separate in screen space to reduce overlap, and labels avoid the existing gameplay inspection panel. The whole label layer is hidden in Normal mode. The tint, palette, Province mask, terrain, accepted borders, settlements and camera code are unchanged by this addition.

Visual QA captures are in [`qa/political_realm_labels/`](qa/political_realm_labels/): Political views at zoom **800**, **1600**, **3600** and **30000**, a continent view with the gameplay panel visible, plus a Normal reference. The capture checks actual P input, 43 unique Realm labels, zero overview text-rectangle or panel overlaps, natural-prop preservation and Normal restoration. Run it with:

```powershell
godot --path . --log-file .godot/realm_labels_capture.log --script res://tools/world_map/capture_political_realm_labels.gd
```
