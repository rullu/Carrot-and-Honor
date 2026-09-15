extends SceneTree


const WorldIdentityCatalogueScript: GDScript = preload(
    "res://src/simulation/world_identity_catalogue.gd"
)
const MASTER_DATA_SHA256: String = "a05c067bdde05322e2f60372c6e2a75364befef3d13c97e03a3ba81cab08de93"


var _failures: int = 0


func _initialize() -> void:
    var catalogue: RefCounted = WorldIdentityCatalogueScript.load_default()
    _check(catalogue != null, "canonical world identity loads")
    if catalogue == null:
        _finish()
        return

    _check(catalogue.get_province_count() == 100, "exactly 100 provinces load")
    _check(catalogue.get_realm_count() == 43, "exactly 43 starting realms load")
    _check(catalogue.get_formable_count() == 19, "all 19 current formables load")
    var actual_master_hash: String = FileAccess.get_sha256(
        WorldIdentityCatalogueScript.DEFAULT_IDENTITY_PATH
    )
    _check(
        actual_master_hash.to_lower() == MASTER_DATA_SHA256,
        "repository master JSON is byte-identical to the accepted input (%s)"
        % actual_master_hash
    )
    _check(catalogue.get_province_ids().size() == 100, "province IDs are unique")
    _check(catalogue.get_realm_ids().size() == 43, "realm IDs are unique")

    _check_province(
        catalogue,
        30,
        "Hasenmark",
        "Carthen",
        "Rethic Faith",
        "Crowned Communion",
        "Rite of the Living Crown",
        "R028"
    )
    _check_province(
        catalogue,
        51,
        "Seravelle",
        "Velaine",
        "Rethic Faith",
        "Crowned Communion",
        "Rite of the Living Crown",
        "R008"
    )
    _check_province(
        catalogue,
        32,
        "Eldsund",
        "Eldskar",
        "Hearthbound Faith",
        null,
        "Rite of the Buried Ember",
        "R009"
    )
    _check_province(
        catalogue,
        53,
        "Conejolandia",
        "Saleran",
        "Rethic Faith",
        "Crowned Communion",
        "Rite of First Light",
        "R012"
    )
    _check_province(
        catalogue,
        99,
        "Zahraim Darun",
        "Qasren",
        "Way of Aven",
        null,
        "Rite of the Veiled Spring",
        "R038"
    )

    var r008: Dictionary = catalogue.get_realm_identity(&"R008")
    _check(r008.get("realm_type") == "holy_state", "R008 remains the unique holy_state")
    _check(r008.get("realm_style") == null, "R008 ceremonial style remains deferred")
    var r028: Dictionary = catalogue.get_realm_identity(&"R028")
    _check(r028.get("display_name") == "Banate of Vel-Kareth", "R028 name loads")
    _check(r028.get("starting_cultures") == ["Carthen", "Vaskari"], "R028 is mixed Carthen/Vaskari")
    var r028_includes_hasenmark: bool = false
    for province_value: Variant in r028.get("starting_province_ids", []):
        r028_includes_hasenmark = r028_includes_hasenmark or int(province_value) == 30
    _check(r028_includes_hasenmark, "R028 includes Hasenmark")
    _check(
        catalogue.get_starting_province_ids_for_realm(&"R028")
        == PackedInt32Array([30, 16, 20, 19]),
        "R028 starting footprint is exposed as integer province IDs"
    )
    _check(
        r028.get("special_flags", []).has("mixed_culture_religion_realm"),
        "R028 mixed-identity flag loads"
    )
    _check(
        catalogue.get_realm_identity(&"R030").get("display_name") == "Empire of Vorthyrion",
        "R030 display name loads"
    )
    _check(
        catalogue.get_realm_identity(&"R043").get("display_name") == "Sultanate of Samera",
        "R043 display name loads"
    )
    _check(
        catalogue.get_realm_identity(&"R035").get("display_name") == "Kingdom of Qasrûn",
        "UTF-8 realm names round-trip"
    )
    _check(
        catalogue.get_formable(&"EAST_TOTAL_AVENUR").get("required_province_ids", []).size() == 19,
        "formable province metadata loads"
    )
    _check(
        catalogue.get_special_systems().get("eastern", {}).has("deep_wells"),
        "special-system metadata loads without executing it"
    )

    _check_defensive_queries(catalogue)
    _check_rejection_paths()
    _finish()


