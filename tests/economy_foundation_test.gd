extends CampaignTestSuite

var _base: CampaignState
var _config: EconomyConfig
var _generated: CampaignState
var _catalogue: EconomyCatalogue


func _initialize() -> void:
    _catalogue = EconomyCatalogue.new()
    _config = EconomyFixture.config()
    _base = CampaignBootstrap.new_cast_campaign("economy-focused", 365)["state"]
    check(_base != null, "cast fixture bootstraps")
    check(_catalogue.errors.is_empty(), "typed sealed catalogue loads")
    check(_catalogue.opportunities.size() == 26 and _catalogue.sites.size() == 32 and _catalogue.buildings.size() == 37, "complete family counts")
    check(_catalogue.random_buildings().size() == 13, "exact Day-1 pool size")
    check(_catalogue.sites["site_fishery"].source_id == "aquatic", "Fish retained outside generated opportunity pool")
    check(_catalogue.buildings["building_mill"].kind == "building" and not _catalogue.sites.has("site_mill"), "Mill is strategic, never rural")
    for id: String in ["stone", "timber", "firewood", "grain", "wool", "hides", "horse", "camel", "fish", "lead", "peat", "coal", "sulfur", "saltpeter", "ebony", "exotic_spices"]:
        check(not _catalogue.opportunities.has("opportunity_" + id), "no legacy/non-opportunity " + id)
    check("ordinary_stone" in _catalogue.background_access and "ordinary_timber" in _catalogue.background_access, "universal background defined once")
    check(EconomyConfig.load_default()["config"] == null, "canonical tuning remains explicitly incomplete")
    check(CampaignBootstrap.new_campaign("incomplete", 365)["state"] == null, "production refuses to guess incomplete canonical inputs")
    var result: Dictionary = EconomyGenerator.generate(_base, _config)
    check(result["state"] != null, "complete fixture economy generates: " + str(result["errors"]))
    if result["state"] == null:
        finish("Economy foundation")
        return
    _generated = result["state"]
    check(_base.economy_generation == null and _base.provinces.values()[0].economy == null, "generation never mutates input")
    print("Economy v1 fixture digest: ", canonical(EconomyFixture.economy_data(_generated)).sha256_text())
    check(canonical(EconomyFixture.economy_data(_generated)).sha256_text() == "5aba598b8eab515bf1986e9d5556398ddd5dfc2b4ef6152e3728104273a639a2", "economy v1 golden replay guard")
    _replay_and_domains()
    _config_rejections()
    _state_rejections()
    _repair_hiding_authored()
    _family_first()
    _persistence_and_lifecycle()
    _distribution_tables()
    finish("Economy foundation")


