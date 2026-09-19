extends CampaignTestSuite


func _initialize() -> void:
    var base: CampaignState = CampaignBootstrap.new_cast_campaign("economy-stress-cast-fixture", 365)["state"]
    var config: EconomyConfig = EconomyFixture.config()
    var catalogue: EconomyCatalogue = EconomyCatalogue.new()
    var unique: Dictionary = {}
    var opportunity_counts: Array[int] = [0, 0, 0, 0]
    var normal_counts: Array[int] = [0, 0, 0, 0]
    var powerhouse_counts: Array[int] = [0, 0, 0, 0]
    var hidden_count: int = 0
    var site_count: int = 0
    var successful_site_rolls: int = 0
    var site_eligible_rolls: int = 0
    var minimum_true: Dictionary = {"opportunity_fertile_land": 100, "opportunity_iron": 100}
    var minimum_visible: Dictionary = minimum_true.duplicate()
    var began: int = Time.get_ticks_msec()
    var seed_count: int = 1000
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--seeds="):
            seed_count = argument.trim_prefix("--seeds=").to_int()
    check(seed_count > 0, "positive stress sample")
    for index: int in seed_count:
        base.campaign_seed = "economy-v1-stress/" + str(index)
        config.strategic_slots = [8, 10, 12][index % 3]
        config.hidden_chance_bp = [0, 2700, 10000][index % 3]
        var generated: Dictionary = EconomyGenerator.generate(base, config)
        check(generated["state"] != null, "stress generation %d: %s" % [index, str(generated["errors"])])
        if generated["state"] == null:
            break
        var state: CampaignState = generated["state"]
        var wire: String = canonical(EconomyFixture.economy_data(state))
        var digest: String = wire.sha256_text()
        check(not unique.has(digest), "different representative seeds vary")
        unique[digest] = true
        var replay: Dictionary = EconomyGenerator.generate(base, config)
        check(replay["state"] != null and canonical(EconomyFixture.economy_data(replay["state"])) == wire, "deterministic full replay")
        var world: EconomyWorld = EconomyWorld.new(state, config)
        var totals: Dictionary = {}
        var visible: Dictionary = {}
        for id: int in world.province_ids:
            var province: ProvinceState = state.provinces[id]
            var economy: ProvinceEconomy = province.economy
            opportunity_counts[int(generated["raw_opportunity_counts"][id])] += 1
            check(economy.opportunities.size() <= 3, "max three opportunities")
            var seen: Dictionary = {}
            var unknown: int = 0
            for item: EconomyOpportunity in economy.opportunities:
                check(not seen.has(item.type_id) and catalogue.opportunities.has(item.type_id), "distinct valid opportunity")
                seen[item.type_id] = true
                totals[item.type_id] = int(totals.get(item.type_id, 0)) + 1
                if province.owner_realm_id in item.known_realm_ids:
                    visible[item.type_id] = int(visible.get(item.type_id, 0)) + 1
                else:
                    unknown += 1
            check(unknown <= 1, "at most one Day-1 hidden opportunity")
            hidden_count += unknown
            check(economy.sites.size() <= 1, "at most one random countryside site")
            for site: EconomyInstance in economy.sites:
                var source: String = catalogue.sites[site.type_id].source_id
                check((world.aquatic(id) if source == "aquatic" else economy.known(source, province.owner_realm_id)) and site.state == "active", "site never leaks owner-hidden source")
            site_count += economy.sites.size()
            var rolled: bool = EconomyGenerator.stream(base, config, "sites", "selection", id).below(10000) < 400
            successful_site_rolls += int(rolled)
            if rolled and not EconomyGenerator.eligible_site_families(province, catalogue, world).is_empty():
                site_eligible_rolls += 1
                check(economy.sites.size() == 1, "eligible successful 4% roll creates exactly one site")
            else:
                check(economy.sites.is_empty(), "failed/no-family roll is not transferred or compensated")
            var building_table: Array[int] = powerhouse_counts if province.owner_realm_id in config.powerhouse_realm_ids else normal_counts
            building_table[economy.buildings.size()] += 1
            seen.clear()
            for building: EconomyInstance in economy.buildings:
                check(not seen.has(building.type_id) and building.type_id in catalogue.random_buildings(), "only distinct exact Day-1 types")
                seen[building.type_id] = true
                check(building.state == "active" and building.form == "base" and building.origin_culture == province.local_culture and building.origin_religion == province.local_religion, "constructed base and stamped local variant")
                check(building.type_id != "building_harbour" or world.coast(id), "Harbour coastal prerequisite")
                check(building.type_id != "building_mill" or economy.known("opportunity_fertile_land", province.owner_realm_id), "Mill visible grain basis")
        for id: String in minimum_true:
            minimum_true[id] = mini(minimum_true[id], int(totals.get(id, 0)))
            minimum_visible[id] = mini(minimum_visible[id], int(visible.get(id, 0)))
            check(totals.get(id, 0) >= EconomyRules.TRUE_FLOORS[id] and visible.get(id, 0) >= EconomyRules.VISIBLE_FLOORS[id], "independent safety-floor checks")
        if index % 25 == 0:
            var restored: Dictionary = CampaignCodec.decode_json(canonical(state.to_data()))
            check(restored["state"] != null and canonical(restored["state"].to_data()) == canonical(state.to_data()), "strict full-state stress round trip")
            var changed: EconomyConfig = EconomyConfig.from_data(config.to_data())
            changed.domain_versions["buildings"] += 1
            var other: CampaignState = EconomyGenerator.generate(base, changed)["state"]
            check(canonical(EconomyFixture.economy_data(other, ["opportunities", "sites"])) == canonical(EconomyFixture.economy_data(state, ["opportunities", "sites"])), "building domain stress independence")
            changed = EconomyConfig.from_data(config.to_data())
            changed.domain_versions["sites"] += 1
            other = EconomyGenerator.generate(base, changed)["state"]
            check(canonical(EconomyFixture.economy_data(other, ["opportunities", "buildings"])) == canonical(EconomyFixture.economy_data(state, ["opportunities", "buildings"])), "site domain stress independence")
        if (index + 1) % 100 == 0:
            print("Economy stress progress: %d/%d" % [index + 1, seed_count])
    if seed_count >= 500:
        _frequencies(opportunity_counts, [20, 45, 30, 5], 0.012, "opportunities before repair")
        _frequencies(normal_counts, [40, 40, 15, 5], 0.012, "Normal buildings")
        _frequencies(powerhouse_counts, [20, 40, 30, 10], 0.025, "Powerhouse buildings")
        check(absf(float(successful_site_rolls) / (seed_count * 100) - 0.04) < 0.004, "unconditional independent 4% roll frequency")
    check(site_count == site_eligible_rolls, "no extra/missing eligible starting sites")
    print(JSON.stringify({"seeds": seed_count, "unique_worlds": unique.size(), "opportunity_counts_before_repair": opportunity_counts,
        "normal_building_counts": normal_counts, "powerhouse_building_counts": powerhouse_counts,
        "hidden_opportunities": hidden_count, "site_roll_successes": successful_site_rolls, "sites": site_count,
        "minimum_true": minimum_true, "minimum_visible": minimum_visible, "elapsed_ms": Time.get_ticks_msec() - began}, "", true))
    finish("Economy stress")


func _frequencies(counts: Array[int], percentages: Array, tolerance: float, label: String) -> void:
    var total: int = 0
    for count: int in counts:
        total += count
    for index: int in counts.size():
        check(absf(float(counts[index]) / total - float(percentages[index]) / 100) < tolerance, label + " broad observed frequency")
