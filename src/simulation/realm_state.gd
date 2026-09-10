class_name RealmState
extends RefCounted


var _realm_id: StringName
var _display_name: String
var _realm_type: StringName


static func create(
        realm_id: StringName,
        display_name: String,
        realm_type: StringName
) -> RealmState:
    if not String(realm_id).begins_with("realm_"):
        return null
    if display_name.is_empty() or display_name != display_name.strip_edges():
        return null
    if String(realm_type).is_empty():
        return null

    var state: RealmState = RealmState.new()
    state._realm_id = realm_id
    state._display_name = display_name
    state._realm_type = realm_type
    return state


func get_id() -> StringName:
    return _realm_id


func get_display_name() -> String:
    return _display_name


func get_realm_type() -> StringName:
    return _realm_type
