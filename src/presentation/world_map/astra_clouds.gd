extends Node3D
## Sparse finite cumulus volumes. Cloud and shadow motion share one presentation clock.
const ROOT: String = "res://assets/world_map/astra/natural_world/atmosphere"
var _clouds: Array[MeshInstance3D] = []
var _origins: Array[Vector3] = []
var _elapsed: float = 0.0
var _shadow_texture: ImageTexture
var _materials: Array[ShaderMaterial] = []
var _view_size: float = -1.0

func build() -> void:
    var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("clouds.json")))
    var size: Array = record.volume_size
    var slice_bytes: int = int(size[0])*int(size[1])*4
    var materials: Array[ShaderMaterial] = []
    for variant: int in range(int(record.variants)):
        var bytes: PackedByteArray = FileAccess.get_file_as_bytes(ROOT.path_join("cumulus_volume_%d.rgba8" % variant))
        var images: Array[Image] = []
        for z: int in range(int(size[2])):
            images.append(Image.create_from_data(int(size[0]),int(size[1]),false,Image.FORMAT_RGBA8,bytes.slice(z*slice_bytes,(z+1)*slice_bytes)))
        var volume: ImageTexture3D = ImageTexture3D.new()
        volume.create(Image.FORMAT_RGBA8,int(size[0]),int(size[1]),int(size[2]),false,images)
        var material: ShaderMaterial = ShaderMaterial.new()
        material.shader = load("res://src/presentation/world_map/astra_cloud_volume.gdshader") as Shader
        material.set_shader_parameter("density_volume",volume)
        materials.append(material)
    _materials = materials
    var plane: PlaneMesh = PlaneMesh.new()
    # Margin accommodates parallax at the 40-degree camera and top-down inspection.
    plane.size = Vector2(1.55,1.75)
    var shadow_image: Image = Image.load_from_file(ProjectSettings.globalize_path(ROOT.path_join("cloud_shadow.png")))
    shadow_image.generate_mipmaps()
    _shadow_texture = ImageTexture.create_from_image(shadow_image)
    RenderingServer.global_shader_parameter_set("astra_cloud_shadow",_shadow_texture)
    for tz: int in range(-3,3):
        for tx: int in range(-4,4):
            for entry: Dictionary in record.clouds:
                var origin: Vector3 = Vector3(float(entry.xz[0])+tx*7500.0,325.0,float(entry.xz[1])+tz*6000.0)
                var cloud: MeshInstance3D = MeshInstance3D.new()
                cloud.mesh = plane
                cloud.material_override = materials[int(entry.variant)]
                cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                cloud.position = origin
                cloud.rotation.y = entry.angle
                cloud.scale = Vector3(entry.size[0],entry.size[1],entry.size[2])
                cloud.custom_aabb = AABB(Vector3(-.8,-.5,-.9),Vector3(1.6,1.0,1.8))
                add_child(cloud)
                _clouds.append(cloud)
                _origins.append(origin)

func _process(delta: float) -> void:
    _elapsed += delta
    RenderingServer.global_shader_parameter_set("astra_atmosphere_time",_elapsed)
    var camera: Camera3D = get_viewport().get_camera_3d()
    if camera != null and not is_equal_approx(camera.size,_view_size):
        _view_size = camera.size
        var opacity: float = lerpf(.65,.84,smoothstep(800.0,2600.0,_view_size))
        for material: ShaderMaterial in _materials:
            material.set_shader_parameter("cloud_opacity",opacity)
    var drift: Vector3 = Vector3(3.0,0.0,1.2)*_elapsed
    for index: int in range(_clouds.size()):
        var point: Vector3 = _origins[index]+drift
        point.x = wrapf(point.x,-30000.0,30000.0)
        point.z = wrapf(point.z,-18000.0,18000.0)
        _clouds[index].position = point
