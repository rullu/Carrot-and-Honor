extends Node3D
## Deterministic miniature botanical meshes and spatially batched presentation instances.

const ROOT: String = "res://assets/world_map/astra/natural_world"
const PROP_SHADER: Shader = preload("res://src/presentation/world_map/astra_natural_props.gdshader")
const ROCK_GEOMETRY: GDScript = preload("res://src/presentation/world_map/astra_rock_geometry.gd")
const ROCK_SHADER: Shader = preload("res://src/presentation/world_map/astra_rock_surface.gdshader")
var instance_count: int = 0
var batch_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _surface: SurfaceTool
var _materials: Dictionary = {}
var _combined_materials: Dictionary = {}
var _full_meshes: Array[ArrayMesh] = []
var _far_meshes: Array[ArrayMesh] = []
var _medium_meshes: Array[ArrayMesh] = []
var _wide_meshes: Array[ArrayMesh] = []
var _batch_mesh_ids: Array[int] = []
var _overview: bool = false
var _detail_level: int = 0
var _overview_root: Node3D
const BOTANICAL: Shader = preload("res://src/presentation/world_map/astra_botanical.gdshader")
const LIBRARY: String = "res://assets/world_map/nature_library/quaternius"
const TILE: float = 1200.0


func build() -> void:
    var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("natural_instances.json")))
    var additions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("shore_details.json")))
    record.instances.append_array(additions.instances)
    var beauty: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("beauty_composition.json")))
    record.instances.append_array(beauty.instances)
    var omitted: Dictionary = {}
    for index: int in beauty.omitted: omitted[index] = true
    var composed: Array[Array] = []
    for index: int in range(record.instances.size()):
        if omitted.has(index): continue
        var entry: Array = record.instances[index].duplicate()
        var shaping: Dictionary = beauty.rock_overrides.get(str(index),{})
        var proportions: Vector3 = Vector3.ONE
        if not shaping.is_empty():
            entry[2] = float(entry[2])-float(shaping.burial)
            proportions = Vector3(shaping.scale[0],shaping.scale[1],shaping.scale[2])
        entry.append(proportions)
        composed.append(entry)
    record.instances = composed
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = PROP_SHADER
    var meshes: Array[ArrayMesh] = []
    for kind: int in range(21):
        for variant: int in range(3):
            var source: ArrayMesh = _make_mesh(kind, variant, material)
            meshes.append(_merge_botanical(source))
            _medium_meshes.append(_merge_botanical(_canopy_lod(source,4,1.70)))
            _wide_meshes.append(_merge_botanical(_canopy_lod(source,8,2.05)))
            _far_meshes.append(_overview_mesh(kind,variant,material))
    _full_meshes = meshes
    var groups: Dictionary = {}
    for entry: Array in record.instances:
        var mesh_id: int = int(entry[0])*3+int(entry[7])
        var tile: Vector2i = Vector2i(floori(float(entry[1])/TILE), floori(float(entry[3])/TILE))
        var key: String = "%d:%d:%d" % [mesh_id, tile.x, tile.y]
        if not groups.has(key):
            groups[key] = {"mesh":mesh_id, "tile":tile, "entries":[]}
        groups[key].entries.append(entry)
    for key: String in groups:
        var group: Dictionary = groups[key]
        var multimesh: MultiMesh = MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.use_colors = true
        multimesh.use_custom_data = true
        multimesh.mesh = meshes[group.mesh]
        multimesh.instance_count = group.entries.size()
        var origin: Vector3 = Vector3(group.tile.x*TILE,0,group.tile.y*TILE)
        var mesh_bounds: AABB = multimesh.mesh.get_aabb()
        var bounds: AABB = AABB()
        for index: int in range(group.entries.size()):
            var entry: Array = group.entries[index]
            var size: float = entry[4]
            var basis: Basis = Basis(Vector3.UP, float(entry[5])).scaled(Vector3(size*.92,size,size)*Vector3(entry[8]))
            var position: Vector3 = Vector3(entry[1],entry[2],entry[3])-origin
            var transform: Transform3D = Transform3D(basis,position)
            multimesh.set_instance_transform(index,transform)
            var instance_bounds: AABB = transform*mesh_bounds
            bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
            var value: float = entry[6]
            multimesh.set_instance_color(index,Color(value,value*(.98+float(entry[7])*.015),value*.97,1))
            multimesh.set_instance_custom_data(index,Color(float(entry[5])/TAU,0,0,0))
        multimesh.custom_aabb = bounds.grow(10.0)
        var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
        instance.name = "NaturalBatch_"+key.replace(":","_").replace("-","n")
        instance.multimesh = multimesh
        instance.position = origin
        add_child(instance)
        _batch_mesh_ids.append(int(group.mesh))
        instance_count += group.entries.size()
    batch_count = groups.size()
    _build_overview(record.instances)


