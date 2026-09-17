extends SceneTree


func _initialize() -> void:
    var seed: String = ""
    var days: int = 0
    var player: String = ""
    var save_path: String = ""
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--seed="):
            seed = argument.trim_prefix("--seed=")
        elif argument.begins_with("--days-per-year="):
            var year_text: String = argument.trim_prefix("--days-per-year=")
            if not year_text.is_valid_int():
                push_error("days-per-year requires an integer.")
                quit(1)
                return
            days = year_text.to_int()
        elif argument.begins_with("--player="):
            player = argument.trim_prefix("--player=")
        elif argument.begins_with("--save="):
            save_path = argument.trim_prefix("--save=")
        else:
            push_error("Unknown campaign-start argument: " + argument)
            quit(1)
            return
    var result: Dictionary = CampaignBootstrap.new_campaign(seed, days, player)
    if result["state"] == null:
        push_error("Campaign creation failed: " + str(result["errors"]))
        quit(1)
        return
    var state: CampaignState = result["state"]
    if not save_path.is_empty():
        var errors: PackedStringArray = CampaignCodec.save_file(state, save_path)
        if not errors.is_empty():
            push_error("Campaign save failed: " + str(errors))
            quit(1)
            return
    print("Seed: ", state.campaign_seed, "; generator: ", state.generator_version,
        "; days/year: ", state.days_per_year, "; attempts: ", result["attempts"])
    for realm: RealmState in state.realms.values():
        var ruler: CharacterState = state.characters[realm.current_ruler_id]
        var dynasty: DynastyState = state.dynasties[ruler.dynasty_id]
        print("%s | %s | %s %s | %s, age %d | Seat P%d | heir %s" % [
            realm.realm_id, ruler.given_name, dynasty.lineage_style, dynasty.lineage_name,
            ruler.sex, ruler.age_years(0, state.days_per_year), realm.capital_province_id,
            "none" if realm.recognized_heir_id.is_empty() else state.characters[realm.recognized_heir_id].given_name])
    print("PASS: complete campaign, %d characters, %d lineages, %d pairs." % [
        state.characters.size(), state.dynasties.size(), state.relationships.size()])
    quit(0)
