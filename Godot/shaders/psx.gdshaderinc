// The PSX colour cut, shared by the world's post pass (psx_post.gdshader) and the CRT close-up's
// glass border (crt.gdshader), so both dither alike.

const float PSX_BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

// The 4 x 4 ordered dither's offset for pixel p, from -0.5 to 0.5.
float psx_dither_offset(ivec2 p) {
	ivec2 cell = p % 4;
	return (PSX_BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0 - 0.5;
}

// c cut to [param levels] steps per channel, moved by [param offset] times [param dither] steps first.
vec3 psx_cut(vec3 c, float levels, float offset, float dither) {
	float steps = levels - 1.0;
	return floor(c * steps + 0.5 + offset * dither) / steps;
}