func _replay_and_domains() -> void:
    var replay: CampaignState = EconomyGenerator.generate(_base, _config)["state"]
    check(canonical(replay.to_data()) == canonical(_generated.to_data()), "complete replay including provenance")
    check(EconomyGenerator.generate(_generated, _config)["state"] == null, "initialized economy cannot regenerate")
    var base_data: Dictionary = _base.to_data()
    var output: Dictionary = _generated.to_data()
    for key: String in ["characters", "dynasties", "realms", "relationships", "wars"]:
        check(base_data[key] == output[key], "economy leaves " + key + " untouched")
    for domain: String in ["buildings", "sites", "hiding", "opportunities"]:
        var changed: EconomyConfig = EconomyConfig.from_data(_config.to_data())
        changed.domain_versions[domain] += 1
        var other: CampaignState = EconomyGenerator.generate(_base, changed)["state"]
        check(other != null, "domain version variant generates")
        if other == null:
            continue
        if domain == "buildings":
            check(canonical(EconomyFixture.economy_data(other, ["opportunities", "sites"])) == canonical(EconomyFixture.economy_data(_generated, ["opportunities", "sites"])), "building RNG leaves resources/hiding/sites unchanged")
        if domain == "sites":
            check(canonical(EconomyFixture.economy_data(other, ["opportunities", "buildings"])) == canonical(EconomyFixture.economy_data(_generated, ["opportunities", "buildings"])), "site RNG leaves resources/hiding/buildings unchanged")
        check(other.to_data()["characters"] == base_data["characters"], "economy RNG never perturbs cast")
    var reordered: Dictionary = _config.to_data()
    reordered["geography"].reverse()
    reordered["rare_opportunity_ids"].reverse()
    check(canonical(EconomyGenerator.generate(_base, EconomyConfig.from_data(reordered))["state"].to_data()) == canonical(_generated.to_data()), "config dictionary/array ordering cannot introduce nondeterminism")
    var powerhouse: EconomyConfig = EconomyConfig.from_data(_config.to_data())
    powerhouse.powerhouse_realm_ids.assign(_base.realms.keys())
    var tiered: CampaignState = EconomyGenerator.generate(_base, powerhouse)["state"]
    check(canonical(EconomyFixture.economy_data(tiered, ["opportunities", "sites"])) == canonical(EconomyFixture.economy_data(_generated, ["opportunities", "sites"])), "Powerhouse affects only buildings")
    for id: int in tiered.provinces:
        var original: Array[EconomyInstance] = _generated.provinces[id].economy.buildings
        var changed_buildings: Array[EconomyInstance] = tiered.provinces[id].economy.buildings
        for index: int in mini(original.size(), changed_buildings.size()):
            check(original[index].to_data() == changed_buildings[index].to_data(), "Powerhouse changes count only, not the type draw sequence")
    var changed_geography: EconomyConfig = EconomyConfig.from_data(_config.to_data())
    for entry: Dictionary in changed_geography.geography:
        entry["coast"] = true
        entry["aquatic"] = true
    var coastal: CampaignState = EconomyGenerator.generate(_base, changed_geography)["state"]
    check(canonical(EconomyFixture.economy_data(coastal, ["opportunities"])) == canonical(EconomyFixture.economy_data(_generated, ["opportunities"])), "fixed geography cannot weight resources or hiding")
    var changed_cast: CampaignState = _base.copy()
    changed_cast.characters.values()[0].given_name = "Different cast-domain outcome"
    changed_cast.player_realm_id = "R043"
    var independent: CampaignState = EconomyGenerator.generate(changed_cast, _config)["state"]
    check(canonical(EconomyFixture.economy_data(independent)) == canonical(EconomyFixture.economy_data(_generated)), "cast/naming outcome and player choice do not affect economy")
    var moved_seat: CampaignState = _base.copy()
    for province: ProvinceState in moved_seat.provinces.values():
        moved_seat.realms[province.owner_realm_id].capital_province_id = province.province_id
    var relocated: CampaignState = EconomyGenerator.generate(moved_seat, _config)["state"]
    check(canonical(EconomyFixture.economy_data(relocated)) == canonical(EconomyFixture.economy_data(_generated)), "no capital bonus or weighting in any economy domain")
    for slots: int in [8, 10, 12]:
        var capacity: EconomyConfig = EconomyConfig.from_data(_config.to_data())
        capacity.strategic_slots = slots
        var sized: CampaignState = EconomyGenerator.generate(_base, capacity)["state"]
        check(sized != null and canonical(EconomyFixture.economy_data(sized)) == canonical(EconomyFixture.economy_data(_generated)), "capacity comparison %d does not change starting state" % slots)
    var api: Dictionary = CampaignBootstrap.new_campaign("economy-api", 360, "R008", _config)
    check(api["state"] != null, "full bootstrap entry point accepts explicit fixture config: " + str(api["errors"]))


