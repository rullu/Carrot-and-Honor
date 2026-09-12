class_name ProvincePresentation
extends Node3D


const REFERENCE_CAMERA_SIZE: float = 1600.0
const MIN_CAMERA_SIZE: float = 800.0
const MAX_CAMERA_SIZE: float = 3600.0
const ZOOM_COMPENSATION_EXPONENT: float = 0.42
const WIDTH_SCALE_EPSILON: float = 0.001

# Political-ribbon tuning. Each province owns exactly half of TOTAL_RIBBON_WIDTH.
const TOTAL_RIBBON_WIDTH: float = 26.0
const RIBBON_OPACITY: float = 0.70
const INWARD_FADE_POWER: float = 0.55
const HATCH_TEXTURE_STRENGTH: float = 0.38
const HATCH_SCALE_WORLD_UNITS: float = 18.0
const PIGMENT_SATURATION: float = 0.82
const RIBBON_HEIGHT_OFFSET: float = 3.15
const MIN_PALETTE_TEXTURE_WIDTH: int = 128

# The accepted subtle renderer remains available as a one-constant fallback.
const USE_LEGACY_SINGLE_LINE_FALLBACK: bool = false
const LEGACY_OUTER_WIDTH: float = 4.0
const LEGACY_INNER_WIDTH: float = 1.8
const LEGACY_OUTER_HEIGHT_OFFSET: float = 2.75
const LEGACY_INNER_HEIGHT_OFFSET: float = 2.95
const LEGACY_OUTER_COLOR: Color = Color(0.20, 0.22, 0.27, 0.24)
const LEGACY_INNER_COLOR: Color = Color(0.39, 0.43, 0.51, 0.56)

const PROTOTYPE_POLITICAL_PALETTE: Array[Color] = [
    Color("873f3f"), # Faded crimson.
    Color("526b82"), # Dusty blue.
    Color("687452"), # Moss / sage green.
    Color("9a7841"), # Muted ochre.
    Color("76566f"), # Weathered plum.
    Color("586775"), # Iron blue-grey.
    Color("805444"), # Warm brown-red.
]

const CHAIKIN_WEIGHT: float = 0.12
const RESAMPLE_SPACING: float = 36.0

const POLITICAL_RIBBON_SHADER_SOURCE: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform sampler2D province_color_palette : source_color, filter_nearest, repeat_disable;
uniform float width_scale = 1.0;
uniform float ribbon_opacity = 0.70;
uniform float inward_fade_power = 0.55;
uniform float hatch_texture_strength = 0.38;
uniform float hatch_scale_world_units = 18.0;
uniform float pigment_saturation = 0.82;

varying vec2 ribbon_world_xz;

void vertex() {
    vec2 center_xz = UV;
    VERTEX.xz = center_xz + (VERTEX.xz - center_xz) * width_scale;
    ribbon_world_xz = VERTEX.xz;
}

