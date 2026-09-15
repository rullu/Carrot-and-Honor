class_name ProvinceState
extends RefCounted


var _province_id: int
var _population: int
var _food: int
var _carrots: int
var _development: int


static func create(
        province_id: int,
        population: int,
        food: int,
        carrots: int,
        development: int
) -> ProvinceState:
    if province_id <= 0:
        return null
    if population < 0 or food < 0 or carrots < 0 or development < 0:
        return null

    var state: ProvinceState = ProvinceState.new()
    state._province_id = province_id
    state._population = population
    state._food = food
    state._carrots = carrots
    state._development = development
    return state


func get_province_id() -> int:
    return _province_id


func get_population() -> int:
    return _population


func get_food() -> int:
    return _food


func get_carrots() -> int:
    return _carrots


func get_development() -> int:
    return _development
