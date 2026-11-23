// The PSX look on a 3D surface: vertices snap to the pixel grid (the PS1 wobble), textures warp
// (affine mapping) and texels stay sharp. Large polygons warp the most: split big floors and walls.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/psx_world.gdshaderinc"
