class_name WarState
extends RefCounted


# Boundary stub: conflict identity and opposing participants only; no war mechanics.
const FIELDS: Dictionary = {
    "war_id": "id",
    "active": "bool",
    "attacker_realm_ids": "ids",
    "defender_realm_ids": "ids",
}

var war_id: String = ""
var active: bool = true
var attacker_realm_ids: Array[String] = []
var defender_realm_ids: Array[String] = []


func to_data() -> Dictionary:
    return {
        "war_id": war_id,
        "active": active,
        "attacker_realm_ids": attacker_realm_ids.duplicate(true),
        "defender_realm_ids": defender_realm_ids.duplicate(true),
    }


# Only call with structurally validated data (CampaignCodec is the trust boundary).
static func from_data(data: Dictionary) -> WarState:
    var state: WarState = WarState.new()
    state.war_id = data["war_id"]
    state.active = data["active"]
    state.attacker_realm_ids.assign(data["attacker_realm_ids"])
    state.defender_realm_ids.assign(data["defender_realm_ids"])
    return state
