class_name RelationshipState
extends RefCounted


const FIELDS: Dictionary = {
    "realm_a_id": "id",
    "realm_b_id": "id",
    "attitude_a_to_b": "attitude",
    "attitude_b_to_a": "attitude",
    "agreement_ids": "ids",
    "history": "history",
}

var realm_a_id: String = ""
var realm_b_id: String = ""
var attitude_a_to_b: Dictionary = StateSchema.neutral_attitude()
var attitude_b_to_a: Dictionary = StateSchema.neutral_attitude()
var agreement_ids: Array[String] = []
var history: Array[HistoricalMemory] = []


func to_data() -> Dictionary:
    return {
        "realm_a_id": realm_a_id,
        "realm_b_id": realm_b_id,
        "attitude_a_to_b": attitude_a_to_b.duplicate(true),
        "attitude_b_to_a": attitude_b_to_a.duplicate(true),
        "agreement_ids": agreement_ids.duplicate(true),
        "history": StateSchema.records_to_data(history),
    }


# Only call with structurally validated data (CampaignCodec is the trust boundary).
static func from_data(data: Dictionary) -> RelationshipState:
    var state: RelationshipState = RelationshipState.new()
    state.realm_a_id = data["realm_a_id"]
    state.realm_b_id = data["realm_b_id"]
    state.attitude_a_to_b = StateSchema.normalized_attitude(data["attitude_a_to_b"])
    state.attitude_b_to_a = StateSchema.normalized_attitude(data["attitude_b_to_a"])
    state.agreement_ids.assign(data["agreement_ids"])
    for record: Dictionary in data["history"]:
        state.history.append(HistoricalMemory.from_data(record))
    return state


static func pair_key(first: String, second: String) -> String:
    var pair: Array[String] = [first, second]
    pair.sort()
    # JSON tuple keys avoid ambiguity for opaque IDs containing delimiters.
    return JSON.stringify(pair)


static func create(first: String, second: String) -> RelationshipState:
    var pair: Array[String] = [first, second]
    pair.sort()
    var state: RelationshipState = RelationshipState.new()
    state.realm_a_id = pair[0]
    state.realm_b_id = pair[1]
    return state
