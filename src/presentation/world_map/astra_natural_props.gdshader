shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://src/presentation/world_map/astra_atmosphere.gdshaderinc"
uniform float wind = 1.0;
varying vec3 local_position;
varying vec3 world_position;
void vertex() {
    local_position=VERTEX;
    float bend=pow(clamp(VERTEX.y,0.0,1.0),2.0);
    VERTEX.x+=sin(TIME*.65+INSTANCE_CUSTOM.x*6.283+VERTEX.y*2.0)*.004*bend*wind;
    VERTEX.z+=sin(TIME*.51+INSTANCE_CUSTOM.x*9.21)*.002*bend*wind;
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    float grain=sin(local_position.x*127.0+local_position.z*213.0)*sin(local_position.y*181.0-local_position.x*91.0);
    ALBEDO=COLOR.rgb*(.97+grain*.035)*(1.0-astra_cloud_occlusion(world_position));
    ROUGHNESS=.92;
    SPECULAR=.12;
    AO=mix(.62,1.0,smoothstep(.05,.65,local_position.y));
    AO_LIGHT_AFFECT=.25;
}
