extends SceneTree


var _failure_count: int = 0


func _initialize() -> void:
    _test_complete_bread_catalogue()
    _test_authoritative_good_order()
    _test_catalogue_rejections()
    _test_dependency_cycles()
    _test_capability_chain_without_production_execution()

    if _failure_count > 0:
        push_error(
            "Prototype content catalogue test FAIL: %d assertion(s) failed."
            % _failure_count
        )
        quit(1)
        return

    print(
        "Prototype content catalogue test PASS: all capability checks succeeded."
    )
    quit(0)


func _test_complete_bread_catalogue() -> void:
    var catalogue: PrototypeContentCatalogue = (
        PrototypeContentCatalogue.create_bread_capability_slice()
    )
    _expect_not_null(catalogue, "complete bread-capability catalogue")
    if catalogue == null:
        return

    _verify_good(
        catalogue,
        &"good_timber",
        "Timber",
        &"automatic_local",
        &"",
        []
    )
    _verify_good(
        catalogue,
        &"good_firewood",
        "Firewood",
        &"automatic_local",
        &"",
        [&"good_timber"]
    )
    _verify_good(
        catalogue,
        &"good_grain",
        "Grain",
        &"building_provided",
        &"building_farm",
        []
    )
    _verify_good(
        catalogue,
        &"good_flour",
        "Flour",
        &"building_provided",
        &"building_mill",
        [&"good_grain"]
    )
    _verify_good(
        catalogue,
        &"good_bread",
        "Bread",
        &"building_provided",
        &"building_bakery",
        [&"good_flour", &"good_firewood"]
    )

    _verify_building(
        catalogue,
        &"building_farm",
        "Farm",
        &"rural_site"
    )
    _verify_building(
        catalogue,
        &"building_mill",
        "Mill",
        &"rural_site"
    )
    _verify_building(
        catalogue,
        &"building_bakery",
        "Bakery",
        &"major_city_workshop"
    )

    var first_bread: GoodDefinition = catalogue.get_good_definition(&"good_bread")
    var second_bread: GoodDefinition = catalogue.get_good_definition(&"good_bread")
    _expect_same(first_bread, second_bread, "deterministic Bread lookup")

    var first_bakery: BuildingDefinition = (
        catalogue.get_building_definition(&"building_bakery")
    )
    var second_bakery: BuildingDefinition = (
        catalogue.get_building_definition(&"building_bakery")
    )
    _expect_same(first_bakery, second_bakery, "deterministic Bakery lookup")

    _expect_null(
        catalogue.get_good_definition(&"good_unknown"),
        "unknown good lookup"
    )
    _expect_null(
        catalogue.get_building_definition(&"building_unknown"),
        "unknown building lookup"
    )

    var returned_requirements: Array[StringName] = (
        first_bread.get_required_good_ids()
    )
    returned_requirements.reverse()
    _expect_required_ids(
        first_bread.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "Bread prerequisites after returned-array mutation"
    )


func _test_authoritative_good_order() -> void:
    var catalogue: PrototypeContentCatalogue = (
        PrototypeContentCatalogue.create_bread_capability_slice()
    )
    _expect_not_null(catalogue, "catalogue for authoritative good order")
    if catalogue == null:
        return

    var expected_order: Array[StringName] = [
        &"good_timber",
        &"good_firewood",
        &"good_grain",
        &"good_flour",
        &"good_bread",
    ]
    var first_returned_ids: Array[StringName] = catalogue.get_good_ids()
    var second_returned_ids: Array[StringName] = catalogue.get_good_ids()
    _expect_required_ids(
        first_returned_ids,
        expected_order,
        "authoritative catalogue good order"
    )

    first_returned_ids.reverse()
    _expect_required_ids(
        catalogue.get_good_ids(),
        expected_order,
        "catalogue order after first returned-array mutation"
    )
    _expect_required_ids(
        second_returned_ids,
        expected_order,
        "independent second returned good-ID array"
    )

    second_returned_ids.clear()
    _expect_required_ids(
        catalogue.get_good_ids(),
        expected_order,
        "catalogue order after second returned-array mutation"
    )


