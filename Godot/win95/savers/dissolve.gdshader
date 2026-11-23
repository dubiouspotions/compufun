shader_type canvas_item;
// Blacks out the rect block by block in a random order as progress runs from 0 to 1.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 block = vec2(2.0, 2.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, hash(floor(FRAGCOORD.xy / block)) < progress ? 1.0 : 0.0);
}
