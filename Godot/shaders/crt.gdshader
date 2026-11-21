// A mid-90s VGA monitor on the screen buffer, for the Screen View (ui/crt_screen.gd). Design and
// the reasons behind each effect: docs/crt.md.
shader_type canvas_item;

#include "res://shaders/crt.gdshaderinc"

/** The screen buffer; CrtScreen sets it. A headless compile, as in CI's export, rejects TEXTURE as a function argument. */
uniform sampler2D screen_texture : filter_nearest;

group_uniforms tube;
/** How far the glass curves from left to right. It bows the horizontal lines; a Trinitron curves only this way. */
uniform float curvature_x : hint_range(0.0, 0.3, 0.005) = 0.04;
/** How far the glass curves from top to bottom. It bows the vertical lines. */
uniform float curvature_y : hint_range(0.0, 0.3, 0.005) = 0.04;
/** The black border between the picture and the bezel, as a share of the screen. */
uniform float underscan : hint_range(0.0, 0.15, 0.005) = 0.0;
/** The roundness of the tube's corners, as a share of the screen's height. The curve keeps the picture's corners inside. */
uniform float corner_radius : hint_range(0.0, 0.2, 0.005) = 0.03;
/** The darkening toward the edges and corners. 0 turns it off. */
uniform float vignette : hint_range(0.0, 1.0, 0.01) = 0.2;

group_uniforms beam;
/** How dark the gap between two lines of the picture is. VGA at 480 lines barely shows one. */
uniform float scanlines : hint_range(0.0, 1.0, 0.01) = 0.12;
/** How much bright pixels widen the beam and close the gap between lines. */
uniform float beam_bloom : hint_range(0.0, 1.0, 0.01) = 0.6;
/** Red and blue land this many VGA pixels off green at the corners. */
uniform float convergence : hint_range(0.0, 2.0, 0.05) = 0.4;
/** Red lands this many VGA pixels right of green everywhere, and blue as far left. */
uniform float static_convergence : hint_range(-1.0, 1.0, 0.05) = 0.1;

group_uniforms phosphor;
/** 0: no mask. 1: aperture grille (Trinitron stripes). 2: shadow mask (dot triads). */
uniform int mask_type : hint_range(0, 2) = 2;
/** How dark the mask is between the phosphors. */
uniform float mask_strength : hint_range(0.0, 1.0, 0.01) = 0.25;
/** The faint horizontal wire across a 14 or 15 inch Trinitron, two thirds of the way down. */
uniform float damper_wire : hint_range(0.0, 0.5, 0.01) = 0.0;
/** The glow of light that scatters in the glass around bright areas. */
uniform float glow : hint_range(0.0, 1.0, 0.01) = 0.15;
/** How far the glow spreads, in VGA pixels. */
uniform float glow_radius : hint_range(1.0, 8.0, 0.1) = 3.0;
/** The colour of white. Monitors of the time shipped at 9300 K: white is a little blue. */
uniform vec3 white_point : source_color = vec3(0.94, 0.97, 1.0);
/** The glow of the glass where the picture is black: phosphor grey and the room's light. */
uniform vec3 black_level : source_color = vec3(0.02, 0.025, 0.025);
/** Multiplies the picture; it makes up for the light that the mask takes. */
uniform float brightness : hint_range(0.5, 2.0, 0.01) = 1.15;

group_uniforms interference;
/** A random flicker of the whole picture, frame to frame. */
uniform float flicker : hint_range(0.0, 0.1, 0.005) = 0.0;
/** A faint band that rolls up the screen: mains hum beating against the refresh rate. */
uniform float hum_bar : hint_range(0.0, 0.1, 0.005) = 0.0;
/** How many times a second the hum bar crosses the screen. */
uniform float hum_bar_speed : hint_range(0.0, 1.0, 0.01) = 0.08;

group_uniforms;

vec3 to_linear(vec3 c) {
	return c * c;
}

vec3 to_display(vec3 c) {
	return sqrt(max(c, vec3(0.0)));
}

