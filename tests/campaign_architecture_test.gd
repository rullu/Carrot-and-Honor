extends CampaignTestSuite


func _initialize() -> void:
    var initial: CampaignState = CampaignFixture.state()
    check(CampaignValidator.validate_data(initial.to_data()).is_empty(), "fixture validates")
    var session: CampaignSession = CampaignFixture.session()
    if session == null:
        check(false, "valid fixture creates session")
        finish("Campaign architecture")
        return
    var queries: CampaignQueries = session.queries()
    check(queries.territory("R002") == [11, 93], "sparse territory derives from ownership")
    check(session.get_province(12) == null and session.get_realm("R003") == null, "unknown IDs do not index arrays")
    check(queries.local_resources_overview("R002") == {"food": 12, "manpower": 30}, "Food/manpower sum province local state")
    check(queries.ruling_dynasty("R002") == "house_oak", "ruling dynasty resolves through current ruler")
    check(queries.dynasty_members("house_ash") == ["foreign_heir", "rabbit_90", "unaffiliated"], "members derive from Characters")
    check(queries.dynasty_is_extinct("house_historical"), "dead-only House is extinct")
    check(session.get_character("ancestor") != null and session.get_dynasty("house_historical") != null, "historical entities remain resolvable")
    check(session.get_realm("R002").recognized_heir_id == "foreign_heir", "foreign allegiance does not erase heir role")
    ok(session.set_allegiance("foreign_heir", ""), "heir may be unaffiliated")
    check(session.get_realm("R002").recognized_heir_id == "foreign_heir", "allegiance writes do not change heir")

    var truth: String = canonical(session.export_data())
    var detached: ProvinceState = session.get_province(11)
    detached.owner_realm_id = "R900"
    var exported: Dictionary = session.export_data()
    exported["realms"][0]["carrots"] = 999
    var returned_members: Array[String] = queries.dynasty_members("house_ash")
    returned_members.clear()
    queries.clear_caches()
    check(queries.territory("R002") == [11, 93], "cache deletion rebuilds territory")
    queries.rebuild_caches()
    check(queries.children_of("ancestor") == ["rabbit_7"], "children derive after cache rebuild")
    check(canonical(session.export_data()) == truth, "read mutations and cache rebuild cannot change truth")
    ok(session.set_local_resources(11, 29, 41), "province resource write")
    check(session.queries().local_resources_overview("R002") == {"food": 37, "manpower": 61}, "overview follows local changes")
    rejected(session, func() -> Dictionary: return session.set_local_resources(11, -1, 7), "negative resource write")

    ok(session.set_parents("foreign_heir", ["rabbit_7"]), "canonical parent write")
    check(session.queries().children_of("rabbit_7") == ["foreign_heir"], "children cannot diverge")
    rejected(session, func() -> Dictionary: return session.set_parents("ancestor", ["foreign_heir"]), "ancestry cycle")
    rejected(session, func() -> Dictionary: return session.set_parents("rabbit_7", ["rabbit_7"]), "self-parent")
    rejected(session, func() -> Dictionary: return session.set_parents("rabbit_7", ["missing"]), "missing parent")
    rejected(session, func() -> Dictionary: return session.set_parents("foreign_heir", ["rabbit_7", "rabbit_7"]), "duplicate parent")
    ok(session.link_partners("rabbit_7", "rabbit_90"), "reciprocal partner transaction")
    check(session.get_character("rabbit_7").partner_ids == ["rabbit_90"] and session.get_character("rabbit_90").partner_ids == ["rabbit_7"], "partner edges reciprocal")
    ok(session.link_partners("rabbit_7", "rabbit_90", false), "unlink partners")
    check(session.get_character("rabbit_90").partner_ids.is_empty(), "unlink removes both edges")

    ok(session.add_claim("character", "rabbit_7", CampaignFixture.claim("personal_right")), "personal claim")
    var house_claim: ClaimRecord = CampaignFixture.claim("house_right")
    house_claim.related_claim_id = "personal_right"
    ok(session.add_claim("dynasty", "house_oak", house_claim), "separate House right with provenance")
    ok(session.add_claim("realm", "R002", CampaignFixture.claim("political_right", 407)), "Realm province claim")
    check(session.get_character("rabbit_7").claims.size() == 1 and session.get_dynasty("house_oak").claims.size() == 1 and session.get_realm("R002").claims.size() == 1, "three claimant levels have separate rights")
    rejected(session, func() -> Dictionary: return session.add_claim("realm", "R002", CampaignFixture.claim("personal_right")), "duplicate claim ownership")
    rejected(session, func() -> Dictionary: return session.add_claim("relationship", "R002", CampaignFixture.claim("bad")), "Relationship cannot own claims")
    rejected(session, func() -> Dictionary: return session.add_claim("realm", "R002", CampaignFixture.claim("retired_claim")), "retired claim reuse")
    var bad_claim: ClaimRecord = CampaignFixture.claim("bad_numeric_target", 407)
    bad_claim.target_id = 407.5
    rejected(session, func() -> Dictionary: return session.add_claim("realm", "R002", bad_claim), "claim API cannot truncate fractional IDs")

    var attitude: Dictionary = StateSchema.neutral_attitude()
    attitude["trust"] = 17
    attitude["grievance"] = 6
    ok(session.set_attitude("R900", "R002", attitude), "directional attitude write")
    var relationship: RelationshipState = session.get_relationship("R002", "R900")
    check(relationship.attitude_a_to_b["trust"] == 0 and relationship.attitude_b_to_a["trust"] == 17, "attitudes can differ within one pair")
    check(relationship.to_data() == session.get_relationship("R900", "R002").to_data(), "reverse pair lookup resolves same record")
    check(RelationshipState.pair_key("a|b", "c") != RelationshipState.pair_key("a", "b|c"), "opaque delimiter-bearing IDs do not collide")

    for entry: Array in [["province", 11], ["realm", "R002"], ["character", "rabbit_7"], ["dynasty", "house_oak"], ["relationship", "R002"]]:
        ok(session.record_memory(entry[0], entry[1], CampaignFixture.memory("Perspective says old war / old owner"), "R900"), "perspective memory " + entry[0])
    check(session.queries().wars_between("R002", "R900").is_empty(), "historical war memory is not active war")
    check(session.get_province(11).owner_realm_id == "R002", "memory is not current ownership")
    var war: WarState = WarState.new()
    war.war_id = "war_sparse_904"
    war.attacker_realm_ids = ["R002"]
    war.defender_realm_ids = ["R900"]
    var pair_before: Dictionary = session.get_relationship("R002", "R900").to_data()
    ok(session.register_war(war), "register boundary WarState")
    check(session.queries().wars_between("R900", "R002") == [war.war_id], "active war derives from WarState")
    check(session.get_relationship("R002", "R900").to_data() == pair_before, "war does not write a relationship flag")
    ok(session.end_war(war.war_id), "end boundary WarState")
    check(session.queries().wars_between("R002", "R900").is_empty(), "ended war clears derived current war")
    check(CampaignValidator.validate_data(session.export_data()).is_empty(), "all cross-state invariants after commands")
    finish("Campaign architecture")
