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
var _inspection_provinces: Dictionary[int, ProvinceState] = {}
var _campaign_session: CampaignSession
var _last_campaign_revision: int = -1
var _political_map: PoliticalMapPresentation = PoliticalMapPresentation.new()
var _realm_labels: PoliticalRealmLabels
var _culture_map: PoliticalMapPresentation = PoliticalMapPresentation.new()
var _culture_labels: CultureRegionLabels
var _map_mode: StringName = &"normal"

@onready var natural_world: Node3D = $NaturalWorld
@onready var interaction: ProvinceInteraction = $ProvinceInteraction
@onready var presentation: ProvincePresentation = $ProvincePresentation
@onready var settlement_prototype: SettlementPrototypeTest = $SettlementPrototypeTestRoot
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
    if not _political_map.configure(terrain):
        return
    # A separate instance reuses the accepted Province-mask shader path without
    # sharing palette state or changing the Political presentation.
    if not _culture_map.configure(terrain):
        return
    _realm_labels = PoliticalRealmLabels.new()
    _realm_labels.name = "PoliticalRealmLabels"
    _realm_labels.configure(_geography, terrain, camera, _identity_catalogue, debug_panel)
    add_child(_realm_labels)
    _culture_labels = CultureRegionLabels.new()
    _culture_labels.name = "CultureRegionLabels"
    _culture_labels.configure(_geography, terrain, camera, debug_panel)
    add_child(_culture_labels)
    settlement_prototype.configure(terrain, _geography)
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
    # Gameplay 001 has no authored scenario roster yet. These ProvinceState
    # records are its initial current ownership, seeded once from frozen canon.
    for province_id: int in _geography.get_province_ids():
        var identity: Dictionary = _identity_catalogue.get_province_identity(province_id)
        var province: ProvinceState = ProvinceState.new()
        province.province_id = province_id
        province.owner_realm_id = String(identity["starting_realm_id"])
        province.local_culture = String(identity["culture"])
        _inspection_provinces[province_id] = province
    return true


func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.physical_keycode == KEY_P:
        get_viewport().set_input_as_handled()
        if _geography != null and _political_map != null:
            _set_map_mode(&"normal" if _map_mode == &"political" else &"political")
    elif event.physical_keycode == KEY_C:
        get_viewport().set_input_as_handled()
        if _geography != null and _culture_map != null:
            _set_map_mode(&"normal" if _map_mode == &"culture" else &"culture")


func _process(_delta: float) -> void:
    if _campaign_session == null or _map_mode == &"normal":
        return
    if _campaign_session.revision() != _last_campaign_revision:
        _last_campaign_revision = _campaign_session.revision()
        if _map_mode == &"political":
            _refresh_political_colors()
        elif _map_mode == &"culture":
            _refresh_culture_colors()


func _set_map_mode(mode: StringName) -> void:
    if mode == _map_mode or mode not in [&"normal", &"political", &"culture"]:
        return
    if mode == &"political":
        if not _refresh_political_colors():
            return
    elif mode == &"culture":
        if not _refresh_culture_colors():
            return
    if _map_mode == &"political":
        _realm_labels.set_enabled(false)
        _political_map.set_enabled(false)
        presentation.set_political_colors({})
    elif _map_mode == &"culture":
        _culture_labels.set_enabled(false)
        _culture_map.set_enabled(false)
    if mode == &"political":
        _political_map.set_enabled(true)
        _realm_labels.set_enabled(true)
    elif mode == &"culture":
        _culture_map.set_enabled(true)
        _culture_labels.set_enabled(true)
    _map_mode = mode


func _refresh_political_colors() -> bool:
    var owners: Dictionary[int, String] = _current_owners()
    if _realm_labels == null or not _realm_labels.refresh_ownership(owners, _campaign_session):
        return false
    var colors: Dictionary[int, Color] = _political_map.refresh_ownership(
        _geography, owners
    )
    if colors.size() != _geography.get_province_count():
        return false
    presentation.set_political_colors(colors)
    return true


func _refresh_culture_colors() -> bool:
    var cultures: Dictionary[int, String] = _current_cultures()
    if _culture_labels == null or not _culture_labels.refresh_cultures(cultures):
        return false
    var colors: Dictionary[int, Color] = _culture_map.refresh_ownership(_geography, cultures)
    return colors.size() == _geography.get_province_count()


func _current_owners() -> Dictionary[int, String]:
    var owners: Dictionary[int, String] = {}
    for province_id: int in _geography.get_province_ids():
        var province: ProvinceState = (
            _campaign_session.get_province(province_id)
            if _campaign_session != null else _inspection_provinces.get(province_id)
        )
        if province == null:
            return {}
        owners[province_id] = province.owner_realm_id
    return owners


func _current_cultures() -> Dictionary[int, String]:
    var cultures: Dictionary[int, String] = {}
    for province_id: int in _geography.get_province_ids():
        var province: ProvinceState = (
            _campaign_session.get_province(province_id)
            if _campaign_session != null else _inspection_provinces.get(province_id)
        )
        if province == null or province.local_culture.is_empty():
            return {}
        cultures[province_id] = province.local_culture
    return cultures


func bind_campaign_session(session: CampaignSession) -> bool:
    if session == null or not initialize_gameplay_data():
        return false
    for province_id: int in _geography.get_province_ids():
        if session.get_province(province_id) == null:
            return false
    _campaign_session = session
    _last_campaign_revision = session.revision()
    _inspection_provinces.clear()
    if _map_mode == &"political":
        return _refresh_political_colors()
    if _map_mode == &"culture":
        return _refresh_culture_colors()
    return true


func get_province_inspection(province_id: int) -> Dictionary:
    if not initialize_gameplay_data():
        return {}
    var geography: Dictionary = _geography.get_province_record(province_id)
    var province_identity: Dictionary = _identity_catalogue.get_province_identity(province_id)
    var realm_identity: Dictionary = _identity_catalogue.get_starting_realm_for_province(
        province_id
    )
    var prototype_metrics: PrototypeProvinceMetrics = _prototype_world_state.get_province_state(
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
