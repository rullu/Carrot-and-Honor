extends SceneTree


const EXPECTED_SOURCE_SHA256: String = "9c36b97b340c1fb5827b897db4f3798d16b017ce0e9906c26426ff295efaaa90"
const HISTORICAL_MAX_PROVINCE_ID: int = 82
const EXPECTED_CANVAS_SIZE: Vector2 = Vector2(2560.0, 1440.0)
const SOURCE_TO_PLAYABLE_SCALE: float = 1.6
const VERTEX_SPACING: float = 12.20703125
const TERRAIN_ORIGIN_XZ: Vector2 = Vector2(-25000.0, -14062.5)
const PLAYABLE_BOUNDS: Rect2 = Rect2(-25000.0, -14062.5, 50000.0, 28125.0)


func _initialize() -> void:
    var arguments: Dictionary = _parse_arguments(OS.get_cmdline_user_args())
    if (
        not arguments.has("source")
        or not arguments.has("manifest")
        or not arguments.has("corrections")
        or not arguments.has("output")
    ):
        push_error(
            "Usage: godot --headless --path <project> --script res://tools/world_map/"
            + "import_astra_provinces.gd -- --source=<Full.json> --manifest=<EXPORT_MANIFEST.json> "
            + "--corrections=res://data/world_map/astra_province_corrections.json "
            + "--output=res://data/world_map/astra_provinces.json"
        )
        quit(1)
        return

    var source_path: String = _global_path(arguments["source"])
    var manifest_path: String = _global_path(arguments["manifest"])
    var corrections_path: String = _global_path(arguments["corrections"])
    var output_path: String = _global_path(arguments["output"])
    var result: Dictionary = _convert(source_path, manifest_path, corrections_path)
    if result.is_empty():
        quit(2)
        return

    var output_directory: String = output_path.get_base_dir()
    if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
        push_error("Could not create output directory: %s" % output_directory)
        quit(3)
        return
    var output_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
    if output_file == null:
        push_error("Could not open province data output: %s" % output_path)
        quit(4)
        return
    output_file.store_string(JSON.stringify(result, "  ", true, true) + "\n")
    output_file.close()
    print(
        "Astra province import PASS: wrote %d authoritative provinces to %s."
        % [result["provinces"].size(), output_path]
    )
    quit(0)


