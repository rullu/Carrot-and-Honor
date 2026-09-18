extends SceneTree


const GAMEPLAY_SCENE: PackedScene = preload("res://scenes/gameplay/world_gameplay.tscn")
const PROVINCE_IDS: Array[int] = [67, 54]
const MODES: Array[Dictionary] = [
    {"id": 0, "name": "2d"},
    {"id": 1, "name": "3d"},
]
const ZOOM_LEVELS: Array[float] = [800.0, 1200.0, 1600.0, 2000.0, 2400.0, 3200.0]


func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var output_path: String = _argument("--output=")
    if output_path.is_empty():
        push_error("Usage: capture_settlement_prototype.gd -- --output=<directory>")
        quit(1)
        return
    output_path = ProjectSettings.globalize_path(output_path)
    if DirAccess.make_dir_recursive_absolute(output_path) != OK:
        push_error("Could not create settlement QA output directory.")
        quit(2)
        return

    var gameplay: Node3D = GAMEPLAY_SCENE.instantiate() as Node3D
    root.add_child(gameplay)
    for frame: int in 40:
        await process_frame
    var natural_world: Node3D = gameplay.get_node("NaturalWorld") as Node3D
    var camera: Camera3D = natural_world.get_node("InspectionCamera") as Camera3D
    var prototype: SettlementPrototypeTest = gameplay.get_node(
        "SettlementPrototypeTestRoot"
    ) as SettlementPrototypeTest
    gameplay.get_node("GameplayUI").visible = false
    natural_world.get_node("InspectionControls").visible = false

    var captures: Array[Dictionary] = []
    for province_id: int in PROVINCE_IDS:
        var anchor: Vector2 = prototype.get_anchor_xz(province_id)
        for mode: Dictionary in MODES:
            prototype.set_display_mode(mode["id"])
            for zoom: float in ZOOM_LEVELS:
                natural_world.set("_camera_target", Vector3(anchor.x, 0.0, anchor.y))
                camera.size = zoom
                natural_world.call("_update_camera")
                prototype.mode_label.text = (
                    "Province %d | %s | zoom %.0f" % [province_id, mode["name"], zoom]
                )
                for frame: int in 12:
                    await process_frame
                await RenderingServer.frame_post_draw
                var image: Image = root.get_texture().get_image()
                var filename: String = "province_%d_%s_zoom_%04d.png" % [
                    province_id, mode["name"], int(zoom)
                ]
                if image.is_empty() or image.save_png(output_path.path_join(filename)) != OK:
                    push_error("Could not save %s." % filename)
                    quit(3)
                    return
                captures.append(
                    {
                        "province_id": province_id,
                        "mode": mode["name"],
                        "zoom": zoom,
                        "anchor_xz": [anchor.x, anchor.y],
                        "camera_position": [camera.position.x, camera.position.y, camera.position.z],
                        "file": filename,
                    }
                )
                print("CAPTURED %s" % filename)

    var report: Dictionary = {
        "passed": true,
        "scene": "res://scenes/gameplay/world_gameplay.tscn",
        "viewport_size": [root.size.x, root.size.y],
        "camera_pitch_degrees": 40.0,
        "zoom_levels": ZOOM_LEVELS,
        "captures": captures,
    }
    var report_file: FileAccess = FileAccess.open(
        output_path.path_join("settlement_prototype_capture_report.json"), FileAccess.WRITE
    )
    if report_file == null:
        push_error("Could not write the settlement QA report.")
        quit(4)
        return
    report_file.store_string(JSON.stringify(report, "  ") + "\n")
    report_file.close()
    print("SETTLEMENT_PROTOTYPE_CAPTURE_PASS: %d images" % captures.size())
    quit(0)


func _argument(prefix: String) -> String:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)
    return ""
