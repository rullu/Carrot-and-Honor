class_name CampaignStartValidator
extends RefCounted

const FIELDS: Dictionary = {
    "campaign_seed": "seed", "generator_version": "positive_int", "days_per_year": "positive_int",
    "world_binding": "id", "realm_setups": "array", "character_setups": "array", "dynasty_setups": "array",
}


static func birth_order(first: CharacterState, second: CharacterState) -> bool:
    # Same-tick siblings are legal. Opaque IDs supply a stable tie break.
    return first.birth_tick < second.birth_tick if first.birth_tick != second.birth_tick else first.character_id < second.character_id


static func validate(cast: Dictionary, world: CampaignStartWorld) -> PackedStringArray:
    var errors: PackedStringArray = world.errors.duplicate()
    StateSchema.validate_record(cast, FIELDS, "Starting cast", errors)
    if not errors.is_empty():
        return errors
    if cast["world_binding"] != world.binding or cast["generator_version"] != 1:
        errors.append("Starting cast has incompatible world binding or generator version.")
    if cast["days_per_year"] > 4294967296 / 256:
        errors.append("Starting cast year length exceeds exact v1 sampling range.")
    var state: CampaignState = CampaignState.new()
    state.days_per_year = int(cast["days_per_year"])
    for category: String in ["realm", "character", "dynasty"]:
        var registry: Dictionary
        var fields: Dictionary
        match category:
            "realm":
                registry = state.realms
                fields = RealmState.FIELDS
            "character":
                registry = state.characters
                fields = CharacterState.FIELDS
            "dynasty":
                registry = state.dynasties
                fields = DynastyState.FIELDS
        for record: Variant in cast[category + "_setups"]:
            var correct_type: bool = (category == "realm" and record is RealmState) or (category == "character" and record is CharacterState) or (category == "dynasty" and record is DynastyState)
            if not correct_type:
                errors.append("Invalid starting " + category + " record type.")
                continue
            var data: Dictionary = record.to_data()
            StateSchema.validate_record(data, fields, "Starting " + category, errors)
            var id: String = data[category + "_id"]
            if registry.has(id):
                errors.append("Duplicate starting " + category + " ID.")
            registry[id] = record
    if not errors.is_empty():
        return errors
    CampaignValidator.validate_family_graph(state, errors)
    for character: CharacterState in state.characters.values():
        if character.birth_tick > 0:
            errors.append("Starting character cannot be born in the future.")
    if not errors.is_empty():
        return errors
    var rulers: Dictionary = {}
    var ruling_dynasties: Dictionary = {}
    if state.realms.size() != 43:
        errors.append("Exactly 43 starting Realms required.")
    for id: String in world.realm_ids:
        if not state.realms.has(id):
            errors.append("Missing starting Realm " + id)
            continue
        var realm: RealmState = state.realms[id]
        var expected: RealmState = world.realm_setup(id)
        for field: String in ["active", "capital_province_id", "official_culture", "official_religion", "succession_law_id", "legitimacy", "original_identity_id", "political_identity_id", "realm_style", "polity_type", "carrots", "faith", "claims", "history"]:
            if realm.get(field) != expected.get(field):
                errors.append("Invalid canonical starting Realm %s.%s." % [id, field])
        var ruler: CharacterState = state.characters.get(realm.current_ruler_id)
        if ruler == null or not ruler.alive:
            errors.append("Starting ruler must be a living Character.")
            continue
        if rulers.has(ruler.character_id):
            errors.append("Starting personal union is forbidden.")
        rulers[ruler.character_id] = true
        ruling_dynasties[ruler.dynasty_id] = true
        if ruler.realm_id != id or ruler.personal_culture != realm.official_culture or ruler.personal_religion != realm.official_religion:
            errors.append("Starting ruler affiliation/identity differs from canonical Realm setup.")
        if ruler.age_years(0, state.days_per_year) < 18:
            errors.append("Starting ruler must be adult.")
        var children: Array[CharacterState] = []
        for child: CharacterState in state.characters.values():
            if ruler.character_id not in child.parent_ids:
                continue
            children.append(child)
            if not child.alive or child.parent_ids.size() != 2 or child.dynasty_id != ruler.dynasty_id:
                errors.append("Starting ruler child must be alive, legitimate and inherit reigning lineage.")
            if child.personal_culture != ruler.personal_culture or child.personal_religion != ruler.personal_religion:
                errors.append("Starting ruler child must inherit ruler personal identity.")
            for parent_id: String in child.parent_ids:
                if parent_id != ruler.character_id and parent_id not in ruler.partner_ids:
                    errors.append("Starting ruler child lacks a recorded spouse parent.")
        children.sort_custom(birth_order)
        var expected_heir: String = ""
        if id != "R008" and not children.is_empty():
            expected_heir = children[0].character_id
        if realm.recognized_heir_id != expected_heir:
            errors.append("Wrong starting recognized heir for " + id)
        if ruler.partner_ids.size() > 2:
            errors.append("Starting ruler has too many former spouses.")
        if ruler.partner_ids.size() == 2:
            var living: int = 0
            for partner_id: String in ruler.partner_ids:
                living += int(state.characters[partner_id].alive)
            if living != 1:
                errors.append("Remarried starting ruler needs one living and one deceased spouse.")
        if children.size() > 5:
            errors.append("Starting ruler child count exceeds Generator Tuning v1.")
        _validate_connected_family(state, ruler, errors)
    _validate_family(state, world, errors)
    var used_names: Dictionary = {}
    for dynasty: DynastyState in state.dynasties.values():
        if not _opaque_id(dynasty.dynasty_id, "dynasty"):
            errors.append("Malformed opaque starting Dynasty ID.")
        if used_names.has(dynasty.lineage_name):
            errors.append("Duplicate unrelated starting lineage name.")
        used_names[dynasty.lineage_name] = true
        if not dynasty.parent_dynasty_id.is_empty():
            errors.append("No procedural cadet parent at start.")
        if not world.names.valid_name(dynasty.lineage_name, dynasty.origin_culture, "lineage"):
            errors.append("Invalid regional lineage name.")
        if dynasty.lineage_style != world.names.style(dynasty.origin_culture, ruling_dynasties.has(dynasty.dynasty_id)):
            errors.append("Invalid starting lineage public style.")
        if not dynasty.claims.is_empty() or not dynasty.history.is_empty():
            errors.append("Generated lineage contains deferred claims/history.")
        var affiliations: Dictionary = {}
        for member: CharacterState in state.characters.values():
            if member.dynasty_id == dynasty.dynasty_id:
                affiliations[member.realm_id] = true
                if member.personal_culture != dynasty.origin_culture or member.personal_religion != dynasty.origin_religion:
                    errors.append("Generated member identity differs from its starting lineage origin.")
        if affiliations.size() != 1:
            errors.append("Starting lineage is unused or spans multiple Realms.")
    return errors


