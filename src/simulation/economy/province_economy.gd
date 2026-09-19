class_name ProvinceEconomy
extends RefCounted

const FIELDS: Dictionary = {"opportunities": "array", "sites": "array", "buildings": "array"}
var opportunities: Array[EconomyOpportunity] = []
var sites: Array[EconomyInstance] = []
var buildings: Array[EconomyInstance] = []


func to_data() -> Dictionary:
    return {"opportunities": StateSchema.records_to_data(opportunities),
        "sites": StateSchema.records_to_data(sites), "buildings": StateSchema.records_to_data(buildings)}


static func from_data(data: Dictionary) -> ProvinceEconomy:
    var result: ProvinceEconomy = ProvinceEconomy.new()
    for record: Dictionary in data["opportunities"]:
        result.opportunities.append(EconomyOpportunity.from_data(record))
    for record: Dictionary in data["sites"]:
        result.sites.append(EconomyInstance.from_data(record))
    for record: Dictionary in data["buildings"]:
        result.buildings.append(EconomyInstance.from_data(record))
    return result


func opportunity(type_id: String) -> EconomyOpportunity:
    for item: EconomyOpportunity in opportunities:
        if item.type_id == type_id:
            return item
    return null


func known(type_id: String, realm_id: String) -> bool:
    var item: EconomyOpportunity = opportunity(type_id)
    return item != null and realm_id in item.known_realm_ids


func reveal_sites(owner_id: String, catalogue: EconomyCatalogue) -> void:
    for site: EconomyInstance in sites:
        var definition: EconomyDefinition = catalogue.sites.get(site.type_id)
        if definition == null:
            continue
        var source: EconomyOpportunity = opportunity(definition.source_id)
        if source != null and owner_id not in source.known_realm_ids:
            source.known_realm_ids.append(owner_id)
