extends Node3D
## Sparse obstacle reactions are culled individually; textures and plane geometry are shared.

func build(textures: Dictionary) -> void:
    var root: String = "res://assets/world_map/astra/natural_world"
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("shore_details.json")))
    var beauty: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("beauty_composition.json")))
    data.wakes.append_array(beauty.wakes)
    var plane: PlaneMesh = PlaneMesh.new()
    plane.size = Vector2.ONE
    for index: int in range(data.wakes.size()):
        var wake: Dictionary = data.wakes[index]
        var material: ShaderMaterial = ShaderMaterial.new()
        material.shader = preload("res://src/presentation/world_map/astra_water_reactions.gdshader")
        material.set_shader_parameter("shore_distance",textures.shore_distance)
        material.set_shader_parameter("water_features",textures.water_features)
        material.set_shader_parameter("reaction_data",Vector3(maxf(float(wake.strength),.90),float(index)*.173,1.0 if wake.river else 0.0))
        var yaw: float = atan2(wake.flow[0],wake.flow[1])
        var basis: Basis = Basis(Vector3.UP,yaw).scaled(Vector3(wake.width,1.0,wake.length))
        basis.x.y=basis.x.x*float(wake.slope[0])+basis.x.z*float(wake.slope[1])
        basis.z.y=basis.z.x*float(wake.slope[0])+basis.z.z*float(wake.slope[1])
        var instance: MeshInstance3D = MeshInstance3D.new()
        instance.name = "Obstacle_%02d" % index
        instance.mesh = plane
        instance.material_override = material
        instance.transform = Transform3D(basis,Vector3(wake.x,wake.y,wake.z))
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(instance)
