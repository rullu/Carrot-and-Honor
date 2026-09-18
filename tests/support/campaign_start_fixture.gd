class_name CampaignStartFixture
extends RefCounted


static func wire(cast: Dictionary) -> Dictionary:
    var result: Dictionary = cast.duplicate()
    for category: String in ["realm", "character", "dynasty"]:
        result[category + "_setups"] = StateSchema.records_to_data(cast[category + "_setups"])
    return result


static func clone(cast: Dictionary) -> Dictionary:
    var result: Dictionary = cast.duplicate()
    var realms: Array[RealmState] = []
    var characters: Array[CharacterState] = []
    var dynasties: Array[DynastyState] = []
    for record: RealmState in cast["realm_setups"]:
        realms.append(RealmState.from_data(record.to_data()))
    for record: CharacterState in cast["character_setups"]:
        characters.append(CharacterState.from_data(record.to_data()))
    for record: DynastyState in cast["dynasty_setups"]:
        dynasties.append(DynastyState.from_data(record.to_data()))
    result["realm_setups"] = realms
    result["character_setups"] = characters
    result["dynasty_setups"] = dynasties
    return result


static func characters(cast: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for character: CharacterState in cast["character_setups"]:
        result[character.character_id] = character
    return result
