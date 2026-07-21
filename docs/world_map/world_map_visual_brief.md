# World Map Visual Brief

This document is the detailed Stage 1.5 authority for the planned world-map visual vertical slice. Repository source, tests and documentation remain authoritative for implemented reality; nothing described here is implemented merely because it is specified.

## Decision status

- **Locked Stage 1.5 requirements** define the proof unless an explicit documented decision supersedes them.
- **Current wider-game direction** guides scalability without promising implementation in Stage 1.5.
- **Deferred** items are deliberately outside the proof.
- **Unresolved future decisions** remain open and must not be invented during implementation.

## 1. Purpose and feasibility gate

### Locked Stage 1.5 requirements

- Stage 1.5 is a six-province, near-final-quality world-map visual vertical slice.
- Its purpose is to prove that the intended map can look beautiful, function correctly and scale to a full continent.
- The proof is not programmer art or a disposable coloured-shape mock-up.
- The proof region may later become part of the final continent or may be discarded; no promise is made.
- Full-continent production and further simulation expansion remain blocked until a **Pass** decision.
- The planned pipeline is **Azgaar → Wonderdraft → Godot**.
- The proof must include at least one deliberate revision and re-export cycle.

## 2. Perspective and visual tone

### Locked Stage 1.5 requirements

- Use a fixed three-quarter oblique perspective based on the general viewing direction of the Knights of Honor 1 references, not a roof-only top-down view.
- The camera never rotates.
- The landscape has a serious, grounded and natural tone.
- Bunny identity comes primarily through portraits, narration, heraldry, settlements, population activity, events and UI.
- Terrain uses restrained earthy greens and browns, grey stone and muted blue water.
- Stronger colours primarily belong to political borders, banners, heraldry, overlays and UI.
- Terrain types use soft hand-painted transitions without visible square tiles, repeated seams or political-border biome changes.

### Current wider-game direction

Stronger climate or biome transitions may use believable natural barriers such as mountain ranges.

## 3. Lighting, time and seasons

### Locked Stage 1.5 requirements

- All art uses one consistent daylight direction.
- Target light comes from the upper-left, with restrained shadows toward the lower-right, subject to adjustment to match the chosen main asset family.
- Shadows are soft but clearly visible.
- The proof uses one stable daylight presentation.
- No day/night system is designed or implemented.
- There are no visual seasons or seasonal terrain variants.

### Unresolved future decisions

Nighttime presentation is neither promised nor designed, but it is not declared permanently impossible.

## 4. Terrain and political view relationship

### Locked Stage 1.5 requirements

- Terrain, political and diplomatic views use the same underlying geography, province polygons, camera direction and three-quarter perspective. They are different visual and information treatments of one map, not separate geographic maps.
- Terrain view has a deliberately narrow zoom range. The same terrain details and objects remain present throughout it.
- No zoom-based asset replacement, disappearing detail or separate terrain detail level is planned for the proof.
- Political view supports a much wider zoom range and may show the entire continent.
- Political view can be entered through a dedicated control or by zooming beyond the terrain-view limit.
- Mode switching is immediate, with no fade, transition animation, automatic recentering, scene change or loading screen.
- Camera centre and current zoom remain unchanged when switching modes where valid.
- Returning from a political zoom farther out than terrain view permits instantly snaps to terrain view's maximum zoom-out while retaining the exact map centre.
- Required visual layers remain available so switching does not visibly reload the map.
- The game opens in terrain view, centred on the player's starting province at normal gameplay zoom.

## 5. Terrain-view political borders

### Locked Stage 1.5 requirements

- Province borders are always visible in terrain view.
- Borders are thin, subtle and dashed or stitched.
- Border colour represents the owning kingdom. Temporary placeholder kingdom colours are valid for the proof.
- Borders update when ownership changes.
- Borders and provinces do not react visually to hovering.
- Borders remain readable across open ground, fields and most forests.
- Major mountains or substantial settlement objects may briefly obscure border sections, but borders must remain traceable overall.
- Deliberate layer ordering or masking may be used to achieve this.

### Current wider-game direction