func _test_catalogue_rejections() -> void:
    var farm: BuildingDefinition = _building(&"building_farm", "Farm")
    var grain: GoodDefinition = _provided_good(
        &"good_grain",
        "Grain",
        &"building_farm",
        []
    )

    var null_goods: Array[GoodDefinition] = [null]
    _expect_null(
        PrototypeContentCatalogue.create_from_definitions(null_goods, [farm]),
        "catalogue with null good"
    )

    var null_buildings: Array[BuildingDefinition] = [null]
    _expect_null(
        PrototypeContentCatalogue.create_from_definitions([grain], null_buildings),
        "catalogue with null building"
    )

    _expect_null(
        PrototypeContentCatalogue.create_from_definitions([grain, grain], [farm]),
        "catalogue with duplicate good IDs"
    )
    _expect_null(
        PrototypeContentCatalogue.create_from_definitions([grain], [farm, farm]),
        "catalogue with duplicate building IDs"
    )

    var unknown_provider_good: GoodDefinition = _provided_good(
        &"good_grain",
        "Grain",
        &"building_missing",
        []
    )
    _expect_null(
        PrototypeContentCatalogue.create_from_definitions(
            [unknown_provider_good],
            [farm]
        ),
        "catalogue with unknown provider building"
    )

    var unknown_prerequisite_good: GoodDefinition = _provided_good(
        &"good_flour",
        "Flour",
        &"building_farm",
        [&"good_missing"]
    )
    _expect_null(
        PrototypeContentCatalogue.create_from_definitions(
            [unknown_prerequisite_good],
            [farm]
        ),
        "catalogue with unknown prerequisite good"
    )


func _test_dependency_cycles() -> void:
    var farm: BuildingDefinition = _building(&"building_farm", "Farm")
    var direct_a: GoodDefinition = _provided_good(
        &"good_a",
        "A",
        &"building_farm",
        [&"good_b"]
    )
    var direct_b: GoodDefinition = _provided_good(
        &"good_b",
        "B",
        &"building_farm",
        [&"good_a"]
    )
    _expect_null(
        PrototypeContentCatalogue.create_from_definitions(
            [direct_a, direct_b],
            [farm]
        ),
        "direct two-good dependency cycle"
    )

    var indirect_a: GoodDefinition = _provided_good(
        &"good_a",
        "A",
        &"building_farm",
        [&"good_b"]
    )
    var indirect_b: GoodDefinition = _provided_good(
        &"good_b",
        "B",
        &"building_farm",
        [&"good_c"]
    )
    var indirect_c: GoodDefinition = _provided_good(
        &"good_c",
        "C",
        &"building_farm",
        [&"good_a"]
    )
    _expect_null(
        PrototypeContentCatalogue.create_from_definitions(
            [indirect_c, indirect_a, indirect_b],
            [farm]
        ),
        "indirect three-good dependency cycle"
    )


func _test_capability_chain_without_production_execution() -> void:
    var catalogue: PrototypeContentCatalogue = (
        PrototypeContentCatalogue.create_bread_capability_slice()
    )
    _expect_not_null(catalogue, "capability-chain catalogue")
    if catalogue == null:
        return

    var firewood: GoodDefinition = catalogue.get_good_definition(&"good_firewood")
    var grain: GoodDefinition = catalogue.get_good_definition(&"good_grain")
    var flour: GoodDefinition = catalogue.get_good_definition(&"good_flour")
    var bread: GoodDefinition = catalogue.get_good_definition(&"good_bread")

    _expect_equal(
        firewood.get_provider_building_id(),
        &"",
        "Firewood has no provider building"
    )
    _expect_required_ids(
        firewood.get_required_good_ids(),
        [&"good_timber"],
        "Firewood requires Timber"
    )
    _expect_equal(
        grain.get_provider_building_id(),
        &"building_farm",
        "Grain is provided by Farm"
    )
    _expect_equal(
        flour.get_provider_building_id(),
        &"building_mill",
        "Flour is provided by Mill"
    )
    _expect_required_ids(
        flour.get_required_good_ids(),
        [&"good_grain"],
        "Flour requires Grain"
    )
    _expect_equal(
        bread.get_provider_building_id(),
        &"building_bakery",
        "Bread is provided by Bakery"
    )
    _expect_required_ids(
        bread.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "Bread requires Flour then Firewood"
    )

    var quantity_data: Dictionary = _good_data(
        &"good_grain",
        "Grain",
        &"building_provided",
        &"building_farm",
        []
    )
    quantity_data["quantity"] = 1
    _expect_null(
        GoodDefinition.create_from_data(quantity_data),
        "quantity field is outside the capability schema"
    )

    var recipe_data: Dictionary = _good_data(
        &"good_bread",
        "Bread",
        &"building_provided",
        &"building_bakery",
        [&"good_flour", &"good_firewood"]
    )
    recipe_data["recipe"] = {}
    _expect_null(
        GoodDefinition.create_from_data(recipe_data),
        "recipe object is outside the capability schema"
    )


