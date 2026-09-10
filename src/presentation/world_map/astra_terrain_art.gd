extends Node3D


const MASK_PATH: String = "res://assets/world_map/astra/source/FCAH_Materials_Playable_4096x2304_RGBA.png"
const MASK_SHA256: String = "261d787da02387142a02f83e11ef253e1a01bb6aaf91dba7b7edc0f960f75e68"
const ASSET_ROOT: String = "res://assets/world_map/terrain_materials/art_preview"
const SHADER: Shader = preload("res://src/presentation/world_map/astra_terrain_art.gdshader")
const VIEW_PRESETS: Array[Dictionary] = [
    {"name": "whole_top_down", "target": Vector3.ZERO, "size": 28125.0, "top": true},
    {"name": "whole_oblique", "target": Vector3.ZERO, "size": 30000.0, "top": false},
    {"name": "west_temperate", "target": Vector3(-3500, 0, -1200), "size": 4800.0, "top": false},
    {"name": "southwest_mediterranean", "target": Vector3(-12200, 0, 4600), "size": 6200.0, "top": false},
    {"name": "east_desert", "target": Vector3(10800, 0, 4700), "size": 6800.0, "top": false},
    {"name": "northeast_mountains", "target": Vector3(10200, 75, -3100), "size": 5200.0, "top": false},
    {"name": "central_transition", "target": Vector3(7000, 0, 200), "size": 6500.0, "top": true},
    {"name": "ground_detail", "target": Vector3(-11694.3359375, 0, -1416.015625), "size": 2.0, "top": false},
]

@onready var terrain: Terrain3D = $Terrain3D
@onready var camera: Camera3D = $InspectionCamera
@onready var view_label: Label = $InspectionControls/Panel/Margin/Rows/View

var _camera_target: Vector3 = Vector3.ZERO
var _top_down: bool = false
var _capturing: bool = false
var _failures: Array[String] = []
var _textures: Array[Texture] = []
var _started_usec: int = Time.get_ticks_usec()


func _ready() -> void:
    var mask: Image = Image.load_from_file(ProjectSettings.globalize_path(MASK_PATH))
    var context: Image = Image.load_from_file(ProjectSettings.globalize_path(ASSET_ROOT.path_join("surface_context_rgba.png")))
    if mask.get_size() != Vector2i(4096, 2304) or context.get_size() != mask.get_size():
        push_error("Terrain art needs the exact playable material and context images.")
        get_tree().quit(1)
        return
    mask.generate_mipmaps()
    context.generate_mipmaps()
    var mask_texture: ImageTexture = ImageTexture.create_from_image(mask)
    var context_texture: ImageTexture = ImageTexture.create_from_image(context)
    var albedo: Texture2DArray = load(ASSET_ROOT.path_join("albedo_srgb.tres")) as Texture2DArray
    var normal_roughness: Texture2DArray = load(ASSET_ROOT.path_join("normal_roughness.tres")) as Texture2DArray
    if albedo == null or normal_roughness == null:
        push_error("Missing terrain art arrays; run build_astra_art_arrays.gd.")
        get_tree().quit(1)
        return
    _textures = [mask_texture, context_texture, albedo, normal_roughness]
    # Empty Terrain3DAssets can turn the checker on during node initialization.
    # Clear every runtime diagnostic before binding this separate override.
    for property: Dictionary in terrain.material.get_property_list():
        if String(property.name).begins_with("show_"):
            terrain.material.set(property.name, false)
    terrain.material.shader_override = SHADER
    terrain.material.shader_override_enabled = true
    terrain.material.set_shader_param(&"material_mask", mask_texture)
    terrain.material.set_shader_param(&"surface_context", context_texture)
    terrain.material.set_shader_param(&"art_albedo", albedo)
    terrain.material.set_shader_param(&"art_normal_roughness", normal_roughness)
    terrain.set_camera(camera)
    camera.current = true
    _frame_world()
    await get_tree().process_frame
    _validate_contract(albedo, normal_roughness)
    if not _failures.is_empty():
        for failure: String in _failures:
            push_error(failure)
        get_tree().quit(1)
        return
    print("ASTRA_TERRAIN_ART_READY: %d regions; %d material sets; runtime shader verified; load %.2fs" % [terrain.data.get_regions_active().size(), albedo.get_layers(), (Time.get_ticks_usec()-_started_usec)/1000000.0])
    var output: String = _argument("--validation-output=")
    if not output.is_empty():
        _validate_controls()
        if "--benchmark" in OS.get_cmdline_user_args():
            DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        await _capture_validation(output)
    elif not _failures.is_empty():
        for failure: String in _failures:
            push_error(failure)


