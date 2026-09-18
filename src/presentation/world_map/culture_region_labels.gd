class_name CultureRegionLabels
extends CanvasLayer


const LABEL_LIFT: float = 22.0
const GAMEPLAY_FONT_COLOR: Color = Color(0.97, 0.96, 0.91, 1.0)
const GAMEPLAY_OUTLINE_COLOR: Color = Color(0.12, 0.14, 0.16, 0.95)
const OVERVIEW_FONT_COLOR: Color = Color(0.10, 0.12, 0.13, 1.0)
const OVERVIEW_OUTLINE_COLOR: Color = Color(0.97, 0.96, 0.91, 0.97)

var _geography: ProvinceGeography
var _terrain: Terrain3D
var _camera: Camera3D
var _avoid_control: Control
var _labels: Dictionary[String, Label] = {}
var _anchors: Dictionary[String, Vector3] = {}
var _names: Dictionary[String, String] = {}
var _province_regions: Dictionary[int, String] = {}
var _last_camera_transform: Transform3D
var _last_camera_size: float = -1.0
var _last_viewport_size: Vector2 = Vector2.ZERO
var _last_avoid_rect: Rect2 = Rect2()
var _last_font_size: int = -1
var _last_overview: bool = false


func configure(
    geography: ProvinceGeography,
    terrain: Terrain3D,
    camera: Camera3D,
    avoid_control: Control
) -> void:
    _geography = geography
    _terrain = terrain
    _camera = camera
    _avoid_control = avoid_control
    layer = -1
    visible = false
    set_process(false)


func refresh_cultures(culture_by_province: Dictionary[int, String]) -> bool:
    if _geography == null or _terrain == null or _camera == null:
        push_error("Culture region labels are not configured.")
        return false
    var specs: Dictionary[String, Dictionary] = build_specs(_geography, culture_by_province)
    if specs.is_empty():
        push_error("Culture region labels could not resolve current Province cultures.")
        return false
    for key: String in _labels.keys():
        if specs.has(key):
            continue
        _labels[key].free()
        _labels.erase(key)
        _anchors.erase(key)
        _names.erase(key)
    _province_regions.clear()
    var keys: Array[String] = []
    keys.assign(specs.keys())
    keys.sort()
    for key: String in keys:
        var spec: Dictionary = specs[key]
        var label: Label = _labels.get(key)
        if label == null:
            label = _create_label(key)
            _labels[key] = label
        _names[key] = spec["culture"]
        for province_id: int in spec["province_ids"]:
            _province_regions[province_id] = key
        var point: Vector2 = spec["anchor_xz"]
        var height: float = _terrain.data.get_height(Vector3(point.x, 0.0, point.y))
        if is_nan(height):
            height = 0.0
        _anchors[key] = Vector3(point.x, height + LABEL_LIFT, point.y)
    _last_camera_size = -1.0
    _last_font_size = -1
    _last_overview = not (_camera.size >= 13000.0)
    if visible:
        _update_positions()
    return true


func set_enabled(enabled: bool) -> void:
    visible = enabled
    set_process(enabled)
    if enabled:
        _last_camera_size = -1.0
        _update_positions()


func get_label_count() -> int:
    return _labels.size()


func _process(_delta: float) -> void:
    _update_positions()


func _create_label(key: String) -> Label:
    var label: Label = Label.new()
    label.name = "CultureRegion_" + key
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", GAMEPLAY_FONT_COLOR)
    label.add_theme_color_override("font_outline_color", GAMEPLAY_OUTLINE_COLOR)
    label.add_theme_constant_override("outline_size", 3)
    add_child(label)
    return label


func _update_positions() -> void:
    if _camera == null:
        return
    var viewport_size: Vector2 = _camera.get_viewport().get_visible_rect().size
    var avoid_rect: Rect2 = Rect2()
    if _avoid_control != null and _avoid_control.is_visible_in_tree():
        avoid_rect = _avoid_control.get_global_rect().grow(4.0)
    if (
        _last_camera_size == _camera.size
        and _last_camera_transform == _camera.global_transform
        and _last_viewport_size == viewport_size
        and _last_avoid_rect == avoid_rect
    ):
        return
    _last_camera_size = _camera.size
    _last_camera_transform = _camera.global_transform
    _last_viewport_size = viewport_size
    _last_avoid_rect = avoid_rect
    var overview: bool = _camera.size >= 13000.0
    var font_size: int = font_size_for_zoom(_camera.size)
    if font_size != _last_font_size:
        for label: Label in _labels.values():
            label.add_theme_font_size_override("font_size", font_size)
        _last_font_size = font_size
    if overview != _last_overview:
        for label: Label in _labels.values():
            label.add_theme_color_override(
                "font_color", OVERVIEW_FONT_COLOR if overview else GAMEPLAY_FONT_COLOR
            )
            label.add_theme_color_override(
                "font_outline_color",
                OVERVIEW_OUTLINE_COLOR if overview else GAMEPLAY_OUTLINE_COLOR
            )
        _last_overview = overview
    var center_province: int = _center_province(viewport_size)
    var preferred: Array[Dictionary] = []
    for key: String in _labels:
        var label: Label = _labels[key]
        label.text = _names[key]
        var anchor: Vector3 = _anchors[key]
        var behind_camera: bool = _camera.is_position_behind(anchor)
        var point: Vector2 = (
            Vector2.ZERO if behind_camera else _camera.unproject_position(anchor)
        )
        var size: Vector2 = label.get_combined_minimum_size()
        var outside_view: bool = (
            point.x < size.x * 0.5 + 4.0
            or point.y < size.y * 0.5 + 4.0
            or point.x > viewport_size.x - size.x * 0.5 - 4.0
            or point.y > viewport_size.y - size.y * 0.5 - 4.0
        )
        if behind_camera or (outside_view and not overview) or (
            overview and (
                point.x < -size.x or point.y < -size.y
                or point.x > viewport_size.x + size.x
                or point.y > viewport_size.y + size.y
            )
        ):
            if center_province < 0 or _province_regions.get(center_province, "") != key:
                label.visible = false
                continue
            point = viewport_size * 0.5
        label.visible = true
        label.size = size
        preferred.append({"key": key, "point": point, "size": size})
    preferred.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if is_equal_approx(a["point"].x, b["point"].x):
            return String(a["key"]) < String(b["key"])
        return a["point"].x < b["point"].x
    )
    var placed: Array[Rect2] = []
    if avoid_rect.has_area():
        placed.append(avoid_rect)
    for entry: Dictionary in preferred:
        var rect: Rect2 = Rect2(entry["point"] - entry["size"] * 0.5, entry["size"])
        if overview or (avoid_rect.has_area() and rect.intersects(avoid_rect)):
            rect = _place_without_overlap(rect, placed, viewport_size)
        _labels[entry["key"]].position = rect.position
        placed.append(rect)


