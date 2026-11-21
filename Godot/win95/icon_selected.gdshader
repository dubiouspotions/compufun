shader_type canvas_item;
// Win95 marks a selected icon by covering every other pixel with the selection colour.

uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.502, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 px = ivec2(FRAGCOORD.xy);
	if (c.a > 0.0 && (px.x + px.y) % 2 == 0) {
		c.rgb = tint.rgb;
	}
	COLOR = c;
}
