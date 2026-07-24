extends SceneTree


const TERRAIN_PATH := "res://assets/world_map/base/stage_1_5_six_province_map_01_terrain_base_candidate_01.png"
const SCENE_PATH := "res://scenes/world_map/world_map_integration_proof.tscn"
const CONTROLLER_PATH := "res://src/presentation/world_map/world_map_camera_controller.gd"
const CENTER := Vector2(960.0, 540.0)
const TERRAIN_SIZE := Vector2(1920.0, 1080.0)
const ACTIONS: Array[StringName] = [&"map_move_up", &"map_move_down", &"map_move_left", &"map_move_right"]


var _failures: int = 0


func _initialize() -> void:
    var resource: Resource = load(TERRAIN_PATH)
    _check(resource is Texture2D, "PNG resource loads")
    var texture: Texture2D = resource as Texture2D
    if texture != null:
        _check(texture.get_size() == Vector2(1920, 1080), "PNG is 1920 x 1080")

    resource = load(SCENE_PATH)
    _check(resource is PackedScene, "proof scene loads")
    if resource is PackedScene:
        var root: Node = (resource as PackedScene).instantiate()
        _verify_scene(root, texture)
        root.free()

    for action: StringName in ACTIONS:
        _check(InputMap.has_action(action), "%s exists" % action)
        _check(InputMap.action_get_events(action).size() == 2, "%s has two keys" % action)

    if _failures > 0:
        push_error("World-map integration proof test FAIL: %d assertion(s) failed." % _failures)
        quit(1)
        return
    print("World-map integration proof test PASS: terrain, scene, camera, and input checks succeeded.")
    quit(0)


func _verify_scene(root: Node, texture: Texture2D) -> void:
    _check(root is Node2D and root.name == &"WorldMapIntegrationProof", "expected Node2D root exists")
    _check(root.get_child_count() == 2, "proof has only Terrain and WorldMapCamera")
    var terrain: Node = root.get_node_or_null("Terrain")
    var camera: Node = root.get_node_or_null("WorldMapCamera")
    _check(terrain is Sprite2D, "Terrain Sprite2D exists")
    _check(camera is Camera2D, "WorldMapCamera Camera2D exists")
    if terrain is Sprite2D:
        _check(terrain.position == CENTER, "terrain is centred")
        _check(terrain.scale == Vector2.ONE and is_zero_approx(terrain.rotation), "terrain uses native undistorted scale")
        _check(terrain.texture == texture and terrain.texture.resource_path == TERRAIN_PATH, "terrain uses expected texture")
    if camera is Camera2D:
        _check(camera.position == CENTER and camera.enabled, "camera starts enabled and centred")
        _check(camera.get_script() != null and camera.get_script().resource_path == CONTROLLER_PATH, "controller is attached")
        _verify_cover_calculation(camera)
        _verify_cursor_zoom_anchor(camera)
    _verify_no_simulation_dependency(root)


func _verify_cover_calculation(camera: Camera2D) -> void:
    _verify_viewport_cover(camera, Vector2(1920.0, 1080.0), 1.0, "16:9 viewport")
    _verify_viewport_cover(camera, Vector2(720.0, 1280.0), 1280.0 / 1080.0, "tall viewport")
    _verify_viewport_cover(camera, Vector2(2560.0, 1080.0), 2560.0 / 1920.0, "wide viewport")


func _verify_viewport_cover(
    camera: Camera2D,
    viewport_size: Vector2,
    expected_zoom: float,
    context: String
) -> void:
    var minimum_zoom: float = camera.call("calculate_minimum_cover_zoom", viewport_size)
    var visible_world_size: Vector2 = viewport_size / minimum_zoom
    _check(is_equal_approx(minimum_zoom, expected_zoom), "%s uses stricter cover ratio" % context)
    _check(visible_world_size.x <= TERRAIN_SIZE.x + 0.001, "%s covers horizontal axis" % context)
    _check(visible_world_size.y <= TERRAIN_SIZE.y + 0.001, "%s covers vertical axis" % context)


func _verify_cursor_zoom_anchor(camera: Camera2D) -> void:
    var viewport_size: Vector2 = Vector2(1920.0, 1080.0)
    var cursor_position: Vector2 = Vector2(1200.0, 700.0)
    var previous_position: Vector2 = CENTER
    var previous_zoom: float = 1.0
    var next_zoom: float = 1.5
    var anchored_position: Vector2 = camera.call(
        "calculate_cursor_anchored_position",
        previous_position,
        cursor_position,
        viewport_size,
        previous_zoom,
        next_zoom
    )
    var cursor_offset: Vector2 = cursor_position - viewport_size * 0.5
    var world_point_before: Vector2 = previous_position + cursor_offset / previous_zoom
    var world_point_after: Vector2 = anchored_position + cursor_offset / next_zoom
    _check(
        world_point_after.is_equal_approx(world_point_before),
        "interior cursor world point remains anchored before boundary clamping"
    )


func _verify_no_simulation_dependency(root: Node) -> void:
    var forbidden: String = "res://src/" + "simulation/"
    _check(not FileAccess.get_file_as_string(SCENE_PATH).contains(forbidden), "scene has no simulation dependency")
    _check(not FileAccess.get_file_as_string(CONTROLLER_PATH).contains(forbidden), "controller has no simulation dependency")
    var nodes: Array[Node] = [root]
    while not nodes.is_empty():
        var node: Node = nodes.pop_back()
        var script: Script = node.get_script() as Script
        _check(script == null or not script.resource_path.begins_with(forbidden), "%s has no simulation script" % node.name)
        nodes.append_array(node.get_children())


func _check(condition: bool, context: String) -> void:
    if not condition:
        _failures += 1
        push_error("%s: expected true." % context)
