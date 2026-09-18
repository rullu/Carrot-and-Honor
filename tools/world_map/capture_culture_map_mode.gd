extends SceneTree


const SCENE: PackedScene = preload("res://scenes/gameplay/world_gameplay.tscn")
const OUTPUT: String = "res://docs/world_map/qa/culture_map_mode"
const GAMEPLAY_ZOOMS: Array[float] = [800.0, 1600.0, 3600.0]


func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var output: String = ProjectSettings.globalize_path(OUTPUT)
    DirAccess.make_dir_recursive_absolute(output)
    var gameplay: WorldGameplay = SCENE.instantiate() as WorldGameplay
    root.add_child(gameplay)
    for frame: int in 40:
        await process_frame
    var natural_world: Node3D = gameplay.get_node("NaturalWorld") as Node3D
    var camera: Camera3D = natural_world.get_node("InspectionCamera") as Camera3D
    var terrain: Terrain3D = natural_world.get_node("Terrain3D") as Terrain3D
    var original_shader: Shader = terrain.material.shader_override
    var props: Node3D = natural_world.get_node("NaturalWorldDetails") as Node3D
    var original_props_visible: bool = props.visible
    var culture_labels: CultureRegionLabels = gameplay.get_node(
        "CultureRegionLabels"
    ) as CultureRegionLabels
    var realm_labels: PoliticalRealmLabels = gameplay.get_node(
        "PoliticalRealmLabels"
    ) as PoliticalRealmLabels
    var gameplay_ui: CanvasLayer = gameplay.get_node("GameplayUI") as CanvasLayer
    var province_panel: Control = gameplay.get_node(
        "GameplayUI/ProvinceDebugPanel"
    ) as Control
    gameplay_ui.visible = false
    gameplay.get_node("SettlementPrototypeTestRoot/PrototypeUI").visible = false
    natural_world.get_node("InspectionControls").visible = false
    if culture_labels.visible or realm_labels.visible or terrain.material.shader_override != original_shader:
        push_error("Gameplay must start in unchanged Normal mode.")
        quit(1)
        return

    for zoom: float in GAMEPLAY_ZOOMS:
        natural_world.set("_camera_target", Vector3(-4500.0, 0.0, -1700.0))
        camera.size = zoom
        natural_world.call("_update_camera")
        if zoom == 1600.0:
            await _save(output.path_join("normal_1600.png"))
        _press(KEY_C)
        for frame: int in 8:
            await process_frame
        if not _check_culture(gameplay, culture_labels, realm_labels, props, original_props_visible):
            quit(2)
            return
        var visible_labels: int = 0
        var screen_rect: Rect2 = Rect2(
            Vector2.ZERO, camera.get_viewport().get_visible_rect().size
        )
        for label: Label in culture_labels.get_children():
            if label.visible and screen_rect.encloses(Rect2(label.position, label.size)):
                visible_labels += 1
        if visible_labels == 0:
            push_error("No cultural region label is readable at zoom %d." % int(zoom))
            quit(2)
            return
        await _save(output.path_join("culture_%d.png" % int(zoom)))
        _press(KEY_C)
        for frame: int in 8:
            await process_frame
        if not _check_normal(gameplay, culture_labels, realm_labels, terrain, original_shader):
            quit(3)
            return
        if zoom == 1600.0:
            await _save(output.path_join("normal_after_culture_1600.png"))

    natural_world.set("_camera_target", Vector3.ZERO)
    camera.size = 30000.0
    natural_world.call("_update_camera")
    _press(KEY_P)
    for frame: int in 8:
        await process_frame
    if not _check_political(gameplay, culture_labels, realm_labels):
        quit(4)
        return
    await _save(output.path_join("political_before_culture.png"))
    _press(KEY_C)
    for frame: int in 8:
        await process_frame
    if not _check_culture(gameplay, culture_labels, realm_labels, props, original_props_visible):
        quit(5)
        return
    var on_screen_count: int = 0
    var rects: Array[Rect2] = []
    var overlaps: int = 0
    for label: Label in culture_labels.get_children():
        if not label.visible:
            continue
        on_screen_count += 1
        var rect: Rect2 = Rect2(label.position, label.size)
        for other: Rect2 in rects:
            if rect.intersects(other):
                overlaps += 1
        rects.append(rect)
    print("CULTURE_OVERVIEW_LABELS: %d/%d; overlaps %d" % [
        on_screen_count, culture_labels.get_label_count(), overlaps
    ])
    if on_screen_count != culture_labels.get_label_count() or overlaps > 0:
        push_error("All connected cultural regions must have legible overview labels.")
        quit(6)
        return
    await _save(output.path_join("culture_overview.png"))
    gameplay_ui.visible = true
    await _save(output.path_join("culture_overview_ui.png"))
    var panel_rect: Rect2 = province_panel.get_global_rect()
    for label: Label in culture_labels.get_children():
        if label.visible and Rect2(label.position, label.size).intersects(panel_rect):
            push_error("A culture name overlaps the gameplay inspection panel.")
            quit(7)
            return
    gameplay_ui.visible = false
    _press(KEY_P)
    for frame: int in 8:
        await process_frame
    if not _check_political(gameplay, culture_labels, realm_labels):
        quit(8)
        return
    await _save(output.path_join("political_after_culture.png"))
    _press(KEY_P)
    for frame: int in 8:
        await process_frame
    if not _check_normal(gameplay, culture_labels, realm_labels, terrain, original_shader):
        quit(9)
        return
    print("CULTURE_MAP_CAPTURE_PASS: P/C transitions, 100 Provinces, 28 regions, Normal restored")
    quit(0)


