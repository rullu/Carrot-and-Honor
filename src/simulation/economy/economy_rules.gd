class_name EconomyRules
extends RefCounted

const TRUE_FLOORS: Dictionary = {"opportunity_fertile_land": 5, "opportunity_iron": 2}
const VISIBLE_FLOORS: Dictionary = {"opportunity_fertile_land": 4, "opportunity_iron": 1}


static func site_valid(definition: EconomyDefinition, province: ProvinceState, world: EconomyWorld) -> bool:
    if definition.source_id == "aquatic":
        return world.aquatic(province.province_id)
    return province.economy.known(definition.source_id, province.owner_realm_id)


static func building_valid(definition: EconomyDefinition, province: ProvinceState, world: EconomyWorld) -> bool:
    match definition.requirement:
        "coast": return world.coast(province.province_id)
        "grain":
            if province.economy.known("opportunity_fertile_land", province.owner_realm_id):
                return true
            for site: EconomyInstance in province.economy.sites:
                if site.type_id == "site_grain_fields" and site.state == "active":
                    return true
            return false
        "always", "authored": return true
    return false


static func authored_valid(entry: Dictionary, province: ProvinceState, world: EconomyWorld) -> bool:
    if entry["requires_coast"] and not world.coast(province.province_id):
        return false
    if not entry["opportunity_any"].is_empty():
        var found: bool = false
        for id: String in entry["opportunity_any"]:
            found = found or province.economy.known(id, province.owner_realm_id)
        if not found:
            return false
    if not entry["site_any"].is_empty():
        var found: bool = false
        for site: EconomyInstance in province.economy.sites:
            found = found or (site.type_id in entry["site_any"] and site.state == "active")
        if not found:
            return false
    # Minimum source bindings only, not production recipes or imported-goods access.
    var sources: Dictionary = {
        "building_clayworks": ["opportunity_clay"],
        "building_glassworks": ["opportunity_glass_sand"],
        "building_smelter": ["opportunity_iron", "opportunity_copper", "opportunity_tin", "opportunity_silver", "opportunity_gold"],
        "building_jeweller": ["opportunity_gold", "opportunity_silver", "opportunity_amber", "opportunity_gemstones"],
    }
    if sources.has(entry["type_id"]):
        for id: String in sources[entry["type_id"]]:
            if province.economy.known(id, province.owner_realm_id):
                return true
        return false
    if entry["type_id"] == "building_leather_parchment_works":
        for site: EconomyInstance in province.economy.sites:
            if site.type_id == "site_sheep_pasture" and site.state == "active":
                return true
        return false
    return true


static func totals(state: CampaignState, visible: bool = false) -> Dictionary:
    var result: Dictionary = {}
    for province: ProvinceState in state.provinces.values():
        if province.economy == null:
            continue
        for item: EconomyOpportunity in province.economy.opportunities:
            if not visible or province.owner_realm_id in item.known_realm_ids:
                result[item.type_id] = int(result.get(item.type_id, 0)) + 1
    return result
