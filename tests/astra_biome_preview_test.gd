extends SceneTree


const SOURCE_PATH: String = "res://assets/world_map/astra/source/FCAH_Materials_RGBA.png"
const CROP_PATH: String = "res://assets/world_map/astra/source/FCAH_Materials_Playable_4096x2304_RGBA.png"
const SCENE_PATH: String = "res://scenes/world_map/astra_biome_preview.tscn"
const CONTROLLER_PATH: String = "res://src/presentation/world_map/astra_biome_preview.gd"
const SHADER_PATH: String = "res://src/presentation/world_map/astra_biome_preview.gdshader"
const SOURCE_SHA256: String = "7add3a96942e23a05957d4cbb37742eec868795765b4f8830c03ede41779a899"
const CROP_SHA256: String = "261d787da02387142a02f83e11ef253e1a01bb6aaf91dba7b7edc0f960f75e68"
const CROP_RECT: Rect2i = Rect2i(0, 896, 4096, 2304)
const EXPECTED_REGION_COUNT: int = 576
const EXPECTED_SAMPLES: Array = [
    [Vector2i(1040, 1392), Color8(165, 90, 0, 0), "west temperate/dry blend"],
    [Vector2i(2136, 1512), Color8(87, 168, 0, 0), "southern Mediterranean/dry"],
    [Vector2i(2792, 1280), Color8(0, 15, 223, 17), "east desert/arid"],
    [Vector2i(2896, 896), Color8(7, 0, 3, 245), "northeast exposed rock"],
]

var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _validate_images()
    _validate_shader()
    await _validate_scene()
    _finish()


func _validate_images() -> void:
    _check(FileAccess.get_sha256(SOURCE_PATH) == SOURCE_SHA256, "full material authority hash matches")
    _check(FileAccess.get_sha256(CROP_PATH) == CROP_SHA256, "playable material crop hash matches")
    var source: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
    var crop: Image = Image.load_from_file(ProjectSettings.globalize_path(CROP_PATH))
    _check(source.get_size() == Vector2i(4096, 4096), "full material authority is 4096x4096")
    _check(crop.get_size() == Vector2i(4096, 2304), "playable material crop is 4096x2304")
    _check(source.get_format() == Image.FORMAT_RGBA8, "full material authority is RGBA8")
    _check(crop.get_format() == Image.FORMAT_RGBA8, "playable material crop is RGBA8")
    _check(not crop.has_mipmaps(), "stored playable crop has no baked mipmaps")
    var expected_crop: Image = source.get_region(CROP_RECT)
    _check(crop.get_data() == expected_crop.get_data(), "playable crop is exact rows [896, 3200)")
    for sample: Array in EXPECTED_SAMPLES:
        _check(crop.get_pixelv(sample[0]).is_equal_approx(sample[1]), sample[2])


func _validate_shader() -> void:
    var shader_source: String = FileAccess.get_file_as_string(SHADER_PATH)
    _check(shader_source.contains("filter_linear_mipmap_anisotropic"), "shader uses filtered mip sampling")
    _check(shader_source.contains("texelFetch(material_mask, nearest_sample, 0)"), "shader uses exact footprint samples")
    _check(shader_source.contains("material_weights /= weight_sum"), "shader normalizes actual channel weights")
    _check(shader_source.contains("vec2(-25000.0, -14062.5)"), "shader uses validated terrain origin")
    _check(shader_source.contains("12.20703125"), "shader uses validated sample spacing")
    _check(not shader_source.contains("land_mask"), "biome shader does not depend on land-mask QA")
    _check(not shader_source.contains("diagnostic_mode"), "biome shader has no stale QA branches")


func _validate_scene() -> void:
    _check(
        ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility",
        "project keeps OpenGL Compatibility renderer"
    )
    var packed_scene: Resource = load(SCENE_PATH)
    _check(packed_scene is PackedScene, "biome preview scene loads")
    if not packed_scene is PackedScene:
        return
    var root: Node = (packed_scene as PackedScene).instantiate()
    get_root().add_child(root)
    await process_frame
    _check(root.name == &"AstraBiomePreview", "scene has expected root")
    _check(root.get_script() != null and root.get_script().resource_path == CONTROLLER_PATH, "scene uses dedicated preview controller")
    var terrain: Terrain3D = root.get_node_or_null("Terrain3D") as Terrain3D
    _check(terrain != null, "scene contains Terrain3D")
    if terrain != null:
        _check(terrain.region_size == 128, "Terrain3D region size remains 128")
        _check(is_equal_approx(terrain.vertex_spacing, 12.20703125), "Terrain3D vertex spacing remains exact")
        _check(terrain.data_directory == "res://assets/world_map/astra/terrain_data", "scene reuses validated terrain data")
        _check(terrain.data.get_regions_active().size() == EXPECTED_REGION_COUNT, "scene loads all 576 regions")
        _check(terrain.material.shader_override_enabled, "custom biome shader override is enabled")
    _check(root.get_node_or_null("InspectionCamera") is Camera3D, "scene contains inspection camera")
    _check(root.get_node_or_null("SeaLevelReference") is MeshInstance3D, "scene contains simple sea reference")
    root.queue_free()


func _check(condition: bool, context: String) -> void:
    if not condition:
        _failures += 1
        push_error("%s: expected true." % context)


func _finish() -> void:
    if _failures > 0:
        push_error("Astra biome preview test FAIL: %d assertion(s) failed." % _failures)
        quit(1)
        return
    print("Astra biome preview test PASS: crop, channels, shader, scene, and Terrain3D settings validated.")
    quit(0)