func _convert(source_path: String, manifest_path: String, corrections_path: String) -> Dictionary:
    if FileAccess.get_sha256(source_path) != EXPECTED_SOURCE_SHA256:
        push_error("The Azgaar Full JSON does not match the authoritative SHA-256.")
        return {}
    # Azgaar's large Full export contains legacy name-base text with a small
    # number of unpaired escaped UTF-16 surrogates. Godot correctly rejects
    # those strings, so replace only those invalid escapes before parsing. The
    # authoritative geometry bytes are still protected by the source hash.
    var source_text: String = _sanitize_unpaired_json_surrogates(
        FileAccess.get_file_as_string(source_path)
    )
    var source: Variant = JSON.parse_string(source_text)
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    var corrections: Variant = JSON.parse_string(FileAccess.get_file_as_string(corrections_path))
    if not source is Dictionary or not manifest is Dictionary or not corrections is Dictionary:
        push_error("Could not parse the Azgaar source, Astra manifest, or corrections as JSON objects.")
        return {}
    if not _validate_authorities(source, manifest):
        return {}
    if not _validate_corrections(corrections, source_path):
        return {}

    var pack: Dictionary = source["pack"]
    var cells: Array = pack["cells"]
    var vertices: Array = pack["vertices"]
    var province_definitions: Array = pack["provinces"]
    var cell_province_ids: PackedInt32Array = []
    cell_province_ids.resize(cells.size())
    for cell_index: int in cells.size():
        var cell: Dictionary = cells[cell_index]
        if int(cell["i"]) != cell_index:
            push_error("Azgaar cell index mismatch at array position %d." % cell_index)
            return {}
        var province_id: int = int(cell.get("province", 0))
        if province_id < 0 or province_id > HISTORICAL_MAX_PROVINCE_ID:
            push_error("Cell %d references unexpected province %d." % [cell_index, province_id])
            return {}
        cell_province_ids[cell_index] = province_id
    for vertex_index: int in vertices.size():
        if int(vertices[vertex_index]["i"]) != vertex_index:
            push_error("Azgaar vertex index mismatch at array position %d." % vertex_index)
            return {}

    if not _apply_corrections(corrections, cells, cell_province_ids):
        return {}
    var active_ids: Array = corrections["id_policy"]["active_ids"].duplicate()
    active_ids.sort()
    var definitions_by_id: Dictionary = _build_active_definitions(
        province_definitions, corrections, cells
    )
    if definitions_by_id.is_empty():
        return {}
    var cell_ids_by_province: Dictionary = {}
    for province_id: int in active_ids:
        cell_ids_by_province[province_id] = []
    for cell_index: int in cell_province_ids.size():
        var province_id: int = cell_province_ids[cell_index]
        if province_id > 0:
            if not cell_ids_by_province.has(province_id):
                push_error("Corrected cell %d references inactive province %d." % [cell_index, province_id])
                return {}
            cell_ids_by_province[province_id].append(cell_index)

    var provinces: Array = []
    for province_id: int in active_ids:
        var definition: Dictionary = definitions_by_id[province_id]
        var province: Dictionary = _build_province(
            definition,
            cell_ids_by_province[province_id],
            cells,
            vertices,
            cell_province_ids
        )
        if province.is_empty():
            return {}
        provinces.append(province)

    var anchors: Array = _build_and_validate_anchors(manifest, provinces, corrections)
    if anchors.is_empty():
        return {}
    return {
        "schema_version": 2,
        "source": {
            "kind": "Azgaar Full JSON",
            "file_name": source_path.get_file(),
            "sha256": EXPECTED_SOURCE_SHA256,
            "map_name": source["info"]["mapName"],
            "map_version": source["info"]["version"],
            "seed": source["info"]["seed"],
            "canvas_size": [EXPECTED_CANVAS_SIZE.x, EXPECTED_CANVAS_SIZE.y],
        },
        "corrections": {
            "file_name": corrections_path.get_file(),
            "sha256": FileAccess.get_sha256(corrections_path),
            "historical_max_province_id": HISTORICAL_MAX_PROVINCE_ID,
            "active_province_ids": active_ids,
            "retired_province_ids": corrections["id_policy"]["retired_ids"],
        },
        "coordinate_mapping": {
            "orientation": "north=-Z;south=+Z;west=-X;east=+X;no_flip_rotation_or_recentering",
            "azgaar_to_playable_sample": "sample_x=x*1.6-0.5;sample_y=y*1.6-0.5",
            "playable_sample_to_godot_xz": (
                "X=-25000+(sample_x+0.5)*12.20703125;"
                + "Z=-14062.5+(sample_y+0.5)*12.20703125"
            ),
            "azgaar_to_godot_xz": "X=(x-1280)*19.53125;Z=(y-720)*19.53125",
            "terrain_origin_xz": [TERRAIN_ORIGIN_XZ.x, TERRAIN_ORIGIN_XZ.y],
            "vertex_spacing": VERTEX_SPACING,
            "godot_units_per_authored_metre": 0.1,
            "playable_bounds_xz": [
                PLAYABLE_BOUNDS.position.x,
                PLAYABLE_BOUNDS.position.y,
                PLAYABLE_BOUNDS.end.x,
                PLAYABLE_BOUNDS.end.y,
            ],
            "manifest_anchors": anchors,
        },
        "province_count": provinces.size(),
        "provinces": provinces,
    }


