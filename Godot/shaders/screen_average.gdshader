// The average colour of a screen buffer, drawn into a 1 x 1 viewport that CrtMonitor reads to colour
// the light that its screen casts on the bezel.
shader_type canvas_item;

/** The screen buffer; CrtMonitor sets it. */
uniform sampler2D screen_texture : filter_linear, repeat_disable;

const ivec2 GRID = ivec2(16, 12);

void fragment() {
	vec3 sum = vec3(0.0);
	for (int y = 0; y < GRID.y; y++) {
		for (int x = 0; x < GRID.x; x++) {
			sum += textureLod(screen_texture, (vec2(float(x), float(y)) + 0.5) / vec2(GRID), 0.0).rgb;
		}
	}
	COLOR = vec4(sum / float(GRID.x * GRID.y), 1.0);
}
