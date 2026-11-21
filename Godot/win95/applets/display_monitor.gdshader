shader_type canvas_item;
// The stock grays of the picture take the scheme's 3D colours, as Win95's LR_LOADMAP3DCOLORS does.

uniform vec4 face_color : source_color = vec4(0.7529412, 0.7529412, 0.7529412, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.5019608, 0.5019608, 0.5019608, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0);
uniform vec4 dark_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

bool is_gray(vec3 c, float v) {
	return all(lessThan(abs(c - vec3(v)), vec3(0.01)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (is_gray(c.rgb, 0.7529412)) {
		c.rgb = face_color.rgb;
	} else if (is_gray(c.rgb, 0.5019608)) {
		c.rgb = shadow_color.rgb;
	} else if (is_gray(c.rgb, 1.0)) {
		c.rgb = highlight_color.rgb;
	} else if (is_gray(c.rgb, 0.0)) {
		c.rgb = dark_shadow_color.rgb;
	}
	COLOR = c;
}
