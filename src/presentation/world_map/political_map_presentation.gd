class_name PoliticalMapPresentation
extends RefCounted


const MASK_PATH: String = "res://assets/world_map/political/province_id_mask.png"
const MASK_SIZE: Vector2i = Vector2i(4096, 2304)
const PALETTE_WIDTH: int = 256
const TINT_STRENGTH: float = 0.38
const FRAGMENT_MARKER: String = "void fragment() {"
const COLOUR_MARKER: String = "    ALBEDO = renderer_colour(clamp(final_colour,vec3(0.0),vec3(.9)));"
const POLITICAL_UNIFORMS: String = """
uniform sampler2D political_province_ids : filter_nearest, repeat_disable;
uniform sampler2D political_province_colors : filter_nearest, repeat_disable;
uniform float political_tint_strength = 0.38;
"""
const POLITICAL_COLOUR: String = """
    ivec2 political_pixel = ivec2(round(
        (v_vertex.xz - vec2(-25000.0, -14062.5)) / 12.20703125
    ));
    if (all(greaterThanEqual(political_pixel, ivec2(0)))
            && all(lessThan(political_pixel, ivec2(4096, 2304)))) {
        int province_id = int(round(texelFetch(
            political_province_ids, political_pixel, 0
        ).r * 255.0));
        vec4 political_color = texelFetch(
            political_province_colors, ivec2(province_id, 0), 0
        );
        if (province_id > 0 && political_color.a > 0.0) {
            final_colour = mix(
                final_colour,
                linear_colour(political_color.rgb),
                political_tint_strength
            );
        }
    }
"""


var _terrain: Terrain3D
var _original_shader: Shader
var _political_shader: Shader
var _province_mask: ImageTexture
var _province_colors: ImageTexture
var _realm_colors: Dictionary[String, Color] = {}
var _enabled: bool = false


func configure(terrain: Terrain3D) -> bool:
    if terrain == null or terrain.material == null:
        push_error("Political map requires the existing Terrain3D material.")
        return false
    var mask: Image = Image.load_from_file(ProjectSettings.globalize_path(MASK_PATH))
    if mask == null or mask.get_size() != MASK_SIZE or mask.get_format() != Image.FORMAT_L8:
        push_error("Political Province ID mask is missing or has the wrong format.")
        return false
    _terrain = terrain
    _original_shader = terrain.material.shader_override
    if _original_shader == null:
        push_error("Political map requires NaturalWorld's configured terrain shader.")
        return false
    var source: String = _original_shader.code
    if source.find(FRAGMENT_MARKER) < 0 or source.find(COLOUR_MARKER) < 0:
        push_error("Political map could not find the NaturalWorld color seam.")
        return false
    _political_shader = Shader.new()
    _political_shader.code = source.replace(
        FRAGMENT_MARKER, POLITICAL_UNIFORMS + "\n" + FRAGMENT_MARKER
    ).replace(COLOUR_MARKER, POLITICAL_COLOUR + "\n" + COLOUR_MARKER)
    _province_mask = ImageTexture.create_from_image(mask)
    return true


func refresh_ownership(
    geography: ProvinceGeography,
    owner_by_province: Dictionary[int, String]
) -> Dictionary[int, Color]:
    if geography == null or owner_by_province.size() != geography.get_province_count():
        push_error("Political map needs one current Realm owner per active Province.")
        return {}
    if _realm_colors.is_empty():
        _realm_colors = PoliticalRealmPalette.assign(geography, owner_by_province)
    if _realm_colors.is_empty():
        push_error("Political Realm palette could not be assigned.")
        return {}
    var image: Image = Image.create(PALETTE_WIDTH, 1, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var province_colors: Dictionary[int, Color] = {}
    for province_id: int in geography.get_province_ids():
        if not owner_by_province.has(province_id):
            push_error("Political map has no owner for Province %d." % province_id)
            return {}
        var realm_id: String = owner_by_province[province_id]
        if not _realm_colors.has(realm_id):
            # A future campaign Realm may appear without recoloring existing Realms.
            var proposed: Dictionary[String, Color] = PoliticalRealmPalette.assign(
                geography, owner_by_province
            )
            if not proposed.has(realm_id):
                return {}
            _realm_colors[realm_id] = proposed[realm_id]
        var color: Color = _realm_colors[realm_id]
        image.set_pixel(province_id, 0, color)
        province_colors[province_id] = color
    _province_colors = ImageTexture.create_from_image(image)
    if _enabled:
        _terrain.material.set_shader_param(&"political_province_colors", _province_colors)
    return province_colors


func set_enabled(enabled: bool) -> void:
    if _terrain == null or _political_shader == null or (_enabled == enabled):
        return
    if enabled and _province_colors == null:
        push_error("Political map cannot enable before current ownership is bound.")
        return
    _enabled = enabled
    if enabled:
        _terrain.material.shader_override = _political_shader
        _terrain.material.set_shader_param(&"political_province_ids", _province_mask)
        _terrain.material.set_shader_param(&"political_province_colors", _province_colors)
        _terrain.material.set_shader_param(&"political_tint_strength", TINT_STRENGTH)
    else:
        _terrain.material.shader_override = _original_shader


func is_enabled() -> bool:
    return _enabled
