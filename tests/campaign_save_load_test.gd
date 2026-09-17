extends CampaignTestSuite


func _initialize() -> void:
    _round_trip()
    _corrupt_saves()
    finish("Campaign save/load")


func _round_trip() -> void:
    var session: CampaignSession = CampaignFixture.session()
    ok(session.add_claim("character", "rabbit_7", CampaignFixture.claim("personal", 407)), "personal claim fixture")
    ok(session.add_claim("dynasty", "house_oak", CampaignFixture.claim("house")), "dynasty claim fixture")
    ok(session.add_claim("realm", "R002", CampaignFixture.claim("political")), "Realm claim fixture")
    ok(session.link_partners("rabbit_7", "rabbit_90"), "family graph save fixture")
    var war: WarState = WarState.new()
    war.war_id = "war_save_700"
    war.attacker_realm_ids = ["R002"]
    war.defender_realm_ids = ["R900"]
    ok(session.register_war(war), "WarState save fixture")
    for entry: Array in [["province", 11], ["realm", "R002"], ["character", "rabbit_7"], ["dynasty", "house_oak"], ["relationship", "R002"]]:
        ok(session.record_memory(entry[0], entry[1], CampaignFixture.memory("Historical UTF-8 memory: forêt / König / 🥕"), "R900"), "save memory fixture")
    var attitude: Dictionary = StateSchema.neutral_attitude()
    attitude["trust"] = -7.0
    ok(session.set_attitude("R900", "R002", attitude), "asymmetric attitude fixture")
    check(session.get_relationship("R002", "R900").attitude_b_to_a["trust"] is int, "validated integral numbers normalize on publication")
    ok(session.capture(11, "R900"), "capture fixture capital")
    ok(session.capture(93, "R900"), "inactivate fixture Realm")
    ok(session.mark_deceased("rabbit_7"), "deceased/extinct fixture")
    var before: Dictionary = session.export_data()
    var result: Dictionary = CampaignCodec.decode_json(canonical(before))
    check(result["state"] != null, "JSON decode returns validated state: " + str(result["errors"]))
    if result["state"] == null:
        return
    var restored: CampaignState = result["state"]
    check(canonical(restored.to_data()) == canonical(before), "JSON round-trip exactly preserves authoritative identities/references/values")
    var loaded: CampaignSession = CampaignSession.create(restored)["session"]
    check(loaded.get_province(407).province_id == 407 and loaded.get_province(88) == null, "sparse and retired IDs survive load")
    check(not loaded.get_realm("R002").active and not loaded.get_character("rabbit_7").alive and loaded.get_dynasty("house_oak") != null, "historical Realm/Character/Dynasty resolve after load")
    check(loaded.queries().dynasty_is_extinct("house_oak"), "extinct lifecycle rebuilds after load")
    check(loaded.get_relationship("R002", "R900").history.size() == 1, "historical relationship remains available")
    check(loaded.get_character("rabbit_7").claims[0].claim_id == "personal", "deceased claimant remains resolvable")
    check(loaded.queries().wars_between("R002", "R900") == ["war_save_700"], "WarState alone retains active conflict truth across load")
    ok(loaded.restore("R002", [11], 11, "foreign_heir", "restored"), "loaded historical Realm can be restored")
    var rebel_result: Dictionary = loaded.create_rebel(CampaignFixture.rebel(93), [93])
    ok(rebel_result, "new ID allocation after load")
    check(rebel_result["realm_id"] == "realm_rebel_2", "retired Realm ID remains reserved after load")
    var path: String = "res://.godot/test_logs/campaign_round_trip_%d.json" % Time.get_ticks_usec()
    check(session.save_file(path).is_empty(), "save file is written and verified")
    var file_result: Dictionary = CampaignCodec.load_file(path)
    check(file_result["state"] != null and canonical(file_result["state"].to_data()) == canonical(before), "file readback matches authoritative state")
    check(loaded.save_file(path).is_empty(), "atomic replacement of an existing save")
    var replaced: Dictionary = CampaignCodec.load_file(path)
    check(replaced["state"] != null and canonical(replaced["state"].to_data()) == canonical(loaded.export_data()), "replacement file is the new complete revision")
    var pending: FileAccess = FileAccess.open(path + ".pending", FileAccess.WRITE)
    pending.store_string("interrupted write")
    pending.close()
    check(not session.save_file(path).is_empty(), "pending interrupted save is not overwritten")
    check(canonical(CampaignCodec.load_file(path)["state"].to_data()) == canonical(loaded.export_data()), "failed save leaves prior complete destination intact")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".pending"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    check(CampaignCodec.load_file("res://.godot/test_logs/missing_save.json")["state"] == null, "missing save rejected")


