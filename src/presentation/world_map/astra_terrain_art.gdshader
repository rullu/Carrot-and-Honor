// Copyright Â© 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.
// This shader is the minimum needed to allow the terrain to function, without any texturing.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,skip_vertex_transform;

// Defined Constants
#define SKIP_PASS 0
#define VERTEX_PASS 1
#define FRAGMENT_PASS 2

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    #define fma(a, b, c) ((a) * (b) + (c))
    #define dFdxCoarse(a) dFdx(a)
    #define dFdyCoarse(a) dFdy(a)
#endif

// Private uniforms
// Commented uniforms aren't needed for this shader, but are available for your own needs.
uniform vec3 _camera_pos = vec3(0.f);
uniform float _mesh_size = 48.f;
uniform uint _background_mode = 1u; // NONE = 0, FLAT = 1, NOISE = 2
uniform uint _mouse_layer = 0x80000000u; // Layer 32
uniform float _vertex_spacing = 1.0;
uniform float _vertex_density = 1.0; // = 1/_vertex_spacing
uniform float _region_size = 1024.0;
uniform float _region_texel_size = 0.0009765625; // = 1/1024
uniform int _region_map_size = 32;
uniform int _region_map[1024];
//uniform vec2 _region_locations[1024];
//uniform float _texture_uv_scale_array[32];
//uniform float _texture_detile_array[32];
//uniform vec4 _texture_color_array[32];
uniform highp sampler2DArray _height_maps : repeat_disable;
uniform highp sampler2DArray _control_maps : repeat_disable;
//uniform highp sampler2DArray _color_maps : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
//uniform highp sampler2DArray _texture_array_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
//uniform highp sampler2DArray _texture_array_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

// Surface resources belong only to this preview. The Terrain3D vertex path is unchanged.
uniform bool flat_terrain_normals = false;
uniform highp sampler2D material_mask : filter_linear_mipmap_anisotropic, repeat_disable;
uniform highp sampler2D surface_context : filter_linear_mipmap_anisotropic, repeat_disable;
uniform highp sampler2DArray art_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform highp sampler2DArray art_normal_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float texture_influence : hint_range(0.0, 1.0) = 0.82;
uniform float relief_influence : hint_range(0.0, 1.0) = 0.85;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.4;

const ivec2 MATERIAL_MASK_SIZE = ivec2(4096, 2304);
const vec2 MATERIAL_MASK_WORLD_ORIGIN = vec2(-25000.0, -14062.5);
const float MATERIAL_MASK_SAMPLE_SPACING = 12.20703125;
const float AUTHORED_METRES_PER_UNIT = 10.0;

// The meso widths are art-directed photographic breakup, not literal blade/stone sizes.
const float MESO_METRES[8] = float[8](1700.0, 2200.0, 2300.0, 2400.0, 4200.0, 2200.0, 2100.0, 2800.0);
// Slightly enlarged ground motifs read as brush-sized surface detail at strategy zoom.
const float MICRO_METRES[8] = float[8](12.0, 10.0, 12.0, 24.0, 18.0, 50.0, 12.0, 24.0);
const vec3 SOURCE_SRGB[8] = vec3[8](
    vec3(.2672,.3589,.1580), vec3(.3107,.2398,.0819),
    vec3(.6764,.5783,.4763), vec3(.4765,.3893,.3050),
    vec3(.4232,.3764,.3076), vec3(.4309,.3626,.2049),
    vec3(.5056,.4198,.3345), vec3(.4461,.3807,.1415)
);
const vec3 PALETTE_SRGB[8] = vec3[8](
    vec3(.32,.435,.245), vec3(.46,.465,.335),
    vec3(.60,.535,.385), vec3(.43,.335,.235),
    vec3(.69,.62,.48), vec3(.46,.465,.43),
    vec3(.52,.45,.355), vec3(.405,.435,.30)
);

// Varyings & Types
// Some are required for editor functions
varying float v_vertex_xz_dist;
varying vec3 v_vertex;

////////////////////////
// Vertex
////////////////////////

