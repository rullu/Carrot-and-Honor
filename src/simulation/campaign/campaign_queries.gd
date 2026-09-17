class_name CampaignQueries
extends RefCounted


var _state: CampaignState
var _territory: Dictionary = {}
var _members: Dictionary = {}
var _children: Dictionary = {}
var _indexed: bool = false


func _init(state: CampaignState) -> void:
    # A query view represents one committed revision, never a mutable live handle.
    _state = state.copy()


func clear_caches() -> void:
    _territory.clear()
    _members.clear()
    _children.clear()
    _indexed = false


func rebuild_caches() -> void:
    clear_caches()
    for province: ProvinceState in _state.provinces.values():
        if not _territory.has(province.owner_realm_id):
            _territory[province.owner_realm_id] = []
        _territory[province.owner_realm_id].append(province.province_id)
    for character: CharacterState in _state.characters.values():
        if not _members.has(character.dynasty_id):
            _members[character.dynasty_id] = []
        _members[character.dynasty_id].append(character.character_id)
        for parent: String in character.parent_ids:
            if not _children.has(parent):
                _children[parent] = []
            _children[parent].append(character.character_id)
    for index: Dictionary in [_territory, _members, _children]:
        for ids: Array in index.values():
            ids.sort()
    _indexed = true


func territory(realm_id: String) -> Array[int]:
    if not _indexed:
        rebuild_caches()
    var result: Array[int] = []
    result.assign(_territory.get(realm_id, []))
    return result


func dynasty_members(dynasty_id: String, living_only: bool = false) -> Array[String]:
    if not _indexed:
        rebuild_caches()
    var result: Array[String] = []
    for id: String in _members.get(dynasty_id, []):
        if not living_only or _state.characters[id].alive:
            result.append(id)
    return result


func dynasty_is_extinct(dynasty_id: String) -> bool:
    return _state.dynasties.has(dynasty_id) and dynasty_members(dynasty_id, true).is_empty()


func children_of(character_id: String) -> Array[String]:
    if not _indexed:
        rebuild_caches()
    var result: Array[String] = []
    result.assign(_children.get(character_id, []))
    return result


func realm_characters(realm_id: String) -> Array[String]:
    var result: Array[String] = []
    for character: CharacterState in _state.characters.values():
        if character.realm_id == realm_id:
            result.append(character.character_id)
    result.sort()
    return result


func ruling_dynasty(realm_id: String) -> String:
    var realm: RealmState = _state.realms.get(realm_id)
    if realm == null or realm.current_ruler_id.is_empty():
        return ""
    return _state.characters[realm.current_ruler_id].dynasty_id


func local_resources_overview(realm_id: String) -> Dictionary:
    var food: int = 0
    var manpower: int = 0
    for id: int in territory(realm_id):
        food += _state.provinces[id].local_food
        manpower += _state.provinces[id].local_manpower
    return {"food": food, "manpower": manpower}


func is_capital(province_id: int) -> bool:
    var province: ProvinceState = _state.provinces.get(province_id)
    return province != null and _state.realms[province.owner_realm_id].capital_province_id == province_id


func diplomacy_active(first: String, second: String) -> bool:
    return first != second and _state.realms.has(first) and _state.realms.has(second) and _state.realms[first].active and _state.realms[second].active and not _state.game_over


func wars_between(first: String, second: String) -> Array[String]:
    var result: Array[String] = []
    for war: WarState in _state.wars.values():
        if war.active and ((first in war.attacker_realm_ids and second in war.defender_realm_ids) or (second in war.attacker_realm_ids and first in war.defender_realm_ids)):
            result.append(war.war_id)
    result.sort()
    return result
