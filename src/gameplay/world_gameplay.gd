class_name WorldGameplay
extends Node3D


const PROVINCE_DATA_PATH: String = "res://data/world_map/astra_provinces.json"
const INVALID_PROVINCE_ID: int = -1
const WorldIdentityCatalogueScript: GDScript = preload(
    "res://src/simulation/world_identity_catalogue.gd"
)


var _geography: ProvinceGeography
var _identity_catalogue: RefCounted
var _prototype_world_state: PrototypeWorldState

@onready var natural_world: Node3D = $NaturalWorld
@onready var interaction: ProvinceInteraction = $ProvinceInteraction
@onready var presentation: ProvincePresentation = $ProvincePresentation
@onready var debug_panel: ProvinceDebugPanel = $GameplayUI/ProvinceDebugPanel


func _ready() -> void:
    await get_tree().process_frame
    if not initialize_gameplay_data():
        return

    var terrain: Terrain3D = natural_world.get_node("Terrain3D") as Terrain3D
    var camera: Camera3D = natural_world.get_node("InspectionCamera") as Camera3D
    var inspection_controls: CanvasLayer = natural_world.get_node("InspectionControls") as CanvasLayer
    inspection_controls.visible = false

    presentation.configure(_geography, terrain, camera)
    interaction.hovered_province_changed.connect(presentation.set_hovered_province_id)
    interaction.selected_province_changed.connect(presentation.set_selected_province_id)
    interaction.selected_province_changed.connect(_on_selected_province_changed)
    interaction.configure(_geography, camera, terrain)
    debug_panel.clear_selection()
    print(
        "GAMEPLAY_001_READY: %d canonical province identities; %d starting realms"
        % [
            _identity_catalogue.get_province_count(),
            _identity_catalogue.get_realm_count(),
        ]
    )


func initialize_gameplay_data() -> bool:
    if _geography != null and _identity_catalogue != null and _prototype_world_state != null:
        return true
    _geography = ProvinceGeography.load_from_path(PROVINCE_DATA_PATH)
    if _geography == null or _geography.get_province_count() == 0:
        push_error("Gameplay 001 requires non-empty authoritative province data.")
        return false
    _identity_catalogue = WorldIdentityCatalogueScript.load_default()
    if _identity_catalogue == null:
        push_error("Gameplay 001 requires valid canonical world identity data.")
        return false
    _prototype_world_state = PrototypeWorldState.create(_geography.get_province_ids())
    if _prototype_world_state == null:
        push_error("Gameplay 001 prototype state could not be created.")
        return false
    return true


func get_province_inspection(province_id: int) -> Dictionary:
    if not initialize_gameplay_data():
        return {}
    var geography: Dictionary = _geography.get_province_record(province_id)
    var province_identity: Dictionary = _identity_catalogue.get_province_identity(province_id)
    var realm_identity: Dictionary = _identity_catalogue.get_starting_realm_for_province(
        province_id
    )
    var prototype_metrics: ProvinceState = _prototype_world_state.get_province_state(
        province_id
    )
    if (
        geography.is_empty()
        or province_identity.is_empty()
        or realm_identity.is_empty()
        or prototype_metrics == null
    ):
        push_error("Gameplay inspection could not resolve province %d." % province_id)
        return {}
    return {
        "geography": geography,
        "province_identity": province_identity,
        "realm_identity": realm_identity,
        "prototype_metrics": prototype_metrics,
    }


func get_active_province_ids() -> PackedInt32Array:
    if not initialize_gameplay_data():
        return []
    return _geography.get_province_ids()


func _on_selected_province_changed(province_id: int) -> void:
    if province_id == INVALID_PROVINCE_ID:
        debug_panel.clear_selection()
        return
    var inspection: Dictionary = get_province_inspection(province_id)
    if inspection.is_empty():
        debug_panel.clear_selection()
        return
    debug_panel.show_province(
        inspection["geography"],
        inspection["province_identity"],
        inspection["realm_identity"],
        inspection["prototype_metrics"]
    )
