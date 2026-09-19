extends CampaignTestSuite

var _world: CampaignStartWorld
var _cast: Dictionary


func _initialize() -> void:
    _world = CampaignStartWorld.new()
    check(_world.errors.is_empty(), "canonical generation authority loads")
    var generator: CampaignStartGenerator = CampaignStartGenerator.new(_world)
    var result: Dictionary = generator.generate("For Carrot and Honour / v1", 365)
    check(result["cast"] != null, "complete generator succeeds: " + str(result["errors"]))
    if result["cast"] == null:
        finish("Campaign start")
        return
    _cast = result["cast"]
    print("V1 cast digest: ", canonical(CampaignStartFixture.wire(_cast)).sha256_text())
    check(canonical(CampaignStartFixture.wire(_cast)).sha256_text() == "7b025d69d906c30e3c427cd45df3108584a5f46f5cafbe912437ae62cb14317c", "version 1 golden cast guards engine/order/random drift")
    _integration(generator)
    _schema()
    _reject_mutations()
    _naming()
    _additional_family_edges()
    _retries(generator)
    finish("Campaign start")


func _integration(generator: CampaignStartGenerator) -> void:
    var again: Dictionary = generator.generate(_cast["campaign_seed"], 365)
    check(canonical(CampaignStartFixture.wire(again["cast"])) == canonical(CampaignStartFixture.wire(_cast)), "same inputs produce byte-identical complete cast")
    check(canonical(CampaignStartFixture.wire(generator.generate("different", 365)["cast"])) != canonical(CampaignStartFixture.wire(_cast)), "different seed changes cast")
    check(canonical(CampaignStartFixture.wire(generator.generate(_cast["campaign_seed"], 360)["cast"])) != canonical(CampaignStartFixture.wire(_cast)), "year configuration affects reproducibility")
    var other_world: CampaignStartWorld = CampaignStartWorld.new()
    other_world.binding = "alternate-test-authority".sha256_text()
    var rebound: Dictionary = CampaignStartGenerator.new(other_world).generate(_cast["campaign_seed"], 365)
    check(rebound["cast"] != null and canonical(CampaignStartFixture.wire(rebound["cast"])) != canonical(CampaignStartFixture.wire(_cast)), "world binding participates in complete cast determinism")
    check(CampaignBootstrap.from_generated(rebound["cast"])["state"] == null, "foreign world cast cannot enter canonical bootstrap")
    var first: Dictionary = CampaignBootstrap.from_generated(_cast, "R001")
    var second: Dictionary = CampaignBootstrap.from_generated(_cast, "R043")
    check(first["state"] != null and second["state"] != null, "validated cast bootstraps for either player: " + str(first["errors"]))
    if first["state"] == null or second["state"] == null:
        return
    var state: CampaignState = first["state"]
    var data: Dictionary = second["state"].to_data()
    data["player_realm_id"] = "R001"
    check(canonical(state.to_data()) == canonical(data), "player choice changes only player reference")
    check(state.provinces.size() == 100 and state.realms.size() == 43 and state.relationships.size() == 903 and state.wars.is_empty(), "bootstrap creates only canonical geography and neutral pairs")
    check(state.realms["R008"].recognized_heir_id == "" and state.realms["R008"].succession_law_id == "elected_office", "Seravelle elected-office exception")
    check(state.realms["R028"].capital_province_id == 16 and state.provinces[30].local_culture == "Carthen", "R028 Seat and Carthen enclave preserved")
    var restored: Dictionary = CampaignCodec.decode_json(canonical(state.to_data()))
    check(restored["state"] != null and canonical(restored["state"].to_data()) == canonical(state.to_data()), "complete generated save round trip")
    var path: String = "res://.godot/test_logs/generated_campaign.json"
    check(CampaignCodec.save_file(state, path).is_empty(), "generated save writes and verifies")
    var loaded: Dictionary = CampaignCodec.load_file(path)
    check(loaded["state"] != null and canonical(loaded["state"].to_data()) == canonical(state.to_data()), "generated disk load does not regenerate")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var session: CampaignSession = CampaignSession.create(state)["session"]
    check(session != null, "generated campaign enters existing atomic session")
    var ruler_a: String = state.realms["R001"].current_ruler_id
    var ruler_b: String = state.realms["R002"].current_ruler_id
    ok(session.succeed("R002", ruler_a, "later_union"), "permanent validator permits later personal union")
    ok(session.link_partners(ruler_a, ruler_b), "permanent validator permits later foreign marriage")
    check(CampaignCodec.decode_data(session.export_data())["state"] != null, "later states remain saveable")
    var clock: SimulationClock = SimulationClock.new(1, 1, 30)
    var child: CharacterState = CharacterState.new()
    child.birth_tick = -365 + 1
    check(child.age_years(clock.get_elapsed_daily_ticks(), 365) == 0, "age before birthday")
    clock.advance_day()
    check(child.age_years(clock.get_elapsed_daily_ticks(), 365) == 1, "clock daily tick advances derived age")
    check(SimulationClock.create_from_state(clock.export_state()).get_elapsed_daily_ticks() == 1, "clock remains independently restorable")
    check(CampaignBootstrap.from_generated(_cast, "unknown")["state"] == null, "invalid player choice fails bootstrap")
    var production: Dictionary = CampaignBootstrap.new_cast_campaign("api-entry", 360, "R008")
    check(production["state"] != null, "explicit cast-only creation entry point preserves cast v1")


