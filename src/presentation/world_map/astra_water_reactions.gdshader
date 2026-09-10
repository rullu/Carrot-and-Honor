shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform sampler2D shore_distance : filter_linear, repeat_disable;
uniform sampler2D water_features : filter_linear, repeat_disable;
uniform vec3 reaction_data = vec3(.9,0,0);
uniform bool debug_footprint = false;
varying vec3 world_position;
varying vec3 reaction;
void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    reaction=reaction_data;
}
void fragment() {
    vec2 uv=((world_position.xz-vec2(-25000,-14062.5))/12.20703125+vec2(.5))/vec2(4096,2304);
    vec4 water=texture(water_features,uv);
    float shore=texture(shore_distance,uv).r;
    if(shore>0.0 && (water.r<.5 || water.g<.01)) { discard; }
    vec2 q=UV-vec2(.5);
    float t=TIME*.72+reaction.g*6.28;
    float tail=smoothstep(-.035,.06,q.y)*(1.0-smoothstep(.08,.46,q.y));
    float spread=.22+max(q.y,0.0)*.40;
    float ribbon_distance=(abs(q.x+sin(q.y*26.0-t)*.026)-spread)/.055;
    float ribbons=exp(-ribbon_distance*ribbon_distance);
    float bow_distance=(length(q*vec2(1.0,1.8))-.28)/.048;
    float bow=exp(-bow_distance*bow_distance)*(1.0-smoothstep(-.01,.09,q.y));
    float breakup=smoothstep(-.48,.65,sin(q.y*85.0-t*4.0+sin(q.x*61.0))*sin(q.x*47.0+q.y*19.0+t));
    vec2 eddy=q-vec2(.08,.19);
    float eddy_radius=length(eddy*vec2(1.1,.9));
    float curl=sin(eddy_radius*68.0-atan(eddy.y,eddy.x)*2.0-t*3.1);
    float boiling=exp(-eddy_radius*eddy_radius/.040)*smoothstep(-.20,.80,curl)*tail;
    float foam=(ribbons*tail*.86+bow*.86+boiling*.48)*(.40+breakup*.60);
    ALBEDO=vec3(.91,.94,.89);
    ALPHA=clamp(foam*reaction.r*1.12,0.0,.86);
    if(debug_footprint) { ALBEDO=vec3(1,0,0); ALPHA=.8; }
}
