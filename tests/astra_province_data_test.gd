extends SceneTree


const DATA_PATH: String = "res://data/world_map/astra_provinces.json"
const EXPECTED_SOURCE_SHA256: String = "9c36b97b340c1fb5827b897db4f3798d16b017ce0e9906c26426ff295efaaa90"
const EXPECTED_PROVINCE_COUNT: int = 100
const EXPECTED_ACTIVE_IDS: Array[int] = [
    1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 58, 59,
    60, 61, 62, 64, 65, 66, 67, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
    83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100,
    101, 102, 103, 104, 105, 106, 107,
]
const EXPECTED_RETIRED_IDS: Array[int] = [8, 31, 57, 63, 68, 81, 82]
const SOURCE_TO_PLAYABLE_SCALE: float = 1.6
const VERTEX_SPACING: float = 12.20703125
const TERRAIN_ORIGIN_XZ: Vector2 = Vector2(-25000.0, -14062.5)
const MINIMUM_XZ: Vector2 = Vector2(-25000.0, -14062.5)
const MAXIMUM_XZ: Vector2 = Vector2(25000.0, 14062.5)
const BOUNDS_EPSILON: float = 0.001

const EXPECTED_ANCHORS: Array = [
    [1, 1, "Nirafielia", Vector2(1168.82, 854.91), Vector2(-2171.484375, 2634.9609375)],
    [5, 5, "Mengia", Vector2(1825.83, 1155.28), Vector2(10660.7421875, 8501.5625)],
    [16, 16, "Milpalcou", Vector2(965.1, 701.5), Vector2(-6150.390625, -361.328125)],
    [32, 32, "Taria", Vector2(562.79, 687.87), Vector2(-14008.0078125, -627.5390625)],
    [42, 42, "Drest", Vector2(1381.01, 887.35), Vector2(1972.8515625, 3268.5546875)],
    [80, 80, "Mackebia", Vector2(2067.51, 378.55), Vector2(15381.0546875, -6668.9453125)],
    [81, 65, "Trosovis", Vector2(899.92, 683.04), Vector2(-7423.4375, -721.875)],
    [82, 56, "Cavempil", Vector2(1199.32, 1144.07), Vector2(-1575.78125, 8282.6171875)],
]

var _failures: int = 0


func _initialize() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    _check(parsed is Dictionary, "province data parses as a JSON object")
    if not parsed is Dictionary:
        _finish()
        return
    var data: Dictionary = parsed
    _validate_metadata(data)
    _validate_provinces(data)
    _validate_anchors(data)
    _finish()


func _validate_metadata(data: Dictionary) -> void:
    _check(int(data.get("schema_version", 0)) == 2, "schema version is 2")
    _check(int(data.get("province_count", 0)) == EXPECTED_PROVINCE_COUNT, "declared province count is 100")
    var source: Dictionary = data.get("source", {})
    _check(source.get("sha256", "") == EXPECTED_SOURCE_SHA256, "source authority hash matches")
    _check(source.get("map_name", "") == "FCAH_Azgaar_Master_01", "map name matches")
    _check(source.get("seed", "") == "796959858", "map seed matches")
    _check(_array_to_vector2(source.get("canvas_size", [])) == Vector2(2560.0, 1440.0), "source canvas is 2560x1440")
    var mapping: Dictionary = data.get("coordinate_mapping", {})
    _check(
        mapping.get("orientation", "")
        == "north=-Z;south=+Z;west=-X;east=+X;no_flip_rotation_or_recentering",
        "orientation contract is explicit"
    )
    _check(_array_to_vector2(mapping.get("terrain_origin_xz", [])) == TERRAIN_ORIGIN_XZ, "terrain origin matches")
    _check(is_equal_approx(float(mapping.get("vertex_spacing", 0.0)), VERTEX_SPACING), "vertex spacing matches")
    _check(_azgaar_to_godot(Vector2.ZERO).is_equal_approx(MINIMUM_XZ), "northwest corner is unchanged")
    _check(_azgaar_to_godot(Vector2(2560.0, 1440.0)).is_equal_approx(MAXIMUM_XZ), "southeast corner is unchanged")
    _check(_azgaar_to_godot(Vector2(1.0, 0.0)).x > MINIMUM_XZ.x, "east increases Godot X")
    _check(_azgaar_to_godot(Vector2(0.0, 1.0)).y > MINIMUM_XZ.y, "south increases Godot Z")
    var corrections: Dictionary = data.get("corrections", {})
    _check(_int_arrays_equal(corrections.get("active_province_ids", []), EXPECTED_ACTIVE_IDS), "active ID contract matches")
    _check(_int_arrays_equal(corrections.get("retired_province_ids", []), EXPECTED_RETIRED_IDS), "retired ID contract matches")


