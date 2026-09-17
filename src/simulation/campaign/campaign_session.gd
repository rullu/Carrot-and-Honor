class_name CampaignSession
extends RefCounted


# The single live publication boundary. All public reads return detached values.
var _state: CampaignState
var _revision: int = 0


static func create(initial: CampaignState) -> Dictionary:
    if initial == null:
        return {"session": null, "errors": PackedStringArray(["Initial state is required."])}
    var key_errors: PackedStringArray = CampaignValidator.validate_registry_keys(initial)
    if not key_errors.is_empty():
        return {"session": null, "errors": key_errors}
    var result: Dictionary = CampaignCodec.decode_data(initial.to_data())
    if result["state"] == null:
        return {"session": null, "errors": result["errors"]}
    var session: CampaignSession = CampaignSession.new()
    session._state = result["state"]
    return {"session": session, "errors": PackedStringArray()}


func export_data() -> Dictionary:
    return _state.to_data()


func queries() -> CampaignQueries:
    return CampaignQueries.new(_state)


func revision() -> int:
    return _revision


func get_province(id: int) -> ProvinceState:
    return ProvinceState.from_data(_state.provinces[id].to_data()) if _state.provinces.has(id) else null


func get_realm(id: String) -> RealmState:
    return RealmState.from_data(_state.realms[id].to_data()) if _state.realms.has(id) else null


func get_character(id: String) -> CharacterState:
    return CharacterState.from_data(_state.characters[id].to_data()) if _state.characters.has(id) else null


func get_dynasty(id: String) -> DynastyState:
    return DynastyState.from_data(_state.dynasties[id].to_data()) if _state.dynasties.has(id) else null


func get_relationship(first: String, second: String) -> RelationshipState:
    var key: String = RelationshipState.pair_key(first, second)
    return RelationshipState.from_data(_state.relationships[key].to_data()) if _state.relationships.has(key) else null


func get_war(id: String) -> WarState:
    return WarState.from_data(_state.wars[id].to_data()) if _state.wars.has(id) else null


func save_file(path: String) -> PackedStringArray:
    return CampaignCodec.save_file(_state, path)


func capture(province_id: int, owner_id: String) -> Dictionary:
    var candidate: CampaignState = _state.copy()
    return _commit(candidate, RealmLifecycle.capture(candidate, province_id, owner_id))


func restore(realm_id: String, provinces: Array[int], capital_id: int, ruler_id: String, legitimacy: String) -> Dictionary:
    var candidate: CampaignState = _state.copy()
    return _commit(candidate, RealmLifecycle.restore(candidate, realm_id, provinces, capital_id, ruler_id, legitimacy))


func create_rebel(setup: RealmState, provinces: Array[int]) -> Dictionary:
    if setup == null:
        return _failure("Rebel setup is required.")
    var candidate: CampaignState = _state.copy()
    var proposal: Dictionary = RealmLifecycle.create_rebel(candidate, setup, provinces)
    var result: Dictionary = _commit(candidate, proposal["errors"])
    result["realm_id"] = proposal["realm_id"] if result["ok"] else ""
    return result


func form(realm_id: String, political_identity_id: String, authored_style: Variant = null) -> Dictionary:
    var candidate: CampaignState = _state.copy()
    return _commit(candidate, RealmLifecycle.form(candidate, realm_id, political_identity_id, authored_style))


func succeed(realm_id: String, ruler_id: String, legitimacy: String, heir_id: String = "") -> Dictionary:
    var candidate: CampaignState = _state.copy()
    return _commit(candidate, RealmLifecycle.succeed(candidate, realm_id, ruler_id, legitimacy, heir_id))


func set_parents(child_id: String, parents: Array[String]) -> Dictionary:
    var candidate: CampaignState = _state.copy()
    return _commit(candidate, CharacterLifecycle.set_parents(candidate, child_id, parents))


func link_partners(first: String, second: String, linked: bool = true) -> Dictionary:
    var candidate: CampaignState = _state.copy()
    return _commit(candidate, CharacterLifecycle.link_partners(candidate, first, second, linked))


func mark_deceased(character_id: String, successions: Dictionary = {}) -> Dictionary:
    var candidate: CampaignState = _state.copy()
    return _commit(candidate, CharacterLifecycle.mark_deceased(candidate, character_id, successions))


