class_name CampaignBootstrap
extends RefCounted


# Capitals/rulers/official identity are supplied by a scenario, not invented by
# the frozen ownership/identity adapter. Tests supply explicitly synthetic roles.
static func from_world(
        realm_setups: Array[RealmState], character_setups: Array[CharacterState],
        dynasty_setups: Array[DynastyState], player_realm_id: String = ""
) -> Dictionary:
    var catalogue: RefCounted = WorldIdentityCatalogue.load_default()
    if catalogue == null:
        return {"state": null, "errors": PackedStringArray(["Canonical world cannot be loaded."])}
    var state: CampaignState = CampaignState.new()
    state.world_binding = CampaignWorldBinding.fingerprint()
    state.player_realm_id = player_realm_id
    state.retired_ids["provinces"] = CampaignWorldBinding.retired_province_ids()
    var data: Dictionary = state.to_data()
    data["characters"] = StateSchema.records_to_data(character_setups)
    data["dynasties"] = StateSchema.records_to_data(dynasty_setups)
    for setup: RealmState in realm_setups:
        if setup == null:
            return {"state": null, "errors": PackedStringArray(["Starting Realm setup cannot be null."])}
        var setup_data: Dictionary = setup.to_data()
        setup_data["political_identity_id"] = setup.realm_id
        var setup_errors: PackedStringArray = []
        StateSchema.validate_record(setup_data, RealmState.FIELDS, "Starting Realm", setup_errors)
        if not setup_errors.is_empty():
            return {"state": null, "errors": setup_errors}
        var identity: Dictionary = catalogue.get_realm_identity(StringName(setup.realm_id))
        if identity.is_empty():
            return {"state": null, "errors": PackedStringArray(["Unknown starting Realm: " + setup.realm_id])}
        var realm: RealmState = RealmState.from_data(setup_data)
        realm.original_identity_id = realm.realm_id
        realm.political_identity_id = realm.realm_id
        realm.realm_style = "" if identity["realm_style"] == null else String(identity["realm_style"])
        realm.polity_type = identity["realm_type"]
        data["realms"].append(realm.to_data())
    for id: int in catalogue.get_province_ids():
        var identity: Dictionary = catalogue.get_province_identity(id)
        var province: ProvinceState = ProvinceState.new()
        province.province_id = id
        province.owner_realm_id = identity["starting_realm_id"]
        province.local_culture = identity["culture"]
        province.local_religion = identity["religion"].duplicate(true)
        # A hub reference only: no authored settlement name, type, model or placement.
        province.primary_settlement_id = "province_hub_%d" % id
        data["provinces"].append(province.to_data())
    var ids: Array[String] = []
    for id: StringName in catalogue.get_realm_ids():
        ids.append(String(id))
    ids.sort()
    for first: int in ids.size():
        for second: int in range(first + 1, ids.size()):
            data["relationships"].append(RelationshipState.create(ids[first], ids[second]).to_data())
    return CampaignCodec.decode_data(data)
