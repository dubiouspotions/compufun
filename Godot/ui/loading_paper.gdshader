shader_type canvas_item;
// The white paper of the loading screen. hole cuts the logo's ink out of it, so the game shows
// through the letters once it runs underneath.

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
	COLOR.a *= 1.0 - ink * hole;
}
