class_name ProvinceGeography
extends RefCounted


const INVALID_PROVINCE_ID: int = -1
const EDGE_EPSILON: float = 0.0001


var _province_ids: PackedInt32Array = []
var _provinces_by_id: Dictionary[int, Dictionary] = {}
var _reference_point_ids: Dictionary[Vector2, int] = {}


static func load_from_path(path: String) -> ProvinceGeography:
    if not FileAccess.file_exists(path):
        return null
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        return null
    return create_from_data(parsed)


static func create_from_data(data: Dictionary) -> ProvinceGeography:
    if not data.has("province_count") or not data.has("provinces"):
        return null
    if not _is_integer_number(data["province_count"]) or not data["provinces"] is Array:
        return null
    if int(data["province_count"]) != data["provinces"].size():
        return null

    var geography: ProvinceGeography = ProvinceGeography.new()
    for raw_value: Variant in data["provinces"]:
        if not raw_value is Dictionary:
            return null
        var record: Dictionary = _normalize_record(raw_value)
        if record.is_empty():
            return null
        var province_id: int = record["id"]
        if geography._provinces_by_id.has(province_id):
            return null
        geography._provinces_by_id[province_id] = record
        geography._province_ids.append(province_id)
        for point_key: String in ["selection_point", "label_point"]:
            var reference_point: Vector2 = record[point_key]
            if (
                geography._reference_point_ids.has(reference_point)
                and geography._reference_point_ids[reference_point] != province_id
            ):
                return null
            geography._reference_point_ids[reference_point] = province_id

    geography._province_ids.sort()
    return geography


static func _normalize_record(raw: Dictionary) -> Dictionary:
    var required_keys: Array[String] = [
        "id", "name", "full_name", "area_godot_units_squared", "neighbor_ids",
        "bounding_box_xz", "label_point_xz", "selection_point_xz", "rings",
    ]
    for key: String in required_keys:
        if not raw.has(key):
            return {}
    if not _is_integer_number(raw["id"]) or int(raw["id"]) <= 0:
        return {}
    if typeof(raw["name"]) != TYPE_STRING or String(raw["name"]).is_empty():
        return {}
    if typeof(raw["full_name"]) != TYPE_STRING:
        return {}
    if not raw["bounding_box_xz"] is Array or raw["bounding_box_xz"].size() != 4:
        return {}
    if not raw["neighbor_ids"] is Array or not raw["rings"] is Array:
        return {}

    var label_point: Vector2 = _vector2_from_array(raw["label_point_xz"])
    var selection_point: Vector2 = _vector2_from_array(raw["selection_point_xz"])
    if is_inf(label_point.x) or is_inf(selection_point.x):
        return {}

    var bounds_values: Array = raw["bounding_box_xz"]
    var bounds_min: Vector2 = Vector2(float(bounds_values[0]), float(bounds_values[1]))
    var bounds_max: Vector2 = Vector2(float(bounds_values[2]), float(bounds_values[3]))
    if bounds_min.x > bounds_max.x or bounds_min.y > bounds_max.y:
        return {}

    var neighbor_ids: PackedInt32Array = []
    for neighbor_value: Variant in raw["neighbor_ids"]:
        if not _is_integer_number(neighbor_value):
            return {}
        neighbor_ids.append(int(neighbor_value))
    neighbor_ids.sort()

    var rings: Array[Dictionary] = []
    var outer_ring_count: int = 0
    for raw_ring_value: Variant in raw["rings"]:
        if not raw_ring_value is Dictionary:
            return {}
        var raw_ring: Dictionary = raw_ring_value
        if not raw_ring.has("is_hole") or not raw_ring.has("points_xz"):
            return {}
        if typeof(raw_ring["is_hole"]) != TYPE_BOOL or not raw_ring["points_xz"] is Array:
            return {}
        var points: PackedVector2Array = []
        for raw_point: Variant in raw_ring["points_xz"]:
            var point: Vector2 = _vector2_from_array(raw_point)
            if is_inf(point.x):
                return {}
            points.append(point)
        if points.size() < 4 or not points[0].is_equal_approx(points[points.size() - 1]):
            return {}
        var is_hole: bool = raw_ring["is_hole"]
        if not is_hole:
            outer_ring_count += 1
        rings.append({"is_hole": is_hole, "points": points})
    if outer_ring_count == 0:
        return {}

    return {
        "id": int(raw["id"]),
        "name": raw["name"],
        "full_name": raw["full_name"],
        "area_godot_units_squared": float(raw["area_godot_units_squared"]),
        "neighbor_ids": neighbor_ids,
        "bounds_min": bounds_min,
        "bounds_max": bounds_max,
        "label_point": label_point,
        "selection_point": selection_point,
        "rings": rings,
    }


