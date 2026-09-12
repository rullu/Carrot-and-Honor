extends SceneTree


const ProvinceGeographyScript: GDScript = preload("res://src/gameplay/province_geography.gd")
const ProvinceStateScript: GDScript = preload("res://src/simulation/province_state.gd")
const RealmStateScript: GDScript = preload("res://src/simulation/realm_state.gd")
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
        var state: ProvinceState = world_state.get_province_state(province_id)
        _check(state != null, "province %d has runtime state" % province_id)
        if state != null:
            _check(
                world_state.get_realm_state(state.get_realm_id()) != null,
                "province %d realm reference resolves" % province_id
            )

    var multi_members: PackedInt32Array = world_state.get_province_ids_for_realm(
        &"realm_hasenreich"
    )
    _check(multi_members == PackedInt32Array([5, 27, 42]), "multi-province realm is independent")
    var single_members: PackedInt32Array = world_state.get_province_ids_for_realm(
        &"realm_bunnyhausen"
    )
    _check(single_members == PackedInt32Array([12]), "one-province realm is valid")

    var province_27: ProvinceState = world_state.get_province_state(27)
    var realm_27: RealmState = world_state.get_realm_for_province(27)
    _check(province_27.get_realm_id() == &"realm_hasenreich", "province stores a realm ID")
    _check(realm_27.get_display_name() == "Hasenreich", "realm owns its separate identity")
    _check(realm_27.get_realm_type() == &"kingdom", "realm type remains realm data")
    _check(province_27.get_population() == 8400, "province fixture population is available")
    _check(province_27.get_food() == 100, "province fixture Food is available")
    _check(province_27.get_carrots() == 50, "province fixture Carrots are available")
    _check(province_27.get_development() == 1, "province fixture development is available")

    _check(
        ProvinceStateScript.create(1, &"", 0, 0, 0, 0) == null,
        "province state rejects an ambiguous empty realm reference"
    )
    _check(
        RealmStateScript.create(&"province_1", "Wrong", &"kingdom") == null,
        "realm state rejects a province-shaped ID"
    )
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
    print("Province/realm state test PASS: separate one-province and multi-province realms validated.")
    quit(0)
