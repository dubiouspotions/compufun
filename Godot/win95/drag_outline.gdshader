shader_type canvas_item;
// The outline that Win95 drags instead of the window: a checkerboard band that inverts what it covers.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec2 size = vec2(100.0, 100.0);
uniform float thickness = 3.0;

void fragment() {
	vec2 p = UV * size;
	bool band = p.x < thickness || p.y < thickness || p.x >= size.x - thickness || p.y >= size.y - thickness;
	ivec2 px = ivec2(FRAGCOORD.xy);
	if (band && (px.x + px.y) % 2 == 0) {
		COLOR = vec4(1.0 - texture(screen, SCREEN_UV).rgb, 1.0);
	} else {
		COLOR = vec4(0.0);
	}
}