func _config_rejections() -> void:
    var valid: Dictionary = _config.to_data()
    for entry: Array in [["hidden_chance_bp", 10001], ["hidden_chance_bp", 1.5], ["anti_cluster_penalty_bp", 10000], ["strategic_slots", 2], ["status", "incomplete"], ["config_version", 0], ["opportunity_weights", {}], ["authored_sites", null]]:
        var data: Dictionary = valid.duplicate(true)
        data[entry[0]] = entry[1]
        check(not EconomyConfig.validate_data(data, _catalogue).is_empty(), "reject invalid config " + entry[0])
    for field: String in valid:
        var data: Dictionary = valid.duplicate(true)
        data.erase(field)
        check(not EconomyConfig.validate_data(data, _catalogue).is_empty(), "reject missing config " + field)
    var bad: Dictionary = valid.duplicate(true)
    bad["opportunity_weights"]["opportunity_stone"] = 1
    check(not EconomyConfig.validate_data(bad, _catalogue).is_empty(), "unknown resource weights rejected")
    bad = valid.duplicate(true)
    bad["geography"].append(bad["geography"][0])
    check(not EconomyConfig.validate_data(bad, _catalogue).is_empty(), "duplicate fixed geography rejected")
    bad = valid.duplicate(true)
    bad["authored_buildings"] = [EconomyFixture.authored(1, "building_market"), EconomyFixture.authored(1, "building_market")]
    check(not EconomyConfig.validate_data(bad, _catalogue).is_empty(), "duplicate mandatory type rejected")
    var config: EconomyConfig = EconomyConfig.from_data(valid)
    config.powerhouse_realm_ids = ["unknown"]
    check(EconomyGenerator.generate(_base, config)["state"] == null, "unknown Powerhouse ID rejected")
    config = EconomyConfig.from_data(valid)
    config.geography.pop_back()
    check(EconomyGenerator.generate(_base, config)["state"] == null, "missing geography binding cannot default to false")


func _state_rejections() -> void:
    var valid: Dictionary = _generated.to_data()
    for entry: Array in [["generator_version", 2], ["content_version", 2], ["content_hash", "wrong"], ["config_hash", "wrong"], ["config", null]]:
        var data: Dictionary = valid.duplicate(true)
        data["economy_generation"][entry[0]] = entry[1]
        invalid(data, "reject corrupt economy provenance " + entry[0])
    var data: Dictionary = valid.duplicate(true)
    data["provinces"][0]["economy"] = null
    invalid(data, "reject partial initialized economy")
    data = valid.duplicate(true)
    data["economy_generation"] = null
    invalid(data, "reject missing provenance")
    data = valid.duplicate(true)
    data["provinces"][0]["economy"]["hidden"] = false
    invalid(data, "reject unknown economy fields")
    data = valid.duplicate(true)
    data["provinces"][0]["economy"]["opportunities"] = [null]
    invalid(data, "reject null opportunity before construction")
    data = valid.duplicate(true)
    data["provinces"][0]["economy"]["opportunities"] = [{"type_id": "opportunity_stone", "known_realm_ids": []}]
    invalid(data, "reject legacy Stone opportunity")
    for province: Dictionary in valid["provinces"]:
        if province["economy"]["opportunities"].is_empty():
            continue
        data = valid.duplicate(true)
        var index: int = valid["provinces"].find(province)
        data["provinces"][index]["economy"]["opportunities"].append(province["economy"]["opportunities"][0])
        invalid(data, "duplicate opportunity rejected")
        data = valid.duplicate(true)
        data["provinces"][index]["economy"]["opportunities"][0]["known_realm_ids"] = ["unknown"]
        invalid(data, "unknown knowledge Realm rejected")
        break
    var instance: Dictionary = {}
    for province: Dictionary in valid["provinces"]:
        if not province["economy"]["buildings"].is_empty():
            instance = province["economy"]["buildings"][0]
            break
    for field: String in instance:
        data = valid.duplicate(true)
        var bad_instance: Dictionary = instance.duplicate(true)
        bad_instance.erase(field)
        data["provinces"][0]["economy"]["buildings"] = [bad_instance]
        invalid(data, "missing instance field " + field)
    data = valid.duplicate(true)
    data["provinces"][0]["economy"]["buildings"] = [instance, instance]
    invalid(data, "duplicate physical ID/type rejected")


