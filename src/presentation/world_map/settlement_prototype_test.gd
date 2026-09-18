class_name SettlementPrototypeTest
extends Node3D


enum DisplayMode {
    TWO_D,
    THREE_D,
    BOTH,
    NONE,
}

const SETTLEMENT_TEXTURE: Texture2D = preload(
    "res://assets/prototypes/settlement/the_victim.png"
)
const PROVINCE_ANCHORS: Dictionary = {
    67: Vector2(-13903.80859375, 6909.1796875),
    54: Vector2(-16223.14453125, 3771.97265625),
}
const TWO_D_PIXEL_SIZE: float = 0.36
const TWO_D_VISIBLE_BOTTOM_PIXEL: float = 1091.0
const THREE_D_FOOTPRINT: Vector2 = Vector2(110.0, 95.0)


var _terrain: Terrain3D
var _geography: ProvinceGeography
var _two_d_roots: Array[Node3D] = []
var _three_d_roots: Array[Node3D] = []
var _display_mode: DisplayMode = DisplayMode.TWO_D
var _materials: Dictionary[StringName, StandardMaterial3D] = {}

@onready var province_67_anchor: Node3D = $Province67_TestAnchor
@onready var province_54_anchor: Node3D = $Province54_TestAnchor
@onready var mode_label: Label = $PrototypeUI/Panel/Margin/Rows/Mode


func configure(terrain: Terrain3D, geography: ProvinceGeography) -> void:
    _terrain = terrain
    _geography = geography
    if terrain == null or geography == null:
        push_error("SettlementPrototypeTest requires Terrain3D and province geography.")
        return
    if not _validate_anchor(67) or not _validate_anchor(54):
        return
    _build_materials()
    _build_province_comparison(province_67_anchor, 67)
    _build_province_comparison(province_54_anchor, 54)
    set_display_mode(DisplayMode.TWO_D)
    print(
        "SETTLEMENT_PROTOTYPE_READY: provinces 67/54; 2D width %.1f; 3D footprint %.0fx%.0f"
        % [SETTLEMENT_TEXTURE.get_width() * TWO_D_PIXEL_SIZE, THREE_D_FOOTPRINT.x, THREE_D_FOOTPRINT.y]
    )


func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    var requested_mode: int = -1
    match event.keycode:
        KEY_F1:
            requested_mode = DisplayMode.TWO_D
        KEY_F2:
            requested_mode = DisplayMode.THREE_D
        KEY_F3:
            requested_mode = DisplayMode.BOTH
        KEY_F4:
            requested_mode = DisplayMode.NONE
    if requested_mode >= 0:
        set_display_mode(requested_mode)
        get_viewport().set_input_as_handled()


func set_display_mode(mode: DisplayMode) -> void:
    _display_mode = mode
    var show_two_d: bool = mode in [DisplayMode.TWO_D, DisplayMode.BOTH]
    var show_three_d: bool = mode in [DisplayMode.THREE_D, DisplayMode.BOTH]
    for root: Node3D in _two_d_roots:
        root.visible = show_two_d
    for root: Node3D in _three_d_roots:
        root.visible = show_three_d
    if mode_label != null:
        mode_label.text = "Visible: %s" % _mode_name(mode)


func get_display_mode() -> DisplayMode:
    return _display_mode


func get_anchor_xz(province_id: int) -> Vector2:
    return PROVINCE_ANCHORS.get(province_id, Vector2(INF, INF))


func _validate_anchor(province_id: int) -> bool:
    var point: Vector2 = get_anchor_xz(province_id)
    var actual_province_id: int = _geography.find_province_id(point)
    if actual_province_id != province_id:
        push_error(
            "Settlement prototype anchor for province %d resolves to %d."
            % [province_id, actual_province_id]
        )
        return false
    var height: float = _height_at(point)
    if is_nan(height):
        push_error("Settlement prototype anchor for province %d has no terrain height." % province_id)
        return false
    return true


func _build_province_comparison(anchor_node: Node3D, province_id: int) -> void:
    var anchor: Vector2 = get_anchor_xz(province_id)
    anchor_node.position = Vector3(anchor.x, 0.0, anchor.y)
    var two_d_root: Node3D = Node3D.new()
    two_d_root.name = "Settlement2D"
    anchor_node.add_child(two_d_root)
    _add_two_d_settlement(two_d_root, anchor)
    _two_d_roots.append(two_d_root)

    var three_d_root: Node3D = Node3D.new()
    three_d_root.name = "Settlement3D"
    anchor_node.add_child(three_d_root)
    _add_three_d_settlement(three_d_root, anchor)
    _three_d_roots.append(three_d_root)