func set_allegiance(character_id: String, realm_id: String) -> Dictionary:
    if not _state.characters.has(character_id) or not _state.characters[character_id].alive:
        return _failure("Allegiance changes require a living Character.")
    var candidate: CampaignState = _state.copy()
    candidate.characters[character_id].realm_id = realm_id
    return _commit(candidate)


func set_local_resources(province_id: int, food: int, manpower: int) -> Dictionary:
    if not _state.provinces.has(province_id):
        return _failure("Unknown Province.")
    var candidate: CampaignState = _state.copy()
    candidate.provinces[province_id].local_food = food
    candidate.provinces[province_id].local_manpower = manpower
    return _commit(candidate)


func set_attitude(from_realm: String, to_realm: String, attitude: Dictionary) -> Dictionary:
    if not queries().diplomacy_active(from_realm, to_realm):
        return _failure("Ordinary diplomacy requires two active Realms.")
    var candidate: CampaignState = _state.copy()
    var relationship: RelationshipState = candidate.relationships[RelationshipState.pair_key(from_realm, to_realm)]
    if relationship.realm_a_id == from_realm:
        relationship.attitude_a_to_b = attitude.duplicate(true)
    else:
        relationship.attitude_b_to_a = attitude.duplicate(true)
    return _commit(candidate)


func add_claim(owner_kind: String, owner_id: String, claim: ClaimRecord) -> Dictionary:
    var candidate: CampaignState = _state.copy()
    var registry: Dictionary = _claimants(candidate, owner_kind)
    if claim == null or not registry.has(owner_id):
        return _failure("Claim requires exactly one known Character, Dynasty or Realm owner.")
    registry[owner_id].claims.append(ClaimRecord.from_data(claim.to_data()))
    return _commit(candidate)


func record_memory(perspective: String, id: Variant, memory: HistoricalMemory, other_realm: String = "") -> Dictionary:
    if memory == null:
        return _failure("Memory is required.")
    var candidate: CampaignState = _state.copy()
    var owner: RefCounted
    match perspective:
        "province": owner = candidate.provinces.get(id) if id is int else null
        "realm": owner = candidate.realms.get(id) if id is String else null
        "character": owner = candidate.characters.get(id) if id is String else null
        "dynasty": owner = candidate.dynasties.get(id) if id is String else null
        "relationship": owner = candidate.relationships.get(RelationshipState.pair_key(id, other_realm)) if id is String else null
    if owner == null:
        return _failure("Unknown historical perspective/entity.")
    owner.history.append(HistoricalMemory.from_data(memory.to_data()))
    return _commit(candidate)


func register_war(war: WarState) -> Dictionary:
    if war == null or _state.wars.has(war.war_id):
        return _failure("A new WarState requires a fresh identity.")
    var candidate: CampaignState = _state.copy()
    candidate.wars[war.war_id] = WarState.from_data(war.to_data())
    return _commit(candidate)


func end_war(war_id: String) -> Dictionary:
    if not _state.wars.has(war_id):
        return _failure("Unknown WarState.")
    var candidate: CampaignState = _state.copy()
    candidate.wars[war_id].active = false
    return _commit(candidate)


static func _claimants(state: CampaignState, kind: String) -> Dictionary:
    match kind:
        "character": return state.characters
        "dynasty": return state.dynasties
        "realm": return state.realms
    return {}


func _commit(candidate: CampaignState, errors: PackedStringArray = []) -> Dictionary:
    if _state.game_over:
        return _failure("Campaign has ended.")
    if errors.is_empty():
        errors = CampaignValidator.validate_registry_keys(candidate)
    if errors.is_empty():
        errors = CampaignValidator.validate_data(candidate.to_data())
    if not errors.is_empty():
        return {"ok": false, "errors": errors, "revision": _revision}
    # Normalize validated JSON-compatible integral numbers at every publication,
    # including nested attitudes/claim targets/retired IDs supplied by callers.
    _state = CampaignState.from_data(candidate.to_data())
    _revision += 1
    return {"ok": true, "errors": PackedStringArray(), "revision": _revision}


func _failure(message: String) -> Dictionary:
    return {"ok": false, "errors": PackedStringArray([message]), "revision": _revision}
