class_name EconomyLifecycle
extends RefCounted

const TRANSITIONS: Dictionary = {
    "under_construction": ["active"], "active": ["disrupted"],
    "disrupted": ["recovering"], "recovering": ["active", "disrupted"],
}


static func transition(state: CampaignState, province_id: int, instance_id: String, next_state: String) -> PackedStringArray:
    var province: ProvinceState = state.provinces.get(province_id)
    if province == null or province.economy == null:
        return PackedStringArray(["Unknown or uninitialized economy Province."])
    for item: EconomyInstance in province.economy.sites + province.economy.buildings:
        if item.instance_id != instance_id:
            continue
        if next_state not in TRANSITIONS.get(item.state, []):
            return PackedStringArray(["Illegal economy lifecycle transition."])
        item.state = next_state
        return []
    return PackedStringArray(["Unknown economy instance."])