func _corrupt_saves() -> void:
    var valid: Dictionary = CampaignFixture.state().to_data()
    var bad_registry: CampaignState = CampaignFixture.state()
    bad_registry.provinces[11].province_id = 12
    check(CampaignSession.create(bad_registry)["session"] == null, "registry key and stable record ID cannot diverge")
    invalid([], "non-object root rejected")
    for bad_version: Variant in [2, 1.5, "1", true]:
        var data: Dictionary = valid.duplicate(true)
        data["schema_version"] = bad_version
        invalid(data, "unsupported/noninteger schema rejected")
    for bad_id: Variant in [0, -1, 11.5, "11", true, 9007199254740992.0]:
        var data: Dictionary = valid.duplicate(true)
        data["provinces"][0]["province_id"] = bad_id
        invalid(data, "Province ID cannot be coerced/truncated")
    for category: String in ["provinces", "realms", "characters", "dynasties", "relationships"]:
        var data: Dictionary = valid.duplicate(true)
        data[category].append(data[category][0].duplicate(true))
        invalid(data, "duplicate " + category + " rejected before indexing")
    var mixed_duplicate: Dictionary = valid.duplicate(true)
    mixed_duplicate["provinces"].append(mixed_duplicate["provinces"][0].duplicate(true))
    mixed_duplicate["provinces"][-1]["province_id"] = 11.0
    invalid(mixed_duplicate, "integer/float representation cannot hide duplicate IDs")
    var mixed_retired: Dictionary = valid.duplicate(true)
    mixed_retired["retired_ids"]["provinces"].append(11.0)
    invalid(mixed_retired, "numeric representation cannot bypass retired-ID reservation")
    for entry: Array in [
        ["provinces", "owner_realm_id", "missing"],
        ["provinces", "local_food", -1],
        ["realms", "capital_province_id", 407],
        ["realms", "current_ruler_id", "ancestor"],
        ["realms", "recognized_heir_id", "ancestor"],
        ["characters", "dynasty_id", "missing"],
        ["characters", "realm_id", "missing"],
        ["characters", "parent_ids", ["missing"]],
        ["characters", "partner_ids", ["rabbit_7"]],
        ["dynasties", "parent_dynasty_id", "missing"],
        ["relationships", "realm_a_id", "missing"],
        ["relationships", "attitude_b_to_a", {"opinion": 50}],
    ]:
        var data: Dictionary = valid.duplicate(true)
        data[entry[0]][0][entry[1]] = entry[2]
        invalid(data, "invalid reference/value " + entry[1])
    for entry: Array in [
        ["realms", "ruling_dynasty_id"], ["realms", "owned_province_ids"],
        ["realms", "food"], ["realms", "manpower"], ["dynasties", "member_ids"],
        ["characters", "children"], ["characters", "recognized_heir"],
        ["relationships", "at_war"], ["relationships", "claims"],
        ["provinces", "controller_realm_id"],
    ]:
        var data: Dictionary = valid.duplicate(true)
        data[entry[0]][0][entry[1]] = []
        invalid(data, "duplicate authority field rejected: " + entry[1])
    var missing_pair: Dictionary = valid.duplicate(true)
    missing_pair["relationships"].clear()
    invalid(missing_pair, "missing pair rejected")
    var reversed: Dictionary = valid.duplicate(true)
    reversed["relationships"][0]["realm_a_id"] = "R900"
    reversed["relationships"][0]["realm_b_id"] = "R002"
    invalid(reversed, "noncanonical pair rejected without reversing attitude meanings")
    var cycle: Dictionary = valid.duplicate(true)
    cycle["characters"][0]["parent_ids"] = ["rabbit_7"]
    invalid(cycle, "ancestry cycle in save rejected")
    var branch_cycle: Dictionary = valid.duplicate(true)
    branch_cycle["dynasties"][0]["parent_dynasty_id"] = branch_cycle["dynasties"][1]["dynasty_id"]
    branch_cycle["dynasties"][1]["parent_dynasty_id"] = branch_cycle["dynasties"][0]["dynasty_id"]
    invalid(branch_cycle, "cadet branch cycle rejected")
    var claim_duplicate: Dictionary = valid.duplicate(true)
    claim_duplicate["characters"][0]["claims"] = [CampaignFixture.claim("duplicate").to_data()]
    claim_duplicate["realms"][0]["claims"] = [CampaignFixture.claim("duplicate").to_data()]
    invalid(claim_duplicate, "cross-level claim duplication rejected on load")
    for bad_target: Variant in ["407", 407.5, true, null]:
        var data: Dictionary = valid.duplicate(true)
        var claim: Dictionary = CampaignFixture.claim("invalid_target", 407).to_data()
        claim["target_id"] = bad_target
        data["realms"][0]["claims"].append(claim)
        invalid(data, "claim target is validated before normalization")
    var bad_war: Dictionary = valid.duplicate(true)
    var war: WarState = WarState.new()
    war.war_id = "bad_participant"
    war.attacker_realm_ids = ["R002"]
    war.defender_realm_ids = ["missing"]
    bad_war["wars"] = [war.to_data()]
    invalid(bad_war, "war participant reference validated")
    bad_war["wars"][0]["defender_realm_ids"] = ["R002"]
    invalid(bad_war, "Realm cannot oppose itself in one war")
    var retired: Dictionary = valid.duplicate(true)
    retired["retired_ids"]["realms"].append("R002")
    invalid(retired, "retired Realm cannot be present under recycled identity")
    var bad_game_over: Dictionary = valid.duplicate(true)
    bad_game_over["game_over"] = true
    invalid(bad_game_over, "game over without a player rejected")
    check(CampaignCodec.decode_json("{broken")["state"] == null, "malformed JSON rejected")
