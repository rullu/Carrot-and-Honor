class_name EconomySchema
extends RefCounted


static func validate_province(data: Variant, context: String, errors: PackedStringArray) -> void:
    if data == null:
        return
    StateSchema.validate_record(data, ProvinceEconomy.FIELDS, context, errors)
    if not errors.is_empty():
        return
    for item: Variant in data["opportunities"]:
        StateSchema.validate_record(item, EconomyOpportunity.FIELDS, context + ".opportunity", errors)
    for item: Variant in data["sites"] + data["buildings"]:
        StateSchema.validate_record(item, EconomyInstance.FIELDS, context + ".instance", errors)


static func validate_generation(data: Variant, context: String, errors: PackedStringArray) -> void:
    if data == null:
        return
    StateSchema.validate_record(data, EconomyProvenance.FIELDS, context, errors)
    if not errors.is_empty():
        return
    var catalogue: EconomyCatalogue = EconomyCatalogue.new()
    errors.append_array(catalogue.errors)
    errors.append_array(EconomyConfig.validate_data(data["config"], catalogue))
    if not errors.is_empty():
        return
    var config: EconomyConfig = EconomyConfig.from_data(data["config"])
    if int(data["generator_version"]) != 1 or int(data["content_version"]) != 1 or data["content_hash"] != catalogue.fingerprint or data["config_hash"] != config.fingerprint():
        errors.append("Unsupported economy version or mismatched config fingerprint.")


static func validate_state(state: CampaignState, errors: PackedStringArray) -> void:
    if state.economy_generation == null:
        for province: ProvinceState in state.provinces.values():
            if province.economy != null:
                errors.append("Economy records require explicit generation/config provenance.")
        return
    var catalogue: EconomyCatalogue = EconomyCatalogue.new()
    errors.append_array(catalogue.errors)
    var world: EconomyWorld = EconomyWorld.new(state, state.economy_generation.config)
    errors.append_array(world.errors)
    if not errors.is_empty():
        return
    var instance_ids: Dictionary = {}
    for province: ProvinceState in state.provinces.values():
        if province.economy == null:
            errors.append("Economy-enabled campaign has an uninitialized Province.")
            continue
        var economy: ProvinceEconomy = province.economy
        var types: Dictionary = {}
        if economy.opportunities.size() > 3:
            errors.append("Province has more than three tracked opportunities.")
        for item: EconomyOpportunity in economy.opportunities:
            if not catalogue.opportunities.has(item.type_id) or types.has(item.type_id):
                errors.append("Unknown or duplicate opportunity type.")
            types[item.type_id] = true
            for realm_id: String in item.known_realm_ids:
                if not state.realms.has(realm_id):
                    errors.append("Opportunity knowledge references an unknown Realm.")
        if economy.buildings.size() > state.economy_generation.config.strategic_slots:
            errors.append("Strategic capacity exceeded.")
        for category: String in ["sites", "buildings"]:
            types.clear()
            var definitions: Dictionary = catalogue.sites if category == "sites" else catalogue.buildings
            for item: EconomyInstance in economy.get(category):
                if not definitions.has(item.type_id) or types.has(item.type_id):
                    errors.append("Unknown or duplicate " + category + " type.")
                    continue
                types[item.type_id] = true
                if instance_ids.has(item.instance_id):
                    errors.append("Duplicate physical economy instance ID.")
                instance_ids[item.instance_id] = true
                if item.state not in EconomyInstance.STATES or item.origin not in ["authored", "random", "later"] or item.form != "base":
                    errors.append("Unknown physical economy lifecycle/origin/form.")
                if not state.realms.has(item.origin_realm_id):
                    errors.append("Unknown instance origin Realm.")
                if category == "sites" and not EconomyRules.site_valid(definitions[item.type_id], province, world):
                    errors.append("Exploitation site lacks a valid owner-known source.")
                if category == "buildings" and item.type_id == "building_harbour" and not world.coast(province.province_id):
                    errors.append("Harbour has no suitable coastal access.")