func _process(delta: float) -> void:
    if _capturing:
        return
    var movement: Vector2 = Input.get_vector(&"map_move_left", &"map_move_right", &"map_move_up", &"map_move_down")
    if not movement.is_zero_approx():
        _camera_target.x = clampf(_camera_target.x + movement.x*camera.size*.65*delta, -24500.0,24500.0)
        _camera_target.z = clampf(_camera_target.z + movement.y*camera.size*.65*delta, -13500.0,13500.0)
        _update_camera()


func _unhandled_input(event: InputEvent) -> void:
    if _capturing:
        return
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera.size = maxf(2.0, camera.size*.82)
            _update_camera()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera.size = minf(42000.0,camera.size*1.22)
            _update_camera()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_V:
                _top_down = not _top_down
                _update_camera()
            KEY_F:
                _frame_world()
            KEY_H:
                $InspectionControls.visible = not $InspectionControls.visible


func _frame_world() -> void:
    _camera_target = Vector3.ZERO
    var aspect: float = get_viewport().get_visible_rect().size.aspect()
    camera.size = maxf(30000.0, 51000.0/aspect)
    _update_camera()


func _update_camera() -> void:
    # The camera distance follows zoom, so close inspection also brings Terrain3D
    # clipmaps close. This changes no terrain sample or world coordinate.
    var height: float = terrain.data.get_height(_camera_target)
    if not is_nan(height):
        _camera_target.y = maxf(height, 0.0)
    if _top_down:
        camera.position = _camera_target + Vector3(0.0,maxf(camera.size,150.0),.01)
        camera.look_at(_camera_target,Vector3.FORWARD)
    else:
        camera.position = _camera_target + Vector3(0.0,.85,.68)*maxf(camera.size,150.0)
        camera.look_at(_camera_target,Vector3.UP)
    camera.near = maxf(.5,camera.size*.0002)
    view_label.text = "%s | %.1f km vertical view | physical terrain scale" % ["TOP-DOWN" if _top_down else "OBLIQUE",camera.size*.01]


func _argument(prefix: String) -> String:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)
    return ""


func _validate_contract(albedo: Texture2DArray, normal_roughness: Texture2DArray) -> void:
    if FileAccess.get_sha256(MASK_PATH) != MASK_SHA256:
        _failures.append("Material mask hash changed.")
    if terrain.version != "1.0.2" or terrain.region_size != 128 or terrain.vertex_spacing != 12.20703125 or terrain.data.get_regions_active().size() != 576:
        _failures.append("Terrain3D contract changed.")
    if terrain.data_directory != "res://assets/world_map/astra/terrain_data" or terrain.transform != Transform3D.IDENTITY:
        _failures.append("Terrain location/transform changed.")
    var range_y: Vector2 = terrain.data.get_height_range()
    if absf(range_y.x+6.0) > .001 or absf(range_y.y-216.9871) > .001:
        _failures.append("Terrain vertical scale/range changed.")
    if albedo.get_layers() != 8 or normal_roughness.get_layers() != 8 or not albedo.has_mipmaps() or not normal_roughness.has_mipmaps():
        _failures.append("Texture array layer count or mip chains are incorrect.")
    if albedo.get_format() != Image.FORMAT_DXT1 or normal_roughness.get_format() != Image.FORMAT_DXT5:
        _failures.append("Art arrays lost their GPU block compression.")
    var active_code: String = RenderingServer.shader_get_code(terrain.material.get_shader_rid())
    if not active_code.contains("vec4 sample_surface(") or not terrain.material.shader_override_enabled or terrain.material.show_checkered:
        _failures.append("Intended terrain art shader is not active at the RenderingServer.")
    if terrain.material.get_shader_param(&"art_albedo") != albedo:
        _failures.append("Active shader has not received the albedo array.")
    if ProjectSettings.get_setting("rendering/renderer/rendering_method") != "gl_compatibility":
        _failures.append("Renderer changed.")


