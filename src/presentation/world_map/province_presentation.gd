class_name ProvincePresentation
extends Node3D


const INVALID_PROVINCE_ID: int = -1
const NORMAL_WIDTH: float = 2.5
const HOVER_WIDTH: float = 6.0
const SELECTED_WIDTH: float = 8.0
const NORMAL_HEIGHT_OFFSET: float = 2.5
const HOVER_HEIGHT_OFFSET: float = 4.5
const SELECTED_HEIGHT_OFFSET: float = 6.0


var _geography: ProvinceGeography
var _terrain: Terrain3D
var _normal_borders: MeshInstance3D
var _hover_border: MeshInstance3D
var _selected_border: MeshInstance3D
var _hovered_province_id: int = INVALID_PROVINCE_ID
var _selected_province_id: int = INVALID_PROVINCE_ID
var _hover_meshes: Dictionary[int, ArrayMesh] = {}
var _selected_meshes: Dictionary[int, ArrayMesh] = {}


func configure(geography: ProvinceGeography, terrain: Terrain3D) -> void:
    _geography = geography
    _terrain = terrain
    if geography == null or terrain == null:
        push_error("ProvincePresentation requires geography and Terrain3D.")
        return

    _normal_borders = _create_mesh_instance(
        "PermanentProvinceBorders",
        _create_border_mesh(geography.get_province_ids(), NORMAL_WIDTH, NORMAL_HEIGHT_OFFSET),
        Color(0.74, 0.72, 0.62, 0.23),
        0
    )
    _hover_border = _create_mesh_instance(
        "HoveredProvinceBorder",
        ArrayMesh.new(),
        Color(1.0, 0.86, 0.36, 0.72),
        1
    )
    _selected_border = _create_mesh_instance(
        "SelectedProvinceBorder",
        ArrayMesh.new(),
        Color(1.0, 0.62, 0.16, 0.94),
        2
    )
    _hover_border.visible = false
    _selected_border.visible = false


func set_hovered_province_id(province_id: int) -> void:
    _hovered_province_id = province_id
    if _hover_border == null:
        return
    if province_id == INVALID_PROVINCE_ID or province_id == _selected_province_id:
        _hover_border.visible = false
        return
    if not _hover_meshes.has(province_id):
        _hover_meshes[province_id] = _create_border_mesh(
            PackedInt32Array([province_id]), HOVER_WIDTH, HOVER_HEIGHT_OFFSET
        )
    _hover_border.mesh = _hover_meshes[province_id]
    _hover_border.visible = true


func set_selected_province_id(province_id: int) -> void:
    _selected_province_id = province_id
    if _selected_border == null:
        return
    if province_id == INVALID_PROVINCE_ID:
        _selected_border.visible = false
    else:
        if not _selected_meshes.has(province_id):
            _selected_meshes[province_id] = _create_border_mesh(
                PackedInt32Array([province_id]), SELECTED_WIDTH, SELECTED_HEIGHT_OFFSET
            )
        _selected_border.mesh = _selected_meshes[province_id]
        _selected_border.visible = true
    set_hovered_province_id(_hovered_province_id)


func _create_mesh_instance(
        node_name: String,
        border_mesh: ArrayMesh,
        color: Color,
        priority: int
) -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = border_mesh
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.albedo_color = color
    material.render_priority = priority
    instance.material_override = material
    add_child(instance)
    return instance


func _create_border_mesh(
        province_ids: PackedInt32Array,
        width: float,
        height_offset: float
) -> ArrayMesh:
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var vertex_count: int = 0
    for province_id: int in province_ids:
        var record: Dictionary = _geography.get_province_record(province_id)
        for ring: Dictionary in record.get("rings", []):
            var points: PackedVector2Array = ring["points"]
            for point_index: int in range(points.size() - 1):
                var start: Vector2 = points[point_index]
                var finish: Vector2 = points[point_index + 1]
                var direction: Vector2 = finish - start
                if direction.length_squared() <= 0.000001:
                    continue
                var side: Vector2 = Vector2(-direction.y, direction.x).normalized() * width * 0.5
                var start_height: float = _terrain.data.get_height(Vector3(start.x, 0.0, start.y))
                var finish_height: float = _terrain.data.get_height(Vector3(finish.x, 0.0, finish.y))
                if is_nan(start_height) or is_nan(finish_height):
                    continue
                var a: Vector3 = Vector3(start.x + side.x, start_height + height_offset, start.y + side.y)
                var b: Vector3 = Vector3(start.x - side.x, start_height + height_offset, start.y - side.y)
                var c: Vector3 = Vector3(finish.x + side.x, finish_height + height_offset, finish.y + side.y)
                var d: Vector3 = Vector3(finish.x - side.x, finish_height + height_offset, finish.y - side.y)
                surface.add_vertex(a)
                surface.add_vertex(b)
                surface.add_vertex(c)
                surface.add_vertex(c)
                surface.add_vertex(b)
                surface.add_vertex(d)
                vertex_count += 6
    if vertex_count == 0:
        return ArrayMesh.new()
    return surface.commit()