func _build_overview(entries: Array) -> void:
    _overview_root = Node3D.new()
    _overview_root.name = "ContinentOverviewBatches"
    _overview_root.visible = false
    add_child(_overview_root)
    var groups: Dictionary = {}
    for entry: Array in entries:
        var id: int = int(entry[0])*3+int(entry[7])
        if not groups.has(id): groups[id] = []
        groups[id].append(entry)
    for id: int in groups:
        var multimesh: MultiMesh = MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.use_colors = true
        multimesh.use_custom_data = true
        multimesh.mesh = _far_meshes[id]
        multimesh.instance_count = groups[id].size()
        for index: int in range(groups[id].size()):
            var entry: Array = groups[id][index]
            var basis: Basis = Basis(Vector3.UP,float(entry[5])).scaled(Vector3(entry[4]*.92,entry[4],entry[4])*Vector3(entry[8]))
            multimesh.set_instance_transform(index,Transform3D(basis,Vector3(entry[1],entry[2],entry[3])))
            multimesh.set_instance_color(index,Color(entry[6],entry[6]*(.98+entry[7]*.015),entry[6]*.97,1))
            multimesh.set_instance_custom_data(index,Color(entry[5]/TAU,0,0,0))
        multimesh.custom_aabb = AABB(Vector3(-25150,-20,-14200),Vector3(50300,450,28400))
        var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
        instance.multimesh = multimesh
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _overview_root.add_child(instance)


