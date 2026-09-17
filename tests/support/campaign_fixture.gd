class_name CampaignFixture
extends RefCounted


# Explicitly synthetic scenario. Sparse numeric province IDs and opaque text IDs
# exercise architecture independently of authored FCAH character/capital content.
static func state() -> CampaignState:
    var state: CampaignState = CampaignState.new()
    state.campaign_seed = "synthetic-fixture"
    state.days_per_year = 365
    for id: String in ["house_oak", "house_ash", "house_historical"]:
        var dynasty: DynastyState = DynastyState.new()
        dynasty.dynasty_id = id
        dynasty.lineage_name = "Fixture " + id
        state.dynasties[id] = dynasty
    for entry: Array in [
        ["rabbit_7", "house_oak", "R002"],
        ["rabbit_90", "house_ash", "R900"],
        ["foreign_heir", "house_ash", "R900"],
        ["unaffiliated", "house_ash", ""],
        ["ancestor", "house_historical", ""],
    ]:
        var character: CharacterState = CharacterState.new()
        character.character_id = entry[0]
        character.given_name = "Fixture " + entry[0]
        character.dynasty_id = entry[1]
        character.realm_id = entry[2]
        character.alive = entry[0] != "ancestor"
        state.characters[character.character_id] = character
    state.characters["rabbit_7"].parent_ids = ["ancestor"]
    for entry: Array in [["R002", 11, "rabbit_7"], ["R900", 407, "rabbit_90"]]:
        var realm: RealmState = RealmState.new()
        realm.realm_id = entry[0]
        realm.original_identity_id = entry[0]
        realm.political_identity_id = entry[0]
        realm.realm_style = "Fixture principality"
        realm.capital_province_id = entry[1]
        realm.current_ruler_id = entry[2]
        realm.legitimacy = "fixture_recognized"
        realm.carrots = 75
        realm.faith = 8
        state.realms[realm.realm_id] = realm
    state.realms["R002"].recognized_heir_id = "foreign_heir"
    for entry: Array in [[11, "R002", 4, 10], [93, "R002", 8, 20], [407, "R900", 16, 30]]:
        var province: ProvinceState = ProvinceState.new()
        province.province_id = entry[0]
        province.owner_realm_id = entry[1]
        province.primary_settlement_id = "fixture_hub_%d" % entry[0]
        province.local_food = entry[2]
        province.local_manpower = entry[3]
        province.local_culture = "Fixture local culture"
        state.provinces[province.province_id] = province
    state.retired_ids["provinces"] = [2, 88]
    state.retired_ids["realms"] = ["realm_rebel_1", "retired_realm"]
    state.retired_ids["characters"] = ["retired_character"]
    state.retired_ids["dynasties"] = ["retired_dynasty"]
    state.retired_ids["wars"] = ["retired_war"]
    state.retired_ids["claims"] = ["retired_claim"]
    state.ensure_relationships()
    return state


static func session() -> CampaignSession:
    return CampaignSession.create(state())["session"]


static func claim(id: String, target: Variant = "R900") -> ClaimRecord:
    var claim: ClaimRecord = ClaimRecord.new()
    claim.claim_id = id
    claim.target_kind = "province" if target is int else "realm"
    claim.target_id = target
    claim.basis = "Shared historical basis, distinct legal rights"
    return claim


static func memory(summary: String) -> HistoricalMemory:
    var memory: HistoricalMemory = HistoricalMemory.new()
    memory.event_id = "fixture_event_73"
    memory.summary = summary
    return memory


static func rebel(capital: int = 93) -> RealmState:
    var realm: RealmState = RealmState.new()
    realm.political_identity_id = "fixture_new_political_identity"
    realm.capital_province_id = capital
    realm.current_ruler_id = "unaffiliated"
    realm.legitimacy = "fixture_established"
    return realm
