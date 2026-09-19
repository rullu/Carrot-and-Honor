class_name EconomyWorld
extends RefCounted

# Read-only binding to fixed geography; suitability is explicitly authored input.
var province_ids: Array[int] = []
var neighbors: Dictionary[int, Array] = {}
var geography: Dictionary[int, Dictionary] = {}
var errors: PackedStringArray = []
static var _cached_binding: String = ""
static var _cached_ids: Array[int] = []
static var _cached_neighbors: Dictionary[int, Array] = {}
static var _cached_identities: Dictionary[int, Dictionary] = {}


func _init(state: CampaignState, config: EconomyConfig) -> void:
    if state.world_binding.is_empty():
        errors.append("Economy generation requires a canonical world binding.")
        return
    # Disposable metadata cache only. Permanent campaign validation still checks
    # the actual authority fingerprints on every load/publication.
    if _cached_binding != state.world_binding:
        var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(CampaignWorldBinding.PATHS[2]))
        var identity: RefCounted = WorldIdentityCatalogue.load_default()
        if not source is Dictionary or not source.get("provinces") is Array or identity == null:
            errors.append("Canonical economy geography could not be loaded.")
            return
        _cached_ids.clear()
        _cached_neighbors.clear()
        _cached_identities.clear()
        for entry: Dictionary in source["provinces"]:
            var id: int = int(entry["id"])
            _cached_ids.append(id)
            _cached_neighbors[id] = StateSchema.integer_array(entry["neighbor_ids"])
            _cached_identities[id] = identity.get_province_identity(id)
        _cached_ids.sort()
        _cached_binding = state.world_binding
    province_ids = _cached_ids.duplicate()
    neighbors = _cached_neighbors.duplicate(true)
    if province_ids.size() != 100 or state.provinces.size() != 100:
        errors.append("Economy v1 floors require the canonical 100-Province world.")
    for id: int in province_ids:
        if not state.provinces.has(id):
            errors.append("Economy input is missing a canonical Province.")
    for entry: Dictionary in config.geography:
        geography[int(entry["province_id"])] = entry.duplicate(true)
    if geography.size() != 100:
        errors.append("Explicit suitable-coast/aquatic bindings for all 100 Provinces are required.")
    for id: int in province_ids:
        if not geography.has(id):
            errors.append("Missing fixed-geography economy binding: " + str(id))
    for id: String in config.powerhouse_realm_ids:
        if not state.realms.has(id):
            errors.append("Unknown configured Powerhouse Realm: " + id)
    for entry: Dictionary in config.authored_sites + config.authored_buildings:
        if not state.provinces.has(int(entry["province_id"])):
            errors.append("Authored start references an unknown Province.")


func coast(id: int) -> bool:
    return bool(geography[id]["coast"])


func aquatic(id: int) -> bool:
    return bool(geography[id]["aquatic"])


func starting_identity(id: int) -> Dictionary:
    return _cached_identities[id].duplicate(true)
