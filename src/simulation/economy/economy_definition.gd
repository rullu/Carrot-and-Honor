class_name EconomyDefinition
extends RefCounted

const FIELDS: Dictionary = {
    "definition_id": "id", "display_name": "id", "kind": "id",
    "source_id": "text", "day_one_random": "bool", "requirement": "id",
}

var definition_id: String
var display_name: String
var kind: String
var source_id: String
var day_one_random: bool
var requirement: String


static func from_data(data: Dictionary) -> EconomyDefinition:
    var result: EconomyDefinition = EconomyDefinition.new()
    result.definition_id = data["definition_id"]
    result.display_name = data["display_name"]
    result.kind = data["kind"]
    result.source_id = data["source_id"]
    result.day_one_random = data["day_one_random"]
    result.requirement = data["requirement"]
    return result