func _validate_authorities(source: Dictionary, manifest: Dictionary) -> bool:
    if not source.has("info") or not source.has("pack"):
        push_error("Azgaar source is missing info or pack data.")
        return false
    var info: Dictionary = source["info"]
    var master: Dictionary = manifest.get("master", {})
    if (
        int(info.get("width", 0)) != int(EXPECTED_CANVAS_SIZE.x)
        or int(info.get("height", 0)) != int(EXPECTED_CANVAS_SIZE.y)
        or info.get("mapName", "") != master.get("mapName", "")
        or info.get("seed", "") != master.get("seed", "")
        or int(master.get("width", 0)) != int(EXPECTED_CANVAS_SIZE.x)
        or int(master.get("height", 0)) != int(EXPECTED_CANVAS_SIZE.y)
    ):
        push_error("Azgaar source and Astra manifest fingerprints do not agree.")
        return false
    var mapping: Dictionary = manifest.get("coordinate_mapping", {})
    if (
        mapping.get("pixel_center_mapping", "") != "px = x*1.6 - 0.5; py = (y+560)*1.6 - 0.5"
        or mapping.get("world_mapping_metres", "")
        != "X=(x-1280)*195.3125; Z=(y-720)*195.3125; Y=R*2560-64"
    ):
        push_error("Astra manifest coordinate mapping is not the expected authority.")
        return false
    var province_definitions: Array = source["pack"].get("provinces", [])
    if province_definitions.size() != HISTORICAL_MAX_PROVINCE_ID + 1:
        push_error("Expected the Azgaar leading zero plus exactly 82 province definitions.")
        return false
    return true


func _validate_corrections(corrections: Dictionary, source_path: String) -> bool:
    if int(corrections.get("schema_version", 0)) != 1:
        push_error("Unsupported province correction schema.")
        return false
    var correction_source: Dictionary = corrections.get("source", {})
    if (
        correction_source.get("sha256", "") != FileAccess.get_sha256(source_path)
        or int(correction_source.get("historical_max_province_id", 0))
        != HISTORICAL_MAX_PROVINCE_ID
    ):
        push_error("Province corrections do not match the immutable Azgaar source.")
        return false
    var id_policy: Dictionary = corrections.get("id_policy", {})
    var active_ids: Array = id_policy.get("active_ids", [])
    var retired_ids: Array = id_policy.get("retired_ids", [])
    if active_ids.is_empty() or not bool(id_policy.get("never_reuse_retired_ids", false)):
        push_error("Province correction ID policy is incomplete.")
        return false
    var seen_ids: Dictionary = {}
    for province_id_value: Variant in active_ids:
        var province_id: int = int(province_id_value)
        if province_id <= 0 or seen_ids.has(province_id) or province_id in retired_ids:
            push_error("Province correction active IDs are invalid or duplicated.")
            return false
        seen_ids[province_id] = true
    for retired_id_value: Variant in retired_ids:
        var retired_id: int = int(retired_id_value)
        if retired_id <= 0 or seen_ids.has(retired_id):
            push_error("Retired province IDs conflict with active IDs.")
            return false
    var supported_operations: Array = corrections.get("supported_operations", [])
    if not "targeted_split_or_reshape_by_source_cell_assignment" in supported_operations:
        push_error("Province corrections do not declare deterministic targeted reshape support.")
        return false
    return true