void fragment() {
    vec4 province_color = texture(province_color_palette, vec2(UV2.x, 0.5));
    float luminance = dot(province_color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 pigment = mix(vec3(luminance), province_color.rgb, pigment_saturation);

    float diagonal_phase = (
        ribbon_world_xz.x * 0.78 + ribbon_world_xz.y
    ) / max(hatch_scale_world_units, 0.001);
    float hatch = sin(diagonal_phase * 6.2831853 + UV2.x * 31.0) * 0.5 + 0.5;
    float brush = sin(
        (ribbon_world_xz.x * 0.19 - ribbon_world_xz.y * 0.13)
        / max(hatch_scale_world_units, 0.001) * 6.2831853
        + UV2.x * 71.0
    ) * 0.5 + 0.5;
    float pigment_texture = mix(
        1.0,
        0.88 + hatch * 0.16 + brush * 0.05,
        hatch_texture_strength
    );

    float inward = clamp(UV2.y, 0.0, 1.0);
    float inward_fade = pow(1.0 - smoothstep(0.0, 1.0, inward), inward_fade_power);
    ALBEDO = pigment * pigment_texture;
    ALPHA = province_color.a * ribbon_opacity * inward_fade;
}
"""

const LEGACY_BORDER_SHADER_SOURCE: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform vec4 border_color : source_color;
uniform float width_scale = 1.0;

void vertex() {
    vec2 center_xz = UV;
    VERTEX.xz = center_xz + (VERTEX.xz - center_xz) * width_scale;
}

void fragment() {
    ALBEDO = border_color.rgb;
    ALPHA = border_color.a;
}
"""


var _geography: ProvinceGeography
var _terrain: Terrain3D
var _camera: Camera3D
var _border_paths: Array[Dictionary] = []
var _zoom_materials: Array[ShaderMaterial] = []
var _last_width_scale: float = -1.0
var _political_colors_by_province: Dictionary[int, Color] = {}
var _palette_texture: ImageTexture
var _palette_texture_width: int = MIN_PALETTE_TEXTURE_WIDTH


func _ready() -> void:
    set_process(false)


func configure(
    geography: ProvinceGeography,
    terrain: Terrain3D,
    camera: Camera3D
) -> void:
    _geography = geography
    _terrain = terrain
    _camera = camera
    if geography == null or terrain == null or camera == null:
        push_error("ProvincePresentation requires geography, Terrain3D and the gameplay camera.")
        return

    var collection: Dictionary = _collect_internal_border_paths(geography.get_province_ids())
    _border_paths = collection.get("paths", [])
    if _border_paths.is_empty():
        push_error("ProvincePresentation found no shared land boundaries.")
        return

    if USE_LEGACY_SINGLE_LINE_FALLBACK:
        _create_legacy_mesh_instance(
            "PermanentProvinceBordersOuter",
            _create_legacy_border_mesh(LEGACY_OUTER_WIDTH, LEGACY_OUTER_HEIGHT_OFFSET),
            LEGACY_OUTER_COLOR,
            0
        )
        _create_legacy_mesh_instance(
            "PermanentProvinceBorders",
            _create_legacy_border_mesh(LEGACY_INNER_WIDTH, LEGACY_INNER_HEIGHT_OFFSET),
            LEGACY_INNER_COLOR,
            1
        )
    else:
        _palette_texture = _create_palette_texture(geography.get_province_ids())
        _create_ribbon_mesh_instance(_create_political_ribbon_mesh())
    _update_width_scale(true)
    set_process(true)
    print(
        "PROVINCE_BORDERS_READY: %d shared segments; %d cached dual-sided land-border paths"
        % [int(collection.get("segment_count", 0)), _border_paths.size()]
    )


func _process(_delta: float) -> void:
    _update_width_scale(false)


func set_hovered_province_id(_province_id: int) -> void:
    # Hover remains available to interaction and UI, but has no map-border effect.
    pass


func set_selected_province_id(_province_id: int) -> void:
    # Selection is represented by UI state and never adds a persistent outline.
    pass


func set_political_colors(colors_by_province: Dictionary[int, Color]) -> void:
    _political_colors_by_province = colors_by_province.duplicate()
    if _geography != null and not USE_LEGACY_SINGLE_LINE_FALLBACK:
        _palette_texture = _create_palette_texture(_geography.get_province_ids())
        for material: ShaderMaterial in _zoom_materials:
            material.set_shader_parameter("province_color_palette", _palette_texture)


func _create_ribbon_mesh_instance(border_mesh: ArrayMesh) -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = "PermanentProvincePoliticalRibbon"
    instance.mesh = border_mesh
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material: ShaderMaterial = ShaderMaterial.new()
    var shader: Shader = Shader.new()
    shader.code = POLITICAL_RIBBON_SHADER_SOURCE
    material.shader = shader
    material.set_shader_parameter("province_color_palette", _palette_texture)
    material.set_shader_parameter("ribbon_opacity", RIBBON_OPACITY)
    material.set_shader_parameter("inward_fade_power", INWARD_FADE_POWER)
    material.set_shader_parameter("hatch_texture_strength", HATCH_TEXTURE_STRENGTH)
    material.set_shader_parameter("hatch_scale_world_units", HATCH_SCALE_WORLD_UNITS)
    material.set_shader_parameter("pigment_saturation", PIGMENT_SATURATION)
    instance.material_override = material
    _zoom_materials.append(material)
    add_child(instance)
    return instance


func _create_legacy_mesh_instance(
    node_name: String,
    border_mesh: ArrayMesh,
    color: Color,
    priority: int
) -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = border_mesh
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material: ShaderMaterial = ShaderMaterial.new()
    var shader: Shader = Shader.new()
    shader.code = LEGACY_BORDER_SHADER_SOURCE
    material.shader = shader
    material.set_shader_parameter("border_color", color)
    material.render_priority = priority
    instance.material_override = material
    _zoom_materials.append(material)
    add_child(instance)
    return instance


func _collect_internal_border_paths(province_ids: PackedInt32Array) -> Dictionary:
    var candidates: Dictionary = {}
    for province_id: int in province_ids:
        var record: Dictionary = _geography.get_province_record(province_id)
        for ring: Dictionary in record.get("rings", []):
            if bool(ring.get("is_hole", false)):
                continue
            var points: PackedVector2Array = ring["points"]
            var ring_interior_side: int = 1 if _signed_ring_area(points) > 0.0 else -1
            for point_index: int in range(points.size() - 1):
                var start: Vector2 = points[point_index]
                var finish: Vector2 = points[point_index + 1]
                if start.distance_squared_to(finish) <= 0.000001:
                    continue
                var key: String = _edge_key(start, finish)
                if not candidates.has(key):
                    candidates[key] = {
                        "start": start,
                        "finish": finish,
                        "owners": PackedInt32Array(),
                        "owner_sides": {},
                    }
                var candidate: Dictionary = candidates[key]
                var owners: PackedInt32Array = candidate["owners"]
                if province_id not in owners:
                    owners.append(province_id)
                var direction_matches_candidate: bool = _point_key(start) == _point_key(
                    candidate["start"]
                )
                var owner_sides: Dictionary = candidate["owner_sides"]
                owner_sides[province_id] = (
                    ring_interior_side if direction_matches_candidate else -ring_interior_side
                )

    var edges_by_pair: Dictionary = {}
    var segment_count: int = 0
    var edge_keys: Array = candidates.keys()
    edge_keys.sort()
    for edge_key_value: Variant in edge_keys:
        var edge: Dictionary = candidates[edge_key_value]
        var owners: PackedInt32Array = edge["owners"]
        owners.sort()
        if owners.size() != 2:
            continue
        var pair_key: String = "%d:%d" % [owners[0], owners[1]]
        if not edges_by_pair.has(pair_key):
            edges_by_pair[pair_key] = []
        var pair_edges: Array = edges_by_pair[pair_key]
        pair_edges.append(edge)
        segment_count += 1

    var paths: Array[Dictionary] = []
    var pair_keys: Array = edges_by_pair.keys()
    pair_keys.sort()
    for pair_key_value: Variant in pair_keys:
        var pair_edges: Array = edges_by_pair[pair_key_value]
        var edges_by_key: Dictionary = {}
        for pair_edge: Dictionary in pair_edges:
            edges_by_key[_edge_key(pair_edge["start"], pair_edge["finish"])] = pair_edge
        var raw_paths: Array[PackedVector2Array] = _stitch_edge_group(
            pair_edges
        )
        for raw_path: PackedVector2Array in raw_paths:
            var smoothed: PackedVector2Array = _smooth_path(raw_path)
            if smoothed.size() < 2:
                continue
            var side_owners: Dictionary = _side_owners_for_path(raw_path, edges_by_key)
            if side_owners.is_empty():
                push_error("ProvincePresentation could not orient a shared border path.")
                continue
            paths.append(
                {
                    "points": smoothed,
                    "authoritative_points": _densify_path_preserving_vertices(
                        raw_path, RESAMPLE_SPACING
                    ),
                    "left_owner": side_owners["left_owner"],
                    "right_owner": side_owners["right_owner"],
                }
            )
    return {"paths": paths, "segment_count": segment_count}


func _signed_ring_area(points: PackedVector2Array) -> float:
    var twice_area: float = 0.0
    for point_index: int in range(points.size() - 1):
        twice_area += points[point_index].cross(points[point_index + 1])
    return twice_area * 0.5


func _side_owners_for_path(raw_path: PackedVector2Array, edges_by_key: Dictionary) -> Dictionary:
    if raw_path.size() < 2:
        return {}
    var first_key: String = _edge_key(raw_path[0], raw_path[1])
    if not edges_by_key.has(first_key):
        return {}
    var first_edge: Dictionary = edges_by_key[first_key]
    var owners: PackedInt32Array = first_edge["owners"]
    var owner_sides: Dictionary = first_edge["owner_sides"]
    if owners.size() != 2 or owner_sides.size() != 2:
        return {}
    var path_matches_candidate: bool = _point_key(raw_path[0]) == _point_key(
        first_edge["start"]
    )
    var left_owner: int = -1
    var right_owner: int = -1
    for owner_id: int in owners:
        var side: int = int(owner_sides.get(owner_id, 0))
        if not path_matches_candidate:
            side = -side
        if side > 0:
            left_owner = owner_id
        elif side < 0:
            right_owner = owner_id
    if left_owner < 0 or right_owner < 0 or left_owner == right_owner:
        return {}
    return {"left_owner": left_owner, "right_owner": right_owner}


func _stitch_edge_group(edges: Array) -> Array[PackedVector2Array]:
    var points_by_key: Dictionary = {}
    var neighbors_by_key: Dictionary = {}
    var unused_edges: Dictionary = {}
    for edge: Dictionary in edges:
        var start: Vector2 = edge["start"]
        var finish: Vector2 = edge["finish"]
        var start_key: String = _point_key(start)
        var finish_key: String = _point_key(finish)
        points_by_key[start_key] = start
        points_by_key[finish_key] = finish
        if not neighbors_by_key.has(start_key):
            neighbors_by_key[start_key] = []
        if not neighbors_by_key.has(finish_key):
            neighbors_by_key[finish_key] = []
        var start_neighbors: Array = neighbors_by_key[start_key]
        var finish_neighbors: Array = neighbors_by_key[finish_key]
        if finish_key not in start_neighbors:
            start_neighbors.append(finish_key)
        if start_key not in finish_neighbors:
            finish_neighbors.append(start_key)
        unused_edges[_string_edge_key(start_key, finish_key)] = true

    for point_key_value: Variant in neighbors_by_key:
        var point_neighbors: Array = neighbors_by_key[point_key_value]
        point_neighbors.sort()

    var paths: Array[PackedVector2Array] = []
    var endpoint_keys: Array = []
    for point_key_value: Variant in neighbors_by_key:
        var point_key: String = point_key_value
        var point_neighbors: Array = neighbors_by_key[point_key]
        if point_neighbors.size() != 2:
            endpoint_keys.append(point_key)
    endpoint_keys.sort()
    for endpoint_key_value: Variant in endpoint_keys:
        var endpoint_key: String = endpoint_key_value
        while _has_unused_edge(endpoint_key, neighbors_by_key, unused_edges):
            paths.append(
                _trace_path(endpoint_key, points_by_key, neighbors_by_key, unused_edges)
            )

    while not unused_edges.is_empty():
        var remaining_key: String = unused_edges.keys()[0]
        var loop_start: String = remaining_key.get_slice("|", 0)
        paths.append(_trace_path(loop_start, points_by_key, neighbors_by_key, unused_edges))
    return paths


func _trace_path(
    start_key: String,
    points_by_key: Dictionary,
    neighbors_by_key: Dictionary,
    unused_edges: Dictionary
) -> PackedVector2Array:
    var path: PackedVector2Array = PackedVector2Array()
    var current_key: String = start_key
    while true:
        path.append(points_by_key[current_key])
        var available: Array = []
        for neighbor_value: Variant in neighbors_by_key[current_key]:
            var neighbor_key: String = neighbor_value
            if unused_edges.has(_string_edge_key(current_key, neighbor_key)):
                available.append(neighbor_key)
        if available.is_empty():
            break
        available.sort()
        var next_key: String = available[0]
        unused_edges.erase(_string_edge_key(current_key, next_key))
        current_key = next_key
        if current_key == start_key:
            path.append(points_by_key[current_key])
            break
        var current_neighbors: Array = neighbors_by_key[current_key]
        if current_neighbors.size() != 2:
            path.append(points_by_key[current_key])
            break
    return path


func _has_unused_edge(
    point_key: String,
    neighbors_by_key: Dictionary,
    unused_edges: Dictionary
) -> bool:
    for neighbor_value: Variant in neighbors_by_key[point_key]:
        if unused_edges.has(_string_edge_key(point_key, String(neighbor_value))):
            return true
    return false


func _smooth_path(raw_path: PackedVector2Array) -> PackedVector2Array:
    if raw_path.size() < 3:
        return raw_path
    var closed: bool = raw_path[0].is_equal_approx(raw_path[-1])
    var rounded: PackedVector2Array = PackedVector2Array()
    if closed:
        var unique_count: int = raw_path.size() - 1
        for index: int in unique_count:
            var current: Vector2 = raw_path[index]
            var next: Vector2 = raw_path[(index + 1) % unique_count]
            rounded.append(current.lerp(next, CHAIKIN_WEIGHT))
            rounded.append(current.lerp(next, 1.0 - CHAIKIN_WEIGHT))
        rounded.append(rounded[0])
    else:
        rounded.append(raw_path[0])
        for index: int in range(raw_path.size() - 1):
            var current: Vector2 = raw_path[index]
            var next: Vector2 = raw_path[index + 1]
            rounded.append(current.lerp(next, CHAIKIN_WEIGHT))
            rounded.append(current.lerp(next, 1.0 - CHAIKIN_WEIGHT))
        rounded.append(raw_path[-1])
    return _resample_path(rounded, RESAMPLE_SPACING, closed)


func _resample_path(
    points: PackedVector2Array,
    spacing: float,
    closed: bool
) -> PackedVector2Array:
    var result: PackedVector2Array = PackedVector2Array([points[0]])
    var distance_until_sample: float = spacing
    var segment_start: Vector2 = points[0]
    for index: int in range(1, points.size()):
        var segment_finish: Vector2 = points[index]
        var segment: Vector2 = segment_finish - segment_start
        var segment_length: float = segment.length()
        while segment_length >= distance_until_sample and segment_length > 0.000001:
            var sample: Vector2 = segment_start + segment.normalized() * distance_until_sample
            result.append(sample)
            segment_start = sample
            segment = segment_finish - segment_start
            segment_length = segment.length()
            distance_until_sample = spacing
        distance_until_sample -= segment_length
        segment_start = segment_finish
    if closed:
        if not result[-1].is_equal_approx(result[0]):
            result.append(result[0])
    elif not result[-1].is_equal_approx(points[-1]):
        result.append(points[-1])
    return result


func _densify_path_preserving_vertices(
    points: PackedVector2Array,
    maximum_spacing: float
) -> PackedVector2Array:
    var result: PackedVector2Array = PackedVector2Array([points[0]])
    for point_index: int in range(points.size() - 1):
        var start: Vector2 = points[point_index]
        var finish: Vector2 = points[point_index + 1]
        var segment_count: int = maxi(1, ceili(start.distance_to(finish) / maximum_spacing))
        for segment_index: int in range(1, segment_count + 1):
            result.append(start.lerp(finish, float(segment_index) / float(segment_count)))
    return result


func _create_political_ribbon_mesh() -> ArrayMesh:
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var vertex_count: int = 0
    var half_width: float = TOTAL_RIBBON_WIDTH * 0.5
    for path_record: Dictionary in _border_paths:
        # The seam follows source vertices exactly; only joins and alpha are softened.
        var centers: PackedVector2Array = path_record["authoritative_points"]
        if centers.size() < 2:
            continue
        var sides: PackedVector2Array = PackedVector2Array()
        var heights: PackedFloat32Array = PackedFloat32Array()
        var valid_path: bool = true
        for point_index: int in centers.size():
            var tangent: Vector2
            if point_index == 0:
                tangent = centers[1] - centers[0]
            elif point_index == centers.size() - 1:
                tangent = centers[-1] - centers[-2]
            else:
                tangent = centers[point_index + 1] - centers[point_index - 1]
            if tangent.length_squared() <= 0.000001:
                valid_path = false
                break
            tangent = tangent.normalized()
            sides.append(Vector2(-tangent.y, tangent.x) * half_width)
            var height: float = _terrain.data.get_height(
                Vector3(centers[point_index].x, 0.0, centers[point_index].y)
            )
            if is_nan(height):
                valid_path = false
                break
            heights.append(height + RIBBON_HEIGHT_OFFSET)
        if not valid_path:
            continue
        var left_owner: int = path_record["left_owner"]
        var right_owner: int = path_record["right_owner"]
        for point_index: int in range(centers.size() - 1):
            var first_center: Vector2 = centers[point_index]
            var second_center: Vector2 = centers[point_index + 1]
            var first_side: Vector2 = sides[point_index]
            var second_side: Vector2 = sides[point_index + 1]
            var first_seam: Vector3 = Vector3(
                first_center.x, heights[point_index], first_center.y
            )
            var second_seam: Vector3 = Vector3(
                second_center.x, heights[point_index + 1], second_center.y
            )
            var first_left: Vector3 = Vector3(
                first_center.x + first_side.x,
                heights[point_index],
                first_center.y + first_side.y
            )
            var first_right: Vector3 = Vector3(
                first_center.x - first_side.x,
                heights[point_index],
                first_center.y - first_side.y
            )
            var second_left: Vector3 = Vector3(
                second_center.x + second_side.x,
                heights[point_index + 1],
                second_center.y + second_side.y
            )
            var second_right: Vector3 = Vector3(
                second_center.x - second_side.x,
                heights[point_index + 1],
                second_center.y - second_side.y
            )

            _add_ribbon_vertex(surface, first_center, first_seam, left_owner, 0.0)
            _add_ribbon_vertex(surface, first_center, first_left, left_owner, 1.0)
            _add_ribbon_vertex(surface, second_center, second_seam, left_owner, 0.0)
            _add_ribbon_vertex(surface, second_center, second_seam, left_owner, 0.0)
            _add_ribbon_vertex(surface, first_center, first_left, left_owner, 1.0)
            _add_ribbon_vertex(surface, second_center, second_left, left_owner, 1.0)

            _add_ribbon_vertex(surface, first_center, first_seam, right_owner, 0.0)
            _add_ribbon_vertex(surface, second_center, second_seam, right_owner, 0.0)
            _add_ribbon_vertex(surface, first_center, first_right, right_owner, 1.0)
            _add_ribbon_vertex(surface, second_center, second_seam, right_owner, 0.0)
            _add_ribbon_vertex(surface, second_center, second_right, right_owner, 1.0)
            _add_ribbon_vertex(surface, first_center, first_right, right_owner, 1.0)
            vertex_count += 12
    if vertex_count == 0:
        return ArrayMesh.new()
    return surface.commit()


func _add_ribbon_vertex(
    surface: SurfaceTool,
    center_xz: Vector2,
    vertex: Vector3,
    province_id: int,
    inward_distance: float
) -> void:
    surface.set_uv(center_xz)
    surface.set_uv2(
        Vector2((float(province_id) + 0.5) / float(_palette_texture_width), inward_distance)
    )
    surface.add_vertex(vertex)


func _create_legacy_border_mesh(width: float, height_offset: float) -> ArrayMesh:
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var vertex_count: int = 0
    for path_record: Dictionary in _border_paths:
        var centers: PackedVector2Array = path_record["points"]
        if centers.size() < 2:
            continue
        var sides: PackedVector2Array = PackedVector2Array()
        var heights: PackedFloat32Array = PackedFloat32Array()
        var valid_path: bool = true
        for point_index: int in centers.size():
            var tangent: Vector2
            if point_index == 0:
                tangent = centers[1] - centers[0]
            elif point_index == centers.size() - 1:
                tangent = centers[-1] - centers[-2]
            else:
                tangent = centers[point_index + 1] - centers[point_index - 1]
            if tangent.length_squared() <= 0.000001:
                valid_path = false
                break
            tangent = tangent.normalized()
            sides.append(Vector2(-tangent.y, tangent.x) * width * 0.5)
            var height: float = _terrain.data.get_height(
                Vector3(centers[point_index].x, 0.0, centers[point_index].y)
            )
            if is_nan(height):
                valid_path = false
                break
            heights.append(height + height_offset)
        if not valid_path:
            continue
        for point_index: int in range(centers.size() - 1):
            var first_center: Vector2 = centers[point_index]
            var second_center: Vector2 = centers[point_index + 1]
            var first_side: Vector2 = sides[point_index]
            var second_side: Vector2 = sides[point_index + 1]
            var first_left: Vector3 = Vector3(
                first_center.x + first_side.x,
                heights[point_index],
                first_center.y + first_side.y
            )
            var first_right: Vector3 = Vector3(
                first_center.x - first_side.x,
                heights[point_index],
                first_center.y - first_side.y
            )
            var second_left: Vector3 = Vector3(
                second_center.x + second_side.x,
                heights[point_index + 1],
                second_center.y + second_side.y
            )
            var second_right: Vector3 = Vector3(
                second_center.x - second_side.x,
                heights[point_index + 1],
                second_center.y - second_side.y
            )
            _add_legacy_border_vertex(surface, first_center, first_left)
            _add_legacy_border_vertex(surface, first_center, first_right)
            _add_legacy_border_vertex(surface, second_center, second_left)
            _add_legacy_border_vertex(surface, second_center, second_left)
            _add_legacy_border_vertex(surface, first_center, first_right)
            _add_legacy_border_vertex(surface, second_center, second_right)
            vertex_count += 6
    if vertex_count == 0:
        return ArrayMesh.new()
    return surface.commit()


func _add_legacy_border_vertex(
    surface: SurfaceTool,
    center_xz: Vector2,
    vertex: Vector3
) -> void:
    surface.set_uv(center_xz)
    surface.add_vertex(vertex)


func _create_palette_texture(province_ids: PackedInt32Array) -> ImageTexture:
    var highest_province_id: int = 0
    for province_id: int in province_ids:
        highest_province_id = maxi(highest_province_id, province_id)
    _palette_texture_width = maxi(MIN_PALETTE_TEXTURE_WIDTH, highest_province_id + 1)

    var image: Image = Image.create(
        _palette_texture_width, 1, false, Image.FORMAT_RGBA8
    )
    image.fill(Color(0.0, 0.0, 0.0, 0.0))
    var prototype_indices: Dictionary[int, int] = _assign_prototype_palette_indices(
        province_ids
    )
    for province_id: int in province_ids:
        var color: Color
        if _political_colors_by_province.has(province_id):
            color = _political_colors_by_province[province_id]
        else:
            color = PROTOTYPE_POLITICAL_PALETTE[prototype_indices[province_id]]
        color.a = 1.0
        image.set_pixel(province_id, 0, color)
    return ImageTexture.create_from_image(image)


func _assign_prototype_palette_indices(
    province_ids: PackedInt32Array
) -> Dictionary[int, int]:
    var assigned: Dictionary[int, int] = {}
    for province_id: int in province_ids:
        var used_by_assigned_neighbors: Dictionary[int, bool] = {}
        var record: Dictionary = _geography.get_province_record(province_id)
        var neighbors: PackedInt32Array = record.get("neighbor_ids", PackedInt32Array())
        for neighbor_id: int in neighbors:
            if assigned.has(neighbor_id):
                used_by_assigned_neighbors[assigned[neighbor_id]] = true
        var seed_index: int = (
            province_id * 5 + floori(float(province_id) / 7.0)
        ) % PROTOTYPE_POLITICAL_PALETTE.size()
        var chosen_index: int = seed_index
        for offset: int in PROTOTYPE_POLITICAL_PALETTE.size():
            var candidate_index: int = (
                seed_index + offset
            ) % PROTOTYPE_POLITICAL_PALETTE.size()
            if not used_by_assigned_neighbors.has(candidate_index):
                chosen_index = candidate_index
                break
        assigned[province_id] = chosen_index
    return assigned


func _point_key(point: Vector2) -> String:
    return "%.4f,%.4f" % [point.x, point.y]


func _edge_key(start: Vector2, finish: Vector2) -> String:
    return _string_edge_key(_point_key(start), _point_key(finish))


func _string_edge_key(start_key: String, finish_key: String) -> String:
    if start_key < finish_key:
        return "%s|%s" % [start_key, finish_key]
    return "%s|%s" % [finish_key, start_key]


func _update_width_scale(force: bool) -> void:
    if _camera == null:
        return
    var camera_size: float = clampf(_camera.size, MIN_CAMERA_SIZE, MAX_CAMERA_SIZE)
    var zoom_ratio: float = camera_size / REFERENCE_CAMERA_SIZE
    var width_scale: float = pow(zoom_ratio, ZOOM_COMPENSATION_EXPONENT)
    if not force and absf(width_scale - _last_width_scale) <= WIDTH_SCALE_EPSILON:
        return
    _last_width_scale = width_scale
    for material: ShaderMaterial in _zoom_materials:
        material.set_shader_parameter("width_scale", width_scale)