func _curated_mesh(kind: int, variant: int, _material: Material) -> ArrayMesh:
    var catalogue: Array[Array] = [
        ["CommonTree_1","CommonTree_3","CommonTree_5"], ["Pine_1","Pine_2","Pine_3"],
        ["TwistedTree_1","TwistedTree_3","TwistedTree_4"], ["Bush_Common","Bush_Common_Flowers","Fern_1"],
        ["Rock_Medium_1","Rock_Medium_2","Rock_Medium_3"], ["Rock_Medium_1","Rock_Medium_2","Rock_Medium_3"],
        ["CommonTree_2","CommonTree_4","CommonTree_5"], ["Pine_4","Pine_5","Pine_2"],
        [],[], ["TwistedTree_2","TwistedTree_4","Bush_Common"], ["DeadTree_1","DeadTree_3","DeadTree_1"],
        ["Bush_Common_Flowers","Grass_Common_Short","Bush_Common"], ["Grass_Wispy_Short","Grass_Common_Short","Grass_Wispy_Short"],
        ["TwistedTree_5","TwistedTree_1","CommonTree_1"], [],[], ["Rock_Medium_1","Rock_Medium_2","Rock_Medium_3"],
        ["DeadTree_3","DeadTree_1","DeadTree_3"], ["Flower_3_Group","Grass_Common_Short","Fern_1"]]
    var filename: String = catalogue[kind][variant]
    var packed: PackedScene = load(LIBRARY.path_join(filename+".gltf")) as PackedScene
    var model: Node3D = packed.instantiate() as Node3D
    var nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
    if model is MeshInstance3D:
        nodes.append(model)
    var mesh_instance: MeshInstance3D = nodes[0] as MeshInstance3D
    var original: Mesh = mesh_instance.mesh
    var bounds: AABB = original.get_aabb()
    var height: float = maxf(bounds.size.y,.01)
    var mesh: ArrayMesh = ArrayMesh.new()
    for surface: int in range(original.get_surface_count()):
        var arrays: Array = original.surface_get_arrays(surface)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        for index: int in range(vertices.size()):
            vertices[index] = (vertices[index]-Vector3(0,bounds.position.y,0))/height
            if kind in [0,2,14]: vertices[index] *= Vector3(1.35,1.0,1.35)
            if kind == 6: vertices[index] *= Vector3(.82,1.15,.82)
            if kind == 7: vertices[index] *= Vector3(1.55,.88,1.55)
            if kind == 10: vertices[index] *= Vector3(1.4,.68,1.4)
            if kind == 17: vertices[index] *= Vector3(.85,1.5,.82)
        arrays[Mesh.ARRAY_VERTEX] = vertices
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        var old_material: StandardMaterial3D = original.surface_get_material(surface) as StandardMaterial3D
        var leaf: bool = old_material.resource_name.begins_with("Leaves") or old_material.resource_name.begins_with("Bush") or kind in [3,12,13,19]
        var key: String = old_material.resource_name+str(kind)
        if not _materials.has(key):
            var material: ShaderMaterial = ShaderMaterial.new()
            material.resource_name = old_material.resource_name
            material.shader = BOTANICAL
            material.set_shader_parameter("botanical_colour",old_material.albedo_texture)
            material.set_shader_parameter("foliage",leaf)
            material.set_shader_parameter("leaf_canopy",old_material.resource_name.begins_with("Leaves"))
            material.set_shader_parameter("pale_bark",kind == 6 and not leaf)
            material.set_shader_parameter("warm_stone",kind == 5)
            material.set_shader_parameter("wind",0.0 if kind in [4,5,17,18] else 1.0)
            var tint: Color = Color(.38,.49,.255)
            if kind in [1,7]: tint = Color(.28,.405,.335)
            if kind in [2,10]: tint = Color(.465,.505,.31)
            if kind == 6: tint = Color(.48,.57,.32)
            if kind in [3,12,13,19]: tint = Color(.43,.48,.28)
            if kind == 12: tint = Color(.48,.43,.34)
            if not leaf: tint = Color(.90,.84,.73)
            if kind in [4,17]: tint = Color(.88,.88,.83)
            if kind == 5:
                material.set_shader_parameter("botanical_colour",load(LIBRARY.path_join("Rocks_Desert_Diffuse.png")))
                tint = Color(.96,.89,.76)
            material.set_shader_parameter("tint",tint)
            if kind in [4,5,17]:
                material.shader = ROCK_SHADER
                material.set_shader_parameter("stone_colour",load(LIBRARY.path_join("Rocks_Desert_Diffuse.png")) if kind == 5 else old_material.albedo_texture)
                material.set_shader_parameter("tint",tint)
                material.set_shader_parameter("warm_stone",kind == 5)
            _materials[key] = material
        mesh.surface_set_material(surface,_materials[key])
    model.free()
    var importer: ImporterMesh = ImporterMesh.from_mesh(mesh)
    importer.generate_lods(65.0,25.0,[])
    if kind in [4,5,17]:
        return ROCK_GEOMETRY.faceted(importer)
    var result: ArrayMesh = ArrayMesh.new()
    for surface: int in range(importer.get_surface_count()):
        var material: ShaderMaterial = importer.get_surface_material(surface) as ShaderMaterial
        var lods: Dictionary = {}
        # Leaf-card topology is not safely simplified by triangle collapse: it
        # makes healthy crowns look bare. Trunks retain the generated LODs.
        if not bool(material.get_shader_parameter("foliage")):
            for level: int in range(importer.get_surface_lod_count(surface)):
                lods[importer.get_surface_lod_size(surface,level)] = importer.get_surface_lod_indices(surface,level)
        var arrays: Array = importer.get_surface_arrays(surface)
        if not bool(material.get_shader_parameter("foliage")) and kind not in [4,5,17]:
            # Bark is a few pixels wide at the closest useful camera. Preserve
            # the branch silhouette while removing invisible radial subdivisions.
            for level: int in range(importer.get_surface_lod_count(surface)):
                var indices: PackedInt32Array = importer.get_surface_lod_indices(surface,level)
                if indices.size() >= 900:
                    arrays[Mesh.ARRAY_INDEX] = indices
            lods = {}
        result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
        result.surface_set_material(surface,material)
    return result


