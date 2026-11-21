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
/** On: the texture follows the world, not the mesh UVs, so boxes of any size tile the same. */
uniform bool world_uv = false;
/** Repeats of the texture per metre (world_uv on) or per UV unit (world_uv off). */
uniform float uv_scale = 1.0;

varying vec2 plain_uv;
varying vec3 affine_uv;

void vertex() {
	vec2 uv = UV;
	if (world_uv) {
		vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 n = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
		if (n.y >= n.x && n.y >= n.z) {
			uv = p.xz;
		} else if (n.x >= n.z) {
			uv = vec2(p.z, -p.y);
		} else {
			uv = vec2(p.x, -p.y);
		}
	}
	uv *= uv_scale;
	plain_uv = uv;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (clip.w > 0.0) {
		vec2 half_size = VIEWPORT_SIZE * 0.5;
		vec2 ndc = clip.xy / clip.w;
		clip.xy = mix(ndc, round(ndc * half_size) / half_size, snap) * clip.w;
	}
	POSITION = clip;
	// The GPU interpolates uv * w and w with perspective; their ratio is the screen-linear UV.
	affine_uv = vec3(uv * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(plain_uv, affine_uv.xy / affine_uv.z, affine);
	ALBEDO = texture(albedo_texture, uv).rgb * albedo_color.rgb;
	ROUGHNESS = 1.0;
}
