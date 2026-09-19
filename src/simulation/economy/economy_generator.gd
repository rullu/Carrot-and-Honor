class_name EconomyGenerator
extends RefCounted

const VERSION: int = 1
const OPPORTUNITY_COUNTS: Array[int] = [20, 45, 30, 5]
const NORMAL_COUNTS: Array[int] = [40, 40, 15, 5]
const POWERHOUSE_COUNTS: Array[int] = [20, 40, 30, 10]
const SITE_CHANCE_BP: int = 400


static func stream(state: CampaignState, config: EconomyConfig, domain: String,
        purpose: String, province_id: int = 0) -> CampaignStartRandom:
    # Full configuration is fingerprinted in provenance, not mixed into every stream.
    # An unrelated setting must not perturb another domain's random sequence.
    return CampaignStartRandom.new(JSON.stringify([
        "economy", VERSION, state.campaign_seed, state.world_binding,
        domain, config.domain_versions[domain], purpose, province_id,
    ]))


static func building_count(state: CampaignState, config: EconomyConfig, province: ProvinceState) -> int:
    return stream(state, config, "buildings", "count", province.province_id).weighted(
        POWERHOUSE_COUNTS if province.owner_realm_id in config.powerhouse_realm_ids else NORMAL_COUNTS)


static func generate(initial: CampaignState, supplied_config: EconomyConfig) -> Dictionary:
    if initial == null or supplied_config == null:
        return _failure("Economy generation requires explicit complete state/configuration.")
    var catalogue: EconomyCatalogue = EconomyCatalogue.new()
    var errors: PackedStringArray = catalogue.errors.duplicate()
    errors.append_array(EconomyConfig.validate_data(supplied_config.to_data(), catalogue))
    errors.append_array(CampaignValidator.validate_registry_keys(initial))
    if errors.is_empty():
        errors.append_array(CampaignValidator.validate_data(initial.to_data()))
    if not errors.is_empty():
        return {"state": null, "errors": errors}
    if initial.economy_generation != null:
        return _failure("Economy is already initialized; accepted state cannot be regenerated.")
    var state: CampaignState = initial.copy()
    var config: EconomyConfig = EconomyConfig.from_data(supplied_config.to_data())
    var world: EconomyWorld = EconomyWorld.new(state, config)
    if not world.errors.is_empty():
        return {"state": null, "errors": world.errors}
    for province: ProvinceState in state.provinces.values():
        province.economy = ProvinceEconomy.new()
    var order: Array[int] = world.province_ids.duplicate()
    _shuffle(order, stream(state, config, "opportunities", "traversal"))
    var raw_counts: Dictionary = {}
    for id: int in order:
        var province: ProvinceState = state.provinces[id]
        var count: int = stream(state, config, "opportunities", "count", id).weighted(OPPORTUNITY_COUNTS)
        raw_counts[id] = count
        var random: CampaignStartRandom = stream(state, config, "opportunities", "types", id)
        for index: int in count:
            var choices: Array[String] = []
            choices.assign(catalogue.opportunities.keys())
            choices.sort()
            var weights: Array[int] = []
            for type_id: String in choices:
                var weight: int = config.opportunity_weights[type_id]
                if province.economy.opportunity(type_id) != null:
                    weight = 0
                elif weight > 0 and type_id in config.rare_opportunity_ids:
                    for neighbor: int in world.neighbors[id]:
                        if state.provinces[neighbor].economy.opportunity(type_id) != null:
                            weight = maxi(1, int(weight * (10000 - config.anti_cluster_penalty_bp) / 10000))
                weights.append(weight)
            _add_opportunity(province, choices[random.weighted(weights)])
    errors = repair(state, config, world)
    if not errors.is_empty():
        return {"state": null, "errors": errors}
    var protected: Dictionary = {}
    for entry: Dictionary in config.authored_sites:
        var id: int = int(entry["province_id"])
        var definition: EconomyDefinition = catalogue.sites[entry["type_id"]]
        if definition.source_id == "aquatic":
            if not world.aquatic(id):
                return _failure("Authored Fishery has no suitable aquatic source.")
        elif state.provinces[id].economy.opportunity(definition.source_id) == null:
            return _failure("Authored exploitation site lacks its true generated source at Province %d; no convenient resource is spawned." % id)
        protected[str(id) + ":" + definition.source_id] = true
    var visible_counts: Dictionary = EconomyRules.totals(state)
    for id: int in world.province_ids:
        var province: ProvinceState = state.provinces[id]
        if province.economy.opportunities.is_empty():
            continue
        var random: CampaignStartRandom = stream(state, config, "hiding", "selection", id)
        if random.below(10000) >= config.hidden_chance_bp:
            continue
        var eligible: Array[EconomyOpportunity] = []
        for item: EconomyOpportunity in province.economy.opportunities:
            if protected.has(str(id) + ":" + item.type_id):
                continue
            if int(visible_counts[item.type_id]) <= int(EconomyRules.VISIBLE_FLOORS.get(item.type_id, 0)):
                continue
            eligible.append(item)
        if not eligible.is_empty():
            var hidden: EconomyOpportunity = eligible[random.below(eligible.size())]
            hidden.known_realm_ids.clear()
            visible_counts[hidden.type_id] -= 1
    for id: int in world.province_ids:
        var province: ProvinceState = state.provinces[id]
        var authored: Array[Dictionary] = config.authored("authored_sites", id)
        if not authored.is_empty():
            for entry: Dictionary in authored:
                if not EconomyRules.site_valid(catalogue.sites[entry["type_id"]], province, world) or not EconomyRules.authored_valid(entry, province, world):
                    return _failure("Authored countryside prerequisite failed at Province " + str(id))
                province.economy.sites.append(_instance(state, config, province, entry["type_id"], "sites", "authored", province.economy.sites.size()))
        else:
            var random: CampaignStartRandom = stream(state, config, "sites", "selection", id)
            if random.below(10000) < SITE_CHANCE_BP:
                var type_id: String = choose_site(province, catalogue, world, random)
                if not type_id.is_empty():
                    province.economy.sites.append(_instance(state, config, province, type_id, "sites", "random", 0))
    for id: int in world.province_ids:
        var province: ProvinceState = state.provinces[id]
        var authored: Array[Dictionary] = config.authored("authored_buildings", id)
        var count: int = maxi(building_count(state, config, province), authored.size())
        var choices: Array[String] = []
        for type_id: String in catalogue.random_buildings():
            if EconomyRules.building_valid(catalogue.buildings[type_id], province, world):
                choices.append(type_id)
        for entry: Dictionary in authored:
            if not EconomyRules.building_valid(catalogue.buildings[entry["type_id"]], province, world) or not EconomyRules.authored_valid(entry, province, world):
                return _failure("Authored city prerequisite failed at Province " + str(id))
            province.economy.buildings.append(_instance(state, config, province, entry["type_id"], "buildings", "authored", province.economy.buildings.size()))
            choices.erase(entry["type_id"])
        if choices.size() < count - authored.size():
            return _failure("Too few distinct eligible Day-1 strategic types; cannot shrink or duplicate the rolled total.")
        var random: CampaignStartRandom = stream(state, config, "buildings", "types", id)
        while province.economy.buildings.size() < count:
            var choice: int = random.below(choices.size())
            province.economy.buildings.append(_instance(state, config, province, choices[choice], "buildings", "random", province.economy.buildings.size()))
            choices.remove_at(choice)
    state.economy_generation = EconomyProvenance.new()
    state.economy_generation.content_hash = catalogue.fingerprint
    state.economy_generation.config = config
    state.economy_generation.config_hash = config.fingerprint()
    errors = EconomyStartValidator.validate(state, catalogue)
    return {"state": state if errors.is_empty() else null, "errors": errors, "raw_opportunity_counts": raw_counts}


