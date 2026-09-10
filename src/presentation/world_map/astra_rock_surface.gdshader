shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://src/presentation/world_map/astra_atmosphere.gdshaderinc"
uniform sampler2D stone_colour : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform bool warm_stone = false;
varying vec3 local_position;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    local_position=VERTEX;
    world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    float face=clamp(world_normal.y,0.0,1.0);
    vec3 texel=texture(stone_colour,UV).rgb;
    vec3 colour=texel*tint*clamp(COLOR.rgb,vec3(.74),vec3(1.16))*(.89+face*.15);
    if(warm_stone) {
        float luminance=dot(texel,vec3(.24,.62,.14));
        colour=mix(colour,vec3(luminance)*vec3(1.05,.92,.73)*(.89+face*.15),.70);
    }
    float foot=1.0-smoothstep(-.06,.30,local_position.y);
    colour*=1.0-foot*.16;
    ALBEDO=colour*(1.0-astra_cloud_occlusion(world_position));
    ROUGHNESS=.84-foot*.12;
    SPECULAR=.22;
    AO=mix(.74,1.0,smoothstep(-.08,.40,local_position.y));
}
