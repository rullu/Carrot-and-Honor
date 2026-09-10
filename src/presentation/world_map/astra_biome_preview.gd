extends Node3D


const MATERIAL_MASK_PATH: String = "res://assets/world_map/astra/source/FCAH_Materials_Playable_4096x2304_RGBA.png"
const MATERIAL_MASK_SHA256: String = "261d787da02387142a02f83e11ef253e1a01bb6aaf91dba7b7edc0f960f75e68"
const EXPECTED_MASK_SIZE: Vector2i = Vector2i(4096, 2304)
const EXPECTED_REGION_COUNT: int = 576
const EXPECTED_REGION_SIZE: int = 128
const VERTEX_SPACING: float = 12.20703125
const FULL_VIEW_SIZE: float = 34000.0
const MIN_VIEW_SIZE: float = 700.0
const MAX_VIEW_SIZE: float = 36000.0
const OBLIQUE_OFFSET: Vector3 = Vector3(0.0, 18000.0, 22000.0)
const TOP_DOWN_OFFSET: Vector3 = Vector3(0.0, 30000.0, 0.01)
const NORTHEAST_MOUNTAIN_TARGET: Vector3 = Vector3(10351.5625, 0.0, -3125.0)
const EAST_DESERT_TARGET: Vector3 = Vector3(9082.03125, 0.0, 1562.5)

@onready var terrain: Terrain3D = $Terrain3D
@onready var camera: Camera3D = $InspectionCamera
@onready var view_label: Label = $DiagnosticsUI/Panel/Margin/Rows/View

var _camera_target: Vector3 = Vector3.ZERO
var _top_down: bool = false
var _material_image: Image


func _ready() -> void:
    _material_image = Image.load_from_file(ProjectSettings.globalize_path(MATERIAL_MASK_PATH))
    if _material_image.is_empty():
        push_error("Could not load the Astra playable material mask.")
        get_tree().quit(1)
        return
    var source_size: Vector2i = _material_image.get_size()
    var source_format: Image.Format = _material_image.get_format()
    if _material_image.generate_mipmaps() != OK:
        push_error("Could not generate linear mipmaps for the material preview.")
        get_tree().quit(2)
        return
    var material_texture: ImageTexture = ImageTexture.create_from_image(_material_image)
    terrain.material.shader_override_enabled = true
    terrain.material.show_checkered = false
    terrain.material.set_shader_param(&"material_mask", material_texture)
    terrain.set_camera(camera)
    camera.current = true
    _update_camera()
    print(
        "Astra biome preview ready: Terrain3D %s, %d regions, material mask %s %s."
        % [terrain.version, terrain.data.get_regions_active().size(), source_size, source_format]
    )

    var validation_output: String = _get_validation_output()
    if not validation_output.is_empty():
        await _run_validation(validation_output, source_size, source_format)


func _process(delta: float) -> void:
    var direction: Vector2 = Input.get_vector(
        &"map_move_left", &"map_move_right", &"map_move_up", &"map_move_down"
    )
    if direction.is_zero_approx():
        return
    var pan_speed: float = camera.size * 0.65
    _camera_target.x = clampf(
        _camera_target.x + direction.x * pan_speed * delta, -24500.0, 24500.0
    )
    _camera_target.z = clampf(
        _camera_target.z + direction.y * pan_speed * delta, -13500.0, 13500.0
    )
    _update_camera()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _set_zoom(camera.size * 0.82)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _set_zoom(camera.size * 1.22)
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_V:
                _top_down = not _top_down
                _update_camera()
            KEY_F:
                _camera_target = Vector3.ZERO
                camera.size = FULL_VIEW_SIZE
                _update_camera()


func _set_zoom(new_size: float) -> void:
    camera.size = clampf(new_size, MIN_VIEW_SIZE, MAX_VIEW_SIZE)


func _update_camera() -> void:
    if _top_down:
        camera.position = _camera_target + TOP_DOWN_OFFSET
        camera.look_at(_camera_target, Vector3.FORWARD)
        view_label.text = "View: TOP-DOWN (north is screen top)"
    else:
        camera.position = _camera_target + OBLIQUE_OFFSET
        camera.look_at(_camera_target, Vector3.UP)
        view_label.text = "View: OBLIQUE (north is screen top)"


