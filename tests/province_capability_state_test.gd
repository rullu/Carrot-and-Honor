extends SceneTree


var _failure_count: int = 0
var _catalogue: PrototypeContentCatalogue


func _initialize() -> void:
    _catalogue = PrototypeContentCatalogue.create_bread_capability_slice()
    _expect_not_null(_catalogue, "shared bread-capability catalogue")
    if _catalogue != null:
        _test_invalid_creation()
        _test_no_buildings()
        _test_farm_capabilities()
        _test_mill_without_farm()
        _test_farm_and_mill()
        _test_bakery_without_mill()
        _test_complete_chain()
        _test_non_topological_catalogue_order()
        _test_building_removal()
        _test_defensive_copying()
        _test_independent_states()
        _test_input_order_independence()
        _test_stable_id_keys_and_query_distinctions()
        _test_direct_blockers()

    if _failure_count > 0:
        push_error(
            "Province capability state test FAIL: %d assertion(s) failed."
            % _failure_count
        )
        quit(1)
        return

    print(
        "Province capability state test PASS: all deterministic capability checks succeeded."
    )
    quit(0)


func _test_invalid_creation() -> void:
    _expect_null(
        ProvinceCapabilityState.create(null, []),
        "null catalogue"
    )
    _expect_null(
        ProvinceCapabilityState.create(
            _catalogue,
            [&"building_farm", &"building_farm"]
        ),
        "duplicate present-building IDs"
    )
    _expect_null(
        ProvinceCapabilityState.create(
            _catalogue,
            [&"building_unknown"]
        ),
        "unknown present-building ID"
    )


func _test_no_buildings() -> void:
    var state: ProvinceCapabilityState = _create_state([])
    _expect_not_null(state, "province with no buildings")
    if state == null:
        return

    _expect_ids(
        state.get_available_good_ids(),
        [&"good_timber", &"good_firewood"],
        "no-building available goods"
    )
    _expect_true(
        state.is_good_available(&"good_timber"),
        "Timber is automatic with no buildings"
    )
    _expect_true(
        state.is_good_available(&"good_firewood"),
        "Firewood is available through automatic Timber"
    )
    _expect_equal(
        state.get_missing_provider_building_id(&"good_firewood"),
        &"",
        "Firewood has no missing provider"
    )
    _expect_equal(
        state.get_missing_provider_building_id(&"good_grain"),
        &"building_farm",
        "Grain reports Farm as missing provider"
    )


func _test_farm_capabilities() -> void:
    var state: ProvinceCapabilityState = _create_state([&"building_farm"])
    _expect_ids(
        state.get_available_good_ids(),
        [&"good_timber", &"good_firewood", &"good_grain"],
        "Farm available goods"
    )
    _expect_true(
        state.is_good_available(&"good_grain"),
        "Farm enables Grain"
    )


func _test_mill_without_farm() -> void:
    var state: ProvinceCapabilityState = _create_state([&"building_mill"])
    _expect_false(
        state.is_good_available(&"good_flour"),
        "Mill without Farm does not enable Flour"
    )
    _expect_ids(
        state.get_missing_required_good_ids(&"good_flour"),
        [&"good_grain"],
        "Mill-without-Farm Flour blocker"
    )
    _expect_equal(
        state.get_missing_provider_building_id(&"good_flour"),
        &"",
        "present Mill is not reported missing for Flour"
    )


func _test_farm_and_mill() -> void:
    var state: ProvinceCapabilityState = _create_state(
        [&"building_farm", &"building_mill"]
    )
    _expect_true(
        state.is_good_available(&"good_flour"),
        "Farm plus Mill enables Flour"
    )
    _expect_ids(
        state.get_available_good_ids(),
        [&"good_timber", &"good_firewood", &"good_grain", &"good_flour"],
        "Farm-plus-Mill available goods"
    )


func _test_bakery_without_mill() -> void:
    var state: ProvinceCapabilityState = _create_state([&"building_bakery"])
    _expect_false(
        state.is_good_available(&"good_bread"),
        "Bakery without Mill does not enable Bread"
    )
    _expect_ids(
        state.get_missing_required_good_ids(&"good_bread"),
        [&"good_flour"],
        "Bakery-without-Mill Bread blocker"
    )
    _expect_equal(
        state.get_missing_provider_building_id(&"good_bread"),
        &"",
        "present Bakery is not reported missing for Bread"
    )


func _test_complete_chain() -> void:
    var state: ProvinceCapabilityState = _create_complete_state()
    _expect_true(
        state.is_good_available(&"good_bread"),
        "Farm plus Mill plus Bakery enables Bread"
    )
    _expect_ids(
        state.get_available_good_ids(),
        [
            &"good_timber",
            &"good_firewood",
            &"good_grain",
            &"good_flour",
            &"good_bread",
        ],
        "complete available capability order"
    )

    var bread: GoodDefinition = _catalogue.get_good_definition(&"good_bread")
    _expect_ids(
        bread.get_required_good_ids(),
        [&"good_flour", &"good_firewood"],
        "Bread prerequisite order"
    )


