class_name CampaignCodec
extends RefCounted


static func decode_data(data: Variant) -> Dictionary:
    var errors: PackedStringArray = CampaignValidator.validate_data(data)
    if not errors.is_empty():
        return {"state": null, "errors": errors}
    return {"state": CampaignState.from_data(data), "errors": errors}


static func decode_json(text: String) -> Dictionary:
    var parser: JSON = JSON.new()
    if parser.parse(text) != OK:
        return {"state": null, "errors": PackedStringArray([
            "Invalid save JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
        ])}
    return decode_data(parser.data)


static func load_file(path: String) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"state": null, "errors": PackedStringArray(["Cannot open save: " + path])}
    return decode_json(file.get_as_text())


static func migrate_v2(data: Variant) -> Dictionary:
    # Explicit lossless migration only; no economy is generated from historical saves.
    var errors: PackedStringArray = []
    var root_fields: Dictionary = CampaignValidator.ROOT_FIELDS.duplicate()
    root_fields.erase("economy_generation")
    StateSchema.validate_record(data, root_fields, "Schema-2 campaign", errors)
    if not errors.is_empty():
        return {"state": null, "errors": errors}
    if int(data["schema_version"]) != 2:
        return {"state": null, "errors": PackedStringArray(["Explicit migration requires schema 2."])}
    var province_fields: Dictionary = ProvinceState.FIELDS.duplicate()
    province_fields.erase("economy")
    for record: Variant in data["provinces"]:
        StateSchema.validate_record(record, province_fields, "Schema-2 Province", errors)
    if not errors.is_empty():
        return {"state": null, "errors": errors}
    var migrated: Dictionary = data.duplicate(true)
    migrated["schema_version"] = CampaignState.SCHEMA_VERSION
    migrated["economy_generation"] = null
    for record: Dictionary in migrated["provinces"]:
        record["economy"] = null
    return decode_data(migrated)


static func save_file(state: CampaignState, path: String) -> PackedStringArray:
    var key_errors: PackedStringArray = CampaignValidator.validate_registry_keys(state)
    if not key_errors.is_empty():
        return key_errors
    var data: Dictionary = state.to_data()
    var errors: PackedStringArray = CampaignValidator.validate_data(data)
    if not errors.is_empty():
        return errors
    data = CampaignState.from_data(data).to_data()
    # Write/verify beside the destination, then replace in one filesystem rename.
    # A failed write or validation leaves the existing save intact.
    var temporary: String = path + ".pending"
    if FileAccess.file_exists(temporary):
        return PackedStringArray(["Pending save already exists; inspect it before retrying: " + temporary])
    var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return PackedStringArray(["Cannot create pending save: " + temporary])
    file.store_string(JSON.stringify(data, "", true, true))
    file.flush()
    var write_error: Error = file.get_error()
    file.close()
    var verification: Dictionary = load_file(temporary)
    if write_error != OK or verification["state"] == null:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return PackedStringArray(["Pending save write/readback failed."])
    var restored: CampaignState = verification["state"]
    if JSON.stringify(restored.to_data(), "", true, true) != JSON.stringify(data, "", true, true):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return PackedStringArray(["Pending save failed authoritative round-trip comparison."])
    var rename_error: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)
    )
    if rename_error != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return PackedStringArray(["Cannot atomically replace save: " + path])
    return []