func _schema() -> void:
    var state: CampaignState = CampaignBootstrap.from_generated(_cast)["state"]
    var valid: Dictionary = state.to_data()
    for entry: Array in [["campaign_seed", ""], ["campaign_seed", 123], ["generator_version", 0], ["generator_version", 1.5], ["days_per_year", 0], ["days_per_year", -1], ["days_per_year", 365.5]]:
        var data: Dictionary = valid.duplicate(true)
        data[entry[0]] = entry[1]
        invalid(data, "strict provenance field " + entry[0])
    for entry: Array in [["sex", "unknown"], ["birth_tick", -1.5], ["birth_tick", "-100"], ["birth_tick", 9007199254740992.0]]:
        var data: Dictionary = valid.duplicate(true)
        data["characters"][0][entry[0]] = entry[1]
        invalid(data, "strict character field " + entry[0])
    for field: String in ["given_name", "sex", "birth_tick"]:
        var data: Dictionary = valid.duplicate(true)
        data["characters"][0].erase(field)
        invalid(data, "missing character field " + field)
    for field: String in ["age_years", "children_ids", "display_name"]:
        var data: Dictionary = valid.duplicate(true)
        data["characters"][0][field] = "obsolete"
        invalid(data, "obsolete/redundant field " + field)
    for field: String in ["campaign_seed", "generator_version", "days_per_year"]:
        var data: Dictionary = valid.duplicate(true)
        data.erase(field)
        invalid(data, "missing provenance field " + field)
    var bad_style: Dictionary = valid.duplicate(true)
    bad_style["dynasties"][0]["lineage_style"] = "territory"
    invalid(bad_style, "invalid lineage presentation enum")
    var old_house: Dictionary = valid.duplicate(true)
    old_house["dynasties"][0]["house_name"] = "old"
    invalid(old_house, "obsolete House field rejected")
    var whitespace_seed: Dictionary = valid.duplicate(true)
    whitespace_seed["campaign_seed"] = "  seed\n🥕  "
    check(CampaignCodec.decode_json(canonical(whitespace_seed))["state"].campaign_seed == whitespace_seed["campaign_seed"], "seed is opaque, never trimmed or coerced")


