extends SceneTree


const WORLD_ORIGIN: Vector2 = Vector2(-25000.0, -14062.5)
const SAMPLE_SPACING: float = 12.20703125
var _failures: int = 0


func _initialize() -> void:
    var geography: ProvinceGeography = ProvinceGeography.load_from_path(
        "res://data/world_map/astra_provinces.json"
    )
    var gameplay: WorldGameplay = load(
        "res://scenes/gameplay/world_gameplay.tscn"
    ).instantiate() as WorldGameplay
    _check(gameplay.initialize_gameplay_data(), "gameplay ownership initializes")
    var owners: Dictionary[int, String] = gameplay._current_owners()
    _check(owners.size() == 100, "all 100 active Provinces have current owners")
    var colors: Dictionary[String, Color] = PoliticalRealmPalette.assign(geography, owners)
    _check(colors.size() == 43, "all 43 starting Realms have colors")
    var distinct: Dictionary[Color, bool] = {}
    for color: Color in colors.values():
        distinct[color] = true
    _check(distinct.size() == PoliticalRealmPalette.COLORS.size(), "all 30 curated pigments are used")
    _check(colors == PoliticalRealmPalette.assign(geography, owners), "assignment is deterministic")
    var minimum_neighbor_distance: float = INF
    var minimum_neighbor_pair: String = ""
    for province_id: int in geography.get_province_ids():
        var record: Dictionary = geography.get_province_record(province_id)
        for neighbor_id: int in record["neighbor_ids"]:
            if owners[province_id] != owners[neighbor_id]:
                var distance: float = PoliticalRealmPalette._distance(
                    colors[owners[province_id]], colors[owners[neighbor_id]]
                )
                if distance < minimum_neighbor_distance:
                    minimum_neighbor_distance = distance
                    minimum_neighbor_pair = "%s/%s %s/%s" % [
                        owners[province_id], owners[neighbor_id],
                        colors[owners[province_id]].to_html(),
                        colors[owners[neighbor_id]].to_html()
                    ]
                _check(distance > 0.0, "neighboring Realms differ at %d/%d" % [province_id, neighbor_id])
    print("POLITICAL_NEIGHBOR_MIN_OKLAB_DISTANCE_SQUARED: %.4f (%s)" % [minimum_neighbor_distance, minimum_neighbor_pair])
    _check(minimum_neighbor_distance > 0.015, "adjacent Realm colors retain visible perceptual separation")
    var political: PoliticalMapPresentation = PoliticalMapPresentation.new()
    var province_colors: Dictionary[int, Color] = political.refresh_ownership(geography, owners)
    _check(province_colors.size() == 100, "presentation binds all 100 current owners")
    var palette_image: Image = political._province_colors.get_image()
    for province_id: int in geography.get_province_ids():
        for other_id: int in geography.get_province_ids():
            if owners[province_id] == owners[other_id]:
                _check(
                    palette_image.get_pixel(province_id, 0) == palette_image.get_pixel(other_id, 0),
                    "one Realm has one exact rendered color"
                )
    var changed_province: ProvinceState = gameplay._inspection_provinces[30]
    var original_owner: String = changed_province.owner_realm_id
    var changed_owner: String = "R001" if original_owner != "R001" else "R002"
    changed_province.owner_realm_id = changed_owner
    var changed_owners: Dictionary[int, String] = gameplay._current_owners()
    _check(changed_owners[30] == changed_owner, "current ProvinceState owner is read after change")
    province_colors = political.refresh_ownership(geography, changed_owners)
    _check(
        province_colors[30] == colors[changed_owner],
        "political color follows current owner without changing Realm colors"
    )
    var catalogue: RefCounted = WorldIdentityCatalogue.load_default()
    var label_specs: Dictionary[String, Dictionary] = PoliticalRealmLabels.build_specs(
        geography, owners, catalogue
    )
    _check(label_specs.size() == 43, "one political label is specified per starting Realm")
    for realm_id: String in label_specs:
        var identity: Dictionary = catalogue.get_realm_identity(StringName(realm_id))
        var display_value: Variant = identity["display_name"]
        var expected_name: String = (
            String(display_value) if display_value != null else String(identity["realm_name"])
        )
        _check(label_specs[realm_id]["name"] == expected_name, "Realm %s uses canonical display name" % realm_id)
        _check(
            owners[label_specs[realm_id]["anchor_province_id"]] == realm_id,
            "Realm %s label sits on currently owned land" % realm_id
        )
    var transferred_owners: Dictionary[int, String] = owners.duplicate()
    var single_province_id: int = catalogue.get_starting_province_ids_for_realm(&"R001")[0]
    transferred_owners[single_province_id] = "R002"
    var transferred_specs: Dictionary[String, Dictionary] = PoliticalRealmLabels.build_specs(
        geography, transferred_owners, catalogue
    )
    _check(transferred_specs.size() == 42 and not transferred_specs.has("R001"), "landless Realm label disappears")
    _check(
        transferred_owners[transferred_specs["R002"]["anchor_province_id"]] == "R002",
        "recipient label anchor reflects transferred territory"
    )
    _check(
        PoliticalRealmLabels.font_size_for_zoom(30000.0)
        < PoliticalRealmLabels.font_size_for_zoom(3600.0),
        "continent labels scale down from gameplay zoom"
    )
    var session: CampaignSession = _canonical_session(catalogue)
    _check(session != null and gameplay.bind_campaign_session(session), "live campaign ownership can be bound")
    if session != null:
        var captured_id: int = -1
        var target_realm: String = ""
        for province_id: int in geography.get_province_ids():
            var starting_owner: String = session.get_province(province_id).owner_realm_id
            var holdings: PackedInt32Array = catalogue.get_starting_province_ids_for_realm(StringName(starting_owner))
            if holdings.size() > 1 and province_id != holdings[0]:
                captured_id = province_id
                target_realm = "R001" if starting_owner != "R001" else "R002"
                break
        _check(captured_id > 0, "fixture has a safe non-capital Province to capture")
        if captured_id > 0:
            var capture_result: Dictionary = session.capture(captured_id, target_realm)
            _check(capture_result["ok"], "campaign capture publishes current ownership")
            var live_owners: Dictionary[int, String] = gameplay._current_owners()
            _check(live_owners[captured_id] == target_realm, "map reads committed ProvinceState owner")
            province_colors = political.refresh_ownership(geography, live_owners)
            _check(province_colors[captured_id] == colors[target_realm], "captured Province takes its new Realm color")
            var live_specs: Dictionary[String, Dictionary] = PoliticalRealmLabels.build_specs(
                geography, live_owners, catalogue, session
            )
            for realm_id: String in live_specs:
                _check(
                    live_owners[live_specs[realm_id]["anchor_province_id"]] == realm_id,
                    "live Realm %s label follows current territory" % realm_id
                )
            var formable_id: StringName = catalogue.get_formable_ids()[0]
            var form_result: Dictionary = session.form(target_realm, String(formable_id))
            _check(form_result["ok"], "current political identity can change")
            var formable: Dictionary = catalogue.get_formable(formable_id)
            var formable_display: Variant = formable.get("display_name")
            var expected_formable_name: String = (
                String(formable_display) if formable_display != null
                else String(formable["formable_name"])
            )
            live_specs = PoliticalRealmLabels.build_specs(geography, live_owners, catalogue, session)
            _check(
                live_specs[target_realm]["name"] == expected_formable_name,
                "Realm label follows current formable display identity"
            )
    var mask: Image = Image.load_from_file(
        ProjectSettings.globalize_path(PoliticalMapPresentation.MASK_PATH)
    )
    _check(mask.get_size() == Vector2i(4096, 2304), "Province mask matches world raster")
    for province_id: int in geography.get_province_ids():
        var center: Vector2 = geography.get_province_record(province_id)["selection_point"]
        var pixel: Vector2i = Vector2i((center - WORLD_ORIGIN) / SAMPLE_SPACING)
        var sampled_id: int = roundi(mask.get_pixelv(pixel).r * 255.0)
        _check(sampled_id == province_id, "Province %d mask anchor resolves" % province_id)
    gameplay.free()
    if _failures == 0:
        print("Political map mode test PASS: ownership, colors, adjacency and mask.")
    else:
        push_error("Political map mode test FAIL: %d checks." % _failures)
    quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)


