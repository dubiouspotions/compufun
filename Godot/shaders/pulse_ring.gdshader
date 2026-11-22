// A ring that calls attention to a small thing the player can use, such as a panel screw: a steady
// ring that brightens on each beat, and a second ring that grows out of it and fades. It faces the
// camera and draws over the scene, so its hole must be wider than the thing it rings.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.84, 0.35, 1.0);
/** The seconds of one beat. */
uniform float period = 1.0;
/** The steady ring's radius and the rings' width, in shares of the quad's half size. */
uniform float radius = 0.45;
uniform float width = 0.14;
/** How far toward white the colour goes at the peak of a beat, from 0 to 1. */
uniform float flash = 0.6;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float t = fract(TIME / period);
	float r = length(UV * 2.0 - 1.0);
	float beat = 0.5 + 0.5 * cos(t * TAU);
	float steady = step(abs(r - radius), width * 0.5);
	float grown = mix(radius, 1.0 - width * 0.5, t);
	float ping = step(abs(r - grown), width * 0.5) * sqrt(1.0 - t);
	ALBEDO = mix(color.rgb, vec3(1.0), flash * beat);
	ALPHA = color.a * max(steady * (0.55 + 0.45 * beat), ping);
}
