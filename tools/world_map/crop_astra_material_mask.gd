extends SceneTree


const SOURCE_PATH: String = "res://assets/world_map/astra/source/FCAH_Materials_RGBA.png"
const OUTPUT_PATH: String = "res://assets/world_map/astra/source/FCAH_Materials_Playable_4096x2304_RGBA.png"
const EXPECTED_SOURCE_SHA256: String = "7add3a96942e23a05957d4cbb37742eec868795765b4f8830c03ede41779a899"
const SOURCE_SIZE: Vector2i = Vector2i(4096, 4096)
const CROP_RECT: Rect2i = Rect2i(0, 896, 4096, 2304)


func _initialize() -> void:
    if FileAccess.get_sha256(SOURCE_PATH) != EXPECTED_SOURCE_SHA256:
        _fail("The project-local material mask does not match the Astra authority hash.", 1)
        return
    var source: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
    if source.is_empty() or source.get_size() != SOURCE_SIZE or source.get_format() != Image.FORMAT_RGBA8:
        _fail("The Astra material mask is not a 4096x4096 RGBA8 image.", 2)
        return
    var crop: Image = source.get_region(CROP_RECT)
    if crop.get_size() != CROP_RECT.size or crop.get_format() != Image.FORMAT_RGBA8:
        _fail("The playable material crop is not a 4096x2304 RGBA8 image.", 3)
        return
    if crop.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) != OK:
        _fail("Could not save the playable material-mask crop.", 4)
        return
    var readback: Image = Image.load_from_file(ProjectSettings.globalize_path(OUTPUT_PATH))
    if (
        readback.get_size() != crop.get_size()
        or readback.get_format() != crop.get_format()
        or readback.get_data() != crop.get_data()
    ):
        _fail("The saved playable material crop failed byte-exact RGBA readback.", 5)
        return
    print(
        "Astra material crop PASS: rows [896, 3200), %s, SHA-256 %s."
        % [readback.get_size(), FileAccess.get_sha256(OUTPUT_PATH)]
    )
    quit(0)


func _fail(message: String, exit_code: int) -> void:
    push_error(message)
    quit(exit_code)
