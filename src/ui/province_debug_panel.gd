class_name ProvinceDebugPanel
extends PanelContainer


@onready var title_label: Label = $Margin/Rows/Title
@onready var details_label: Label = $Margin/Rows/Details


func clear_selection() -> void:
    title_label.text = "No province selected"
    details_label.text = "Hover a province to inspect its border.\nLeft click selects. Escape clears selection."


func show_province(
        province: Dictionary,
        province_state: ProvinceState,
        realm_state: RealmState
) -> void:
    if province.is_empty() or province_state == null or realm_state == null:
        clear_selection()
        return
    var neighbor_ids: PackedInt32Array = province["neighbor_ids"]
    title_label.text = "Province %d" % province_state.get_province_id()
    details_label.text = (
        "Province Name: %s\n"
        + "Area: %.0f\n"
        + "Neighbours: %d\n\n"
        + "Realm: %s\n"
        + "Realm Type: %s\n\n"
        + "Population: %d\n"
        + "Food: %d\n"
        + "Carrots: %d\n"
        + "Development: %d"
    ) % [
        province["name"],
        province["area_godot_units_squared"],
        neighbor_ids.size(),
        realm_state.get_display_name(),
        String(realm_state.get_realm_type()).capitalize(),
        province_state.get_population(),
        province_state.get_food(),
        province_state.get_carrots(),
        province_state.get_development(),
    ]
