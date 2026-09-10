extends Node3D


const SOURCE_HEIGHTMAP: String = "res://assets/world_map/astra/source/FCAH_Height_Playable_4096x2304_F32.exr"
const SOURCE_HEIGHT_TEXTURE: Texture2D = preload(
    "res://assets/world_map/astra/source/FCAH_Height_Playable_4096x2304_F32.exr"
)
const EXPECTED_SOURCE_SHA256: String = "5a1a895081e2cf24fe1466b2a0cf036b04908afad57dfff01f50b366f63a3dbc"
const EXPECTED_REGION_COUNT: int = 576
const VERTEX_SPACING: float = 12.20703125
const HEIGHT_SCALE: float = 256.0
const HEIGHT_OFFSET: float = -6.4
const IMPORT_ORIGIN: Vector3 = Vector3(-25000.0, 0.0, -14062.5)

@onready var terrain: Terrain3D = $Terrain3D
@onready var camera: Camera3D = $InspectionCamera


func _ready() -> void:
    camera.current = true
    camera.look_at(Vector3.ZERO, Vector3.UP)
    terrain.set_camera(camera)
    print(
        "Astra terrain ready: Terrain3D %s, %d regions, range %s"
        % [terrain.version, terrain.data.get_regions_active().size(), terrain.data.get_height_range()]
    )

    var validation_output: String = _get_validation_output()
    if not validation_output.is_empty():
        await _run_validation(validation_output)


func _get_validation_output() -> String:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--validation-output="):
            return argument.trim_prefix("--validation-output=")
    return ""


func _run_validation(output_directory: String) -> void:
    var failures: Array[String] = []
    var source_image: Image = SOURCE_HEIGHT_TEXTURE.get_image()
    if source_image.is_empty():
        failures.append("The production EXR could not be decoded.")
    else:
        if source_image.get_size() != Vector2i(4096, 2304):
            failures.append("The source dimensions are not 4096x2304.")
        if FileAccess.get_sha256(SOURCE_HEIGHTMAP) != EXPECTED_SOURCE_SHA256:
            failures.append("The project-local EXR does not match the Astra authority hash.")

    if terrain.version != "1.0.2":
        failures.append("Unexpected Terrain3D version: %s" % terrain.version)
    if terrain.region_size != 128:
        failures.append("Unexpected region size: %d" % terrain.region_size)
    if not is_equal_approx(terrain.vertex_spacing, VERTEX_SPACING):
        failures.append("Unexpected vertex spacing: %s" % terrain.vertex_spacing)
    if terrain.data.get_regions_active().size() != EXPECTED_REGION_COUNT:
        failures.append(
            "Expected %d terrain regions, found %d."
            % [EXPECTED_REGION_COUNT, terrain.data.get_regions_active().size()]
        )

    if not source_image.is_empty():
        _validate_height_samples(source_image, failures)

    DirAccess.make_dir_recursive_absolute(output_directory)
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var oblique_image: Image = get_viewport().get_texture().get_image()
    var oblique_error: Error = oblique_image.save_png(
        output_directory.path_join("astra_terrain_oblique.png")
    )
    if oblique_error != OK:
        failures.append("Could not save the oblique validation image.")

    camera.position = Vector3(0.0, 30000.0, 0.01)
    camera.size = 28125.0
    camera.look_at(Vector3.ZERO, Vector3.FORWARD)
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var top_down_image: Image = get_viewport().get_texture().get_image()
    var top_down_error: Error = top_down_image.save_png(
        output_directory.path_join("astra_terrain_top_down.png")
    )
    if top_down_error != OK:
        failures.append("Could not save the top-down validation image.")

    if failures.is_empty():
        print("ASTRA_TERRAIN_VALIDATION_PASS")
        get_tree().quit(0)
        return

    for failure: String in failures:
        push_error(failure)
    get_tree().quit(1)


func _validate_height_samples(source_image: Image, failures: Array[String]) -> void:
    var points: Array[Vector2i] = [
        Vector2i(0, 0),
        Vector2i(4095, 0),
        Vector2i(0, 2303),
        Vector2i(4095, 2303),
        Vector2i(2048, 1152),
        Vector2i(900, 1100),
        Vector2i(3308, 605),
    ]
    for point: Vector2i in points:
        var expected_height: float = (
            source_image.get_pixelv(point).r * HEIGHT_SCALE + HEIGHT_OFFSET
        )
        var world_position: Vector3 = Vector3(
            IMPORT_ORIGIN.x + float(point.x) * VERTEX_SPACING,
            0.0,
            IMPORT_ORIGIN.z + float(point.y) * VERTEX_SPACING
        )
        var actual_height: float = terrain.data.get_height(world_position)
        if absf(actual_height - expected_height) > 0.00001:
            failures.append(
                "Height mismatch at %s: expected %s, found %s."
                % [point, expected_height, actual_height]
            )