func _repair_hiding_authored() -> void:
    var config: EconomyConfig = EconomyConfig.from_data(_config.to_data())
    config.hidden_chance_bp = 10000
    for id: String in config.opportunity_weights:
        config.opportunity_weights[id] = 0
    for id: String in ["opportunity_gold", "opportunity_clay", "opportunity_vine"]:
        config.opportunity_weights[id] = 1
    var generated: CampaignState = EconomyGenerator.generate(_base, config)["state"]
    check(generated != null, "zero-weight essentials repaired under 100% hiding")
    if generated == null:
        return
    var totals: Dictionary = EconomyRules.totals(generated)
    var visible: Dictionary = EconomyRules.totals(generated, true)
    check(totals["opportunity_fertile_land"] == 5 and totals["opportunity_iron"] == 2, "repair is floor, not overshooting quota")
    check(visible["opportunity_fertile_land"] >= 4 and visible["opportunity_iron"] >= 1, "visible floors survive aggressive hiding")
    var filled: CampaignState = _base.copy()
    for province: ProvinceState in filled.provinces.values():
        province.economy = ProvinceEconomy.new()
        for id: String in ["opportunity_gold", "opportunity_clay", "opportunity_vine"]:
            EconomyGenerator._add_opportunity(province, id)
    var world: EconomyWorld = EconomyWorld.new(filled, config)
    check(EconomyGenerator.repair(filled, config, world).is_empty(), "all-full repair replaces instead of adding a fourth")
    for province: ProvinceState in filled.provinces.values():
        check(province.economy.opportunities.size() == 3, "all-full repair preserves capacity")
    var target_id: int = -1
    var source_id: String = ""
    var site_id: String = ""
    for province: ProvinceState in _generated.provinces.values():
        if not province.economy.opportunities.is_empty():
            target_id = province.province_id
            source_id = province.economy.opportunities[0].type_id
            for definition: EconomyDefinition in _catalogue.sites.values():
                if definition.source_id == source_id:
                    site_id = definition.definition_id
                    break
            break
    config = EconomyConfig.from_data(_config.to_data())
    config.hidden_chance_bp = 10000
    config.authored_sites = [EconomyFixture.authored(target_id, site_id)]
    config.authored_buildings = [EconomyFixture.authored(target_id, "building_cathedral"), EconomyFixture.authored(target_id, "building_palace"), EconomyFixture.authored(target_id, "building_market")]
    var authored_result: Dictionary = EconomyGenerator.generate(_base, config)
    check(authored_result["state"] != null, "explicit fixture-authored starts succeed: " + str(authored_result["errors"]))
    if authored_result["state"] != null:
        var authored: ProvinceState = authored_result["state"].provinces[target_id]
        check(authored.economy.known(source_id, authored.owner_realm_id), "authored site source excluded from hiding")
        check(authored.economy.sites.size() == 1 and authored.economy.sites[0].origin == "authored", "authored site suppresses RNG")
        check(authored.economy.buildings.size() == 3, "mandatory buildings consume cap without compensation")
    config.authored_buildings.append(EconomyFixture.authored(target_id, "building_barracks"))
    check(EconomyGenerator.generate(_base, config)["state"] == null, "four authored starts fail without partial publication")
    config = EconomyConfig.from_data(_config.to_data())
    for province: ProvinceState in _generated.provinces.values():
        if province.economy.opportunity("opportunity_iron") == null:
            config.authored_sites = [EconomyFixture.authored(province.province_id, "site_iron_mine")]
            break
    check(EconomyGenerator.generate(_base, config)["state"] == null, "authored site cannot invent a convenient absent resource")


