class_name GoodDefinition
extends RefCounted


const REQUIRED_KEYS: Array[String] = [
    "good_id",
    "display_name",
]


var _good_id: StringName
var _display_name: String


static func create_from_data(data: Dictionary) -> GoodDefinition:
    if data.size() != REQUIRED_KEYS.size():
        return null

    for key: String in REQUIRED_KEYS:
        if not data.has(key):
            return null

    if typeof(data["good_id"]) != TYPE_STRING_NAME:
        return null
    if typeof(data["display_name"]) != TYPE_STRING:
        return null

    var good_id: StringName = data["good_id"]
    var display_name: String = data["display_name"]

    if not _is_valid_good_id(good_id):
        return null
    if display_name.is_empty() or display_name != display_name.strip_edges():
        return null

    var definition: GoodDefinition = GoodDefinition.new()
    definition._good_id = good_id
    definition._display_name = display_name
    return definition


func get_good_id() -> StringName:
    return _good_id


func get_display_name() -> String:
    return _display_name


static func _is_valid_good_id(good_id: StringName) -> bool:
    var id_text: String = String(good_id)
    if not id_text.begins_with("good_"):
        return false

    var suffix: String = id_text.substr(5)
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
