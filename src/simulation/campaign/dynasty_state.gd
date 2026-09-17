class_name DynastyState
extends RefCounted


const FIELDS: Dictionary = {
    "dynasty_id": "id",
    "lineage_name": "id",
    "lineage_style": "lineage_style",
    "parent_dynasty_id": "text",
    "origin_culture": "text",
    "origin_religion": "religion",
    "claims": "claims",
    "history": "history",
}

var dynasty_id: String = ""
var lineage_name: String = ""
var lineage_style: String = "house"
var parent_dynasty_id: String = ""
var origin_culture: String = ""
var origin_religion: Dictionary = StateSchema.empty_religion()
var claims: Array[ClaimRecord] = []
var history: Array[HistoricalMemory] = []


func to_data() -> Dictionary:
    return {
        "dynasty_id": dynasty_id,
        "lineage_name": lineage_name,
        "lineage_style": lineage_style,
        "parent_dynasty_id": parent_dynasty_id,
        "origin_culture": origin_culture,
        "origin_religion": origin_religion.duplicate(true),
        "claims": StateSchema.records_to_data(claims),
        "history": StateSchema.records_to_data(history),
    }


# Only call with structurally validated data (CampaignCodec is the trust boundary).
static func from_data(data: Dictionary) -> DynastyState:
    var state: DynastyState = DynastyState.new()
    state.dynasty_id = data["dynasty_id"]
    state.lineage_name = data["lineage_name"]
    state.lineage_style = data["lineage_style"]
    state.parent_dynasty_id = data["parent_dynasty_id"]
    state.origin_culture = data["origin_culture"]
    state.origin_religion = data["origin_religion"].duplicate(true)
    for record: Dictionary in data["claims"]:
        state.claims.append(ClaimRecord.from_data(record))
    for record: Dictionary in data["history"]:
        state.history.append(HistoricalMemory.from_data(record))
    return state
