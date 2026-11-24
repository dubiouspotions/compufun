extends SceneTree
## Draws Win95's "Working in Background" cursor: the arrow with a small hourglass beside it, from memory
## (no reference shot yet). Run from Godot/:
## godot --headless -s ../tools/make_busy_cursor.gd

const ARROW := "res://win95/theme/arrow_cursor.png"
const OUT := "res://win95/theme/busy_cursor.png"
const HOURGLASS := [
	"#########",
	"#ooooooo#",
	"#########",
	" #ooooo# ",
	" #o###o# ",
	"  #o#o#  ",
	"   #o#   ",
	"  #ooo#  ",
	" #oo#oo# ",
	" #o###o# ",
	"#########",
	"#ooooooo#",
	"#########",
]
const AT := Vector2i(11, 6)  # the hourglass's top left, right of the arrow's diagonal


func _init() -> void:
	var arrow := Image.load_from_file(ProjectSettings.globalize_path(ARROW))
	if arrow == null:
		push_error("make_busy_cursor: can't load %s" % ARROW)
		quit(1)
		return
	arrow.convert(Image.FORMAT_RGBA8)
	var size := Vector2i(maxi(arrow.get_width(), AT.x + HOURGLASS[0].length()), maxi(arrow.get_height(), AT.y + HOURGLASS.size()))
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.blit_rect(arrow, Rect2i(Vector2i.ZERO, arrow.get_size()), Vector2i.ZERO)
	for y: int in HOURGLASS.size():
		for x: int in HOURGLASS[y].length():
			var pixel: String = HOURGLASS[y][x]
			if pixel != " ":
				image.set_pixelv(AT + Vector2i(x, y), Color.BLACK if pixel == "#" else Color.WHITE)
	var error := image.save_png(ProjectSettings.globalize_path(OUT))
	if error != OK:
		push_error("make_busy_cursor: can't save %s: %s" % [OUT, error_string(error)])
	quit(1 if error != OK else 0)
