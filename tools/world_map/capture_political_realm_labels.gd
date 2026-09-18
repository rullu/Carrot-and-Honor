extends SceneTree


const SCENE: PackedScene = preload("res://scenes/gameplay/world_gameplay.tscn")
const OUTPUT: String = "res://docs/world_map/qa/political_realm_labels"
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
    var labels: PoliticalRealmLabels = gameplay.get_node("PoliticalRealmLabels") as PoliticalRealmLabels
    var props: Node3D = natural_world.get_node("NaturalWorldDetails") as Node3D
    var original_props_visible: bool = props.visible
    gameplay.get_node("GameplayUI").visible = false
    gameplay.get_node("SettlementPrototypeTestRoot/PrototypeUI").visible = false
    natural_world.get_node("InspectionControls").visible = false
    if labels.visible or labels.get_label_count() != 0:
        push_error("Normal mode must start without Realm labels.")
        quit(1)
        return
    for zoom: float in GAMEPLAY_ZOOMS:
        natural_world.set("_camera_target", Vector3(-4500.0, 0.0, -1700.0))
        camera.size = zoom
        natural_world.call("_update_camera")
        if zoom == 1600.0:
            await _save(output.path_join("normal_1600.png"))
        _press_p()
        for frame: int in 8:
            await process_frame
        if not labels.visible or labels.get_label_count() != 43:
            push_error("Political mode must have exactly one label per starting Realm.")
            quit(2)
            return
        var visible_gameplay_labels: int = 0
        for label: Label in labels.get_children():
            if label.visible:
                visible_gameplay_labels += 1
        if visible_gameplay_labels == 0:
            push_error("No Realm name is readable at gameplay zoom %d." % int(zoom))
            quit(2)
            return
        await _save(output.path_join("political_%d.png" % int(zoom)))
        _press_p()
        for frame: int in 8:
            await process_frame
        if labels.visible or terrain.material.shader_override != original_shader or props.visible != original_props_visible:
            push_error("P did not restore Normal presentation and hide Realm labels.")
            quit(3)
            return
    natural_world.set("_camera_target", Vector3.ZERO)
    camera.size = 30000.0
    natural_world.call("_update_camera")
    _press_p()
    for frame: int in 12:
        await process_frame
    var on_screen_count: int = 0
    var visible_rects: Array[Rect2] = []
    var overlapping_pairs: int = 0
    for label: Label in labels.get_children():
        if label.visible:
            on_screen_count += 1
            var rect: Rect2 = Rect2(label.position, label.size)
            for other: Rect2 in visible_rects:
                if rect.intersects(other):
                    overlapping_pairs += 1
            visible_rects.append(rect)
    print("REALM_LABELS_OVERVIEW_VISIBLE: %d/43" % on_screen_count)
    print("REALM_LABELS_OVERVIEW_OVERLAPS: %d" % overlapping_pairs)
    if on_screen_count != 43 or overlapping_pairs > 0:
        push_error("Continent names must all be visible without text overlap.")
        quit(4)
        return
    await _save(output.path_join("political_overview.png"))
    gameplay.get_node("GameplayUI").visible = true
    await _save(output.path_join("political_overview_ui.png"))
    var panel_rect: Rect2 = gameplay.get_node("GameplayUI/ProvinceDebugPanel").get_global_rect()
    for label: Label in labels.get_children():
        if label.visible and Rect2(label.position, label.size).intersects(panel_rect):
            push_error("A Realm name overlaps the gameplay inspection panel.")
            quit(4)
            return
    _press_p()
    for frame: int in 8:
        await process_frame
    if labels.visible:
        push_error("Overview labels persisted in Normal mode.")
        quit(4)
        return
    print("REALM_LABELS_CAPTURE_PASS: close/default/far/overview; 43 unique labels; Normal restored")
    quit(0)


func _press_p() -> void:
    var event: InputEventKey = InputEventKey.new()
    event.physical_keycode = KEY_P
    event.pressed = true
    Input.parse_input_event(event)


func _save(path: String) -> void:
    for frame: int in 8:
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image.is_empty() or image.save_png(path) != OK:
        push_error("Could not save Realm-label QA image: %s" % path)
        quit(5)
