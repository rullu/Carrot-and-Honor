class_name ProvinceState
extends RefCounted


# province_id is also the immutable reference into canonical geography/heritage.
const FIELDS: Dictionary = {
    "province_id": "positive_int",
    "owner_realm_id": "id",
    "local_culture": "text",
    "local_religion": "religion",
    "primary_settlement_id": "id",
    "population_base": "count",
    "local_manpower": "count",
    "local_food": "count",
    "development_stage": "count",
    "history": "history",
    "economy": "economy",
}

var province_id: int = 0
var owner_realm_id: String = ""
var local_culture: String = ""
var local_religion: Dictionary = StateSchema.empty_religion()
var primary_settlement_id: String = ""
var population_base: int = 0
var local_manpower: int = 0
var local_food: int = 0
var development_stage: int = 0
var history: Array[HistoricalMemory] = []
var economy: ProvinceEconomy


func to_data() -> Dictionary:
    return {
        "province_id": province_id,
        "owner_realm_id": owner_realm_id,
        "local_culture": local_culture,
        "local_religion": local_religion.duplicate(true),
        "primary_settlement_id": primary_settlement_id,
        "population_base": population_base,
        "local_manpower": local_manpower,
        "local_food": local_food,
        "development_stage": development_stage,
        "history": StateSchema.records_to_data(history),
        "economy": economy.to_data() if economy != null else null,
    }


# Only call with structurally validated data (CampaignCodec is the trust boundary).
static func from_data(data: Dictionary) -> ProvinceState:
    var state: ProvinceState = ProvinceState.new()
    state.province_id = int(data["province_id"])
    state.owner_realm_id = data["owner_realm_id"]
    state.local_culture = data["local_culture"]
    state.local_religion = data["local_religion"].duplicate(true)
    state.primary_settlement_id = data["primary_settlement_id"]
    state.population_base = int(data["population_base"])
    state.local_manpower = int(data["local_manpower"])
    state.local_food = int(data["local_food"])
    state.development_stage = int(data["development_stage"])
    state.economy = ProvinceEconomy.from_data(data["economy"]) if data["economy"] != null else null
    for record: Dictionary in data["history"]:
        state.history.append(HistoricalMemory.from_data(record))
    return state
