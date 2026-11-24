// The CRT look's glow, once per pixel of the screen buffer instead of once per pixel of the window:
// the average light of an even disc of 12 texels around it, the cursor included. CrtScreen renders
// it into a viewport beside the buffer, and crt.gdshader reads it. docs/crt.md.
shader_type canvas_item;
render_mode blend_disabled;

#include "res://shaders/crt.gdshaderinc"

uniform sampler2D screen_texture : filter_nearest;
/** The disc's radius in buffer pixels: the look's glow_radius. */
uniform float glow_radius = 3.0;

// Tap i at radius sqrt((i + 0.5) / 12) and angle i * 2.39996, the golden angle.
const vec2 TAPS[12] = vec2[12](
	vec2(0.2041241, 0.0000000),
	vec2(-0.2606985, 0.2388227),
	vec2(0.0399013, -0.4546880),
	vec2(0.3285987, 0.4285902),
	vec2(-0.6030128, -0.1066564),
	vec2(0.5712192, -0.3633758),
	vec2(-0.1910498, 0.7107508),
	vec2(-0.3643949, -0.7015813),
	vec2(0.7905641, 0.2886896),
	vec2(-0.8224326, 0.3395162),
	vec2(0.3964443, -0.8472496),
	vec2(0.2930156, 0.9340638));

void fragment() {
	vec2 size = vec2(textureSize(screen_texture, 0));
	vec2 px = (floor(UV * size) + 0.5);
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		vec3 c = crt_texel(screen_texture, ivec2(floor(px + glow_radius * TAPS[i])));
		sum += c * c;
	}
	COLOR = vec4(sqrt(sum / 12.0), 1.0);  // the square root keeps the dark end's precision in 8 bits
}
