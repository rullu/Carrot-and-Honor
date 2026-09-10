shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
#include "res://src/presentation/world_map/astra_atmosphere.gdshaderinc"
uniform sampler2D climate : filter_linear, repeat_disable;
uniform sampler2D shore_finish : filter_linear_mipmap, repeat_disable;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; }
void fragment() {
    vec2 uv=((world_position.xz-vec2(-25000,-14062.5))/12.20703125+vec2(.5))/vec2(4096,2304);
    vec4 biome=texture(climate,uv);
    vec3 colour=mix(vec3(.30,.34,.245),vec3(.51,.46,.335),clamp(biome.g+biome.b,0.0,1.0));
    vec4 finish=texture(shore_finish,uv);
    colour=mix(colour,vec3(.27,.31,.23),finish.r*.55);
    colour=mix(colour,vec3(.38,.395,.34),max(finish.g,finish.a)*.62);
    float grain=fract(sin(dot(floor(world_position.xz*1.1),vec2(12.9898,78.233)))*43758.5453);
    // These thin closure faces can fold above/below the sampled waterline.
    // A ground-facing normal cage prevents alternating dark triangle edges.
    vec3 face=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
    if(face.y<0.0) { face=-face; }
    face=normalize(vec3(face.x*.35,max(face.y,.85),face.z*.35));
    NORMAL=normalize((VIEW_MATRIX*vec4(face,0.0)).xyz);
    ALBEDO=colour*(.82+grain*.22)*(1.0-astra_cloud_occlusion(world_position));
    ROUGHNESS=.82;
}
