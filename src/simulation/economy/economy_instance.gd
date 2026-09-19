class_name EconomyInstance
extends RefCounted

# Shared physical-instance record; catalogue kind decides countryside/city placement.
const FIELDS: Dictionary = {
    "instance_id": "id", "type_id": "id", "origin": "id", "state": "id",
    "form": "id", "origin_realm_id": "id", "origin_culture": "id",
    "origin_religion": "religion",
}
const STATES: Array[String] = ["under_construction", "active", "disrupted", "recovering"]
var instance_id: String = ""
var type_id: String = ""
var origin: String = "random"
var state: String = "active"
var form: String = "base"
var origin_realm_id: String = ""
var origin_culture: String = ""
var origin_religion: Dictionary = StateSchema.empty_religion()


func to_data() -> Dictionary:
    return {"instance_id": instance_id, "type_id": type_id, "origin": origin,
        "state": state, "form": form, "origin_realm_id": origin_realm_id,
        "origin_culture": origin_culture, "origin_religion": origin_religion.duplicate(true)}


static func from_data(data: Dictionary) -> EconomyInstance:
    var result: EconomyInstance = EconomyInstance.new()
    result.instance_id = data["instance_id"]
    result.type_id = data["type_id"]
    result.origin = data["origin"]
    result.state = data["state"]
    result.form = data["form"]
    result.origin_realm_id = data["origin_realm_id"]
    result.origin_culture = data["origin_culture"]
    result.origin_religion = data["origin_religion"].duplicate(true)
    return result
