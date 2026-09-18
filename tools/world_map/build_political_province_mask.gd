extends SceneTree


# Presentation derivative only. Pixel values are Province IDs, never Realm IDs.
const GEOGRAPHY_PATH: String = "res://data/world_map/astra_provinces.json"
const OUTPUT_PATH: String = "res://assets/world_map/political/province_id_mask.png"
const MASK_SIZE: Vector2i = Vector2i(4096, 2304)
const WORLD_ORIGIN: Vector2 = Vector2(-25000.0, -14062.5)
const SAMPLE_SPACING: float = 12.20703125


func _initialize() -> void:
    var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEOGRAPHY_PATH))
    if not document is Dictionary or int(document.get("province_count", 0)) != 100:
        push_error("Political mask requires the accepted 100-province geography.")
        quit(1)
        return
    var provinces: Array = document["provinces"].duplicate()
    # Inner islands/enclaves overwrite larger surrounding rings deterministically.
    provinces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["area_godot_units_squared"]) > float(b["area_godot_units_squared"])
    )
    var mask: Image = Image.create(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_L8)
    mask.fill(Color.BLACK)
    for province: Dictionary in provinces:
        var province_id: int = int(province["id"])
        if province_id <= 0 or province_id > 255:
            push_error("Political mask needs 8-bit positive Province IDs.")
            quit(1)
            return
        for ring: Dictionary in province["rings"]:
            if bool(ring["is_hole"]):
                continue
            _fill_ring(mask, ring["points_xz"], province_id)
    var output: String = ProjectSettings.globalize_path(OUTPUT_PATH)
    DirAccess.make_dir_recursive_absolute(output.get_base_dir())
    var error: Error = mask.save_png(output)
    if error != OK:
        push_error("Could not save Province ID mask: %s" % error_string(error))
        quit(1)
        return
    print("POLITICAL_MASK_READY: %s" % OUTPUT_PATH)
    quit(0)


func _fill_ring(mask: Image, source_points: Array, province_id: int) -> void:
    var points: PackedVector2Array = []
    var min_y: float = float(MASK_SIZE.y)
    var max_y: float = 0.0
    for source: Array in source_points:
        var point: Vector2 = (Vector2(float(source[0]), float(source[1])) - WORLD_ORIGIN) / SAMPLE_SPACING
        points.append(point)
        min_y = minf(min_y, point.y)
        max_y = maxf(max_y, point.y)
    var ink: Color = Color(float(province_id) / 255.0, 0.0, 0.0)
    for y: int in range(maxi(0, ceili(min_y)), mini(MASK_SIZE.y - 1, floori(max_y)) + 1):
        var intersections: Array[float] = []
        for index: int in range(points.size() - 1):
            var start: Vector2 = points[index]
            var finish: Vector2 = points[index + 1]
            if (start.y <= float(y) and finish.y > float(y)) or (finish.y <= float(y) and start.y > float(y)):
                intersections.append(start.x + (float(y) - start.y) * (finish.x - start.x) / (finish.y - start.y))
        intersections.sort()
        for pair_index: int in range(0, intersections.size() - 1, 2):
            var left: int = maxi(0, ceili(intersections[pair_index]))
            var right: int = mini(MASK_SIZE.x - 1, floori(intersections[pair_index + 1]))
            for x: int in range(left, right + 1):
                mask.set_pixel(x, y, ink)
