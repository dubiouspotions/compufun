class_name DesktopScreenshot
extends ImageTexture
## A screenshot of a desktop, for the prank that sets it as the wallpaper: the wallpaper with the
## icons on it, as they were. The Win95 screen draws it at the first boot that shows it (win95.gd);
## until then it is black.

## The size of the desktop, and so of the picture.
const SIZE := Vector2i(640, 480)

## The wallpaper under the icons.
@export var wallpaper: Texture2D
## The desktop's icons, in order, after the system icons.
@export var icons: Array[Win95File] = []
## How much colour the picture loses, as a cheap capture would: the steps per channel (256 keeps
## them all) and the dither, as in psx_post.gdshader.
@export_range(2.0, 256.0) var color_levels := 256.0
@export_range(0.0, 2.0) var dither := 0.0
## The picture has been drawn, or is being drawn.
var taken := false


func _init() -> void:
	set_image(Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGB8))
