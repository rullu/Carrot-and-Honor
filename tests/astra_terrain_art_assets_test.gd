extends SceneTree


const ROOT: String = "res://assets/world_map/terrain_materials/art_preview"
const EXPECTED_NAMES: Array[String] = ["Grass001","sparse_grass","withered_grass","dirt_aerial_03","sand_03","aerial_rocks_02","rock_05","aerial_grass_rock"]
var failures: Array[String] = []


func _initialize() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("texture_manifest.json")))
    if not parsed is Dictionary:
        push_error("Missing art manifest.")
        quit(1)
        return
    var manifest: Dictionary = parsed
    _check(manifest.version == 2 and manifest.materials.size() == 8,"Manifest version or material count changed.")
    _check(manifest.height_source_sha256 == "5a1a895081e2cf24fe1466b2a0cf036b04908afad57dfff01f50b366f63a3dbc","Wrong relief authority.")
    var context: Image = Image.load_from_file(ProjectSettings.globalize_path(ROOT.path_join("surface_context_rgba.png")))
    _check(context.get_size() == Vector2i(4096,2304) and context.get_format() == Image.FORMAT_RGBA8,"Context is not the exact linear RGBA8 playable grid.")
    _check(FileAccess.get_sha256(ROOT.path_join("surface_context_rgba.png")) == manifest.context_sha256,"Derived context hash mismatch.")
    for index: int in range(manifest.materials.size()):
        var entry: Dictionary = manifest.materials[index]
        _check(entry.name == EXPECTED_NAMES[index] and entry.layer == index,"Layer order changed.")
        for source_name: String in entry.sources:
            var source_path: String = "res://assets/world_map/terrain_materials/%s/%s" % [entry.name,source_name]
            _check(FileAccess.get_sha256(source_path) == entry.sources[source_name],"Source texture changed: "+source_path)
        for map_index: int in range(2):
            var path: String = entry.production_albedo if map_index == 0 else entry.production_normal_roughness
            var packed: Image = load(path) as Image
            if packed == null:
                failures.append("Missing compressed image: "+path)
                continue
            _check(packed.get_size() == Vector2i(2048,2048) and packed.get_mipmap_count() == 11,"Invalid 2K mip chain: "+path)
            _check(packed.get_format() == (Image.FORMAT_DXT1 if map_index == 0 else Image.FORMAT_DXT5),"Lost block compression: "+path)
            _check(packed.get_data().size() == (2796216 if map_index == 0 else 5592432),"Truncated BC mip payload: "+path)
    var shader: String = FileAccess.get_file_as_string("res://src/presentation/world_map/astra_terrain_art.gdshader")
    var baseline: String = FileAccess.get_file_as_string("res://src/presentation/world_map/astra_biome_preview.gdshader")
    var vertex: RegEx = RegEx.new()
    vertex.compile("void vertex\\(\\) \\{[\\s\\S]*?\\n\\}")
    var actual_vertex: RegExMatch = vertex.search(shader)
    var baseline_vertex: RegExMatch = vertex.search(baseline)
    _check(actual_vertex != null and baseline_vertex != null,"Could not find Terrain3D vertex kernels.")
    if actual_vertex != null and baseline_vertex != null:
        _check(actual_vertex.get_string() == baseline_vertex.get_string(),"Authoritative Terrain3D vertex path was altered.")
    _check(shader.contains("vec2(-25000.0, -14062.5)") and shader.contains("12.20703125"),"Art mapping constants changed.")
    _check(not shader.contains("SCREEN_UV") and not shader.contains("render_mode unshaded"),"A temporary visual probe remains installed.")
    for failure: String in failures:
        push_error(failure)
    print("ASTRA_TERRAIN_ART_ASSETS_PASS: 24 source hashes, 16 compressed mip payloads, aligned context and unchanged vertex kernel" if failures.is_empty() else "ASTRA_TERRAIN_ART_ASSETS_FAIL")
    quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
