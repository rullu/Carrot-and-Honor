shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler3D density_volume : filter_linear, repeat_disable;
uniform float cloud_opacity = .78;
varying vec3 local_position;
varying vec3 local_view;

void vertex() {
    local_position = VERTEX;
    local_view = (inverse(MODEL_MATRIX)*vec4(INV_VIEW_MATRIX[2].xyz,0.0)).xyz;
    // At the closest orthographic view, a cloud volume can enter the screen
    // while its horizontal proxy crosses the near plane. Keep that proxy
    // drawable; the ray still samples the same world-space volume.
    POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0);
    POSITION.z = clamp(POSITION.z,-POSITION.w+.000001,POSITION.w-.000001);
}

void fragment() {
    // The proxy is a horizontal slice. Trace the actual volume along the view ray.
    vec3 ray = local_view / max(local_view.y,.0001);
    vec3 p = local_position + ray*.5;
    vec3 step_vector = ray/28.0;
    float opacity = 0.0;
    vec3 colour = vec3(0.0);
    for(int i=0; i<28; i++) {
        vec3 uvw=p+vec3(.5);
        if(all(greaterThan(uvw,vec3(0.0))) && all(lessThan(uvw,vec3(1.0)))) {
            vec3 sample_cloud=texture(density_volume,uvw).rgb;
            float a=1.0-exp(-sample_cloud.r*.40);
            float lighting=smoothstep(.12,.94,sample_cloud.g);
            vec3 lit=mix(vec3(.40,.535,.64),vec3(1.0,.982,.915),lighting);
            lit=mix(lit,vec3(.68,.75,.79),.12*(1.0-sample_cloud.b));
            colour+=(1.0-opacity)*a*lit;
            opacity+=(1.0-opacity)*a;
        }
        p-=step_vector;
    }
    ALBEDO=colour/max(opacity,.001);
    ALPHA=opacity*cloud_opacity;
}
