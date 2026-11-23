// psx_world.gdshader in the transparent pass, without depth writes: the room still hides it, but
// among themselves these surfaces draw in the order of their sorting_offset, the highest last, as
// layers of paint (the posters_bounce trail). Fully opaque all the same.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, depth_draw_never;

#define PSX_LAYERED
#include "res://shaders/psx_world.gdshaderinc"
