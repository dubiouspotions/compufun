// A mid-90s VGA monitor on the picture of a SubViewportContainer (the screen buffer in the Screen
// View). Design and the reasons behind each effect: docs/crt.md. ui/crt_screen.gd maps the mouse
// through warp(); keep the two in step.
shader_type canvas_item;

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

group_uniforms power;
/** 1 shows the picture. Toward 0 it collapses to a line, then a dot that fades: the power-off. */
uniform float power : hint_range(0.0, 1.0, 0.001) = 1.0;
/** The tube's warm-up after power-on: 0 is cold and dark, 1 is fully warm. */
uniform float warmup : hint_range(0.0, 1.0, 0.001) = 1.0;
/** The strength of the degauss wobble: the picture shakes and its colours swim. */
uniform float degauss : hint_range(0.0, 1.0, 0.001) = 0.0;
group_uniforms;

vec3 to_linear(vec3 c) {
	return c * c;
}

vec3 to_display(vec3 c) {
	return sqrt(max(c, vec3(0.0)));
}

// Glass position (0..1) to picture position (0..1). The twin of CrtScreen.warp().
vec2 warp(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + underscan * 2.0;
	c *= 1.0 + vec2(curvature_y, curvature_x) * c.yx * c.yx;
	return c * 0.5 + 0.5;
}

// Bilinear that stays sharp at whole scales: blends only across the pixel's edge, over the width
// of one screen pixel. scale = screen pixels per VGA pixel.
vec3 sharp_sample(sampler2D tex, vec2 uv, vec2 size, float scale) {
	vec2 p = uv * size - 0.5;
	vec2 i = floor(p);
	vec2 f = clamp((p - i - 0.5) * scale + 0.5, 0.0, 1.0);
	ivec2 lo = clamp(ivec2(i), ivec2(0), ivec2(size) - 1);
	ivec2 hi = clamp(ivec2(i) + 1, ivec2(0), ivec2(size) - 1);
	vec3 a = texelFetch(tex, lo, 0).rgb;
	vec3 b = texelFetch(tex, ivec2(hi.x, lo.y), 0).rgb;
	vec3 c = texelFetch(tex, ivec2(lo.x, hi.y), 0).rgb;
	vec3 d = texelFetch(tex, hi, 0).rgb;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 fetch_linear(sampler2D tex, vec2 px, vec2 size) {
	return to_linear(texelFetch(tex, clamp(ivec2(px), ivec2(0), ivec2(size) - 1), 0).rgb);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 1 inside the rounded rect of the tube's face, 0 outside, antialiased over aa.
float tube_face(vec2 uv, float aa) {
	vec2 aspect = vec2(4.0 / 3.0, 1.0);
	vec2 q = abs(uv - 0.5) * aspect;
	vec2 half_size = 0.5 * aspect - corner_radius;
	float d = length(max(q - half_size, 0.0)) - corner_radius;
	return 1.0 - smoothstep(-aa, aa, d);
}

// 1 inside the picture (0..1), 0 outside, antialiased over aa.
float picture_edge(vec2 uv, float aa) {
	vec2 inside = smoothstep(vec2(-aa), vec2(aa), uv) * smoothstep(vec2(-aa), vec2(aa), 1.0 - uv);
	return inside.x * inside.y;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	// Screen pixels per VGA pixel: 2 in the 1080p Screen View, less during the zoom.
	float scale = 1.0 / max(fwidth(UV.y) * size.y, 1.0e-4);
	// The patterns line up with the screen pixels only at whole scales from 2x; elsewhere they moire.
	float fine = smoothstep(1.9, 2.0, scale) * (1.0 - smoothstep(0.02, 0.08, abs(scale - round(scale))));

	vec2 glass = UV;
	// Power-off: squash the picture to a line, then the line to a dot.
	float squash_y = mix(0.004, 1.0, smoothstep(0.6, 1.0, power));
	float squash_x = mix(0.003, 1.0, smoothstep(0.25, 0.6, power));
	glass = (glass - 0.5) / vec2(squash_x, squash_y) + 0.5;
	// Degauss: the field shakes the beam along the lines and swims the colours.
	float wobble = degauss * degauss;
	glass.x += wobble * 0.012 * sin(glass.y * 23.0 + TIME * 41.0) * sin(TIME * 7.0);
	glass.y += wobble * 0.006 * sin(glass.x * 17.0 - TIME * 29.0);

	vec2 uv = warp(glass);
	vec2 centered = uv * 2.0 - 1.0;
	vec2 misconverge = (centered * convergence * length(centered) / 1.41421 + vec2(static_convergence, 0.0)) / size;
	vec3 color;
	if (misconverge == vec2(0.0)) {
		color = to_linear(sharp_sample(TEXTURE, uv, size, scale));
	} else {
		color.r = to_linear(sharp_sample(TEXTURE, uv - misconverge, size, scale)).r;
		color.g = to_linear(sharp_sample(TEXTURE, uv, size, scale)).g;
		color.b = to_linear(sharp_sample(TEXTURE, uv + misconverge, size, scale)).b;
	}

	if (glow > 0.0) {
		vec2 px = uv * size;
		vec3 sum = vec3(0.0);
		for (int i = 0; i < 12; i++) {
			float angle = float(i) * 2.39996;  // golden angle: an even disc in few taps
			float r = glow_radius * sqrt((float(i) + 0.5) / 12.0);
			sum += fetch_linear(TEXTURE, px + r * vec2(cos(angle), sin(angle)), size);
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
	// Degauss: the field magnetises the mask for a moment, so the beams hit the wrong phosphors.
	float swim = uv.x * 4.0 + uv.y * 3.0 + TIME * 5.0;
	color *= 1.0 + wobble * 0.5 * vec3(sin(swim), sin(swim + 2.1), sin(swim + 4.2));

	// Warm-up: dark and soft at first, the last of the light comes slowly.
	color *= warmup * warmup;
	// Power-off: the beam's energy crowds into the line and the dot, so they glow bright.
	float squashed = 1.0 / sqrt(squash_x * squash_y);
	color = mix(color, vec3(max(color.r, max(color.g, color.b))), 1.0 - smoothstep(0.5, 0.9, power));
	color *= mix(1.0, min(squashed, 6.0), 1.0 - power) * smoothstep(0.0, 0.25, power);

	color *= picture_edge(uv, fwidth(uv.y));
	color = max(color, to_linear(black_level)) * tube_face(UV, fwidth(UV.y));
	COLOR = vec4(to_display(color), 1.0);
}
