class_name ProvinceCapabilityState
extends RefCounted


var _present_building_ids: Array[StringName]
var _available_good_ids: Array[StringName]
var _blocked_good_ids: Array[StringName]
var _missing_provider_building_ids_by_good_id: Dictionary[StringName, StringName]
var _missing_required_good_ids_by_good_id: Dictionary[StringName, Array]


static func create(
        catalogue: PrototypeContentCatalogue,
        present_building_ids: Array[StringName]
) -> ProvinceCapabilityState:
    if catalogue == null:
        return null

    var copied_building_ids: Array[StringName] = []
    for building_id: StringName in present_building_ids:
        if catalogue.get_building_definition(building_id) == null:
            return null
        if building_id in copied_building_ids:
            return null
        copied_building_ids.append(building_id)
    copied_building_ids.sort_custom(_building_id_precedes)

    var catalogue_good_ids: Array[StringName] = catalogue.get_good_ids()
    var available_good_ids_by_id: Dictionary[StringName, bool] = {}
    var added_capability: bool = true
    while added_capability:
        added_capability = false
        for good_id: StringName in catalogue_good_ids:
            if available_good_ids_by_id.has(good_id):
                continue

            var definition: GoodDefinition = catalogue.get_good_definition(good_id)
            if not _provider_is_present(definition, copied_building_ids):
                continue
            if not _requirements_are_available(
                definition,
                available_good_ids_by_id
            ):
                continue

            available_good_ids_by_id[good_id] = true
            added_capability = true

    var available_good_ids: Array[StringName] = []
    var blocked_good_ids: Array[StringName] = []
    var missing_providers: Dictionary[StringName, StringName] = {}
    var missing_requirements: Dictionary[StringName, Array] = {}
    for good_id: StringName in catalogue_good_ids:
        if available_good_ids_by_id.has(good_id):
            available_good_ids.append(good_id)
            continue

        blocked_good_ids.append(good_id)
        var definition: GoodDefinition = catalogue.get_good_definition(good_id)
        if (
            definition.get_availability_kind() == &"building_provided"
            and definition.get_provider_building_id() not in copied_building_ids
        ):
            missing_providers[good_id] = definition.get_provider_building_id()

        var direct_missing_requirements: Array[StringName] = []
        for required_good_id: StringName in definition.get_required_good_ids():
            if not available_good_ids_by_id.has(required_good_id):
                direct_missing_requirements.append(required_good_id)
        missing_requirements[good_id] = direct_missing_requirements.duplicate()

    var state: ProvinceCapabilityState = ProvinceCapabilityState.new()
    state._present_building_ids = copied_building_ids.duplicate()
    state._available_good_ids = available_good_ids.duplicate()
    state._blocked_good_ids = blocked_good_ids.duplicate()
    state._missing_provider_building_ids_by_good_id = missing_providers
    state._missing_required_good_ids_by_good_id = missing_requirements
    return state


func get_present_building_ids() -> Array[StringName]:
    return _present_building_ids.duplicate()


func get_available_good_ids() -> Array[StringName]:
    return _available_good_ids.duplicate()


func get_blocked_good_ids() -> Array[StringName]:
    return _blocked_good_ids.duplicate()


func has_capability_result(good_id: StringName) -> bool:
    return good_id in _available_good_ids or good_id in _blocked_good_ids


func is_good_available(good_id: StringName) -> bool:
    return good_id in _available_good_ids


func get_missing_provider_building_id(good_id: StringName) -> StringName:
    return _missing_provider_building_ids_by_good_id.get(good_id, &"")


func get_missing_required_good_ids(good_id: StringName) -> Array[StringName]:
    if not _missing_required_good_ids_by_good_id.has(good_id):
        return []
    return _missing_required_good_ids_by_good_id[good_id].duplicate()


static func _provider_is_present(
        definition: GoodDefinition,
        present_building_ids: Array[StringName]
) -> bool:
    if definition.get_availability_kind() == &"automatic_local":
        return true
    return definition.get_provider_building_id() in present_building_ids


static func _building_id_precedes(left: StringName, right: StringName) -> bool:
    return String(left) < String(right)


static func _requirements_are_available(
        definition: GoodDefinition,
        available_good_ids_by_id: Dictionary[StringName, bool]
) -> bool:
    for required_good_id: StringName in definition.get_required_good_ids():
        if not available_good_ids_by_id.has(required_good_id):
            return false
    return true