func _check_province(
        catalogue: RefCounted,
        province_id: int,
        expected_name: String,
        expected_culture: String,
        expected_broad_faith: String,
        expected_communion: Variant,
        expected_rite: String,
        expected_owner: String
) -> void:
    var province: Dictionary = catalogue.get_province_identity(province_id)
    var religion: Dictionary = province.get("religion", {})
    _check(province.get("province_name") == expected_name, "province %d name loads" % province_id)
    _check(province.get("culture") == expected_culture, "province %d culture loads" % province_id)
    _check(religion.get("broad_faith") == expected_broad_faith, "province %d broad faith loads" % province_id)
    _check(religion.get("communion") == expected_communion, "province %d communion loads" % province_id)
    _check(religion.get("rite_or_belief") == expected_rite, "province %d rite/belief loads" % province_id)
    _check(province.get("starting_realm_id") == expected_owner, "province %d owner loads" % province_id)


func _check_defensive_queries(catalogue: RefCounted) -> void:
    var province: Dictionary = catalogue.get_province_identity(30)
    province["province_name"] = "Changed"
    province["religion"]["rite_or_belief"] = "Changed"
    var fresh_province: Dictionary = catalogue.get_province_identity(30)
    _check(fresh_province["province_name"] == "Hasenmark", "province query is defensive")
    _check(
        fresh_province["religion"]["rite_or_belief"] == "Rite of the Living Crown",
        "nested province query data is defensive"
    )
    var systems: Dictionary = catalogue.get_special_systems()
    systems.clear()
    _check(not catalogue.get_special_systems().is_empty(), "special-system query is defensive")


func _check_rejection_paths() -> void:
    var identity: Dictionary = _load_json(WorldIdentityCatalogueScript.DEFAULT_IDENTITY_PATH)
    var ownership: Dictionary = _load_json(WorldIdentityCatalogueScript.DEFAULT_OWNERSHIP_PATH)
    var geography: Dictionary = _load_json(WorldIdentityCatalogueScript.DEFAULT_GEOGRAPHY_PATH)

    var duplicate_data: Dictionary = identity.duplicate(true)
    duplicate_data["provinces"].append(duplicate_data["provinces"][0].duplicate(true))
    _check_errors_contain(
        WorldIdentityCatalogueScript.validate_documents(duplicate_data, ownership, geography),
        "duplicate province ID",
        "duplicate province IDs fail validation"
    )

    var malformed_data: Dictionary = identity.duplicate(true)
    malformed_data["provinces"][0].erase("culture")
    _check_errors_contain(
        WorldIdentityCatalogueScript.validate_documents(malformed_data, ownership, geography),
        "missing required field culture",
        "missing required province fields fail validation"
    )

    var contradictory_data: Dictionary = identity.duplicate(true)
    for province: Dictionary in contradictory_data["provinces"]:
        if int(province["province_id"]) == 30:
            province["starting_realm_id"] = "R027"
            break
    _check_errors_contain(
        WorldIdentityCatalogueScript.validate_documents(contradictory_data, ownership, geography),
        "contradicts frozen ownership",
        "contradictory starting ownership fails validation"
    )

    var bad_formable_data: Dictionary = identity.duplicate(true)
    bad_formable_data["formables"][0]["eligible_origin_realm_ids"].append("R999")
    _check_errors_contain(
        WorldIdentityCatalogueScript.validate_documents(bad_formable_data, ownership, geography),
        "references unknown realm R999",
        "unknown formable realm references fail validation"
    )


func _load_json(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if parsed is Dictionary:
        return parsed
    return {}


func _check_errors_contain(
        errors: PackedStringArray,
        expected_fragment: String,
        message: String
) -> void:
    for error: String in errors:
        if expected_fragment in error:
            _check(true, message)
            return
    _check(false, "%s (missing diagnostic: %s)" % [message, expected_fragment])


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures > 0:
        push_error("World identity catalogue test FAIL: %d check(s) failed." % _failures)
        quit(1)
        return
    print(
        "World identity catalogue test PASS: 100 provinces, 43 realms, ownership, "
        + "mixed identity, formables, special systems, UTF-8, and rejection paths validated."
    )
    quit(0)
