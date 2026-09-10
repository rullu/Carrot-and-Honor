extends SceneTree
## Matching-camera art review, usable on the checkpoint and polished scene alike.

func _initialize() -> void:
    _run.call_deferred()

func _argument(prefix: String) -> String:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with(prefix): return argument.trim_prefix(prefix)
    return ""

func _run() -> void:
    var output: String = _argument("--out=")
    var view_path: String = _argument("--views=")
    if output.is_empty() or not FileAccess.file_exists(view_path):
        push_error("Review requires --out=<directory> and --views=<existing JSON file>.")
        quit(1)
        return
    var views: Array = JSON.parse_string(FileAccess.get_file_as_string(view_path))
    DirAccess.make_dir_recursive_absolute(output)
    var packed: PackedScene = load("res://scenes/world_map/astra_natural_world_final.tscn") as PackedScene
    var world: Node3D = packed.instantiate() as Node3D
    root.add_child(world)
    for frame: int in range(45): await process_frame
    world.set("_capturing",true)
    world.get_node("InspectionControls").visible = false
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var camera: Camera3D = world.get_node("InspectionCamera") as Camera3D
    var terrain: Terrain3D = world.get_node("Terrain3D") as Terrain3D
    var records: Array[Dictionary] = []
    if "--mesh-stats" in OS.get_cmdline_user_args():
        var detail: Node3D = world.get("_props") as Node3D
        var meshes: Array = detail.get("_full_meshes")
        for id: int in [0,3,6,18,21]:
            var mesh: ArrayMesh = meshes[id]
            for surface: int in range(mesh.get_surface_count()):
                print("MESH_DETAIL ",id," ",mesh.surface_get_material(surface).resource_name," ",mesh.surface_get_array_index_len(surface)/3)
    for view: Dictionary in views:
        var environment: Environment = (world.get_node("WorldEnvironment") as WorldEnvironment).environment
        environment.ssao_enabled = bool(view.get("ssao",false))
        environment.ssao_radius = 18.0
        environment.ssao_intensity = 1.1
        environment.ssao_light_affect = .18
        for reaction: MeshInstance3D in world.get_node("SelectedWaterReactions").get_children():
            (reaction.material_override as ShaderMaterial).set_shader_parameter("debug_footprint",bool(view.get("reaction_debug",false)))
        for node_name: String in ["SelectedWaterReactions","NaturalBankFaces","MovingCloudVolumes","AuthoritativeInlandWater"]:
            var layer: Node3D = world.get_node_or_null(NodePath(node_name)) as Node3D
            if layer != null: layer.visible = node_name not in view.get("hide_nodes",[])
        root.mesh_lod_threshold = float(view.get("lod",1.0))
        var position: Array = view.target
        var target: Vector3 = Vector3(position[0],position[1],position[2])
        var height: float = terrain.data.get_height(target)
        if not is_nan(height): target.y = maxf(0.0,height)
        var pitch: float = float(view.get("pitch",40.0))
        var radians: float = deg_to_rad(pitch)
        camera.size = view.size
        world.set("_camera_target",target)
        world.call("_update_camera")
        if view.has("far"): camera.far = float(view.far)
        camera.position = target+Vector3(0,sin(radians),cos(radians))*camera.size*1.1
        if pitch > 89.0:
            camera.position = target+Vector3(0,camera.size,.01)
            camera.look_at(target,Vector3.FORWARD)
        else:
            camera.look_at(target,Vector3.UP)
        var detail: Node3D = world.get("_props") as Node3D
        detail.visible = not bool(view.get("bare",false))
        for frame: int in range(20): await process_frame
        var timings: Array[float] = []
        var begin: int = Time.get_ticks_usec()
        for frame: int in range(40):
            await RenderingServer.frame_post_draw
            var now: int = Time.get_ticks_usec()
            timings.append((now-begin)/1000.0)
            begin = now
        timings.sort()
        var screenshot: Image = root.get_texture().get_image()
        screenshot.save_png(output.path_join(String(view.name)+".png"))
        records.append({"name":view.name,"target":[target.x,target.y,target.z],"size":camera.size,"pitch":pitch,
            "median_present_ms":timings[20],"p95_present_ms":timings[38],
            "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
            "primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
            "video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
        print("ART_CAPTURE ",view.name," ",timings[20]," ms")
    var file: FileAccess = FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"views":records,"gpu":RenderingServer.get_video_adapter_name(),
        "renderer":RenderingServer.get_current_rendering_method(),"image_size":str(root.get_size())},"  "))
    file.close()
    print("ART_REVIEW_COMPLETE")
    quit()
