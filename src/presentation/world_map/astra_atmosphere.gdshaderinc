// Shared sunlight projection of the same sparse volumes rendered above the map.
global uniform sampler2D astra_cloud_shadow : filter_linear_mipmap, repeat_enable;
global uniform float astra_atmosphere_time;

float astra_cloud_occlusion(vec3 world) {
    vec2 projected = world.xz + vec2(-.353,-.505)/.788*(325.0-world.y);
    vec2 drift = vec2(3.0,1.2)*astra_atmosphere_time;
    return texture(astra_cloud_shadow,fract((projected-drift)/vec2(7500.0,6000.0))).r*.42;
}