func _apply_corrections(
    corrections: Dictionary,
    cells: Array,
    cell_province_ids: PackedInt32Array
) -> bool:
    for merge_value: Variant in corrections.get("merges", []):
        var merge: Dictionary = merge_value
        var retained_id: int = int(merge["retained_id"])
        for retired_id_value: Variant in merge["retired_ids"]:
            var retired_id: int = int(retired_id_value)
            for cell_id: int in cell_province_ids.size():
                if cell_province_ids[cell_id] == retired_id:
                    cell_province_ids[cell_id] = retained_id

    var explicitly_assigned: Dictionary = {}
    for assignment_value: Variant in corrections.get("cell_assignments", []):
        var assignment: Dictionary = assignment_value
        var province_id: int = int(assignment["province_id"])
        for cell_id_value: Variant in assignment["cell_ids"]:
            var cell_id: int = int(cell_id_value)
            if cell_id < 0 or cell_id >= cells.size() or explicitly_assigned.has(cell_id):
                push_error("Invalid or duplicate explicit province correction cell %d." % cell_id)
                return false
            explicitly_assigned[cell_id] = true
            cell_province_ids[cell_id] = province_id

    var assigned_features: Dictionary = {}
    for assignment_value: Variant in corrections.get("inland_water_assignments", []):
        var assignment: Dictionary = assignment_value
        var province_id: int = int(assignment["province_id"])
        for feature_id_value: Variant in assignment["feature_ids"]:
            var feature_id: int = int(feature_id_value)
            if assigned_features.has(feature_id):
                push_error("Inland-water feature %d is assigned more than once." % feature_id)
                return false
            assigned_features[feature_id] = true
            var matched_cells: int = 0
            for cell_id: int in cells.size():
                if int(cells[cell_id].get("f", 0)) == feature_id:
                    if int(cells[cell_id].get("h", 0)) >= 20:
                        push_error("Inland-water feature %d unexpectedly contains land." % feature_id)
                        return false
                    if cell_province_ids[cell_id] not in [0, province_id]:
                        push_error(
                            "Inland-water feature %d would overwrite province %d."
                            % [feature_id, cell_province_ids[cell_id]]
                        )
                        return false
                    cell_province_ids[cell_id] = province_id
                    matched_cells += 1
            if matched_cells == 0:
                push_error("Inland-water feature %d has no source cells." % feature_id)
                return false
    return true


func _build_active_definitions(
    province_definitions: Array,
    corrections: Dictionary,
    cells: Array
) -> Dictionary:
    var definitions: Dictionary = {}
    for province_id_value: Variant in corrections["id_policy"]["active_ids"]:
        var province_id: int = int(province_id_value)
        if province_id <= HISTORICAL_MAX_PROVINCE_ID:
            if province_id >= province_definitions.size():
                push_error("Missing historical province definition %d." % province_id)
                return {}
            var definition: Variant = province_definitions[province_id]
            if not definition is Dictionary or int(definition.get("i", 0)) != province_id:
                push_error("Invalid historical province definition %d." % province_id)
                return {}
            definitions[province_id] = definition.duplicate(true)
    for new_value: Variant in corrections.get("new_provinces", []):
        var new_definition: Dictionary = new_value
        var province_id: int = int(new_definition["id"])
        var center_cell_id: int = int(new_definition["selection_cell_id"])
        if (
            province_id <= HISTORICAL_MAX_PROVINCE_ID
            or definitions.has(province_id)
            or center_cell_id < 0
            or center_cell_id >= cells.size()
        ):
            push_error("Invalid new province definition %d." % province_id)
            return {}
        definitions[province_id] = {
            "i": province_id,
            "name": new_definition["name"],
            "fullName": new_definition["full_name"],
            "center": center_cell_id,
            "pole": new_definition["label_point_source_xy"],
            "provisional_name": bool(new_definition.get("provisional_name", false)),
        }
    for override_value: Variant in corrections.get("anchor_overrides", []):
        var anchor_override: Dictionary = override_value
        var province_id: int = int(anchor_override["province_id"])
        if not definitions.has(province_id):
            push_error("Anchor override references inactive province %d." % province_id)
            return {}
        var definition: Dictionary = definitions[province_id]
        if anchor_override.has("selection_cell_id"):
            definition["center"] = int(anchor_override["selection_cell_id"])
        if anchor_override.has("label_point_source_xy"):
            definition["pole"] = anchor_override["label_point_source_xy"]
    if definitions.size() != corrections["id_policy"]["active_ids"].size():
        push_error("Active province definitions are incomplete.")
        return {}
    return definitions


