extends RefCounted
## Offline Fourier waves are streamed through one interpolated volume lookup.
static func load_volume() -> ImageTexture3D:
    var root: String = "res://assets/world_map/astra/natural_world/atmosphere"
    var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("ocean_spectrum.json")))
    var packed: PackedByteArray = FileAccess.get_file_as_bytes(root.path_join("ocean_spectrum.deflate"))
    var raw: PackedByteArray = packed.decompress(int(record.bytes),FileAccess.COMPRESSION_DEFLATE)
    assert(raw.size() == int(record.bytes),"Ocean spectrum failed to decompress.")
    var size: Array = record.size
    var slice_size: int = int(size[0])*int(size[1])*4
    var images: Array[Image] = []
    for z: int in range(int(size[2])):
        images.append(Image.create_from_data(int(size[0]),int(size[1]),false,Image.FORMAT_RGBA8,raw.slice(z*slice_size,(z+1)*slice_size)))
    var volume: ImageTexture3D = ImageTexture3D.new()
    volume.create(Image.FORMAT_RGBA8,int(size[0]),int(size[1]),int(size[2]),false,images)
    return volume