func _check_culture(
    gameplay: WorldGameplay,
    culture_labels: CultureRegionLabels,
    realm_labels: PoliticalRealmLabels,
    props: Node3D,
    original_props_visible: bool
) -> bool:
    var valid: bool = (
        gameplay._map_mode == &"culture"
        and gameplay._culture_map.is_enabled()
        and not gameplay._political_map.is_enabled()
        and culture_labels.visible
        and culture_labels.get_label_count() == 28
        and not realm_labels.visible
        and gameplay.presentation._political_colors_by_province.is_empty()
        and props.visible == original_props_visible
    )
    if not valid:
        push_error("Culture mode retained Political presentation or did not cover all regions.")
    return valid


func _check_political(
    gameplay: WorldGameplay,
    culture_labels: CultureRegionLabels,
    realm_labels: PoliticalRealmLabels
) -> bool:
    var valid: bool = (
        gameplay._map_mode == &"political"
        and gameplay._political_map.is_enabled()
        and not gameplay._culture_map.is_enabled()
        and realm_labels.visible
        and realm_labels.get_label_count() == 43
        and not culture_labels.visible
        and gameplay.presentation._political_colors_by_province.size() == 100
    )
    if not valid:
        push_error("Political presentation did not return intact after Culture mode.")
    return valid


func _check_normal(
    gameplay: WorldGameplay,
    culture_labels: CultureRegionLabels,
    realm_labels: PoliticalRealmLabels,
    terrain: Terrain3D,
    original_shader: Shader
) -> bool:
    var valid: bool = (
        gameplay._map_mode == &"normal"
        and not gameplay._political_map.is_enabled()
        and not gameplay._culture_map.is_enabled()
        and not realm_labels.visible
        and not culture_labels.visible
        and terrain.material.shader_override == original_shader
        and gameplay.presentation._political_colors_by_province.is_empty()
    )
    if not valid:
        push_error("Normal mode retained a map overlay, color or label.")
    return valid


func _press(key: Key) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.physical_keycode = key
    event.pressed = true
    Input.parse_input_event(event)


func _save(path: String) -> void:
    for frame: int in 8:
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image.is_empty() or image.save_png(path) != OK:
        push_error("Could not save Culture-map QA image: %s" % path)
        quit(10)
