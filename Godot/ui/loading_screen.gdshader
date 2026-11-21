shader_type canvas_item;
// Reveals a dark logo on white paper: first its outline draws on, then the ink fills in, both left
// to right. The paper is keyed out, so the logo never shows a box against the background.

// 0 shows nothing, 1 the whole logo. The loading screen drives it.
uniform float progress : hint_range(0.0, 1.0) = 1.0;
// The first part of progress draws the outline; the rest fills the ink in.
uniform float outline_share : hint_range(0.05, 0.95) = 0.3;
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
	float outline = edge * outline_color.a * wipe(progress / outline_share, UV.x);
	float filled = wipe((progress - outline_share) / (1.0 - outline_share), UV.x);
	COLOR = vec4(mix(outline_color.rgb, ink_color.rgb, filled), max(outline, here * ink_color.a * filled)) * tint;
}
