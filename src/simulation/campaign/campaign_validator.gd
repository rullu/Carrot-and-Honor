class_name CampaignValidator
extends RefCounted


const ROOT_FIELDS: Dictionary = {
    "campaign_seed": "seed", "generator_version": "positive_int", "days_per_year": "positive_int",
    "schema_version": "positive_int", "world_binding": "text",
    "player_realm_id": "text", "game_over": "bool", "retired_ids": "object",
    "provinces": "array", "realms": "array", "characters": "array",
    "dynasties": "array", "relationships": "array", "wars": "array",
}
const RECORD_FIELDS: Dictionary = {
    "provinces": ProvinceState.FIELDS, "realms": RealmState.FIELDS,
    "characters": CharacterState.FIELDS, "dynasties": DynastyState.FIELDS,
    "relationships": RelationshipState.FIELDS, "wars": WarState.FIELDS,
}
const ID_FIELDS: Dictionary = {
    "provinces": "province_id", "realms": "realm_id", "characters": "character_id",
    "dynasties": "dynasty_id", "wars": "war_id",
}


static func validate_registry_keys(state: CampaignState) -> PackedStringArray:
    var errors: PackedStringArray = []
    for category: String in RECORD_FIELDS:
        var registry: Dictionary = state.get(category)
        for key: Variant in registry:
            var record: RefCounted = registry[key]
            if record == null:
                errors.append(category + " contains a null record.")
                continue
            var expected: Variant = RelationshipState.pair_key(record.realm_a_id, record.realm_b_id) if category == "relationships" else record.get(ID_FIELDS[category])
            if key != expected:
                errors.append("%s registry key differs from record identity." % category)
    return errors


static func validate_data(data: Variant) -> PackedStringArray:
    var errors: PackedStringArray = []
    StateSchema.validate_record(data, ROOT_FIELDS, "Campaign", errors)
    if not errors.is_empty():
        return errors
    if int(data["schema_version"]) != CampaignState.SCHEMA_VERSION:
        errors.append("Unsupported campaign schema_version; explicit migration required.")
    StateSchema.validate_record(data["retired_ids"], CampaignState.RETIRED_FIELDS, "Retired IDs", errors)
    for category: String in RECORD_FIELDS:
        for index: int in data[category].size():
            StateSchema.validate_record(data[category][index], RECORD_FIELDS[category], "%s[%d]" % [category, index], errors)
    if not errors.is_empty():
        return errors
    # Check the target's category before constructing typed records; strings must
    # never be coerced to geographic integers (nor fractional values truncated).
    for category: String in ["realms", "characters", "dynasties"]:
        for owner: Dictionary in data[category]:
            for claim: Dictionary in owner["claims"]:
                if claim["target_kind"] == "province" and not StateSchema.is_integer(claim["target_id"]):
                    errors.append("Province claim target requires an integer ID.")
                elif claim["target_kind"] == "realm" and not StateSchema.is_id(claim["target_id"]):
                    errors.append("Realm claim target requires a string ID.")
    if not errors.is_empty():
        return errors
    for category: String in RECORD_FIELDS:
        var seen: Dictionary = {}
        for record: Dictionary in data[category]:
            var id: Variant
            if category == "relationships":
                id = RelationshipState.pair_key(record["realm_a_id"], record["realm_b_id"])
                if record["realm_a_id"] >= record["realm_b_id"]:
                    errors.append("Relationship pair must contain two distinct IDs in canonical order.")
            else:
                id = record[ID_FIELDS[category]]
                var retired: Array = data["retired_ids"][category]
                if category == "provinces":
                    id = int(id)
                    retired = StateSchema.integer_array(retired)
                if id in retired:
                    errors.append("%s reuses retired ID %s." % [category, str(id)])
            if seen.has(id):
                errors.append("Duplicate %s ID %s." % [category, str(id)])
            seen[id] = true
    if not errors.is_empty():
        return errors
    var state: CampaignState = CampaignState.from_data(data)
    _validate_provinces_and_realms(state, errors)
    validate_family_graph(state, errors)
    _validate_relationships_and_wars(state, errors)
    _validate_claims(state, errors)
    if not state.world_binding.is_empty():
        CampaignWorldBinding.validate(state, errors)
    return errors


static func _validate_provinces_and_realms(state: CampaignState, errors: PackedStringArray) -> void:
    var territory: Dictionary = {}
    var hubs: Dictionary = {}
    for province: ProvinceState in state.provinces.values():
        if not state.realms.has(province.owner_realm_id):
            errors.append("Province %d has an unresolved owner." % province.province_id)
        territory[province.owner_realm_id] = int(territory.get(province.owner_realm_id, 0)) + 1
        if hubs.has(province.primary_settlement_id):
            errors.append("Primary settlement ID belongs to multiple provinces.")
        hubs[province.primary_settlement_id] = true
    for realm: RealmState in state.realms.values():
        var land_count: int = territory.get(realm.realm_id, 0)
        if realm.active:
            if land_count == 0:
                errors.append("Active realm %s has no provinces." % realm.realm_id)
            var capital: ProvinceState = state.provinces.get(realm.capital_province_id)
            if capital == null or capital.owner_realm_id != realm.realm_id:
                errors.append("Realm %s lacks an owned capital." % realm.realm_id)
            _living_reference(state, realm.current_ruler_id, "Realm ruler " + realm.realm_id, errors)
            if not realm.recognized_heir_id.is_empty():
                _living_reference(state, realm.recognized_heir_id, "Recognized heir " + realm.realm_id, errors)
                if realm.recognized_heir_id == realm.current_ruler_id:
                    errors.append("Ruler cannot simultaneously be their own recognized heir.")
        elif land_count != 0 or realm.capital_province_id != 0 or not realm.current_ruler_id.is_empty() or not realm.recognized_heir_id.is_empty():
            errors.append("Inactive realm %s must have no territory/capital/current roles." % realm.realm_id)
    if state.player_realm_id.is_empty():
        if state.game_over:
            errors.append("Game over requires a player realm.")
    elif not state.realms.has(state.player_realm_id):
        errors.append("Player realm reference is invalid.")
    elif state.game_over == state.realms[state.player_realm_id].active:
        errors.append("Player land loss must end the campaign; an active player cannot be defeated.")