func _add_two_d_settlement(root: Node3D, anchor: Vector2) -> void:
    var sprite: Sprite3D = Sprite3D.new()
    sprite.name = "Testhome2DSticker"
    sprite.texture = SETTLEMENT_TEXTURE
    sprite.pixel_size = TWO_D_PIXEL_SIZE
    sprite.centered = true
    sprite.offset = Vector2(
        0.0,
        TWO_D_VISIBLE_BOTTOM_PIXEL - SETTLEMENT_TEXTURE.get_height() * 0.5
    )
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    sprite.shaded = false
    sprite.double_sided = true
    sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    sprite.position = Vector3(0.0, _height_at(anchor), 0.0)
    root.add_child(sprite)


func _add_three_d_settlement(root: Node3D, anchor: Vector2) -> void:
    _add_market(root, anchor)
    _add_roads(root, anchor)
    _add_walls(root, anchor)
    _add_building(root, anchor, &"Keep", Vector2(0.0, -8.0), Vector3(18.0, 11.0, 14.0), 0.08, &"stone", &"roof_red")
    _add_building(root, anchor, &"Chapel", Vector2(18.0, 5.0), Vector3(9.0, 7.0, 13.0), -0.32, &"stone_light", &"roof_dark")
    _add_chapel_tower(root, anchor, Vector2(18.0, 2.0))

    var houses: Array[Dictionary] = [
        {"p": Vector2(-27, -23), "s": Vector3(9, 5, 6), "r": -0.35},
        {"p": Vector2(-13, -29), "s": Vector3(8, 5, 6), "r": 0.18},
        {"p": Vector2(16, -27), "s": Vector3(8, 5, 6), "r": -0.12},
        {"p": Vector2(30, -20), "s": Vector3(9, 5, 6), "r": 0.38},
        {"p": Vector2(-34, -7), "s": Vector3(8, 5, 6), "r": 0.16},
        {"p": Vector2(34, -3), "s": Vector3(8, 5, 6), "r": -0.22},
        {"p": Vector2(-31, 12), "s": Vector3(9, 5, 6), "r": -0.28},
        {"p": Vector2(31, 17), "s": Vector3(9, 5, 6), "r": 0.28},
        {"p": Vector2(-24, 28), "s": Vector3(8, 5, 6), "r": 0.15},
        {"p": Vector2(-8, 31), "s": Vector3(8, 5, 6), "r": -0.18},
        {"p": Vector2(10, 31), "s": Vector3(8, 5, 6), "r": 0.2},
        {"p": Vector2(27, 30), "s": Vector3(8, 5, 6), "r": -0.12},
        {"p": Vector2(-16, 10), "s": Vector3(7, 4.5, 5), "r": 0.45},
        {"p": Vector2(5, 17), "s": Vector3(7, 4.5, 5), "r": -0.4},
    ]
    for index: int in houses.size():
        var house: Dictionary = houses[index]
        _add_building(
            root,
            anchor,
            StringName("House%02d" % (index + 1)),
            house["p"],
            house["s"],
            house["r"],
            &"plaster",
            &"roof_red" if index % 3 != 1 else &"roof_dark"
        )


func _add_market(root: Node3D, anchor: Vector2) -> void:
    var square: CylinderMesh = CylinderMesh.new()
    square.top_radius = 13.0
    square.bottom_radius = 13.0
    square.height = 0.45
    square.radial_segments = 12
    _add_mesh(root, "MarketSquare", square, &"road", anchor, Vector2(0.0, 12.0), 0.25)
    var well: CylinderMesh = CylinderMesh.new()
    well.top_radius = 1.8
    well.bottom_radius = 2.2
    well.height = 2.5
    well.radial_segments = 10
    _add_mesh(root, "MarketWell", well, &"stone", anchor, Vector2(0.0, 12.0), 1.5)


func _add_roads(root: Node3D, anchor: Vector2) -> void:
    var roads: Array[Dictionary] = [
        {"p": Vector2(0, -51), "length": 42.0, "rotation": 0.0},
        {"p": Vector2(-50, 2), "length": 45.0, "rotation": PI * 0.5},
        {"p": Vector2(49, 14), "length": 45.0, "rotation": PI * 0.5},
    ]
    for index: int in roads.size():
        var road: Dictionary = roads[index]
        var mesh: BoxMesh = BoxMesh.new()
        mesh.size = Vector3(5.0, 0.4, road["length"])
        _add_mesh(
            root,
            "RoadExit%d" % (index + 1),
            mesh,
            &"road",
            anchor,
            road["p"],
            0.3,
            road["rotation"]
        )