func _build_province(
    definition: Dictionary,
    province_cell_ids: Array,
    cells: Array,
    vertices: Array,
    cell_province_ids: PackedInt32Array
) -> Dictionary:
    var province_id: int = int(definition["i"])
    if province_cell_ids.is_empty():
        push_error("Province %d has no cells." % province_id)
        return {}
    var edge_counts: Dictionary = {}
    var oriented_edges: Dictionary = {}
    var neighbors: Dictionary = {}
    var source_area: float = 0.0
    var cell_orientation: float = 0.0
    for cell_id: int in province_cell_ids:
        var cell: Dictionary = cells[cell_id]
        var vertex_ids: Array = cell["v"]
        source_area += float(cell.get("area", 0.0))
        if cell_orientation == 0.0:
            cell_orientation = signf(_signed_area_for_vertex_ids(vertex_ids, vertices))
        for offset: int in vertex_ids.size():
            var from_id: int = int(vertex_ids[offset])
            var to_id: int = int(vertex_ids[(offset + 1) % vertex_ids.size()])
            var edge_key: String = _undirected_edge_key(from_id, to_id)
            edge_counts[edge_key] = int(edge_counts.get(edge_key, 0)) + 1
            oriented_edges[edge_key] = [from_id, to_id]
        for neighbor_cell_id_value: Variant in cell["c"]:
            var neighbor_cell_id: int = int(neighbor_cell_id_value)
            if neighbor_cell_id < 0 or neighbor_cell_id >= cells.size():
                continue
            var neighbor_id: int = cell_province_ids[neighbor_cell_id]
            if neighbor_id > 0 and neighbor_id != province_id:
                neighbors[neighbor_id] = true

    var boundary_edges: Array = []
    for edge_key: String in edge_counts:
        var count: int = int(edge_counts[edge_key])
        if count == 1:
            boundary_edges.append(oriented_edges[edge_key])
        elif count != 2:
            push_error("Province %d has non-manifold cell edge %s." % [province_id, edge_key])
            return {}
    var vertex_rings: Array = _stitch_boundary_rings(boundary_edges, province_id)
    if vertex_rings.is_empty():
        return {}

    var rings: Array = []
    var source_bounds: Array = [INF, INF, -INF, -INF]
    var world_bounds: Array = [INF, INF, -INF, -INF]
    var world_area: float = 0.0
    for vertex_ring: Array in vertex_rings:
        var source_points: Array = []
        var world_points: Array = []
        for vertex_id: int in vertex_ring:
            var source_point: Array = _copy_point(vertices[vertex_id]["p"])
            var world_point: Array = _azgaar_point_to_godot(source_point)
            source_points.append(source_point)
            world_points.append(world_point)
            _expand_bounds(source_bounds, source_point)
            _expand_bounds(world_bounds, world_point)
        var signed_world_area: float = _signed_area_for_points(world_points)
        var is_hole: bool = signf(signed_world_area) != cell_orientation
        world_area += -absf(signed_world_area) if is_hole else absf(signed_world_area)
        rings.append({
            "is_hole": is_hole,
            "source_points_xy": source_points,
            "points_xz": world_points,
        })

    var center_cell_id: int = int(definition["center"])
    if center_cell_id < 0 or center_cell_id >= cells.size():
        push_error("Province %d has an invalid center cell." % province_id)
        return {}
    var selection_source: Array = _copy_point(cells[center_cell_id]["p"])
    var label_source: Array = _copy_point(definition["pole"])
    var neighbor_ids: Array = neighbors.keys()
    neighbor_ids.sort()
    return {
        "id": province_id,
        "name": definition["name"],
        "full_name": definition.get("fullName", definition["name"]),
        "provisional_name": bool(definition.get("provisional_name", false)),
        "selection_point_source_xy": selection_source,
        "selection_point_xz": _azgaar_point_to_godot(selection_source),
        "label_point_source_xy": label_source,
        "label_point_xz": _azgaar_point_to_godot(label_source),
        "bounding_box_source_xy": source_bounds,
        "bounding_box_xz": world_bounds,
        "source_area": source_area,
        "source_area_unit": "Azgaar exported area units",
        "area_godot_units_squared": world_area,
        "neighbor_ids": neighbor_ids,
        "rings": rings,
    }


