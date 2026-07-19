extends SceneTree


var _failure_count: int = 0


func _initialize() -> void:
    _test_valid_grain_farm_definition()
    _test_invalid_data_rejection()

    if _failure_count > 0:
        push_error("Building definition test FAIL: %d assertion(s) failed." % _failure_count)
        quit(1)
        return

    print("Building definition test PASS: pure-data definition checks succeeded.")
    quit(0)


func _test_valid_grain_farm_definition() -> void:
    var grain_farm_data: Dictionary = {
        "building_id": &"building_grain_farm",
        "display_name": "Grain Farm",
    }
    var first_definition: BuildingDefinition = BuildingDefinition.create_from_data(grain_farm_data)
    var second_definition: BuildingDefinition = BuildingDefinition.create_from_data(grain_farm_data)

    _expect_not_null(first_definition, "first valid grain-farm definition")
    _expect_not_null(second_definition, "second valid grain-farm definition")
    if first_definition == null or second_definition == null:
        return

    _expect_equal(first_definition.get_building_id(), &"building_grain_farm", "grain-farm ID")
    _expect_equal(first_definition.get_display_name(), "Grain Farm", "grain-farm display name")

    var definitions_by_id: Dictionary[StringName, BuildingDefinition] = {}
    definitions_by_id[first_definition.get_building_id()] = first_definition
    _expect_same(
        definitions_by_id[&"building_grain_farm"],
        first_definition,
        "stable building ID dictionary lookup"
    )

    _expect_different(first_definition, second_definition, "independent definition objects")
    _expect_equal(
        second_definition.get_building_id(),
        first_definition.get_building_id(),
        "matching instance IDs"
    )
    _expect_equal(
        second_definition.get_display_name(),
        first_definition.get_display_name(),
        "matching instance display names"
    )

    grain_farm_data["building_id"] = &"building_bakery"
    grain_farm_data["display_name"] = "Bakery"
    _expect_equal(
        first_definition.get_building_id(),
        &"building_grain_farm",
        "first instance ID after source mutation"
    )
    _expect_equal(
        first_definition.get_display_name(),
        "Grain Farm",
        "first instance name after source mutation"
    )
    _expect_equal(
        second_definition.get_building_id(),
        &"building_grain_farm",
        "second instance ID after source mutation"
    )
    _expect_equal(
        second_definition.get_display_name(),
        "Grain Farm",
        "second instance name after source mutation"
    )


func _test_invalid_data_rejection() -> void:
    _expect_rejected({"display_name": "Grain Farm"}, "missing building ID")
    _expect_rejected({"building_id": &"building_grain_farm"}, "missing display name")
    _expect_rejected(
        {"building_id": &"building_grain_farm", "display_name": "Grain Farm", "unexpected": true},
        "unexpected field"
    )
    _expect_rejected(
        {"building_id": "building_grain_farm", "display_name": "Grain Farm"},
        "String building ID"
    )
    _expect_rejected(
        {"building_id": &"building_grain_farm", "display_name": &"Grain Farm"},
        "StringName display name"
    )
    _expect_rejected(
        {"building_id": &"site_grain_farm", "display_name": "Grain Farm"},
        "wrong building prefix"
    )
    _expect_rejected({"building_id": &"building_", "display_name": "Grain Farm"}, "empty suffix")
    _expect_rejected(
        {"building_id": &"building__grain_farm", "display_name": "Grain Farm"},
        "leading suffix underscore"
    )
    _expect_rejected(
        {"building_id": &"building_grain_farm_", "display_name": "Grain Farm"},
        "trailing suffix underscore"
    )
    _expect_rejected(
        {"building_id": &"building_grain__farm", "display_name": "Grain Farm"},
        "consecutive suffix underscores"
    )
    _expect_rejected(
        {"building_id": &"building_Grain_farm", "display_name": "Grain Farm"},
        "uppercase building ID"
    )
    _expect_rejected(
        {"building_id": &"building_grain farm", "display_name": "Grain Farm"},
        "space in building ID"
    )
    _expect_rejected(
        {"building_id": &"building_grain-farm", "display_name": "Grain Farm"},
        "hyphen in building ID"
    )
    _expect_rejected(
        {"building_id": &"building_grain_farm", "display_name": ""},
        "empty display name"
    )
    _expect_rejected(
        {"building_id": &"building_grain_farm", "display_name": " Grain Farm"},
        "leading display whitespace"
    )
    _expect_rejected(
        {"building_id": &"building_grain_farm", "display_name": "Grain Farm "},
        "trailing display whitespace"
    )


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


func _expect_different(actual: Object, expected: Object, context: String) -> void:
    if actual != expected:
        return

    _failure_count += 1
    push_error("%s: expected different objects." % context)
