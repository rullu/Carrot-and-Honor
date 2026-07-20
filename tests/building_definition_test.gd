extends SceneTree


var _failure_count: int = 0


func _initialize() -> void:
    _test_authoritative_buildings()
    _test_dictionary_key()
    _test_missing_and_unexpected_fields()
    _test_incorrect_types()
    _test_malformed_ids()
    _test_display_names()
    _test_placement_kinds()

    if _failure_count > 0:
        push_error("Building definition test FAIL: %d assertion(s) failed." % _failure_count)
        quit(1)
        return

    print("Building definition test PASS: all pure-data definition checks succeeded.")
    quit(0)


func _test_authoritative_buildings() -> void:
    _verify_building(&"building_farm", "Farm", &"rural_site")
    _verify_building(&"building_mill", "Mill", &"rural_site")
    _verify_building(
        &"building_bakery",
        "Bakery",
        &"major_city_workshop"
    )


func _test_dictionary_key() -> void:
    var farm: BuildingDefinition = _create_building(
        &"building_farm",
        "Farm",
        &"rural_site"
    )
    _expect_not_null(farm, "Farm dictionary-key definition")
    if farm == null:
        return

    var definitions_by_id: Dictionary[StringName, BuildingDefinition] = {}
    definitions_by_id[farm.get_building_id()] = farm
    _expect_same(
        definitions_by_id[&"building_farm"],
        farm,
        "StringName building ID dictionary lookup"
    )


func _test_missing_and_unexpected_fields() -> void:
    var valid_data: Dictionary = _valid_farm_data()
    for missing_key: String in BuildingDefinition.REQUIRED_KEYS:
        var incomplete_data: Dictionary = valid_data.duplicate()
        incomplete_data.erase(missing_key)
        _expect_rejected(incomplete_data, "missing field: " + missing_key)

    var unexpected_data: Dictionary = valid_data.duplicate()
    unexpected_data["unexpected"] = true
    _expect_rejected(unexpected_data, "unexpected field")


func _test_incorrect_types() -> void:
    var valid_data: Dictionary = _valid_farm_data()
    _expect_rejected_with_field(
        valid_data,
        "building_id",
        "building_farm",
        "String building ID"
    )
    _expect_rejected_with_field(
        valid_data,
        "display_name",
        &"Farm",
        "StringName display name"
    )
    _expect_rejected_with_field(
        valid_data,
        "placement_kind",
        "rural_site",
        "String placement kind"
    )


func _test_malformed_ids() -> void:
    var malformed_ids: Array[StringName] = [
        &"farm",
        &"building_",
        &"building__farm",
        &"building_farm_",
        &"building_grain__farm",
        &"building_Farm",
        &"building_grain farm",
        &"building_grain-farm",
        &"building.farm",
    ]
    var descriptions: Array[String] = [
        "missing prefix",
        "empty suffix",
        "leading suffix underscore",
        "trailing underscore",
        "repeated underscores",
        "uppercase letters",
        "spaces",
        "punctuation",
        "dotted ID",
    ]

    for index: int in range(malformed_ids.size()):
        var invalid_data: Dictionary = _valid_farm_data()
        invalid_data["building_id"] = malformed_ids[index]
        _expect_rejected(
            invalid_data,
            "malformed building ID: " + descriptions[index]
        )


func _test_display_names() -> void:
    _expect_rejected_with_field(
        _valid_farm_data(),
        "display_name",
        "",
        "empty display name"
    )
    _expect_rejected_with_field(
        _valid_farm_data(),
        "display_name",
        " Farm",
        "leading display-name whitespace"
    )
    _expect_rejected_with_field(
        _valid_farm_data(),
        "display_name",
        "Farm ",
        "trailing display-name whitespace"
    )


func _test_placement_kinds() -> void:
    _expect_not_null(
        _create_building(&"building_farm", "Farm", &"rural_site"),
        "supported rural-site placement"
    )
    _expect_not_null(
        _create_building(
            &"building_bakery",
            "Bakery",
            &"major_city_workshop"
        ),
        "supported major-city-workshop placement"
    )
    _expect_rejected_with_field(
        _valid_farm_data(),
        "placement_kind",
        &"village",
        "unsupported placement kind"
    )


func _verify_building(
        building_id: StringName,
        display_name: String,
        placement_kind: StringName
) -> void:
    var definition: BuildingDefinition = _create_building(
        building_id,
        display_name,
        placement_kind
    )
    _expect_not_null(definition, display_name + " construction")
    if definition == null:
        return

    _expect_equal(
        definition.get_building_id(),
        building_id,
        display_name + " building ID"
    )
    _expect_equal(
        definition.get_display_name(),
        display_name,
        display_name + " display name"
    )
    _expect_equal(
        definition.get_placement_kind(),
        placement_kind,
        display_name + " placement kind"
    )


func _valid_farm_data() -> Dictionary:
    return {
        "building_id": &"building_farm",
        "display_name": "Farm",
        "placement_kind": &"rural_site",
    }


func _create_building(
        building_id: StringName,
        display_name: String,
        placement_kind: StringName
) -> BuildingDefinition:
    return BuildingDefinition.create_from_data({
        "building_id": building_id,
        "display_name": display_name,
        "placement_kind": placement_kind,
    })


func _expect_rejected_with_field(
        source_data: Dictionary,
        field: String,
        invalid_value: Variant,
        context: String
) -> void:
    var invalid_data: Dictionary = source_data.duplicate()
    invalid_data[field] = invalid_value
    _expect_rejected(invalid_data, context)


func _expect_rejected(data: Dictionary, context: String) -> void:
    _expect_null(BuildingDefinition.create_from_data(data), context)


func _expect_equal(actual: Variant, expected: Variant, context: String) -> void:
    if actual == expected:
        return
    _failure_count += 1
    push_error("%s: expected %s, got %s." % [context, expected, actual])


func _expect_null(actual: Variant, context: String) -> void:
    if actual == null:
        return
    _failure_count += 1
    push_error("%s: expected null." % context)


func _expect_not_null(actual: Variant, context: String) -> void:
    if actual != null:
        return
    _failure_count += 1
    push_error("%s: expected a BuildingDefinition." % context)


func _expect_same(actual: Object, expected: Object, context: String) -> void:
    if actual == expected:
        return
    _failure_count += 1
    push_error("%s: expected the same object." % context)
