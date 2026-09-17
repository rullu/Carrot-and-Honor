class_name HistoricalMemory
extends RefCounted


# Perspective-specific narrative; never read as current gameplay truth.
const FIELDS: Dictionary = {
    "event_id": "text",
    "summary": "id",
}

var event_id: String = ""
var summary: String = ""


func to_data() -> Dictionary:
    return {
        "event_id": event_id,
        "summary": summary,
    }


# Only call with structurally validated data (CampaignCodec is the trust boundary).
static func from_data(data: Dictionary) -> HistoricalMemory:
    var state: HistoricalMemory = HistoricalMemory.new()
    state.event_id = data["event_id"]
    state.summary = data["summary"]
    return state