func _canopy_lod(mesh: ArrayMesh, stride: int, expansion: float) -> ArrayMesh:
    var result: ArrayMesh = ArrayMesh.new()
    for surface: int in range(mesh.get_surface_count()):
        var material: Material = mesh.surface_get_material(surface)
        var arrays: Array = mesh.surface_get_arrays(surface)
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        if material is ShaderMaterial and material.shader == BOTANICAL and bool(material.get_shader_parameter("leaf_canopy")) and not material.resource_name.contains("Pine") and indices.size()%6 == 0:
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
            var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
            var points: PackedVector3Array = PackedVector3Array()
            var directions: PackedVector3Array = PackedVector3Array()
            var coords: PackedVector2Array = PackedVector2Array()
            # Keep whole alpha cards, enlarge their footprint gently, and retain
            # their original distribution. Triangle collapse destroys leaf masks.
            for card: int in range(0,indices.size(),6*stride):
                var centre: Vector3 = Vector3.ZERO
                for corner: int in range(6): centre+=vertices[indices[card+corner]]/6.0
                for corner: int in range(6):
                    var index: int = indices[card+corner]
                    points.append(centre+(vertices[index]-centre)*expansion)
                    directions.append(normals[index])
                    coords.append(uvs[index])
            arrays = []
            arrays.resize(Mesh.ARRAY_MAX)
            arrays[Mesh.ARRAY_VERTEX] = points
            arrays[Mesh.ARRAY_NORMAL] = directions
            arrays[Mesh.ARRAY_TEX_UV] = coords
        result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        result.surface_set_material(surface,material)
    return result


func _merge_botanical(mesh: ArrayMesh) -> ArrayMesh:
    if mesh.get_surface_count() != 2: return mesh
    var leaf: ShaderMaterial
    var bark: ShaderMaterial
    for surface: int in range(2):
        var material: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
        if material == null or material.shader != BOTANICAL: return mesh
        if bool(material.get_shader_parameter("leaf_canopy")): leaf = material
        else: bark = material
    if leaf == null or bark == null: return mesh
    var key: int = leaf.get_instance_id()
    if not _combined_materials.has(key):
        var material: ShaderMaterial = leaf.duplicate() as ShaderMaterial
        material.set_shader_parameter("combined",true)
        material.set_shader_parameter("bark_colour",bark.get_shader_parameter("botanical_colour"))
        material.set_shader_parameter("bark_tint",bark.get_shader_parameter("tint"))
        material.set_shader_parameter("pale_bark",bark.get_shader_parameter("pale_bark"))
        _combined_materials[key] = material
    var points: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    var coords: PackedVector2Array = PackedVector2Array()
    var colours: PackedColorArray = PackedColorArray()
    var indices: PackedInt32Array = PackedInt32Array()
    for surface: int in range(2):
        var arrays: Array = mesh.surface_get_arrays(surface)
        var offset: int = points.size()
        var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var leaf_flag: float = 1.0 if mesh.surface_get_material(surface) == leaf else 0.0
        var source_colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
        for index: int in range(source.size()):
            var colour: Color = source_colours[index] if source_colours.size() == source.size() else Color.WHITE
            colour.a = leaf_flag
            colours.append(colour)
        points.append_array(source)
        normals.append_array(arrays[Mesh.ARRAY_NORMAL])
        coords.append_array(arrays[Mesh.ARRAY_TEX_UV])
        var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
        if source_indices.is_empty():
            for index: int in range(source.size()): indices.append(offset+index)
        else:
            for index: int in source_indices: indices.append(offset+index)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=points
    arrays[Mesh.ARRAY_NORMAL]=normals
    arrays[Mesh.ARRAY_TEX_UV]=coords
    arrays[Mesh.ARRAY_COLOR]=colours
    arrays[Mesh.ARRAY_INDEX]=indices
    var result: ArrayMesh = ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    result.surface_set_material(0,_combined_materials[key])
    return result


