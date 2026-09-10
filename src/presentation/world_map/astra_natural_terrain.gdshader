// Copyright Â© 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.
// This shader is the minimum needed to allow the terrain to function, without any texturing.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,skip_vertex_transform;

#include "res://src/presentation/world_map/astra_atmosphere.gdshaderinc"

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
uniform highp sampler2D shore_distance : filter_linear, repeat_disable;
uniform highp sampler2D ecology : filter_linear_mipmap_anisotropic, repeat_disable;
uniform highp sampler2D water_features : filter_linear, repeat_disable;
uniform sampler2D landscape_character : filter_linear_mipmap, repeat_disable;
uniform sampler2D shore_finish : filter_linear_mipmap, repeat_disable;
uniform sampler2D water_edge_style : filter_linear, repeat_disable;
uniform bool flat_terrain_normals = false;
uniform highp sampler2D material_mask : filter_linear_mipmap_anisotropic, repeat_disable;
uniform highp sampler2D surface_context : filter_linear_mipmap_anisotropic, repeat_disable;
uniform highp sampler2DArray art_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform highp sampler2DArray art_normal_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float texture_influence : hint_range(0.0, 1.0) = 0.94;
uniform float relief_influence : hint_range(0.0, 1.0) = 0.85;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.58;

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
    vec3(.30,.405,.215), vec3(.385,.415,.275),
    vec3(.60,.52,.36), vec3(.46,.37,.245),
    vec3(.72,.625,.435), vec3(.385,.405,.40),
    vec3(.56,.465,.34), vec3(.445,.47,.32)
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