func _center_province(viewport_size: Vector2) -> int:
    var ray_origin: Vector3 = _camera.project_ray_origin(viewport_size * 0.5)
    var ray_direction: Vector3 = _camera.project_ray_normal(viewport_size * 0.5)
    if ray_direction.y >= -0.001:
        return -1
    var height: float = 0.0
    var point: Vector3 = Vector3.ZERO
    for step: int in 2:
        point = ray_origin + ray_direction * ((height - ray_origin.y) / ray_direction.y)
        height = _terrain.data.get_height(point)
        if is_nan(height):
            height = 0.0
    return _geography.find_province_id(Vector2(point.x, point.z))


func _place_without_overlap(rect: Rect2, placed: Array[Rect2], viewport_size: Vector2) -> Rect2:
    var best_rect: Rect2 = rect
    var best_score: float = INF
    for radius: int in 10:
        for x_step: int in range(-radius, radius + 1):
            for y_step: int in range(-radius, radius + 1):
                if maxi(absi(x_step), absi(y_step)) != radius:
                    continue
                var candidate: Rect2 = Rect2(
                    rect.position + Vector2(x_step, y_step) * 20.0, rect.size
                )
                if (
                    candidate.position.x < 4.0 or candidate.position.y < 4.0
                    or candidate.end.x > viewport_size.x - 4.0
                    or candidate.end.y > viewport_size.y - 4.0
                ):
                    continue
                var overlap: float = 0.0
                for other: Rect2 in placed:
                    var expanded: Rect2 = other.grow(3.0)
                    if candidate.intersects(expanded):
                        overlap += candidate.intersection(expanded).get_area()
                var displacement: float = candidate.position.distance_squared_to(rect.position)
                var score: float = overlap * 100.0 + displacement
                if score < best_score:
                    best_score = score
                    best_rect = candidate
        if best_score < INF and best_score <= float(radius * radius * 400):
            return best_rect
    return best_rect


static func font_size_for_zoom(zoom: float) -> int:
    if zoom < 1100.0:
        return 16
    if zoom < 2400.0:
        return 17
    if zoom < 5000.0:
        return 16
    return 14


static func build_specs(
    geography: ProvinceGeography,
    culture_by_province: Dictionary[int, String]
) -> Dictionary[String, Dictionary]:
    if geography == null or culture_by_province.size() != geography.get_province_count():
        return {}
    var visited: Dictionary[int, bool] = {}
    var specs: Dictionary[String, Dictionary] = {}
    for starting_id: int in geography.get_province_ids():
        if visited.has(starting_id):
            continue
        if not culture_by_province.has(starting_id):
            return {}
        var culture: String = culture_by_province[starting_id]
        if culture.is_empty():
            return {}
        var queue: Array[int] = [starting_id]
        var component: Array[int] = []
        visited[starting_id] = true
        while not queue.is_empty():
            var province_id: int = queue.pop_front()
            component.append(province_id)
            var record: Dictionary = geography.get_province_record(province_id)
            for adjacent_id: int in record["neighbor_ids"]:
                if visited.has(adjacent_id):
                    continue
                if not culture_by_province.has(adjacent_id):
                    return {}
                if culture_by_province[adjacent_id] != culture:
                    continue
                visited[adjacent_id] = true
                queue.append(adjacent_id)
        component.sort()
        var center: Vector2 = Vector2.ZERO
        var total_weight: float = 0.0
        for province_id: int in component:
            var record: Dictionary = geography.get_province_record(province_id)
            var weight: float = sqrt(maxf(float(record["area_godot_units_squared"]), 1.0))
            center += record["selection_point"] * weight
            total_weight += weight
        center /= total_weight
        var anchor_id: int = -1
        var best_distance: float = INF
        for province_id: int in component:
            var record: Dictionary = geography.get_province_record(province_id)
            var distance: float = record["selection_point"].distance_squared_to(center)
            if distance < best_distance:
                anchor_id = province_id
                best_distance = distance
        var key: String = str(component[0])
        specs[key] = {
            "culture": culture,
            "province_ids": component,
            "anchor_province_id": anchor_id,
            "anchor_xz": geography.get_province_record(anchor_id)["selection_point"],
        }
    return specs
