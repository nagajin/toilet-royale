shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform float grain = 0.12;
uniform float surface_roughness = 0.85;
uniform int pattern = 0; // 0 plaster, 1 asphalt, 2 paving, 3 brick, 4 fabric
varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 local_pos;
varying vec3 local_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
		mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	local_pos = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec3 pos = pattern == 4 ? local_pos : world_pos;
	vec3 n = abs(pattern == 4 ? local_normal : world_normal);
	vec2 p = n.y > 0.6 ? pos.xz : (n.x > n.z ? pos.zy : pos.xy);
	float fine = noise(p * 95.0);
	// Fade subpixel grains to avoid crawling during movement.
	float fade = 1.0 - smoothstep(0.008, 0.045, length(fwidth(p)));
	fine = mix(0.5, fine, fade);
	float mottling = noise(p * 2.5) * 0.55 + noise(p * 0.35) * 0.45;
	vec3 color = base_color.rgb * (1.0 + (fine - 0.5) * grain + (mottling - 0.5) * grain * 1.5);
	float joint = 0.0;
	if (pattern == 1) {
		color *= 0.87 + noise(p * 0.18) * 0.22;
		color += vec3(smoothstep(0.75, 0.86, fine) * 0.035 * fade);
	} else if (pattern == 2 || pattern == 3) {
		vec2 grid = p / (pattern == 3 ? vec2(0.52, 0.22) : vec2(0.7, 0.7));
		grid.x += mod(floor(grid.y), 2.0) * 0.5;
		vec2 edge = abs(fract(grid) - 0.5);
		vec2 aa = max(fwidth(grid), vec2(0.004));
		vec2 seams = smoothstep(vec2(0.48) - aa, vec2(0.49) + aa, edge);
		joint = max(seams.x, seams.y);
		color *= 0.92 + hash(floor(grid)) * 0.16;
		color = mix(color, base_color.rgb * (pattern == 3 ? 0.65 : 0.72), joint * 0.75);
	} else if (pattern == 4) {
		color *= 0.97 + 0.06 * sin(p.x * 380.0) * sin(p.y * 380.0) * fade;
	}
	ALBEDO = color;
	ROUGHNESS = clamp(surface_roughness + (fine - 0.5) * 0.12 + joint * 0.08, 0.04, 1.0);
	SPECULAR = 0.35;
}
