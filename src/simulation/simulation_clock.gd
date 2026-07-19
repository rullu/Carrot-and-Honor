class_name SimulationClock
extends RefCounted


var _current_day: int
var _current_month: int
var _elapsed_daily_ticks: int = 0
var _days_per_month: int


func _init(initial_day: int, initial_month: int, days_per_month: int) -> void:
    assert(days_per_month > 0, "Days per month must be positive.")
    assert(initial_day > 0 and initial_day <= days_per_month, "Initial day must be within the configured month.")
    assert(initial_month > 0, "Initial month must be positive.")

    _current_day = initial_day
    _current_month = initial_month
    _days_per_month = days_per_month


func get_current_day() -> int:
    return _current_day


func get_current_month() -> int:
    return _current_month


func get_elapsed_daily_ticks() -> int:
    return _elapsed_daily_ticks


func get_days_per_month() -> int:
    return _days_per_month


func advance_day() -> void:
    _elapsed_daily_ticks += 1
    _current_day += 1

    if _current_day > _days_per_month:
        _current_day = 1
        _current_month += 1