func _add_walls(root: Node3D, anchor: Vector2) -> void:
    var points: Array[Vector2] = [
        Vector2(-31, -37), Vector2(13, -40), Vector2(40, -25), Vector2(47, 8),
        Vector2(31, 37), Vector2(-13, 42), Vector2(-41, 25), Vector2(-48, -9),
    ]
    var gate_segments: Array[int] = [0, 3, 6]
    for index: int in points.size():
        if index in gate_segments:
            continue
        var start: Vector2 = points[index]
        var finish: Vector2 = points[(index + 1) % points.size()]
        var direction: Vector2 = finish - start
        var mesh: BoxMesh = BoxMesh.new()
        mesh.size = Vector3(2.2, 3.5, direction.length())
        _add_mesh(
            root,
            "Wall%d" % index,
            mesh,
            &"stone",
            anchor,
            (start + finish) * 0.5,
            2.0,
            atan2(direction.x, direction.y)
        )
    for index: int in points.size():
        if index % 2 != 0:
            continue
        var tower: CylinderMesh = CylinderMesh.new()
        tower.top_radius = 3.0
        tower.bottom_radius = 3.3
        tower.height = 5.5
        tower.radial_segments = 8
        _add_mesh(root, "WallTower%d" % index, tower, &"stone", anchor, points[index], 3.0)


func _add_building(
    root: Node3D,
    anchor: Vector2,
    node_name: StringName,
    offset: Vector2,
    size: Vector3,
    rotation_y: float,
    wall_material: StringName,
    roof_material: StringName
) -> void:
    var building: Node3D = Node3D.new()
    building.name = node_name
    building.position = Vector3(offset.x, _height_at(anchor + offset), offset.y)
    building.rotation.y = rotation_y
    root.add_child(building)

    var body_mesh: BoxMesh = BoxMesh.new()
    body_mesh.size = Vector3(size.x, size.y, size.z)
    var body: MeshInstance3D = MeshInstance3D.new()
    body.name = "Body"
    body.mesh = body_mesh
    body.position.y = size.y * 0.5
    body.material_override = _materials[wall_material]
    building.add_child(body)

    var roof: MeshInstance3D = MeshInstance3D.new()
    roof.name = "Roof"
    roof.mesh = _create_gable_roof(size.x + 1.5, size.z + 1.5, minf(4.5, size.x * 0.45))
    roof.position.y = size.y
    roof.material_override = _materials[roof_material]
    building.add_child(roof)


func _add_chapel_tower(root: Node3D, anchor: Vector2, offset: Vector2) -> void:
    var tower: CylinderMesh = CylinderMesh.new()
    tower.top_radius = 2.2
    tower.bottom_radius = 2.8
    tower.height = 11.0
    tower.radial_segments = 6
    _add_mesh(root, "ChapelTower", tower, &"stone_light", anchor, offset, 6.0)
    var spire: CylinderMesh = CylinderMesh.new()
    spire.top_radius = 0.0
    spire.bottom_radius = 3.2
    spire.height = 6.0
    spire.radial_segments = 6
    _add_mesh(root, "ChapelSpire", spire, &"roof_dark", anchor, offset, 14.5)


func _add_mesh(
    root: Node3D,
    node_name: String,
    mesh: PrimitiveMesh,
    material_id: StringName,
    anchor: Vector2,
    offset: Vector2,
    height_offset: float,
    rotation_y: float = 0.0
) -> void:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = _materials[material_id]
    instance.position = Vector3(
        offset.x,
        _height_at(anchor + offset) + height_offset,
        offset.y
    )
    instance.rotation.y = rotation_y
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    root.add_child(instance)


func _create_gable_roof(width: float, length: float, height: float) -> ArrayMesh:
    var half_width: float = width * 0.5
    var half_length: float = length * 0.5
    var vertices: PackedVector3Array = PackedVector3Array([
        Vector3(-half_width, 0, -half_length), Vector3(half_width, 0, -half_length),
        Vector3(0, height, -half_length), Vector3(-half_width, 0, half_length),
        Vector3(half_width, 0, half_length), Vector3(0, height, half_length),
    ])
    var indices: PackedInt32Array = PackedInt32Array([
        0, 1, 2, 3, 5, 4,
        0, 2, 5, 0, 5, 3,
        1, 4, 5, 1, 5, 2,
    ])
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index: int in indices:
        surface.add_vertex(vertices[index])
    surface.generate_normals()
    return surface.commit()


func _build_materials() -> void:
    _materials[&"plaster"] = _material(Color("b5a17d"), 0.92)
    _materials[&"stone"] = _material(Color("726e62"), 0.96)
    _materials[&"stone_light"] = _material(Color("9b927d"), 0.94)
    _materials[&"roof_red"] = _material(Color("74402f"), 0.88)
    _materials[&"roof_dark"] = _material(Color("3f4140"), 0.9)
    _materials[&"road"] = _material(Color("9c896b"), 1.0)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material


func _height_at(point_xz: Vector2) -> float:
    return _terrain.data.get_height(Vector3(point_xz.x, 0.0, point_xz.y))


func _mode_name(mode: DisplayMode) -> String:
    match mode:
        DisplayMode.TWO_D:
            return "2D only"
        DisplayMode.THREE_D:
            return "3D only"
        DisplayMode.BOTH:
            return "2D + 3D"
        _:
            return "none"
