extends SceneTree


const SCENE: PackedScene = preload("res://scenes/gameplay/world_gameplay.tscn")
const OUTPUT: String = "res://docs/world_map/qa/political_map_mode"
const ZOOMS: Array[float] = [800.0, 1600.0, 3600.0]


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
    var border_presentation: ProvincePresentation = gameplay.get_node("ProvincePresentation") as ProvincePresentation
    var props: Node3D = natural_world.get_node("NaturalWorldDetails") as Node3D
    var original_props_visible: bool = props.visible
    gameplay.get_node("GameplayUI").visible = false
    gameplay.get_node("SettlementPrototypeTestRoot/PrototypeUI").visible = false
    natural_world.get_node("InspectionControls").visible = false
    for zoom: float in ZOOMS:
        natural_world.set("_camera_target", Vector3(-4500.0, 0.0, -1700.0))
        camera.size = zoom
        natural_world.call("_update_camera")
        await _save(output.path_join("normal_%d.png" % int(zoom)))
        _press_p()
        for frame: int in 8:
            await process_frame
        if gameplay._map_mode != &"political" or props.visible != original_props_visible or terrain.material.shader_override == original_shader:
            push_error("P failed to enter Political mode without changing NaturalWorld props.")
            quit(1)
            return
        await _save(output.path_join("political_%d.png" % int(zoom)))
        _press_p()
        for frame: int in 8:
            await process_frame
        if gameplay._map_mode != &"normal" or props.visible != original_props_visible or terrain.material.shader_override != original_shader or not border_presentation._political_colors_by_province.is_empty():
            push_error("P failed to restore Normal mode cleanly.")
            quit(2)
            return
    var settlement: SettlementPrototypeTest = gameplay.get_node("SettlementPrototypeTestRoot") as SettlementPrototypeTest
    var settlement_xz: Vector2 = settlement.get_anchor_xz(67)
    var extra_views: Array[Dictionary] = [
        {"name": "mountains", "target": Vector3(10300.0, 75.0, -3300.0), "zoom": 2400.0},
        {"name": "settlement", "target": Vector3(settlement_xz.x, 0.0, settlement_xz.y), "zoom": 1600.0},
    ]
    for view: Dictionary in extra_views:
        natural_world.set("_camera_target", view["target"])
        camera.size = view["zoom"]
        natural_world.call("_update_camera")
        await _save(output.path_join("%s_normal.png" % view["name"]))
        _press_p()
        for frame: int in 8:
            await process_frame
        await _save(output.path_join("%s_political.png" % view["name"]))
        _press_p()
        for frame: int in 8:
            await process_frame
    natural_world.set("_camera_target", Vector3.ZERO)
    camera.size = 30000.0
    natural_world.call("_update_camera")
    _press_p()
    for frame: int in 8:
        await process_frame
    await _save(output.path_join("political_overview.png"))
    _press_p()
    print("POLITICAL_CAPTURE_PASS: 3 zoom pairs, mountain/settlement pairs and overview; P restored Normal and preserved props")
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
        push_error("Could not save Political Map capture: %s" % path)
        quit(3)
