class_name CampaignStartRandom
extends RefCounted

# Versioned counter stream avoids engine PRNG, hash(), global RNG and clock changes.
var _key: String
var _counter: int = 0


func _init(key: String) -> void:
    _key = key


func below(limit: int) -> int:
    assert(limit > 0 and limit <= 4294967296)
    var ceiling: int = 4294967296 - (4294967296 % limit)
    while true:
        var value: int = (_key + ":" + str(_counter)).sha256_text().left(8).hex_to_int()
        _counter += 1
        if value < ceiling:
            return value % limit
    return 0


func between(first: int, last: int) -> int:
    return first + below(last - first + 1)


func weighted(weights: Array) -> int:
    var total: int = 0
    for weight: int in weights:
        total += weight
    var roll: int = below(total)
    for index: int in weights.size():
        roll -= int(weights[index])
        if roll < 0:
            return index
    return -1