func _get_validation_output() -> String:
    var arguments: PackedStringArray = OS.get_cmdline_user_args()
    arguments.append_array(OS.get_cmdline_args())
    for argument: String in arguments:
        if argument.begins_with("--validation-output="):
            return argument.trim_prefix("--validation-output=")
    return ""


func _run_validation(
    output_directory: String,
    source_size: Vector2i,
    source_format: Image.Format
) -> void:
    var failures: Array[String] = []
    if source_size != EXPECTED_MASK_SIZE:
        failures.append("The playable material mask is not 4096x2304.")
    if source_format != Image.FORMAT_RGBA8:
        failures.append("The playable material mask is not RGBA8.")
    if FileAccess.get_sha256(MATERIAL_MASK_PATH) != MATERIAL_MASK_SHA256:
        failures.append("The playable material mask does not match its validated SHA-256.")
    if terrain.version != "1.0.2":
        failures.append("Unexpected Terrain3D version: %s" % terrain.version)
    if terrain.region_size != EXPECTED_REGION_SIZE:
        failures.append("Unexpected Terrain3D region size: %d" % terrain.region_size)
    if not is_equal_approx(terrain.vertex_spacing, VERTEX_SPACING):
        failures.append("Unexpected Terrain3D vertex spacing: %s" % terrain.vertex_spacing)
    if terrain.data.get_regions_active().size() != EXPECTED_REGION_COUNT:
        failures.append(
            "Expected %d Terrain3D regions, found %d."
            % [EXPECTED_REGION_COUNT, terrain.data.get_regions_active().size()]
        )

    DirAccess.make_dir_recursive_absolute(output_directory)
    $DiagnosticsUI.visible = false
    _top_down = true
    _camera_target = Vector3.ZERO
    camera.size = 28125.0
    _update_camera()
    await _save_view(output_directory.path_join("astra_biome_whole_top_down.png"), failures)

    _top_down = false
    _camera_target = Vector3.ZERO
    camera.size = FULL_VIEW_SIZE
    _update_camera()
    await _save_view(output_directory.path_join("astra_biome_whole_oblique.png"), failures)

    _top_down = false
    _camera_target = NORTHEAST_MOUNTAIN_TARGET
    camera.size = 5200.0
    _update_camera()
    await _save_view(output_directory.path_join("astra_biome_northeast_mountain.png"), failures)

    _top_down = true
    _camera_target = EAST_DESERT_TARGET
    camera.size = 6000.0
    _update_camera()
    await _save_view(output_directory.path_join("astra_biome_east_desert.png"), failures)

    var result_path: String = output_directory.path_join("astra_biome_preview_validation_result.txt")
    var result_file: FileAccess = FileAccess.open(result_path, FileAccess.WRITE)
    if result_file == null:
        failures.append("Could not write the biome-preview validation result.")
    elif failures.is_empty():
        result_file.store_string(
            "ASTRA_BIOME_PREVIEW_VALIDATION_PASS\n"
            + "material_mask_sha256=%s\n" % MATERIAL_MASK_SHA256
            + "material_mask_size=4096x2304\n"
            + "terrain_regions=%d\n" % terrain.data.get_regions_active().size()
            + "region_size=%d\n" % terrain.region_size
            + "vertex_spacing=%.8f\n" % terrain.vertex_spacing
            + "orientation=north_-Z_south_+Z_west_-X_east_+X\n"
            + "screenshots=4\n"
        )
        result_file.close()
    else:
        result_file.close()

    if failures.is_empty():
        print("ASTRA_BIOME_PREVIEW_VALIDATION_PASS")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    get_tree().quit(1)


func _save_view(path: String, failures: Array[String]) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var screenshot: Image = get_viewport().get_texture().get_image()
    if screenshot.is_empty() or screenshot.save_png(path) != OK:
        failures.append("Could not save validation screenshot: %s" % path)
