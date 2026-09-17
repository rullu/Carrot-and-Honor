class_name RealmState
extends RefCounted


const FIELDS: Dictionary = {
    "realm_id": "id",
    "original_identity_id": "text",
    "political_identity_id": "id",
    "realm_style": "text",
    "polity_type": "text",
    "active": "bool",
    "capital_province_id": "count",
    "current_ruler_id": "text",
    "recognized_heir_id": "text",
    "legitimacy": "id",
    "succession_law_id": "text",
    "official_culture": "text",
    "official_religion": "religion",
    "carrots": "count",
    "faith": "count",
    "claims": "claims",
    "history": "history",
}

var realm_id: String = ""
var original_identity_id: String = ""
var political_identity_id: String = ""
var realm_style: String = ""
var polity_type: String = ""
var active: bool = true
var capital_province_id: int = 0
var current_ruler_id: String = ""
var recognized_heir_id: String = ""
var legitimacy: String = "unresolved"
var succession_law_id: String = ""
var official_culture: String = ""
var official_religion: Dictionary = StateSchema.empty_religion()
var carrots: int = 0
var faith: int = 0
var claims: Array[ClaimRecord] = []
var history: Array[HistoricalMemory] = []


func to_data() -> Dictionary:
    return {
        "realm_id": realm_id,
        "original_identity_id": original_identity_id,
        "political_identity_id": political_identity_id,
        "realm_style": realm_style,
        "polity_type": polity_type,
        "active": active,
        "capital_province_id": capital_province_id,
        "current_ruler_id": current_ruler_id,
        "recognized_heir_id": recognized_heir_id,
        "legitimacy": legitimacy,
        "succession_law_id": succession_law_id,
        "official_culture": official_culture,
        "official_religion": official_religion.duplicate(true),
        "carrots": carrots,
        "faith": faith,
        "claims": StateSchema.records_to_data(claims),
        "history": StateSchema.records_to_data(history),
    }


# Only call with structurally validated data (CampaignCodec is the trust boundary).
static func from_data(data: Dictionary) -> RealmState:
    var state: RealmState = RealmState.new()
    state.realm_id = data["realm_id"]
    state.original_identity_id = data["original_identity_id"]
    state.political_identity_id = data["political_identity_id"]
    state.realm_style = data["realm_style"]
    state.polity_type = data["polity_type"]
    state.active = data["active"]
    state.capital_province_id = int(data["capital_province_id"])
    state.current_ruler_id = data["current_ruler_id"]
    state.recognized_heir_id = data["recognized_heir_id"]
    state.legitimacy = data["legitimacy"]
    state.succession_law_id = data["succession_law_id"]
    state.official_culture = data["official_culture"]
    state.official_religion = data["official_religion"].duplicate(true)
    state.carrots = int(data["carrots"])
    state.faith = int(data["faith"])
    for record: Dictionary in data["claims"]:
        state.claims.append(ClaimRecord.from_data(record))
    for record: Dictionary in data["history"]:
        state.history.append(HistoricalMemory.from_data(record))
    return state
