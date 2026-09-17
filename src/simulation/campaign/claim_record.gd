class_name ClaimRecord
extends RefCounted


# Containment on exactly one Character, Dynasty or Realm determines the claimant.
const FIELDS: Dictionary = {
    "claim_id": "id",
    "target_kind": "target_kind",
    "target_id": "target_id",
    "basis": "text",
    "related_claim_id": "text",
}

var claim_id: String = ""
var target_kind: String = "realm"
var target_id: Variant = ""
var basis: String = ""
var related_claim_id: String = ""


func to_data() -> Dictionary:
    return {
        "claim_id": claim_id,
        "target_kind": target_kind,
        "target_id": target_id,
        "basis": basis,
        "related_claim_id": related_claim_id,
    }


# Only call with structurally validated data (CampaignCodec is the trust boundary).
static func from_data(data: Dictionary) -> ClaimRecord:
    var state: ClaimRecord = ClaimRecord.new()
    state.claim_id = data["claim_id"]
    state.target_kind = data["target_kind"]
    state.target_id = int(data["target_id"]) if state.target_kind == "province" and StateSchema.is_integer(data["target_id"]) else data["target_id"]
    state.basis = data["basis"]
    state.related_claim_id = data["related_claim_id"]
    return state
