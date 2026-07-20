class_name GoodDefinition
extends RefCounted


const REQUIRED_KEYS: Array[String] = [
    "good_id",
    "display_name",
    "scope_kind",
    "availability_kind",
    "provider_building_id",
    "required_good_ids",
]
const SUPPORTED_SCOPE_KINDS: Array[StringName] = [&"province_local"]
const SUPPORTED_AVAILABILITY_KINDS: Array[StringName] = [
    &"automatic_local",
    &"building_provided",
]


var _good_id: StringName
var _display_name: String
var _scope_kind: StringName
var _availability_kind: StringName
var _provider_building_id: StringName
var _required_good_ids: Array[StringName]


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
    if typeof(data["scope_kind"]) != TYPE_STRING_NAME:
        return null
    if typeof(data["availability_kind"]) != TYPE_STRING_NAME:
        return null
    if typeof(data["provider_building_id"]) != TYPE_STRING_NAME:
        return null
    if typeof(data["required_good_ids"]) != TYPE_ARRAY:
        return null

    var good_id: StringName = data["good_id"]
    var display_name: String = data["display_name"]
    var scope_kind: StringName = data["scope_kind"]
    var availability_kind: StringName = data["availability_kind"]
    var provider_building_id: StringName = data["provider_building_id"]
    var source_required_good_ids: Array = data["required_good_ids"]

    if not _is_valid_good_id(good_id):
        return null
    if display_name.is_empty() or display_name != display_name.strip_edges():
        return null
    if scope_kind not in SUPPORTED_SCOPE_KINDS:
        return null
    if availability_kind not in SUPPORTED_AVAILABILITY_KINDS:
        return null
    if availability_kind == &"automatic_local" and not provider_building_id.is_empty():
        return null
    if (
        availability_kind == &"building_provided"
        and not _is_valid_building_id(provider_building_id)
    ):
        return null

    var required_good_ids: Array[StringName] = []
    for prerequisite: Variant in source_required_good_ids:
        if typeof(prerequisite) != TYPE_STRING_NAME:
            return null

        var prerequisite_id: StringName = prerequisite
        if not _is_valid_good_id(prerequisite_id):
            return null
        if prerequisite_id == good_id:
            return null
        if prerequisite_id in required_good_ids:
            return null

        required_good_ids.append(prerequisite_id)

    var definition: GoodDefinition = GoodDefinition.new()
    definition._good_id = good_id
    definition._display_name = display_name
    definition._scope_kind = scope_kind
    definition._availability_kind = availability_kind
    definition._provider_building_id = provider_building_id
    definition._required_good_ids = required_good_ids.duplicate()
    return definition


func get_good_id() -> StringName:
    return _good_id


func get_display_name() -> String:
    return _display_name


func get_scope_kind() -> StringName:
    return _scope_kind


func get_availability_kind() -> StringName:
    return _availability_kind


func get_provider_building_id() -> StringName:
    return _provider_building_id


func get_required_good_ids() -> Array[StringName]:
    return _required_good_ids.duplicate()


static func _is_valid_good_id(identifier: StringName) -> bool:
    var id_text: String = String(identifier)
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


static func _is_valid_building_id(identifier: StringName) -> bool:
    var id_text: String = String(identifier)
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
