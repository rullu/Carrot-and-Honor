class_name ProvinceInteraction
extends Node


signal hovered_province_changed(province_id: int)
signal selected_province_changed(province_id: int)


const INVALID_PROVINCE_ID: int = -1


var _geography: ProvinceGeography
var _camera: Camera3D
var _terrain: Terrain3D
var _hovered_province_id: int = INVALID_PROVINCE_ID
var _selected_province_id: int = INVALID_PROVINCE_ID
var _configured: bool = false
var _terrain_queries_available: bool = false


func configure(
        geography: ProvinceGeography,
        world_camera: Camera3D,
        terrain: Terrain3D
) -> void:
    _geography = geography
    _camera = world_camera
    _terrain = terrain
    _configured = geography != null and world_camera != null and terrain != null
    _terrain_queries_available = _configured and DisplayServer.get_name() != "headless"


func _process(_delta: float) -> void:
    if not _terrain_queries_available:
        return
    if get_viewport().gui_get_hovered_control() != null:
        _set_hovered_province_id(INVALID_PROVINCE_ID)
        return
    _set_hovered_province_id(_province_at_screen_position(get_viewport().get_mouse_position()))


func _unhandled_input(event: InputEvent) -> void:
    if not _configured:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
            _set_selected_province_id(INVALID_PROVINCE_ID)
            get_viewport().set_input_as_handled()
        return
    if not event is InputEventMouseButton:
        return
    if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
        return
    if get_viewport().gui_get_hovered_control() != null:
        return
    if not _terrain_queries_available:
        return
    var province_id: int = _province_at_screen_position(event.position)
    _set_hovered_province_id(province_id)
    _set_selected_province_id(province_id)
    get_viewport().set_input_as_handled()


func get_hovered_province_id() -> int:
    return _hovered_province_id


func get_selected_province_id() -> int:
    return _selected_province_id


func _province_at_screen_position(screen_position: Vector2) -> int:
    var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
    var ray_direction: Vector3 = _camera.project_ray_normal(screen_position)
    var intersection: Vector3 = _terrain.get_intersection(ray_origin, ray_direction, true)
    if (
        is_nan(intersection.x)
        or is_nan(intersection.y)
        or is_nan(intersection.z)
        or is_inf(intersection.x)
        or is_inf(intersection.y)
        or is_inf(intersection.z)
        or absf(intersection.x) > 1.0e30
        or absf(intersection.z) > 1.0e30
    ):
        return INVALID_PROVINCE_ID
    return _geography.find_province_id(Vector2(intersection.x, intersection.z))


func _set_hovered_province_id(province_id: int) -> void:
    if province_id == _hovered_province_id:
        return
    _hovered_province_id = province_id
    hovered_province_changed.emit(province_id)


func _set_selected_province_id(province_id: int) -> void:
    if province_id == _selected_province_id:
        return
    _selected_province_id = province_id
    selected_province_changed.emit(province_id)