func _validate_provinces(data: Dictionary) -> void:
    var provinces: Array = data.get("provinces", [])
    _check(provinces.size() == EXPECTED_PROVINCE_COUNT, "exactly 100 province records exist")
    var province_by_id: Dictionary = {}
    for province_value: Variant in provinces:
        _check(province_value is Dictionary, "province record is an object")
        if not province_value is Dictionary:
            continue
        var province: Dictionary = province_value
        var province_id: int = int(province.get("id", 0))
        _check(province_id > 0, "province ID is positive")
        _check(not province_by_id.has(province_id), "province ID %d is unique" % province_id)
        province_by_id[province_id] = province
        _check(not String(province.get("name", "")).is_empty(), "province %d has a name" % province_id)
        _check(float(province.get("source_area", 0.0)) > 0.0, "province %d has source area" % province_id)
        _check(float(province.get("area_godot_units_squared", 0.0)) > 0.0, "province %d has derived area" % province_id)
        _validate_point(province["selection_point_source_xy"], province["selection_point_xz"], province_id, "selection")
        _validate_point(province["label_point_source_xy"], province["label_point_xz"], province_id, "label")
        _validate_geometry(province)
    for expected_id: int in EXPECTED_ACTIVE_IDS:
        _check(province_by_id.has(expected_id), "province ID %d is represented" % expected_id)
    for retired_id: int in EXPECTED_RETIRED_IDS:
        _check(not province_by_id.has(retired_id), "retired province ID %d is absent" % retired_id)
    for province_id: int in province_by_id:
        var province: Dictionary = province_by_id[province_id]
        var previous_neighbor_id: int = 0
        for neighbor_value: Variant in province.get("neighbor_ids", []):
            var neighbor_id: int = int(neighbor_value)
            _check(neighbor_id > previous_neighbor_id, "province %d neighbors are unique and sorted" % province_id)
            _check(neighbor_id != province_id, "province %d does not neighbor itself" % province_id)
            _check(province_by_id.has(neighbor_id), "province %d neighbor %d exists" % [province_id, neighbor_id])
            if province_by_id.has(neighbor_id):
                _check(_has_int(province_by_id[neighbor_id]["neighbor_ids"], province_id), "province %d/%d adjacency is symmetric" % [province_id, neighbor_id])
            previous_neighbor_id = neighbor_id


func _validate_geometry(province: Dictionary) -> void:
    var province_id: int = int(province["id"])
    var rings: Array = province.get("rings", [])
    _check(not rings.is_empty(), "province %d has boundary geometry" % province_id)
    var source_bounds: Array = [INF, INF, -INF, -INF]
    var world_bounds: Array = [INF, INF, -INF, -INF]
    var derived_area: float = 0.0
    var retained_beyond_float32: bool = false
    var hole_count: int = 0
    for ring_value: Variant in rings:
        var ring: Dictionary = ring_value
        if bool(ring.get("is_hole", false)):
            hole_count += 1
        var source_points: Array = ring.get("source_points_xy", [])
        var world_points: Array = ring.get("points_xz", [])
        _check(source_points.size() == world_points.size(), "province %d ring coordinate counts match" % province_id)
        _check(source_points.size() >= 4, "province %d ring is non-degenerate" % province_id)
        if source_points.size() < 4 or source_points.size() != world_points.size():
            continue
        _check(source_points[0] == source_points[-1], "province %d source ring is closed" % province_id)
        _check(world_points[0] == world_points[-1], "province %d Godot ring is closed" % province_id)
        for point_index: int in source_points.size():
            var source_point: Array = source_points[point_index]
            var world_point: Array = world_points[point_index]
            _check(_mapping_matches(source_point, world_point), "province %d point %d preserves mapping" % [province_id, point_index])
            _check(_is_in_playable_bounds(world_point), "province %d point %d lies in terrain footprint" % [province_id, point_index])
            _expand_bounds(source_bounds, source_point)
            _expand_bounds(world_bounds, world_point)
            retained_beyond_float32 = retained_beyond_float32 or _point_has_more_than_float32_precision(source_point)
        var ring_area: float = absf(_signed_area(world_points))
        derived_area += -ring_area if bool(ring.get("is_hole", false)) else ring_area
    _check(_bounds_equal(province.get("bounding_box_source_xy", []), source_bounds), "province %d source bounds match geometry" % province_id)
    _check(_bounds_equal(province.get("bounding_box_xz", []), world_bounds), "province %d Godot bounds match geometry" % province_id)
    _check(is_equal_approx(derived_area, float(province.get("area_godot_units_squared", 0.0))), "province %d derived area matches rings" % province_id)
    _check(retained_beyond_float32, "province %d retains source precision beyond float32" % province_id)
    _check(hole_count == 0, "province %d has no unowned political holes" % province_id)


func _validate_point(source_values: Array, world_values: Array, province_id: int, kind: String) -> void:
    _check(_mapping_matches(source_values, world_values), "province %d %s point preserves mapping" % [province_id, kind])
    _check(_is_in_playable_bounds(world_values), "province %d %s point lies in terrain footprint" % [province_id, kind])


