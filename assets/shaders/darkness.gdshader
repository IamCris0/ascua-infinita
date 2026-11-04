shader_type canvas_item;
// The dark of the eclipse, multiplied over the stage. Each light adds its
// colour with a smooth falloff; where nothing shines only the ambient is left.
// Positions and radii are in stage pixels (the background's 1024 x 800 space).
render_mode blend_mul;

const int MAX_LIGHTS = 24;
uniform vec4 lights[MAX_LIGHTS];
uniform vec4 tints[MAX_LIGHTS];
uniform int light_count = 0;
uniform vec3 ambient = vec3(0.35, 0.35, 0.45);
// 1 lights the whole chamber (Destello).
uniform float lift = 0.0;
// Top-left corner of this rectangle in stage pixels.
uniform vec2 origin = vec2(0.0);

varying vec2 stage_pos;

void vertex() {
	stage_pos = VERTEX + origin;
}

void fragment() {
	vec3 light = ambient;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 l = lights[i];
		float k = clamp(1.0 - distance(stage_pos, l.xy) / max(l.z, 1.0), 0.0, 1.0);
		light += tints[i].rgb * (k * k * (3.0 - 2.0 * k)) * l.w;
	}
	COLOR = vec4(min(mix(light, vec3(1.0), lift), vec3(1.0)), 1.0);
}
