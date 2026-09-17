extends SceneTree


const ProvinceGeographyScript: GDScript = preload("res://src/gameplay/province_geography.gd")
const PrototypeProvinceMetricsScript: GDScript = preload("res://src/simulation/prototype_province_metrics.gd")
const PrototypeWorldStateScript: GDScript = preload("res://src/simulation/prototype_world_state.gd")


var _failures: int = 0


func _initialize() -> void:
    var geography: ProvinceGeography = ProvinceGeographyScript.load_from_path(
        "res://data/world_map/astra_provinces.json"
    )
    _check(geography != null, "province geography loads")
    if geography == null:
        _finish()
        return
    var world_state: PrototypeWorldState = PrototypeWorldStateScript.create(
        geography.get_province_ids()
    )
    _check(world_state != null, "prototype world state constructs")
    if world_state == null:
        _finish()
        return

    _check(world_state.get_province_count() == geography.get_province_count(), "all active provinces receive runtime state")
    for province_id: int in geography.get_province_ids():
        var state: PrototypeProvinceMetrics = world_state.get_province_state(province_id)
        _check(state != null, "province %d has runtime state" % province_id)
        if state != null:
            _check(state.get_province_id() == province_id, "province %d state ID matches" % province_id)

    var province_27: PrototypeProvinceMetrics = world_state.get_province_state(27)
    _check(province_27.get_population() == 8400, "province fixture population is available")
    _check(province_27.get_food() == 100, "province fixture Food is available")
    _check(province_27.get_carrots() == 50, "province fixture Carrots are available")
    _check(province_27.get_development() == 1, "province fixture development is available")

    _check(
        PrototypeProvinceMetricsScript.create(0, 0, 0, 0, 0) == null,
        "province state rejects a non-positive province ID"
    )
    _check(
        PrototypeProvinceMetricsScript.create(1, -1, 0, 0, 0) == null,
        "province state rejects negative prototype metrics"
    )
    var prototype_source: String = FileAccess.get_file_as_string(
        "res://src/simulation/prototype_world_state.gd"
    )
    _check("RealmState" not in prototype_source, "prototype metrics own no parallel realm state")
    _check("realm_" not in prototype_source, "prototype metrics own no mock political IDs")
    _finish()


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures > 0:
        push_error("Province/realm state test FAIL: %d checks failed." % _failures)
        quit(1)
        return
    print("Province state test PASS: synthetic metrics remain isolated from canonical identity and ownership.")
    quit(0)
