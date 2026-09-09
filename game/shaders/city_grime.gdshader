shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.23, 0.10, 0.035, 1.0);
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = length(p) + (noise(world_pos.xz * 9.0) - 0.5) * 0.18;
	if (edge > 0.95) { discard; }
	float variation = noise(world_pos.xz * 5.0);
	ALBEDO = base_color.rgb * (0.8 + variation * 0.45);
	ROUGHNESS = 0.19 + variation * 0.16;
	SPECULAR = 0.7;
	NORMAL_MAP = vec3(0.5 + sin(world_pos.x * 24.0) * 0.02, 0.5 + cos(world_pos.z * 21.0) * 0.02, 1.0);
}
