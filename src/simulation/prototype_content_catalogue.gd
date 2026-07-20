class_name PrototypeContentCatalogue
extends RefCounted


var _goods_by_id: Dictionary[StringName, GoodDefinition]
var _buildings_by_id: Dictionary[StringName, BuildingDefinition]
var _good_ids: Array[StringName]


static func create_from_definitions(
        goods: Array[GoodDefinition],
        buildings: Array[BuildingDefinition]
) -> PrototypeContentCatalogue:
    var good_map: Dictionary[StringName, GoodDefinition] = {}
    var building_map: Dictionary[StringName, BuildingDefinition] = {}
    var ordered_good_ids: Array[StringName] = []
    for building: BuildingDefinition in buildings:
        if building == null:
            return null
        if building_map.has(building.get_building_id()):
            return null
        building_map[building.get_building_id()] = building

    for good: GoodDefinition in goods:
        if good == null:
            return null
        if good_map.has(good.get_good_id()):
            return null
        good_map[good.get_good_id()] = good
        ordered_good_ids.append(good.get_good_id())

    for good: GoodDefinition in goods:
        var provider_is_unknown: bool = (
            good.get_availability_kind() == &"building_provided"
            and not building_map.has(good.get_provider_building_id())
        )
        if provider_is_unknown:
            return null

        for required_id: StringName in good.get_required_good_ids():
            if not good_map.has(required_id):
                return null

    if _has_cycle(good_map):
        return null

    var result: PrototypeContentCatalogue = PrototypeContentCatalogue.new()
    result._goods_by_id = good_map
    result._buildings_by_id = building_map
    # Definition input order is deliberate authoritative catalogue content order.
    result._good_ids = ordered_good_ids.duplicate()
    return result


static func create_bread_capability_slice() -> PrototypeContentCatalogue:
    var buildings: Array[BuildingDefinition] = [
        _building(&"building_farm", "Farm", &"rural_site"),
        _building(&"building_mill", "Mill", &"rural_site"),
        _building(&"building_bakery", "Bakery", &"major_city_workshop"),
    ]
    var goods: Array[GoodDefinition] = [
        _good(&"good_timber", "Timber", &"automatic_local", &"", []),
        _good(
            &"good_firewood",
            "Firewood",
            &"automatic_local",
            &"",
            [&"good_timber"]
        ),
        _good(
            &"good_grain",
            "Grain",
            &"building_provided",
            &"building_farm",
            []
        ),
        _good(
            &"good_flour",
            "Flour",
            &"building_provided",
            &"building_mill",
            [&"good_grain"]
        ),
        _good(
            &"good_bread",
            "Bread",
            &"building_provided",
            &"building_bakery",
            [&"good_flour", &"good_firewood"]
        ),
    ]
    return create_from_definitions(goods, buildings)


func get_good_definition(good_id: StringName) -> GoodDefinition:
    return _goods_by_id.get(good_id)


func get_building_definition(building_id: StringName) -> BuildingDefinition:
    return _buildings_by_id.get(building_id)


func get_good_ids() -> Array[StringName]:
    return _good_ids.duplicate()


static func _good(
        good_id: StringName,
        display_name: String,
        availability_kind: StringName,
        provider_building_id: StringName,
        required_good_ids: Array[StringName]
) -> GoodDefinition:
    return GoodDefinition.create_from_data({
        "good_id": good_id,
        "display_name": display_name,
        "scope_kind": &"province_local",
        "availability_kind": availability_kind,
        "provider_building_id": provider_building_id,
        "required_good_ids": required_good_ids,
    })


static func _building(
        building_id: StringName,
        display_name: String,
        placement_kind: StringName
) -> BuildingDefinition:
    return BuildingDefinition.create_from_data({
        "building_id": building_id,
        "display_name": display_name,
        "placement_kind": placement_kind,
    })


static func _has_cycle(
        goods: Dictionary[StringName, GoodDefinition]
) -> bool:
    var states: Dictionary[StringName, int] = {}
    var ids: Array[StringName] = goods.keys()
    ids.sort()
    for id: StringName in ids:
        if _visit(id, goods, states):
            return true

    return false


static func _visit(
        good_id: StringName,
        goods: Dictionary[StringName, GoodDefinition],
        states: Dictionary[StringName, int]
) -> bool:
    var state: int = states.get(good_id, 0)
    if state == 1:
        return true
    if state == 2:
        return false

    states[good_id] = 1
    for required_id: StringName in goods[good_id].get_required_good_ids():
        if _visit(required_id, goods, states):
            return true

    states[good_id] = 2
    return false
