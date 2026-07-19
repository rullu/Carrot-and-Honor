extends SceneTree


var _failure_count: int = 0


func _initialize() -> void:
    _test_normal_daily_progression()
    _test_month_boundary_progression()
    _test_deterministic_repetition()

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


func _expect_equal(actual: int, expected: int, context: String) -> void:
    if actual == expected:
        return

    _failure_count += 1
    push_error("%s: expected %d, got %d." % [context, expected, actual])