// Bilinear that stays sharp at whole scales: blends only across the pixel's edge, over the width
// of one screen pixel. scale = screen pixels per VGA pixel.
vec3 sharp_sample(sampler2D tex, vec2 uv, vec2 size, float scale) {
	vec2 p = uv * size - 0.5;
	vec2 i = floor(p);
	vec2 f = clamp((p - i - 0.5) * scale + 0.5, 0.0, 1.0);
	ivec2 lo = clamp(ivec2(i), ivec2(0), ivec2(size) - 1);
	ivec2 hi = clamp(ivec2(i) + 1, ivec2(0), ivec2(size) - 1);
	vec3 a = crt_texel(tex, lo);
	vec3 b = crt_texel(tex, ivec2(hi.x, lo.y));
	vec3 c = crt_texel(tex, ivec2(lo.x, hi.y));
	vec3 d = crt_texel(tex, hi);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 fetch_linear(sampler2D tex, vec2 px, vec2 size) {
	return to_linear(crt_texel(tex, ivec2(floor(px))));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 size = vec2(textureSize(screen_texture, 0));
	// Screen pixels per VGA pixel: 2 in the 1080p Screen View, less during the zoom.
	float scale = 1.0 / max(fwidth(UV.y) * size.y, 1.0e-4);
	// The patterns line up with the screen pixels only at whole scales from 2x; elsewhere they moire.
	float fine = smoothstep(1.9, 2.0, scale) * (1.0 - smoothstep(0.02, 0.08, abs(scale - round(scale))));

	vec2 uv = crt_bend(crt_beam(UV, TIME), vec2(curvature_x, curvature_y), underscan);
	vec2 centered = uv * 2.0 - 1.0;
	vec2 misconverge = (centered * convergence * length(centered) / 1.41421 + vec2(static_convergence, 0.0)) / size;
	vec3 color;
	if (misconverge == vec2(0.0)) {
		color = to_linear(sharp_sample(screen_texture, uv, size, scale));
	} else {
		color.r = to_linear(sharp_sample(screen_texture, uv - misconverge, size, scale)).r;
		color.g = to_linear(sharp_sample(screen_texture, uv, size, scale)).g;
		color.b = to_linear(sharp_sample(screen_texture, uv + misconverge, size, scale)).b;
	}

	if (glow > 0.0) {
		vec2 px = uv * size;
		vec3 sum = vec3(0.0);
		for (int i = 0; i < 12; i++) {
			float angle = float(i) * 2.39996;  // golden angle: an even disc in few taps
			float r = glow_radius * sqrt((float(i) + 0.5) / 12.0);
			sum += fetch_linear(screen_texture, px + r * vec2(cos(angle), sin(angle)), size);
		}
		color += sum / 12.0 * glow;
	}

	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	// Scanlines sit on the glass, not in the bent picture: bent lines would beat against the
	// screen pixels. At 2x the upper screen row of each VGA line is the beam's centre.
	float line = fract(UV.y * size.y);
	float gap = smoothstep(0.0, 1.0, abs(line - 0.25) * 2.0);
	color *= 1.0 - scanlines * fine * gap * (1.0 - beam_bloom * clamp(luma, 0.0, 1.0));

	vec2 cell = UV * size;
	if (mask_type > 0) {
		float shift = mask_type == 2 ? 0.5 * mod(floor(cell.y), 2.0) : 0.0;
		float dark = 1.0 - mask_strength * fine;
		color *= fract(cell.x + shift) < 0.5 ? vec3(1.0, dark, 1.0) : vec3(dark, 1.0, dark);
	}
	if (damper_wire > 0.0 && floor(cell.y) == floor(size.y * 2.0 / 3.0)) {
		color *= 1.0 - damper_wire * fine;
	}

	vec2 from_centre = UV * 2.0 - 1.0;
	color *= 1.0 - vignette * smoothstep(0.3, 1.6, dot(from_centre, from_centre));
	color *= 1.0 + flicker * (hash(vec2(TIME, 0.37)) - 0.5) * 2.0;
	color *= 1.0 - hum_bar * smoothstep(0.0, 1.0, sin((UV.y + TIME * hum_bar_speed) * 6.28318) * 0.5 + 0.5);
	color *= brightness * white_point;
	color = crt_tube_light(color, uv, TIME);

	color *= crt_picture_edge(uv, fwidth(uv.y));
	color = max(color, to_linear(black_level)) * crt_tube_face(UV, corner_radius, fwidth(UV.y));
	COLOR = vec4(to_display(color), 1.0);
}
