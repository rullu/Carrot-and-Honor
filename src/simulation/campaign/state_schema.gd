class_name StateSchema
extends RefCounted


const MAX_SAFE_INTEGER: int = 9007199254740991
const RELIGION_FIELDS: Dictionary = {
    "broad_faith": "text", "grand_tradition": "nullable_text",
    "communion": "nullable_text", "institution_or_tradition": "nullable_text",
    "rite_or_belief": "text",
}
const ATTITUDE_FIELDS: Dictionary = {
    "trust": "integer", "respect": "integer", "fear": "integer", "grievance": "integer",
}


static func empty_religion() -> Dictionary:
    return {"broad_faith": "", "grand_tradition": null, "communion": null,
        "institution_or_tradition": null, "rite_or_belief": ""}


static func neutral_attitude() -> Dictionary:
    return {"trust": 0, "respect": 0, "fear": 0, "grievance": 0}


static func integer_array(values: Array) -> Array[int]:
    var result: Array[int] = []
    for value: Variant in values:
        result.append(int(value))
    return result


static func normalized_attitude(value: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for key: String in value:
        result[key] = int(value[key])
    return result


static func records_to_data(records: Array) -> Array:
    var result: Array = []
    for record: RefCounted in records:
        result.append(record.to_data() if record != null else null)
    return result


static func is_integer(value: Variant) -> bool:
    if value is int:
        return value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER
    return value is float and is_finite(value) and absf(value) <= MAX_SAFE_INTEGER and value == floor(value)


static func is_id(value: Variant) -> bool:
    return value is String and not value.is_empty() and value == value.strip_edges()


static func validate_record(value: Variant, fields: Dictionary, context: String, errors: PackedStringArray) -> void:
    if not value is Dictionary:
        errors.append(context + " must be an object.")
        return
    for key: Variant in value:
        if not fields.has(key):
            errors.append("%s has unknown field %s." % [context, str(key)])
    for key: String in fields:
        if not value.has(key):
            errors.append("%s is missing %s." % [context, key])
        else:
            _validate_value(value[key], fields[key], context + "." + key, errors)


static func _validate_value(value: Variant, kind: String, context: String, errors: PackedStringArray) -> void:
    var valid: bool = true
    match kind:
        "seed": valid = value is String and not value.is_empty()
        "sex": valid = value is String and value in ["male", "female"]
        "lineage_style": valid = value is String and value in ["house", "dynasty", "clan", "family", "lineage"]
        "id": valid = is_id(value)
        "text": valid = value is String and value == value.strip_edges()
        "nullable_text": valid = value == null or (value is String and value == value.strip_edges())
        "bool": valid = value is bool
        "array": valid = value is Array
        "object": valid = value is Dictionary
        "integer": valid = is_integer(value)
        "count": valid = is_integer(value) and value >= 0
        "positive_int": valid = is_integer(value) and value > 0
        "target_kind": valid = value is String and value in ["province", "realm"]
        "target_id": valid = is_id(value) or (is_integer(value) and value > 0)
        "religion": validate_record(value, RELIGION_FIELDS, context, errors)
        "attitude": validate_record(value, ATTITUDE_FIELDS, context, errors)
        "ids", "province_ids":
            if not value is Array:
                valid = false
            else:
                var seen: Dictionary = {}
                for item: Variant in value:
                    var item_valid: bool = is_id(item) if kind == "ids" else (is_integer(item) and item > 0)
                    var identity: Variant = int(item) if kind == "province_ids" and item_valid else item
                    if not item_valid or seen.has(identity):
                        errors.append(context + " contains an invalid or duplicate ID.")
                    if item_valid:
                        seen[identity] = true
        "claims", "history":
            if not value is Array:
                valid = false
            else:
                var fields: Dictionary = ClaimRecord.FIELDS if kind == "claims" else HistoricalMemory.FIELDS
                for index: int in value.size():
                    validate_record(value[index], fields, "%s[%d]" % [context, index], errors)
        _:
            valid = false
    if not valid:
        errors.append("%s has invalid %s value." % [context, kind])
