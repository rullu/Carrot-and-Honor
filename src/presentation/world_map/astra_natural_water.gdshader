shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform sampler2D shore_distance : filter_linear, repeat_disable;
uniform sampler2D water_features : filter_linear, repeat_disable;
uniform sampler2D water_optics : filter_linear, repeat_disable;
uniform sampler2D ecology : filter_linear_mipmap, repeat_disable;
uniform sampler2D shore_finish : filter_linear_mipmap, repeat_disable;
uniform sampler2D river_motion : filter_linear, repeat_disable;
uniform bool inland = false;
uniform float motion = 1.0;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 q=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(q),hash(q+vec2(1,0)),f.x),mix(hash(q+vec2(0,1)),hash(q+vec2(1)),f.x),f.y);
}
float swell(vec2 p, float t, float calm) {
    vec2 drift=p+vec2(t*2.2,t*.9);
    float a=sin(dot(drift,vec2(.046,.022))+noise(drift/75.0)*3.0);
    float b=sin(dot(drift,vec2(-.024,.093))+noise(drift/39.0)*2.5);
    float c=sin(dot(p,vec2(.161,.071))-t*.95+noise(p/25.0)*2.0);
    return (a*.52+b*.32+c*.16)*calm;
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; }
void fragment() {
    vec2 p=world_position.xz;
    vec2 uv=((p-vec2(-25000,-14062.5))/12.20703125+vec2(.5))/vec2(4096,2304);
    float distance=texture(shore_distance,uv).r;
    vec4 water=texture(water_features,uv);
    vec4 optics=texture(water_optics,uv);
    float stream_distance=(water.r-.5)*16.0;
    if(!inland && distance>0.0) { discard; }
    if(inland) {
        if(water.b>.1) {
            if(distance>0.0 && stream_distance<0.0) { discard; }
        } else if(stream_distance<0.0) { discard; }
    }
    float edge_distance=max((water.a-.5)*32.0,0.0);
    float t=TIME*motion;
    float lake=inland ? water.b : 0.0;
    float river=inland ? 1.0-water.b : 0.0;
    river*=smoothstep(-.5,4.0,distance);
    float calm=mix(1.0,.42,lake)*mix(1.0,.62,river);
    vec2 flow=normalize(optics.gb*2.0-1.0+vec2(.0001));
    vec2 surface_p=p-flow*t*4.5*river;
    float pixels=max(length(dFdx(p)),length(dFdy(p)));
    float resolved=1.0-smoothstep(5.0,18.0,pixels);
    float h=swell(surface_p,t,calm);
    float response=mix(1.1,2.4,river);
    float nx=(swell(surface_p+vec2(1.0,0),t,calm)-h)*response*resolved;
    float nz=(swell(surface_p+vec2(0,1.0),t,calm)-h)*response*resolved;
    vec3 n=normalize(vec3(-nx,1.0,-nz));
    vec4 route=texture(river_motion,uv);
    float route_phase=atan(route.r*2.0-1.0,route.g*2.0-1.0);
    float across=(route.b-.5)*12.0;
    if(river>.05) {
        float along_ripple=cos(route_phase-t*.75+sin(across*.9)*.28)*.045*resolved;
        float cross_ripple=sin(across*2.5-route_phase*.4+t*.30)*.012*resolved;
        vec2 gradient=flow*along_ripple+vec2(-flow.y,flow.x)*cross_ripple;
        n=normalize(mix(n,normalize(vec3(-gradient.x,1.0,-gradient.y)),river*.78));
    }
    NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
    // One absorption scale across connected water prevents a visible material
    // boundary where a river mesh meets the ocean or a lake.
    float shelf=exp(-edge_distance/6.5)*(1.0-smoothstep(11.0,16.0,edge_distance));
    float channel_depth=clamp(optics.r*1.5+edge_distance*.24,0.0,1.0);
    shelf=mix(shelf,1.0-channel_depth,river*.84);
    shelf*=mix(1.0,.66+noise(p/57.0)*.48,river);
    float bed=noise(p/17.0)*.50+noise(p/47.0)*.30+noise(p/151.0)*.20;
    vec3 deep=mix(vec3(.055,.225,.245),vec3(.11,.26,.24),river);
    vec3 shallow=mix(vec3(.25,.445,.36),vec3(.25,.36,.275),river);
    vec3 c=mix(deep,shallow*(.83+bed*.30),shelf);
    vec4 finish=texture(shore_finish,uv);
    c=mix(c,c*vec3(.83,.91,.80),shelf*finish.r*.36);
    c=mix(c,c*vec3(1.05,1.035,.99),shelf*finish.g*.32);
    if(river>.05) {
        float phase=route_phase;
        float lane=pow(.5+.5*sin(across*3.4+sin(phase-t*.18)*.32),5.0);
        float streak=pow(max(sin(phase-t*.75+across*.3),0.0),5.0)*(.35+lane*.65);
        float current_fade=1.0-smoothstep(7.0,14.0,pixels);
        c+=vec3(.024,.038,.030)*(streak-.08)*river*current_fade;
    }
    float cold=texture(ecology,uv).r;
    c*=mix(vec3(1),vec3(.86,.98,1.12),cold*.6);
    float caustic=pow(1.0-abs(sin(p.x*.20+sin(p.y*.13+t*.20))*sin(p.y*.18+sin(p.x*.11-t*.25))),14.0);
    c+=vec3(.018,.023,.015)*caustic*shelf*resolved;
    float wave_phase=edge_distance*3.8-t*.62+noise(p/58.0)*2.4;
    float wash=pow(.5+.5*sin(wave_phase),14.0)*exp(-edge_distance/1.9);
    wash*=smoothstep(.44,.72,noise(p/31.0))*resolved*(1.0-river*.80)*(1.0-lake*.85);
    c=mix(c,vec3(.69,.77,.69),wash*.24);
    float cloud=noise((p-vec2(t*14.0,t*5.0))/850.0)*.7+noise((p-vec2(t*14.0,t*5.0))/390.0)*.3;
    c*=1.0-smoothstep(.44,.72,cloud)*.07*mix(.15,1.0,resolved);
    ALBEDO=c;
    ROUGHNESS=mix(.29,.24,river)+wash*.18;
    SPECULAR=.60;
    METALLIC=.02;
}
