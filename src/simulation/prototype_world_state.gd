class_name PrototypeWorldState
extends RefCounted


const DISTINCTIVE_VALUES: Dictionary = {
    1: {"population": 3200, "food": 70, "carrots": 35, "development": 1},
    5: {"population": 6100, "food": 85, "carrots": 42, "development": 2},
    12: {"population": 2700, "food": 64, "carrots": 88, "development": 2},
    27: {"population": 8400, "food": 100, "carrots": 50, "development": 1},
    42: {"population": 4900, "food": 76, "carrots": 31, "development": 3},
    83: {"population": 7300, "food": 93, "carrots": 61, "development": 2},
}


var _province_states: Dictionary[int, PrototypeProvinceMetrics] = {}


static func create(province_ids: PackedInt32Array) -> PrototypeWorldState:
    if province_ids.is_empty():
        return null

    var seen_ids: Dictionary[int, bool] = {}
    for province_id: int in province_ids:
        if province_id <= 0 or seen_ids.has(province_id):
            return null
        seen_ids[province_id] = true

    var world_state: PrototypeWorldState = PrototypeWorldState.new()
    for province_id: int in province_ids:
        var values: Dictionary = DISTINCTIVE_VALUES.get(
            province_id,
            {"population": 1200, "food": 40, "carrots": 20, "development": 0}
        )
        var province_state: PrototypeProvinceMetrics = PrototypeProvinceMetrics.create(
            province_id,
            values["population"],
            values["food"],
            values["carrots"],
            values["development"]
        )
        if province_state == null:
            return null
        world_state._province_states[province_id] = province_state

    return world_state


func get_province_state(province_id: int) -> PrototypeProvinceMetrics:
    return _province_states.get(province_id)


func get_province_count() -> int:
    return _province_states.size()
