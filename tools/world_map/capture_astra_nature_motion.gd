extends SceneTree
## Real engine frames at a fixed simulation step; encoding is a separate QA task.

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    var output: String = ""
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--out="): output=argument.trim_prefix("--out=")
    DirAccess.make_dir_recursive_absolute(output)
    var packed: PackedScene = load("res://scenes/world_map/astra_natural_world_final.tscn") as PackedScene
    var world: Node3D = packed.instantiate() as Node3D
    root.add_child(world)
    for frame: int in range(30): await process_frame
    world.set("_capturing",true)
    world.get_node("InspectionControls").visible=false
    var camera: Camera3D = world.get_node("InspectionCamera") as Camera3D
    var districts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_map/astra/natural_world/natural_districts.json"))
    var discoveries: Dictionary = {}
    for landmark: Dictionary in districts.landmarks:
        discoveries[landmark.name]=Vector3(landmark.target[0],landmark.target[1],landmark.target[2])
    var shots: Array[Dictionary] = [
        {"name":"Woodland pan","target":Vector3(-4500,0,-1700),"size":1600.0,"end_size":1600.0,"pan":Vector3(160,0,70)},
        {"name":"Coastal water","target":Vector3(-5250,0,-1400),"size":1200.0,"end_size":1200.0,"pan":Vector3(50,0,0)},
        {"name":"River surface","target":Vector3(-2576,0,-928),"size":800.0,"end_size":800.0,"pan":Vector3.ZERO},
        {"name":"Parmetos lake","target":discoveries.parmetos_silent_arch,"size":1000.0,"end_size":1000.0,"pan":Vector3.ZERO},
        {"name":"Amber spring","target":discoveries.amber_spring,"size":1000.0,"end_size":1000.0,"pan":Vector3.ZERO},
        {"name":"Gameplay zoom","target":Vector3(-4500,0,-1700),"size":3600.0,"end_size":800.0,"pan":Vector3(80,0,60)}]
    var capture: int = 0
    for shot: Dictionary in shots:
        for frame: int in range(180):
            var t: float = frame/179.0
            var eased: float = smoothstep(0.0,1.0,t)
            world.set("_camera_target",shot.target+shot.pan*eased)
            camera.size=lerpf(shot.size,shot.end_size,eased)
            world.call("_update_camera")
            await RenderingServer.frame_post_draw
            var screenshot: Image = root.get_texture().get_image()
            screenshot.save_jpg(output.path_join("frame_%05d.jpg"%capture),.95)
            capture+=1
        print("MOTION_SHOT ",shot.name)
    var file: FileAccess=FileAccess.open(output.path_join("motion.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"frames":capture,"fps":30,"seconds":36,"pitch":40,"shots":shots},"  "))
    print("MOTION_CAPTURE_COMPLETE")
    quit()
