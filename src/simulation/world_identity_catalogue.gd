class_name WorldIdentityCatalogue
extends RefCounted


const DEFAULT_IDENTITY_PATH: String = "res://data/world_identity/world_identity_master_canon.json"
const DEFAULT_OWNERSHIP_PATH: String = "res://data/politics/starting_realm_ownership_v1.json"
const DEFAULT_GEOGRAPHY_PATH: String = "res://data/world_map/astra_provinces.json"
const EXPECTED_PROVINCE_COUNT: int = 100
const EXPECTED_REALM_COUNT: int = 43


var _identity_data: Dictionary = {}
var _provinces_by_id: Dictionary[int, Dictionary] = {}
var _realms_by_id: Dictionary[StringName, Dictionary] = {}
var _formables_by_id: Dictionary[StringName, Dictionary] = {}
var _province_ids: PackedInt32Array = []
var _realm_ids: Array[StringName] = []
var _formable_ids: Array[StringName] = []


static func load_default() -> RefCounted:
    return load_from_paths(
        DEFAULT_IDENTITY_PATH,
        DEFAULT_OWNERSHIP_PATH,
        DEFAULT_GEOGRAPHY_PATH
    )


static func load_from_paths(
        identity_path: String,
        ownership_path: String,
        geography_path: String
) -> RefCounted:
    var identity_result: Dictionary = _load_json_object(identity_path, "world identity")
    var ownership_result: Dictionary = _load_json_object(ownership_path, "frozen ownership")
    var geography_result: Dictionary = _load_json_object(geography_path, "province geography")
    if identity_result.is_empty() or ownership_result.is_empty() or geography_result.is_empty():
        return null

    var errors: PackedStringArray = validate_documents(
        identity_result,
        ownership_result,
        geography_result
    )
    if not errors.is_empty():
        push_error(
            "World identity validation failed with %d error(s):\n- %s"
            % [errors.size(), "\n- ".join(errors)]
        )
        return null

    return _create_validated(identity_result)


static func validate_documents(
        identity_data: Dictionary,
        ownership_data: Dictionary,
        geography_data: Dictionary
) -> PackedStringArray:
    var errors: PackedStringArray = []
    var geography_ids: Dictionary[int, bool] = _validate_geography(
        geography_data,
        errors
    )
    var ownership_realms: Dictionary[StringName, Dictionary] = {}
    var ownership_by_province: Dictionary[int, StringName] = {}
    _validate_ownership(
        ownership_data,
        ownership_realms,
        ownership_by_province,
        errors
    )
    _validate_identity(
        identity_data,
        geography_ids,
        ownership_realms,
        ownership_by_province,
        errors
    )
    return errors