func _verify_good(
        catalogue: PrototypeContentCatalogue,
        expected_id: StringName,
        expected_display_name: String,
        expected_availability_kind: StringName,
        expected_provider_id: StringName,
        expected_required_ids: Array[StringName]
) -> void:
    var definition: GoodDefinition = catalogue.get_good_definition(expected_id)
    _expect_not_null(definition, String(expected_id) + " lookup")
    if definition == null:
        return

    _expect_equal(
        definition.get_good_id(),
        expected_id,
        String(expected_id) + " good ID"
    )
    _expect_equal(
        definition.get_display_name(),
        expected_display_name,
        String(expected_id) + " display name"
    )
    _expect_equal(
        definition.get_scope_kind(),
        &"province_local",
        String(expected_id) + " scope kind"
    )
    _expect_equal(
        definition.get_availability_kind(),
        expected_availability_kind,
        String(expected_id) + " availability kind"
    )
    _expect_equal(
        definition.get_provider_building_id(),
        expected_provider_id,
        String(expected_id) + " provider building ID"
    )
    _expect_required_ids(
        definition.get_required_good_ids(),
        expected_required_ids,
        String(expected_id) + " prerequisite IDs"
    )


func _verify_building(
        catalogue: PrototypeContentCatalogue,
        expected_id: StringName,
        expected_display_name: String,
        expected_placement_kind: StringName
) -> void:
    var definition: BuildingDefinition = (
        catalogue.get_building_definition(expected_id)
    )
    _expect_not_null(definition, String(expected_id) + " lookup")
    if definition == null:
        return

    _expect_equal(
        definition.get_building_id(),
        expected_id,
        String(expected_id) + " building ID"
    )
    _expect_equal(
        definition.get_display_name(),
        expected_display_name,
        String(expected_id) + " display name"
    )
    _expect_equal(
        definition.get_placement_kind(),
        expected_placement_kind,
        String(expected_id) + " placement kind"
    )


func _provided_good(
        good_id: StringName,
        display_name: String,
        provider_id: StringName,
        required_ids: Array[StringName]
) -> GoodDefinition:
    return GoodDefinition.create_from_data(
        _good_data(
            good_id,
            display_name,
            &"building_provided",
            provider_id,
            required_ids
        )
    )


func _good_data(
        good_id: StringName,
        display_name: String,
        availability_kind: StringName,
        provider_id: StringName,
        required_ids: Array[StringName]
) -> Dictionary:
    return {
        "good_id": good_id,
        "display_name": display_name,
        "scope_kind": &"province_local",
        "availability_kind": availability_kind,
        "provider_building_id": provider_id,
        "required_good_ids": required_ids,
    }


func _building(
        building_id: StringName,
        display_name: String
) -> BuildingDefinition:
    return BuildingDefinition.create_from_data({
        "building_id": building_id,
        "display_name": display_name,
        "placement_kind": &"rural_site",
    })


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
    push_error("%s: expected a catalogue definition." % context)


func _expect_same(actual: Object, expected: Object, context: String) -> void:
    if actual == expected:
        return
    _failure_count += 1
    push_error("%s: expected the same object." % context)
