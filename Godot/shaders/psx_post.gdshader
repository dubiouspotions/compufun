// The PSX look on a whole picture: a 4 x 4 ordered dither, then fewer colours. Put it in the
// material of the SubViewportContainer that shows the 3D world, or of a TextureRect (a portrait).
// Set the node's texture_filter to Nearest. With a palette, each pixel takes the nearest palette
// colour instead of the colour cut.
shader_type canvas_item;

/** Steps per colour channel. 32 is 15-bit colour, as on the PS1. 256 turns the cut off. */
uniform float color_levels : hint_range(2.0, 256.0) = 32.0;
/** Optional: one row of equal-width colour swatches, such as fade-grub-32x.png. */
uniform sampler2D palette : filter_nearest;
/** The number of swatches in the palette. 0 = no palette: use color_levels. */
uniform int palette_size : hint_range(0, 64) = 0;
/** How far the dither moves a colour, in steps. 0 turns the dither off. */
uniform float dither : hint_range(0.0, 2.0) = 1.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

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

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// The pattern follows the pixels of the source picture, so it scales up with the picture.
	ivec2 cell = ivec2(floor(UV / TEXTURE_PIXEL_SIZE)) % 4;
	float offset = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0 - 0.5;
	vec3 c;
	if (palette_size > 0) {
		c = nearest_palette_color(source.rgb + offset * dither / float(palette_size));
	} else {
		float steps = color_levels - 1.0;
		c = floor(source.rgb * steps + 0.5 + offset * dither) / steps;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), source.a);
}