func _reject_mutations() -> void:
    for field_value: Array in [["current_ruler_id", "missing"], ["recognized_heir_id", "missing"], ["capital_province_id", 37], ["official_culture", "Carthen"], ["succession_law_id", "elected_office"], ["legitimacy", "legitimate"], ["carrots", 1]]:
        var cast: Dictionary = CampaignStartFixture.clone(_cast)
        cast["realm_setups"][0].set(field_value[0], field_value[1])
        _reject(cast, "Realm rule " + field_value[0])
    var union: Dictionary = CampaignStartFixture.clone(_cast)
    union["realm_setups"][1].current_ruler_id = union["realm_setups"][0].current_ruler_id
    _reject(union, "personal union")
    var holy: Dictionary = CampaignStartFixture.clone(_cast)
    holy["realm_setups"][7].recognized_heir_id = holy["realm_setups"][0].current_ruler_id
    _reject(holy, "Seravelle heir")
    holy = CampaignStartFixture.clone(_cast)
    holy["realm_setups"][7].succession_law_id = "eldest_legitimate_child"
    _reject(holy, "Seravelle law")
    for entry: Array in [["alive", false], ["birth_tick", -17 * 365], ["birth_tick", -86 * 365], ["birth_tick", 1], ["given_name", "Inventedname"], ["realm_id", "R043"]]:
        var cast: Dictionary = CampaignStartFixture.clone(_cast)
        cast["character_setups"][0].set(entry[0], entry[1])
        _reject(cast, "ruler field " + entry[0])
    var traits: Dictionary = CampaignStartFixture.clone(_cast)
    traits["character_setups"][0].traits.append("invented")
    _reject(traits, "deferred traits")
    for entry: Array in [["lineage_style", "clan"], ["lineage_name", "Inventedlineage"], ["parent_dynasty_id", "missing"]]:
        var cast: Dictionary = CampaignStartFixture.clone(_cast)
        cast["dynasty_setups"][0].set(entry[0], entry[1])
        _reject(cast, "lineage field " + entry[0])
    var duplicate: Dictionary = CampaignStartFixture.clone(_cast)
    duplicate["dynasty_setups"][1].lineage_name = duplicate["dynasty_setups"][0].lineage_name
    _reject(duplicate, "duplicate lineage name")
    duplicate = CampaignStartFixture.clone(_cast)
    duplicate["character_setups"].append(duplicate["character_setups"][0])
    _reject(duplicate, "duplicate Character ID")
    var missing: Dictionary = CampaignStartFixture.clone(_cast)
    missing["realm_setups"].pop_back()
    _reject(missing, "missing Realm")
    # Target an actual child and marriage rather than assuming a seed's array shape.
    for original: RealmState in _cast["realm_setups"]:
        if original.recognized_heir_id.is_empty():
            continue
        for mutation: String in ["dead_child", "young_parent", "missing_parent", "wrong_lineage", "wrong_identity", "wrong_heir", "asymmetric", "foreign", "child_spouse", "ancestry_cycle"]:
            var cast: Dictionary = CampaignStartFixture.clone(_cast)
            var chars: Dictionary = CampaignStartFixture.characters(cast)
            var ruler: CharacterState = chars[original.current_ruler_id]
            var child: CharacterState = chars[original.recognized_heir_id]
            var spouse: CharacterState = chars[ruler.partner_ids[0]]
            match mutation:
                "dead_child": child.alive = false
                "young_parent": child.birth_tick = ruler.birth_tick + 15 * 365
                "missing_parent": child.parent_ids = [ruler.character_id]
                "wrong_lineage": child.dynasty_id = spouse.dynasty_id
                "wrong_identity": child.personal_religion = StateSchema.empty_religion()
                "wrong_heir":
                    for realm: RealmState in cast["realm_setups"]:
                        if realm.realm_id == original.realm_id:
                            realm.recognized_heir_id = ""
                "asymmetric": spouse.partner_ids.clear()
                "foreign": spouse.realm_id = "R043" if ruler.realm_id != "R043" else "R001"
                "child_spouse":
                    spouse.alive = true
                    spouse.birth_tick = -17 * 365
                "ancestry_cycle": ruler.parent_ids = [child.character_id]
            _reject(cast, mutation)
        break