func _test_non_topological_catalogue_order() -> void:
    var custom_goods: Array[GoodDefinition] = [
        _custom_good(
            &"good_bread",
            "Bread",
            &"building_provided",
            &"building_bakery",
            [&"good_flour", &"good_firewood"]
        ),
        _custom_good(
            &"good_flour",
            "Flour",
            &"building_provided",
            &"building_mill",
            [&"good_grain"]
        ),
        _custom_good(
            &"good_grain",
            "Grain",
            &"building_provided",
            &"building_farm",
            []
        ),
        _custom_good(
            &"good_firewood",
            "Firewood",
            &"automatic_local",
            &"",
            [&"good_timber"]
        ),
        _custom_good(
            &"good_timber",
            "Timber",
            &"automatic_local",
            &"",
            []
        ),
    ]
    var custom_buildings: Array[BuildingDefinition] = [
        _custom_building(&"building_farm", "Farm"),
        _custom_building(&"building_mill", "Mill"),
        _custom_building(&"building_bakery", "Bakery"),
    ]
    var custom_catalogue: PrototypeContentCatalogue = (
        PrototypeContentCatalogue.create_from_definitions(
            custom_goods,
            custom_buildings
        )
    )
    _expect_not_null(custom_catalogue, "valid non-topological catalogue")
    if custom_catalogue == null:
        return

    var state: ProvinceCapabilityState = ProvinceCapabilityState.create(
        custom_catalogue,
        [&"building_farm", &"building_mill", &"building_bakery"]
    )
    _expect_not_null(state, "state from non-topological catalogue")
    if state == null:
        return

    _expect_ids(
        state.get_available_good_ids(),
        [
            &"good_bread",
            &"good_flour",
            &"good_grain",
            &"good_firewood",
            &"good_timber",
        ],
        "non-topological catalogue authoritative result order"
    )
    _expect_ids(
        state.get_blocked_good_ids(),
        [],
        "non-topological complete state blocked goods"
    )


func _test_building_removal() -> void:
    var without_farm: ProvinceCapabilityState = _create_state(
        [&"building_mill", &"building_bakery"]
    )
    _expect_true(
        without_farm.is_good_available(&"good_timber"),
        "removing Farm preserves Timber"
    )
    _expect_true(
        without_farm.is_good_available(&"good_firewood"),
        "removing Farm preserves Firewood"
    )
    _expect_false(
        without_farm.is_good_available(&"good_grain"),
        "removing Farm removes Grain"
    )
    _expect_false(
        without_farm.is_good_available(&"good_flour"),
        "removing Farm removes Flour"
    )
    _expect_false(
        without_farm.is_good_available(&"good_bread"),
        "removing Farm removes Bread"
    )

    var without_mill: ProvinceCapabilityState = _create_state(
        [&"building_farm", &"building_bakery"]
    )
    _expect_true(
        without_mill.is_good_available(&"good_grain"),
        "removing Mill preserves Grain"
    )
    _expect_false(
        without_mill.is_good_available(&"good_flour"),
        "removing Mill removes Flour"
    )
    _expect_false(
        without_mill.is_good_available(&"good_bread"),
        "removing Mill removes Bread"
    )

    var without_bakery: ProvinceCapabilityState = _create_state(
        [&"building_farm", &"building_mill"]
    )
    _expect_true(
        without_bakery.is_good_available(&"good_grain"),
        "removing Bakery preserves Grain"
    )
    _expect_true(
        without_bakery.is_good_available(&"good_flour"),
        "removing Bakery preserves Flour"
    )
    _expect_false(
        without_bakery.is_good_available(&"good_bread"),
        "removing Bakery removes Bread"
    )


