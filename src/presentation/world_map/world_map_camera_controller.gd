extends Camera2D


const TERRAIN_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const TERRAIN_CENTER: Vector2 = TERRAIN_SIZE * 0.5
const ZOOM_STEP: float = 0.1


@export_range(100.0, 2000.0, 10.0) var pan_speed: float = 700.0
@export_range(1.0, 128.0, 1.0) var edge_margin: float = 24.0
@export_range(0.0, 1.0, 0.05) var edge_slowdown: float = 0.35
@export_range(0.1, 3.0, 0.05) var drag_sensitivity: float = 1.0
@export_range(1.0, 4.0, 0.05) var maximum_zoom: float = 2.0


var _minimum_zoom: float = 1.0
var _middle_mouse_dragging: bool = false


func _ready() -> void:
    get_viewport().size_changed.connect(_recalculate_camera_limits)
    _recalculate_camera_limits()


func _process(delta: float) -> void:
    var movement_direction: Vector2 = Input.get_vector(
        "map_move_left",
        "map_move_right",
        "map_move_up",
        "map_move_down"
    )
    movement_direction += _get_edge_scroll_direction()
    if movement_direction.length_squared() > 1.0:
        movement_direction = movement_direction.normalized()

    if movement_direction != Vector2.ZERO:
        position += movement_direction * pan_speed * delta / zoom.x
        _clamp_position()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        _handle_mouse_button(event)
        return

    if event is InputEventMouseMotion and _middle_mouse_dragging:
        position -= event.relative * drag_sensitivity / zoom.x
        _clamp_position()
        get_viewport().set_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
    if event.button_index == MOUSE_BUTTON_MIDDLE:
        _middle_mouse_dragging = event.pressed
        get_viewport().set_input_as_handled()
        return

    if not event.pressed:
        return

    if event.button_index == MOUSE_BUTTON_WHEEL_UP:
        _set_uniform_zoom(zoom.x + ZOOM_STEP, true, event.position)
        get_viewport().set_input_as_handled()
    elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
        _set_uniform_zoom(zoom.x - ZOOM_STEP, true, event.position)
        get_viewport().set_input_as_handled()


func _get_edge_scroll_direction() -> Vector2:
    if edge_margin <= 0.0:
        return Vector2.ZERO

    var viewport_size: Vector2 = get_viewport_rect().size
    var mouse_position: Vector2 = get_viewport().get_mouse_position()
    if not Rect2(Vector2.ZERO, viewport_size).has_point(mouse_position):
        return Vector2.ZERO

    return Vector2(
        _get_axis_edge_strength(mouse_position.x, viewport_size.x),
        _get_axis_edge_strength(mouse_position.y, viewport_size.y)
    )


func _get_axis_edge_strength(mouse_position: float, viewport_extent: float) -> float:
    if mouse_position < edge_margin:
        var left_strength: float = 1.0 - mouse_position / edge_margin
        return -lerpf(edge_slowdown, 1.0, left_strength)
    if mouse_position > viewport_extent - edge_margin:
        var right_strength: float = (mouse_position - (viewport_extent - edge_margin)) / edge_margin
        return lerpf(edge_slowdown, 1.0, right_strength)
    return 0.0


func _recalculate_camera_limits() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return

    _minimum_zoom = calculate_minimum_cover_zoom(viewport_size)
    _set_uniform_zoom(zoom.x)


func calculate_minimum_cover_zoom(viewport_size: Vector2) -> float:
    assert(viewport_size.x > 0.0 and viewport_size.y > 0.0, "Viewport size must be positive.")
    return maxf(
        viewport_size.x / TERRAIN_SIZE.x,
        viewport_size.y / TERRAIN_SIZE.y
    )


func calculate_cursor_anchored_position(
    camera_position: Vector2,
    cursor_position: Vector2,
    viewport_size: Vector2,
    previous_zoom: float,
    next_zoom: float
) -> Vector2:
    assert(previous_zoom > 0.0 and next_zoom > 0.0, "Zoom values must be positive.")
    var cursor_offset_from_centre: Vector2 = cursor_position - viewport_size * 0.5
    return (
        camera_position
        + cursor_offset_from_centre / previous_zoom
        - cursor_offset_from_centre / next_zoom
    )


func _set_uniform_zoom(
    requested_zoom: float,
    anchor_to_cursor: bool = false,
    cursor_position: Vector2 = Vector2.ZERO
) -> void:
    var effective_maximum_zoom: float = maxf(maximum_zoom, _minimum_zoom)
    var clamped_zoom: float = clampf(requested_zoom, _minimum_zoom, effective_maximum_zoom)
    if anchor_to_cursor and not is_equal_approx(clamped_zoom, zoom.x):
        position = calculate_cursor_anchored_position(
            position,
            cursor_position,
            get_viewport_rect().size,
            zoom.x,
            clamped_zoom
        )
    zoom = Vector2(clamped_zoom, clamped_zoom)
    _clamp_position()


func _clamp_position() -> void:
    var half_visible_world_size: Vector2 = get_viewport_rect().size / (2.0 * zoom.x)
    var minimum_position: Vector2 = half_visible_world_size
    var maximum_position: Vector2 = TERRAIN_SIZE - half_visible_world_size

    position = Vector2(
        TERRAIN_CENTER.x if minimum_position.x > maximum_position.x else clampf(
            position.x,
            minimum_position.x,
            maximum_position.x
        ),
        TERRAIN_CENTER.y if minimum_position.y > maximum_position.y else clampf(
            position.y,
            minimum_position.y,
            maximum_position.y
        )
    )