func _family_first() -> void:
    var province: ProvinceState = ProvinceState.from_data(_base.provinces.values()[0].to_data())
    province.economy = ProvinceEconomy.new()
    EconomyGenerator._add_opportunity(province, "opportunity_fertile_land")
    EconomyGenerator._add_opportunity(province, "opportunity_iron")
    var config: EconomyConfig = EconomyConfig.from_data(_config.to_data())
    for entry: Dictionary in config.geography:
        entry["coast"] = false
        entry["aquatic"] = false
    var world: EconomyWorld = EconomyWorld.new(_base, config)
    var families: Dictionary = EconomyGenerator.eligible_site_families(province, _catalogue, world)
    check(families.size() == 2 and families["opportunity_fertile_land"].size() == 6 and families["opportunity_iron"].size() == 1, "six crops receive one family ticket, like Iron")
    var random: CampaignStartRandom = CampaignStartRandom.new("family-first-fixture")
    var crops: int = 0
    var types: Dictionary = {}
    for index: int in 10000:
        var type_id: String = EconomyGenerator.choose_site(province, _catalogue, world, random)
        crops += int(type_id != "site_iron_mine")
        types[type_id] = int(types.get(type_id, 0)) + 1
    check(crops > 4700 and crops < 5300 and types.size() == 7, "family-first is approximately half crops, not six-sevenths")
    for id: String in types:
        if id != "site_iron_mine":
            check(types[id] > 700 and types[id] < 1000, "equal crop odds within the selected family")
    province.economy.opportunity("opportunity_fertile_land").known_realm_ids.clear()
    check(EconomyGenerator.eligible_site_families(province, _catalogue, world).size() == 1, "hidden family excluded")
    check(not EconomyRules.building_valid(_catalogue.buildings["building_mill"], province, world), "Mill cannot leak hidden Fertile Land")
    check(not EconomyRules.building_valid(_catalogue.buildings["building_harbour"], province, world), "Harbour cannot use inland geography")
    world.geography[province.province_id]["coast"] = true
    world.geography[province.province_id]["aquatic"] = true
    check(EconomyRules.building_valid(_catalogue.buildings["building_harbour"], province, world), "ordinary coast is sufficient without exceptional Natural Harbour")
    check(EconomyGenerator.eligible_site_families(province, _catalogue, world).has("aquatic"), "Fishery participates as one fixed-geography family")
    world.geography[province.province_id]["coast"] = false
    world.geography[province.province_id]["aquatic"] = false
    province.economy.opportunities.clear()
    check(EconomyGenerator.choose_site(province, _catalogue, world, random).is_empty(), "successful site roll without a family creates nothing")
    check(EconomyRules.building_valid(_catalogue.buildings["building_smithy"], province, world) and EconomyRules.building_valid(_catalogue.buildings["building_woodworks"], province, world), "basic smithing/carpentry uses background access")


