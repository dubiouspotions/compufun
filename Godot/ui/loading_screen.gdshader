shader_type canvas_item;
// Reveals a dark logo on white paper: its outline draws on, and the ink fills in close behind, both
// left to right. The paper is keyed out, so the logo never shows a box against the background.

// How far the outline and the ink have drawn in: 0 shows nothing, 1 the whole logo, and in between
// about that share of the logo's width. The loading screen drives both.
uniform float outline_progress : hint_range(0.0, 1.0) = 1.0;
uniform float ink_progress : hint_range(0.0, 1.0) = 1.0;
// In texels of the logo, inside the ink.
uniform float outline_width : hint_range(0.5, 16.0) = 3.0;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 ink_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// The width of the soft front of each wipe, as a share of the logo width.
uniform float softness : hint_range(0.001, 0.5) = 0.02;

float ink(vec4 color) {
	return 1.0 - dot(color.rgb, vec3(0.299, 0.587, 0.114));
}

// 1 behind the wipe front and 0 ahead of it; t = 0 covers nothing, t = 1 covers everything.
float wipe(float t, float x) {
	float front = mix(-softness, 1.0 + softness, clamp(t, 0.0, 1.0));
	return 1.0 - smoothstep(front - softness, front + softness, x);
}

// The node's modulate and the vertex colour, which the custom COLOR below must keep.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	float here = ink(texture(TEXTURE, UV));
	float least = here;
	for (int i = 0; i < 12; i++) {
		float angle = float(i) * TAU / 12.0;
		vec2 offset = vec2(cos(angle), sin(angle)) * outline_width * TEXTURE_PIXEL_SIZE;
		least = min(least, ink(texture(TEXTURE, UV + offset)));
	}
	float edge = here - least;
	float outline = edge * outline_color.a * wipe(outline_progress, UV.x);
	float filled = wipe(ink_progress, UV.x);
	COLOR = vec4(mix(outline_color.rgb, ink_color.rgb, filled), max(outline, here * ink_color.a * filled)) * tint;
}