Final kingdom colours should connect to flags and heraldic identity.

## 6. Terrain-view province selection

### Locked Stage 1.5 requirements

- Clicking the main town or any point inside a province selects that province.
- Selection creates a gentle province tint and clearer outline in terrain view, separate from the permanent political border.
- Selection opens or updates the temporary province-information UI.
- Selection never moves, zooms or recentres the camera.
- Selection persists while changing map modes.

## 7. Normal political view

### Locked Stage 1.5 requirements

- Kingdom territory is filled with mostly opaque but slightly transparent kingdom colour.
- Faint stylised geography remains visible underneath, including coastlines, major rivers and mountain ranges; political view does not reproduce the complete detailed terrain treatment.
- Internal province borders are hidden. Only borders between different kingdoms are strongly visible.
- Kingdom names appear directly on the map, upright and screen-aligned.
- Small kingdoms still receive visible labels through smaller text, adjusted placement or a pointer line where necessary.
- Province names are hidden.
- Towns, farms, monasteries, workshops, resource sites and other settlement objects are hidden.
- There are no capitals, capital provinces, capital markers or capital filter.

### Deferred

An optional administrative filter revealing province divisions may be considered later; it is not part of Stage 1.5.

## 8. Diplomatic filter

### Locked Stage 1.5 requirements

- Diplomatic view is a filter within the political presentation.
- Base territory becomes a neutral parchment-like colour.
- Friendlier kingdoms move progressively toward green, neutral kingdoms remain parchment-coloured, hostile kingdoms move progressively toward red, and kingdoms at war with the reference kingdom appear clearly red.
- Kingdom names remain visible.
- The player's kingdom is the initial reference where applicable.
- Clicking another kingdom name changes the diplomatic reference.
- Clicking ordinary territory selects the underlying province rather than the whole kingdom.

### Current wider-game direction

Kingdoms may also later be selected through diplomacy UI.

## 9. Political-view province selection

### Locked Stage 1.5 requirements

- Political and diplomatic views continue using the same hidden province polygons.
- Clicking ordinary territory selects the province underneath and opens the same province information/action as terrain view.
- These views do not reveal the selected province boundary and show no province tint, outline or internal border.
- Selection is communicated through UI.
- Returning to terrain view immediately restores the existing province tint and outline.

## 10. Geographic and knowledge visibility

### Locked Stage 1.5 requirements

- Handcrafted geography is visible from the beginning.
- Known kingdom territories and borders are not hidden by conventional fog of war.
- Permanent natural-feature labels are hidden by default.

### Current wider-game direction

- Future knowledge systems may limit detailed information such as armies, resources, development, activity and internal conditions.
- Rivers, forests and mountain ranges may later be identified through tooltips, lore interfaces or an optional geographic filter.

## 11. Camera behaviour

### Locked Stage 1.5 requirements

The camera supports:

- screen-edge scrolling;
- middle-mouse dragging;
- WASD;
- arrow keys;
- mouse-wheel zoom.

Zoom is centred on the screen centre, not the mouse cursor. Movement and zoom are smooth but restrained, responsive and slightly snappy; inputs stop quickly without floaty drifting.

The camera has firm playable boundaries with a very small slowdown near the edge. Terrain artwork extends beyond those boundaries as visual bleed so the player never sees a harsh rectangular map edge. Bleed contains no selectable provinces or gameplay data.

## 12. Six-province proof geography

### Locked Stage 1.5 requirements

The proof is:

- a moderately wide landscape composition suitable for a 16:9 display;
- a coastal mainland region rather than an island;
- visibly part of a larger landmass;
- six provinces divided between three temporary kingdoms in a 3–2–1 ownership split;
- three coastal and three inland provinces;
- moderately varied in province size, including at least one clearly larger province.

Its geographic content includes:

- one calm bay or river mouth;
- one rougher rocky or cliff coastline;
- one major river crossing at least two provinces before reaching the sea;
- an optional smaller tributary;
- one modest coherent mountain range;
- scattered foothills and isolated rocky outcrops;
- at least one natural valley or pass;
- one major forest spanning parts of two provinces;
- several smaller woodland clusters;
- one clear agricultural heartland;
- smaller farmland areas near other settlements.