static func _living_reference(state: CampaignState, id: String, context: String, errors: PackedStringArray) -> void:
    var character: CharacterState = state.characters.get(id)
    if character == null or not character.alive:
        errors.append(context + " must resolve to a living Character.")


static func validate_family_graph(state: CampaignState, errors: PackedStringArray) -> void:
    var ancestry: Dictionary = {}
    for character: CharacterState in state.characters.values():
        if not state.dynasties.has(character.dynasty_id):
            errors.append("Character %s has an unresolved Dynasty." % character.character_id)
        if not character.realm_id.is_empty() and not state.realms.has(character.realm_id):
            errors.append("Character %s has an unresolved allegiance." % character.character_id)
        if character.parent_ids.size() > 2:
            errors.append("Character may have at most two known actual parents.")
        ancestry[character.character_id] = character.parent_ids
        for id: String in character.parent_ids:
            if id == character.character_id or not state.characters.has(id):
                errors.append("Character %s has an invalid parent." % character.character_id)
        for id: String in character.partner_ids:
            var partner: CharacterState = state.characters.get(id)
            if partner == null or id == character.character_id or character.character_id not in partner.partner_ids:
                errors.append("Character %s has a nonreciprocal/invalid partner." % character.character_id)
    _acyclic(ancestry, "Character ancestry", errors)
    var branches: Dictionary = {}
    for dynasty: DynastyState in state.dynasties.values():
        branches[dynasty.dynasty_id] = []
        if not dynasty.parent_dynasty_id.is_empty():
            branches[dynasty.dynasty_id].append(dynasty.parent_dynasty_id)
            if not state.dynasties.has(dynasty.parent_dynasty_id):
                errors.append("Dynasty %s has an unresolved parent Dynasty." % dynasty.dynasty_id)
    _acyclic(branches, "Dynasty branches", errors)


static func _acyclic(graph: Dictionary, label: String, errors: PackedStringArray) -> void:
    # Iterative topological traversal also handles long genealogies without recursion.
    var remaining: Dictionary = {}
    var descendants: Dictionary = {}
    var ready: Array[String] = []
    for id: String in graph:
        remaining[id] = 0
        for parent: String in graph[id]:
            if not graph.has(parent):
                continue
            remaining[id] += 1
            if not descendants.has(parent):
                descendants[parent] = []
            descendants[parent].append(id)
        if remaining[id] == 0:
            ready.append(id)
    var visited: int = 0
    while visited < ready.size():
        var id: String = ready[visited]
        visited += 1
        for child: String in descendants.get(id, []):
            remaining[child] -= 1
            if remaining[child] == 0:
                ready.append(child)
    if visited != graph.size():
        errors.append(label + " contains a cycle.")


static func _validate_relationships_and_wars(state: CampaignState, errors: PackedStringArray) -> void:
    for relationship: RelationshipState in state.relationships.values():
        if not state.realms.has(relationship.realm_a_id) or not state.realms.has(relationship.realm_b_id):
            errors.append("Relationship has an unresolved Realm pair.")
    var count: int = state.realms.size()
    if state.relationships.size() != count * (count - 1) / 2:
        errors.append("Exactly one RelationshipState is required for every known Realm pair.")
    for war: WarState in state.wars.values():
        if war.attacker_realm_ids.is_empty() or war.defender_realm_ids.is_empty():
            errors.append("War %s requires opposing participant sides." % war.war_id)
        for id: String in war.attacker_realm_ids + war.defender_realm_ids:
            if not state.realms.has(id):
                errors.append("War %s has an unresolved participant." % war.war_id)
            if id in war.attacker_realm_ids and id in war.defender_realm_ids:
                errors.append("War %s has a participant on both sides." % war.war_id)


static func _validate_claims(state: CampaignState, errors: PackedStringArray) -> void:
    var claims: Dictionary[String, ClaimRecord] = {}
    for registry: Dictionary in [state.characters, state.dynasties, state.realms]:
        for owner: RefCounted in registry.values():
            for claim: ClaimRecord in owner.claims:
                if claims.has(claim.claim_id) or claim.claim_id in state.retired_ids["claims"]:
                    errors.append("Claim %s has duplicate ownership or a retired ID." % claim.claim_id)
                claims[claim.claim_id] = claim
                if claim.target_kind == "province":
                    if not StateSchema.is_integer(claim.target_id) or not state.provinces.has(int(claim.target_id)):
                        errors.append("Claim %s has an invalid Province target." % claim.claim_id)
                elif not claim.target_id is String or not state.realms.has(claim.target_id):
                    errors.append("Claim %s has an invalid Realm target." % claim.claim_id)
    for claim: ClaimRecord in claims.values():
        if not claim.related_claim_id.is_empty() and (not claims.has(claim.related_claim_id) or claim.related_claim_id == claim.claim_id):
            errors.append("Claim %s has invalid provenance reference." % claim.claim_id)
