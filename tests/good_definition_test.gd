extends SceneTree


var _failure_count: int = 0


func _initialize() -> void:
    _test_authoritative_goods_construct()
    _test_dictionary_keys_and_instance_independence()
    _test_exact_fields()
    _test_incorrect_types()
    _test_malformed_ids()
    _test_display_names()
    _test_capability_validation()

    if _failure_count > 0:
        push_error("Good definition test FAIL: %d assertion(s) failed." % _failure_count)
        quit(1)
        return

    print("Good definition test PASS: all pure-data definition checks succeeded.")
    quit(0)


func _test_authoritative_goods_construct() -> void:
    _expect_not_null(
        _create_good(&"good_timber", "Timber", &"automatic_local", &"", []),
        "Timber construction"
    )
    _expect_not_null(
        _create_good(
            &"good_firewood",
            "Firewood",
            &"automatic_local",
            &"",
            [&"good_timber"]
        ),
        "Firewood construction"
    )
    _expect_not_null(
        _create_good(
            &"good_grain",
            "Grain",
            &"building_provided",
            &"building_farm",
            []
        ),
        "Grain construction"
    )
    _expect_not_null(
        _create_good(
            &"good_flour",
            "Flour",
            &"building_provided",
            &"building_mill",
            [&"good_grain"]
        ),
        "Flour construction"
    )
    _expect_not_null(
        _create_good(
            &"good_bread",
            "Bread",
            &"building_provided",
            &"building_bakery",
            [&"good_flour", &"good_firewood"]
        ),
        "Bread construction"
    )


func _test_dictionary_keys_and_instance_independence() -> void:
    var source_requirements: Array[StringName] = [&"good_flour", &"good_firewood"]
    var source_data: Dictionary = _good_data(
        &"good_bread",
        "Bread",
        &"building_provided",
        &"building_bakery",
        source_requirements
    )
    var first: GoodDefinition = GoodDefinition.create_from_data(source_data)
    var second: GoodDefinition = GoodDefinition.create_from_data(source_data)

    _expect_not_null(first, "first independent Bread definition")
    _expect_not_null(second, "second independent Bread definition")
    if first == null or second == null:
        return

    _expect_different(first, second, "independent definition objects")

    var definitions_by_id: Dictionary[StringName, GoodDefinition] = {}
    definitions_by_id[first.get_good_id()] = first
    _expect_same(
        definitions_by_id[&"good_bread"],
        first,
        "StringName good ID dictionary lookup"
    )

    source_requirements.clear()
    _expect_required_ids(
        first.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "first instance after source-array mutation"
    )
    _expect_required_ids(
        second.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "second instance after source-array mutation"
    )

    var first_returned_requirements: Array[StringName] = first.get_required_good_ids()
    first_returned_requirements.clear()
    _expect_required_ids(
        first.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "first instance after returned-array mutation"
    )
    _expect_required_ids(
        second.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "second instance after first returned-array mutation"
    )

    var second_returned_requirements: Array[StringName] = second.get_required_good_ids()
    second_returned_requirements.append(&"good_grain")
    _expect_required_ids(
        first.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "first instance after second returned-array mutation"
    )
    _expect_required_ids(
        second.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "second instance after its returned-array mutation"
    )


func _test_exact_fields() -> void:
    var bread: GoodDefinition = _create_good(
        &"good_bread",
        "Bread",
        &"building_provided",
        &"building_bakery",
        [&"good_flour", &"good_firewood"]
    )
    _expect_not_null(bread, "Bread exact-field definition")
    if bread == null:
        return

    _expect_equal(bread.get_good_id(), &"good_bread", "Bread good ID")
    _expect_equal(bread.get_display_name(), "Bread", "Bread display name")
    _expect_equal(bread.get_scope_kind(), &"province_local", "Bread scope kind")
    _expect_equal(
        bread.get_availability_kind(),
        &"building_provided",
        "Bread availability kind"
    )
    _expect_equal(
        bread.get_provider_building_id(),
        &"building_bakery",
        "Bread provider building ID"
    )
    _expect_required_ids(
        bread.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "Bread prerequisites"
    )


func _test_incorrect_types() -> void:
    var valid_data: Dictionary = _valid_grain_data()
    _expect_rejected_with_field(valid_data, "good_id", "good_grain", "String good ID")
    _expect_rejected_with_field(
        valid_data,
        "display_name",
        &"Grain",
        "StringName display name"
    )
    _expect_rejected_with_field(
        valid_data,
        "scope_kind",
        "province_local",
        "String scope kind"
    )
    _expect_rejected_with_field(
        valid_data,
        "availability_kind",
        "building_provided",
        "String availability kind"
    )
    _expect_rejected_with_field(
        valid_data,
        "provider_building_id",
        "building_farm",
        "String provider building ID"
    )
    _expect_rejected_with_field(
        valid_data,
        "required_good_ids",
        &"good_timber",
        "non-array prerequisites"
    )

    var wrong_entry_data: Dictionary = valid_data.duplicate(true)
    wrong_entry_data["required_good_ids"] = [&"good_timber", "good_firewood"]
    _expect_rejected(wrong_entry_data, "String prerequisite entry")