Province borders usually follow believable rivers, ridges, coasts and forest edges, while some administrative borders may cross open land.

### Current wider-game direction

The full continent may use much greater province-size variation.

## 13. Province structure and towns

### Locked Stage 1.5 requirements

- Every province has the same fundamental structural status and exactly one main town.
- There are no capital provinces or inherently superior provinces.
- Provinces differ through geography, resources, traits, development and later growth potential.
- Towns occupy predefined permanent positions chosen for geography rather than geometric province centres. Suitable locations include rivers, bays, fertile plains, crossings, valleys and mountain passes.
- Towns use intentionally exaggerated miniature scale for readability.
- All six proof towns share one coherent western-European architectural family.
- Temporary kingdom differences are limited to banners, roof accents, layout variations and heraldic colour.
- Towns are separate Godot objects rather than part of the painted base terrain.
- The proof uses one temporary town stage; town growth is not implemented.
- Town objects must be replaceable by larger development stages later.

## 14. Province and site labels

### Locked Stage 1.5 requirements

- Each province name appears above its main town in terrain view.
- Province labels remain upright and roughly screen-readable throughout the narrow terrain zoom range. They may scale slightly but must not become tiny or enormous.
- Supporting farms, mines, mills, monasteries, workshops and similar sites are unlabeled by default; names and information appear through selection or province UI.

## 15. Supporting province sites

### Locked Stage 1.5 requirements

- Gameplay-relevant farms, mills, mines, monasteries, workshops and similar sites are separate placeable objects at predefined authored positions based on geography and composition.
- Players do not position sites freely or procedurally.
- Sites may appear, disappear or be replaced as development changes. Empty site positions are invisible.
- The proof includes only six main towns, several farms, one religious site, one resource site, and one mill or workshop.
- Decorative fields, dirt paths, hedges, bushes, rocks and minor landscape details may remain part of the terrain artwork.

### Deferred

The full building catalogue is outside Stage 1.5.

## 16. Roads and paths

### Locked Stage 1.5 requirements

- There is no continent-wide rendered strategic road-network requirement.
- Most visible routes are local dirt paths and worn tracks inside provinces, generally painted into the terrain.
- Predefined settlement and site positions allow paths to be composed around them.

### Deferred

Dynamic road construction, visual road upgrading and road-network gameplay are outside Stage 1.5. They may be reconsidered only if later gameplay genuinely requires them.

## 17. Mountains, forests and water

### Locked Stage 1.5 requirements

- Mountains are placed during authoring and baked into the final terrain artwork.
- Major forests remain grouped visual layers or clusters.
- Gentle forest movement may be tested; forests remain static if animation looks artificial, wobbly or visually worse.
- Individual trees are reserved for selected landmarks or close settlement details.
- Logging and resource extraction do not visibly remove forests.
- Sea, lake, river and coastline shapes are stable terrain artwork.
- Restrained shimmer, gentle directional flow and subtle shoreline motion may be layered over water.
- Water is not physically simulated.

## 18. Ambient motion

### Locked Stage 1.5 requirements

Priorities are:

- **Required:** gentle decorative cloud movement.
- **Medium priority:** chimney smoke.
- **Low priority:** coastal mist.

Clouds are decorative only in Stage 1.5 and the current wider-game direction. They create no gameplay, weather, storms, rain, visibility penalties or simulated cloud cover, and must not meaningfully obscure towns, borders, kingdom labels or important information.

Water shimmer and restrained forest movement are desired. All ambient movement appears only in terrain view. Clouds, water shimmer, forest movement and smoke pause or disappear in political and diplomatic views, then resume on return to terrain view.

Ambient animation offers **Full**, **Reduced** and **Off** settings; Full is the default.

No moving bunny population, route animation, crowds or path-following logic is included. Composition should preserve sensible future corridors for predefined population movement paths.

## 19. Asset strategy and quality target

### Locked Stage 1.5 requirements