func _triangle(a: Vector3,b: Vector3,c: Vector3,colour: Color) -> void:
    _surface.set_color(colour)
    _surface.add_vertex(a)
    _surface.add_vertex(b)
    _surface.add_vertex(c)


func _ellipsoid(centre: Vector3,radius: Vector3,colour: Color,roughness: float) -> void:
    var points: Array[Vector3] = []
    var sides: int = 8
    var rings: int = 5
    for ring: int in range(rings+1):
        var phi: float = PI*ring/rings
        for side: int in range(sides):
            var theta: float = TAU*side/sides
            var r: float = 1.0+_rng.randf_range(-roughness,roughness)
            points.append(centre+Vector3(sin(phi)*cos(theta),cos(phi),sin(phi)*sin(theta))*radius*r)
    for ring: int in range(rings):
        for side: int in range(sides):
            var a: int = ring*sides+side
            var b: int = ring*sides+(side+1)%sides
            var c: int = a+sides
            var d: int = b+sides
            var shade: Color = colour*_rng.randf_range(.94,1.06)
            _triangle(points[a],points[c],points[b],shade)
            _triangle(points[b],points[c],points[d],shade)


func _stem(start: Vector3,end: Vector3,r0: float,r1: float,colour: Color) -> void:
    var axis: Vector3 = (end-start).normalized()
    var reference: Vector3 = Vector3.UP if absf(axis.y) < .95 else Vector3.RIGHT
    var u: Vector3 = axis.cross(reference).normalized()
    var v: Vector3 = axis.cross(u).normalized()
    for side: int in range(7):
        var a: float = TAU*side/7.0
        var b: float = TAU*(side+1)/7.0
        var va: Vector3 = u*cos(a)+v*sin(a)
        var vb: Vector3 = u*cos(b)+v*sin(b)
        _triangle(start+va*r0,end+vb*r1,end+va*r1,colour)
        _triangle(start+va*r0,start+vb*r0,end+vb*r1,colour)


func _pine_tier(base: float,width: float,height: float,colour: Color) -> void:
    var points: Array[Vector3] = []
    var profile: Array[float] = [.52,1.0,.68,.33,.025]
    for ring: int in range(5):
        for side: int in range(9):
            var angle: float = TAU*side/9.0
            var radius: float = width*profile[ring]*_rng.randf_range(.85,1.13)
            points.append(Vector3(cos(angle)*radius,base+height*ring/4.0+_rng.randf_range(-.015,.015),sin(angle)*radius))
    for ring: int in range(4):
        for side: int in range(9):
            var a: int = ring*9+side
            var b: int = ring*9+(side+1)%9
            _triangle(points[a],points[b+9],points[a+9],colour)
            _triangle(points[a],points[b],points[b+9],colour)


