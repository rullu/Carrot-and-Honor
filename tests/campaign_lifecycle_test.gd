extends CampaignTestSuite


func _initialize() -> void:
    _capture_restore_and_form()
    _rebels()
    _succession_and_death()
    _player_defeat()
    finish("Campaign lifecycle")


func _capture_restore_and_form() -> void:
    var session: CampaignSession = CampaignFixture.session()
    ok(session.record_memory("relationship", "R002", CampaignFixture.memory("Old diplomatic memory"), "R900"), "record bilateral history")
    var pair_before: Dictionary = session.get_relationship("R002", "R900").to_data()
    var old_view: CampaignQueries = session.queries()
    rejected(session, func() -> Dictionary: return session.capture(11, "missing"), "unknown capture recipient")
    rejected(session, func() -> Dictionary: return session.capture(88, "R900"), "retired province capture")
    ok(session.capture(11, "R900"), "capture old capital")
    check(session.get_province(11).owner_realm_id == "R900", "capture changes formal ownership immediately")
    check(session.get_realm("R002").capital_province_id == 93, "surviving Realm gets valid capital")
    check(session.queries().territory("R002") == [93] and session.queries().territory("R900") == [11, 407], "territory follows transferred owner")
    check(old_view.territory("R002") == [11, 93], "a prior query snapshot remains internally consistent")
    ok(session.capture(93, "R900"), "take last NPC province")
    var inactive: RealmState = session.get_realm("R002")
    check(not inactive.active and inactive.capital_province_id == 0 and inactive.current_ruler_id.is_empty() and inactive.recognized_heir_id.is_empty(), "landless NPC becomes inactive with cleared current roles")
    check(session.get_character("rabbit_7").alive, "political extinction does not delete/kill the Character")
    check(not session.queries().diplomacy_active("R002", "R900"), "ordinary diplomacy suspended")
    check(session.get_relationship("R002", "R900").to_data() == pair_before, "historical relationship survives inactivity")
    rejected(session, func() -> Dictionary: return session.set_attitude("R002", "R900", StateSchema.neutral_attitude()), "inactive diplomacy write")
    rejected(session, func() -> Dictionary: return session.restore("R002", [11], 11, "missing", "restored"), "restoration with missing ruler")
    rejected(session, func() -> Dictionary: return session.restore("R002", [11, 11], 11, "rabbit_7", "restored"), "restoration duplicate grant")
    rejected(session, func() -> Dictionary: return session.restore("R002", [11], 93, "rabbit_7", "restored"), "restoration capital outside grant")
    ok(session.restore("R002", [11, 407], 407, "rabbit_7", "restored"), "restore historical Realm")
    check(session.get_realm("R002").realm_id == "R002" and session.get_realm("R002").active, "restoration reuses identity")
    check(session.get_realm("R900").capital_province_id == 93, "restoration repairs donor capital")
    check(session.queries().diplomacy_active("R002", "R900"), "restored active network available")
    check(session.get_relationship("R002", "R900").to_data() == pair_before, "restoration retains bilateral history and attitudes")
    var before_form: Dictionary = session.get_realm("R002").to_data()
    var provinces_before: Array = session.export_data()["provinces"]
    ok(session.form("R002", "fixture_formable"), "political transformation")
    var expected: Dictionary = before_form.duplicate(true)
    expected["political_identity_id"] = "fixture_formable"
    check(session.get_realm("R002").to_data() == expected, "formable changes identity only; stable ID/style/wallets/ruler/history persist")
    check(session.export_data()["provinces"] == provinces_before, "formable does not convert local identities")
    check(session.get_relationship("R002", "R900").to_data() == pair_before, "formable preserves relationship")
    ok(session.form("R002", "fixture_formable_2", "Authored style"), "explicit style transformation")
    check(session.get_realm("R002").realm_style == "Authored style", "style changes only when supplied")
    check(CampaignValidator.validate_data(session.export_data()).is_empty(), "capture/restoration/formation invariants")


