class_name SimulationClock
extends RefCounted


const STATE_KEYS: Array[String] = [
    "current_day",
    "current_month",
    "elapsed_daily_ticks",
    "days_per_month",
]


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


func export_state() -> Dictionary[String, int]:
    return {
        "current_day": _current_day,
        "current_month": _current_month,
        "elapsed_daily_ticks": _elapsed_daily_ticks,
        "days_per_month": _days_per_month,
    }


static func create_from_state(state: Dictionary) -> SimulationClock:
    if state.size() != STATE_KEYS.size():
        return null

    for key: String in STATE_KEYS:
        if not state.has(key) or typeof(state[key]) != TYPE_INT:
            return null

    var current_day: int = state["current_day"]
    var current_month: int = state["current_month"]
    var elapsed_daily_ticks: int = state["elapsed_daily_ticks"]
    var days_per_month: int = state["days_per_month"]

    if days_per_month <= 0:
        return null
    if current_day <= 0 or current_day > days_per_month:
        return null
    if current_month <= 0 or elapsed_daily_ticks < 0:
        return null

    var restored_clock: SimulationClock = SimulationClock.new(current_day, current_month, days_per_month)
    restored_clock._elapsed_daily_ticks = elapsed_daily_ticks
    return restored_clock


func advance_day() -> void:
    _elapsed_daily_ticks += 1
    _current_day += 1

    if _current_day > _days_per_month:
        _current_day = 1
        _current_month += 1
