class_name CampaignBootstrap
extends RefCounted


static func new_campaign(campaign_seed: String, days_per_year: int,
        player_realm_id: String = "", economy_config: EconomyConfig = null) -> Dictionary:
    if economy_config == null:
        var loaded: Dictionary = EconomyConfig.load_default()
        if loaded["config"] == null:
            return {"state": null, "errors": loaded["errors"]}
        economy_config = loaded["config"]
    var cast_result: Dictionary = new_cast_campaign(campaign_seed, days_per_year, player_realm_id)
    if cast_result["state"] == null:
        return cast_result
    var result: Dictionary = EconomyGenerator.generate(cast_result["state"], economy_config)
    result["attempts"] = cast_result["attempts"]
    result["rejections"] = cast_result["rejections"]
    return result


# Explicit cast-only/scenario boundary. Null economy means uninitialized, not barren.
static func new_cast_campaign(campaign_seed: String, days_per_year: int,
        player_realm_id: String = "") -> Dictionary:
    var generator: CampaignStartGenerator = CampaignStartGenerator.new()
    var generated: Dictionary = generator.generate(campaign_seed, days_per_year)
    if generated["cast"] == null:
        return {"state": null, "errors": generated["errors"], "attempts": generated["attempts"], "rejections": generated["rejections"]}
    var result: Dictionary = from_generated(generated["cast"], player_realm_id)
    result["attempts"] = generated["attempts"]
    result["rejections"] = generated["rejections"]
    return result


static func from_generated(cast: Dictionary, player_realm_id: String = "") -> Dictionary:
    var world: CampaignStartWorld = CampaignStartWorld.new()
    var errors: PackedStringArray = CampaignStartValidator.validate(cast, world)
    if errors.is_empty():
        errors = CampaignStartValidator.soft_sanity(cast)
    if not errors.is_empty():
        return {"state": null, "errors": errors}
    return from_world(cast["realm_setups"], cast["character_setups"], cast["dynasty_setups"],
        cast["campaign_seed"], int(cast["generator_version"]), int(cast["days_per_year"]), player_realm_id)


# Capitals/rulers/official identity are supplied by a scenario, not invented by
# the frozen ownership/identity adapter. Tests supply explicitly synthetic roles.
static func from_world(
        realm_setups: Array[RealmState], character_setups: Array[CharacterState],
        dynasty_setups: Array[DynastyState], campaign_seed: String,
        generator_version: int, days_per_year: int, player_realm_id: String = ""
) -> Dictionary:
    var catalogue: RefCounted = WorldIdentityCatalogue.load_default()
    if catalogue == null:
        return {"state": null, "errors": PackedStringArray(["Canonical world cannot be loaded."])}
    var state: CampaignState = CampaignState.new()
    state.campaign_seed = campaign_seed
    state.generator_version = generator_version
    state.days_per_year = days_per_year
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
