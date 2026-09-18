class_name PoliticalRealmPalette
extends RefCounted


# Presentation pigments, deliberately separate from canonical Realm identity.
const COLORS: Array[Color] = [
    Color("a64f51"), Color("486f9f"), Color("74864a"), Color("ae8743"),
    Color("765990"), Color("398a83"), Color("ad664b"), Color("586a81"),
    Color("b09b48"), Color("4b805d"), Color("904765"), Color("528fa3"),
    Color("866243"), Color("9575a5"), Color("5c9a78"), Color("ad7081"),
    Color("4b5794"), Color("8a9b64"), Color("bc7440"), Color("7f708b"),
    Color("5a84b3"), Color("aa7959"), Color("476d65"), Color("b98c71"),
    Color("a14f7f"), Color("647f96"), Color("b2a56b"), Color("569a9a"),
    Color("8d604f"), Color("787ab0"),
]


static func assign(
    geography: ProvinceGeography,
    owner_by_province: Dictionary[int, String]
) -> Dictionary[String, Color]:
    var neighbors: Dictionary[String, Dictionary] = {}
    var realm_ids: Array[String] = []
    for province_id: int in geography.get_province_ids():
        if not owner_by_province.has(province_id):
            return {}
        var realm_id: String = owner_by_province[province_id]
        if realm_id.is_empty():
            return {}
        if not neighbors.has(realm_id):
            neighbors[realm_id] = {}
            realm_ids.append(realm_id)
        var record: Dictionary = geography.get_province_record(province_id)
        for adjacent_id: int in record["neighbor_ids"]:
            if not owner_by_province.has(adjacent_id):
                continue
            var adjacent_realm: String = owner_by_province[adjacent_id]
            if adjacent_realm == realm_id or adjacent_realm.is_empty():
                continue
            if not neighbors.has(adjacent_realm):
                neighbors[adjacent_realm] = {}
                realm_ids.append(adjacent_realm)
            neighbors[realm_id][adjacent_realm] = true
            neighbors[adjacent_realm][realm_id] = true
    realm_ids.sort()
    var penalties: Array[PackedFloat32Array] = _penalty_matrix()

    var assigned: Dictionary[String, int] = {}
    var used: Dictionary[int, bool] = {}
    while assigned.size() < realm_ids.size():
        var chosen_realm: String = ""
        var best_saturation: int = -1
        var best_degree: int = -1
        for realm_id: String in realm_ids:
            if assigned.has(realm_id):
                continue
            var saturation: int = 0
            for neighbor_id: String in neighbors[realm_id]:
                if assigned.has(neighbor_id):
                    saturation += 1
            var degree: int = neighbors[realm_id].size()
            if saturation > best_saturation or (saturation == best_saturation and degree > best_degree):
                chosen_realm = realm_id
                best_saturation = saturation
                best_degree = degree

        var chosen_index: int = -1
        var best_score: float = -INF
        var use_only_fresh: bool = used.size() < COLORS.size()
        for color_index: int in COLORS.size():
            if use_only_fresh and used.has(color_index):
                continue
            var nearest_neighbor: float = INF
            for neighbor_id: String in neighbors[chosen_realm]:
                if assigned.has(neighbor_id):
                    nearest_neighbor = minf(
                        nearest_neighbor,
                        _distance(COLORS[color_index], COLORS[assigned[neighbor_id]])
                    )
            if is_inf(nearest_neighbor):
                nearest_neighbor = 1.0
            var nearest_any: float = INF
            for assigned_index: int in assigned.values():
                nearest_any = minf(nearest_any, _distance(COLORS[color_index], COLORS[assigned_index]))
            if is_inf(nearest_any):
                nearest_any = 0.0
            var score: float = nearest_neighbor * 4.0 + nearest_any * 0.3
            if score > best_score:
                best_score = score
                chosen_index = color_index
        assigned[chosen_realm] = chosen_index
        used[chosen_index] = true

    # Preserve the 30-color spread while improving the weakest geographic
    # boundaries left by greedy assignment. Swaps keep each Realm's color stable
    # after this one deterministic initial calculation.
    for pass_index: int in 8:
        var best_change: float = -0.000001
        var first_swap: String = ""
        var second_swap: String = ""
        for first_index: int in realm_ids.size():
            for second_index: int in range(first_index + 1, realm_ids.size()):
                var first_realm: String = realm_ids[first_index]
                var second_realm: String = realm_ids[second_index]
                if assigned[first_realm] == assigned[second_realm]:
                    continue
                var change: float = _swap_penalty_change(
                    first_realm, second_realm, neighbors, assigned, penalties
                )
                if change < best_change:
                    best_change = change
                    first_swap = first_realm
                    second_swap = second_realm
        if first_swap.is_empty():
            break
        var held: int = assigned[first_swap]
        assigned[first_swap] = assigned[second_swap]
        assigned[second_swap] = held

    var result: Dictionary[String, Color] = {}
    for realm_id: String in realm_ids:
        result[realm_id] = COLORS[assigned[realm_id]]
    return result


static func _swap_penalty_change(
    first_realm: String,
    second_realm: String,
    neighbors: Dictionary[String, Dictionary],
    assigned: Dictionary[String, int],
    penalties: Array[PackedFloat32Array]
) -> float:
    var first_color: int = assigned[first_realm]
    var second_color: int = assigned[second_realm]
    var change: float = 0.0
    for neighbor_id: String in neighbors[first_realm]:
        var neighbor_color: int = assigned[neighbor_id]
        if neighbor_id == second_realm:
            change += penalties[second_color][first_color] - penalties[first_color][second_color]
        else:
            change += penalties[second_color][neighbor_color] - penalties[first_color][neighbor_color]
    for neighbor_id: String in neighbors[second_realm]:
        if neighbor_id == first_realm:
            continue
        var neighbor_color: int = assigned[neighbor_id]
        change += penalties[first_color][neighbor_color] - penalties[second_color][neighbor_color]
    return change


static func _penalty_matrix() -> Array[PackedFloat32Array]:
    var result: Array[PackedFloat32Array] = []
    for first: int in COLORS.size():
        var row: PackedFloat32Array = []
        for second: int in COLORS.size():
            var distance: float = _distance(COLORS[first], COLORS[second])
            row.append(1.0 / pow(distance + 0.002, 2.0))
        result.append(row)
    return result


static func _distance(first: Color, second: Color) -> float:
    var a: Vector3 = _oklab(first)
    var b: Vector3 = _oklab(second)
    # Slightly favor hue separation; muted colors retain useful value contrast.
    var delta: Vector3 = a - b
    return delta.x * delta.x + 1.5 * (delta.y * delta.y + delta.z * delta.z)


static func _oklab(color: Color) -> Vector3:
    var linear: Color = color.srgb_to_linear()
    var l: float = pow(0.4122214708 * linear.r + 0.5363325363 * linear.g + 0.0514459929 * linear.b, 1.0 / 3.0)
    var m: float = pow(0.2119034982 * linear.r + 0.6806995451 * linear.g + 0.1073969566 * linear.b, 1.0 / 3.0)
    var s: float = pow(0.0883024619 * linear.r + 0.2817188376 * linear.g + 0.6299787005 * linear.b, 1.0 / 3.0)
    return Vector3(
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    )
