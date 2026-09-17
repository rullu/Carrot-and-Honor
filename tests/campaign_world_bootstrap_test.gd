extends CampaignTestSuite


func _initialize() -> void:
    check(CampaignWorldBinding.authority_text_hash("{\r\n\"id\": 7\r\n}") == CampaignWorldBinding.authority_text_hash("{\n\"id\": 7\n}"), "world binding tolerates Git checkout line-ending differences")
    check(CampaignWorldBinding.authority_text_hash("{\"id\": 7}") != CampaignWorldBinding.authority_text_hash("{\"id\": 8}"), "world binding still detects authority content changes")
    var fingerprint: String = CampaignWorldBinding.fingerprint()
    var catalogue: RefCounted = WorldIdentityCatalogue.load_default()
    var realms: Array[RealmState] = []
    var characters: Array[CharacterState] = []
    var dynasties: Array[DynastyState] = []
    # These roles, capital tie-breaks and official identities are TEST FIXTURES.
    # No invented ruler, House or capital is written to production content.
    for id: StringName in catalogue.get_realm_ids():
        var realm: RealmState = RealmState.new()
        realm.realm_id = String(id)
        realm.capital_province_id = catalogue.get_starting_province_ids_for_realm(id)[0]
        realm.current_ruler_id = "fixture_ruler_" + String(id)
        realm.legitimacy = "fixture_recognized"
        var identity: Dictionary = catalogue.get_province_identity(realm.capital_province_id)
        realm.official_culture = identity["culture"]
        realm.official_religion = identity["religion"].duplicate(true)
        realms.append(realm)
        var dynasty: DynastyState = DynastyState.new()
        dynasty.dynasty_id = "fixture_house_" + String(id)
        dynasty.lineage_name = "Test House " + String(id)
        dynasties.append(dynasty)
        var character: CharacterState = CharacterState.new()
        character.character_id = realm.current_ruler_id
        character.given_name = "Test Ruler " + String(id)
        character.dynasty_id = dynasty.dynasty_id
        character.realm_id = String(id)
        characters.append(character)
    var result: Dictionary = CampaignBootstrap.from_world(realms, characters, dynasties, "fixture", 1, 365, "R028")
    check(result["state"] != null, "canonical bootstrap validates: " + str(result["errors"]))
    if result["state"] == null:
        finish("Campaign canonical bootstrap")
        return
    var state: CampaignState = result["state"]
    check(state.provinces.size() == 100 and state.realms.size() == 43, "exact canonical province/Realm counts")
    check(state.relationships.size() == 903, "43 Realms yield 903 unique persistent pairs")
    check(state.realms["R008"].polity_type == "holy_state", "canonical holy-state identity preserved")
    var query: CampaignQueries = CampaignQueries.new(state)
    for id: int in catalogue.get_province_ids():
        var identity: Dictionary = catalogue.get_province_identity(id)
        var province: ProvinceState = state.provinces[id]
        check(province.owner_realm_id == identity["starting_realm_id"], "frozen starting owner %d" % id)
        check(province.local_culture == identity["culture"] and province.local_religion == identity["religion"], "local identity %d begins at canon" % id)
        check(province.local_food == 0 and province.local_manpower == 0, "prototype numeric metrics are not promoted into canon %d" % id)
    for id: StringName in catalogue.get_realm_ids():
        var expected: Array[int] = []
        expected.assign(catalogue.get_starting_province_ids_for_realm(id))
        expected.sort()
        check(query.territory(String(id)) == expected, "derived starting territory " + String(id))
    check(state.provinces[30].local_culture == "Carthen" and state.provinces[30].owner_realm_id == "R028", "Hasenmark mixed identity preserved")
    for id: int in [8, 31, 57, 63, 68, 81, 82]:
        check(not state.provinces.has(id) and id in state.retired_ids["provinces"], "retired geography %d stays reserved" % id)
    var session: CampaignSession = CampaignSession.create(state)["session"]
    var restored: Dictionary = CampaignCodec.decode_json(canonical(session.export_data()))
    check(restored["state"] != null and canonical(restored["state"].to_data()) == canonical(session.export_data()), "whole canonical campaign JSON round-trip")
    var foreign_data: Dictionary = session.export_data()
    foreign_data["world_binding"] = "wrong_fingerprint"
    invalid(foreign_data, "incompatible world authority fingerprint rejected")
    var missing_province: Dictionary = session.export_data()
    missing_province["provinces"].remove_at(missing_province["provinces"].size() - 1)
    invalid(missing_province, "canonical province cannot disappear from save")
    var missing_retirement: Dictionary = session.export_data()
    missing_retirement["retired_ids"]["provinces"].clear()
    invalid(missing_retirement, "canonical retired IDs cannot disappear from save")
    var impersonated: Dictionary = session.export_data()
    impersonated["realms"][0]["original_identity_id"] = "R002"
    invalid(impersonated, "original canonical identity cannot be reassigned")
    var duplicate_realms: Array[RealmState] = realms.duplicate()
    duplicate_realms.append(realms[0])
    check(CampaignBootstrap.from_world(duplicate_realms, characters, dynasties, "fixture", 1, 365)["state"] == null, "duplicate scenario Realm rejected before indexing")
    var missing_realms: Array[RealmState] = realms.duplicate()
    missing_realms.pop_back()
    check(CampaignBootstrap.from_world(missing_realms, characters, dynasties, "fixture", 1, 365)["state"] == null, "missing starting Realm rejected")
    var missing_ruler: Array[CharacterState] = characters.duplicate()
    missing_ruler.pop_back()
    check(CampaignBootstrap.from_world(realms, missing_ruler, dynasties, "fixture", 1, 365)["state"] == null, "missing authored/scenario ruler fails instead of inventing one")
    check(CampaignWorldBinding.fingerprint() == fingerprint, "protected world authorities unchanged by bootstrap and save/load")
    finish("Campaign canonical bootstrap")