static func eligible_site_families(province: ProvinceState, catalogue: EconomyCatalogue, world: EconomyWorld) -> Dictionary:
    var families: Dictionary = {}
    var ids: Array = catalogue.sites.keys()
    ids.sort()
    for id: String in ids:
        var definition: EconomyDefinition = catalogue.sites[id]
        if definition.day_one_random and EconomyRules.site_valid(definition, province, world):
            if not families.has(definition.source_id):
                families[definition.source_id] = []
            families[definition.source_id].append(id)
    return families


static func choose_site(province: ProvinceState, catalogue: EconomyCatalogue,
        world: EconomyWorld, random: CampaignStartRandom) -> String:
    var families: Dictionary = eligible_site_families(province, catalogue, world)
    var family_ids: Array = families.keys()
    family_ids.sort()
    if family_ids.is_empty():
        return ""
    var family: Array = families[family_ids[random.below(family_ids.size())]]
    return family[random.below(family.size())]


static func repair(state: CampaignState, config: EconomyConfig, world: EconomyWorld) -> PackedStringArray:
    var counts: Dictionary = EconomyRules.totals(state)
    var order: Array[int] = world.province_ids.duplicate()
    _shuffle(order, stream(state, config, "opportunities", "repair"))
    var catalogue: EconomyCatalogue = EconomyCatalogue.new()
    for type_id: String in EconomyRules.TRUE_FLOORS:
        while int(counts.get(type_id, 0)) < EconomyRules.TRUE_FLOORS[type_id]:
            var chosen: int = -1
            var replacement: String = ""
            var best_score: int = 2147483647
            for id: int in order:
                var province: ProvinceState = state.provinces[id]
                if province.economy.opportunity(type_id) != null:
                    continue
                var replace_id: String = ""
                var best_weight: int = -1
                if province.economy.opportunities.size() == 3:
                    for item: EconomyOpportunity in province.economy.opportunities:
                        if int(counts[item.type_id]) <= int(EconomyRules.TRUE_FLOORS.get(item.type_id, 0)):
                            continue
                        var protected: bool = false
                        for entry: Dictionary in config.authored("authored_sites", id):
                            protected = protected or catalogue.sites[entry["type_id"]].source_id == item.type_id
                        if protected:
                            continue
                        var weight: int = config.opportunity_weights[item.type_id]
                        if item.type_id not in config.rare_opportunity_ids:
                            weight += 1000001
                        if weight > best_weight:
                            best_weight = weight
                            replace_id = item.type_id
                    if replace_id.is_empty():
                        continue
                var score: int = 10000 if province.economy.opportunities.size() == 3 else 0
                if type_id in config.rare_opportunity_ids and config.anti_cluster_penalty_bp > 0:
                    for neighbor: int in world.neighbors[id]:
                        score += int(state.provinces[neighbor].economy.opportunity(type_id) != null)
                if score < best_score:
                    best_score = score
                    chosen = id
                    replacement = replace_id
            if chosen == -1:
                return PackedStringArray(["No legal max-three world-floor repair exists."])
            var province: ProvinceState = state.provinces[chosen]
            if not replacement.is_empty():
                province.economy.opportunities.erase(province.economy.opportunity(replacement))
                counts[replacement] -= 1
            _add_opportunity(province, type_id)
            counts[type_id] = int(counts.get(type_id, 0)) + 1
    return []


