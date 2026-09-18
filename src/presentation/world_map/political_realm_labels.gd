class_name PoliticalRealmLabels
extends CanvasLayer


const LABEL_LIFT: float = 22.0
const FONT_COLOR: Color = Color(0.97, 0.96, 0.91, 1.0)
const OUTLINE_COLOR: Color = Color(0.12, 0.14, 0.16, 0.95)
const OVERVIEW_FONT_COLOR: Color = Color(0.10, 0.12, 0.13, 1.0)
const OVERVIEW_OUTLINE_COLOR: Color = Color(0.97, 0.96, 0.91, 0.97)


var _geography: ProvinceGeography
var _terrain: Terrain3D
var _camera: Camera3D
var _catalogue: RefCounted
var _avoid_control: Control
var _labels: Dictionary[String, Label] = {}
var _world_anchors: Dictionary[String, Vector3] = {}
var _full_names: Dictionary[String, String] = {}
var _owners: Dictionary[int, String] = {}
var _last_font_size: int = -1
var _last_overview: bool = false
var _last_camera_transform: Transform3D
var _last_camera_size: float = -1.0
var _last_viewport_size: Vector2 = Vector2.ZERO
var _last_avoid_rect: Rect2 = Rect2()


func configure(
    geography: ProvinceGeography,
    terrain: Terrain3D,
    camera: Camera3D,
    catalogue: RefCounted,
    avoid_control: Control
) -> void:
    _geography = geography
    _terrain = terrain
    _camera = camera
    _catalogue = catalogue
    _avoid_control = avoid_control
    layer = -1
    visible = false
    set_process(false)


func refresh_ownership(
    owner_by_province: Dictionary[int, String],
    campaign_session: CampaignSession = null
) -> bool:
    if _geography == null or _terrain == null or _camera == null or _catalogue == null:
        push_error("Political Realm labels are not configured.")
        return false
    var specs: Dictionary[String, Dictionary] = build_specs(
        _geography, owner_by_province, _catalogue, campaign_session
    )
    if specs.is_empty():
        push_error("Political Realm labels could not resolve current territory.")
        return false
    _owners = owner_by_province.duplicate()
    for realm_id: String in _labels.keys():
        if specs.has(realm_id):
            continue
        _labels[realm_id].free()
        _labels.erase(realm_id)
        _world_anchors.erase(realm_id)
        _full_names.erase(realm_id)
    var realm_ids: Array[String] = []
    realm_ids.assign(specs.keys())
    realm_ids.sort()
    for realm_id: String in realm_ids:
        var spec: Dictionary = specs[realm_id]
        var label: Label = _labels.get(realm_id)
        if label == null:
            label = _create_label(realm_id)
            _labels[realm_id] = label
        _full_names[realm_id] = spec["name"]
        var anchor_xz: Vector2 = spec["anchor_xz"]
        var height: float = _terrain.data.get_height(
            Vector3(anchor_xz.x, 0.0, anchor_xz.y)
        )
        if is_nan(height):
            height = 0.0
        _world_anchors[realm_id] = Vector3(
            anchor_xz.x, height + LABEL_LIFT, anchor_xz.y
        )
    _last_font_size = -1
    _last_overview = not (_camera.size >= 13000.0)
    _last_camera_size = -1.0
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


func _create_label(realm_id: String) -> Label:
    var label: Label = Label.new()
    label.name = "Realm_" + realm_id
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", FONT_COLOR)
    label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
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
    var font_size: int = font_size_for_zoom(_camera.size)
    var overview: bool = _camera.size >= 13000.0
    if font_size != _last_font_size:
        for label: Label in _labels.values():
            label.add_theme_font_size_override("font_size", font_size)
        _last_font_size = font_size
    if overview != _last_overview:
        for label: Label in _labels.values():
            label.add_theme_color_override(
                "font_color", OVERVIEW_FONT_COLOR if overview else FONT_COLOR
            )
            label.add_theme_color_override(
                "font_outline_color",
                OVERVIEW_OUTLINE_COLOR if overview else OUTLINE_COLOR
            )
        _last_overview = overview
    var center_province: int = _center_province(viewport_size)
    var preferred: Array[Dictionary] = []
    for realm_id: String in _labels:
        var label: Label = _labels[realm_id]
        var name_text: String = _full_names[realm_id]
        label.text = _wrap_name(name_text) if overview else name_text
        var anchor: Vector3 = _world_anchors[realm_id]
        if _camera.is_position_behind(anchor):
            label.visible = false
            continue
        var screen_point: Vector2 = _camera.unproject_position(anchor)
        var label_size: Vector2 = label.get_combined_minimum_size()
        if (
            screen_point.x < -label_size.x
            or screen_point.y < -label_size.y
            or screen_point.x > viewport_size.x + label_size.x
            or screen_point.y > viewport_size.y + label_size.y
        ):
            if center_province < 0 or _owners.get(center_province, "") != realm_id:
                label.visible = false
                continue
            screen_point = viewport_size * 0.5
        label.visible = true
        label.size = label_size
        preferred.append({"realm_id": realm_id, "point": screen_point, "size": label_size})
    preferred.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["point"].x < b["point"].x
    )
    var placed: Array[Rect2] = []
    if avoid_rect.has_area():
        placed.append(avoid_rect)
    for entry: Dictionary in preferred:
        var point: Vector2 = entry["point"]
        var size: Vector2 = entry["size"]
        var rect: Rect2 = Rect2(point - size * 0.5, size)
        if overview or (avoid_rect.has_area() and rect.intersects(avoid_rect)):
            rect = _place_without_overlap(rect, placed, viewport_size)
        _labels[entry["realm_id"]].position = rect.position
        placed.append(rect)