static func _load_json_object(path: String, label: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Cannot load %s JSON; file does not exist: %s" % [label, path])
        return {}
    var json: JSON = JSON.new()
    var parse_error: Error = json.parse(FileAccess.get_file_as_string(path))
    if parse_error != OK:
        push_error(
            "Cannot parse %s JSON at line %d: %s (%s)"
            % [label, json.get_error_line(), json.get_error_message(), path]
        )
        return {}
    var parsed: Variant = json.data
    if not parsed is Dictionary:
        push_error("%s JSON root must be an object: %s" % [label.capitalize(), path])
        return {}
    return parsed


static func _create_validated(identity_data: Dictionary) -> RefCounted:
    var catalogue: Variant = load(
        "res://src/simulation/world_identity_catalogue.gd"
    ).new()
    catalogue._identity_data = identity_data.duplicate(true)
    for province_value: Variant in identity_data["provinces"]:
        var province: Dictionary = province_value
        var province_id: int = int(province["province_id"])
        catalogue._province_ids.append(province_id)
        catalogue._provinces_by_id[province_id] = province.duplicate(true)
    catalogue._province_ids.sort()

    for realm_value: Variant in identity_data["starting_realms"]:
        var realm: Dictionary = realm_value
        var realm_id: StringName = StringName(realm["realm_id"])
        catalogue._realm_ids.append(realm_id)
        catalogue._realms_by_id[realm_id] = realm.duplicate(true)
    catalogue._realm_ids.sort()

    for formable_value: Variant in identity_data["formables"]:
        var formable: Dictionary = formable_value
        var formable_id: StringName = StringName(formable["formable_id"])
        catalogue._formable_ids.append(formable_id)
        catalogue._formables_by_id[formable_id] = formable.duplicate(true)
    return catalogue


static func _validate_geography(
        geography_data: Dictionary,
        errors: PackedStringArray
) -> Dictionary[int, bool]:
    var ids: Dictionary[int, bool] = {}
    if not geography_data.has("provinces") or not geography_data["provinces"] is Array:
        errors.append("Province geography must contain a provinces array.")
        return ids
    for index: int in geography_data["provinces"].size():
        var value: Variant = geography_data["provinces"][index]
        if not value is Dictionary or not _is_positive_integer(value.get("id")):
            errors.append("Province geography record %d has an invalid id." % index)
            continue
        var province_id: int = int(value["id"])
        if ids.has(province_id):
            errors.append("Province geography contains duplicate province ID %d." % province_id)
        ids[province_id] = true
    if ids.size() != EXPECTED_PROVINCE_COUNT:
        errors.append(
            "Province geography must contain %d unique IDs; found %d."
            % [EXPECTED_PROVINCE_COUNT, ids.size()]
        )
    if int(geography_data.get("province_count", -1)) != ids.size():
        errors.append("Province geography declared count does not match its unique IDs.")
    return ids


static func _validate_ownership(
        ownership_data: Dictionary,
        realms_by_id: Dictionary[StringName, Dictionary],
        owner_by_province: Dictionary[int, StringName],
        errors: PackedStringArray
) -> void:
    if not ownership_data.has("realms") or not ownership_data["realms"] is Array:
        errors.append("Frozen ownership must contain a realms array.")
        return
    for index: int in ownership_data["realms"].size():
        var value: Variant = ownership_data["realms"][index]
        if not value is Dictionary:
            errors.append("Frozen ownership realm record %d must be an object." % index)
            continue
        var realm: Dictionary = value
        var realm_id_text: String = String(realm.get("realm_id", ""))
        if not _is_realm_id(realm_id_text):
            errors.append("Frozen ownership realm record %d has an invalid realm_id." % index)
            continue
        var realm_id: StringName = StringName(realm_id_text)
        if realms_by_id.has(realm_id):
            errors.append("Frozen ownership contains duplicate realm ID %s." % realm_id_text)
            continue
        realms_by_id[realm_id] = realm
        if not realm.has("province_ids") or not realm["province_ids"] is Array:
            errors.append("Frozen ownership realm %s lacks a province_ids array." % realm_id_text)
            continue
        var local_ids: Dictionary[int, bool] = {}
        for province_value: Variant in realm["province_ids"]:
            if not _is_positive_integer(province_value):
                errors.append("Frozen ownership realm %s has an invalid province ID." % realm_id_text)
                continue
            var province_id: int = int(province_value)
            if local_ids.has(province_id):
                errors.append(
                    "Frozen ownership realm %s repeats province %d."
                    % [realm_id_text, province_id]
                )
            local_ids[province_id] = true
            if owner_by_province.has(province_id):
                errors.append(
                    "Frozen ownership assigns province %d to both %s and %s."
                    % [province_id, owner_by_province[province_id], realm_id]
                )
            else:
                owner_by_province[province_id] = realm_id
    if realms_by_id.size() != EXPECTED_REALM_COUNT:
        errors.append(
            "Frozen ownership must contain %d unique realms; found %d."
            % [EXPECTED_REALM_COUNT, realms_by_id.size()]
        )
    if owner_by_province.size() != EXPECTED_PROVINCE_COUNT:
        errors.append(
            "Frozen ownership must assign %d unique provinces; found %d."
            % [EXPECTED_PROVINCE_COUNT, owner_by_province.size()]
        )
    if int(ownership_data.get("realm_count", -1)) != realms_by_id.size():
        errors.append("Frozen ownership declared realm count does not match its unique realms.")
    if int(ownership_data.get("province_count", -1)) != owner_by_province.size():
        errors.append("Frozen ownership declared province count does not match its assignments.")


static func _validate_identity(
        identity_data: Dictionary,
        geography_ids: Dictionary[int, bool],
        ownership_realms: Dictionary[StringName, Dictionary],
        ownership_by_province: Dictionary[int, StringName],
        errors: PackedStringArray
) -> void:
    var required_root_keys: Array[String] = [
        "schema_version", "canon_id", "canon_status", "purpose", "authority",
        "source_files_sha256", "global_rules", "provinces", "starting_realms",
        "formables", "regional_title_rules", "special_systems", "validation",
    ]
    _require_keys(identity_data, required_root_keys, "World identity root", errors)
    if not _is_positive_integer(identity_data.get("schema_version")) or int(identity_data["schema_version"]) != 1:
        errors.append("World identity schema_version must be 1.")
    for key: String in ["canon_id", "canon_status", "purpose", "authority"]:
        if not _is_non_empty_string(identity_data.get(key)):
            errors.append("World identity %s must be a non-empty string." % key)
    for key: String in [
        "source_files_sha256", "global_rules", "regional_title_rules",
        "special_systems", "validation",
    ]:
        if not identity_data.get(key) is Dictionary:
            errors.append("World identity %s must be an object." % key)
    for key: String in ["provinces", "starting_realms", "formables"]:
        if not identity_data.get(key) is Array:
            errors.append("World identity %s must be an array." % key)
    if not identity_data.get("provinces") is Array:
        return
    if not identity_data.get("starting_realms") is Array:
        return
    if not identity_data.get("formables") is Array:
        return

    _validate_global_guardrails(identity_data.get("global_rules", {}), errors)
    _validate_regional_title_rules(identity_data.get("regional_title_rules", {}), errors)

    var provinces_by_id: Dictionary[int, Dictionary] = {}
    _validate_identity_provinces(identity_data["provinces"], provinces_by_id, errors)
    var realms_by_id: Dictionary[StringName, Dictionary] = {}
    _validate_identity_realms(identity_data["starting_realms"], realms_by_id, errors)

    if provinces_by_id.size() != EXPECTED_PROVINCE_COUNT:
        errors.append(
            "World identity must contain %d unique provinces; found %d."
            % [EXPECTED_PROVINCE_COUNT, provinces_by_id.size()]
        )
    if realms_by_id.size() != EXPECTED_REALM_COUNT:
        errors.append(
            "World identity must contain %d unique starting realms; found %d."
            % [EXPECTED_REALM_COUNT, realms_by_id.size()]
        )

    _compare_id_sets(provinces_by_id, geography_ids, "identity", "geography", errors)
    _compare_id_sets(provinces_by_id, ownership_by_province, "identity", "ownership", errors)
    _compare_realm_sets(realms_by_id, ownership_realms, errors)
    _validate_ownership_agreement(
        provinces_by_id,
        realms_by_id,
        ownership_realms,
        ownership_by_province,
        errors
    )
    _validate_realm_identity_summaries(provinces_by_id, realms_by_id, errors)
    _validate_formables(identity_data["formables"], provinces_by_id, realms_by_id, errors)
    _validate_locked_special_cases(provinces_by_id, realms_by_id, errors)


static func _validate_identity_provinces(
        provinces: Array,
        provinces_by_id: Dictionary[int, Dictionary],
        errors: PackedStringArray
) -> void:
    var required_keys: Array[String] = [
        "province_id", "province_name", "identity_region", "culture",
        "starting_realm_id", "religion", "special_flags", "source_canon",
    ]
    var names: Dictionary[String, int] = {}
    for index: int in provinces.size():
        var value: Variant = provinces[index]
        if not value is Dictionary:
            errors.append("World identity province record %d must be an object." % index)
            continue
        var province: Dictionary = value
        var context: String = "World identity province record %d" % index
        _require_keys(province, required_keys, context, errors)
        if not _is_positive_integer(province.get("province_id")):
            errors.append("%s has an invalid province_id." % context)
            continue
        var province_id: int = int(province["province_id"])
        context = "Province %d" % province_id
        if provinces_by_id.has(province_id):
            errors.append("World identity contains duplicate province ID %d." % province_id)
            continue
        provinces_by_id[province_id] = province
        for key: String in ["province_name", "identity_region", "culture"]:
            if not _is_non_empty_string(province.get(key)):
                errors.append("%s %s must be a non-empty trimmed string." % [context, key])
        var province_name: String = String(province.get("province_name", ""))
        if not province_name.is_empty():
            if names.has(province_name):
                errors.append(
                    "Province name %s is duplicated by IDs %d and %d."
                    % [province_name, names[province_name], province_id]
                )
            names[province_name] = province_id
        if not _is_realm_id(String(province.get("starting_realm_id", ""))):
            errors.append("%s has an invalid starting_realm_id." % context)
        _validate_religion(province.get("religion"), context, errors)
        _validate_string_array(province.get("special_flags"), context + " special_flags", errors)
        if not province.get("source_canon") is Dictionary:
            errors.append("%s source_canon must be an object." % context)


static func _validate_religion(
        value: Variant,
        context: String,
        errors: PackedStringArray
) -> void:
    if not value is Dictionary:
        errors.append("%s religion must be an object." % context)
        return
    var religion: Dictionary = value
    var keys: Array[String] = [
        "broad_faith", "grand_tradition", "communion",
        "institution_or_tradition", "rite_or_belief",
    ]
    _require_keys(religion, keys, context + " religion", errors)
    if not _is_non_empty_string(religion.get("broad_faith")):
        errors.append("%s broad_faith must be a non-empty string." % context)
    if not _is_non_empty_string(religion.get("rite_or_belief")):
        errors.append("%s rite_or_belief must be a non-empty string." % context)
    for key: String in ["grand_tradition", "communion", "institution_or_tradition"]:
        var field: Variant = religion.get(key)
        if field != null and not _is_non_empty_string(field):
            errors.append("%s %s must be null or a non-empty string." % [context, key])


static func _validate_identity_realms(
        realms: Array,
        realms_by_id: Dictionary[StringName, Dictionary],
        errors: PackedStringArray
) -> void:
    var required_keys: Array[String] = [
        "realm_id", "realm_name", "realm_style", "realm_type", "display_name",
        "identity_region", "primary_culture", "primary_religious_identity",
        "starting_province_ids", "starting_cultures", "starting_broad_faiths",
        "starting_rites_or_beliefs", "special_flags", "source_canon",
    ]
    for index: int in realms.size():
        var value: Variant = realms[index]
        if not value is Dictionary:
            errors.append("Starting realm record %d must be an object." % index)
            continue
        var realm: Dictionary = value
        var context: String = "Starting realm record %d" % index
        _require_keys(realm, required_keys, context, errors)
        var realm_id_text: String = String(realm.get("realm_id", ""))
        if not _is_realm_id(realm_id_text):
            errors.append("%s has an invalid realm_id." % context)
            continue
        var realm_id: StringName = StringName(realm_id_text)
        context = "Realm %s" % realm_id_text
        if realms_by_id.has(realm_id):
            errors.append("World identity contains duplicate realm ID %s." % realm_id_text)
            continue
        realms_by_id[realm_id] = realm
        for key: String in [
            "realm_name", "realm_type", "identity_region", "primary_culture",
            "primary_religious_identity",
        ]:
            if not _is_non_empty_string(realm.get(key)):
                errors.append("%s %s must be a non-empty trimmed string." % [context, key])
        for key: String in ["realm_style", "display_name"]:
            var field: Variant = realm.get(key)
            if field != null and not _is_non_empty_string(field):
                errors.append("%s %s must be null or a non-empty string." % [context, key])
        _validate_integer_array(
            realm.get("starting_province_ids"),
            context + " starting_province_ids",
            errors
        )
        for key: String in [
            "starting_cultures", "starting_broad_faiths",
            "starting_rites_or_beliefs", "special_flags",
        ]:
            _validate_string_array(realm.get(key), context + " " + key, errors)
        if not realm.get("source_canon") is Dictionary:
            errors.append("%s source_canon must be an object." % context)
        if realm.has("source_specific") and not realm["source_specific"] is Dictionary:
            errors.append("%s source_specific must be an object when present." % context)


static func _validate_ownership_agreement(
        provinces_by_id: Dictionary[int, Dictionary],
        realms_by_id: Dictionary[StringName, Dictionary],
        ownership_realms: Dictionary[StringName, Dictionary],
        ownership_by_province: Dictionary[int, StringName],
        errors: PackedStringArray
) -> void:
    var identity_footprints: Dictionary[int, StringName] = {}
    for realm_id: StringName in realms_by_id:
        var realm: Dictionary = realms_by_id[realm_id]
        if not realm.get("starting_province_ids") is Array:
            continue
        var identity_ids: Array[int] = _sorted_integer_array(realm["starting_province_ids"])
        var ownership: Dictionary = ownership_realms.get(realm_id, {})
        var frozen_ids: Array[int] = []
        if ownership.get("province_ids") is Array:
            frozen_ids = _sorted_integer_array(ownership["province_ids"])
        if identity_ids != frozen_ids:
            errors.append(
                "Realm %s starting footprint contradicts frozen ownership: identity=%s frozen=%s."
                % [realm_id, identity_ids, frozen_ids]
            )
        for province_id: int in identity_ids:
            if identity_footprints.has(province_id):
                errors.append(
                    "World identity realm footprints assign province %d to both %s and %s."
                    % [province_id, identity_footprints[province_id], realm_id]
                )
            else:
                identity_footprints[province_id] = realm_id

    for province_id: int in provinces_by_id:
        var province: Dictionary = provinces_by_id[province_id]
        var identity_owner: StringName = StringName(province.get("starting_realm_id", ""))
        var frozen_owner: StringName = ownership_by_province.get(province_id, &"")
        var footprint_owner: StringName = identity_footprints.get(province_id, &"")
        if identity_owner != frozen_owner:
            errors.append(
                "Province %d owner contradicts frozen ownership: identity=%s frozen=%s."
                % [province_id, identity_owner, frozen_owner]
            )
        if identity_owner != footprint_owner:
            errors.append(
                "Province %d owner %s contradicts identity realm footprint %s."
                % [province_id, identity_owner, footprint_owner]
            )
        if not realms_by_id.has(identity_owner):
            errors.append("Province %d references unknown realm %s." % [province_id, identity_owner])


static func _validate_realm_identity_summaries(
        provinces_by_id: Dictionary[int, Dictionary],
        realms_by_id: Dictionary[StringName, Dictionary],
        errors: PackedStringArray
) -> void:
    for realm_id: StringName in realms_by_id:
        var realm: Dictionary = realms_by_id[realm_id]
        if not realm.get("starting_province_ids") is Array:
            continue
        var cultures: Dictionary[String, bool] = {}
        var broad_faiths: Dictionary[String, bool] = {}
        var rites: Dictionary[String, bool] = {}
        for province_value: Variant in realm["starting_province_ids"]:
            if not _is_positive_integer(province_value):
                continue
            var province_id: int = int(province_value)
            if not provinces_by_id.has(province_id):
                errors.append("Realm %s references unknown province %d." % [realm_id, province_id])
                continue
            var province: Dictionary = provinces_by_id[province_id]
            cultures[String(province.get("culture", ""))] = true
            var religion: Dictionary = province.get("religion", {})
            broad_faiths[String(religion.get("broad_faith", ""))] = true
            rites[String(religion.get("rite_or_belief", ""))] = true
        _compare_string_summary(
            realm,
            "starting_cultures",
            cultures,
            String(realm_id),
            errors
        )
        _compare_string_summary(
            realm,
            "starting_broad_faiths",
            broad_faiths,
            String(realm_id),
            errors
        )
        _compare_string_summary(
            realm,
            "starting_rites_or_beliefs",
            rites,
            String(realm_id),
            errors
        )
        if not cultures.has(String(realm.get("primary_culture", ""))):
            errors.append("Realm %s primary_culture is absent from its starting provinces." % realm_id)
        if not rites.has(String(realm.get("primary_religious_identity", ""))):
            errors.append(
                "Realm %s primary_religious_identity is absent from its starting provinces."
                % realm_id
            )


static func _compare_string_summary(
        realm: Dictionary,
        key: String,
        actual_set: Dictionary[String, bool],
        realm_id: String,
        errors: PackedStringArray
) -> void:
    if not realm.get(key) is Array:
        return
    var declared: Array[String] = []
    for value: Variant in realm[key]:
        declared.append(String(value))
    declared.sort()
    var actual: Array[String] = actual_set.keys()
    actual.sort()
    if declared != actual:
        errors.append(
            "Realm %s %s does not match its provinces: declared=%s actual=%s."
            % [realm_id, key, declared, actual]
        )


static func _validate_formables(
        formables: Array,
        provinces_by_id: Dictionary[int, Dictionary],
        realms_by_id: Dictionary[StringName, Dictionary],
        errors: PackedStringArray
) -> void:
    var formable_ids: Dictionary[String, bool] = {}
    var required_keys: Array[String] = [
        "formable_id", "formable_name", "formation_scope", "eligible_origin_realm_ids",
        "result_style", "exact_condition_status", "conceptual_condition",
        "identity_region", "source_canon_file",
    ]
    for index: int in formables.size():
        var value: Variant = formables[index]
        if not value is Dictionary:
            errors.append("Formable record %d must be an object." % index)
            continue
        var formable: Dictionary = value
        var context: String = "Formable record %d" % index
        _require_keys(formable, required_keys, context, errors)
        var formable_id: String = String(formable.get("formable_id", ""))
        if not _is_non_empty_string(formable_id):
            errors.append("%s formable_id must be a non-empty string." % context)
            continue
        context = "Formable %s" % formable_id
        if formable_ids.has(formable_id):
            errors.append("World identity contains duplicate formable ID %s." % formable_id)
            continue
        formable_ids[formable_id] = true
        for key: String in [
            "formable_name", "formation_scope", "exact_condition_status",
            "conceptual_condition", "identity_region", "source_canon_file",
        ]:
            if not _is_non_empty_string(formable.get(key)):
                errors.append("%s %s must be a non-empty string." % [context, key])
        var style: Variant = formable.get("result_style")
        if style != null and not _is_non_empty_string(style):
            errors.append("%s result_style must be null or a non-empty string." % context)
        _validate_formable_realm_field(
            formable,
            "eligible_origin_realm_ids",
            true,
            realms_by_id,
            context,
            errors
        )
        _validate_formable_realm_field(
            formable,
            "excluded_origin_realm_ids",
            false,
            realms_by_id,
            context,
            errors
        )
        if formable.has("established_realm_not_required_to_rename"):
            var established_id: StringName = StringName(
                formable["established_realm_not_required_to_rename"]
            )
            if not realms_by_id.has(established_id):
                errors.append("%s references unknown established realm %s." % [context, established_id])
        for key: String in ["required_province_ids", "required_cultural_core_province_ids"]:
            if not formable.has(key):
                continue
            _validate_integer_array(formable[key], context + " " + key, errors)
            if formable[key] is Array:
                for province_value: Variant in formable[key]:
                    if _is_positive_integer(province_value) and not provinces_by_id.has(int(province_value)):
                        errors.append(
                            "%s %s references unknown province %d."
                            % [context, key, int(province_value)]
                        )
        if formable.has("special_rules"):
            _validate_string_array(formable["special_rules"], context + " special_rules", errors)


static func _validate_formable_realm_field(
        formable: Dictionary,
        key: String,
        allow_any_realm: bool,
        realms_by_id: Dictionary[StringName, Dictionary],
        context: String,
        errors: PackedStringArray
) -> void:
    if not formable.has(key):
        return
    var value: Variant = formable[key]
    if allow_any_realm and value is String and value == "ANY_REALM":
        return
    if not value is Array:
        errors.append("%s %s must be an array%s." % [context, key, " or ANY_REALM" if allow_any_realm else ""])
        return
    _validate_string_array(value, context + " " + key, errors)
    for realm_value: Variant in value:
        var realm_id: StringName = StringName(realm_value)
        if not realms_by_id.has(realm_id):
            errors.append("%s %s references unknown realm %s." % [context, key, realm_id])


static func _validate_locked_special_cases(
        provinces_by_id: Dictionary[int, Dictionary],
        realms_by_id: Dictionary[StringName, Dictionary],
        errors: PackedStringArray
) -> void:
    var hasenmark: Dictionary = provinces_by_id.get(30, {})
    var hasenmark_religion: Dictionary = hasenmark.get("religion", {})
    if (
        hasenmark.get("province_name") != "Hasenmark"
        or hasenmark.get("identity_region") != "western"
        or hasenmark.get("culture") != "Carthen"
        or hasenmark.get("starting_realm_id") != "R028"
        or hasenmark_religion.get("broad_faith") != "Rethic Faith"
        or hasenmark_religion.get("communion") != "Crowned Communion"
        or hasenmark_religion.get("rite_or_belief") != "Rite of the Living Crown"
    ):
        errors.append("Province 30 Hasenmark locked identity/ownership separation is invalid.")
    var holy_state_ids: Array[StringName] = []
    for realm_id: StringName in realms_by_id:
        if realms_by_id[realm_id].get("realm_type") == "holy_state":
            holy_state_ids.append(realm_id)
    var seravelle: Dictionary = realms_by_id.get(&"R008", {})
    if seravelle.get("realm_type") != "holy_state":
        errors.append("R008 Seravelle must retain realm_type=holy_state.")
    if holy_state_ids.size() != 1 or holy_state_ids[0] != &"R008":
        errors.append("R008 Seravelle must be the unique holy_state starting realm.")
    var mixed_realm: Dictionary = realms_by_id.get(&"R028", {})
    var cultures: Array[String] = []
    for value: Variant in mixed_realm.get("starting_cultures", []):
        cultures.append(String(value))
    cultures.sort()
    var includes_hasenmark: bool = false
    for province_value: Variant in mixed_realm.get("starting_province_ids", []):
        includes_hasenmark = includes_hasenmark or int(province_value) == 30
    if (
        cultures.size() != 2
        or cultures[0] != "Carthen"
        or cultures[1] != "Vaskari"
        or not includes_hasenmark
    ):
        errors.append("R028 must retain mixed Carthen/Vaskari identity including Hasenmark.")


static func _validate_global_guardrails(
        rules: Variant,
        errors: PackedStringArray
) -> void:
    if not rules is Dictionary:
        return
    var locked_true_rules: Array[String] = [
        "realm_style_is_not_size_ladder",
        "ordinary_expansion_does_not_auto_rename",
        "ordinary_expansion_does_not_auto_promote_style",
        "province_identity_is_separate_from_political_ownership",
        "legacy_ownership_region_metadata_is_non_authoritative_for_identity",
        "formables_are_data_driven",
        "exact_modifier_values_are_not_locked_here",
        "exact_deferred_formation_thresholds_remain_deferred",
    ]
    for key: String in locked_true_rules:
        if rules.get(key) != true:
            errors.append("World identity global guardrail %s must be true." % key)


static func _validate_regional_title_rules(
        rules: Variant,
        errors: PackedStringArray
) -> void:
    if not rules is Dictionary:
        return
    for region: String in ["western", "northern", "mediterranean", "central", "eastern"]:
        if not rules.get(region) is Dictionary:
            errors.append("Regional title rules must define %s as an object." % region)
            continue
        var region_rules: Dictionary = rules[region]
        for key: String in [
            "style_is_size_ladder", "ordinary_expansion_changes_style_automatically",
            "ordinary_expansion_changes_name_automatically",
        ]:
            if region_rules.get(key) != false:
                errors.append("Regional title rule %s.%s must be false." % [region, key])


static func _compare_id_sets(
        identity_ids: Dictionary,
        authority_ids: Dictionary,
        identity_label: String,
        authority_label: String,
        errors: PackedStringArray
) -> void:
    for id: Variant in identity_ids:
        if not authority_ids.has(id):
            errors.append("Province ID %d exists in %s but not %s." % [id, identity_label, authority_label])
    for id: Variant in authority_ids:
        if not identity_ids.has(id):
            errors.append("Province ID %d exists in %s but not %s." % [id, authority_label, identity_label])


static func _compare_realm_sets(
        identity_realms: Dictionary[StringName, Dictionary],
        ownership_realms: Dictionary[StringName, Dictionary],
        errors: PackedStringArray
) -> void:
    for realm_id: StringName in identity_realms:
        if not ownership_realms.has(realm_id):
            errors.append("Realm %s exists in identity but not frozen ownership." % realm_id)
    for realm_id: StringName in ownership_realms:
        if not identity_realms.has(realm_id):
            errors.append("Realm %s exists in frozen ownership but not identity." % realm_id)


static func _require_keys(
        record: Dictionary,
        required_keys: Array[String],
        context: String,
        errors: PackedStringArray
) -> void:
    for key: String in required_keys:
        if not record.has(key):
            errors.append("%s is missing required field %s." % [context, key])


static func _validate_integer_array(
        value: Variant,
        context: String,
        errors: PackedStringArray
) -> void:
    if not value is Array:
        errors.append("%s must be an array." % context)
        return
    var seen: Dictionary[int, bool] = {}
    for item: Variant in value:
        if not _is_positive_integer(item):
            errors.append("%s contains a non-positive or non-integer value." % context)
            continue
        var id: int = int(item)
        if seen.has(id):
            errors.append("%s contains duplicate ID %d." % [context, id])
        seen[id] = true


static func _validate_string_array(
        value: Variant,
        context: String,
        errors: PackedStringArray
) -> void:
    if not value is Array:
        errors.append("%s must be an array." % context)
        return
    var seen: Dictionary[String, bool] = {}
    for item: Variant in value:
        if not _is_non_empty_string(item):
            errors.append("%s contains an empty or non-string value." % context)
            continue
        var text: String = item
        if seen.has(text):
            errors.append("%s contains duplicate value %s." % [context, text])
        seen[text] = true


static func _sorted_integer_array(values: Array) -> Array[int]:
    var result: Array[int] = []
    for value: Variant in values:
        if _is_positive_integer(value):
            result.append(int(value))
    result.sort()
    return result


static func _is_positive_integer(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return value > 0
    return typeof(value) == TYPE_FLOAT and value > 0.0 and is_equal_approx(value, roundf(value))


static func _is_non_empty_string(value: Variant) -> bool:
    return (
        typeof(value) == TYPE_STRING
        and not String(value).is_empty()
        and String(value) == String(value).strip_edges()
    )


static func _is_realm_id(value: String) -> bool:
    if value.length() != 4 or not value.begins_with("R"):
        return false
    return value.substr(1).is_valid_int() and int(value.substr(1)) > 0


func get_province_count() -> int:
    return _province_ids.size()


func get_realm_count() -> int:
    return _realm_ids.size()


func get_formable_count() -> int:
    return _formable_ids.size()


func get_province_ids() -> PackedInt32Array:
    return _province_ids.duplicate()


func get_realm_ids() -> Array[StringName]:
    return _realm_ids.duplicate()


func get_formable_ids() -> Array[StringName]:
    return _formable_ids.duplicate()


func get_province_identity(province_id: int) -> Dictionary:
    if not _provinces_by_id.has(province_id):
        return {}
    return _provinces_by_id[province_id].duplicate(true)


func get_realm_identity(realm_id: StringName) -> Dictionary:
    if not _realms_by_id.has(realm_id):
        return {}
    return _realms_by_id[realm_id].duplicate(true)


func get_starting_realm_for_province(province_id: int) -> Dictionary:
    var province: Dictionary = get_province_identity(province_id)
    if province.is_empty():
        return {}
    return get_realm_identity(StringName(province["starting_realm_id"]))


func get_starting_province_ids_for_realm(realm_id: StringName) -> PackedInt32Array:
    var result: PackedInt32Array = []
    var realm: Dictionary = get_realm_identity(realm_id)
    for province_value: Variant in realm.get("starting_province_ids", []):
        result.append(int(province_value))
    return result


func get_formable(formable_id: StringName) -> Dictionary:
    if not _formables_by_id.has(formable_id):
        return {}
    return _formables_by_id[formable_id].duplicate(true)


func get_global_rules() -> Dictionary:
    return _identity_data["global_rules"].duplicate(true)


func get_regional_title_rules() -> Dictionary:
    return _identity_data["regional_title_rules"].duplicate(true)


func get_special_systems() -> Dictionary:
    return _identity_data["special_systems"].duplicate(true)
