// The PSX look on a 3D surface: vertices snap to the pixel grid (the PS1 wobble), textures warp
// (affine mapping) and texels stay sharp. Large polygons warp the most: split big floors and walls.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
/** 0 = smooth edges. 1 = each vertex snaps to a whole pixel of the 3D viewport. */
uniform float snap : hint_range(0.0, 1.0) = 1.0;
/** 0 = correct perspective. 1 = the full PS1 texture warp. */
uniform float affine : hint_range(0.0, 1.0) = 0.5;

varying vec3 affine_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (clip.w > 0.0) {
		vec2 half_size = VIEWPORT_SIZE * 0.5;
		vec2 ndc = clip.xy / clip.w;
		clip.xy = mix(ndc, round(ndc * half_size) / half_size, snap) * clip.w;
	}
	POSITION = clip;
	// The GPU interpolates UV * w and w with perspective; their ratio is the screen-linear UV.
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, affine);
	ALBEDO = texture(albedo_texture, uv).rgb * albedo_color.rgb;
	ROUGHNESS = 1.0;
}
