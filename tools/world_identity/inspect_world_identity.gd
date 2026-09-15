extends SceneTree


const WorldIdentityCatalogueScript: GDScript = preload(
    "res://src/simulation/world_identity_catalogue.gd"
)


func _initialize() -> void:
    var catalogue: RefCounted = WorldIdentityCatalogueScript.load_default()
    if catalogue == null:
        push_error("World identity inspection aborted because canonical data did not validate.")
        quit(1)
        return

    var province_filter: int = -1
    var realm_filter: StringName = &""
    var inspect_all: bool = false
    for argument: String in OS.get_cmdline_user_args():
        if argument == "--all":
            inspect_all = true
        elif argument.begins_with("--province="):
            province_filter = int(argument.trim_prefix("--province="))
        elif argument.begins_with("--realm="):
            realm_filter = StringName(argument.trim_prefix("--realm="))

    print(
        "WORLD_IDENTITY_READY: %d provinces; %d starting realms; %d formables"
        % [catalogue.get_province_count(), catalogue.get_realm_count(), catalogue.get_formable_count()]
    )
    if province_filter > 0:
        if not _print_province(catalogue, province_filter):
            quit(1)
            return
    elif not realm_filter.is_empty():
        if not _print_realm(catalogue, realm_filter):
            quit(1)
            return
    elif inspect_all:
        for province_id: int in catalogue.get_province_ids():
            _print_province(catalogue, province_id)
        for realm_id: StringName in catalogue.get_realm_ids():
            _print_realm(catalogue, realm_id)
    else:
        for province_id: int in [30, 51, 32, 53, 99]:
            _print_province(catalogue, province_id)
        for realm_id: StringName in [&"R008", &"R028", &"R030", &"R043"]:
            _print_realm(catalogue, realm_id)
        print("Use -- --province=30, -- --realm=R028, or -- --all for targeted/full inspection.")
    quit(0)


func _print_province(catalogue: RefCounted, province_id: int) -> bool:
    var province: Dictionary = catalogue.get_province_identity(province_id)
    if province.is_empty():
        push_error("Unknown province ID %d." % province_id)
        return false
    var religion: Dictionary = province["religion"]
    print(
        (
            "PROVINCE %d | %s | region=%s | culture=%s | broad_faith=%s | "
            + "grand_tradition=%s | communion=%s | institution_or_tradition=%s | "
            + "rite_or_belief=%s | owner=%s | flags=%s"
        )
        % [
            province_id,
            province["province_name"],
            province["identity_region"],
            province["culture"],
            _optional(religion["broad_faith"]),
            _optional(religion["grand_tradition"]),
            _optional(religion["communion"]),
            _optional(religion["institution_or_tradition"]),
            _optional(religion["rite_or_belief"]),
            province["starting_realm_id"],
            province["special_flags"],
        ]
    )
    return true


func _print_realm(catalogue: RefCounted, realm_id: StringName) -> bool:
    var realm: Dictionary = catalogue.get_realm_identity(realm_id)
    if realm.is_empty():
        push_error("Unknown realm ID %s." % realm_id)
        return false
    print(
        (
            "REALM %s | %s | name=%s | style=%s | type=%s | region=%s | "
            + "primary_culture=%s | primary_religious_identity=%s | provinces=%s | "
            + "cultures=%s | broad_faiths=%s | rites_or_beliefs=%s | flags=%s | source_specific=%s"
        )
        % [
            realm_id,
            _optional(realm["display_name"]),
            realm["realm_name"],
            _optional(realm["realm_style"]),
            realm["realm_type"],
            realm["identity_region"],
            realm["primary_culture"],
            realm["primary_religious_identity"],
            catalogue.get_starting_province_ids_for_realm(realm_id),
            realm["starting_cultures"],
            realm["starting_broad_faiths"],
            realm["starting_rites_or_beliefs"],
            realm["special_flags"],
            realm.get("source_specific", {}),
        ]
    )
    return true


func _optional(value: Variant) -> String:
    if value == null:
        return "<not applicable/deferred>"
    return String(value)
