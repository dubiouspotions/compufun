// The tube of the bench screen, shared by the Screen View (crt.gdshader) and the 3D monitor
// (crt_world.gdshader). ui/crt_tube.gd animates the global uniforms; docs/crt.md.

/** 1 shows the picture. Toward 0 it collapses to a line, then a dot that fades. */
global uniform float crt_power;
/** 0 is a cold tube, dark and too big; 1 is warm. */
global uniform float crt_warmup;
/** The strength of the degauss wobble. */
global uniform float crt_degauss;
/** 1 is locked to the signal. Toward 0 the picture tears, rolls and goes black. */
global uniform float crt_sync;
/** How strongly the mask is magnetised: blotches of wrong colour. */
global uniform float crt_magnetization;
/** The top-left of the mouse cursor in screen buffer pixels; far outside hides it. */
global uniform vec2 crt_cursor;
global uniform sampler2D crt_cursor_texture : filter_nearest;

// Glass position (0..1) to picture position (0..1). The twin of CrtScreen.bend().
vec2 crt_bend(vec2 uv, vec2 curvature, float underscan) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + underscan * 2.0;
	c *= 1.0 + curvature.yx * c.yx * c.yx;
	return c * 0.5 + 0.5;
}

// 1 inside the rounded rect of the tube's face, 0 outside, antialiased over aa.
float crt_tube_face(vec2 uv, float corner_radius, float aa) {
	vec2 aspect = vec2(4.0 / 3.0, 1.0);
	vec2 q = abs(uv - 0.5) * aspect;
	float d = length(max(q - (0.5 * aspect - corner_radius), 0.0)) - corner_radius;
	return 1.0 - smoothstep(-aa, aa, d);
}

// 1 inside the picture (0..1), 0 outside, antialiased over aa.
float crt_picture_edge(vec2 uv, float aa) {
	vec2 inside = smoothstep(vec2(-aa), vec2(aa), uv) * smoothstep(vec2(-aa), vec2(aa), 1.0 - uv);
	return inside.x * inside.y;
}

// The picture's width and height as the power-off squashes them to a line, then a dot.
vec2 crt_squash() {
	return vec2(mix(0.003, 1.0, smoothstep(0.25, 0.6, crt_power)), mix(0.004, 1.0, smoothstep(0.6, 1.0, crt_power)));
}

// Where the beam lands for the glass position uv: squashed, oversized while cold, shaken by the
// degauss, torn and rolled while out of sync. The black bar of the vertical blank rolls through.
vec2 crt_beam(vec2 uv, float time) {
	vec2 g = (uv - 0.5) / crt_squash();
	g /= 1.0 + 0.08 * (1.0 - crt_warmup);
	g += 0.5;
	float wobble = crt_degauss * crt_degauss;
	g.x += wobble * 0.03 * sin(g.y * 19.0 + time * 37.0) * sin(time * 6.0);
	g.y += wobble * 0.015 * sin(g.x * 13.0 - time * 23.0);
	float lost = 1.0 - crt_sync;
	g.x += lost * 0.08 * sin(g.y * 90.0 + time * 60.0) * sin(time * 17.0 + g.y * 7.0);
	if (lost > 0.0) {
		g.y = mod(g.y + lost * lost * 3.0, 1.09);
	}
	return g;
}

// The light of the tube on [param c] at picture position uv: warm-up, power, sync, magnetised
// blotches and the colours that swim while degaussing.
vec3 crt_tube_light(vec3 c, vec2 uv, float time) {
	vec2 drift = 0.04 * vec2(sin(time * 0.13), cos(time * 0.11));
	vec2 a = uv - vec2(0.18, 0.22) - drift;
	vec2 b = uv - vec2(0.8, 0.72) + drift;
	vec2 d = uv - vec2(0.86, 0.12) + drift.yx;
	vec3 blotch = exp(-dot(a, a) * 10.0) * vec3(0.9, -0.7, 1.0) + exp(-dot(b, b) * 8.0) * vec3(-0.6, 0.9, -0.5) + exp(-dot(d, d) * 18.0) * vec3(1.0, 0.7, -0.8);
	c *= max(1.0 + crt_magnetization * blotch, 0.0);
	float wobble = crt_degauss * crt_degauss;
	float swim = uv.x * 5.0 + uv.y * 3.0 + time * 7.0;
	c *= max(1.0 + wobble * 0.9 * vec3(sin(swim), sin(swim + 2.1), sin(swim + 4.2)), 0.0);
	c *= crt_warmup * crt_warmup;
	c *= smoothstep(0.0, 0.3, crt_sync);
	// The beam's energy crowds into the line and the dot, so they glow white-hot.
	vec2 squash = crt_squash();
	c = mix(c, vec3(max(c.r, max(c.g, c.b))), 1.0 - smoothstep(0.5, 0.9, crt_power));
	c *= mix(1.0, min(1.0 / sqrt(squash.x * squash.y), 8.0), 1.0 - crt_power) * smoothstep(0.0, 0.25, crt_power);
	return c;
}

// The screen buffer's pixel p, with the mouse cursor drawn over it.
vec3 crt_texel(sampler2D tex, ivec2 p) {
	ivec2 size = textureSize(tex, 0);
	vec3 c = texelFetch(tex, clamp(p, ivec2(0), size - 1), 0).rgb;
	ivec2 q = p - ivec2(floor(crt_cursor));
	if (all(greaterThanEqual(q, ivec2(0))) && all(lessThan(q, textureSize(crt_cursor_texture, 0)))) {
		vec4 k = texelFetch(crt_cursor_texture, q, 0);
		c = mix(c, k.rgb, k.a);
	}
	return c;
}
