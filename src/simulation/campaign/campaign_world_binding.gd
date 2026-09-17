class_name CampaignWorldBinding
extends RefCounted


const PATHS: Array[String] = [
    "res://data/world_identity/world_identity_master_canon.json",
    "res://data/politics/starting_realm_ownership_v1.json",
    "res://data/world_map/astra_provinces.json",
    "res://data/world_map/astra_province_corrections.json",
]


static func fingerprint() -> String:
    var hashes: PackedStringArray = []
    for path: String in PATHS:
        if not FileAccess.file_exists(path):
            return ""
        hashes.append(authority_text_hash(FileAccess.get_file_as_string(path)))
    return "|".join(hashes).sha256_text()


static func authority_text_hash(text: String) -> String:
    # Git checkout line endings differ across platforms. Preserve content changes
    # in the fingerprint without invalidating a save solely due to CRLF versus LF.
    return text.replace("\r\n", "\n").sha256_text()


static func retired_province_ids() -> Array:
    var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATHS[3]))
    if not document is Dictionary:
        return []
    return StateSchema.integer_array(document.get("id_policy", {}).get("retired_ids", []))


static func validate(state: CampaignState, errors: PackedStringArray) -> void:
    if state.world_binding != fingerprint():
        errors.append("Save belongs to different world authorities; explicit migration required.")
        return
    var catalogue: RefCounted = WorldIdentityCatalogue.load_default()
    if catalogue == null:
        errors.append("World identity catalogue cannot be resolved.")
        return
    var province_ids: PackedInt32Array = catalogue.get_province_ids()
    if state.provinces.size() != province_ids.size():
        errors.append("Campaign must preserve the exact authoritative province footprint.")
    for id: int in province_ids:
        if not state.provinces.has(id):
            errors.append("Missing canonical Province %d." % id)
    for id: StringName in catalogue.get_realm_ids():
        var realm: RealmState = state.realms.get(String(id))
        if realm == null or realm.original_identity_id != String(id):
            errors.append("Canonical Realm %s must retain its stable original identity." % id)
    for realm: RealmState in state.realms.values():
        if not realm.original_identity_id.is_empty() and realm.original_identity_id != realm.realm_id:
            errors.append("A new realm cannot impersonate another original Realm identity.")
    for id: Variant in retired_province_ids():
        if id not in state.retired_ids["provinces"]:
            errors.append("Retired geographic IDs must remain reserved.")
