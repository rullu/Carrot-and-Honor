class_name EconomyStartValidator
extends RefCounted


static func validate(state: CampaignState, catalogue: EconomyCatalogue = null) -> PackedStringArray:
    var errors: PackedStringArray = CampaignValidator.validate_data(state.to_data())
    if not errors.is_empty():
        return errors
    if state.economy_generation == null:
        return PackedStringArray(["Campaign economy has not been generated."])
    if catalogue == null:
        catalogue = EconomyCatalogue.new()
    var config: EconomyConfig = state.economy_generation.config
    var world: EconomyWorld = EconomyWorld.new(state, config)
    var true_counts: Dictionary = EconomyRules.totals(state)
    var visible_counts: Dictionary = EconomyRules.totals(state, true)
    for type_id: String in EconomyRules.TRUE_FLOORS:
        if int(true_counts.get(type_id, 0)) < EconomyRules.TRUE_FLOORS[type_id] or int(visible_counts.get(type_id, 0)) < EconomyRules.VISIBLE_FLOORS[type_id]:
            errors.append("Day-1 true/visible world floor failed for " + type_id)
    for province: ProvinceState in state.provinces.values():
        var canon: Dictionary = world.starting_identity(province.province_id)
        if province.owner_realm_id != canon["starting_realm_id"] or province.local_culture != canon["culture"] or province.local_religion != canon["religion"]:
            errors.append("Economy start requires unchanged canonical Province identity/ownership.")
        var hidden: int = 0
        for item: EconomyOpportunity in province.economy.opportunities:
            if province.owner_realm_id not in item.known_realm_ids:
                hidden += 1
            for id: String in item.known_realm_ids:
                if id != province.owner_realm_id:
                    errors.append("No foreign Day-1 opportunity knowledge is generated.")
        if hidden > 1 or province.economy.buildings.size() > 3:
            errors.append("Day-1 hidden/building cap exceeded.")
        var expected_count: int = maxi(EconomyGenerator.building_count(state, config, province),
            config.authored("authored_buildings", province.province_id).size())
        if province.economy.buildings.size() != expected_count:
            errors.append("Starting building count differs from the independent roll/mandatory maximum.")
        for category: String in ["sites", "buildings"]:
            var authored: Array[Dictionary] = config.authored("authored_" + category, province.province_id)
            var mandatory: Dictionary = {}
            for entry: Dictionary in authored:
                mandatory[entry["type_id"]] = entry
            var found: Dictionary = {}
            var random_count: int = 0
            for item: EconomyInstance in province.economy.get(category):
                if item.state != "active" or item.form != "base" or item.origin_culture != province.local_culture or item.origin_religion != province.local_religion or item.origin_realm_id != province.owner_realm_id:
                    errors.append("Starting instance lifecycle/variant/origin is invalid.")
                if item.origin == "authored":
                    if not mandatory.has(item.type_id):
                        errors.append("Unexpected authored starting instance.")
                    else:
                        found[item.type_id] = true
                        if not EconomyRules.authored_valid(mandatory[item.type_id], province, world):
                            errors.append("Authored start prerequisite failed.")
                elif item.origin == "random":
                    random_count += 1
                    var definition: EconomyDefinition = catalogue.sites.get(item.type_id) if category == "sites" else catalogue.buildings.get(item.type_id)
                    if definition == null or not definition.day_one_random:
                        errors.append("Type is excluded from normal Day-1 generation.")
                else:
                    errors.append("Later instance cannot appear in campaign-start state.")
                if category == "buildings" and not EconomyRules.building_valid(catalogue.buildings[item.type_id], province, world):
                    errors.append("Day-1 building prerequisite failed.")
            if found.size() != mandatory.size():
                errors.append("Mandatory authored start is missing.")
            if category == "sites" and (random_count > 1 or (not authored.is_empty() and random_count != 0)):
                errors.append("Authored countryside start must suppress the single RNG site.")
    return errors
