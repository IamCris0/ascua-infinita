shader_type canvas_item;
// Per-actor colour treatment: biome hue variants, hit flash and fades.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float hue_shift = 0.0;
uniform float saturation = 1.0;
uniform float brightness = 1.0;

vec3 hue_rotate(vec3 c, float turns) {
	float angle = turns * 6.2831853;
	vec3 k = vec3(0.57735);
	float ca = cos(angle);
	return c * ca + cross(k, c) * sin(angle) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	// Godot 4 already multiplies the sampled texture into fragment COLOR.
	vec4 c = COLOR;
	if (abs(hue_shift) > 0.001) {
		c.rgb = clamp(hue_rotate(c.rgb, hue_shift), 0.0, 1.0);
	}
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(g), c.rgb, saturation) * brightness;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