// Takes in world space XZ (UV) coordinates & search depth (only applicable for background mode none)
// Returns ivec3 with:
// XY: (0 to _region_size - 1) coordinates within a region
// Z: layer index used for texturearrays, -1 if not in a region
ivec3 get_index_coord(const vec2 uv, const int search) {
	vec2 r_uv = round(uv);
	vec2 o_uv = mod(r_uv,_region_size);
	ivec2 pos;
	int bounds, layer_index = -1;
	for (int i = -1; i < clamp(search, SKIP_PASS, FRAGMENT_PASS); i++) {
		if ((layer_index == -1 && _background_mode == 0u ) || i < 0) {
			r_uv -= i == -1 ? vec2(0.0) : vec2(float(o_uv.x <= o_uv.y), float(o_uv.y <= o_uv.x));
			pos = ivec2(floor((r_uv) * _region_texel_size)) + (_region_map_size / 2);
			bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
			layer_index = (_region_map[ pos.y * _region_map_size + pos.x ] * bounds - 1);
		}
	}
	return ivec3(ivec2(mod(r_uv,_region_size)), layer_index);
}

void vertex() {
	// Get vertex of flat plane in world coordinates and set world UV
	v_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Camera distance to vertex on flat plane
	v_vertex_xz_dist = length(v_vertex.xz - _camera_pos.xz);

	// Geomorph vertex, set end and start for linear height interpolate
	float scale = MODEL_MATRIX[0][0];
	float vertex_lerp = smoothstep(0.55, 0.95, (v_vertex_xz_dist / scale - _mesh_size - 4.0) / (_mesh_size - 2.0));
	vec2 v_fract = fract(VERTEX.xz * 0.5) * 2.0;
	// For LOD0 morph from a regular grid to an alternating grid to align with LOD1+
	vec2 shift = (scale < _vertex_spacing + 1e-6) ? // LOD0 or not
		// Shift from regular to symetric
		mix(v_fract, vec2(v_fract.x, -v_fract.y),
			round(fract(round(mod(v_vertex.z * _vertex_density, 4.0)) *
			round(mod(v_vertex.x * _vertex_density, 4.0)) * 0.25))
			) :
		// Symetric shift
		v_fract * round((fract(v_vertex.xz * 0.25 / scale) - 0.5) * 4.0);
	vec2 start_pos = v_vertex.xz * _vertex_density;
	vec2 end_pos = (v_vertex.xz - shift * scale) * _vertex_density;
	v_vertex.xz -= shift * scale * vertex_lerp;

	// UV coordinates in world space. Values are 0 to _region_size within regions
	UV = v_vertex.xz * _vertex_density;

	// UV coordinates in region space + texel offset. Values are 0 to 1 within regions
	UV2 = fma(UV, vec2(_region_texel_size), vec2(0.5 * _region_texel_size));

	// Discard vertices for Holes. 1 lookup
	ivec3 v_region = get_index_coord(start_pos, VERTEX_PASS);
	uint control = floatBitsToUint(texelFetch(_control_maps, v_region, 0)).r;
	bool hole = bool(control >>2u & 0x1u);

	// Show holes to all cameras except mouse camera (on exactly 1 layer)
	if ( !(CAMERA_VISIBLE_LAYERS == _mouse_layer) &&
			(hole || (_background_mode == 0u && v_region.z < 0))) {
		v_vertex.x = 0. / 0.;
	} else {
		// Interpolate Geomorph Start & End, set height. 2 Lookups.
		ivec3 uv_a = get_index_coord(start_pos, VERTEX_PASS);
		ivec3 uv_b = get_index_coord(end_pos, VERTEX_PASS);
		float h = mix(texelFetch(_height_maps, uv_a, 0).r, texelFetch(_height_maps, uv_b, 0).r, vertex_lerp);
		v_vertex.y = h;
	}

	// Convert model space to view space w/ skip_vertex_transform render mode
	VERTEX = (VIEW_MATRIX * vec4(v_vertex, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	BINORMAL = normalize((MODELVIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz);
	TANGENT = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
}


vec2 rotate_uv(vec2 p, float angle) {
    float c = cos(angle), s = sin(angle);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec2 tile_hash(float seed) {
    return fract(sin(vec2(seed * 127.1 + 13.7, seed * 269.5 + 83.1)) * 43758.5453);
}

vec3 linear_colour(vec3 c) {
    return mix(pow((c + vec3(.055)) / 1.055, vec3(2.4)), c/12.92, lessThanEqual(c,vec3(.04045)));
}

vec3 sampled_linear(vec3 c) {
    // Compatibility's OUTPUT_IS_SRGB path supplies sRGB colour samples and
    // expects sRGB ALBEDO. Perform all our grading/blending in linear light.
    return OUTPUT_IS_SRGB ? linear_colour(c) : c;
}

vec3 renderer_colour(vec3 c) {
    vec3 encoded = mix(1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-.055, c*12.92, lessThanEqual(c,vec3(.0031308)));
    return OUTPUT_IS_SRGB ? encoded : c;
}

vec3 grade_colour(vec3 colour, int layer) {
    vec3 ratio = colour / max(linear_colour(SOURCE_SRGB[layer]), vec3(.005));
    float influence = texture_influence;
    if (layer == 5 || layer == 6) {
        // Rock photos supply subordinate stone structure, not a competing ridge pattern.
        vec3 luminance = vec3(.2126,.7152,.0722);
        ratio = vec3(dot(colour,luminance) / dot(linear_colour(SOURCE_SRGB[layer]),luminance));
        influence = .24;
    }
    // Bound the original photo's contrast; retain its chromatic and luminance detail.
    ratio = pow(clamp(ratio, vec3(.22), vec3(3.2)), vec3(.68));
    return linear_colour(PALETTE_SRGB[layer]) * mix(vec3(1.0), ratio, influence);
}

// Two continuous offset/rotation variants. Explicit gradients avoid mip seams
// at the random index boundary. The same transforms apply to all micro maps.
vec4 sample_surface(int layer, vec2 metres, vec2 dx, vec2 dy, float variety,
        float pixel_metres, out vec3 detail_normal) {
    float phase = variety * 7.0 + float(layer) * 1.719;
    float index = floor(phase);
    float blend = smoothstep(.1, .9, fract(phase));
    vec2 hash0 = tile_hash(index), hash1 = tile_hash(index + 1.0);
    float angle0 = hash0.x * 6.2831853, angle1 = hash1.x * 6.2831853;
    float meso = MESO_METRES[layer];
    vec2 uv0 = rotate_uv(metres / meso, angle0) + hash0 * 19.0;
    vec2 uv1 = rotate_uv(metres / meso, angle1) + hash1 * 19.0;
    vec3 c0 = textureGrad(art_albedo, vec3(uv0,float(layer)),
        rotate_uv(dx/meso,angle0), rotate_uv(dy/meso,angle0)).rgb;
    vec3 c1 = textureGrad(art_albedo, vec3(uv1,float(layer)),
        rotate_uv(dx/meso,angle1), rotate_uv(dy/meso,angle1)).rgb;
    vec3 colour = grade_colour(mix(sampled_linear(c0),sampled_linear(c1),blend), layer);
    float micro = MICRO_METRES[layer];
    float close_mix = 1.0 - smoothstep(micro / 32.0, micro / 4.0, pixel_metres);
    detail_normal = vec3(0.0,0.0,1.0);
    float roughness;
    if (close_mix > .005) {
        vec2 mu0 = rotate_uv(metres/micro,angle0) + hash0*19.0;
        vec2 mu1 = rotate_uv(metres/micro,angle1) + hash1*19.0;
        vec4 n0 = textureGrad(art_normal_roughness,vec3(mu0,float(layer)),
            rotate_uv(dx/micro,angle0),rotate_uv(dy/micro,angle0));
        vec4 n1 = textureGrad(art_normal_roughness,vec3(mu1,float(layer)),
            rotate_uv(dx/micro,angle1),rotate_uv(dy/micro,angle1));
        vec3 v0 = n0.rgb*2.0-1.0, v1 = n1.rgb*2.0-1.0;
        v0.xy = rotate_uv(v0.xy*vec2(1.0,-1.0),-angle0)*vec2(1.0,-1.0);
        v1.xy = rotate_uv(v1.xy*vec2(1.0,-1.0),-angle1)*vec2(1.0,-1.0);
        detail_normal = normalize(mix(v0,v1,blend));
        detail_normal.xy *= normal_strength * close_mix;
        detail_normal = normalize(detail_normal);
        roughness = mix(n0.a,n1.a,blend);
        vec3 micro0 = textureGrad(art_albedo,vec3(mu0,float(layer)),
            rotate_uv(dx/micro,angle0),rotate_uv(dy/micro,angle0)).rgb;
        vec3 micro1 = textureGrad(art_albedo,vec3(mu1,float(layer)),
            rotate_uv(dx/micro,angle1),rotate_uv(dy/micro,angle1)).rgb;
        colour = mix(colour,grade_colour(mix(sampled_linear(micro0),sampled_linear(micro1),blend),layer),close_mix*.7);
    } else {
        roughness = textureLod(art_normal_roughness,vec3(.5,.5,float(layer)),11.0).a;
    }
    return vec4(colour,clamp(mix(.88,roughness,.55),.62,.98));
}

////////////////////////
// Fragment
////////////////////////

void fragment() {
	// Recover UVs
	vec2 uv = UV;
	//vec2 uv2 = UV2;

	// Lookup offsets, ID and blend weight
	const vec3 offsets = vec3(0, 1, 2);
	vec2 index_id = floor(uv);
	vec2 weight = fract(uv);
	vec2 invert = 1.0 - weight;
	vec4 weights = vec4(
		invert.x * weight.y, // 0
		weight.x * weight.y, // 1
		weight.x * invert.y, // 2
		invert.x * invert.y  // 3
	);

	vec3 base_ddx = dFdxCoarse(v_vertex);
	vec3 base_ddy = dFdyCoarse(v_vertex);
	//vec4 base_derivatives = vec4(base_ddx.xz, base_ddy.xz);
	// Calculate the effective mipmap for regionspace, and if less than 0,
	// skip all extra lookups required for bilinear blend.
	float region_mip = log2(max(length(base_ddx.xz), length(base_ddy.xz)) * _vertex_density);
	bool bilerp = region_mip < 0.0;

	ivec3 index[4];
	// control map lookups, used for some normal lookups as well
	index[0] = get_index_coord(index_id + offsets.xy, FRAGMENT_PASS);
	index[1] = get_index_coord(index_id + offsets.yy, FRAGMENT_PASS);
	index[2] = get_index_coord(index_id + offsets.yx, FRAGMENT_PASS);
	index[3] = get_index_coord(index_id + offsets.xx, FRAGMENT_PASS);

	// Terrain normals
	vec3 index_normal[4];
	float h[4];
	// allows additional derivatives, eg world noise, brush previews etc
	float u = 0.0;
	float v = 0.0;

	// Re-use index[] for the first lookups, skipping some math. 3 lookups
	h[3] = texelFetch(_height_maps, index[3], 0).r; // 0 (0,0)
	h[2] = texelFetch(_height_maps, index[2], 0).r; // 1 (1,0)
	h[0] = texelFetch(_height_maps, index[0], 0).r; // 2 (0,1)
	index_normal[3] = normalize(vec3(h[3] - h[2] + u, _vertex_spacing, h[3] - h[0] + v));

	// Set flat world normal - overriden if bilerp is true
	vec3 w_normal = index_normal[3];

	// Branching smooth normals must be done seperatley for correct normals at all 4 index ids
	if (bilerp) {
		// 5 lookups
		// Fetch the additional required height values for smooth normals
		h[1] = texelFetch(_height_maps, index[1], 0).r; // 3 (1,1)
		float h_4 = texelFetch(_height_maps, get_index_coord(index_id + offsets.yz, FRAGMENT_PASS), 0).r; // 4 (1,2)
		float h_5 = texelFetch(_height_maps, get_index_coord(index_id + offsets.zy, FRAGMENT_PASS), 0).r; // 5 (2,1)
		float h_6 = texelFetch(_height_maps, get_index_coord(index_id + offsets.zx, FRAGMENT_PASS), 0).r; // 6 (2,0)
		float h_7 = texelFetch(_height_maps, get_index_coord(index_id + offsets.xz, FRAGMENT_PASS), 0).r; // 7 (0,2)

		// Calculate the normal for the remaining index ids.
		index_normal[0] = normalize(vec3(h[0] - h[1] + u, _vertex_spacing, h[0] - h_7 + v));
		index_normal[1] = normalize(vec3(h[1] - h_5 + u, _vertex_spacing, h[1] - h_4 + v));
		index_normal[2] = normalize(vec3(h[2] - h_6 + u, _vertex_spacing, h[2] - h[1] + v));

		// Set interpolated world normal
		w_normal =
			index_normal[0] * weights[0] +
			index_normal[1] * weights[1] +
			index_normal[2] * weights[2] +
			index_normal[3] * weights[3] ;
	}

	// Apply terrain normals
	vec3 w_tangent = normalize(cross(w_normal, vec3(0.0, 0.0, 1.0)));
	vec3 w_binormal = normalize(cross(w_normal, w_tangent));
	NORMAL = mat3(VIEW_MATRIX) * w_normal;
	TANGENT = mat3(VIEW_MATRIX) * w_tangent;
	BINORMAL = mat3(VIEW_MATRIX) * w_binormal;

	if (flat_terrain_normals) {
		NORMAL = normalize(cross(dFdyCoarse(VERTEX),dFdxCoarse(VERTEX)));
		TANGENT = normalize(cross(NORMAL, VIEW_MATRIX[2].xyz));
		BINORMAL = normalize(cross(NORMAL, TANGENT));
	}


    vec2 continuous_sample =
        (v_vertex.xz - MATERIAL_MASK_WORLD_ORIGIN) / MATERIAL_MASK_SAMPLE_SPACING;
    ivec2 nearest_sample = ivec2(floor(continuous_sample + vec2(0.5)));
    if (any(lessThan(nearest_sample,ivec2(0))) || any(greaterThanEqual(nearest_sample,MATERIAL_MASK_SIZE))) {
        discard;
    }
    vec4 exact_weights = texelFetch(material_mask, nearest_sample, 0);
    if (dot(exact_weights,vec4(1.0)) < .5/255.0) {
        // Exact existing playable footprint; no padded-image offsets.
        discard;
    }
    vec2 material_uv = (continuous_sample + vec2(.5)) / vec2(MATERIAL_MASK_SIZE);
    vec4 climate = max(texture(material_mask,material_uv),vec4(0.0));
    climate /= max(dot(climate,vec4(1.0)),.0001);
    vec4 context = texture(surface_context,material_uv);
    float broad = smoothstep(.2,.8,context.r);
    float patches = smoothstep(.24,.76,context.g);
    float slope = 1.0 - normalize(w_normal).y;
    float supplementary_rock = smoothstep(.015,.15,slope) * .20 * (1.0-climate.a);
    float rock = clamp(climate.a + supplementary_rock,0.0,1.0);
    vec3 ground = climate.rgb * (1.0-rock) / max(1.0-climate.a,.0001);
    float transition = ground.r * smoothstep(.01,.35,rock) * .36;
    ground.r -= transition;

    float sparse_fraction = .12 + .48*smoothstep(.18,.8,context.r*.58+context.g*.42);
    float soil_fraction = .025 + .12*patches;
    float dry_grass = .45 + .34*broad;
    float desert_sand = clamp(.08 + .88*smoothstep(.26,.73,context.r*.62+context.g*.38)
        - smoothstep(.005,.07,slope)*.26 - max(context.b-.5,0.0)*.45,.04,.94);
    float dry_rock = clamp(climate.b + .5*climate.g + .2*broad,0.0,1.0);

    float layer_weight[8];
    layer_weight[0] = ground.r*(1.0-sparse_fraction-soil_fraction);
    layer_weight[1] = ground.r*sparse_fraction + ground.g*(.08+.12*(1.0-broad));
    layer_weight[2] = ground.g*dry_grass;
    layer_weight[3] = ground.r*soil_fraction + ground.g*(.92-.12*(1.0-broad)-dry_grass) + ground.b*(1.0-desert_sand)*.58;
    layer_weight[4] = ground.b*desert_sand;
    layer_weight[5] = rock*(1.0-dry_rock*.8);
    layer_weight[6] = rock*dry_rock*.8 + ground.b*(1.0-desert_sand)*.42;
    layer_weight[7] = transition;

    vec2 metres = v_vertex.xz * AUTHORED_METRES_PER_UNIT;
    vec2 dx = dFdxCoarse(metres), dy = dFdyCoarse(metres);
    float pixel_metres = max(length(dx),length(dy));
    vec4 surface = vec4(0.0);
    vec3 mapped_normal = vec3(0.0);
    float total = 0.0;
    for (int layer=0;layer<8;layer++) {
        if (layer_weight[layer] > .018) {
            vec3 detail;
            vec4 sampled = sample_surface(layer,metres,dx,dy,context.g,pixel_metres,detail);
            surface += sampled * layer_weight[layer];
            mapped_normal += detail * layer_weight[layer];
            total += layer_weight[layer];
        }
    }
    surface /= max(total,.0001);
    mapped_normal = normalize(mapped_normal);
    // All shading support derives from actual relief. No displaced or exaggerated vertex.
    // Strong relief support belongs to rock, not narrow lowland drainage cuts.
    // This only limits presentation contrast; the source elevation is untouched.
    float relief_support = mix(.35,1.0,smoothstep(.015,.22,climate.a));
    float relief = mix(1.0, .38 + context.b*1.24, relief_influence*relief_support);
    float shelter = 1.0 - context.a * .26 * relief_support;
    float macro_value = .90 + .20*broad;
    ALBEDO = renderer_colour(clamp(surface.rgb * relief * shelter * macro_value,vec3(0.0),vec3(.9)));
    NORMAL_MAP = mapped_normal*.5+.5;
    NORMAL_MAP_DEPTH = 1.0;
    ROUGHNESS = surface.a;
    SPECULAR = .18;
}