func _reject(cast: Dictionary, label: String) -> void:
    check(not CampaignStartValidator.validate(cast, _world).is_empty(), "Day-1 rejects " + label)


func _naming() -> void:
    var names: CampaignStartNames = _world.names
    check(CampaignStartNames.affinity({"primary": ["Haldren"], "rare": ["Velaine"]}, "Haldren") == 5, "Primary weight 5")
    check(CampaignStartNames.affinity({"primary": ["Haldren"], "rare": ["Velaine"]}, "Velaine") == 1, "Rare weight 1")
    check(CampaignStartNames.affinity({"primary": ["Haldren"], "rare": ["Velaine"]}, "Brevane") == 3, "Shared weight 3")
    for family: String in names.data["families"]:
        var culture: String = names.data["families"][family]["cultures"][0]
        var used: Dictionary = {}
        var random: CampaignStartRandom = CampaignStartRandom.new("pool-test")
        for index: int in names.entries(culture, "lineage").size():
            var value: String = names.lineage_name(culture, used, random)
            check(not value.is_empty() and not used.has(value), "unique pool allocation " + family)
            used[value] = true
        check(names.lineage_name(culture, used, random).is_empty(), "pool exhaustion returns explicit failure " + family)
    check(names.style("Kharven", true) == "clan" and names.style("Kharven", false) == "clan", "Kharven public clan convention")
    check(names.style("Averi", true) == "dynasty" and names.style("Averi", false) == "house", "Eastern role-based public style")
    var random: CampaignStartRandom = CampaignStartRandom.new("overlay-frequency")
    var soft: int = 0
    var natural: int = 0
    var conspicuous: int = 0
    for index: int in 30000:
        var name: String = names.given_name("Haldren", "female", random)
        if name in CampaignStartNames.SOFT_NAMES:
            soft += 1
            if CampaignStartNames.SOFT_NAMES.find(name) < 6:
                natural += 1
            else:
                conspicuous += 1
    check(soft > 2100 and soft < 2700, "8 percent overlay controls frequency even for regional soft entries")
    check(natural > conspicuous * 2.5 and natural < conspicuous * 3.5, "conspicuous overlay names have one-third weight")