func _rebels() -> void:
    var session: CampaignSession = CampaignFixture.session()
    var invalid_setup: RealmState = CampaignFixture.rebel()
    invalid_setup.current_ruler_id = "missing"
    rejected(session, func() -> Dictionary: return session.create_rebel(invalid_setup, [93]), "invalid rebel ruler after proposed transfers")
    var malformed_setup: RealmState = CampaignFixture.rebel()
    malformed_setup.history.append(null)
    rejected(session, func() -> Dictionary: return session.create_rebel(malformed_setup, [93]), "malformed nested rebel history")
    var impersonator: RealmState = CampaignFixture.rebel()
    impersonator.realm_id = "retired_realm"
    rejected(session, func() -> Dictionary: return session.create_rebel(impersonator, [93]), "retired realm impersonation")
    var result: Dictionary = session.create_rebel(CampaignFixture.rebel(), [93])
    ok(result, "create new rebel Realm")
    var id: String = result["realm_id"]
    check(id == "realm_rebel_2", "allocator skips tombstone; failed transaction consumed no identity")
    check(session.get_realm(id).capital_province_id == 93 and session.get_realm(id).current_ruler_id == "unaffiliated", "rebel capital/ruler valid")
    check(session.get_relationship(id, "R002") != null and session.get_relationship(id, "R900") != null, "rebel joins diplomatic network")
    check(session.export_data()["relationships"].size() == 3, "three Realms have exactly three pair records")
    ok(session.capture(93, "R900"), "rebel becomes historical")
    var next: Dictionary = session.create_rebel(CampaignFixture.rebel(11), [11])
    ok(next, "create a second genuinely new rebel")
    check(next["realm_id"] == "realm_rebel_3" and session.get_realm(id) != null, "inactive identity cannot be recycled")
    check(session.get_relationship(next["realm_id"], id) != null, "network includes historical pair for later restoration")


func _succession_and_death() -> void:
    var session: CampaignSession = CampaignFixture.session()
    var characters_before: Array = session.export_data()["characters"]
    var pair_before: Dictionary = session.get_relationship("R002", "R900").to_data()
    rejected(session, func() -> Dictionary: return session.succeed("R002", "ancestor", "recognized"), "dead ruler succession")
    rejected(session, func() -> Dictionary: return session.succeed("R002", "foreign_heir", "recognized", "foreign_heir"), "ruler also recognized heir")
    ok(session.succeed("R002", "foreign_heir", "recognized"), "foreign heir succeeds")
    check(session.export_data()["characters"] == characters_before, "succession changes no character-owned facts")
    check(session.get_realm("R002").recognized_heir_id.is_empty() and session.get_realm("R002").legitimacy == "recognized", "succession resolves legitimacy and clears stale heir")
    check(session.queries().ruling_dynasty("R002") == "house_ash", "ruling dynasty follows new ruler")
    check(session.get_relationship("R002", "R900").to_data() == pair_before, "succession preserves relationship identity and contents")
    ok(session.mark_deceased("rabbit_7"), "retain deceased former ruler")
    check(not session.get_character("rabbit_7").alive and session.queries().dynasty_is_extinct("house_oak"), "House extinction derived, identities retained")
    rejected(session, func() -> Dictionary: return session.set_allegiance("rabbit_7", "R900"), "dead character active allegiance change")
    rejected(session, func() -> Dictionary: return session.mark_deceased("foreign_heir"), "death without required succession")
    ok(session.succeed("R900", "foreign_heir", "recognized"), "same Character may hold several Realm roles")
    rejected(session, func() -> Dictionary: return session.mark_deceased("foreign_heir", {"R002": {"ruler_id": "unaffiliated", "legitimacy": "resolved", "heir_id": ""}}), "death with partial multi-Realm succession")
    ok(session.mark_deceased("foreign_heir", {
        "R002": {"ruler_id": "unaffiliated", "legitimacy": "resolved", "heir_id": ""},
        "R900": {"ruler_id": "rabbit_90", "legitimacy": "resolved", "heir_id": ""},
    }), "death with all successors committed together")
    check(not session.get_character("foreign_heir").alive and session.get_realm("R002").current_ruler_id == "unaffiliated" and session.get_realm("R900").current_ruler_id == "rabbit_90", "multi-Realm death leaves valid rulers")
    check(CampaignValidator.validate_data(session.export_data()).is_empty(), "all lifecycle references validate")


func _player_defeat() -> void:
    var state: CampaignState = CampaignFixture.state()
    state.player_realm_id = "R002"
    var session: CampaignSession = CampaignSession.create(state)["session"]
    ok(session.capture(11, "R900"), "player survives first loss")
    check(not session.export_data()["game_over"], "player with remaining land continues")
    ok(session.capture(93, "R900"), "player last-province capture commits")
    check(session.export_data()["game_over"] and not session.get_realm("R002").active, "zero provinces ends campaign without invalid active Realm")
    rejected(session, func() -> Dictionary: return session.restore("R002", [11], 11, "rabbit_7", "restored"), "terminal campaign cannot silently resume")
    var decoded: Dictionary = CampaignCodec.decode_json(canonical(session.export_data()))
    check(decoded["state"] != null, "terminal campaign round-trips and validates")
