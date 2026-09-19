class_name EconomyOpportunity
extends RefCounted

const FIELDS: Dictionary = {"type_id": "id", "known_realm_ids": "ids"}
var type_id: String = ""
var known_realm_ids: Array[String] = []


func to_data() -> Dictionary:
    var known: Array[String] = known_realm_ids.duplicate()
    known.sort()
    return {"type_id": type_id, "known_realm_ids": known}


static func from_data(data: Dictionary) -> EconomyOpportunity:
    var result: EconomyOpportunity = EconomyOpportunity.new()
    result.type_id = data["type_id"]
    result.known_realm_ids.assign(data["known_realm_ids"])
    return result
