// The bench screen's tube in the 3D room: the screen buffer bent and lit like the Screen View's
// CRT look, without the mask and scanlines, which the small world buffer can't show. docs/crt.md.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/crt.gdshaderinc"

/** The screen buffer; CrtMonitor sets it. */
uniform sampler2D screen_texture : filter_nearest;
/** How far the glass curves from left to right. The Screen View starts its zoom with this curve. */
uniform float curvature_x : hint_range(0.0, 0.3, 0.005) = 0.05;
/** How far the glass curves from top to bottom. */
uniform float curvature_y : hint_range(0.0, 0.3, 0.005) = 0.05;
/** The black border between the picture and the bezel, as a share of the screen. */
uniform float underscan : hint_range(0.0, 0.15, 0.005) = 0.02;
/** The roundness of the tube's corners, as a share of the screen's height. */
uniform float corner_radius : hint_range(0.0, 0.2, 0.005) = 0.04;
/** The darkening toward the edges and corners. */
uniform float vignette : hint_range(0.0, 1.0, 0.01) = 0.3;
/** The colour of white. */
uniform vec3 white_point = vec3(0.95, 0.97, 1.0);
/** The glow of the glass where the picture is black. */
uniform vec3 black_level = vec3(0.02, 0.025, 0.025);
/** Multiplies the picture, so the screen glows in the dim room. */
uniform float brightness : hint_range(0.5, 2.0, 0.01) = 1.1;

void fragment() {
	vec2 uv = crt_bend(crt_beam(UV, TIME), vec2(curvature_x, curvature_y), underscan);
	vec2 size = vec2(textureSize(screen_texture, 0));
	vec3 color = crt_texel(screen_texture, ivec2(floor(uv * size)));
	vec2 from_centre = UV * 2.0 - 1.0;
	color *= 1.0 - vignette * smoothstep(0.3, 1.6, dot(from_centre, from_centre));
	color *= brightness * white_point;
	color = crt_tube_light(color, uv, TIME);
	float aa = fwidth(uv.y);
	color *= crt_picture_edge(uv, aa);
	ALBEDO = max(color, black_level) * crt_tube_face(UV, corner_radius, fwidth(UV.y));
}
