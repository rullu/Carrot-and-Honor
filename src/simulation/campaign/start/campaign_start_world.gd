class_name CampaignStartWorld
extends RefCounted

# Read-only canonical adapter, scoped to a generation operation/batch.
var catalogue: RefCounted
var names: CampaignStartNames
var binding: String
var realm_ids: Array[String] = []
var errors: PackedStringArray = []


func _init() -> void:
    catalogue = WorldIdentityCatalogue.load_default()
    names = CampaignStartNames.new()
    binding = CampaignWorldBinding.fingerprint()
    if catalogue == null or binding.is_empty():
        errors.append("Cannot load canonical campaign-start authorities.")
        return
    for id: StringName in catalogue.get_realm_ids():
        realm_ids.append(String(id))
    realm_ids.sort()
    if realm_ids.size() != 43 or names.data["seats"].size() != 43:
        errors.append("Campaign start requires exactly 43 canonical Realms and Seats.")
    for id: String in realm_ids:
        var seat: int = int(names.data["seats"].get(id, 0))
        var province: Dictionary = catalogue.get_province_identity(seat)
        if province.is_empty() or province["starting_realm_id"] != id:
            errors.append("Invalid canonical Seat for " + id)
        if names.family(catalogue.get_realm_identity(StringName(id))["primary_culture"]).is_empty():
            errors.append("Missing naming family for " + id)


func realm_setup(id: String) -> RealmState:
    var realm: RealmState = RealmState.new()
    realm.realm_id = id
    var identity: Dictionary = catalogue.get_realm_identity(StringName(id))
    realm.original_identity_id = id
    realm.political_identity_id = id
    realm.realm_style = "" if identity["realm_style"] == null else String(identity["realm_style"])
    realm.polity_type = identity["realm_type"]
    realm.capital_province_id = int(names.data["seats"][id])
    realm.official_culture = identity["primary_culture"]
    realm.official_religion = catalogue.get_province_identity(realm.capital_province_id)["religion"].duplicate(true)
    realm.succession_law_id = "elected_office" if id == "R008" else "eldest_legitimate_child"
    return realm


func identities(id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var ids: Array[int] = []
    ids.assign(catalogue.get_starting_province_ids_for_realm(StringName(id)))
    ids.sort()
    for province_id: int in ids:
        var province: Dictionary = catalogue.get_province_identity(province_id)
        var identity: Dictionary = {"culture": province["culture"], "religion": province["religion"].duplicate(true)}
        if identity not in result:
            result.append(identity)
    return result
