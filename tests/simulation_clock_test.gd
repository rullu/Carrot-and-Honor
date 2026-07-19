extends SceneTree


var _failure_count: int = 0


func _initialize() -> void:
    _test_normal_daily_progression()
    _test_month_boundary_progression()
    _test_deterministic_repetition()
    _test_state_round_trip()
    _test_invalid_state_rejection()

    if _failure_count > 0:
        push_error("Simulation clock test FAIL: %d assertion(s) failed." % _failure_count)
        quit(1)
        return

    print("Simulation clock test PASS: all deterministic clock checks succeeded.")
    quit(0)


func _test_normal_daily_progression() -> void:
    var clock: SimulationClock = SimulationClock.new(1, 1, 3)

    clock.advance_day()

    _expect_equal(clock.get_current_day(), 2, "normal progression day")
    _expect_equal(clock.get_current_month(), 1, "normal progression month")
    _expect_equal(clock.get_elapsed_daily_ticks(), 1, "normal progression elapsed ticks")


func _test_month_boundary_progression() -> void:
    var clock: SimulationClock = SimulationClock.new(3, 1, 3)

    clock.advance_day()

    _expect_equal(clock.get_current_day(), 1, "month boundary day")
    _expect_equal(clock.get_current_month(), 2, "month boundary month")
    _expect_equal(clock.get_elapsed_daily_ticks(), 1, "month boundary elapsed ticks")


func _test_deterministic_repetition() -> void:
    var first_clock: SimulationClock = SimulationClock.new(2, 3, 3)
    var second_clock: SimulationClock = SimulationClock.new(2, 3, 3)

    for _tick_index: int in range(5):
        first_clock.advance_day()
        second_clock.advance_day()

    _expect_equal(first_clock.get_current_day(), second_clock.get_current_day(), "deterministic day")
    _expect_equal(first_clock.get_current_month(), second_clock.get_current_month(), "deterministic month")
    _expect_equal(
        first_clock.get_elapsed_daily_ticks(),
        second_clock.get_elapsed_daily_ticks(),
        "deterministic elapsed ticks"
    )
    _expect_equal(first_clock.get_days_per_month(), second_clock.get_days_per_month(), "deterministic month length")

    _expect_equal(first_clock.get_current_day(), 1, "deterministic final day")
    _expect_equal(first_clock.get_current_month(), 5, "deterministic final month")
    _expect_equal(first_clock.get_elapsed_daily_ticks(), 5, "deterministic final elapsed ticks")
    _expect_equal(first_clock.get_days_per_month(), 3, "deterministic final month length")


func _test_state_round_trip() -> void:
    var original_clock: SimulationClock = SimulationClock.new(2, 4, 3)
    original_clock.advance_day()
    original_clock.advance_day()

    var exported_state: Dictionary[String, int] = original_clock.export_state()
    var restored_clock: SimulationClock = SimulationClock.create_from_state(exported_state)
    _expect_not_null(restored_clock, "valid exported state restoration")
    if restored_clock == null:
        return

    _verify_restored_fields(original_clock, restored_clock)
    exported_state["current_day"] = 3
    _expect_equal(original_clock.get_current_day(), 1, "export mutation does not affect original")
    _expect_equal(restored_clock.get_current_day(), 1, "export mutation does not affect restored clock")

    for _tick_index: int in range(5):
        original_clock.advance_day()
        restored_clock.advance_day()

    _verify_round_trip_final_state(original_clock, restored_clock)


func _verify_restored_fields(original_clock: SimulationClock, restored_clock: SimulationClock) -> void:
    _expect_equal(restored_clock.get_current_day(), original_clock.get_current_day(), "restored day")
    _expect_equal(restored_clock.get_current_month(), original_clock.get_current_month(), "restored month")
    _expect_equal(restored_clock.get_elapsed_daily_ticks(), original_clock.get_elapsed_daily_ticks(), "restored elapsed ticks")
    _expect_equal(restored_clock.get_days_per_month(), original_clock.get_days_per_month(), "restored month length")


func _verify_round_trip_final_state(original_clock: SimulationClock, restored_clock: SimulationClock) -> void:
    _expect_equal(original_clock.get_current_day(), restored_clock.get_current_day(), "round-trip final day match")
    _expect_equal(original_clock.get_current_month(), restored_clock.get_current_month(), "round-trip final month match")
    _expect_equal(original_clock.get_elapsed_daily_ticks(), restored_clock.get_elapsed_daily_ticks(), "round-trip final elapsed ticks match")
    _expect_equal(original_clock.get_days_per_month(), restored_clock.get_days_per_month(), "round-trip final month length match")
    _expect_equal(restored_clock.get_current_day(), 3, "round-trip exact final day")
    _expect_equal(restored_clock.get_current_month(), 6, "round-trip exact final month")
    _expect_equal(restored_clock.get_elapsed_daily_ticks(), 7, "round-trip exact final elapsed ticks")
    _expect_equal(restored_clock.get_days_per_month(), 3, "round-trip exact final month length")


func _test_invalid_state_rejection() -> void:
    var valid_state: Dictionary[String, int] = SimulationClock.new(1, 1, 3).export_state()
    var incomplete_state: Dictionary = valid_state.duplicate()
    incomplete_state.erase("current_day")
    _expect_null(SimulationClock.create_from_state(incomplete_state), "incomplete state")

    var extra_state: Dictionary = valid_state.duplicate()
    extra_state["unexpected"] = 1
    _expect_null(SimulationClock.create_from_state(extra_state), "state with extra field")

    var wrongly_typed_state: Dictionary = {
        "current_day": 1,
        "current_month": "1",
        "elapsed_daily_ticks": 0,
        "days_per_month": 3,
    }
    _expect_null(SimulationClock.create_from_state(wrongly_typed_state), "wrongly typed state")

    var invalid_day_state: Dictionary = valid_state.duplicate()
    invalid_day_state["current_day"] = 4
    _expect_null(SimulationClock.create_from_state(invalid_day_state), "invalid day state")


func _expect_equal(actual: int, expected: int, context: String) -> void:
    if actual == expected:
        return

    _failure_count += 1
    push_error("%s: expected %d, got %d." % [context, expected, actual])


func _expect_null(actual: Variant, context: String) -> void:
    if actual == null:
        return

    _failure_count += 1
    push_error("%s: expected null." % context)


func _expect_not_null(actual: Variant, context: String) -> void:
    if actual != null:
        return

    _failure_count += 1
    push_error("%s: expected a SimulationClock." % context)