func _make_mesh(kind: int, variant: int, material: Material) -> ArrayMesh:
    if kind not in [8,9,15,16,20]:
        return _curated_mesh(kind,variant,material)
    _rng.seed = 796959858+kind*73+variant*977
    _surface = SurfaceTool.new()
    _surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    if kind in [15,16]:
        if not _materials.has("still_stone"):
            var still: ShaderMaterial = material.duplicate() as ShaderMaterial
            still.set_shader_parameter("wind",0.0)
            _materials["still_stone"] = still
        _surface.set_material(_materials["still_stone"])
    else:
        _surface.set_material(material)
    if kind == 20:
        _reed_clump(variant)
    elif kind == 8:
        _stem(Vector3.ZERO,Vector3(.02,.98,0),.033,.006,Color(.34,.29,.19))
        for tier: int in range(8):
            var y: float = .25+tier*.088
            var radius: float = .16*(1.0-float(tier)/10.0)
            _ellipsoid(Vector3(sin(tier)*.017,y,0),Vector3(radius,.19,radius*.86),Color(.24,.34,.18)*(1.0+tier*.023),.05)
    elif kind == 9:
        for segment: int in range(8):
            var a: float = segment/8.0
            var b: float = (segment+1)/8.0
            _stem(Vector3(.16*a*a,a*.80,0),Vector3(.16*b*b,b*.80,0),.034*(1-a*.35),.034*(1-b*.35),Color(.43,.34,.21))
        for frond: int in range(10):
            var angle: float = frond*TAU/10.0+variant*.42+_rng.randf_range(-.18,.18)
            var direction: Vector3 = Vector3(cos(angle),0,sin(angle))
            var side: Vector3 = Vector3(-sin(angle),0,cos(angle))
            var reach: float = _rng.randf_range(.45,.67)
            var lift: float = _rng.randf_range(.22,.39)
            var previous: Vector3 = Vector3(.16,.80,0)
            for segment: int in range(1,12):
                var t: float = segment/11.0
                var centre: Vector3 = Vector3(.16,.80+lift*sin(t*2.5)-.20*t,0)+direction*t*reach
                _stem(previous,centre,.0045*(1-t*.7),.003*(1-t*.7),Color(.32,.39,.17))
                var width: float = sin(pow(t,.65)*PI)*_rng.randf_range(.12,.18)
                var leaf_colour: Color = Color(.30,.405,.19)*_rng.randf_range(.88,1.08)
                # Separate drooping pinnae, with air between them and no fan-like sheet.
                for sign_side: int in [-1,1]:
                    var root: Vector3 = previous.lerp(centre,.35)
                    var tip: Vector3 = centre+side*width*sign_side+direction*.052-Vector3.UP*(.025+t*.050)
                    var mid: Vector3 = root.lerp(tip,.52)+Vector3.UP*.013
                    _triangle(root,mid-direction*.014,tip,leaf_colour)
                    _triangle(root,tip,mid+direction*.015,leaf_colour*.95)
                previous = centre
    elif kind == 15:
        if variant == 2:
            _stone_block(Vector3(0,.12,0),Vector3(.46,.14,.15),Color(.47,.48,.42))
        else:
            _stone_block(Vector3(.02,.43,0),Vector3(.16,.45,.13),Color(.50,.515,.455))
            _stone_block(Vector3(.0,.91,.015),Vector3(.12,.075,.11),Color(.55,.555,.49))
    elif kind == 16:
        # A broken ancient arch is a single isolated environmental remnant.
        var colour: Color = Color(.59,.55,.43) if variant == 1 else Color(.63,.49,.33)
        for pillar: int in [-1,1]:
            for course: int in range(4):
                _stone_block(Vector3(pillar*.38,.09+course*.16,0),Vector3(.115,.085,.13),colour)
        for stone: int in range(9):
            var a: float = stone*PI/9.0+.012
            var b: float = (stone+1)*PI/9.0-.012
            var p: Array[Vector3] = []
            for depth: float in [-.14,.14]:
                for radius: float in [.255,.515]:
                    for angle: float in [a,b]:
                        p.append(Vector3(cos(angle)*radius,.62+sin(angle)*radius,depth)+Vector3(_rng.randf_range(-.006,.006),_rng.randf_range(-.006,.006),0))
            for face: Array in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
                _triangle(p[face[0]],p[face[1]],p[face[2]],colour)
                _triangle(p[face[0]],p[face[2]],p[face[3]],colour)
        _stone_block(Vector3(.19,.045,.27),Vector3(.17,.08,.12),colour*.88)
    _surface.generate_normals()
    _surface.index()
    return _surface.commit()


func _stone_block(c: Vector3,r: Vector3,colour: Color) -> void:
    var p: Array[Vector3] = []
    for y: int in [-1,1]:
        for z: int in [-1,1]:
            for x: int in [-1,1]:
                p.append(c+Vector3(x,y,z)*r*Vector3(_rng.randf_range(.90,1.08),_rng.randf_range(.93,1.07),_rng.randf_range(.90,1.08)))
    var faces: Array[Array] = [[0,2,3,1],[4,5,7,6],[0,1,5,4],[2,6,7,3],[0,4,6,2],[1,3,7,5]]
    for f: Array in faces:
        _triangle(p[f[0]],p[f[1]],p[f[2]],colour)
        _triangle(p[f[0]],p[f[2]],p[f[3]],colour)