static func _add_opportunity(province: ProvinceState, type_id: String) -> void:
    var item: EconomyOpportunity = EconomyOpportunity.new()
    item.type_id = type_id
    item.known_realm_ids = [province.owner_realm_id]
    province.economy.opportunities.append(item)


static func _instance(state: CampaignState, config: EconomyConfig, province: ProvinceState,
        type_id: String, domain: String, origin: String, index: int) -> EconomyInstance:
    var result: EconomyInstance = EconomyInstance.new()
    result.instance_id = "eco_" + JSON.stringify(["economy-instance", state.campaign_seed,
        state.world_binding, VERSION, config.domain_versions[domain], domain,
        province.province_id, index]).sha256_text().left(32)
    result.type_id = type_id
    result.origin = origin
    result.origin_realm_id = province.owner_realm_id
    result.origin_culture = province.local_culture
    result.origin_religion = province.local_religion.duplicate(true)
    return result


static func _shuffle(values: Array[int], random: CampaignStartRandom) -> void:
    for index: int in range(values.size() - 1, 0, -1):
        var other: int = random.below(index + 1)
        var value: int = values[index]
        values[index] = values[other]
        values[other] = value


static func _failure(message: String) -> Dictionary:
    return {"state": null, "errors": PackedStringArray([message])}
