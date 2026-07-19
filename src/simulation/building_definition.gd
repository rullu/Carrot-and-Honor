class_name BuildingDefinition
extends RefCounted


const REQUIRED_KEYS: Array[String] = [
    "building_id",
    "display_name",
]


var _building_id: StringName
var _display_name: String


static func create_from_data(data: Dictionary) -> BuildingDefinition:
    if data.size() != REQUIRED_KEYS.size():
        return null

    for key: String in REQUIRED_KEYS:
        if not data.has(key):
            return null

    if typeof(data["building_id"]) != TYPE_STRING_NAME:
        return null
    if typeof(data["display_name"]) != TYPE_STRING:
        return null

    var building_id: StringName = data["building_id"]
    var display_name: String = data["display_name"]

    if not _is_valid_building_id(building_id):
        return null
    if display_name.is_empty() or display_name != display_name.strip_edges():
        return null

    var definition: BuildingDefinition = BuildingDefinition.new()
    definition._building_id = building_id
    definition._display_name = display_name
    return definition


func get_building_id() -> StringName:
    return _building_id


func get_display_name() -> String:
    return _display_name


static func _is_valid_building_id(building_id: StringName) -> bool:
    var id_text: String = String(building_id)
    if not id_text.begins_with("building_"):
        return false

    var suffix: String = id_text.substr(9)
    if suffix.is_empty() or suffix.begins_with("_"):
        return false

    var previous_was_underscore: bool = false
    for character_index: int in range(suffix.length()):
        var character: String = suffix[character_index]
        if character == "_":
            if previous_was_underscore:
                return false
            previous_was_underscore = true
            continue

        previous_was_underscore = false
        var character_code: int = character.unicode_at(0)
        var is_lowercase_letter: bool = character_code >= 97 and character_code <= 122
        var is_digit: bool = character_code >= 48 and character_code <= 57
        if not is_lowercase_letter and not is_digit:
            return false

    return not previous_was_underscore