func _stitch_boundary_rings(boundary_edges: Array, province_id: int) -> Array:
    var next_by_vertex: Dictionary = {}
    for edge: Array in boundary_edges:
        var from_id: int = int(edge[0])
        var to_id: int = int(edge[1])
        if next_by_vertex.has(from_id):
            push_error("Province %d boundary branches at vertex %d." % [province_id, from_id])
            return []
        next_by_vertex[from_id] = to_id
    var rings: Array = []
    while not next_by_vertex.is_empty():
        var start_id: int = int(next_by_vertex.keys()[0])
        var current_id: int = start_id
        var ring: Array = [start_id]
        while true:
            if not next_by_vertex.has(current_id):
                push_error("Province %d boundary is open at vertex %d." % [province_id, current_id])
                return []
            var next_id: int = int(next_by_vertex[current_id])
            next_by_vertex.erase(current_id)
            ring.append(next_id)
            current_id = next_id
            if current_id == start_id:
                break
            if ring.size() > boundary_edges.size() + 1:
                push_error("Province %d boundary traversal did not close." % province_id)
                return []
        if ring.size() < 4:
            push_error("Province %d contains a degenerate boundary ring." % province_id)
            return []
        rings.append(ring)
    return rings


func _build_and_validate_anchors(
    manifest: Dictionary,
    provinces: Array,
    corrections: Dictionary
) -> Array:
    var anchors: Array = manifest.get("anchors", [])
    if anchors.size() != 8:
        push_error("Expected exactly eight Astra manifest anchors.")
        return []
    var province_by_id: Dictionary = {}
    for province: Dictionary in provinces:
        province_by_id[province["id"]] = province
    var retained_by_retired: Dictionary = {}
    for merge_value: Variant in corrections.get("merges", []):
        var merge: Dictionary = merge_value
        for retired_id_value: Variant in merge["retired_ids"]:
            retained_by_retired[int(retired_id_value)] = int(merge["retained_id"])
    var converted: Array = []
    for anchor: Dictionary in anchors:
        var historical_province_id: int = int(anchor["province"])
        var active_province_id: int = int(
            retained_by_retired.get(historical_province_id, historical_province_id)
        )
        if not province_by_id.has(active_province_id):
            push_error("Manifest anchor references missing active province %d." % active_province_id)
            return []
        var source_point: Vector2 = _array_to_vector2(anchor["azgaar_xy"])
        var province: Dictionary = province_by_id[active_province_id]
        if active_province_id == historical_province_id and (
            province["name"] != anchor["name"]
            or not _array_to_vector2(province["selection_point_source_xy"]).is_equal_approx(source_point)
        ):
            push_error(
                "Manifest anchor %d does not match its active Azgaar province center."
                % historical_province_id
            )
            return []
        var sample_point: Vector2 = source_point * SOURCE_TO_PLAYABLE_SCALE - Vector2(0.5, 0.5)
        var expected_sample: Vector2 = _array_to_vector2(anchor["playable_sample_xy"])
        var world_point: Vector2 = TERRAIN_ORIGIN_XZ + (sample_point + Vector2(0.5, 0.5)) * VERTEX_SPACING
        var expected_world_units: Vector2 = _array_to_vector2(anchor["world_xz_metres"]) * 0.1
        if not sample_point.is_equal_approx(expected_sample) or not world_point.is_equal_approx(expected_world_units):
            push_error(
                "Manifest anchor %d fails the documented Godot mapping."
                % historical_province_id
            )
            return []
        converted.append({
            "historical_province_id": historical_province_id,
            "active_province_id": active_province_id,
            "name": anchor["name"],
            "source_xy": [source_point.x, source_point.y],
            "playable_sample_xy": [sample_point.x, sample_point.y],
            "godot_xz": [world_point.x, world_point.y],
        })
    return converted