- The proof is a near-final-quality visual vertical slice that genuinely demonstrates a beautiful intended map.
- Technically functional but visually worthless placeholders are insufficient.
- One coherent commercial-use asset family provides the primary environmental foundation.
- Additional commercial-use packs may fill genuine gaps only after adaptation to match perspective, lighting, scale, detail and tone.
- The result must not resemble an asset-store collage.
- Individual assets may later be replaced without invalidating the proof if the overall visual method remains sound.
- Raw editable sources, purchased packs, invoices and licence evidence remain outside Git as defined in [`world_map_workspace.md`](world_map_workspace.md).
- No asset purchase or download occurs in this documentation milestone.

## 20. UI scope

### Locked Stage 1.5 requirements

- The map receives near-final visual attention; UI remains minimal and temporary.
- Required temporary UI is limited to terrain/political mode controls, diplomatic filter controls, selected-province information, and useful development and performance readouts.

### Deferred

The complete HUD, economy bar, royal court, alerts, minimap and final UI styling are outside Stage 1.5.

## 21. Resolution and performance

### Locked Stage 1.5 requirements

- Primary target: 1920×1080 at 16:9.
- The map adapts to common desktop resolutions and artwork remains sharp at 1440p.
- Dedicated 4K optimisation is not required.
- Target stable 60 FPS on the user's current laptop with Full ambient animation enabled.
- Camera movement and zoom remain smooth.
- Province selection and map-mode switching do not visibly hitch.
- Load time and memory use are recorded to estimate full-continent feasibility.

## 22. Scalable map structure

### Locked Stage 1.5 requirements

- The world is authored as one coherent visual map.
- Godot may divide terrain and overlay artwork into controlled sections and layers, but joins remain invisible and camera movement across sections remains smooth and hitch-free.
- The player must not perceive the underlying division.
- Towns, sites, forests, borders, labels, ambient effects and political overlays remain appropriately separated from stable terrain.

## 23. Live ownership test

### Locked Stage 1.5 requirements

The proof includes a temporary debug-only ownership transfer that:

- moves one province between placeholder kingdoms;
- updates terrain-view dashed border colours;
- updates political territory fills;
- updates kingdom boundaries;
- updates kingdom-label placement where needed;
- updates diplomatic colouring;
- requires no map reload.

This test does not implement war, conquest or simulation logic.

## 24. Revision and re-export test

### Locked Stage 1.5 requirements

- At least one geography or object-placement revision occurs after the first Godot import.
- The source is re-exported and updated in Godot without rebuilding the implementation from scratch.
- This demonstrates that the Azgaar → Wonderdraft → Godot pipeline is repeatable rather than a one-time success.

## 25. Pass, Revise and Replace gate

### Pass

**Pass** requires all of the following:

- the region looks genuinely beautiful and close to intended full-game quality;
- the serious three-quarter presentation is visually coherent;
- the result does not resemble mismatched asset packs;
- terrain, coastline, rivers, mountains, forests, towns and sites fit together naturally;
- camera movement and both zoom ranges feel responsive and polished;
- province selection behaves correctly in every map view;
- terrain borders, political ownership, kingdom names and diplomatic colours work correctly;
- live ownership transfer updates without reloading;
- ambient motion improves atmosphere without harming readability or performance;
- the revision and re-export cycle works cleanly;
- the proof maintains stable 60 FPS at 1080p on the target laptop;
- measured memory use and loading behaviour credibly show that the method can scale to a full continent.

A technically functional but ugly result is not a Pass. A beautiful result created through a fragile or unrepeatable process is not a Pass.

### Revise

**Revise** means the core pipeline is sound but identifiable problems require correction.

### Replace

**Replace** means the tools, assets, perspective or technical approach fundamentally cannot meet the goal.

## Deferred and unresolved summary

Deliberately deferred features include detailed province close-ups, the full building catalogue, town growth, dynamic roads, visual seasons, a day/night system, final UI, simulation expansion and full-continent production.

Unresolved future decisions include whether nighttime presentation should ever exist, whether optional administrative or geographic filters are worthwhile, whether kingdoms also need diplomacy-UI selection, whether forest animation passes visual review, and whether the proof region or individual assets survive into the final continent.