func _reed_clump(variant: int) -> void:
    for stalk: int in range(11):
        var angle: float = _rng.randf()*TAU
        var base: Vector3 = Vector3(cos(angle),0,sin(angle))*_rng.randf_range(.05,.31)
        var height: float = _rng.randf_range(.54,1.0)
        var tip: Vector3 = base+Vector3(cos(angle)*.10,height,sin(angle)*.10)
        var green: Color = Color(.30,.37,.17)*_rng.randf_range(.85,1.15)
        _stem(base,tip,.009,.004,green)
        for leaf: int in range(3):
            var root: Vector3 = base.lerp(tip,.20+leaf*.20)
            var direction: Vector3 = Vector3(cos(angle+leaf*2.1),0,sin(angle+leaf*2.1))
            var side: Vector3 = Vector3(-direction.z,0,direction.x)*.023
            var bend: Vector3 = root+direction*.16+Vector3.UP*.20
            var end: Vector3 = root+direction*.31+Vector3.UP*.08
            _triangle(root,bend+side,bend-side,green)
            _triangle(bend+side,end,bend-side,green*.94)
        if stalk%3 == variant:
            _stem(tip-Vector3.UP*.13,tip+Vector3.UP*.035,.019,.016,Color(.33,.28,.16))


func set_overview(enabled: bool) -> void:
    set_view_size(30000.0 if enabled else 800.0)


func set_view_size(size: float) -> void:
    var level: int = 3 if size > 4200.0 else (2 if size > 2400.0 else (1 if size > 1100.0 else 0))
    if level == _detail_level: return
    _detail_level = level
    var enabled: bool = level == 3
    _overview = enabled
    _overview_root.visible = enabled
    for index: int in range(_batch_mesh_ids.size()):
        var instance: MultiMeshInstance3D = get_child(index) as MultiMeshInstance3D
        instance.visible = not enabled
        if not enabled:
            instance.multimesh.mesh = _wide_meshes[_batch_mesh_ids[index]] if level == 2 else (_medium_meshes[_batch_mesh_ids[index]] if level == 1 else _full_meshes[_batch_mesh_ids[index]])


func _overview_mesh(kind: int,variant: int,material: Material) -> ArrayMesh:
    if kind in [4,5,8,9,11,13,15,16,17,18,20]: return _make_mesh(kind,variant,material)
    _rng.seed = 879125+kind*97+variant*381
    _surface = SurfaceTool.new()
    _surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    _surface.set_material(material)
    var colour: Color = Color(.33,.45,.23)
    if kind in [1,7]: colour = Color(.28,.405,.335)
    if kind in [2,10]: colour = Color(.42,.47,.29)
    if kind == 6: colour = Color(.48,.56,.32)
    if kind in [3,12,19]:
        _ellipsoid(Vector3(0,.28,0),Vector3(.38,.32,.32),colour,.12)
    elif kind in [1,7]:
        _stem(Vector3.ZERO,Vector3(0,.94,0),.035,.01,Color(.35,.27,.18))
        for tier: int in range(4): _pine_tier(.24+tier*.14,.30-tier*.05,.39-tier*.04,colour*(1+tier*.04))
    else:
        _stem(Vector3.ZERO,Vector3(.04,.72,0),.045,.016,Color(.38,.28,.18))
        for lobe: int in range(3):
            var angle: float = lobe*TAU/3+variant
            var radius: Vector3 = Vector3(.29,.28,.27) if kind != 6 else Vector3(.17,.35,.17)
            _ellipsoid(Vector3(cos(angle)*.15,.69+sin(angle)*.09,sin(angle)*.12),radius,colour*(.93+lobe*.045),.07)
    _surface.generate_normals()
    _surface.index()
    return _surface.commit()
