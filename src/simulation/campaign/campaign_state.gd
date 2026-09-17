class_name CampaignState
extends RefCounted


# A typed registry, not an additional owner of entity facts. Runtime writers use
# CampaignSession; this value object is also useful for explicit scenario setup.
const SCHEMA_VERSION: int = 1
const RETIRED_FIELDS: Dictionary = {
    "provinces": "province_ids", "realms": "ids", "characters": "ids",
    "dynasties": "ids", "wars": "ids", "claims": "ids",
}

var provinces: Dictionary[int, ProvinceState] = {}
var realms: Dictionary[String, RealmState] = {}
var characters: Dictionary[String, CharacterState] = {}
var dynasties: Dictionary[String, DynastyState] = {}
var relationships: Dictionary[String, RelationshipState] = {}
var wars: Dictionary[String, WarState] = {}
var retired_ids: Dictionary = {
    "provinces": [], "realms": [], "characters": [], "dynasties": [], "wars": [], "claims": [],
}
var world_binding: String = ""
var player_realm_id: String = ""
var game_over: bool = false


func to_data() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION, "world_binding": world_binding,
        "player_realm_id": player_realm_id, "game_over": game_over,
        "retired_ids": retired_ids.duplicate(true),
        "provinces": _registry_data(provinces), "realms": _registry_data(realms),
        "characters": _registry_data(characters), "dynasties": _registry_data(dynasties),
        "relationships": _registry_data(relationships), "wars": _registry_data(wars),
    }


static func _registry_data(registry: Dictionary) -> Array:
    var ids: Array = registry.keys()
    ids.sort()
    var result: Array = []
    for id: Variant in ids:
        result.append(registry[id].to_data())
    return result


static func from_data(data: Dictionary) -> CampaignState:
    var state: CampaignState = CampaignState.new()
    state.world_binding = data["world_binding"]
    state.player_realm_id = data["player_realm_id"]
    state.game_over = data["game_over"]
    state.retired_ids = data["retired_ids"].duplicate(true)
    state.retired_ids["provinces"] = StateSchema.integer_array(data["retired_ids"]["provinces"])
    for record: Dictionary in data["provinces"]:
        var province: ProvinceState = ProvinceState.from_data(record)
        state.provinces[province.province_id] = province
    for record: Dictionary in data["realms"]:
        var realm: RealmState = RealmState.from_data(record)
        state.realms[realm.realm_id] = realm
    for record: Dictionary in data["characters"]:
        var character: CharacterState = CharacterState.from_data(record)
        state.characters[character.character_id] = character
    for record: Dictionary in data["dynasties"]:
        var dynasty: DynastyState = DynastyState.from_data(record)
        state.dynasties[dynasty.dynasty_id] = dynasty
    for record: Dictionary in data["relationships"]:
        var relationship: RelationshipState = RelationshipState.from_data(record)
        state.relationships[RelationshipState.pair_key(relationship.realm_a_id, relationship.realm_b_id)] = relationship
    for record: Dictionary in data["wars"]:
        var war: WarState = WarState.from_data(record)
        state.wars[war.war_id] = war
    return state


func copy() -> CampaignState:
    return from_data(to_data())


func ensure_relationships() -> void:
    # Retain one pair for every known realm, including inactive historical realms.
    var ids: Array[String] = []
    ids.assign(realms.keys())
    ids.sort()
    for first: int in ids.size():
        for second: int in range(first + 1, ids.size()):
            var key: String = RelationshipState.pair_key(ids[first], ids[second])
            if not relationships.has(key):
                relationships[key] = RelationshipState.create(ids[first], ids[second])
