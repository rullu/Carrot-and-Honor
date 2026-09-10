shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
#include "res://src/presentation/world_map/astra_atmosphere.gdshaderinc"
uniform sampler2D shore_distance : filter_linear, repeat_disable;
uniform sampler2D water_features : filter_linear, repeat_disable;
uniform sampler2D water_optics : filter_linear, repeat_disable;
uniform sampler2D shore_finish : filter_linear_mipmap, repeat_disable;
uniform sampler2D river_motion : filter_linear, repeat_disable;
uniform sampler3D wave_spectrum : filter_linear, repeat_enable;
uniform sampler2D water_edge_style : filter_linear, repeat_disable;
uniform bool inland = false;
uniform float motion = 1.0;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 q=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(q),hash(q+vec2(1,0)),f.x),mix(hash(q+vec2(0,1)),hash(q+vec2(1)),f.x),f.y);
}
vec3 display_colour(vec3 c) {
    if(OUTPUT_IS_SRGB) { return mix(c*12.92,1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-.055,step(vec3(.0031308),c)); }
    return c;
}
vec2 pebble_bed(vec2 p) {
    vec2 cell=floor(p), f=fract(p);
    float closest=2.0, value=0.0;
    for(int y=-1;y<=1;y++) {
        for(int x=-1;x<=1;x++) {
            vec2 offset=vec2(float(x),float(y));
            vec2 centre=vec2(hash(cell+offset),hash(cell+offset+83.0));
            float d=length(offset+centre*.72+.14-f);
            if(d<closest) { closest=d; value=hash(cell+offset+17.0); }
        }
    }
    return vec2(closest,value);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_position.xz;
    vec2 uv=((p-vec2(-25000,-14062.5))/12.20703125+vec2(.5))/vec2(4096,2304);
    float distance=texture(shore_distance,uv).r;
    vec4 water=texture(water_features,uv);
    vec4 optics=texture(water_optics,uv);
    float stream_distance=(water.r-.5)*16.0;
    if(!inland && distance>0.0) { discard; }
    if(inland) {
        if(water.b>.1) { if(distance>0.0 && stream_distance<0.0) { discard; } }
        else if(stream_distance<0.0) { discard; }
    }
    float edge=max(-texture(water_edge_style,uv).r,0.0);
    float t=TIME*motion;
    float lake=inland ? water.b : 0.0;
    float river=(inland ? 1.0-water.b : 0.0)*smoothstep(-.5,4.0,distance);
    float ocean=1.0-max(lake,river);
    float pixel=max(length(dFdx(p)),length(dFdy(p)));
    float resolved=1.0-smoothstep(8.0,20.0,pixel);
    vec4 finish=texture(shore_finish,uv);
    vec2 flow=normalize(optics.gb*2.0-1.0+vec2(.0001));
    vec4 route=texture(river_motion,uv);
    float phase=atan(route.r*2.0-1.0,route.g*2.0-1.0);
    float across=(route.b-.5)*12.0;
    vec2 warp=vec2(noise(p/430.0),noise(p/390.0+83.0))*37.0;
    vec4 spectrum=texture(wave_spectrum,vec3((p+warp)/900.0,t/24.0));
    vec4 secondary=texture(wave_spectrum,vec3((p-warp)*1.731/900.0+.37,t/24.0+.43));
    vec2 gradient=((spectrum.rg-.5)*.9+(secondary.rg-.5)*.22)*mix(1.0,.23,lake);
    vec2 current_gradient=flow*cos(phase-t*1.10+sin(across*.8)*.7)*.12;
    current_gradient+=vec2(-flow.y,flow.x)*sin(across*2.8+phase-t*.53)*.05;
    gradient=mix(gradient,current_gradient,river*.93);
    gradient*=mix(.64,1.0,smoothstep(.2,3.0,edge));
    vec3 n=normalize(vec3(-gradient.x,1.0,-gradient.y));
    vec3 v=normalize(INV_VIEW_MATRIX[2].xyz);
    vec3 reflection=reflect(-v,n);
    float fresnel=.022+.62*pow(1.0-clamp(dot(n,v),0.0,1.0),4.0);
    vec3 sky=mix(vec3(.50,.60,.69),vec3(.12,.25,.42),smoothstep(.05,.86,reflection.y));
    vec2 sky_p=p*.25+reflection.xz/max(reflection.y,.10)*380.0-vec2(t*.7,t*.25);
    float reflected_cloud=smoothstep(.51,.72,noise(sky_p/265.0)*.7+noise(sky_p/83.0)*.3);
    sky=mix(sky,vec3(.75,.79,.77),reflected_cloud*.25);
    float shelf=exp(-edge/4.2)*(1.0-smoothstep(10.0,16.0,edge));
    float bed_depth=clamp(optics.r*1.5+edge*.22,0.0,1.0);
    shelf=mix(shelf,exp(-edge/1.1)*(.72+bed_depth*.28),river*.92);
    float bed=noise(p/38.0)*.42+noise(p/113.0)*.34+noise(p/13.0)*.24;
    vec3 deep=mix(vec3(.008,.045,.090),vec3(.027,.085,.085),river);
    deep=mix(deep,vec3(.025,.104,.128),lake*.45);
    vec3 shallow=mix(vec3(.055,.275,.235),vec3(.13,.205,.13),river);
    shallow=mix(shallow,vec3(.085,.19,.165),finish.r*.55);
    vec3 body=mix(deep,shallow*(.72+bed*.52),shelf);
    float gravel=smoothstep(.30,.75,finish.g)*shelf;
    if(gravel>.02) {
        vec2 stones=pebble_bed(p/5.4);
        float joint=smoothstep(.24,.47,stones.x);
        vec3 stone=mix(vec3(.075,.125,.105),vec3(.19,.23,.16),stones.y)*(1.0-joint*.44);
        body=mix(body,stone,gravel*.28*resolved);
    }
    float sun_diffuse=.84+dot(n,normalize(vec3(-.353,.788,-.505)))*.16;
    vec3 c=body*(1.0-fresnel)*sun_diffuse+sky*fresnel;
    vec3 half_sun=normalize(v+normalize(vec3(-.353,.788,-.505)));
    float sun=pow(max(dot(n,half_sun),0.0),220.0);
    c+=vec3(1.0,.91,.74)*sun*.085*mix(1.0,.40,river);
    float caustic=pow(1.0-abs(sin(p.x*.18+sin(p.y*.15+t*.38))*sin(p.y*.19+sin(p.x*.12-t*.42))),18.0);
    c+=vec3(.028,.04,.018)*caustic*shelf*resolved;
    // A broken family of moving, shoaling crests belongs only to exposed sea.
    float exposure=smoothstep(.48,.71,noise(p/420.0)+finish.a*.18);
    float surf_phase=edge*2.1+t*.88+noise(p/55.0)*3.6+noise(p/17.0)*1.4;
    float crest=pow(.5+.5*sin(surf_phase),22.0);
    float broken=smoothstep(.45,.66,noise(p/13.0+vec2(t*.13,0.0))*.65+noise(p/51.0)*.35);
    float surf=crest*broken*exp(-edge/3.3)*smoothstep(.08,.6,edge)*exposure*ocean;
    float wash=(1.0-smoothstep(.0,.48,edge))*smoothstep(.44,.67,noise(p/16.0-t*.28))*exposure*ocean*.34;
    float streak=pow(max(sin(phase-t*1.10+across*.6),0.0),8.0)*pow(.5+.5*sin(across*3.0+phase*.7),4.0);
    c+=vec3(.055,.075,.075)*streak*river*resolved;
    c=mix(c,vec3(.68,.76,.71),clamp((surf*.72+wash)*resolved,0.0,.85));
    c*=1.0-astra_cloud_occlusion(world_position)*.72;
    ALBEDO=display_colour(c);
}