// Stochastic triangular tiling: every triangle blends three independently
// rotated source patches. Derivatives never cross a random coordinate jump.
vec2 hash_position(vec2 p) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}
float natural_noise(vec2 p) {
    vec2 q=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash_position(q).x,hash_position(q+vec2(1,0)).x,f.x),
        mix(hash_position(q+vec2(0,1)).x,hash_position(q+vec2(1)).x,f.x),f.y);
}
vec4 sample_surface(int layer, vec2 metres, vec2 dx, vec2 dy, float variety,
        float pixel_metres, out vec3 detail_normal) {
    float scale=MESO_METRES[layer];
    vec2 pos=metres/scale;
    vec2 skew=vec2(pos.x-pos.y*.57735027,pos.y*1.15470054);
    vec2 cell=floor(skew), f=fract(skew);
    vec2 ids[3]; vec3 weights;
    if (f.x+f.y<1.0) {
        ids[0]=cell; ids[1]=cell+vec2(1,0); ids[2]=cell+vec2(0,1);
        weights=vec3(1.0-f.x-f.y,f.x,f.y);
    } else {
        ids[0]=cell+vec2(1); ids[1]=cell+vec2(0,1); ids[2]=cell+vec2(1,0);
        weights=vec3(f.x+f.y-1.0,1.0-f.x,1.0-f.y);
    }
    weights=pow(weights,vec3(3.0)); weights/=dot(weights,vec3(1));
    vec3 colour=vec3(0), normal_accum=vec3(0);
    float roughness=0.0;
    float normal_fade=1.0-smoothstep(90.0,260.0,pixel_metres);
    for(int i=0;i<3;i++) {
        vec2 hash=hash_position(ids[i]+vec2(float(layer)*13.7));
        float angle=hash.x*6.2831853;
        vec2 uv=rotate_uv(pos,angle)+hash*29.0;
        vec2 ddx=rotate_uv(dx/scale,angle), ddy=rotate_uv(dy/scale,angle);
        vec3 c=sampled_linear(textureGrad(art_albedo,vec3(uv,float(layer)),ddx,ddy).rgb);
        colour+=grade_colour(c,layer)*weights[i];
        vec4 nr=textureGrad(art_normal_roughness,vec3(uv,float(layer)),ddx,ddy);
        vec3 n=nr.rgb*2.0-1.0;
        n.xy=rotate_uv(n.xy*vec2(1,-1),-angle)*vec2(1,-1);
        normal_accum+=n*weights[i]; roughness+=nr.a*weights[i];
    }
    normal_accum.xy*=normal_strength*normal_fade;
    detail_normal=normalize(normal_accum);
    // Close inspections receive another resolved photographic scale, not a blur.
    float micro=180.0;
    float close=1.0-smoothstep(4.0,25.0,pixel_metres);
    if(close>.01) {
        vec2 uv=rotate_uv(metres/micro,.72+float(layer));
        vec3 c=sampled_linear(textureGrad(art_albedo,vec3(uv,float(layer)),
            rotate_uv(dx/micro,.72+float(layer)),rotate_uv(dy/micro,.72+float(layer))).rgb);
        colour=mix(colour,grade_colour(c,layer),close*.35);
    }
    return vec4(colour,clamp(mix(.9,roughness,.4),.7,.98));
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
    vec2 material_uv = (continuous_sample + vec2(.5)) / vec2(MATERIAL_MASK_SIZE);
    float shore = texture(shore_distance,material_uv).r;
    if (shore < 0.0) { discard; }
    vec4 habitat = texture(ecology,material_uv);
    vec4 character = texture(landscape_character,material_uv);
    vec4 hydro = texture(water_features,material_uv);
    // Land and inland water share one reconstructed coverage boundary. The
    // coarse heightfield must not cut triangular teeth into the water footprint.
    // This is a surface cutout only; original heights and collision data remain.
    if (hydro.r >= .5 && hydro.g > .01) { discard; }
    vec4 climate = max(texture(material_mask,material_uv),vec4(0.0));
    climate /= max(dot(climate,vec4(1.0)),.0001);
    vec4 context = texture(surface_context,material_uv);
    float broad = smoothstep(.2,.8,context.r);
    float patches = smoothstep(.24,.76,context.g);
    float slope = 1.0 - normalize(w_normal).y;
    float supplementary_rock = smoothstep(.015,.15,slope) * .20 * (1.0-climate.a);
    float rock = clamp(climate.a + supplementary_rock,0.0,1.0);
    // Presentation relief strengthens source slopes under the fixed sun.
    // Terrain positions and the Terrain3D vertex kernel remain unchanged.
    float mountain_mass=smoothstep(48.0,132.0,v_vertex.y)*smoothstep(.18,.65,rock);
    vec3 mass_normal=normalize(w_normal*vec3(1.0+mountain_mass*.75,1.0,1.0+mountain_mass*.75));
    NORMAL=normalize(mat3(VIEW_MATRIX)*mass_normal);
    TANGENT=normalize(mat3(VIEW_MATRIX)*normalize(cross(mass_normal,vec3(0,0,1))));
    BINORMAL=normalize(cross(NORMAL,TANGENT));
    vec3 sun_direction=normalize(vec3(-.353,.788,-.505));
    float mass_light=clamp(dot(mass_normal,sun_direction)/max(dot(normalize(w_normal),sun_direction),.20),.72,1.18);
    vec3 ground = climate.rgb * (1.0-rock) / max(1.0-climate.a,.0001);
    float transition = ground.r * (.07 + smoothstep(.01,.35,rock) * .27);
    ground.r -= transition;

    float ground_pixel_metres=max(length(dFdxCoarse(v_vertex.xz)),length(dFdyCoarse(v_vertex.xz)))*10.0;
    float resolved_patches=1.0-smoothstep(100.0,260.0,ground_pixel_metres);
    float sparse_fraction = mix(.30,.08 + .30*smoothstep(.36,.68,context.g),resolved_patches);
    float soil_fraction = mix(.075,.025 + .08*smoothstep(.56,.76,context.g),resolved_patches);
    soil_fraction = mix(soil_fraction,.31,habitat.g*.72);
    float dry_grass = .55 + .28*broad;
    float desert_sand = clamp(.38 + .65*smoothstep(.26,.73,context.r*.62+context.g*.38)
        - smoothstep(.005,.07,slope)*.26 - max(context.b-.5,0.0)*.45 - character.b*.34,.04,.94);
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
    float arid_gravel=character.b*ground.b*smoothstep(.35,.67,context.g)*.42;
    layer_weight[6]+=arid_gravel;
    layer_weight[4]=max(layer_weight[4]-arid_gravel,0.0);

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
    float macro_value = .97 + .06*broad;
    vec2 p = v_vertex.xz;
    vec2 warp=vec2(natural_noise(p/311.0),natural_noise(p/271.0+73.0))*83.0;
    float grain=natural_noise((p+warp)/35.0)*.46 + natural_noise((p-warp)/91.0)*.34 + habitat.a*.20;
    float grain_fade=1.0-smoothstep(120.0,500.0,pixel_metres);
    float surface_grain=1.0+(grain-.5)*.22*grain_fade*(1.0-rock*.65);
    float micro=(natural_noise(p/3.7)*.55+natural_noise(p/8.3)*.45-.5);
    surface_grain*=1.0+micro*.13*(1.0-smoothstep(40.0,95.0,pixel_metres));
    vec3 final_colour=surface.rgb*relief*shelter*macro_value*surface_grain;
    float lower_flank=1.0-smoothstep(.46,.65,context.b);
    final_colour*=1.0-mountain_mass*(.08+lower_flank*.18);
    final_colour*=mix(1.0,mass_light,mountain_mass*.30);
    // Cold ground is heather, lichen and blue-grey scree. Snow is restricted to summits.
    final_colour=mix(final_colour,final_colour*vec3(.86,.97,1.13),habitat.r*.72);
    vec3 heath=linear_colour(mix(vec3(.38,.405,.34),vec3(.43,.43,.36),mix(.5,patches,resolved_patches)));
    final_colour=mix(final_colour,heath*(.85+grain*.30)*relief,habitat.r*.56*(1.0-rock));
    float snow=habitat.r*smoothstep(148.0,211.0,v_vertex.y)*(1.0-smoothstep(.04,.18,slope));
    final_colour=mix(final_colour,linear_colour(vec3(.71,.755,.745)),snow*.62);
    final_colour=mix(final_colour,final_colour*vec3(.75,.82,.64),habitat.g*.65);
    final_colour=mix(final_colour,linear_colour(vec3(.37,.43,.24))*relief,habitat.g*ground.b*.48);
    final_colour=mix(final_colour,final_colour*vec3(1.11,1.04,.87),character.b*(1.0-rock)*.30);
    final_colour=mix(final_colour,linear_colour(vec3(.52,.46,.34))*(.80+grain*.40)*relief,character.b*ground.b*.40);
    // Broken beach/pebble transitions follow distance, climate and actual steepness.
    float sandy=1.0-smoothstep(.35,.60,character.a);
    sandy*=1.0-smoothstep(.12,.45,rock);
    sandy*=1.0-habitat.r*.70;
    vec4 finish=texture(shore_finish,material_uv);
    float edge_style=texture(water_edge_style,material_uv).r;
    float interruption=max(finish.r*.88,finish.a*.94);
    sandy*=1.0-interruption;
    sandy*=1.0-finish.g*.42;
    float beach_width=mix(.65,4.6,sandy)*(1.0-smoothstep(.02,.08,slope)*.70)*(.65+grain*.75);
    beach_width*=1.0-interruption*.38;
    float beach=1.0-smoothstep(.05,max(.40,beach_width),max(edge_style,0.0));
    beach*=1.0-smoothstep(2.0,7.0,shore);
    vec3 shore_colour=linear_colour(mix(vec3(.44,.445,.385),vec3(.63,.565,.41),sandy));
    shore_colour=mix(shore_colour,linear_colour(vec3(.355,.385,.29)),finish.r*.75);
    shore_colour=mix(shore_colour,linear_colour(mix(vec3(.435,.445,.405),vec3(.54,.475,.35),ground.g+ground.b)),finish.g*.65);
    shore_colour=mix(shore_colour,shore_colour*vec3(.87,.96,1.08),habitat.r*.55);
    float shore_grain=natural_noise(p/4.0)*.50+natural_noise(p/11.0)*.50;
    float bank_breakup=1.0-smoothstep(.43,.70,natural_noise(p/93.0))*finish.r*.52;
    final_colour=mix(final_colour,shore_colour*(.76+.43*shore_grain),beach*.78*bank_breakup);
    float wet_edge=1.0-smoothstep(.05,1.8+grain*1.1,shore);
    final_colour*=1.0-wet_edge*.30;
    final_colour*=1.0-habitat.b*.06;
    float stream_distance=(hydro.r-.5)*16.0;
    float river_bank=(1.0-smoothstep(.0,1.8+grain*2.5+finish.r*1.8,max(edge_style,0.0)))*smoothstep(-.7,.0,edge_style);
    river_bank*=1.0-smoothstep(3.0,6.0,max(-stream_distance,0.0));
    vec3 bank_colour=mix(vec3(.24,.30,.195),vec3(.46,.40,.275),climate.g+climate.b);
    final_colour=mix(final_colour,linear_colour(bank_colour)*(.78+shore_grain*.42),river_bank*.80);
    float river_sand=exp(-max(-stream_distance,0.0)/.9)*smoothstep(.46,.69,grain)*river_bank;
    final_colour=mix(final_colour,linear_colour(vec3(.52,.49,.35))*(.87+shore_grain*.22),river_sand*.72);
    float gravel_margin=max(beach,river_bank)*finish.g;
    float pebble=smoothstep(.48,.69,natural_noise(p/3.9)*.62+natural_noise(p/8.7)*.38);
    vec3 gravel_colour=linear_colour(mix(vec3(.36,.39,.30),vec3(.50,.445,.315),ground.g+ground.b));
    final_colour=mix(final_colour,gravel_colour*(.75+pebble*.46),gravel_margin*.44);
    vec3 riparian=linear_colour(mix(vec3(.29,.37,.205),vec3(.39,.42,.22),ground.b));
    final_colour=mix(final_colour,riparian*(.84+grain*.32)*relief,finish.b*.84);
    // Arid flats get restrained, irregular wind-shaped sand texture, not a global stripe.
    float dune_zone=ground.b*desert_sand*(1.0-smoothstep(.002,.014,slope));
    float phase=(p.x*.09+p.y*.039)+natural_noise(p/91.0)*8.0+natural_noise(p/29.0)*1.7;
    float dunes=sin(phase)*.5+.5;
    final_colour*=1.0+(dunes-.5)*dune_zone*.095*grain_fade;
    final_colour*=1.0-astra_cloud_occlusion(v_vertex);
    ALBEDO = renderer_colour(clamp(final_colour,vec3(0.0),vec3(.9)));
    NORMAL_MAP = mapped_normal*.5+.5;
    NORMAL_MAP_DEPTH = mix(1.0,.15,mountain_mass);
    ROUGHNESS = surface.a;
    SPECULAR = .18;
}
