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
/** The part of the texture that the UV square shows: x, y, width, height, in shares of the texture. */
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
/** The picked colour: the average colour of tint_rect (x, y, width, height) in tint_texture. */
uniform sampler2D tint_texture : source_color, filter_linear, hint_default_white;
uniform vec4 tint_rect = vec4(0.15, 0.2, 0.7, 0.7);
/** On: the picked colour tints the texture instead of albedo_color. */
uniform bool tint_from_texture = false;
/** Fades the sides and the top of the texture into the picked colour, as a share of the texture.
 * Where uv_rect reaches past the texture, the picked colour shows. */
uniform float edge_fade : hint_range(0.0, 0.5) = 0.0;
/** On: the transparent parts of the texture show the picked colour. */
uniform bool fill_transparent = false;

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
	uv = uv_rect.xy + uv * uv_scale * uv_rect.zw;
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
	vec3 picked = albedo_color.rgb;
	if (tint_from_texture || edge_fade > 0.0 || fill_transparent) {
		// A 5 x 5 grid, weighted by alpha, so transparent pixels do not darken the average.
		vec4 sum = vec4(0.0);
		for (int i = 0; i < 5; i++) {
			for (int j = 0; j < 5; j++) {
				vec4 texel = texture(tint_texture, tint_rect.xy + (vec2(float(i), float(j)) + 0.5) / 5.0 * tint_rect.zw);
				sum += vec4(texel.rgb * texel.a, texel.a);
			}
		}
		picked = sum.a > 0.0 ? sum.rgb / sum.a : albedo_color.rgb;
	}
	vec4 texel = texture(albedo_texture, uv);
	vec3 color = texel.rgb * (tint_from_texture ? picked : albedo_color.rgb);
	if (fill_transparent) {
		color = mix(picked, color, step(0.5, texel.a));
	}
	if (edge_fade > 0.0) {
		float edge = min(min(uv.x, 1.0 - uv.x), uv.y);
		color = mix(picked, color, smoothstep(0.0, edge_fade, edge) * step(uv.y, 1.0));
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
