shader_type canvas_item;
// The white paper of the loading screen. hole cuts the logo's ink out of it, so the game shows
// through the letters once it runs underneath. The cut's edge stays sharp however far it zooms in.

uniform sampler2D logo : source_color, filter_linear;
// Where the logo lies on the paper, in the paper's pixels: x, y, width, height.
uniform vec4 logo_rect = vec4(0.0, 0.0, 1.0, 1.0);
// 0 is solid paper, 1 cuts out all the ink.
uniform float hole : hint_range(0.0, 1.0) = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 uv = (local - logo_rect.xy) / logo_rect.zw;
	float ink = 0.0;
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		ink = 1.0 - dot(texture(logo, uv).rgb, vec3(0.299, 0.587, 0.114));
	}
	// The ink's edge is where it is half grey, one screen pixel wide at any zoom: the zoom magnifies the
	// picture up to about 90 times, and its soft rims would blur over as many pixels.
	float edge = max(fwidth(ink), 0.0001);
	ink = clamp((ink - 0.5) / edge + 0.5, 0.0, 1.0);
	COLOR.a *= 1.0 - ink * hole;
}
