class_name ProvinceDebugPanel
extends PanelContainer


@onready var title_label: Label = $Margin/Rows/Title
@onready var details_label: Label = $Margin/Rows/Details


func clear_selection() -> void:
    title_label.text = "No province selected"
    details_label.text = "Hover a province to inspect its border.\nLeft click selects. Escape clears selection."


func show_province(
        geography: Dictionary,
        province_identity: Dictionary,
        realm_identity: Dictionary,
        prototype_metrics: ProvinceState
) -> void:
    var display: Dictionary = build_display_data(
        geography,
        province_identity,
        realm_identity,
        prototype_metrics
    )
    if display.is_empty():
        clear_selection()
        return
    title_label.text = display["title"]
    details_label.text = display["details"]


static func build_display_data(
        geography: Dictionary,
        province_identity: Dictionary,
        realm_identity: Dictionary,
        prototype_metrics: ProvinceState
) -> Dictionary:
    if (
        geography.is_empty()
        or province_identity.is_empty()
        or realm_identity.is_empty()
        or prototype_metrics == null
    ):
        return {}
    var religion: Variant = province_identity.get("religion")
    var neighbor_ids: Variant = geography.get("neighbor_ids")
    if not religion is Dictionary or not neighbor_ids is PackedInt32Array:
        return {}
    var province_id: int = prototype_metrics.get_province_id()
    if int(province_identity.get("province_id", -1)) != province_id:
        return {}

    var realm_display_name: String = ""
    if realm_identity.get("display_name") != null:
        realm_display_name = String(realm_identity["display_name"])
    if realm_display_name.is_empty():
        realm_display_name = String(realm_identity.get("realm_name", ""))
    var lines: Array[String] = [
        "Identity",
        "Region: %s" % String(province_identity["identity_region"]).capitalize(),
        "Culture: %s" % province_identity["culture"],
        "Faith / Belief: %s" % religion["broad_faith"],
    ]
    _append_optional(lines, "Grand Tradition", religion.get("grand_tradition"))
    _append_optional(lines, "Communion", religion.get("communion"))
    _append_optional(
        lines,
        "Institution / Tradition",
        religion.get("institution_or_tradition")
    )
    lines.append("Rite / Belief: %s" % religion["rite_or_belief"])
    lines.append("")
    lines.append("Starting Political Realm")
    lines.append("Owner ID: %s" % province_identity["starting_realm_id"])
    lines.append("Realm: %s" % realm_display_name)
    _append_optional(lines, "Realm Style", realm_identity.get("realm_style"))
    lines.append(
        "Realm Type: %s"
        % String(realm_identity["realm_type"]).replace("_", " ").capitalize()
    )
    lines.append("")
    lines.append("Geography")
    lines.append("Area: %.0f" % geography["area_godot_units_squared"])
    lines.append("Neighbours: %d" % neighbor_ids.size())
    lines.append("")
    lines.append("Prototype Metrics (not canon)")
    lines.append("Population: %d" % prototype_metrics.get_population())
    lines.append("Food: %d" % prototype_metrics.get_food())
    lines.append("Carrots: %d" % prototype_metrics.get_carrots())
    lines.append("Development: %d" % prototype_metrics.get_development())
    return {
        "title": "Province %d — %s" % [province_id, province_identity["province_name"]],
        "details": "\n".join(lines),
    }


static func _append_optional(lines: Array[String], label: String, value: Variant) -> void:
    if value == null or String(value).is_empty():
        return
    lines.append("%s: %s" % [label, value])
