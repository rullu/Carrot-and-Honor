extends SceneTree
## Fixed-step engine motion and regional pans. Frame files remain QA-only.

func _initialize() -> void:
    _run.call_deferred()

func _argument(prefix: String) -> String:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with(prefix): return argument.trim_prefix(prefix)
    return ""

func _run() -> void:
    var output: String = _argument("--out=")
    var shot_path: String = _argument("--views=")
    if output.is_empty() or not FileAccess.file_exists(shot_path):
        push_error("Motion capture requires --out and --views (shot JSON).")
        quit(1)
        return
    var shots: Array = JSON.parse_string(FileAccess.get_file_as_string(shot_path))
    DirAccess.make_dir_recursive_absolute(output)
    var world: Node3D = (load("res://scenes/world_map/astra_natural_world_final.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(world)
    for frame: int in range(45): await process_frame
    world.set("_capturing",true)
    world.get_node("InspectionControls").visible=false
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var camera: Camera3D = world.get_node("InspectionCamera") as Camera3D
    var capture: int = 0
    var records: Array[Dictionary] = []
    for shot: Dictionary in shots:
        var target: Vector3 = Vector3(shot.target[0],shot.target[1],shot.target[2])
        var pan: Vector3 = Vector3(shot.pan[0],0,shot.pan[1])
        var frames: int = int(shot.get("seconds",4))*30
        var first: int = capture
        for frame: int in range(frames):
            var progress: float = smoothstep(0.0,1.0,float(frame)/float(frames-1))
            world.set("_camera_target",target+pan*progress)
            camera.size=lerpf(shot.size,shot.get("end_size",shot.size),progress)
            world.call("_update_camera")
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_jpg(output.path_join("frame_%05d.jpg"%capture),.97)
            capture+=1
        records.append({"name":shot.name,"first_frame":first,"frames":frames,"target":shot.target,"pan":shot.pan,"size":shot.size})
        print("MOTION_SHOT ",shot.name," ",capture)
    var file: FileAccess = FileAccess.open(output.path_join("motion.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"frames":capture,"fps":30,"pitch":40,"image_size":str(root.get_size()),"shots":records},"  "))
    file.close()
    print("PRODUCTION_MOTION_COMPLETE")
    quit()
