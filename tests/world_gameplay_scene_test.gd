extends SceneTree


const GAMEPLAY_SCENE_PATH: String = "res://scenes/gameplay/world_gameplay.tscn"
const NATURAL_WORLD_SCENE_PATH: String = "res://scenes/world_map/astra_natural_world_final.tscn"
const NATURAL_WORLD_SCENE_SHA256: String = "0f5450a6488b3ae7e1789c1bf7bddb69594efb225cd45da3b8d2c52edb7dc90a"
const PROVINCE_DATA_SHA256: String = "c5ccc4f9d5afb4b3988dcb418402ffeccbab08d70cef8c48a9c57df08f993d7e"
const NATURAL_WORLD_CONTROLLER_SHA256: String = "eb9e433f559f741d07ac1327da1b954228f90e721c96f426c7038420095a4a6e"


var _failures: int = 0


func _initialize() -> void:
    _check(
        FileAccess.get_sha256(NATURAL_WORLD_SCENE_PATH) == NATURAL_WORLD_SCENE_SHA256,
        "locked NaturalWorld scene remains unchanged"
    )
    _check(
        FileAccess.get_sha256("res://data/world_map/astra_provinces.json") == PROVINCE_DATA_SHA256,
        "corrected authoritative province geography matches its reviewed artifact"
    )
    _check(
        FileAccess.get_sha256("res://src/presentation/world_map/astra_natural_world.gd")
        == NATURAL_WORLD_CONTROLLER_SHA256,
        "locked NaturalWorld camera controller remains unchanged"
    )

    var packed_scene: PackedScene = load(GAMEPLAY_SCENE_PATH) as PackedScene
    _check(packed_scene != null, "gameplay wrapper scene loads")
    if packed_scene == null:
        _finish()
        return
    var root: Node = packed_scene.instantiate()
    _check(root.name == "WorldGameplay", "wrapper root is WorldGameplay")
    var natural_world: Node = root.get_node_or_null("NaturalWorld")
    _check(natural_world != null, "wrapper instances NaturalWorld")
    if natural_world != null:
        _check(
            natural_world.scene_file_path == NATURAL_WORLD_SCENE_PATH,
            "NaturalWorld is a scene instance rather than duplicated content"
        )
        _check(natural_world.get_node_or_null("Terrain3D") != null, "instance exposes Terrain3D")
        _check(natural_world.get_node_or_null("InspectionCamera") != null, "instance preserves camera")
    _check(root.get_node_or_null("ProvinceInteraction") != null, "interaction responsibility exists")
    _check(root.get_node_or_null("ProvincePresentation") != null, "presentation responsibility exists")
    _check(
        root.get_node_or_null("GameplayUI/ProvinceDebugPanel") != null,
        "debug UI responsibility exists"
    )
    _check(
        root.find_children("*", "CollisionShape3D", true, false).is_empty(),
        "wrapper does not create province collision meshes"
    )
    root.free()
    _finish()


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures > 0:
        push_error("World gameplay scene test FAIL: %d checks failed." % _failures)
        quit(1)
        return
    print("World gameplay scene test PASS: wrapper architecture and locked files validated.")
    quit(0)