func _validate_anchors(data: Dictionary) -> void:
    var anchors: Array = data.get("coordinate_mapping", {}).get("manifest_anchors", [])
    _check(anchors.size() == EXPECTED_ANCHORS.size(), "all eight manifest anchors are retained")
    for index: int in mini(anchors.size(), EXPECTED_ANCHORS.size()):
        var anchor: Dictionary = anchors[index]
        var expected: Array = EXPECTED_ANCHORS[index]
        var source_point: Vector2 = _array_to_vector2(anchor.get("source_xy", []))
        var sample_point: Vector2 = _array_to_vector2(anchor.get("playable_sample_xy", []))
        var world_point: Vector2 = _array_to_vector2(anchor.get("godot_xz", []))
        _check(int(anchor.get("historical_province_id", 0)) == expected[0], "anchor %d historical ID matches" % index)
        _check(int(anchor.get("active_province_id", 0)) == expected[1], "anchor %d active ID matches" % index)
        _check(anchor.get("name", "") == expected[2], "anchor %d name matches" % index)
        _check(source_point.is_equal_approx(expected[3]), "anchor %d Azgaar point matches manifest" % index)
        _check(sample_point.is_equal_approx(source_point * SOURCE_TO_PLAYABLE_SCALE - Vector2(0.5, 0.5)), "anchor %d uses sample-centre conversion" % index)
        _check(world_point.is_equal_approx(expected[4]), "anchor %d Godot X/Z matches manifest" % index)
        _check(world_point.is_equal_approx(TERRAIN_ORIGIN_XZ + (sample_point + Vector2(0.5, 0.5)) * VERTEX_SPACING), "anchor %d recovers continuous position without a nudge" % index)


func _azgaar_to_godot(source_point: Vector2) -> Vector2:
    var sample_point: Vector2 = source_point * SOURCE_TO_PLAYABLE_SCALE - Vector2(0.5, 0.5)
    return TERRAIN_ORIGIN_XZ + (sample_point + Vector2(0.5, 0.5)) * VERTEX_SPACING


func _signed_area(points: Array) -> float:
    var twice_area: float = 0.0
    for index: int in points.size() - 1:
        var first: Array = points[index]
        var second: Array = points[index + 1]
        twice_area += float(first[0]) * float(second[1]) - float(second[0]) * float(first[1])
    return twice_area * 0.5


func _bounds_equal(values: Array, expected: Array) -> bool:
    if values.size() != 4 or expected.size() != 4:
        return false
    for index: int in 4:
        if not is_equal_approx(float(values[index]), float(expected[index])):
            return false
    return true


func _is_in_playable_bounds(point: Array) -> bool:
    return (
        float(point[0]) >= MINIMUM_XZ.x - BOUNDS_EPSILON
        and float(point[0]) <= MAXIMUM_XZ.x + BOUNDS_EPSILON
        and float(point[1]) >= MINIMUM_XZ.y - BOUNDS_EPSILON
        and float(point[1]) <= MAXIMUM_XZ.y + BOUNDS_EPSILON
    )


func _mapping_matches(source_point: Array, world_point: Array) -> bool:
    var expected_x: float = (float(source_point[0]) - 1280.0) * 19.53125
    var expected_z: float = (float(source_point[1]) - 720.0) * 19.53125
    return _nearly_exact(float(world_point[0]), expected_x) and _nearly_exact(float(world_point[1]), expected_z)


func _nearly_exact(actual: float, expected: float) -> bool:
    return absf(actual - expected) <= 1.0e-11 * maxf(1.0, absf(expected))


func _expand_bounds(bounds: Array, point: Array) -> void:
    bounds[0] = minf(float(bounds[0]), float(point[0]))
    bounds[1] = minf(float(bounds[1]), float(point[1]))
    bounds[2] = maxf(float(bounds[2]), float(point[0]))
    bounds[3] = maxf(float(bounds[3]), float(point[1]))


func _point_has_more_than_float32_precision(point: Array) -> bool:
    var packed: PackedFloat32Array = PackedFloat32Array([float(point[0]), float(point[1])])
    return float(point[0]) != float(packed[0]) or float(point[1]) != float(packed[1])


func _array_to_vector2(values: Array) -> Vector2:
    if values.size() != 2:
        return Vector2(INF, INF)
    return Vector2(float(values[0]), float(values[1]))


func _has_int(values: Array, expected: int) -> bool:
    for value: Variant in values:
        if int(value) == expected:
            return true
    return false


func _int_arrays_equal(values: Array, expected: Array[int]) -> bool:
    if values.size() != expected.size():
        return false
    for index: int in values.size():
        if int(values[index]) != expected[index]:
            return false
    return true


func _check(condition: bool, context: String) -> void:
    if not condition:
        _failures += 1
        push_error("%s: expected true." % context)


func _finish() -> void:
    if _failures > 0:
        push_error("Astra province data test FAIL: %d assertion(s) failed." % _failures)
        quit(1)
        return
    print("Astra province data test PASS: 100 stable active IDs, geometry, adjacency, bounds, and anchors validated.")
    quit(0)
