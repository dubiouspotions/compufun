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
varying vec3 model_position;

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
	model_position = VERTEX;
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

// Fades the picture into the vertex colour where the vertex alpha is low: the photo relief's shared
// colour at its outline, where its front and back meet.
uniform bool vertex_color_fade = false;

/** 0 = clean. 1 = a broken part's look: darker, with blotches and specks of dirt. Piece.make_model
 * gives each mesh of a broken piece a copy of its material with this at 1. Not an instance uniform:
 * every mesh with this shader would take one of the 4096 instance-variable slots. */
uniform float grime : hint_range(0.0, 1.0) = 0.0;
/** The share of its colour that a fully grimy surface keeps. */
uniform float grime_darken : hint_range(0.0, 1.0) = 0.6;
uniform vec3 grime_color : source_color = vec3(0.22, 0.18, 0.12);
/** Dirt cells per metre of the model: the size of a blotch. Specks are four times smaller. */
uniform float grime_cells = 70.0;
/** How much of a blotch's and of a speck's colour is dirt. */
uniform float grime_blotch : hint_range(0.0, 1.0) = 0.55;
uniform float grime_speck : hint_range(0.0, 1.0) = 0.6;

float grime_hash(vec3 cell) {
	return fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// Smooth value noise, 0 to 1, over cells of size 1.
float grime_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(0.0, 1.0, fract(p));
	float x00 = mix(grime_hash(i), grime_hash(i + vec3(1, 0, 0)), f.x);
	float x10 = mix(grime_hash(i + vec3(0, 1, 0)), grime_hash(i + vec3(1, 1, 0)), f.x);
	float x01 = mix(grime_hash(i + vec3(0, 0, 1)), grime_hash(i + vec3(1, 0, 1)), f.x);
	float x11 = mix(grime_hash(i + vec3(0, 1, 1)), grime_hash(i + vec3(1, 1, 1)), f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

vec3 with_grime(vec3 color) {
	vec3 p = model_position * grime_cells;
	float blotch = smoothstep(0.5, 0.75, grime_noise(p)) * grime_blotch;
	float speck = step(0.88, grime_hash(floor(p * 4.0))) * grime_speck;
	vec3 dirty = mix(color * grime_darken, grime_color, max(blotch, speck));
	return mix(color, dirty, grime);
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
	if (vertex_color_fade) {
		color = mix(COLOR.rgb, color, COLOR.a);
	}
	if (grime > 0.0) {
		color = with_grime(color);
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