func _validate_controls() -> void:
    var initial_top: bool = _top_down
    var key: InputEventKey = InputEventKey.new()
    key.pressed = true
    key.physical_keycode = KEY_V
    _unhandled_input(key)
    if _top_down == initial_top:
        _failures.append("V did not change inspection projection.")
    var wheel: InputEventMouseButton = InputEventMouseButton.new()
    wheel.pressed = true
    wheel.button_index = MOUSE_BUTTON_WHEEL_UP
    var previous_size: float = camera.size
    _unhandled_input(wheel)
    if camera.size >= previous_size:
        _failures.append("Mouse wheel did not zoom in.")
    var previous_target: Vector3 = _camera_target
    Input.action_press(&"map_move_right")
    _process(.1)
    Input.action_release(&"map_move_right")
    if _camera_target.x <= previous_target.x:
        _failures.append("Pan input did not move east.")
    key.physical_keycode = KEY_F
    _unhandled_input(key)
    if not is_zero_approx(_camera_target.x) or not is_zero_approx(_camera_target.z) or camera.size < 28125.0:
        _failures.append("F did not frame the whole map.")
    _top_down = initial_top
    _update_camera()


func _capture_validation(output: String) -> void:
    _capturing = true
    DirAccess.make_dir_recursive_absolute(output)
    var active_record: FileAccess = FileAccess.open(output.path_join("active_shader.gdshader.txt"),FileAccess.WRITE)
    active_record.store_string(RenderingServer.shader_get_code(terrain.material.get_shader_rid()))
    active_record.close()
    $InspectionControls.visible = false
    var measurements: Array[Dictionary] = []
    var only_view: String = _argument("--view=")
    var presets: Array[Dictionary] = VIEW_PRESETS.duplicate(true)
    if "--motion-check" in OS.get_cmdline_user_args():
        # Same regional surface through zoom and a small pan across clipmap updates.
        for index: int in range(6):
            presets.append({"name":"motion_%02d" % index,"target":Vector3(10800+index*35,0,4700),
                "size":6800.0*pow(.85,index),"top":false})
    for preset: Dictionary in presets:
        if not only_view.is_empty() and only_view != preset.name:
            continue
        _camera_target = preset.target
        _top_down = preset.top
        camera.size = preset.size
        _update_camera()
        # Allow clipmaps, shaders, mips and shadows to settle before each capture.
        for frame: int in range(12):
            await get_tree().process_frame
        var start: int = Time.get_ticks_usec()
        for frame: int in range(24):
            await RenderingServer.frame_post_draw
        var elapsed_ms: float = (Time.get_ticks_usec()-start)/1000.0/24.0
        var screenshot: Image = get_viewport().get_texture().get_image()
        var filename: String = "astra_art_%s.png" % preset.name
        if screenshot.is_empty() or screenshot.save_png(output.path_join(filename)) != OK:
            _failures.append("Could not save " + filename)
        measurements.append({"view":preset.name,"mean_present_ms":elapsed_ms,"size":camera.size,
            "camera":str(camera.position),"target":str(_camera_target),"image_size":str(screenshot.get_size()),
            "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
            "video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
        print("CAPTURED %s %.2f ms/present" % [filename,elapsed_ms])
    var result: Dictionary = {"pass":_failures.is_empty(),"failures":_failures,"views":measurements,
        "terrain_regions":terrain.data.get_regions_active().size(),"height_range":str(terrain.data.get_height_range()),
        "material_mask_sha256":FileAccess.get_sha256(MASK_PATH),
        "active_shader_sha256":RenderingServer.shader_get_code(terrain.material.get_shader_rid()).sha256_text(),
        "source_shader_sha256":SHADER.code.sha256_text(),"renderer":RenderingServer.get_current_rendering_method(),
        "gpu":RenderingServer.get_video_adapter_name(),
        "vsync_mode":DisplayServer.window_get_vsync_mode(),
        "controls_tested":["V projection","wheel zoom","pan east","F frame"],
        "albedo_format":"BC1 / sRGB samples","normal_roughness_format":"BC3 / linear RGBA"}
    var record: FileAccess = FileAccess.open(output.path_join("art_validation.json"),FileAccess.WRITE)
    if record == null:
        _failures.append("Could not write art_validation.json")
    else:
        record.store_string(JSON.stringify(result,"  ")+"\n")
        record.close()
    for failure: String in _failures:
        push_error(failure)
    print("ASTRA_TERRAIN_ART_VALIDATION_PASS" if _failures.is_empty() else "ASTRA_TERRAIN_ART_VALIDATION_FAIL")
    get_tree().quit(0 if _failures.is_empty() else 1)