func _parse_arguments(raw_arguments: PackedStringArray) -> Dictionary:
    var parsed: Dictionary = {}
    for argument: String in raw_arguments:
        if not argument.begins_with("--") or not argument.contains("="):
            continue
        var separator: int = argument.find("=")
        parsed[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
    return parsed


func _sanitize_unpaired_json_surrogates(source_text: String) -> String:
    var chunks: PackedStringArray = []
    var copied_through: int = 0
    var index: int = source_text.find("\\u")
    while index >= 0:
        var replace_escape: bool = false
        if index + 6 <= source_text.length():
            var code_text: String = source_text.substr(index + 2, 4)
            if code_text.is_valid_hex_number(false):
                var code: int = code_text.hex_to_int()
                if code >= 0xD800 and code <= 0xDBFF:
                    var has_low_surrogate: bool = false
                    if index + 12 <= source_text.length() and source_text.substr(index + 6, 2) == "\\u":
                        var low_text: String = source_text.substr(index + 8, 4)
                        if low_text.is_valid_hex_number(false):
                            var low_code: int = low_text.hex_to_int()
                            has_low_surrogate = low_code >= 0xDC00 and low_code <= 0xDFFF
                    replace_escape = not has_low_surrogate
                elif code >= 0xDC00 and code <= 0xDFFF:
                    var follows_high_surrogate: bool = false
                    if index >= 6 and source_text.substr(index - 6, 2) == "\\u":
                        var high_text: String = source_text.substr(index - 4, 4)
                        if high_text.is_valid_hex_number(false):
                            var high_code: int = high_text.hex_to_int()
                            follows_high_surrogate = high_code >= 0xD800 and high_code <= 0xDBFF
                    replace_escape = not follows_high_surrogate
        if replace_escape:
            chunks.append(source_text.substr(copied_through, index - copied_through))
            chunks.append("\\ufffd")
            copied_through = index + 6
            index = source_text.find("\\u", copied_through)
        else:
            index = source_text.find("\\u", index + 2)
    chunks.append(source_text.substr(copied_through))
    return "".join(chunks)


func _global_path(path: String) -> String:
    return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func _undirected_edge_key(first: int, second: int) -> String:
    return "%d:%d" % [mini(first, second), maxi(first, second)]


func _signed_area_for_vertex_ids(vertex_ids: Array, vertices: Array) -> float:
    var points: Array = []
    for vertex_id: int in vertex_ids:
        points.append(vertices[vertex_id]["p"])
    return _signed_area_for_points(points)


func _signed_area_for_points(points: Array) -> float:
    var twice_area: float = 0.0
    for index: int in points.size() - 1:
        var first: Array = points[index]
        var second: Array = points[index + 1]
        twice_area += float(first[0]) * float(second[1]) - float(second[0]) * float(first[1])
    if points.size() > 1 and not _points_equal(points[0], points[-1]):
        var last: Array = points[-1]
        var first: Array = points[0]
        twice_area += float(last[0]) * float(first[1]) - float(first[0]) * float(last[1])
    return twice_area * 0.5


func _azgaar_to_godot(source_point: Vector2) -> Vector2:
    var sample_point: Vector2 = source_point * SOURCE_TO_PLAYABLE_SCALE - Vector2(0.5, 0.5)
    return TERRAIN_ORIGIN_XZ + (sample_point + Vector2(0.5, 0.5)) * VERTEX_SPACING


func _array_to_vector2(values: Array) -> Vector2:
    return Vector2(float(values[0]), float(values[1]))


func _copy_point(values: Array) -> Array:
    return [float(values[0]), float(values[1])]


func _azgaar_point_to_godot(source_point: Array) -> Array:
    var source_x: float = float(source_point[0])
    var source_y: float = float(source_point[1])
    var sample_x: float = source_x * SOURCE_TO_PLAYABLE_SCALE - 0.5
    var sample_y: float = source_y * SOURCE_TO_PLAYABLE_SCALE - 0.5
    return [
        TERRAIN_ORIGIN_XZ.x + (sample_x + 0.5) * VERTEX_SPACING,
        TERRAIN_ORIGIN_XZ.y + (sample_y + 0.5) * VERTEX_SPACING,
    ]


func _expand_bounds(bounds: Array, point: Array) -> void:
    bounds[0] = minf(float(bounds[0]), float(point[0]))
    bounds[1] = minf(float(bounds[1]), float(point[1]))
    bounds[2] = maxf(float(bounds[2]), float(point[0]))
    bounds[3] = maxf(float(bounds[3]), float(point[1]))


func _points_equal(first: Array, second: Array) -> bool:
    return float(first[0]) == float(second[0]) and float(first[1]) == float(second[1])
