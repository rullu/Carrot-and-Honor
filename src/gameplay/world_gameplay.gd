class_name WorldGameplay
extends Node3D


const PROVINCE_DATA_PATH: String = "res://data/world_map/astra_provinces.json"
const INVALID_PROVINCE_ID: int = -1


var _geography: ProvinceGeography
var _world_state: PrototypeWorldState

@onready var natural_world: Node3D = $NaturalWorld
@onready var interaction: ProvinceInteraction = $ProvinceInteraction
@onready var presentation: ProvincePresentation = $ProvincePresentation
@onready var debug_panel: ProvinceDebugPanel = $GameplayUI/ProvinceDebugPanel


func _ready() -> void:
    await get_tree().process_frame
    _geography = ProvinceGeography.load_from_path(PROVINCE_DATA_PATH)
    if _geography == null or _geography.get_province_count() == 0:
        push_error("Gameplay 001 requires non-empty authoritative province data.")
        return
    _world_state = PrototypeWorldState.create(_geography.get_province_ids())
    if _world_state == null:
        push_error("Gameplay 001 prototype state could not be created.")
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
        "GAMEPLAY_001_READY: %d active provinces; province and realm state separated"
        % _geography.get_province_count()
    )


func _on_selected_province_changed(province_id: int) -> void:
    if province_id == INVALID_PROVINCE_ID:
        debug_panel.clear_selection()
        return
    var province_state: ProvinceState = _world_state.get_province_state(province_id)
    var realm_state: RealmState = _world_state.get_realm_for_province(province_id)
    debug_panel.show_province(
        _geography.get_province_record(province_id),
        province_state,
        realm_state
    )
