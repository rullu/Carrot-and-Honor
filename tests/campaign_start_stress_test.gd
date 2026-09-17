extends CampaignTestSuite


func _initialize() -> void:
    var sample_count: int = 1000
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--seeds="):
            sample_count = argument.trim_prefix("--seeds=").to_int()
    check(sample_count > 0, "positive deterministic sample size")
    var world: CampaignStartWorld = CampaignStartWorld.new()
    var generator: CampaignStartGenerator = CampaignStartGenerator.new(world)
    var attempts: Dictionary = {}
    var ranges: Dictionary = {}
    var total_characters: int = 0
    var total_dynasties: int = 0
    var dead_spouses: int = 0
    var repeated_names: int = 0
    var female_heirs: int = 0
    var empty_heirs: int = 0
    var max_pool_use: Dictionary = {}
    var digests: Dictionary = {}
    var started: int = Time.get_ticks_msec()
    for index: int in sample_count:
        var seed: String = "sealed-v1-stress/" + str(index)
        var days: int = [1, 360, 365, 400][index % 4]
        var result: Dictionary = generator.generate(seed, days)
        check(result["cast"] != null, "stress seed %d accepted: %s" % [index, str(result["errors"])] )
        if result["cast"] == null:
            break
        var cast: Dictionary = result["cast"]
        var accepted_attempt: int = result["attempts"]
        attempts[str(accepted_attempt)] = int(attempts.get(str(accepted_attempt), 0)) + 1
        var wire: String = canonical(CampaignStartFixture.wire(cast))
        var digest: String = wire.sha256_text()
        check(not digests.has(digest), "representative seeds genuinely vary")
        digests[digest] = true
        # Repeat the accepted attempt independently for every sample. A full retry
        # replay for every tenth seed also verifies the acceptance sequence.
        var replay: Dictionary = generator.generate_attempt(seed, days, accepted_attempt - 1)
        check(wire == canonical(CampaignStartFixture.wire(replay)), "complete deterministic replay " + seed)
        if index % 10 == 0:
            var retry_replay: Dictionary = generator.generate(seed, days)
            check(result["rejections"] == retry_replay["rejections"] and wire == canonical(CampaignStartFixture.wire(retry_replay["cast"])), "repeat entire bounded retry sequence")
        var stats: Dictionary = CampaignStartValidator.statistics(cast)
        for key: String in stats:
            if not ranges.has(key):
                ranges[key] = [stats[key], stats[key]]
            ranges[key][0] = mini(ranges[key][0], stats[key])
            ranges[key][1] = maxi(ranges[key][1], stats[key])
        var chars: Dictionary = CampaignStartFixture.characters(cast)
        var names: Dictionary = {}
        var ruler_ids: Dictionary = {}
        for character: CharacterState in chars.values():
            repeated_names += int(names.has(character.given_name))
            names[character.given_name] = true
            dead_spouses += int(not character.alive and not character.partner_ids.is_empty())
            for parent_id: String in character.parent_ids:
                check(character.birth_tick - chars[parent_id].birth_tick >= days * 16, "independent exact age floor")
            for partner_id: String in character.partner_ids:
                check(character.character_id in chars[partner_id].partner_ids and character.realm_id == chars[partner_id].realm_id, "independent reciprocal affiliated spouse")
        for realm: RealmState in cast["realm_setups"]:
            check(not ruler_ids.has(realm.current_ruler_id), "distinct ruler for all 43 Realms")
            ruler_ids[realm.current_ruler_id] = true
            var ruler: CharacterState = chars[realm.current_ruler_id]
            var oldest_tick: int = 1
            var children: int = 0
            for child: CharacterState in chars.values():
                if ruler.character_id in child.parent_ids:
                    children += 1
                    oldest_tick = mini(oldest_tick, child.birth_tick)
                    check(child.alive and child.dynasty_id == ruler.dynasty_id and child.parent_ids.size() == 2, "independent legitimate living reigning bloodline")
            check(not ruler.partner_ids.is_empty() or children == 0, "unmarried ruler cannot have legitimate children")
            if realm.realm_id == "R008":
                check(realm.recognized_heir_id.is_empty() and realm.succession_law_id == "elected_office", "Seravelle across seeds")
            elif children == 0:
                empty_heirs += 1
                check(realm.recognized_heir_id.is_empty(), "no manufactured collateral heir")
            else:
                var heir: CharacterState = chars[realm.recognized_heir_id]
                female_heirs += int(heir.sex == "female")
                check(heir.birth_tick == oldest_tick and ruler.character_id in heir.parent_ids, "independent oldest child regardless of sex")
        var used_lineages: Dictionary = {}
        var pools: Dictionary = {}
        for dynasty: DynastyState in cast["dynasty_setups"]:
            check(not used_lineages.has(dynasty.lineage_name), "no unrelated name reuse")
            used_lineages[dynasty.lineage_name] = true
            var family: String = world.names.family(dynasty.origin_culture)
            pools[family] = int(pools.get(family, 0)) + 1
        for family: String in pools:
            max_pool_use[family] = maxi(int(max_pool_use.get(family, 0)), pools[family])
        total_characters += chars.size()
        total_dynasties += cast["dynasty_setups"].size()
        # Real canonical bootstrap and codec at regular intervals across all year configs.
        if index % 101 == 0:
            var built: Dictionary = CampaignBootstrap.from_generated(cast, "R028")
            check(built["state"] != null, "stress bootstrap: " + str(built["errors"]))
            if built["state"] != null:
                var json: String = canonical(built["state"].to_data())
                var restored: Dictionary = CampaignCodec.decode_json(json)
                check(restored["state"] != null and json == canonical(restored["state"].to_data()), "stress strict full-world save round trip")
        if (index + 1) % 100 == 0:
            print("Stress progress: ", index + 1, "/", sample_count)
    if sample_count >= 100:
        check(female_heirs > 0 and empty_heirs > 0 and dead_spouses > 0 and repeated_names > 0, "sample covers sex-neutral succession, vacant heirs, widowhood and legal repeated given names")
        check(ranges["male"][0] != ranges["male"][1] and ranges["childless"][0] != ranges["childless"][1], "soft bounds do not impose quotas")
    var report: Dictionary = {"seeds": sample_count, "unique_casts": digests.size(), "attempt_histogram": attempts,
        "stat_ranges": ranges, "characters": total_characters, "dynasties": total_dynasties,
        "deceased_spouses": dead_spouses, "female_heirs": female_heirs, "empty_heirs": empty_heirs,
        "repeated_given_names": repeated_names, "maximum_lineage_pool_use": max_pool_use,
        "elapsed_ms": Time.get_ticks_msec() - started}
    print(JSON.stringify(report, "", true, true))
    var output: FileAccess = FileAccess.open("res://.godot/test_logs/campaign_start_stress_report.json", FileAccess.WRITE)
    output.store_string(JSON.stringify(report, "  ", true, true))
    output.close()
    finish("Campaign start stress")