func _center_province(viewport_size: Vector2) -> int:
    if _geography == null or _terrain == null:
        return -1
    var ray_origin: Vector3 = _camera.project_ray_origin(viewport_size * 0.5)
    var ray_direction: Vector3 = _camera.project_ray_normal(viewport_size * 0.5)
    if ray_direction.y >= -0.001:
        return -1
    var ground_height: float = 0.0
    var ground_point: Vector3 = Vector3.ZERO
    for step: int in 2:
        ground_point = ray_origin + ray_direction * ((ground_height - ray_origin.y) / ray_direction.y)
        ground_height = _terrain.data.get_height(ground_point)
        if is_nan(ground_height):
            ground_height = 0.0
    return _geography.find_province_id(Vector2(ground_point.x, ground_point.z))


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
                    candidate.position.x < 4.0
                    or candidate.position.y < 4.0
                    or candidate.end.x > viewport_size.x - 4.0
                    or candidate.end.y > viewport_size.y - 4.0
                ):
                    continue
                var overlap: float = 0.0
                for other: Rect2 in placed:
                    var expanded: Rect2 = other.grow(3.0)
                    if candidate.intersects(expanded):
                        var intersection: Rect2 = candidate.intersection(expanded)
                        overlap += intersection.get_area()
                var displacement: float = candidate.position.distance_squared_to(rect.position)
                var score: float = overlap * 100.0 + displacement
                if score < best_score:
                    best_score = score
                    best_rect = candidate
        if best_score < INF and best_score <= float(radius * radius * 400):
            return best_rect
    return best_rect


static func _wrap_name(name_text: String) -> String:
    if name_text.length() <= 16 or not name_text.contains(" "):
        return name_text
    var words: PackedStringArray = name_text.split(" ")
    var best_break: int = 1
    var best_balance: int = 100000
    for break_index: int in range(1, words.size()):
        var first_line: String = " ".join(words.slice(0, break_index))
        var second_line: String = " ".join(words.slice(break_index))
        var balance: int = maxi(first_line.length(), second_line.length())
        if balance < best_balance:
            best_balance = balance
            best_break = break_index
    return " ".join(words.slice(0, best_break)) + "\n" + " ".join(words.slice(best_break))


static func font_size_for_zoom(zoom: float) -> int:
    if zoom < 1100.0:
        return 16
    if zoom < 2400.0:
        return 17
    if zoom < 5000.0:
        return 16
    if zoom < 13000.0:
        return 14
    return 14


static func build_specs(
    geography: ProvinceGeography,
    owner_by_province: Dictionary[int, String],
    catalogue: RefCounted,
    campaign_session: CampaignSession = null
) -> Dictionary[String, Dictionary]:
    if geography == null or catalogue == null:
        return {}
    var territories: Dictionary[String, Array] = {}
    for province_id: int in geography.get_province_ids():
        if not owner_by_province.has(province_id):
            return {}
        var realm_id: String = owner_by_province[province_id]
        if realm_id.is_empty():
            return {}
        if not territories.has(realm_id):
            territories[realm_id] = []
        territories[realm_id].append(province_id)
    var result: Dictionary[String, Dictionary] = {}
    for realm_id: String in territories:
        var weighted_center: Vector2 = Vector2.ZERO
        var total_weight: float = 0.0
        for province_id: int in territories[realm_id]:
            var record: Dictionary = geography.get_province_record(province_id)
            var weight: float = sqrt(maxf(float(record["area_godot_units_squared"]), 1.0))
            weighted_center += record["selection_point"] * weight
            total_weight += weight
        weighted_center /= total_weight
        var best_id: int = -1
        var best_distance: float = INF
        for province_id: int in territories[realm_id]:
            var record: Dictionary = geography.get_province_record(province_id)
            var distance: float = record["selection_point"].distance_squared_to(weighted_center)
            if distance < best_distance:
                best_id = province_id
                best_distance = distance
        result[realm_id] = {
            "name": resolve_display_name(realm_id, catalogue, campaign_session),
            "anchor_province_id": best_id,
            "anchor_xz": geography.get_province_record(best_id)["selection_point"],
        }
    return result


static func resolve_display_name(
    realm_id: String,
    catalogue: RefCounted,
    campaign_session: CampaignSession = null
) -> String:
    var identity_id: String = realm_id
    if campaign_session != null:
        var realm: RealmState = campaign_session.get_realm(realm_id)
        if realm != null and not realm.political_identity_id.is_empty():
            identity_id = realm.political_identity_id
    var identity: Dictionary = catalogue.get_realm_identity(StringName(identity_id))
    if not identity.is_empty():
        var display_value: Variant = identity.get("display_name")
        var display_name: String = "" if display_value == null else String(display_value)
        return display_name if not display_name.is_empty() else String(identity["realm_name"])
    var formable: Dictionary = catalogue.get_formable(StringName(identity_id))
    if not formable.is_empty():
        var display_value: Variant = formable.get("display_name")
        var display_name: String = "" if display_value == null else String(display_value)
        return display_name if not display_name.is_empty() else String(formable["formable_name"])
    # A generated Realm with no authored political identity has no proper name yet.
    return realm_id
