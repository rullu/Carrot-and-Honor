class_name RealmLifecycle
extends RefCounted


# Mutates only a detached candidate owned by CampaignSession's transaction.
static func capture(state: CampaignState, province_id: int, owner_id: String) -> PackedStringArray:
    if not state.provinces.has(province_id) or not state.realms.has(owner_id) or not state.realms[owner_id].active:
        return PackedStringArray(["Capture requires an existing Province and active recipient Realm."])
    if state.provinces[province_id].owner_realm_id == owner_id:
        return PackedStringArray(["Province already belongs to recipient."])
    state.provinces[province_id].owner_realm_id = owner_id
    settle_territory(state)
    return []


static func restore(state: CampaignState, realm_id: String, province_ids: Array[int], capital_id: int, ruler_id: String, legitimacy: String) -> PackedStringArray:
    var realm: RealmState = state.realms.get(realm_id)
    if realm == null or realm.active:
        return PackedStringArray(["Restoration requires a known inactive Realm."])
    var errors: PackedStringArray = _validate_grant(state, province_ids, capital_id)
    if not errors.is_empty():
        return errors
    realm.active = true
    realm.capital_province_id = capital_id
    realm.current_ruler_id = ruler_id
    realm.recognized_heir_id = ""
    realm.legitimacy = legitimacy
    for id: int in province_ids:
        state.provinces[id].owner_realm_id = realm_id
    settle_territory(state)
    return []


static func create_rebel(state: CampaignState, setup: RealmState, province_ids: Array[int]) -> Dictionary:
    var errors: PackedStringArray = _validate_grant(state, province_ids, setup.capital_province_id)
    if not errors.is_empty():
        return {"errors": errors, "realm_id": ""}
    if not setup.realm_id.is_empty() or not setup.original_identity_id.is_empty():
        return {"errors": PackedStringArray(["New rebels receive a fresh ID; restoration is a separate command."]), "realm_id": ""}
    var setup_data: Dictionary = setup.to_data()
    setup_data["realm_id"] = "pending_rebel_identity"
    StateSchema.validate_record(setup_data, RealmState.FIELDS, "New rebel Realm", errors)
    if not errors.is_empty():
        return {"errors": errors, "realm_id": ""}
    var suffix: int = 1
    var id: String = "realm_rebel_%d" % suffix
    while state.realms.has(id) or id in state.retired_ids["realms"]:
        suffix += 1
        id = "realm_rebel_%d" % suffix
    var realm: RealmState = RealmState.from_data(setup_data)
    realm.realm_id = id
    realm.active = true
    state.realms[id] = realm
    for province_id: int in province_ids:
        state.provinces[province_id].owner_realm_id = id
    settle_territory(state)
    state.ensure_relationships()
    return {"errors": PackedStringArray(), "realm_id": id}


static func form(state: CampaignState, realm_id: String, identity_id: String, authored_style: Variant) -> PackedStringArray:
    if not state.realms.has(realm_id) or not state.realms[realm_id].active or not StateSchema.is_id(identity_id):
        return PackedStringArray(["Formation requires an active Realm and political identity ID."])
    if authored_style != null and not authored_style is String:
        return PackedStringArray(["An authored Realm Style must be a string, or null to preserve it."])
    # Eligibility remains a future authored subsystem. This is the atomic state primitive.
    state.realms[realm_id].political_identity_id = identity_id
    if authored_style != null:
        state.realms[realm_id].realm_style = authored_style
    return []


static func succeed(state: CampaignState, realm_id: String, ruler_id: String, legitimacy: String, heir_id: String) -> PackedStringArray:
    if not state.realms.has(realm_id) or not state.realms[realm_id].active:
        return PackedStringArray(["Succession requires an active Realm."])
    var realm: RealmState = state.realms[realm_id]
    realm.current_ruler_id = ruler_id
    realm.legitimacy = legitimacy
    realm.recognized_heir_id = heir_id
    return []


static func _validate_grant(state: CampaignState, ids: Array[int], capital_id: int) -> PackedStringArray:
    if ids.is_empty() or capital_id not in ids:
        return PackedStringArray(["A land grant requires provinces including its new capital."])
    var seen: Dictionary[int, bool] = {}
    for id: int in ids:
        if not state.provinces.has(id) or seen.has(id):
            return PackedStringArray(["Land grant contains an invalid or repeated Province ID."])
        seen[id] = true
    return []


static func settle_territory(state: CampaignState) -> void:
    var territory: Dictionary = {}
    for province: ProvinceState in state.provinces.values():
        if not territory.has(province.owner_realm_id):
            territory[province.owner_realm_id] = []
        territory[province.owner_realm_id].append(province.province_id)
    for realm: RealmState in state.realms.values():
        var owned: Array = territory.get(realm.realm_id, [])
        if owned.is_empty():
            realm.active = false
            realm.capital_province_id = 0
            realm.current_ruler_id = ""
            realm.recognized_heir_id = ""
            if realm.realm_id == state.player_realm_id:
                state.game_over = true
        elif realm.capital_province_id not in owned:
            # Deterministic ID ordering is a tie-break only, not identity arithmetic
            # or a gameplay claim about which province makes the best capital.
            owned.sort()
            realm.capital_province_id = owned[0]
