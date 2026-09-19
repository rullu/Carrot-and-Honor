class_name EconomyCatalogue
extends RefCounted

const PATH: String = "res://data/economy/economy_catalogue_v1.json"
var opportunities: Dictionary[String, EconomyDefinition] = {}
var sites: Dictionary[String, EconomyDefinition] = {}
var buildings: Dictionary[String, EconomyDefinition] = {}
var background_access: Array[String] = []
var content_version: int = 1
var fingerprint: String = ""
var errors: PackedStringArray = []


func _init(data: Variant = null) -> void:
    if data == null:
        data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    StateSchema.validate_record(data, {"content_version": "positive_int", "background_access": "ids", "definitions": "array"}, "Economy catalogue", errors)
    if not errors.is_empty():
        return
    content_version = int(data["content_version"])
    fingerprint = JSON.stringify(data, "", true, true).sha256_text()
    background_access.assign(data["background_access"])
    var seen: Dictionary = {}
    for entry: Variant in data["definitions"]:
        StateSchema.validate_record(entry, EconomyDefinition.FIELDS, "Economy definition", errors)
        if not errors.is_empty():
            return
        var definition: EconomyDefinition = EconomyDefinition.from_data(entry)
        if seen.has(definition.definition_id) or definition.kind not in ["opportunity", "site", "building"]:
            errors.append("Duplicate definition or unknown economic kind.")
            return
        seen[definition.definition_id] = true
        if not definition.definition_id.begins_with(definition.kind + "_"):
            errors.append("Economy definition ID has the wrong namespace.")
        if definition.requirement not in ["always", "source", "coast", "grain", "authored"]:
            errors.append("Unknown prerequisite rule.")
        match definition.kind:
            "opportunity": opportunities[definition.definition_id] = definition
            "site": sites[definition.definition_id] = definition
            "building": buildings[definition.definition_id] = definition
    for site: EconomyDefinition in sites.values():
        if site.source_id != "aquatic" and not opportunities.has(site.source_id):
            errors.append("Site has unresolved source: " + site.definition_id)
    if content_version != 1 or opportunities.size() != 26 or sites.size() != 32 or buildings.size() != 37 or random_buildings().size() != 13:
        errors.append("Unsupported/incomplete sealed economy catalogue.")


func random_buildings() -> Array[String]:
    var result: Array[String] = []
    for definition: EconomyDefinition in buildings.values():
        if definition.day_one_random:
            result.append(definition.definition_id)
    result.sort()
    return result
