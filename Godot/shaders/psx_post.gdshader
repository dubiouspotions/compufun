// The PSX look on a whole picture: an optional vignette, an optional drift towards the Windows
// colours, a 4 x 4 ordered dither, then fewer colours. Put it in the material of the
// SubViewportContainer that shows the 3D world, or of a TextureRect (a portrait).
// Set the node's texture_filter to Nearest. With a palette, each pixel takes the nearest palette
// colour instead of the colour cut.
shader_type canvas_item;

#include "res://shaders/psx.gdshaderinc"

/** Steps per colour channel. 32 is 15-bit colour, as on the PS1. 256 turns the cut off. */
uniform float color_levels : hint_range(2.0, 256.0) = 32.0;
/** Optional: one row of equal-width colour swatches, such as fade-grub-32x.png. */
uniform sampler2D palette : filter_nearest;
/** The number of swatches in the palette. 0 = no palette: use color_levels. */
uniform int palette_size : hint_range(0, 64) = 0;
/** How far the dither moves a colour, in steps. 0 turns the dither off. */
uniform float dither : hint_range(0.0, 2.0) = 1.0;
/** How much the corners darken: 0 turns the vignette off, 1 turns the corners black. */
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
/** Where the darkening starts, as a share of the distance from the centre to a corner. */
uniform float vignette_start : hint_range(0.0, 1.0) = 0.4;
/** How far the colours drift towards the 16 colours of Windows 95: 0 = no change, 1 = only those. */
uniform float windows_shades : hint_range(0.0, 1.0) = 0.0;

// The 16 colours of VGA, the Windows 95 palette.
const vec3 WINDOWS_COLORS[16] = vec3[16](
	vec3(0.0), vec3(0.5, 0.0, 0.0), vec3(0.0, 0.5, 0.0), vec3(0.5, 0.5, 0.0),
	vec3(0.0, 0.0, 0.5), vec3(0.5, 0.0, 0.5), vec3(0.0, 0.5, 0.5), vec3(0.75),
	vec3(0.5), vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(1.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0), vec3(1.0, 0.0, 1.0), vec3(0.0, 1.0, 1.0), vec3(1.0));

vec3 nearest_palette_color(vec3 c) {
	vec3 best = c;
	float best_distance = 1.0e9;
	for (int i = 0; i < palette_size; i++) {
		vec3 p = texture(palette, vec2((float(i) + 0.5) / float(palette_size), 0.5)).rgb;
		float d = dot(c - p, c - p);
		if (d < best_distance) {
			best_distance = d;
			best = p;
		}
	}
	return best;
}

vec3 nearest_windows_color(vec3 c) {
	vec3 best = WINDOWS_COLORS[0];
	float best_distance = 1.0e9;
	for (int i = 0; i < 16; i++) {
		vec3 d = c - WINDOWS_COLORS[i];
		if (dot(d, d) < best_distance) {
			best_distance = dot(d, d);
			best = WINDOWS_COLORS[i];
		}
	}
	return best;
}

// The node's modulate, which fragment() would lose by writing COLOR.
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * modulate;
	float from_centre = length(UV - 0.5) / length(vec2(0.5));
	source.rgb *= 1.0 - vignette * smoothstep(vignette_start, 1.0, from_centre);
	// The pattern follows the pixels of the source picture, so it scales up with the picture.
	float offset = psx_dither_offset(ivec2(floor(UV / TEXTURE_PIXEL_SIZE)));
	// The drift dithers between the Windows colours, as a 16-colour picture does.
	if (windows_shades > 0.0) {  // the search is 16 steps per window pixel; skip it while it changes nothing
		source.rgb = mix(source.rgb, nearest_windows_color(source.rgb + offset * 0.25), windows_shades);
	}
	vec3 c;
	if (palette_size > 0) {
		c = nearest_palette_color(source.rgb + offset * dither / float(palette_size));
	} else {
		c = psx_cut(source.rgb, color_levels, offset, dither);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), source.a);
}
