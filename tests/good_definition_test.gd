extends SceneTree


var _failure_count: int = 0


func _initialize() -> void:
    _test_valid_grain_definition()
    _test_invalid_data_rejection()

    if _failure_count > 0:
        push_error("Good definition test FAIL: %d assertion(s) failed." % _failure_count)
        quit(1)
        return

    print("Good definition test PASS: pure-data definition checks succeeded.")
    quit(0)


func _test_valid_grain_definition() -> void:
    var grain_data: Dictionary = {
        "good_id": &"good_grain",
        "display_name": "Grain",
    }
    var first_definition: GoodDefinition = GoodDefinition.create_from_data(grain_data)
    var second_definition: GoodDefinition = GoodDefinition.create_from_data(grain_data)

    _expect_not_null(first_definition, "first valid grain definition")
    _expect_not_null(second_definition, "second valid grain definition")
    if first_definition == null or second_definition == null:
        return

    _expect_equal(first_definition.get_good_id(), &"good_grain", "grain ID")
    _expect_equal(first_definition.get_display_name(), "Grain", "grain display name")

    var definitions_by_id: Dictionary[StringName, GoodDefinition] = {}
    definitions_by_id[first_definition.get_good_id()] = first_definition
    _expect_same(definitions_by_id[&"good_grain"], first_definition, "stable ID dictionary lookup")

    _expect_different(first_definition, second_definition, "independent definition objects")
    _expect_equal(second_definition.get_good_id(), first_definition.get_good_id(), "matching instance IDs")
    _expect_equal(
        second_definition.get_display_name(),
        first_definition.get_display_name(),
        "matching instance display names"
    )

    grain_data["good_id"] = &"good_flour"
    grain_data["display_name"] = "Flour"
    _expect_equal(first_definition.get_good_id(), &"good_grain", "first instance ID after source mutation")
    _expect_equal(first_definition.get_display_name(), "Grain", "first instance name after source mutation")
    _expect_equal(second_definition.get_good_id(), &"good_grain", "second instance ID after source mutation")
    _expect_equal(second_definition.get_display_name(), "Grain", "second instance name after source mutation")


func _test_invalid_data_rejection() -> void:
    _expect_rejected({"display_name": "Grain"}, "missing good ID")
    _expect_rejected({"good_id": &"good_grain"}, "missing display name")
    _expect_rejected(
        {"good_id": &"good_grain", "display_name": "Grain", "unexpected": true},
        "unexpected field"
    )
    _expect_rejected({"good_id": "good_grain", "display_name": "Grain"}, "String good ID")
    _expect_rejected({"good_id": &"good_grain", "display_name": &"Grain"}, "StringName display name")
    _expect_rejected({"good_id": &"grain", "display_name": "Grain"}, "missing good prefix")
    _expect_rejected({"good_id": &"good_grain_", "display_name": "Grain"}, "trailing underscore")
    _expect_rejected({"good_id": &"good__grain", "display_name": "Grain"}, "empty first ID segment")
    _expect_rejected({"good_id": &"good_grain__seed", "display_name": "Grain"}, "repeated underscores")
    _expect_rejected({"good_id": &"good_Grain", "display_name": "Grain"}, "uppercase ID")
    _expect_rejected({"good_id": &"good_grain seed", "display_name": "Grain"}, "space in ID")
    _expect_rejected({"good_id": &"good_grain-seed", "display_name": "Grain"}, "punctuation in ID")
    _expect_rejected({"good_id": &"good_grain", "display_name": ""}, "empty display name")
    _expect_rejected({"good_id": &"good_grain", "display_name": " Grain"}, "leading display whitespace")
    _expect_rejected({"good_id": &"good_grain", "display_name": "Grain "}, "trailing display whitespace")


func _expect_rejected(data: Dictionary, context: String) -> void:
    _expect_null(GoodDefinition.create_from_data(data), context)


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
