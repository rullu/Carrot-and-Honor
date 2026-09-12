extends SceneTree


const REPORT_PATH: String = "res://data/world_map/astra_province_coverage_report.json"
const PROVINCE_DATA_PATH: String = "res://data/world_map/astra_provinces.json"
const CORRECTIONS_PATH: String = "res://data/world_map/astra_province_corrections.json"
const ACCEPTED_LAND_MASK_SHA256: String = "b4d5f3ae4c4eafa53074ad9644df586348b47abcc344c5f57346c92fdd2d61c3"
const IMMUTABLE_SOURCE_SHA256: String = "9c36b97b340c1fb5827b897db4f3798d16b017ce0e9906c26426ff295efaaa90"
const EXPECTED_ACTIVE_COUNT: int = 100
const EXPECTED_RETIRED_IDS: Array[int] = [8, 31, 57, 63, 68, 81, 82]


var _failures: int = 0


func _initialize() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH))
    _check(parsed is Dictionary, "coverage report parses")
    if not parsed is Dictionary:
        _finish()
        return
    var report: Dictionary = parsed
    var authorities: Dictionary = report.get("authorities", {})
    _check(
        authorities.get("province_data", {}).get("sha256", "")
        == FileAccess.get_sha256(PROVINCE_DATA_PATH),
        "coverage report matches current runtime geography"
    )
    _check(
        authorities.get("corrections", {}).get("sha256", "")
        == FileAccess.get_sha256(CORRECTIONS_PATH),
        "coverage report matches current correction manifest"
    )
    _check(
        authorities.get("land_mask", {}).get("sha256", "") == ACCEPTED_LAND_MASK_SHA256,
        "coverage report uses the accepted playable-land authority"
    )
    _check(
        authorities.get("immutable_source", {}).get("sha256", "") == IMMUTABLE_SOURCE_SHA256,
        "coverage report uses the immutable Azgaar authority"
    )
    _check(bool(report.get("passed", false)), "deterministic geography validation passed")
    _check(report.get("validation_errors", []).is_empty(), "validation has no errors")
    _check(int(report.get("active_province_count", 0)) == EXPECTED_ACTIVE_COUNT, "100 provinces are active")
    _check(
        _int_arrays_equal(report.get("retired_province_ids", []), EXPECTED_RETIRED_IDS),
        "retired IDs are explicit"
    )

    var coverage: Dictionary = report.get("raster_coverage", {})
    _check(
        int(coverage.get("meaningful_unassigned_pixels", -1)) == 0,
        "meaningful playable land has complete province coverage"
    )
    _check(
        is_zero_approx(float(coverage.get("meaningful_unassigned_percent", -1.0))),
        "meaningful unassigned playable-land percentage is zero"
    )
    _check(
        int(report.get("vector_overlap", {}).get("positive_area_pair_count", -1)) == 0,
        "province polygons have no positive-area overlap"
    )
    _check(int(report.get("political_hole_count", -1)) == 0, "province polygons have no political holes")
    var topology: Dictionary = report.get("source_cell_topology", {})
    _check(int(topology.get("unassigned_land_cell_count", -1)) == 0, "source land cells are assigned")
    _check(
        topology.get("active_provinces_without_land_cells", []).is_empty(),
        "every active province contains land"
    )
    _check(
        int(topology.get("assigned_external_water_cell_count", -1)) == 0,
        "external sea and ocean cells remain unassigned"
    )
    _check(
        int(topology.get("remaining_retired_cell_count", -1)) == 0,
        "retired IDs own no source cells"
    )
    _finish()


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)


func _int_arrays_equal(values: Array, expected: Array[int]) -> bool:
    if values.size() != expected.size():
        return false
    for index: int in values.size():
        if int(values[index]) != expected[index]:
            return false
    return true


func _finish() -> void:
    if _failures > 0:
        push_error("Astra province coverage test FAIL: %d checks failed." % _failures)
        quit(1)
        return
    print("Astra province coverage test PASS: accepted land has complete, non-overlapping province coverage.")
    quit(0)