func _test_defensive_copying() -> void:
    var source_buildings: Array[StringName] = [
        &"building_mill",
        &"building_farm",
    ]
    var state: ProvinceCapabilityState = (
        ProvinceCapabilityState.create(_catalogue, source_buildings)
    )
    source_buildings.clear()
    _expect_ids(
        state.get_present_building_ids(),
        [&"building_farm", &"building_mill"],
        "state after source-building mutation"
    )

    var returned_buildings: Array[StringName] = state.get_present_building_ids()
    returned_buildings.clear()
    _expect_ids(
        state.get_present_building_ids(),
        [&"building_farm", &"building_mill"],
        "state after returned-building mutation"
    )

    var returned_available: Array[StringName] = state.get_available_good_ids()
    returned_available.clear()
    _expect_ids(
        state.get_available_good_ids(),
        [&"good_timber", &"good_firewood", &"good_grain", &"good_flour"],
        "state after returned-available-good mutation"
    )

    var returned_blocked: Array[StringName] = state.get_blocked_good_ids()
    returned_blocked.clear()
    _expect_ids(
        state.get_blocked_good_ids(),
        [&"good_bread"],
        "state after returned-blocked-good mutation"
    )

    var missing_bread_requirements: Array[StringName] = (
        state.get_missing_required_good_ids(&"good_bread")
    )
    missing_bread_requirements.clear()
    _expect_ids(
        state.get_missing_required_good_ids(&"good_bread"),
        [],
        "state after returned empty blocker-array mutation"
    )

    var mill_only: ProvinceCapabilityState = _create_state([&"building_mill"])
    var missing_flour_requirements: Array[StringName] = (
        mill_only.get_missing_required_good_ids(&"good_flour")
    )
    missing_flour_requirements.clear()
    _expect_ids(
        mill_only.get_missing_required_good_ids(&"good_flour"),
        [&"good_grain"],
        "state after returned non-empty blocker-array mutation"
    )


func _test_independent_states() -> void:
    var shared_source: Array[StringName] = [&"building_mill"]
    var first: ProvinceCapabilityState = (
        ProvinceCapabilityState.create(_catalogue, shared_source)
    )
    var second: ProvinceCapabilityState = (
        ProvinceCapabilityState.create(_catalogue, shared_source)
    )
    _expect_different(first, second, "independent province state objects")

    var first_buildings: Array[StringName] = first.get_present_building_ids()
    first_buildings.clear()
    var first_goods: Array[StringName] = first.get_available_good_ids()
    first_goods.clear()
    var first_blockers: Array[StringName] = (
        first.get_missing_required_good_ids(&"good_flour")
    )
    first_blockers.clear()
    _expect_ids(
        second.get_present_building_ids(),
        [&"building_mill"],
        "second state buildings after first-state collection mutation"
    )
    _expect_ids(
        first.get_missing_required_good_ids(&"good_flour"),
        [&"good_grain"],
        "first state blockers after returned blocker mutation"
    )
    _expect_ids(
        second.get_missing_required_good_ids(&"good_flour"),
        [&"good_grain"],
        "second state blockers after first-state blocker mutation"
    )
    _expect_ids(
        second.get_available_good_ids(),
        [&"good_timber", &"good_firewood"],
        "second state goods after first-state collection mutation"
    )


func _test_input_order_independence() -> void:
    var first: ProvinceCapabilityState = _create_state(
        [&"building_bakery", &"building_farm", &"building_mill"]
    )
    var second: ProvinceCapabilityState = _create_state(
        [&"building_mill", &"building_bakery", &"building_farm"]
    )
    _expect_ids(
        first.get_present_building_ids(),
        second.get_present_building_ids(),
        "permuted sorted building IDs"
    )
    _expect_ids(
        first.get_available_good_ids(),
        second.get_available_good_ids(),
        "permuted available-good IDs"
    )
    _expect_ids(
        first.get_blocked_good_ids(),
        second.get_blocked_good_ids(),
        "permuted blocked-good IDs"
    )
    for good_id: StringName in _catalogue.get_good_ids():
        _expect_equal(
            first.get_missing_provider_building_id(good_id),
            second.get_missing_provider_building_id(good_id),
            "permuted missing provider for " + String(good_id)
        )
        _expect_ids(
            first.get_missing_required_good_ids(good_id),
            second.get_missing_required_good_ids(good_id),
            "permuted missing prerequisites for " + String(good_id)
        )

    var first_partial: ProvinceCapabilityState = _create_state(
        [&"building_farm", &"building_bakery"]
    )
    var second_partial: ProvinceCapabilityState = _create_state(
        [&"building_bakery", &"building_farm"]
    )
    _expect_ids(
        first_partial.get_present_building_ids(),
        [&"building_bakery", &"building_farm"],
        "partial permutation lexical building order"
    )
    _expect_ids(
        first_partial.get_present_building_ids(),
        second_partial.get_present_building_ids(),
        "partial permutation sorted building IDs"
    )
    _expect_ids(
        first_partial.get_available_good_ids(),
        second_partial.get_available_good_ids(),
        "partial permutation available goods"
    )
    _expect_ids(
        first_partial.get_blocked_good_ids(),
        second_partial.get_blocked_good_ids(),
        "partial permutation blocked goods"
    )
    for good_id: StringName in _catalogue.get_good_ids():
        _expect_equal(
            first_partial.get_missing_provider_building_id(good_id),
            second_partial.get_missing_provider_building_id(good_id),
            "partial permutation missing provider for " + String(good_id)
        )
        _expect_ids(
            first_partial.get_missing_required_good_ids(good_id),
            second_partial.get_missing_required_good_ids(good_id),
            "partial permutation missing prerequisites for " + String(good_id)
        )

    _expect_true(
        first_partial.is_good_available(&"good_grain"),
        "partial permutation Grain availability"
    )
    _expect_equal(
        first_partial.get_missing_provider_building_id(&"good_flour"),
        &"building_mill",
        "partial permutation Flour missing Mill"
    )
    _expect_ids(
        first_partial.get_missing_required_good_ids(&"good_bread"),
        [&"good_flour"],
        "partial permutation Bread direct blocker"
    )
    _expect_equal(
        first_partial.get_missing_provider_building_id(&"good_bread"),
        &"",
        "partial permutation present Bakery is not missing"
    )


