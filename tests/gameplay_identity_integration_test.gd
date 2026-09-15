extends SceneTree


const GAMEPLAY_SCENE_PATH: String = "res://scenes/gameplay/world_gameplay.tscn"
const ProvinceDebugPanelScript: GDScript = preload(
    "res://src/ui/province_debug_panel.gd"
)
const REQUIRED_EXAMPLES: Dictionary = {
    5: ["Meyru", "R041", "Beylik of Meyru", "Averi", "Way of Aven", "Rite of the Living Garden"],
    30: ["Hasenmark", "R028", "Banate of Vel-Kareth", "Carthen", "Rethic Faith", "Rite of the Living Crown"],
    32: ["Eldsund", "R009", "Earldom of Eldsund", "Eldskar", "Hearthbound Faith", "Rite of the Buried Ember"],
    51: ["Seravelle", "R008", "Seravelle", "Velaine", "Rethic Faith", "Rite of the Living Crown"],
    53: ["Conejolandia", "R012", "Principality of Conejolandia", "Saleran", "Rethic Faith", "Rite of First Light"],
    99: ["Zahraim Darun", "R038", "Sultanate of Darun", "Qasren", "Way of Aven", "Rite of the Veiled Spring"],
    103: ["Keldren", "R022", "Jarldom of Skeldmark", "Skeldren", "Hearthbound Faith", "Rite of the Buried Ember"],
}
const STALE_VISIBLE_NAMES: Array[String] = [
    "Free Province League",
    "Hasenreich",
    "Bunnyhausen",
]


var _failures: int = 0


func _initialize() -> void:
    var packed_scene: PackedScene = load(GAMEPLAY_SCENE_PATH) as PackedScene
    _check(packed_scene != null, "gameplay scene loads")
    if packed_scene == null:
        _finish()
        return
    var gameplay: Node = packed_scene.instantiate()
    _check(gameplay.initialize_gameplay_data(), "gameplay scene initializes canonical data")
    if _failures > 0:
        gameplay.free()
        _finish()
        return

    var seen_province_ids: Dictionary[int, bool] = {}
    var seen_owner_ids: Dictionary[String, bool] = {}
    for province_id: int in gameplay.get_active_province_ids():
        var inspection: Dictionary = gameplay.get_province_inspection(province_id)
        if inspection.is_empty():
            continue
        _check(not seen_province_ids.has(province_id), "province %d resolves once" % province_id)
        seen_province_ids[province_id] = true
        _validate_inspection(province_id, inspection)
        var identity: Dictionary = inspection["province_identity"]
        seen_owner_ids[String(identity["starting_realm_id"])] = true

    _check(seen_province_ids.size() == 100, "all 100 active provinces resolve through gameplay")
    _check(seen_owner_ids.size() == 43, "gameplay resolves all 43 frozen starting owners")
    for province_id: int in REQUIRED_EXAMPLES:
        var inspection: Dictionary = gameplay.get_province_inspection(province_id)
        _validate_required_example(province_id, inspection)

    var province_5: Dictionary = gameplay.get_province_inspection(5)
    var display_5: Dictionary = _build_display(province_5)
    _check("Mengia" not in display_5.get("details", ""), "province 5 does not display geography source name")
    _check("Hasenreich" not in display_5.get("details", ""), "province 5 does not display mock realm")
    var province_103: Dictionary = gameplay.get_province_inspection(103)
    var display_103: Dictionary = _build_display(province_103)
    _check(
        "Proposal Province 103" not in display_103.get("details", ""),
        "province 103 does not display provisional geography name"
    )
    _check(
        "Free Province League" not in display_103.get("details", ""),
        "province 103 does not display mock realm"
    )
    _check(
        "Prototype Metrics (not canon)" in display_5.get("details", ""),
        "synthetic economic values are visibly labelled non-canon"
    )
    _validate_actual_scene_selection(gameplay)
    gameplay.free()
    _finish()