func _additional_family_edges() -> void:
    var cast: Dictionary = CampaignStartFixture.clone(_cast)
    cast["character_setups"][0].parent_ids.assign([
        cast["character_setups"][1].character_id, cast["character_setups"][2].character_id,
        cast["character_setups"][3].character_id])
    _reject(cast, "more than two actual parents")
    cast = CampaignStartFixture.clone(_cast)
    cast["dynasty_setups"][0].parent_dynasty_id = cast["dynasty_setups"][1].dynasty_id
    cast["dynasty_setups"][1].parent_dynasty_id = cast["dynasty_setups"][0].dynasty_id
    _reject(cast, "cadet ancestry cycle")
    cast = CampaignStartFixture.clone(_cast)
    cast["character_setups"][0].character_id = "ruler_R001_named"
    _reject(cast, "semantic/malformed generated ID")
    var saw_children: bool = false
    for realm: RealmState in _cast["realm_setups"]:
        var children: Array[CharacterState] = []
        for child: CharacterState in _cast["character_setups"]:
            if realm.current_ruler_id in child.parent_ids:
                children.append(child)
        if children.size() < 2 or realm.realm_id == "R008":
            continue
        saw_children = true
        children.sort_custom(CampaignStartValidator.birth_order)
        cast = CampaignStartFixture.clone(_cast)
        for changed_realm: RealmState in cast["realm_setups"]:
            if changed_realm.realm_id == realm.realm_id:
                changed_realm.recognized_heir_id = children[-1].character_id
        _reject(cast, "younger child cannot displace oldest heir")
        # Same-tick siblings: deterministically choose smallest opaque ID.
        var chars: Dictionary = CampaignStartFixture.characters(cast)
        var sibling_ids: Array[String] = []
        for child: CharacterState in children:
            chars[child.character_id].birth_tick = children[0].birth_tick
            sibling_ids.append(child.character_id)
        sibling_ids.sort()
        for changed_realm: RealmState in cast["realm_setups"]:
            if changed_realm.realm_id == realm.realm_id:
                changed_realm.recognized_heir_id = sibling_ids[0]
        check(CampaignStartValidator.validate(cast, _world).is_empty(), "same-tick siblings have deterministic heir tie break")
        break
    check(saw_children, "fixture covers competing children")
    var generator: CampaignStartGenerator = CampaignStartGenerator.new(_world)
    var saw_remarriage: bool = false
    for index: int in 40:
        cast = generator.generate("remarriage/" + str(index), 365)["cast"]
        var chars: Dictionary = CampaignStartFixture.characters(cast)
        for realm: RealmState in cast["realm_setups"]:
            var ruler: CharacterState = chars[realm.current_ruler_id]
            if ruler.partner_ids.size() != 2:
                continue
            saw_remarriage = true
            var spouse_a: CharacterState = chars[ruler.partner_ids[0]]
            var spouse_b: CharacterState = chars[ruler.partner_ids[1]]
            check(spouse_a.alive != spouse_b.alive, "remarriage uses one current and one deceased real spouse")
            spouse_a.alive = true
            spouse_b.alive = true
            _reject(cast, "two living spouses")
            spouse_a.alive = false
            spouse_b.alive = false
            _reject(cast, "two deceased spouses cannot represent remarried v1 start")
            break
        if saw_remarriage:
            break
    check(saw_remarriage, "fixture covers remarriage")


func _retries(generator: CampaignStartGenerator) -> void:
    for args: Array in [["", 365, 1, 64], ["seed", 0, 1, 64], ["seed", 365, 2, 64], ["seed", 365, 1, 0], ["seed", 365, 1, 65]]:
        var bad: Dictionary = generator.generate(args[0], args[1], args[2], args[3])
        check(bad["cast"] == null and bad["attempts"] == 0 and not bad["errors"].is_empty(), "invalid configuration fails loudly before attempts")
    var found: bool = false
    for index: int in 200:
        var seed: String = "retry-" + str(index)
        var raw: Dictionary = generator.generate_attempt(seed, 365, 0)
        if CampaignStartValidator.validate(raw, _world).is_empty() and not CampaignStartValidator.soft_sanity(raw).is_empty():
            var exhausted: Dictionary = generator.generate(seed, 365, 1, 1)
            check(exhausted["cast"] == null and exhausted["attempts"] == 1 and exhausted["rejections"][0]["category"] == "soft", "bounded failure retains soft reason")
            var accepted: Dictionary = generator.generate(seed, 365)
            var again: Dictionary = generator.generate(seed, 365)
            check(accepted["cast"] != null and accepted["attempts"] > 1, "deterministic retry reaches valid world")
            check(accepted["rejections"] == again["rejections"] and canonical(CampaignStartFixture.wire(accepted["cast"])) == canonical(CampaignStartFixture.wire(again["cast"])), "retry diagnostics and accepted cast repeat exactly")
            print("Deterministic soft retry seed: ", seed, "; attempts: ", accepted["attempts"])
            found = true
            break
    check(found, "sample exercises real soft rejection")
    var depleted: CampaignStartWorld = CampaignStartWorld.new()
    for family: String in depleted.names.data["families"]:
        depleted.names.data["families"][family]["lineage"] = []
    var exhausted: Dictionary = CampaignStartGenerator.new(depleted).generate("exhausted", 365, 1, 2)
    check(exhausted["cast"] == null and exhausted["attempts"] == 2 and exhausted["rejections"].size() == 2 and exhausted["rejections"][0]["category"] == "hard", "bounded hard failure never invents or reuses lineages")
