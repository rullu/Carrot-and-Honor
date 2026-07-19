extends SceneTree


func _initialize() -> void:
    var expected: int = 5
    var actual: int = _add_integers(2, 3)

    if actual != expected:
        push_error('Foundation smoke test FAIL: expected %d, got %d.' % [expected, actual])
        quit(1)
        return

    print('Foundation smoke test PASS: typed GDScript executed successfully.')
    quit(0)


func _add_integers(left: int, right: int) -> int:
    return left + right