static func _vector2_from_array(value: Variant) -> Vector2:
    if not value is Array or value.size() != 2:
        return Vector2(INF, INF)
    if typeof(value[0]) not in [TYPE_INT, TYPE_FLOAT]:
        return Vector2(INF, INF)
    if typeof(value[1]) not in [TYPE_INT, TYPE_FLOAT]:
        return Vector2(INF, INF)
    return Vector2(float(value[0]), float(value[1]))


static func _is_integer_number(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    return typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value))


func get_province_count() -> int:
    return _province_ids.size()


func get_province_ids() -> PackedInt32Array:
    return _province_ids.duplicate()


func get_province_record(province_id: int) -> Dictionary:
    if not _provinces_by_id.has(province_id):
        return {}
    return _provinces_by_id[province_id].duplicate(true)


func find_province_id(point_xz: Vector2, use_bounds_filter: bool = true) -> int:
    # Azgaar label positions are declared province references, but a few sit
    # outside their polygon for cartographic readability. Exact reference-point
    # queries retain that identity; ordinary cursor coordinates use geometry.
    if _reference_point_ids.has(point_xz):
        return _reference_point_ids[point_xz]
    for province_id: int in _province_ids:
        var record: Dictionary = _provinces_by_id[province_id]
        if use_bounds_filter and not _bounds_contain(record, point_xz):
            continue
        if contains_point_in_rings(point_xz, record["rings"]):
            return province_id
    return INVALID_PROVINCE_ID


static func _bounds_contain(record: Dictionary, point: Vector2) -> bool:
    var minimum: Vector2 = record["bounds_min"]
    var maximum: Vector2 = record["bounds_max"]
    return (
        point.x >= minimum.x - EDGE_EPSILON
        and point.y >= minimum.y - EDGE_EPSILON
        and point.x <= maximum.x + EDGE_EPSILON
        and point.y <= maximum.y + EDGE_EPSILON
    )


static func contains_point_in_rings(point: Vector2, rings: Array) -> bool:
    var inside_outer_ring: bool = false
    for ring_value: Variant in rings:
        if not ring_value is Dictionary:
            return false
        var ring: Dictionary = ring_value
        if not ring.has("is_hole") or not ring.has("points"):
            return false
        if not _point_in_polygon(point, ring["points"]):
            continue
        if ring["is_hole"]:
            return false
        inside_outer_ring = true
    return inside_outer_ring


static func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
    var vertex_count: int = polygon.size()
    if vertex_count > 1 and polygon[0].is_equal_approx(polygon[vertex_count - 1]):
        vertex_count -= 1
    if vertex_count < 3:
        return false

    var inside: bool = false
    var previous: Vector2 = polygon[vertex_count - 1]
    for index: int in range(vertex_count):
        var current: Vector2 = polygon[index]
        if _point_is_on_segment(point, previous, current):
            return true
        if (current.y > point.y) != (previous.y > point.y):
            var intersection_x: float = (
                (previous.x - current.x)
                * (point.y - current.y)
                / (previous.y - current.y)
                + current.x
            )
            if point.x < intersection_x:
                inside = not inside
        previous = current
    return inside


static func _point_is_on_segment(point: Vector2, start: Vector2, end: Vector2) -> bool:
    var segment: Vector2 = end - start
    var to_point: Vector2 = point - start
    var cross: float = absf(segment.cross(to_point))
    if cross > EDGE_EPSILON * maxf(1.0, segment.length()):
        return false
    var projection: float = to_point.dot(segment)
    return projection >= -EDGE_EPSILON and projection <= segment.length_squared() + EDGE_EPSILON