static func _validate_family(state: CampaignState, world: CampaignStartWorld, errors: PackedStringArray) -> void:
    for character: CharacterState in state.characters.values():
        if not _opaque_id(character.character_id, "character"):
            errors.append("Malformed opaque starting Character ID.")
        if character.birth_tick > 0:
            errors.append("Starting character cannot be born in the future.")
            continue
        if character.alive and character.age_years(0, state.days_per_year) > 85:
            errors.append("Generated living character exceeds age ceiling.")
        if not world.names.valid_name(character.given_name, character.personal_culture, character.sex):
            errors.append("Invalid regional given name.")
        if not state.realms.has(character.realm_id):
            errors.append("Starting Character lacks Realm affiliation.")
            continue
        var realm: RealmState = state.realms[character.realm_id]
        var identity: Dictionary = {"culture": character.personal_culture, "religion": character.personal_religion}
        var official: Dictionary = {"culture": realm.official_culture, "religion": realm.official_religion}
        if identity != official and identity not in world.identities(character.realm_id):
            errors.append("Personal identity is unsupported by the canonical starting footprint.")
        if not character.traits.is_empty() or not character.claims.is_empty() or not character.history.is_empty():
            errors.append("Generated character contains deferred traits/claims/history.")
        for parent_id: String in character.parent_ids:
            var parent: CharacterState = state.characters[parent_id]
            if character.birth_tick - parent.birth_tick < 16 * state.days_per_year:
                errors.append("Parent-child age gap below 16 years.")
            if parent.realm_id != character.realm_id:
                errors.append("Starting parent/child affiliations differ.")
        if character.parent_ids.size() == 2:
            var first: CharacterState = state.characters[character.parent_ids[0]]
            var second: CharacterState = state.characters[character.parent_ids[1]]
            if second.character_id not in first.partner_ids or first.sex == second.sex:
                errors.append("Starting two-parent branch is not a coherent legitimate family.")
        var living_spouses: int = 0
        for partner_id: String in character.partner_ids:
            var partner: CharacterState = state.characters[partner_id]
            if partner.alive:
                living_spouses += 1
            if partner.realm_id != character.realm_id:
                errors.append("Starting inter-Realm marriage is forbidden.")
            if character.alive and character.age_years(0, state.days_per_year) < 18:
                errors.append("Living starting spouse must be adult.")
            if partner.dynasty_id == character.dynasty_id:
                errors.append("Starting spouses require unrelated birth lineages.")
            if _related(state, character, partner):
                errors.append("Starting partners cannot be close blood relatives.")
        if living_spouses > 1:
            errors.append("More than one living starting spouse.")
        if not character.alive and character.partner_ids.is_empty():
            var needed: bool = false
            for child: CharacterState in state.characters.values():
                needed = needed or character.character_id in child.parent_ids
            if not needed:
                errors.append("Decorative deceased relative has no family purpose.")


