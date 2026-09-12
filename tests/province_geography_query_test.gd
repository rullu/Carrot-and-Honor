extends SceneTree


const ProvinceGeographyScript: GDScript = preload("res://src/gameplay/province_geography.gd")
const DATA_PATH: String = "res://data/world_map/astra_provinces.json"
const EXPECTED_PROVINCE_COUNT: int = 100
const INLAND_WATER_FIXTURES: Array = [
    [1, 36, Vector2(-2236.328125, 2277.34375)],
    [1, 37, Vector2(-1695.703125, 2276.953125)],
    [3, 30, Vector2(-7119.3359375, 1957.421875)],
    [3, 33, Vector2(-7253.90625, 2192.96875)],
    [3, 34, Vector2(-6950.0, 2178.515625)],
    [3, 41, Vector2(-7340.234375, 2881.4453125)],
    [104, 8, Vector2(-6428.125, -6605.46875)],
    [24, 35, Vector2(-13792.96875, 2269.140625)],
    [54, 40, Vector2(-15340.234375, 2726.5625)],
    [64, 14, Vector2(-10978.3203125, -3434.9609375)],
    [66, 32, Vector2(-15171.2890625, 2140.625)],
    [83, 3, Vector2(7390.8203125, -8597.8515625)],
    [93, 16, Vector2(10592.96875, -3175.78125)],
    [87, 52, Vector2(11617.1875, 6153.125)],
]


var _failures: int = 0


func _initialize() -> void:
    var geography: ProvinceGeography = ProvinceGeographyScript.load_from_path(DATA_PATH)
    _check(geography != null, "authoritative province data loads")
    if geography == null:
        _finish()
        return

    _check(geography.get_province_count() == EXPECTED_PROVINCE_COUNT, "all 100 active provinces are available")
    _test_authoritative_points(geography)
    _test_bounds_filter_equivalence(geography)
    _test_synthetic_hole_and_multipart_geometry()
    _test_corrected_inland_water(geography)
    _test_authoritative_multipart_province(geography)
    _finish()


func _test_authoritative_points(geography: ProvinceGeography) -> void:
    var resolved_ids: Dictionary[int, bool] = {}
    for province_id: int in geography.get_province_ids():
        var record: Dictionary = geography.get_province_record(province_id)
        var selection_result: int = geography.find_province_id(record["selection_point"])
        var label_result: int = geography.find_province_id(record["label_point"])
        _check(
            selection_result == province_id,
            "selection point resolves province %d (got %d)" % [province_id, selection_result]
        )
        _check(
            label_result == province_id,
            "label point resolves province %d (got %d)" % [province_id, label_result]
        )
        resolved_ids[selection_result] = true
    _check(resolved_ids.size() == EXPECTED_PROVINCE_COUNT, "queries resolve every active province ID")


func _test_bounds_filter_equivalence(geography: ProvinceGeography) -> void:
    for province_id: int in geography.get_province_ids():
        var record: Dictionary = geography.get_province_record(province_id)
        for point_key: String in ["selection_point", "label_point"]:
            var point: Vector2 = record[point_key]
            _check(
                geography.find_province_id(point, true)
                == geography.find_province_id(point, false),
                "bounds filter preserves %s lookup for province %d" % [point_key, province_id]
            )
    for z_index: int in range(13):
        for x_index: int in range(21):
            var point: Vector2 = Vector2(
                lerpf(-25000.0, 25000.0, float(x_index) / 20.0),
                lerpf(-14062.5, 14062.5, float(z_index) / 12.0)
            )
            _check(
                geography.find_province_id(point, true)
                == geography.find_province_id(point, false),
                "bounds filter preserves deterministic grid lookup"
            )


func _test_synthetic_hole_and_multipart_geometry() -> void:
    var rings: Array = [
        {"is_hole": false, "points": _closed_square(Vector2(0, 0), Vector2(10, 10))},
        {"is_hole": true, "points": _closed_square(Vector2(4, 4), Vector2(6, 6))},
        {"is_hole": false, "points": _closed_square(Vector2(20, 20), Vector2(24, 24))},
    ]
    _check(
        ProvinceGeographyScript.contains_point_in_rings(Vector2(2, 2), rings),
        "point in primary outer ring resolves"
    )
    _check(
        not ProvinceGeographyScript.contains_point_in_rings(Vector2(5, 5), rings),
        "point in a hole is excluded"
    )
    _check(
        ProvinceGeographyScript.contains_point_in_rings(Vector2(22, 22), rings),
        "point in disconnected outer ring resolves"
    )
    _check(
        not ProvinceGeographyScript.contains_point_in_rings(Vector2(15, 15), rings),
        "point outside all multipart rings is excluded"
    )


func _test_corrected_inland_water(geography: ProvinceGeography) -> void:
    for fixture: Array in INLAND_WATER_FIXTURES:
        var expected_province_id: int = fixture[0]
        var feature_id: int = fixture[1]
        var point: Vector2 = fixture[2]
        _check(
            geography.find_province_id(point) == expected_province_id,
            "inland-water feature %d resolves politically to province %d"
            % [feature_id, expected_province_id]
        )


func _test_authoritative_multipart_province(geography: ProvinceGeography) -> void:
    var record: Dictionary = geography.get_province_record(90)
    var exercised_outer_rings: int = 0
    for ring: Dictionary in record["rings"]:
        if ring["is_hole"]:
            continue
        var point: Vector2 = _interior_point(ring["points"])
        if is_inf(point.x):
            continue
        _check(
            geography.find_province_id(point) == 90,
            "authoritative disconnected ring resolves to province 90"
        )
        exercised_outer_rings += 1
    _check(exercised_outer_rings >= 2, "multiple authoritative outer rings were exercised")


func _closed_square(minimum: Vector2, maximum: Vector2) -> PackedVector2Array:
    return PackedVector2Array([
        minimum,
        Vector2(maximum.x, minimum.y),
        maximum,
        Vector2(minimum.x, maximum.y),
        minimum,
    ])


func _interior_point(closed_polygon: PackedVector2Array) -> Vector2:
    var polygon: PackedVector2Array = closed_polygon.duplicate()
    if polygon.size() > 1 and polygon[0].is_equal_approx(polygon[polygon.size() - 1]):
        polygon.resize(polygon.size() - 1)
    var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
    if triangles.size() < 3:
        return Vector2(INF, INF)
    return (
        polygon[triangles[0]] + polygon[triangles[1]] + polygon[triangles[2]]
    ) / 3.0


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures > 0:
        push_error("Province geography query test FAIL: %d checks failed." % _failures)
        quit(1)
        return
    print("Province geography query test PASS: 100 provinces, inland water, bounds, and multipart rings validated.")
    quit(0)
