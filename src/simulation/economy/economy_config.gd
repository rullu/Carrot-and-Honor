class_name EconomyConfig
extends RefCounted

const PATH: String = "res://data/economy/campaign_economy_v1.json"
const FIELDS: Dictionary = {
    "config_id": "id", "config_version": "positive_int", "status": "id",
    "strategic_slots": "positive_int", "opportunity_weights": "object",
    "hidden_chance_bp": "count", "rare_opportunity_ids": "ids", "anti_cluster_penalty_bp": "count",
    "powerhouse_realm_ids": "ids", "authored_sites": "array", "authored_buildings": "array",
    "geography": "array", "domain_versions": "object",
}
const DOMAIN_FIELDS: Dictionary = {"opportunities": "positive_int", "hiding": "positive_int", "sites": "positive_int", "buildings": "positive_int"}
const GEOGRAPHY_FIELDS: Dictionary = {"province_id": "positive_int", "coast": "bool", "aquatic": "bool"}
const AUTHORED_FIELDS: Dictionary = {
    "province_id": "positive_int", "type_id": "id", "opportunity_any": "ids", "site_any": "ids", "requires_coast": "bool",
}
var config_id: String
var config_version: int
var status: String
var strategic_slots: int
var opportunity_weights: Dictionary[String, int] = {}
var hidden_chance_bp: int
var rare_opportunity_ids: Array[String] = []
var anti_cluster_penalty_bp: int
var powerhouse_realm_ids: Array[String] = []
# These dictionaries have exact, recursively validated schemas, not extension bags.
var authored_sites: Array[Dictionary] = []
var authored_buildings: Array[Dictionary] = []
var geography: Array[Dictionary] = []
var domain_versions: Dictionary[String, int] = {}


static func validate_data(data: Variant, catalogue: EconomyCatalogue) -> PackedStringArray:
    var errors: PackedStringArray = []
    StateSchema.validate_record(data, FIELDS, "Economy configuration (unresolved values require authoring)", errors)
    if not errors.is_empty():
        return errors
    if data["status"] not in ["fixture", "approved"]:
        errors.append("Canonical economy configuration is incomplete; fixture values are not canon.")
    if data["strategic_slots"] < 3:
        errors.append("Strategic capacity must support the sealed max-three Day-1 start.")
    if data["hidden_chance_bp"] > 10000 or data["anti_cluster_penalty_bp"] >= 10000:
        errors.append("Probability must be 0..10000 basis points; soft penalty must remain below 10000.")
    StateSchema.validate_record(data["domain_versions"], DOMAIN_FIELDS, "Economy domain versions", errors)
    var positive: int = 0
    for id: Variant in data["opportunity_weights"]:
        var weight: Variant = data["opportunity_weights"][id]
        if not catalogue.opportunities.has(id) or not StateSchema.is_integer(weight) or weight < 0 or weight > 1000000:
            errors.append("Unknown opportunity or invalid integer rarity weight (0..1000000).")
        elif weight > 0:
            positive += 1
    if data["opportunity_weights"].size() != catalogue.opportunities.size() or positive < 3:
        errors.append("Explicit weights for every opportunity and at least three selectable types are required.")
    for id: String in data["rare_opportunity_ids"]:
        if not catalogue.opportunities.has(id):
            errors.append("Unknown anti-clustering opportunity.")
    var seen: Dictionary = {}
    for entry: Variant in data["geography"]:
        StateSchema.validate_record(entry, GEOGRAPHY_FIELDS, "Economy fixed-geography binding", errors)
        if not errors.is_empty():
            return errors
        if seen.has(int(entry["province_id"])):
            errors.append("Duplicate fixed-geography Province.")
        seen[int(entry["province_id"])] = true
        if entry["coast"] and not entry["aquatic"]:
            errors.append("Suitable coast must also be suitable aquatic access.")
    for category: String in ["authored_sites", "authored_buildings"]:
        seen.clear()
        var counts: Dictionary = {}
        for entry: Variant in data[category]:
            StateSchema.validate_record(entry, AUTHORED_FIELDS, "Authored start", errors)
            if not errors.is_empty():
                return errors
            var id: int = int(entry["province_id"])
            var key: String = str(id) + ":" + entry["type_id"]
            var definitions: Dictionary = catalogue.sites if category == "authored_sites" else catalogue.buildings
            if not definitions.has(entry["type_id"]) or seen.has(key):
                errors.append("Unknown or duplicate authored economic type.")
            seen[key] = true
            counts[id] = int(counts.get(id, 0)) + 1
            if category == "authored_buildings" and counts[id] > 3:
                errors.append("More than three mandatory starting buildings.")
            for source: String in entry["opportunity_any"]:
                if not catalogue.opportunities.has(source):
                    errors.append("Unknown authored opportunity prerequisite.")
            for source: String in entry["site_any"]:
                if not catalogue.sites.has(source):
                    errors.append("Unknown authored site prerequisite.")
    return errors


static func from_data(data: Dictionary) -> EconomyConfig:
    var result: EconomyConfig = EconomyConfig.new()
    result.config_id = data["config_id"]
    result.config_version = int(data["config_version"])
    result.status = data["status"]
    result.strategic_slots = int(data["strategic_slots"])
    result.hidden_chance_bp = int(data["hidden_chance_bp"])
    result.anti_cluster_penalty_bp = int(data["anti_cluster_penalty_bp"])
    for id: String in data["opportunity_weights"]:
        result.opportunity_weights[id] = int(data["opportunity_weights"][id])
    for id: String in data["domain_versions"]:
        result.domain_versions[id] = int(data["domain_versions"][id])
    result.rare_opportunity_ids.assign(data["rare_opportunity_ids"])
    result.powerhouse_realm_ids.assign(data["powerhouse_realm_ids"])
    for category: String in ["authored_sites", "authored_buildings", "geography"]:
        for entry: Dictionary in data[category]:
            var record: Dictionary = entry.duplicate(true)
            record["province_id"] = int(record["province_id"])
            result.get(category).append(record)
    return result


static func load_default() -> Dictionary:
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    var errors: PackedStringArray = validate_data(data, EconomyCatalogue.new())
    return {"config": from_data(data) if errors.is_empty() else null, "errors": errors}


func to_data() -> Dictionary:
    var result: Dictionary = {}
    for field: String in FIELDS:
        var value: Variant = get(field)
        result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
    for field: String in ["rare_opportunity_ids", "powerhouse_realm_ids"]:
        result[field].sort()
    for field: String in ["authored_sites", "authored_buildings", "geography"]:
        result[field].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            return JSON.stringify(a, "", true) < JSON.stringify(b, "", true))
    return result


func fingerprint() -> String:
    return JSON.stringify(to_data(), "", true, true).sha256_text()


func authored(category: String, province_id: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry: Dictionary in get(category):
        if int(entry["province_id"]) == province_id:
            result.append(entry.duplicate(true))
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["type_id"] < b["type_id"])
    return result
