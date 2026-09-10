extends SceneTree


const ROOT: String = "res://assets/world_map/terrain_materials/art_preview"


func _initialize() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Array GPU validation requires a display. Run this builder without --headless.")
        quit(1)
        return
    var staging: String = "C:/Projects/FCAH_ASTRA_WORKSPACE/07_Astra_Work/TerrainArt/packed"
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--source-dir="):
            staging = argument.trim_prefix("--source-dir=")
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(staging.path_join("texture_manifest.json")))
    if not parsed is Dictionary:
        push_error("Art texture manifest is missing. Run prepare_astra_art_support.py first.")
        quit(1)
        return
    var albedos: Array[Image] = []
    var normals: Array[Image] = []
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT.path_join("layers")))
    for entry: Dictionary in parsed.materials:
        var colour_bytes: PackedByteArray = FileAccess.get_file_as_bytes(staging.path_join(entry.name + "_albedo_mips.bin"))
        var normal_bytes: PackedByteArray = FileAccess.get_file_as_bytes(staging.path_join(entry.name + "_normal_roughness_mips.bin"))
        if colour_bytes.size() != 16777215 or normal_bytes.size() != 22369620:
            push_error("Missing or truncated mip payload for " + String(entry.name))
            quit(1)
            return
        var albedo: Image = Image.create_from_data(2048, 2048, true, Image.FORMAT_RGB8, colour_bytes)
        var packed: Image = Image.create_from_data(2048, 2048, true, Image.FORMAT_RGBA8, normal_bytes)
        if albedo.get_size() != Vector2i(2048, 2048) or packed.get_size() != albedo.get_size():
            push_error("Art array source dimensions are incorrect.")
            quit(1)
            return
        # Python creates colour mips in linear light and re-encodes as sRGB;
        # normal mips average signed vectors and renormalize before encoding.
        var albedo_error: Error = albedo.compress(Image.COMPRESS_S3TC)
        var normal_error: Error = packed.compress(Image.COMPRESS_S3TC)
        if albedo_error != OK or normal_error != OK:
            push_error("S3TC texture packing failed.")
            quit(1)
            return
        albedos.append(albedo)
        normals.append(packed)
    # Save the CPU-side compressed Images directly. Saving a Texture2DArray
    # performs GPU readback, which expands BC data to RGBA8 in Compatibility.
    if not _save_array(albedos, "albedo_srgb") or not _save_array(normals, "normal_roughness"):
        push_error("Could not save compressed art resources.")
        quit(1)
        return
    var saved: Texture2DArray = ResourceLoader.load(ROOT.path_join("albedo_srgb.tres"), "Texture2DArray", ResourceLoader.CACHE_MODE_IGNORE) as Texture2DArray
    var saved_normal: Texture2DArray = ResourceLoader.load(ROOT.path_join("normal_roughness.tres"), "Texture2DArray", ResourceLoader.CACHE_MODE_IGNORE) as Texture2DArray
    if saved == null or saved_normal == null or saved.get_layers() != 8 or saved_normal.get_layers() != 8 or saved.get_format() != Image.FORMAT_DXT1 or saved_normal.get_format() != Image.FORMAT_DXT5:
        push_error("Serialized texture arrays failed GPU format/layer validation.")
        quit(1)
        return
    print("ASTRA_ART_ARRAYS_PASS: eight 2K layers; sRGB albedo BC1, linear NormalGL/roughness BC3; full mip chains.")
    quit(0)


func _save_array(images: Array[Image], name_prefix: String) -> bool:
    var contents: String = "[gd_resource type=\"Texture2DArray\" load_steps=9 format=3]\n\n"
    var references: PackedStringArray = []
    for index: int in range(images.size()):
        var image_path: String = ROOT.path_join("layers/%s_%d.res" % [name_prefix,index])
        if ResourceSaver.save(images[index], image_path) != OK:
            return false
        var restored: Image = ResourceLoader.load(image_path, "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
        if restored == null or restored.get_data() != images[index].get_data() or restored.get_format() != images[index].get_format():
            return false
        contents += "[ext_resource type=\"Image\" path=\"%s\" id=\"%d\"]\n" % [image_path,index+1]
        references.append("ExtResource(\"%d\")" % (index+1))
    contents += "\n[resource]\n_images = Array[Image]([%s])\n" % ", ".join(references)
    var output: FileAccess = FileAccess.open(ROOT.path_join(name_prefix+".tres"), FileAccess.WRITE)
    if output == null:
        return false
    output.store_string(contents)
    output.close()
    return true
