class_name EconomyFixture
extends RefCounted

# Synthetic tuning and suitability bindings only. None of these values are canon.
static func config() -> EconomyConfig:
    var catalogue: EconomyCatalogue = EconomyCatalogue.new()
    var data: Dictionary = {
        "config_id": "economy_test_fixture", "config_version": 1, "status": "fixture",
        "strategic_slots": 10, "opportunity_weights": {}, "hidden_chance_bp": 2700,
        "rare_opportunity_ids": ["opportunity_gold", "opportunity_gemstones"],
        "anti_cluster_penalty_bp": 7500, "powerhouse_realm_ids": ["R002", "R028"],
        "authored_sites": [], "authored_buildings": [], "geography": [],
        "domain_versions": {"opportunities": 1, "hiding": 1, "sites": 1, "buildings": 1},
    }
    for id: String in catalogue.opportunities:
        data["opportunity_weights"][id] = 100
    var identity: RefCounted = WorldIdentityCatalogue.load_default()
    for id: int in identity.get_province_ids():
        data["geography"].append({"province_id": id, "coast": id % 3 == 0, "aquatic": id % 3 == 0 or id % 5 == 0})
    return EconomyConfig.from_data(data)


static func authored(province_id: int, type_id: String) -> Dictionary:
    return {"province_id": province_id, "type_id": type_id, "opportunity_any": [], "site_any": [], "requires_coast": false}


static func economy_data(state: CampaignState, categories: Array[String] = ["opportunities", "sites", "buildings"]) -> Dictionary:
    var result: Dictionary = {}
    for id: int in state.provinces:
        var record: Dictionary = {}
        var data: Dictionary = state.provinces[id].economy.to_data()
        for category: String in categories:
            record[category] = data[category]
        result[str(id)] = record
    return result
