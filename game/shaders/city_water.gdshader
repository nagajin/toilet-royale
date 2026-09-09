shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float flush = 0.0;
varying vec3 local_pos;
void vertex() {
	local_pos = VERTEX;
}
void fragment() {
	vec2 p = local_pos.xz;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float ripple = sin(radius * 24.0 - TIME * 3.0) * 0.012;
	float spiral = sin(angle * 4.0 + radius * 16.0 - TIME * (2.0 + flush * 12.0));
	float foam = smoothstep(0.82, 1.0, spiral) * flush * smoothstep(0.2, 0.6, radius);
	ALBEDO = mix(vec3(0.025, 0.22, 0.27), vec3(0.17, 0.52, 0.55), radius * 0.55);
	ALBEDO = mix(ALBEDO, vec3(0.83, 0.94, 0.91), foam * 0.8);
	ROUGHNESS = mix(0.12, 0.32, foam);
	METALLIC = 0.15;
	SPECULAR = 0.8;
	NORMAL_MAP = vec3(0.5 + cos(angle) * ripple + sin(p.y * 12.0 + TIME * 2.0) * 0.035,
		0.5 + sin(angle) * ripple + cos(p.x * 13.0 + TIME * 2.1) * 0.035, 1.0);
}
