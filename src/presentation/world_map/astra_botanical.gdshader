shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;
#include "res://src/presentation/world_map/astra_atmosphere.gdshaderinc"
uniform sampler2D botanical_colour : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_colour : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool combined = false;
uniform vec3 bark_tint : source_color = vec3(.90,.84,.73);
uniform vec3 tint : source_color = vec3(1.0);
uniform bool foliage = false;
uniform bool leaf_canopy = false;
uniform bool pale_bark = false;
uniform bool warm_stone = false;
uniform float wind = 1.0;
varying vec3 local_position;
varying vec3 world_position;
varying float leaf_part;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 q=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(q),hash(q+vec2(1,0)),f.x),mix(hash(q+vec2(0,1)),hash(q+vec2(1)),f.x),f.y);
}
void vertex() {
    local_position=VERTEX;
    leaf_part=COLOR.a;
    float bend=pow(clamp(VERTEX.y,0.0,1.0),2.0);
    VERTEX.x+=sin(TIME*.70+INSTANCE_CUSTOM.x*6.283+VERTEX.y*3.0)*.008*bend*wind;
    VERTEX.z+=sin(TIME*.49+INSTANCE_CUSTOM.x*9.21)*.004*bend*wind;
    world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
    if(foliage && (!combined || leaf_part>.5)) {
        // Crown normals face outward/up, keeping leaf cards a rounded canopy.
        vec3 crown=normalize(vec3(VERTEX.x, max(.14,VERTEX.y-.30)*.80,VERTEX.z));
        NORMAL=normalize(mix(NORMAL,crown,.78));
    }
}
void fragment() {
    bool is_leaf=foliage && (!combined || leaf_part>.5);
    vec4 texel=texture(botanical_colour,UV);
    if(combined && !is_leaf) { texel=texture(bark_colour,UV); }
    ALPHA=texel.a;
    ALPHA_SCISSOR_THRESHOLD=.28;
    ALPHA_ANTIALIASING_EDGE=.26;
    ALPHA_TEXTURE_COORDINATE=UV*vec2(textureSize(botanical_colour,0));
    float ao=clamp(dot(COLOR.rgb,vec3(.3333)),.74,1.16);
    vec3 c=texel.rgb*((combined && !is_leaf)?bark_tint:tint)*ao;
    float luminance=dot(texel.rgb,vec3(.24,.62,.14));
    if(leaf_canopy && is_leaf) { c=tint*pow(clamp(luminance/.36,.65,1.5),.34)*ao; }
    if(pale_bark && !is_leaf) { c=mix(c,vec3(.61,.60,.51)*clamp(luminance*2.0,.45,1.0),.72); }
    if(warm_stone) { c=mix(c,vec3(luminance)*vec3(1.05,.92,.73),.70); }
    float t=TIME;
    vec2 p=world_position.xz-vec2(t*14.0,t*5.0);
    float cloud=noise(p/850.0)*.7+noise(p/390.0)*.3;
    c*=1.0-astra_cloud_occlusion(world_position);
    ALBEDO=c;
    ROUGHNESS=.87;
    SPECULAR=.10;
    AO=mix(.70,1.0,smoothstep(.08,.70,local_position.y));
    AO_LIGHT_AFFECT=.25;
    if(is_leaf) { BACKLIGHT=c*.36; }
}