func _test_stable_id_keys_and_query_distinctions() -> void:
    var state: ProvinceCapabilityState = _create_state([&"building_farm"])
    var building_keys: Dictionary[StringName, bool] = {
        state.get_present_building_ids()[0]: true,
    }
    _expect_true(
        building_keys.has(&"building_farm"),
        "building StringName dictionary key"
    )

    var good_keys: Dictionary[StringName, bool] = {}
    for good_id: StringName in state.get_available_good_ids():
        good_keys[good_id] = true
    _expect_true(
        good_keys.has(&"good_grain"),
        "good StringName dictionary key"
    )

    _expect_true(
        state.has_capability_result(&"good_grain"),
        "known available good has capability result"
    )
    _expect_true(
        state.is_good_available(&"good_grain"),
        "known available good is available"
    )
    _expect_true(
        state.has_capability_result(&"good_flour"),
        "known blocked good has capability result"
    )
    _expect_false(
        state.is_good_available(&"good_flour"),
        "known blocked good is unavailable"
    )
    _expect_false(
        state.has_capability_result(&"good_unknown"),
        "unknown good has no capability result"
    )
    _expect_false(
        state.is_good_available(&"good_unknown"),
        "unknown good is unavailable"
    )


func _test_direct_blockers() -> void:
    var state: ProvinceCapabilityState = _create_state([])
    _expect_equal(
        state.get_missing_provider_building_id(&"good_flour"),
        &"building_mill",
        "no-building Flour missing provider"
    )
    _expect_ids(
        state.get_missing_required_good_ids(&"good_flour"),
        [&"good_grain"],
        "no-building Flour direct prerequisite blocker"
    )
    _expect_equal(
        state.get_missing_provider_building_id(&"good_bread"),
        &"building_bakery",
        "no-building Bread missing provider"
    )
    _expect_ids(
        state.get_missing_required_good_ids(&"good_bread"),
        [&"good_flour"],
        "no-building Bread direct prerequisite blocker"
    )
    _expect_false(
        &"good_grain" in state.get_missing_required_good_ids(&"good_bread"),
        "Bread blockers are not flattened to Grain"
    )


func _create_state(
        building_ids: Array[StringName]
) -> ProvinceCapabilityState:
    return ProvinceCapabilityState.create(_catalogue, building_ids)


func _create_complete_state() -> ProvinceCapabilityState:
    return _create_state([
        &"building_farm",
        &"building_mill",
        &"building_bakery",
    ])


func _custom_good(
        good_id: StringName,
        display_name: String,
        availability_kind: StringName,
        provider_building_id: StringName,
        required_good_ids: Array[StringName]
) -> GoodDefinition:
    return GoodDefinition.create_from_data({
        "good_id": good_id,
        "display_name": display_name,
        "scope_kind": &"province_local",
        "availability_kind": availability_kind,
        "provider_building_id": provider_building_id,
        "required_good_ids": required_good_ids,
    })


func _custom_building(
        building_id: StringName,
        display_name: String
) -> BuildingDefinition:
    return BuildingDefinition.create_from_data({
        "building_id": building_id,
        "display_name": display_name,
        "placement_kind": &"rural_site",
    })


func _expect_ids(
        actual: Array[StringName],
        expected: Array[StringName],
        context: String
) -> void:
    _expect_equal(actual.size(), expected.size(), context + " length")
    for index: int in range(mini(actual.size(), expected.size())):
        _expect_equal(actual[index], expected[index], context + " item %d" % index)


func _expect_true(actual: bool, context: String) -> void:
    _expect_equal(actual, true, context)


func _expect_false(actual: bool, context: String) -> void:
    _expect_equal(actual, false, context)


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
    push_error("%s: expected a ProvinceCapabilityState." % context)


func _expect_different(actual: Object, expected: Object, context: String) -> void:
    if actual != expected:
        return
    _failure_count += 1
    push_error("%s: expected different objects." % context)