static func _ancestors(state: CampaignState, character: CharacterState) -> Dictionary:
    var found: Dictionary = {character.character_id: true}
    var pending: Array[String] = character.parent_ids.duplicate()
    while not pending.is_empty():
        var id: String = pending.pop_back()
        if not found.has(id):
            found[id] = true
            pending.append_array(state.characters[id].parent_ids)
    return found


static func _related(state: CampaignState, first: CharacterState, second: CharacterState) -> bool:
    var ancestors: Dictionary = _ancestors(state, first)
    for id: String in _ancestors(state, second):
        if ancestors.has(id):
            return true
    return false


static func _validate_connected_family(state: CampaignState, ruler: CharacterState, errors: PackedStringArray) -> void:
    var reached: Dictionary = {ruler.character_id: true}
    var pending: Array[String] = [ruler.character_id]
    while not pending.is_empty():
        var id: String = pending.pop_back()
        var record: CharacterState = state.characters[id]
        var adjacent: Array[String] = record.parent_ids + record.partner_ids
        for child: CharacterState in state.characters.values():
            if id in child.parent_ids:
                adjacent.append(child.character_id)
        for neighbor: String in adjacent:
            if not reached.has(neighbor):
                reached[neighbor] = true
                pending.append(neighbor)
    for member: CharacterState in state.characters.values():
        if member.realm_id == ruler.realm_id and not reached.has(member.character_id):
            errors.append("Starting relative has no connection to its Realm ruler.")


static func _opaque_id(id: String, prefix: String) -> bool:
    if not id.begins_with(prefix + "_") or id.length() != prefix.length() + 33:
        return false
    for letter: String in id.substr(prefix.length() + 1):
        if letter not in "0123456789abcdef":
            return false
    return true


static func statistics(cast: Dictionary) -> Dictionary:
    var characters: Dictionary = {}
    for character: CharacterState in cast["character_setups"]:
        characters[character.character_id] = character
    var stats: Dictionary = {"male": 0, "young": 0, "old": 0, "childless": 0, "large_family": 0, "remarried": 0}
    for realm: RealmState in cast["realm_setups"]:
        var ruler: CharacterState = characters[realm.current_ruler_id]
        var age: int = ruler.age_years(0, int(cast["days_per_year"]))
        stats["male"] += int(ruler.sex == "male")
        stats["young"] += int(age <= 24)
        stats["old"] += int(age >= 60)
        var children: int = 0
        for child: CharacterState in characters.values():
            children += int(ruler.character_id in child.parent_ids)
        stats["childless"] += int(children == 0)
        stats["large_family"] += int(children >= 4)
        stats["remarried"] += int(ruler.partner_ids.size() == 2)
    return stats


static func soft_sanity(cast: Dictionary) -> PackedStringArray:
    var stats: Dictionary = statistics(cast)
    var errors: PackedStringArray = []
    if stats["male"] < 25 or stats["male"] > 40:
        errors.append("Male ruler count outside broad 25..40 sanity bound.")
    if stats["young"] > 10 or stats["old"] > 12:
        errors.append("Ruler age bands exceed broad sanity bounds.")
    if stats["childless"] < 18 or stats["childless"] > 34:
        errors.append("Childless ruler count outside broad 18..34 sanity bound.")
    if stats["large_family"] > 8 or stats["remarried"] > 3:
        errors.append("Large-family/remarriage count exceeds broad sanity bounds.")
    return errors