func _persistence_and_lifecycle() -> void:
    var fixture_file: FileAccess = FileAccess.open("res://.godot/test_logs/economy_fixture.json", FileAccess.WRITE)
    fixture_file.store_string(JSON.stringify(_config.to_data(), "", true, true))
    fixture_file.close()
    var text: String = canonical(_generated.to_data())
    var loaded: Dictionary = CampaignCodec.decode_json(text)
    check(loaded["state"] != null and canonical(loaded["state"].to_data()) == text, "strict complete economy round trip")
    var path: String = "res://.godot/test_logs/economy_save.json"
    check(CampaignCodec.save_file(_generated, path).is_empty(), "atomic economy save")
    check(canonical(CampaignCodec.load_file(path)["state"].to_data()) == text, "load accepted state, never generate")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var old: Dictionary = _base.to_data()
    old["schema_version"] = 2
    old.erase("economy_generation")
    for province: Dictionary in old["provinces"]:
        province.erase("economy")
    invalid(old, "old schema rejected without explicit migration")
    var migrated: Dictionary = CampaignCodec.migrate_v2(old)
    check(migrated["state"] != null and canonical(migrated["state"].to_data()) == canonical(_base.to_data()), "explicit schema-2 migration preserves cast and leaves economy uninitialized")
    var session: CampaignSession = CampaignSession.create(_generated)["session"]
    var target: ProvinceState
    var item: EconomyInstance
    for province: ProvinceState in _generated.provinces.values():
        if not province.economy.sites.is_empty():
            target = province
            item = province.economy.sites[0]
            break
    check(target != null, "fixture has physical site for ownership/lifecycle checks")
    if target == null:
        return
    rejected(session, func() -> Dictionary: return session.transition_economy_instance(target.province_id, item.instance_id, "suspended"), "no manual suspension state")
    ok(session.transition_economy_instance(target.province_id, item.instance_id, "disrupted"), "physical site disrupted")
    var new_owner: String = "R001" if target.owner_realm_id != "R001" else "R002"
    var before: Dictionary = session.get_province(target.province_id).economy.to_data()
    ok(session.capture(target.province_id, new_owner), "conquest preserves physical economy")
    var after: ProvinceState = session.get_province(target.province_id)
    check(before["sites"] == after.economy.to_data()["sites"] and before["buildings"] == after.economy.to_data()["buildings"], "damage and historical variant survive conquest")
    var source: String = _catalogue.sites[item.type_id].source_id
    if source != "aquatic":
        check(after.economy.known(source, new_owner) and after.economy.known(source, target.owner_realm_id), "physical site reveals source to new owner and retains former knowledge")
    ok(session.transition_economy_instance(target.province_id, item.instance_id, "recovering"), "recovery transition")
    ok(session.transition_economy_instance(target.province_id, item.instance_id, "active"), "recovered site becomes active")
    check(CampaignCodec.decode_data(session.export_data())["state"] != null, "later ownership/damage state remains saveable")
    check(not EconomyStartValidator.validate(CampaignState.from_data(session.export_data())).is_empty(), "Day-1 rules remain separate from permanent validation")
    var expanded: CampaignState = _generated.copy()
    var later: ProvinceState = expanded.provinces.values()[0]
    later.economy.buildings.clear()
    for type_id: String in ["building_market", "building_storehouse", "building_barracks", "building_woodworks"]:
        var physical: EconomyInstance = EconomyGenerator._instance(expanded, _config, later, type_id, "buildings", "later", later.economy.buildings.size())
        later.economy.buildings.append(physical)
    check(CampaignValidator.validate_data(expanded.to_data()).is_empty(), "permanent state permits four later buildings within configured capacity")
    check(not EconomyStartValidator.validate(expanded).is_empty(), "same four-building state is intentionally illegal on Day 1")
    var original_variant: Dictionary = later.economy.buildings[0].to_data()
    later.local_culture = "Later culture"
    later.local_religion["rite_or_belief"] = "Later rite"
    check(CampaignCodec.decode_json(canonical(expanded.to_data()))["state"] != null and later.economy.buildings[0].to_data() == original_variant, "local identity change never reskins stored origin")


func _distribution_tables() -> void:
    check(EconomyGenerator.OPPORTUNITY_COUNTS == [20, 45, 30, 5], "sealed opportunity table")
    check(EconomyGenerator.NORMAL_COUNTS == [40, 40, 15, 5], "sealed Normal table")
    check(EconomyGenerator.POWERHOUSE_COUNTS == [20, 40, 30, 10], "sealed Powerhouse table")
    check(EconomyGenerator.SITE_CHANCE_BP == 400, "sealed independent 4% site roll")
    var total: int = 100000
    var counts: Array[int] = [0, 0, 0, 0]
    var random: CampaignStartRandom = CampaignStartRandom.new("economy-frequency-fixture")
    for index: int in total:
        counts[random.weighted(EconomyGenerator.OPPORTUNITY_COUNTS)] += 1
    for index: int in 4:
        check(absf(float(counts[index]) / total - float(EconomyGenerator.OPPORTUNITY_COUNTS[index]) / 100) < 0.008, "observed opportunity distribution is broad, not a quota")