func _canonical_session(catalogue: RefCounted) -> CampaignSession:
    var realms: Array[RealmState] = []
    var characters: Array[CharacterState] = []
    var dynasties: Array[DynastyState] = []
    for realm_id: StringName in catalogue.get_realm_ids():
        var realm: RealmState = RealmState.new()
        realm.realm_id = String(realm_id)
        realm.capital_province_id = catalogue.get_starting_province_ids_for_realm(realm_id)[0]
        realm.current_ruler_id = "political_fixture_ruler_" + String(realm_id)
        realm.legitimacy = "fixture_recognized"
        var capital_identity: Dictionary = catalogue.get_province_identity(realm.capital_province_id)
        realm.official_culture = capital_identity["culture"]
        realm.official_religion = capital_identity["religion"].duplicate(true)
        realms.append(realm)
        var dynasty: DynastyState = DynastyState.new()
        dynasty.dynasty_id = "political_fixture_house_" + String(realm_id)
        dynasty.house_name = "Political Fixture " + String(realm_id)
        dynasties.append(dynasty)
        var character: CharacterState = CharacterState.new()
        character.character_id = realm.current_ruler_id
        character.display_name = "Political Fixture Ruler " + String(realm_id)
        character.dynasty_id = dynasty.dynasty_id
        character.realm_id = String(realm_id)
        characters.append(character)
    var result: Dictionary = CampaignBootstrap.from_world(realms, characters, dynasties, "R028")
    if result["state"] == null:
        return null
    return CampaignSession.create(result["state"])["session"]