func _validate_inspection(province_id: int, inspection: Dictionary) -> void:
    var geography: Dictionary = inspection.get("geography", {})
    var identity: Dictionary = inspection.get("province_identity", {})
    var realm: Dictionary = inspection.get("realm_identity", {})
    var metrics: ProvinceState = inspection.get("prototype_metrics")
    _check(int(geography.get("id", -1)) == province_id, "province %d geography resolves" % province_id)
    _check(int(identity.get("province_id", -1)) == province_id, "province %d identity resolves" % province_id)
    _check(metrics != null and metrics.get_province_id() == province_id, "province %d prototype metrics remain isolated" % province_id)
    _check(
        identity.get("starting_realm_id") == realm.get("realm_id"),
        "province %d owner resolves to its canonical realm" % province_id
    )
    var display: Dictionary = _build_display(inspection)
    _check(not display.is_empty(), "province %d display data builds" % province_id)
    _check(String(identity.get("province_name", "")) in display.get("title", ""), "province %d title uses canonical name" % province_id)
    _check(String(identity.get("starting_realm_id", "")) in display.get("details", ""), "province %d details use canonical owner" % province_id)
    for stale_name: String in STALE_VISIBLE_NAMES:
        _check(stale_name not in display.get("details", ""), "province %d excludes stale realm %s" % [province_id, stale_name])


func _validate_required_example(province_id: int, inspection: Dictionary) -> void:
    _check(not inspection.is_empty(), "required province %d resolves" % province_id)
    if inspection.is_empty():
        return
    var expected: Array = REQUIRED_EXAMPLES[province_id]
    var identity: Dictionary = inspection["province_identity"]
    var realm: Dictionary = inspection["realm_identity"]
    var religion: Dictionary = identity["religion"]
    var realm_display_name: String = ""
    if realm.get("display_name") != null:
        realm_display_name = String(realm["display_name"])
    if realm_display_name.is_empty():
        realm_display_name = String(realm.get("realm_name", ""))
    _check(identity["province_name"] == expected[0], "province %d canonical name" % province_id)
    _check(identity["starting_realm_id"] == expected[1], "province %d canonical owner" % province_id)
    _check(realm_display_name == expected[2], "province %d canonical realm name" % province_id)
    _check(identity["culture"] == expected[3], "province %d canonical culture" % province_id)
    _check(religion["broad_faith"] == expected[4], "province %d canonical faith" % province_id)
    _check(religion["rite_or_belief"] == expected[5], "province %d canonical rite/belief" % province_id)


func _build_display(inspection: Dictionary) -> Dictionary:
    return ProvinceDebugPanelScript.build_display_data(
        inspection.get("geography", {}),
        inspection.get("province_identity", {}),
        inspection.get("realm_identity", {}),
        inspection.get("prototype_metrics")
    )


func _validate_actual_scene_selection(gameplay: Node) -> void:
    var panel: ProvinceDebugPanel = gameplay.get_node(
        "GameplayUI/ProvinceDebugPanel"
    ) as ProvinceDebugPanel
    _check(panel != null, "actual gameplay debug panel resolves")
    if panel == null:
        return
    panel.title_label = panel.get_node("Margin/Rows/Title") as Label
    panel.details_label = panel.get_node("Margin/Rows/Details") as Label
    gameplay.debug_panel = panel

    gameplay._on_selected_province_changed(5)
    _check(panel.title_label.text == "Province 5 — Meyru", "actual selection displays Meyru")
    _check("Owner ID: R041" in panel.details_label.text, "actual selection displays R041")
    _check("Realm: Beylik of Meyru" in panel.details_label.text, "actual selection displays Beylik of Meyru")
    _check("Mengia" not in panel.details_label.text, "actual selection excludes Mengia")
    _check("Hasenreich" not in panel.details_label.text, "actual selection excludes Hasenreich")

    gameplay._on_selected_province_changed(103)
    _check(panel.title_label.text == "Province 103 — Keldren", "actual selection displays Keldren")
    _check("Owner ID: R022" in panel.details_label.text, "actual selection displays R022")
    _check("Realm: Jarldom of Skeldmark" in panel.details_label.text, "actual selection displays Skeldmark")
    _check("Proposal Province 103" not in panel.details_label.text, "actual selection excludes provisional name")
    _check("Free Province League" not in panel.details_label.text, "actual selection excludes mock realm")


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures > 0:
        push_error("Gameplay identity integration test FAIL: %d check(s) failed." % _failures)
        quit(1)
        return
    print(
        "Gameplay identity integration test PASS: all 100 displayed province identities and "
        + "43 starting owners resolve canonically; prototype metrics remain explicit."
    )
    quit(0)
