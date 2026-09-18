extends SceneTree


var _failures: int = 0


func _initialize() -> void:
    var geography: ProvinceGeography = ProvinceGeography.load_from_path(
        "res://data/world_map/astra_provinces.json"
    )
    var catalogue: RefCounted = WorldIdentityCatalogue.load_default()
    var gameplay: WorldGameplay = load(
        "res://scenes/gameplay/world_gameplay.tscn"
    ).instantiate() as WorldGameplay
    _check(gameplay.initialize_gameplay_data(), "gameplay inspection state initializes")
    var cultures: Dictionary[int, String] = gameplay._current_cultures()
    _check(cultures.size() == 100, "all 100 active Provinces have current culture")
    var distinct_cultures: Dictionary[String, bool] = {}
    for province_id: int in geography.get_province_ids():
        var expected: String = catalogue.get_province_identity(province_id)["culture"]
        _check(cultures[province_id] == expected, "Province culture uses canonical seed")
        distinct_cultures[cultures[province_id]] = true
    _check(distinct_cultures.size() == 18, "all 18 starting cultures are present")

    var culture_colors: Dictionary[String, Color] = PoliticalRealmPalette.assign(
        geography, cultures
    )
    _check(culture_colors.size() == 18, "every culture receives a color")
    _check(
        culture_colors == PoliticalRealmPalette.assign(geography, cultures),
        "culture color assignment is deterministic"
    )
    var distinct_colors: Dictionary[Color, bool] = {}
    for color: Color in culture_colors.values():
        distinct_colors[color] = true
    _check(distinct_colors.size() == 18, "all starting cultures have distinct colors")
    var minimum_neighbor_distance: float = INF
    for province_id: int in geography.get_province_ids():
        var record: Dictionary = geography.get_province_record(province_id)
        for neighbor_id: int in record["neighbor_ids"]:
            if cultures[province_id] == cultures[neighbor_id]:
                continue
            minimum_neighbor_distance = minf(
                minimum_neighbor_distance,
                PoliticalRealmPalette._distance(
                    culture_colors[cultures[province_id]],
                    culture_colors[cultures[neighbor_id]]
                )
            )
    print("CULTURE_NEIGHBOR_MIN_OKLAB_DISTANCE_SQUARED: %.4f" % minimum_neighbor_distance)
    _check(minimum_neighbor_distance > 0.015, "neighboring cultures are distinguishable")

    var map: PoliticalMapPresentation = PoliticalMapPresentation.new()
    var rendered_colors: Dictionary[int, Color] = map.refresh_ownership(geography, cultures)
    _check(rendered_colors.size() == 100, "all Province mask entries receive culture color")
    for province_id: int in geography.get_province_ids():
        _check(
            rendered_colors[province_id] == culture_colors[cultures[province_id]],
            "Province %d renders its culture color" % province_id
        )

    var specs: Dictionary[String, Dictionary] = CultureRegionLabels.build_specs(
        geography, cultures
    )
    _check(specs.size() == 28, "disconnected starting cultures form 28 label regions")
    var seen_provinces: Dictionary[int, bool] = {}
    var averi_regions: int = 0
    for spec: Dictionary in specs.values():
        var culture: String = spec["culture"]
        var provinces: Array[int] = spec["province_ids"]
        _check(
            provinces.has(spec["anchor_province_id"]),
            "culture region anchor is inside its component"
        )
        if culture == "Averi":
            averi_regions += 1
        for province_id: int in provinces:
            _check(not seen_provinces.has(province_id), "Province has one culture region")
            seen_provinces[province_id] = true
            _check(cultures[province_id] == culture, "label matches component culture")
    _check(seen_provinces.size() == 100, "culture regions cover all active Provinces")
    _check(averi_regions == 2, "disconnected Averi regions get separate labels")

    var changed_province: ProvinceState = gameplay._inspection_provinces[32]
    changed_province.local_culture = "Carthen"
    var changed_cultures: Dictionary[int, String] = gameplay._current_cultures()
    _check(changed_cultures[32] == "Carthen", "map reads current ProvinceState culture")
    var changed_specs: Dictionary[String, Dictionary] = CultureRegionLabels.build_specs(
        geography, changed_cultures
    )
    for spec: Dictionary in changed_specs.values():
        _check(spec["culture"] != "Eldskar", "lost culture leaves no stale label")
        if spec["province_ids"].has(32):
            _check(spec["culture"] == "Carthen", "changed Province label follows culture")
    gameplay.free()
    if _failures == 0:
        print("Culture map mode test PASS: current state, colors and connected labels.")
    else:
        push_error("Culture map mode test FAIL: %d checks." % _failures)
    quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)
