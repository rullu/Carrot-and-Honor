class_name CharacterState
extends RefCounted


const FIELDS: Dictionary = {
    "character_id": "id",
    "display_name": "id",
    "alive": "bool",
    "dynasty_id": "id",
    "realm_id": "text",
    "personal_culture": "text",
    "personal_religion": "religion",
    "parent_ids": "ids",
    "partner_ids": "ids",
    "traits": "ids",
    "claims": "claims",
    "history": "history",
}

var character_id: String = ""
var display_name: String = ""
var alive: bool = true
var dynasty_id: String = ""
var realm_id: String = ""
var personal_culture: String = ""
var personal_religion: Dictionary = StateSchema.empty_religion()
var parent_ids: Array[String] = []
var partner_ids: Array[String] = []
var traits: Array[String] = []
var claims: Array[ClaimRecord] = []
var history: Array[HistoricalMemory] = []


func to_data() -> Dictionary:
    return {
        "character_id": character_id,
        "display_name": display_name,
        "alive": alive,
        "dynasty_id": dynasty_id,
        "realm_id": realm_id,
        "personal_culture": personal_culture,
        "personal_religion": personal_religion.duplicate(true),
        "parent_ids": parent_ids.duplicate(true),
        "partner_ids": partner_ids.duplicate(true),
        "traits": traits.duplicate(true),
        "claims": StateSchema.records_to_data(claims),
        "history": StateSchema.records_to_data(history),
    }


# Only call with structurally validated data (CampaignCodec is the trust boundary).
static func from_data(data: Dictionary) -> CharacterState:
    var state: CharacterState = CharacterState.new()
    state.character_id = data["character_id"]
    state.display_name = data["display_name"]
    state.alive = data["alive"]
    state.dynasty_id = data["dynasty_id"]
    state.realm_id = data["realm_id"]
    state.personal_culture = data["personal_culture"]
    state.personal_religion = data["personal_religion"].duplicate(true)
    state.parent_ids.assign(data["parent_ids"])
    state.partner_ids.assign(data["partner_ids"])
    state.traits.assign(data["traits"])
    for record: Dictionary in data["claims"]:
        state.claims.append(ClaimRecord.from_data(record))
    for record: Dictionary in data["history"]:
        state.history.append(HistoricalMemory.from_data(record))
    return state
