class_name PrototypeWorldState
extends RefCounted


const MULTI_PROVINCE_REALM_IDS: Array[int] = [5, 27, 42]
const SINGLE_PROVINCE_REALM_ID: int = 12
const DISTINCTIVE_VALUES: Dictionary = {
    1: {"population": 3200, "food": 70, "carrots": 35, "development": 1},
    5: {"population": 6100, "food": 85, "carrots": 42, "development": 2},
    12: {"population": 2700, "food": 64, "carrots": 88, "development": 2},
    27: {"population": 8400, "food": 100, "carrots": 50, "development": 1},
    42: {"population": 4900, "food": 76, "carrots": 31, "development": 3},
    83: {"population": 7300, "food": 93, "carrots": 61, "development": 2},
}


var _province_states: Dictionary[int, ProvinceState] = {}
var _realm_states: Dictionary[StringName, RealmState] = {}


static func create(province_ids: PackedInt32Array) -> PrototypeWorldState:
    if province_ids.is_empty():
        return null

    var seen_ids: Dictionary[int, bool] = {}
    for province_id: int in province_ids:
        if province_id <= 0 or seen_ids.has(province_id):
            return null
        seen_ids[province_id] = true

    var world_state: PrototypeWorldState = PrototypeWorldState.new()
    var realms: Array[RealmState] = [
        RealmState.create(&"realm_free_league", "Free Province League", &"confederation"),
        RealmState.create(&"realm_hasenreich", "Hasenreich", &"kingdom"),
        RealmState.create(&"realm_bunnyhausen", "Bunnyhausen", &"principality"),
    ]
    for realm: RealmState in realms:
        if realm == null:
            return null
        world_state._realm_states[realm.get_id()] = realm

    for province_id: int in province_ids:
        var realm_id: StringName = &"realm_free_league"
        if province_id in MULTI_PROVINCE_REALM_IDS:
            realm_id = &"realm_hasenreich"
        elif province_id == SINGLE_PROVINCE_REALM_ID:
            realm_id = &"realm_bunnyhausen"

        var values: Dictionary = DISTINCTIVE_VALUES.get(
            province_id,
            {"population": 1200, "food": 40, "carrots": 20, "development": 0}
        )
        var province_state: ProvinceState = ProvinceState.create(
            province_id,
            realm_id,
            values["population"],
            values["food"],
            values["carrots"],
            values["development"]
        )
        if province_state == null:
            return null
        world_state._province_states[province_id] = province_state

    return world_state


func get_province_state(province_id: int) -> ProvinceState:
    return _province_states.get(province_id)


func get_realm_state(realm_id: StringName) -> RealmState:
    return _realm_states.get(realm_id)


func get_realm_for_province(province_id: int) -> RealmState:
    var province_state: ProvinceState = get_province_state(province_id)
    if province_state == null:
        return null
    return get_realm_state(province_state.get_realm_id())


func get_province_ids_for_realm(realm_id: StringName) -> PackedInt32Array:
    var province_ids: PackedInt32Array = []
    for province_id: int in _province_states:
        var state: ProvinceState = _province_states[province_id]
        if state.get_realm_id() == realm_id:
            province_ids.append(province_id)
    province_ids.sort()
    return province_ids


func get_province_count() -> int:
    return _province_states.size()
