class_name CharacterLifecycle
extends RefCounted


static func set_parents(state: CampaignState, child_id: String, parent_ids: Array[String]) -> PackedStringArray:
    if not state.characters.has(child_id):
        return PackedStringArray(["Unknown child Character."])
    # The child alone owns parent edges. Children are always derived.
    state.characters[child_id].parent_ids = parent_ids.duplicate()
    return []


static func link_partners(state: CampaignState, first: String, second: String, linked: bool) -> PackedStringArray:
    if first == second or not state.characters.has(first) or not state.characters.has(second):
        return PackedStringArray(["Partner linkage requires two different known Characters."])
    for pair: Array in [[first, second], [second, first]]:
        var character: CharacterState = state.characters[pair[0]]
        if linked and pair[1] not in character.partner_ids:
            character.partner_ids.append(pair[1])
            character.partner_ids.sort()
        elif not linked:
            character.partner_ids.erase(pair[1])
    return []


static func mark_deceased(state: CampaignState, character_id: String, successions: Dictionary) -> PackedStringArray:
    if not state.characters.has(character_id) or not state.characters[character_id].alive:
        return PackedStringArray(["Death requires a living Character."])
    # One character can be referenced by several realms. Require replacement in
    # every current rulership in this same transaction, without choosing successors.
    var required: Dictionary = {}
    for realm: RealmState in state.realms.values():
        if realm.current_ruler_id == character_id:
            required[realm.realm_id] = true
        if realm.recognized_heir_id == character_id:
            realm.recognized_heir_id = ""
    if required.size() != successions.size():
        return PackedStringArray(["Provide one explicit succession for every Realm ruled by the deceased."])
    for id: Variant in successions:
        if not required.has(id):
            return PackedStringArray(["Succession supplied for an unrelated Realm."])
        var errors: PackedStringArray = []
        StateSchema.validate_record(successions[id], {"ruler_id": "id", "legitimacy": "id", "heir_id": "text"}, "Death succession", errors)
        if not errors.is_empty():
            return errors
        var succession: Dictionary = successions[id]
        RealmLifecycle.succeed(state, id, succession["ruler_id"], succession["legitimacy"], succession["heir_id"])
    state.characters[character_id].alive = false
    return []
