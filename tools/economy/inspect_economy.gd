extends SceneTree


func _initialize() -> void:
    var seed: String = ""
    var days: int = 0
    var config_path: String = EconomyConfig.PATH
    var save_path: String = ""
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--seed="):
            seed = argument.trim_prefix("--seed=")
        elif argument.begins_with("--days-per-year="):
            var value: String = argument.trim_prefix("--days-per-year=")
            if not value.is_valid_int():
                push_error("days-per-year must be an integer.")
                quit(1)
                return
            days = value.to_int()
        elif argument.begins_with("--config="):
            config_path = argument.trim_prefix("--config=")
        elif argument.begins_with("--save="):
            save_path = argument.trim_prefix("--save=")
        else:
            push_error("Unknown argument: " + argument)
            quit(1)
            return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
    var errors: PackedStringArray = EconomyConfig.validate_data(data, EconomyCatalogue.new())
    if not errors.is_empty():
        push_error("Economy configuration is incomplete/invalid: " + str(errors))
        quit(1)
        return
    var config: EconomyConfig = EconomyConfig.from_data(data)
    var result: Dictionary = CampaignBootstrap.new_campaign(seed, days, "", config)
    if result["state"] == null:
        push_error(str(result["errors"]))
        quit(1)
        return
    var state: CampaignState = result["state"]
    if not save_path.is_empty():
        errors = CampaignCodec.save_file(state, save_path)
        if not errors.is_empty():
            push_error(str(errors))
            quit(1)
            return
    var sites: int = 0
    var buildings: int = 0
    for province: ProvinceState in state.provinces.values():
        sites += province.economy.sites.size()
        buildings += province.economy.buildings.size()
    print(JSON.stringify({"configuration_status": config.status, "config_hash": config.fingerprint(),
        "schema": CampaignState.SCHEMA_VERSION, "economy_generator": EconomyGenerator.VERSION,
        "seed": seed, "provinces": state.provinces.size(), "sites": sites, "buildings": buildings,
        "true_opportunities": EconomyRules.totals(state), "owner_visible_opportunities": EconomyRules.totals(state, true)}, "", true))
    print("PASS: validated economy campaign; configuration status = ", config.status)
    quit(0)