func _test_malformed_ids() -> void:
    var malformed_ids: Array[StringName] = [
        &"grain",
        &"good_",
        &"good__grain",
        &"good_grain_",
        &"good_grain__seed",
        &"good_Grain",
        &"good_grain seed",
        &"good_grain-seed",
        &"good.grain",
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
        var invalid_data: Dictionary = _valid_grain_data()
        invalid_data["good_id"] = malformed_ids[index]
        _expect_rejected(invalid_data, "malformed good ID: " + descriptions[index])


func _test_display_names() -> void:
    _expect_rejected_with_field(
        _valid_grain_data(),
        "display_name",
        "",
        "empty display name"
    )
    _expect_rejected_with_field(
        _valid_grain_data(),
        "display_name",
        " Grain",
        "leading display-name whitespace"
    )
    _expect_rejected_with_field(
        _valid_grain_data(),
        "display_name",
        "Grain ",
        "trailing display-name whitespace"
    )


func _test_capability_validation() -> void:
    var valid_data: Dictionary = _valid_grain_data()
    for missing_key: String in GoodDefinition.REQUIRED_KEYS:
        var incomplete_data: Dictionary = valid_data.duplicate(true)
        incomplete_data.erase(missing_key)
        _expect_rejected(incomplete_data, "missing field: " + missing_key)

    var unexpected_data: Dictionary = valid_data.duplicate(true)
    unexpected_data["unexpected"] = true
    _expect_rejected(unexpected_data, "unexpected field")

    _expect_rejected_with_field(
        valid_data,
        "scope_kind",
        &"global",
        "unsupported scope kind"
    )
    _expect_rejected_with_field(
        valid_data,
        "availability_kind",
        &"inventory",
        "unsupported availability kind"
    )
    _expect_rejected(
        _good_data(
            &"good_timber",
            "Timber",
            &"automatic_local",
            &"building_farm",
            []
        ),
        "automatic-local good with provider"
    )
    _expect_rejected(
        _good_data(
            &"good_grain",
            "Grain",
            &"building_provided",
            &"",
            []
        ),
        "building-provided good without provider"
    )
    _expect_rejected(
        _good_data(
            &"good_grain",
            "Grain",
            &"building_provided",
            &"farm",
            []
        ),
        "malformed provider building ID"
    )
    _expect_rejected(
        _good_data(
            &"good_flour",
            "Flour",
            &"building_provided",
            &"building_mill",
            [&"grain"]
        ),
        "malformed prerequisite good ID"
    )
    _expect_rejected(
        _good_data(
            &"good_flour",
            "Flour",
            &"building_provided",
            &"building_mill",
            [&"good_grain", &"good_grain"]
        ),
        "duplicate prerequisites"
    )
    _expect_rejected(
        _good_data(
            &"good_flour",
            "Flour",
            &"building_provided",
            &"building_mill",
            [&"good_flour"]
        ),
        "direct self-dependency"
    )


func _valid_grain_data() -> Dictionary:
    return _good_data(
        &"good_grain",
        "Grain",
        &"building_provided",
        &"building_farm",
        []
    )


func _good_data(
        good_id: StringName,
        display_name: String,
        availability_kind: StringName,
        provider_building_id: StringName,
        required_good_ids: Array[StringName]
) -> Dictionary:
    return {
        "good_id": good_id,
        "display_name": display_name,
        "scope_kind": &"province_local",
        "availability_kind": availability_kind,
        "provider_building_id": provider_building_id,
        "required_good_ids": required_good_ids,
    }


func _create_good(
        good_id: StringName,
        display_name: String,
        availability_kind: StringName,
        provider_building_id: StringName,
        required_good_ids: Array[StringName]
) -> GoodDefinition:
    return GoodDefinition.create_from_data(
        _good_data(
            good_id,
            display_name,
            availability_kind,
            provider_building_id,
            required_good_ids
        )
    )


func _expect_rejected_with_field(
        source_data: Dictionary,
        field: String,
        invalid_value: Variant,
        context: String
) -> void:
    var invalid_data: Dictionary = source_data.duplicate(true)
    invalid_data[field] = invalid_value
    _expect_rejected(invalid_data, context)


func _expect_rejected(data: Dictionary, context: String) -> void:
    _expect_null(GoodDefinition.create_from_data(data), context)


func _expect_required_ids(
        actual: Array[StringName],
        expected: Array[StringName],
        context: String
) -> void:
    _expect_equal(actual.size(), expected.size(), context + " length")
    for index: int in range(mini(actual.size(), expected.size())):
        _expect_equal(actual[index], expected[index], context + " item %d" % index)


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
    push_error("%s: expected a GoodDefinition." % context)


func _expect_same(actual: Object, expected: Object, context: String) -> void:
    if actual == expected:
        return
    _failure_count += 1
    push_error("%s: expected the same object." % context)


func _expect_different(actual: Object, expected: Object, context: String) -> void:
    if actual != expected:
        return
    _failure_count += 1
    push_error("%s: expected different objects." % context)
