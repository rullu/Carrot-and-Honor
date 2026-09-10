extends SceneTree


const SOURCE_HEIGHTMAP: String = "res://assets/world_map/astra/source/FCAH_Height_Playable_4096x2304_F32.exr"
const EXPECTED_SOURCE_SHA256: String = "5a1a895081e2cf24fe1466b2a0cf036b04908afad57dfff01f50b366f63a3dbc"
const DATA_DIRECTORY: String = "res://assets/world_map/astra/terrain_data"
const SOURCE_SIZE: Vector2i = Vector2i(4096, 2304)
const EXPECTED_REGION_COUNT: int = 576
const VERTEX_SPACING: float = 12.20703125
const HEIGHT_SCALE: float = 256.0
const HEIGHT_OFFSET: float = -6.4
const IMPORT_ORIGIN: Vector3 = Vector3(-25000.0, 0.0, -14062.5)


func _initialize() -> void:
    call_deferred("_run_import")


func _run_import() -> void:
    var existing_files: PackedStringArray = DirAccess.get_files_at(DATA_DIRECTORY)
    if not existing_files.is_empty():
        push_error(
            "Refusing to overwrite %d existing terrain files in %s."
            % [existing_files.size(), DATA_DIRECTORY]
        )
        quit(1)
        return

    if FileAccess.get_sha256(SOURCE_HEIGHTMAP) != EXPECTED_SOURCE_SHA256:
        push_error("The project-local heightmap does not match the Astra authority hash.")
        quit(2)
        return

    var height_image: Image = Terrain3DUtil.load_image(SOURCE_HEIGHTMAP)
    if height_image.is_empty() or height_image.get_size() != SOURCE_SIZE:
        push_error("The Astra heightmap did not decode as a 4096x2304 image.")
        quit(3)
        return

    var terrain: Terrain3D = Terrain3D.new()
    terrain.vertex_spacing = VERTEX_SPACING
    terrain.save_16_bit = false
    get_root().add_child(terrain)

    var camera: Camera3D = Camera3D.new()
    camera.current = true
    get_root().add_child(camera)
    await process_frame
    terrain.set_camera(camera)
    terrain.region_size = 128

    var images: Array[Image] = []
    images.resize(Terrain3DRegion.TYPE_MAX)
    images[Terrain3DRegion.TYPE_HEIGHT] = height_image
    terrain.data.import_images(images, IMPORT_ORIGIN, HEIGHT_OFFSET, HEIGHT_SCALE)
    terrain.data.calc_height_range(true)

    var region_count: int = terrain.data.get_regions_active().size()
    if region_count != EXPECTED_REGION_COUNT:
        push_error("Expected %d regions, imported %d." % [EXPECTED_REGION_COUNT, region_count])
        quit(4)
        return

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIRECTORY))
    terrain.data.save_directory(DATA_DIRECTORY)
    print(
        "Astra terrain import complete: %d float32 regions, height range %s."
        % [region_count, terrain.data.get_height_range()]
    )
    terrain.queue_free()
    quit(0)
